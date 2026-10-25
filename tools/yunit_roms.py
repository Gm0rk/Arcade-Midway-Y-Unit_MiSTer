#!/usr/bin/env python3
"""Y Unit ROM layout: parse MAME's midyunit.cpp ROM definitions and build
the MiSTer download image (the same layout the MRA files describe).

Layout of ROM index 0 (byte addresses):
  0x000000  maindata  1 MB  (16-bit little endian, ROM_LOAD16_BYTE pairs)
  0x100000  gfx       8 MB  (MAME "gfx" region as loaded)
  0x900000  sound CPU       (MAME region from offset 0x10000), 1 MB window
  0xA00000  OKI       1 MB  (ADPCM boards only; the Yawdim bootlegs: up to 2 MB)

The Yawdim bootlegs (Z80 + OKI sound board) name their regions "audiocpu"
(the Z80 program, from offset 0) and "oki" (the sample ROMs, banked).
"""
import re, sys, zipfile, zlib

REGION_BASE = {
    'maindata':  (0x000000, 0x000000, 0x100000),   # (image base, MAME offset of base, window)
    'gfx':       (0x100000, 0x000000, 0x800000),
    'cvsd:cpu':  (0x900000, 0x010000, 0x100000),
    'adpcm:cpu': (0x900000, 0x010000, 0x100000),
    'adpcm:oki': (0xA00000, 0x000000, 0x100000),
    'audiocpu':  (0x900000, 0x000000, 0x100000),   # Yawdim bootlegs
    'oki':       (0xA00000, 0x000000, 0x200000),
}
SOUND_CPU = ('cvsd:cpu', 'adpcm:cpu', 'audiocpu')
OKI = ('adpcm:oki', 'oki')

def parse_driver(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    games = {}
    for m in re.finditer(r'ROM_START\(\s*(\w+)\s*\)(.*?)ROM_END', src, re.S):
        name, body = m.group(1), m.group(2)
        regions = []
        cur = None
        last = None
        filepos = 0
        for line in body.split('\n'):
            line = line.split('//')[0].strip()
            if not line:
                continue
            r = re.match(r'ROM_REGION(16_LE)?\s*\(\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*"([^"]+)"', line)
            if r:
                cur = {'name': r.group(3), 'size': int(r.group(2), 0), 'loads': []}
                regions.append(cur)
                continue
            r = re.match(r'ROM_LOAD(16_BYTE)?\s*\(\s*"([^"]+)"\s*,\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*CRC\(([0-9a-fA-F]+)\)', line)
            if r:
                last = {'file': r.group(2), 'offset': int(r.group(3), 0), 'size': int(r.group(4), 0),
                        'crc': r.group(5).lower(), 'byte16': bool(r.group(1)), 'skip': 0, 'fileoff': 0}
                filepos = last['size']
                cur['loads'].append(dict(last))
                continue
            # MAME: RELOAD reads the file again from its start, CONTINUE goes
            # on where the last load stopped (both put the data at a new offset)
            r = re.match(r'ROM_RELOAD\s*\(\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)', line)
            if r:
                e = dict(last)
                e['offset'] = int(r.group(1), 0)
                e['size'] = int(r.group(2), 0)
                e['reload'] = True
                e['fileoff'] = 0
                filepos = e['size']
                cur['loads'].append(e)
                continue
            r = re.match(r'ROM_CONTINUE\s*\(\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)', line)
            if r:
                e = dict(last)
                e['offset'] = int(r.group(1), 0)
                e['size'] = int(r.group(2), 0)
                e['continued'] = True
                e['fileoff'] = filepos
                filepos += e['size']
                cur['loads'].append(e)
                continue
            # ROM_COPY(region, from, to, length): data already loaded in a
            # region goes to another offset (the Maze bootleg's sound ROM
            # banks). Each piece becomes a load of the same file part, so the
            # image and the MRA need nothing new.
            r = re.match(r'ROM_COPY\s*\(\s*"([^"]+)"\s*,\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)', line)
            if r:
                srcreg = [x for x in regions if x['name'] == r.group(1)]
                s, d, n = int(r.group(2), 0), int(r.group(3), 0), int(r.group(4), 0)
                if not srcreg or any(l['byte16'] for l in srcreg[0]['loads']):
                    cur.setdefault('unsupported', True)
                    continue
                # what the source range holds now: later loads overwrite earlier ones
                segs = []
                for l in srcreg[0]['loads']:
                    a, b = l['offset'], l['offset'] + l['size']
                    keep = []
                    for (sa, sb, sl) in segs:
                        if sb <= a or sa >= b:
                            keep.append((sa, sb, sl))
                            continue
                        if sa < a:
                            keep.append((sa, a, sl))
                        if sb > b:
                            keep.append((b, sb, sl))
                    keep.append((a, b, l))
                    segs = keep
                for (sa, sb, l) in sorted(segs, key=lambda x: x[0]):
                    lo, hi = max(sa, s), min(sb, s + n)
                    if lo >= hi:
                        continue
                    e = dict(l)
                    e['offset'] = d + (lo - s)
                    e['size'] = hi - lo
                    e['fileoff'] = l.get('fileoff', 0) + (lo - l['offset'])
                    e['copied'] = True
                    cur['loads'].append(e)
                continue
            # MAME writes some macros with a space before the bracket
            # ("ROM_RELOAD (" in the T2 and Total Carnage sets): every
            # pattern above allows it. Anything else that moves data is not
            # supported and marks the set.
            if re.match(r'ROM_(COPY|FILL|IGNORE|LOAD16_WORD|LOAD32)', line):
                cur.setdefault('unsupported', True)
        games[name] = regions
    return games

class RomSource:
    """Finds files by CRC in one or more zips (any folder inside the zip)."""
    def __init__(self, zips):
        self.by_crc = {}
        for z in zips:
            zf = zipfile.ZipFile(z)
            for info in zf.infolist():
                self.by_crc.setdefault('%08x' % info.CRC, (zf, info.filename))
    def get(self, crc):
        zf, fn = self.by_crc[crc]
        return zf.read(fn)

def image_size(regions):
    """Length of the image: up to the end of the OKI region (1 MB at least)
    when the set has one, else up to the sound CPU window."""
    for reg in regions:
        if reg['name'] in OKI:
            return 0xA00000 + max(0x100000, reg['size'])
    return 0xA00000

def build_image(regions, src, adpcm):
    img = bytearray(image_size(regions))
    for reg in regions:
        if reg['name'] not in REGION_BASE:
            continue
        base, mbase, win = REGION_BASE[reg['name']]
        for ld in reg['loads']:
            data = src.get(ld['crc'])[ld['fileoff']:ld['fileoff'] + ld['size']]
            off = ld['offset'] - mbase
            if ld['byte16']:
                for i, b in enumerate(data):
                    a = off + 2 * i
                    if 0 <= a < win:
                        img[base + a] = b
            else:
                for i in range(len(data)):
                    a = off + i
                    if 0 <= a < win:
                        img[base + a] = data[i]
    return img

if __name__ == '__main__':
    drv, game, out = sys.argv[1], sys.argv[2], sys.argv[3]
    zips = sys.argv[4:]
    games = parse_driver(drv)
    regs = games[game]
    adpcm = any(r['name'].startswith('adpcm') for r in regs)
    img = build_image(regs, RomSource(zips), adpcm)
    open(out, 'wb').write(img)
    print(game, 'image', hex(len(img)))
