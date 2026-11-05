#!/usr/bin/env python3
"""Cheats of the Y Unit core: the <cheats> section of the MRA files.

The MRA's <cheats size="8" max="16"> section holds one hex string per cheat
and Main_MiSTer sends the units of every cheat that is switched on to the core
(ROM index 255, see rtl/yunit_cheat.sv). One unit is 8 bytes, four 16-bit
words, each written low byte first:

	word address [15:0]            (the CPU's bit address >> 4)
	bit 15: one-shot write; bits 11:0: word address [27:16]
	data
	mask                           (the bits of the word the cheat controls)

While a cheat is on, the CPU reading that word gets (game word & ~mask) | data.
Words of the program ROM (0xFF800000 and up) are changed for instruction
fetches only. A unit with the one-shot flag writes its data to main RAM once,
when the cheat is switched on.

The tables are in yunit_cheat_data.py: per MAME set, in the order of the
Cheats menu (alphabetical), the cheat's name (25 characters at most, what the
menu line shows) and its units as (word address, data, mask, one-shot,
original ROM word).
"""
import os, sys
from xml.sax.saxutils import quoteattr

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from yunit_cheat_data import CHEATS

UNIT_SIZE = 8
MAX_ACTIVE = 16            # units the engine takes at once (rtl/yunit_cheat.sv: N)
MAX_POKES = 4              # one-shot writes it takes at once (NP)
ROM_BASE_WA = 0xFF800000 >> 4
RAM_WA = range(0x0100000, 0x0110000)
NAME_MAX = 25              # the Cheats menu line shows 25 characters of a name


def unit_hex(wa, data, mask, poke):
	words = (wa & 0xFFFF, ((wa >> 16) & 0x0FFF) | (0x8000 if poke else 0), data & mask, mask)
	return ' '.join('%02X%02X' % (w & 0xFF, w >> 8) for w in words)


def check(setname, prog):
	"""Raises ValueError when a table does not fit the set: a name too long or out of
	alphabetical order, a unit outside RAM and ROM, a ROM unit whose original word is not what the
	program ROM holds (or that changes nothing), a one-shot write into ROM, a
	cheat with more units than the engine takes."""
	names = set()
	prev = None
	for name, units in CHEATS.get(setname, []):
		if len(name) > NAME_MAX:
			raise ValueError(f'{setname}: cheat name "{name}" is longer than {NAME_MAX} characters')
		if name in names:
			raise ValueError(f'{setname}: cheat name "{name}" appears twice')
		names.add(name)
		if prev is not None and name.casefold() < prev.casefold():
			raise ValueError(f'{setname}: cheat "{name}" is not in alphabetical order (after "{prev}")')
		prev = name
		if not units or sum(1 for u in units if not u[3]) > MAX_ACTIVE or sum(1 for u in units if u[3]) > MAX_POKES:
			raise ValueError(f'{setname}: "{name}" has too many units')
		for wa, data, mask, poke, orig in units:
			if data & ~mask:
				raise ValueError(f'{setname}: "{name}": data {data:04X} has bits outside the mask {mask:04X}')
			rom = wa >= ROM_BASE_WA
			if not rom and wa not in RAM_WA:
				raise ValueError(f'{setname}: "{name}": word address {wa:07X} is neither RAM nor program ROM')
			if rom and poke:
				raise ValueError(f'{setname}: "{name}": one-shot write into ROM')
			if rom:
				off = ((wa << 4) - 0xFF800000) // 8
				if orig is None:
					raise ValueError(f'{setname}: "{name}": ROM unit without its original word')
				if prog is not None:
					w = prog[off] | prog[off + 1] << 8
					if w != orig:
						raise ValueError(f'{setname}: "{name}": ROM word {wa:07X} is {w:04X}, the table expects {orig:04X}')
					if (w & ~mask) | data == w:
						raise ValueError(f'{setname}: "{name}": ROM word {wa:07X} already holds {w:04X}')


def mra_lines(setname, prog=None):
	"""The <cheats> section of a set (a list of lines, empty when it has none)."""
	cheats = CHEATS.get(setname)
	if not cheats:
		return []
	check(setname, prog)
	out = [f'\t<cheats size="{UNIT_SIZE}" max="{MAX_ACTIVE}">']
	for name, units in cheats:
		out.append(f'\t\t<cheat name={quoteattr(name)}>')
		for wa, data, mask, poke, orig in units:
			out.append('\t\t\t' + unit_hex(wa, data, mask, poke))
		out.append('\t\t</cheat>')
	out.append('\t</cheats>')
	return out


if __name__ == '__main__':
	for s in sorted(CHEATS):
		print(f'{s:12s} {len(CHEATS[s]):3d} cheats, {sum(len(u) for _, u in CHEATS[s]):3d} units')
