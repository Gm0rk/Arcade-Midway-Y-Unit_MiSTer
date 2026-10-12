#!/usr/bin/env python3
"""Y Unit ROM layout: parse MAME's midyunit.cpp ROM definitions and build
the MiSTer download image (the same layout the MRA files describe).

Layout of ROM index 0 (byte addresses):
  0x000000  maindata  1 MB  (16-bit little endian, ROM_LOAD16_BYTE pairs)
  0x100000  gfx       8 MB  (MAME "gfx" region as loaded)
  0x900000  sound CPU       (MAME region from offset 0x10000), 1 MB window
  0xA00000  OKI       1 MB  (ADPCM boards only)
"""
import re, sys, zipfile, zlib

REGION_BASE = {
    'maindata':  (0x000000, 0x000000, 0x100000),   # (image base, MAME offset of base, window)
    'gfx':       (0x100000, 0x000000, 0x800000),
    'cvsd:cpu':  (0x900000, 0x010000, 0x100000),
    'adpcm:cpu': (0x900000, 0x010000, 0x100000),
    'adpcm:oki': (0xA00000, 0x000000, 0x100000),
}

def parse_driver(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    games = {}
    for m in re.finditer(r'ROM_START\(\s*(\w+)\s*\)(.*?)ROM_END', src, re.S):
        name, body = m.group(1), m.group(2)
        regions = []
        cur = None
        last = None
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
                        'crc': r.group(5).lower(), 'byte16': bool(r.group(1)), 'skip': 0}
                cur['loads'].append(dict(last))
                continue
            r = re.match(r'ROM_RELOAD\s*\(\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*(0x[0-9a-fA-F]+|\d+)', line)
            if r:
                e = dict(last)
                e['offset'] = int(r.group(1), 0)
                e['size'] = int(r.group(2), 0)
                e['reload'] = True
                cur['loads'].append(e)
                continue
            # MAME writes some macros with a space before the bracket
            # ("ROM_RELOAD (" in the T2 and Total Carnage sets): every
            # pattern above allows it. Anything else that moves data is not
            # supported and marks the set.
            if re.match(r'ROM_(CONTINUE|COPY|FILL|IGNORE|LOAD16_WORD|LOAD32)', line):
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

def build_image(regions, src, adpcm):
    img = bytearray((0xB00000 if adpcm else 0xA00000))
    for reg in regions:
        if reg['name'] not in REGION_BASE:
            continue
        base, mbase, win = REGION_BASE[reg['name']]
        for ld in reg['loads']:
            data = src.get(ld['crc'])[:ld['size']]
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
