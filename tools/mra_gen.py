#!/usr/bin/env python3
"""Generate the MRA files for the Williams/Midway Y Unit core from MAME's
midyunit.cpp driver source.

usage: mra_gen.py <midyunit.cpp> <out dir> [rom zips for md5/verification...]

ROM index 0 is assembled from the MAME regions in this order (see
Arcade-Midway-Y-Unit.sv): maindata (1 MB), gfx (8 MB), sound CPU (from MAME
offset 0x10000, 1 MB window), OKI samples (1 MB, ADPCM games only). Gaps inside a
region are filled with zeros so every byte of the image is defined.
"""
import os, re, sys, hashlib, zipfile, datetime
from xml.sax.saxutils import escape, quoteattr

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from yunit_roms import parse_driver, build_image, RomSource, REGION_BASE
import yunit_fmoves

MAMEVERSION = '0289'
RBF = 'Arcade-Midway-Y-Unit'

# set name -> (game id, layout)
GAME_ID = {
	'trog': 0, 'trog4': 0, 'trog3': 0, 'trog3a': 0, 'trogpa6': 0, 'trogpa5': 0,
	'trogpa4': 1,
	'smashtv': 2, 'smashtv6': 2, 'smashtv5': 2, 'smashtv4': 2, 'smashtv3': 2,
	'hiimpact': 3, 'hiimpact4': 3, 'hiimpact3': 3, 'hiimpact2': 3, 'hiimpact1': 3, 'hiimpactp': 3,
	'shimpact': 4, 'shimpactl1': 4, 'shimpactp6': 4, 'shimpactp5': 4, 'shimpactp4': 4,
	'strkforc': 5, 'saurnfrnt': 5,
	'mkla4': 6, 'mkla3': 6, 'mkla2': 6, 'mkla1': 6,
	'mkprot9': 7, 'mkprot8': 7, 'mkprot4': 7,
	'mkyturbo': 8, 'mkyturboe': 8, 'mknifty': 8, 'mknifty666': 8,
	'term2': 9, 'term2la3': 10, 'term2la2': 11, 'term2la1': 12, 'term2pa2': 12, 'term2lg1': 12,
	'totcarn': 13, 'totcarnp2': 13, 'totcarnp1': 13,
	# Y Unit test ROM: Super High Impact's board (6-bit, 40 MHz, CVSD, its
	# protection, High Impact controls); sound and graphics ROMs never dumped
	'yunittst': 4,
}

# main set of each family (goes in the mra folder, clones in _alternatives)
MAIN_SETS = {'trog', 'trogpa4', 'smashtv', 'hiimpact', 'shimpact', 'strkforc', 'mkla4', 'term2', 'totcarn', 'yunittst'}

FAMILY = {
	'trog': 'Trog', 'smashtv': 'Smash T.V.', 'hiimpact': 'High Impact Football',
	'shimpact': 'Super High Impact', 'strkforc': 'Strike Force', 'mk': 'Mortal Kombat',
	'term2': 'Terminator 2 - Judgment Day', 'totcarn': 'Total Carnage',
}

# joystick bits 4-13: B1-B6, Start, Coin, Test, Pause
def buttons_for(setname, gid):
	if gid in (0, 1):
		b = 'Bone' if gid == 1 else 'Punch'
		return f'{b},-,-,-,-,-,Start,Coin,Test,Pause', 'A,-,-,-,-,-,Start,Select,-,-'
	if gid in (3, 4):
		return 'Action,-,-,-,-,-,Start,Coin,Test,Pause', 'A,-,-,-,-,-,Start,Select,-,-'
	if gid in (2, 13):
		start = 'Start/Bomb' if gid == 13 else 'Start'      # Total Carnage: Start throws a bomb
		return f'Fire Up,Fire Down,Fire Left,Fire Right,-,-,{start},Coin,Test,Pause', 'X,B,Y,A,-,-,Start,Select,-,-'
	if gid == 5:
		return 'Fire,Weapon,Weapon Select,-,-,-,Start/Transform,Coin,Test,Pause', 'A,B,X,-,-,-,Start,Select,-,-'
	if gid in (6, 7, 8):
		# the cabinet's five buttons (one block button; the board's "Block 2"
		# input is left open). The "-" keeps Start, Coin, Test and Pause on
		# the joystick bits every game uses; MiSTer skips it when defining
		# the controls.
		return 'High Punch,Low Punch,High Kick,Low Kick,Block,-,Start,Coin,Test,Pause', 'Y,B,X,A,R,-,Start,Select,-,-'
	return 'Trigger,Bomb,-,-,-,-,Start,Coin,Test,Pause', 'A,B,-,-,-,-,Start,Select,-,-'

CATEGORY = {
	'trog': 'Maze / Collect', 'smashtv': 'Shooter / Multi-directional', 'hiimpact': 'Sports / Football',
	'shimpact': 'Sports / Football', 'strkforc': 'Shooter / Flying', 'mk': 'Fighter / Versus',
	'term2': 'Shooter / Gun', 'totcarn': 'Shooter / Multi-directional',
	'yunittst': 'Utility / Test',
}

DEF_STR = {
	'1C_1C': '1 Coin/1 Credit', '1C_2C': '1 Coin/2 Credits', '1C_3C': '1 Coin/3 Credits',
	'1C_4C': '1 Coin/4 Credits', '1C_5C': '1 Coin/5 Credits', '1C_6C': '1 Coin/6 Credits',
	'2C_1C': '2 Coins/1 Credit', '3C_1C': '3 Coins/1 Credit', '4C_1C': '4 Coins/1 Credit',
	'5C_1C': '5 Coins/1 Credit', 'Free_Play': 'Free Play', 'Coin_A': 'Coin A', 'Coin_B': 'Coin B',
}

def def_str(tok):
	return DEF_STR.get(tok, tok.replace('_', ' '))

def label(s):
	s = s.strip()
	m = re.match(r'DEF_STR\(\s*(\w+)\s*\)', s)
	if m:
		return def_str(m.group(1))
	m = re.match(r'"(.*)"', s)
	return m.group(1) if m else s

# ---------------------------------------------------------------- DIP switches

def parse_inputs(src):
	"""input name -> list of statements (raw lines) in order."""
	ports = {}
	for m in re.finditer(r'static INPUT_PORTS_START\(\s*(\w+)\s*\)(.*?)INPUT_PORTS_END', src, re.S):
		ports[m.group(1)] = m.group(2).split('\n')
	return ports

def dsw_fields(ports, name):
	"""Return the DSW fields of an input definition: list of (mask, default, name, [(value, label)])."""
	fields = []
	cur_port = None
	cur = None
	for line in ports[name]:
		line = line.split('//')[0].strip()
		if not line:
			continue
		m = re.match(r'PORT_INCLUDE\(\s*(\w+)\s*\)', line)
		if m:
			fields = dsw_fields(ports, m.group(1))
			continue
		m = re.match(r'PORT_(START|MODIFY)\(\s*"(\w+)"\s*\)', line)
		if m:
			cur_port = m.group(2)
			cur = None
			continue
		if cur_port != 'DSW':
			continue
		m = re.match(r'PORT_DIPNAME\(\s*(0x[0-9a-fA-F]+)\s*,\s*(0x[0-9a-fA-F]+)\s*,\s*(.*?)\)\s*(PORT_DIPLOCATION.*)?$', line)
		if m:
			mask = int(m.group(1), 16)
			name = label(m.group(3))
			# several switches share the name "Unknown": tell them apart by
			# their position on the board
			loc = re.search(r'PORT_DIPLOCATION\(\s*"([^"]+)"', m.group(4) or '')
			if name == 'Unknown' and loc:
				name = f'Unknown ({loc.group(1)})'
			# a redefinition replaces whatever overlapped it
			fields = [f for f in fields if not (f[0] & mask)]
			cur = [mask, int(m.group(2), 16), name, []]
			fields.append(cur)
			continue
		m = re.match(r'PORT_DIPSETTING\(\s*(0x[0-9a-fA-F]+)\s*,\s*(.*?)\s*\)\s*(PORT_CONDITION.*)?$', line)
		if m and cur is not None:
			cur[3].append((int(m.group(1), 16), label(m.group(2))))
			continue
	return fields

# MiSTer entries added to the OSD DIP Switches menu with the board's own
# switches (the menu and each switch's settings are in alphabetical order),
# in DIP bits 16-19 (default 0; see Arcade-Midway-Y-Unit.sv):
# Service Credit and Tilt are buttons (each selection flips the bit, which
# the core takes as one press, so both values read "Press"); Terminator 2
# also gets its gun control and crosshair settings.
def mister_dips(gid):
	d = [('16', 'Service Credit', 'Press,Press'), ('17', 'Tilt', 'Press,Press')]
	if gid in (9, 10, 11, 12):
		d += [('18', 'Gun Control', 'Joystick,Mouse'), ('19', 'Crosshair', 'On,Off')]
	return d

def natural_key(text):
	"""A to Z, the numbers in a name by value ("2 Players" before "10 ...")."""
	return [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', text.casefold())]

def dip_xml(bits, name, sets):
	"""A <dip> line; sets: [(value, label)] put in alphabetical order (the
	values attribute keeps each label on its own value)."""
	sets = sorted(sets, key=lambda s: natural_key(s[1]))
	ids = ','.join(lb.replace(',', ' ') for _, lb in sets)
	vals = [v for v, _ in sets]
	valattr = '' if vals == list(range(len(sets))) else f' values="{",".join(str(v) for v in vals)}"'
	return f'\t\t<dip bits="{bits}" name={quoteattr(name)} ids={quoteattr(ids)}{valattr}/>'

def switches_xml(fields, extra=()):
	default = 0xFFFF
	for mask, dflt, name, sets in fields:
		default = (default & ~mask) | (dflt & mask)
	lines = [f'\t<switches default="{default & 0xFF:02X},{(default >> 8) & 0xFF:02X},00">']
	dips = []
	for mask, dflt, name, sets in sorted(fields, key=lambda f: (f[0] & -f[0])):
		if name in ('Unused',):
			continue
		lo = (mask & -mask).bit_length() - 1
		hi = mask.bit_length() - 1
		if mask != ((1 << (hi + 1)) - (1 << lo)):
			raise ValueError(f'non-contiguous dip {name} {mask:x}')
		bits = f'{lo}' if lo == hi else f'{lo},{hi}'
		dips.append((name, dip_xml(bits, name, [((v & mask) >> lo, lb) for v, lb in sets])))
	for bits, name, ids in extra:
		dips.append((name, dip_xml(bits, name, list(enumerate(ids.split(','))))))
	# the OSD lists the switches and each one's settings in the MRA's order:
	# both alphabetical (the bits and values say where each is)
	lines += [d for _, d in sorted(dips, key=lambda d: natural_key(d[0]))]
	lines.append('\t</switches>')
	return '\n'.join(lines)

# ---------------------------------------------------------------- ROM parts

class Parts:
	def __init__(self):
		self.lines = []
		self.pos = 0
	def fill(self, n):
		if n > 0:
			self.lines.append(f'\t\t<part repeat="0x{n:X}">00</part>')
			self.pos += n
	def file(self, ld, comment=None):
		self.lines.append(f'\t\t<part crc="{ld["crc"]}" name="{ld["file"]}"/>')
		self.pos += ld['size']
	def pair(self, lo, hi):
		self.lines.append('\t\t<interleave output="16">')
		self.lines.append(f'\t\t\t<part crc="{lo["crc"]}" name="{lo["file"]}" map="01"/>')
		self.lines.append(f'\t\t\t<part crc="{hi["crc"]}" name="{hi["file"]}" map="10"/>')
		self.lines.append('\t\t</interleave>')
		self.pos += lo['size'] * 2
	def comment(self, text):
		self.lines.append(f'\t\t<!-- {text} -->')

def rom_parts(regions, adpcm):
	p = Parts()
	order = ['maindata', 'gfx', 'cvsd:cpu' if not adpcm else 'adpcm:cpu']
	if adpcm:
		order.append('adpcm:oki')
	byname = {r['name']: r for r in regions}
	for ri, rname in enumerate(order):
		reg = byname[rname]
		base, mbase, win = REGION_BASE[rname]
		assert p.pos == base, (rname, hex(p.pos), hex(base))
		p.comment({'maindata': 'program ROM', 'gfx': 'graphics', 'cvsd:cpu': 'sound CPU',
		           'adpcm:cpu': 'sound CPU', 'adpcm:oki': 'OKI samples'}[rname])
		loads = [l for l in reg['loads'] if l['offset'] >= mbase]
		loads.sort(key=lambda l: (l['offset'] & ~1, l['offset'] & 1))
		i = 0
		while i < len(loads):
			ld = loads[i]
			off = ld['offset'] - mbase
			if ld['byte16']:
				hi = loads[i + 1]
				assert hi['byte16'] and hi['offset'] == ld['offset'] + 1 and hi['size'] == ld['size']
				p.fill(base + off - p.pos)
				p.pair(ld, hi)
				i += 2
			else:
				assert base + off >= p.pos, ('overlap', ld)
				p.fill(base + off - p.pos)
				p.file(ld)
				i += 1
		# the last region is not padded (shorter download), except one with no
		# dumped ROM at all, which MAME reads as zeros: the core must too
		last = (ri == len(order) - 1)
		if not last or not loads:
			p.fill(base + win - p.pos)
	return p

# ---------------------------------------------------------------- MRA loader (port of Main_MiSTer)

def mister_load(mra_xml, src, index='0'):
	"""Load one <rom> element the way Main_MiSTer's support/arcade/mra_loader.cpp
	does and return (image sent to the core, md5 hex string).

	Two details matter for the md5 attribute:
	- the md5 covers the ROM data in the order it is read (each part, each
	  repeat), BEFORE interleaving, not the assembled image;
	- a mismatch is not just a warning: the loader then does not send the
	  ROM to the core at all.
	Interleaving follows rom_data(): a part's map is a hex number, one nibble
	per output byte starting with the lowest; a non-zero nibble k sends the
	part's next byte to output byte (k - 1) of the unit, after skipping the
	unit's leading zero nibbles.
	"""
	import xml.etree.ElementTree as ET
	root = ET.fromstring(mra_xml)
	rom = [r for r in root.findall('rom') if r.get('index') == index][0]
	md5 = hashlib.md5()
	data = bytearray()
	romlen = [0] * 8
	st = {'unitlen': 1}

	def rom_data(buf, mapv):
		md5.update(buf)
		unitlen = st['unitlen']
		if not mapv:
			mapv = 1
		idx, m = 0, mapv
		for _ in range(unitlen):
			if m & 0xF:
				break
			m >>= 4
			idx += 1
		if idx >= unitlen:
			raise ValueError('illegal map')
		offsets, first, gaps, m = [], True, 0, mapv
		for _ in range(unitlen):
			if m & 0xF:
				offsets.append(idx + (m & 0xF) - 1 + gaps)
				first = False
			elif not first:
				gaps += 1
			m >>= 4
		# the C loop writes len(offsets) bytes per unit; done here with slices
		k = len(offsets)
		units = len(buf) // k
		assert units * k == len(buf), 'part length is not a whole number of units'
		base = romlen[idx]
		need = base + units * unitlen
		if need > len(data):
			data.extend(bytes(need - len(data)))
		for j, o in enumerate(offsets):
			data[base + o:base + o + units * unitlen:unitlen] = buf[j::k]
		romlen[idx] += units * unitlen

	def part(el, mapv):
		repeat = int(el.get('repeat', '1'), 0)
		if el.get('name'):
			buf = src.get(el.get('crc'))
		else:
			buf = bytes.fromhex(''.join((el.text or '').split()))
		for _ in range(repeat):
			rom_data(buf, mapv)

	for el in rom:
		if el.tag == 'part':
			part(el, 0)
		elif el.tag == 'interleave':
			unit = int(el.get('output')) // int(el.get('input', '8'))
			st['unitlen'] = unit
			for i in range(1, 8):
				romlen[i] = romlen[0]
			for p_el in el:
				part(p_el, int(p_el.get('map', '0'), 16))
			st['unitlen'] = 1
	return bytes(data[:romlen[0]]), md5.hexdigest()

# ---------------------------------------------------------------- GAME list

def parse_games(src):
	games = []
	for m in re.finditer(r'^GAME\(\s*(\w+|\d+\?)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*([\w|]+)\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"', src, re.M):
		games.append({'year': m.group(1), 'name': m.group(2), 'parent': m.group(3), 'machine': m.group(4),
		              'input': m.group(5), 'company': m.group(9), 'full': m.group(10)})
	return games

def family_of(g, bynm):
	root = g['name'] if g['parent'] == '0' else g['parent']
	if root == 'mk':
		return 'mk'
	return root

def safe_filename(s):
	return s.replace('/', '-').replace(':', ' -').replace('?', '').replace('"', '')

def safe_dirname(s):
	# Windows drops a trailing dot or space from a folder name ("_Smash T.V.")
	s = safe_filename(s)
	t = s.rstrip('. ')
	return t + '_' * (len(s) - len(t))

def rom1_lines(gid, name, prog):
	"""ROM index 1: the game id, and for Mortal Kombat, High Impact and
	Super High Impact the words of tools/yunit_fmoves.py (finishing moves,
	the Hidden Items page's state word, Reptile's program patches)."""
	data, notes = yunit_fmoves.build(gid, name, prog)
	if not any(data[2:]):
		return [f'\t<rom index="1">\n\t\t<part>{gid:02X}</part>\n\t</rom>']
	out = ['\t<rom index="1">']
	out.append('\t\t<!-- game id; ' + escape('; '.join(notes)) + ' (tools/yunit_fmoves.py) -->')
	out.append('\t\t<part>')
	for i in range(0, len(data), 32):
		out.append('\t\t' + ' '.join('%02X' % b for b in data[i:i + 32]))
	out.append('\t\t</part>')
	out.append('\t</rom>')
	return out

def main():
	drv, outdir = sys.argv[1], sys.argv[2]
	zips = sys.argv[3:]
	src_text = open(drv, encoding='utf-8', errors='replace').read()
	romdefs = parse_driver(drv)
	ports = parse_inputs(src_text)
	games = parse_games(src_text)
	bynm = {g['name']: g for g in games}
	src = RomSource(zips) if zips else None
	stamp = datetime.date.today().strftime('%Y%m%d')
	report = []

	for g in games:
		name = g['name']
		if name not in GAME_ID:
			continue
		gid = GAME_ID[name]
		regs = romdefs[name]
		adpcm = any(r['name'].startswith('adpcm') for r in regs)
		parts = rom_parts(regs, adpcm)
		fam = family_of(g, bynm)
		parent = g['parent'] if g['parent'] != '0' else None
		zipattr = f'{name}.zip' + (f'|{parent}.zip' if parent else '')

		# region image when the ROMs are at hand (the md5 itself comes from
		# loading the finished MRA the way Main_MiSTer does, below)
		md5 = 'None'
		verified = False
		if src:
			try:
				img = build_image(regs, src, adpcm)
				img = img[:parts.pos]
				verified = True
			except KeyError:
				pass

		names, defaults = buttons_for(name, gid)
		players = 4 if gid in (0, 1, 3, 4) else 2
		fields = dsw_fields(ports, g['input'])
		mra = []
		mra.append('<misterromdescription>')
		mra.append(f'\t<name>{escape(g["full"])}</name>')
		mra.append(f'\t<mratimestamp>{stamp}</mratimestamp>')
		mra.append(f'\t<mameversion>{MAMEVERSION}</mameversion>')
		mra.append(f'\t<setname>{name}</setname>')
		mra.append(f'\t<year>{g["year"]}</year>')
		mra.append(f'\t<manufacturer>{escape(g["company"])}</manufacturer>')
		mra.append(f'\t<category>{escape(CATEGORY[fam])}</category>')
		mra.append(f'\t<rbf>{RBF}</rbf>')
		mra.append(f'\t<remark>{players} players</remark>')
		mra.append(switches_xml(fields, mister_dips(gid)))
		mra.append(f'\t<buttons names="{names}" default="{defaults}"/>')
		mra.append('\t<romstruct>')
		mra.append('0x000000 program ROM (1 MB, 16-bit little endian)')
		mra.append('0x100000 graphics ROM (8 MB, MAME gfx region)')
		mra.append('0x900000 sound CPU ROM (MAME region from 0x10000)')
		if adpcm:
			mra.append('0xA00000 OKI M6295 samples (1 MB)')
		mra.append('\t</romstruct>')
		mra.extend(rom1_lines(gid, name, img[:0x100000] if verified else None))
		mra.append(f'\t<rom index="0" zip="{zipattr}" md5="{md5}" type="merged">')
		mra.extend(parts.lines)
		mra.append('\t</rom>')
		mra.append('\t<nvram index="2" size="32768"/>')
		mra.append('</misterromdescription>')
		xml = '\n'.join(mra) + '\n'

		if verified:
			asm, md5 = mister_load(xml, src)
			assert asm == img, f'{name}: MRA assembly differs from the region image'
			xml = xml.replace('md5="None"', f'md5="{md5}"', 1)

		title = safe_filename(g['full'])
		if name in MAIN_SETS:
			path = os.path.join(outdir, f'{title}.mra')
		else:
			path = os.path.join(outdir, '_alternatives', '_' + safe_dirname(FAMILY[fam]), f'{title}.mra')
		os.makedirs(os.path.dirname(path), exist_ok=True)
		open(path, 'w', newline='\n').write(xml)
		report.append((name, path, 'verified' if verified else 'unverified', md5))

	for r in report:
		print(f'{r[0]:12s} {r[2]:10s} {r[1]}')

if __name__ == '__main__':
	main()
