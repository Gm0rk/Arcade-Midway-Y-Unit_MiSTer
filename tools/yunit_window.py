#!/usr/bin/env python3
"""
yunit_window.py - the pages of Mortal Kombat's Move List window

With the OSD's "Move List" set to a fighter, rtl/yunit_window.sv draws that
fighter's page over the picture, on the game's title screen dimmed so the
text reads (the T-Unit core's Move List window, Arcade-Midway-T-Unit
tools/tunit_window.py): the fighter's special moves, then the fatality and
The Pit with the distance each needs, in words (Close, Sweep, Jump; tools/
yunit_fmoves.py has the moves and the distances). A page per fighter, in
the Move List option's order.

A page is 30 rows of 56 characters; a row is a list of segments, runs of
text in one colour (the blanks between them are not stored). ROM images
for $readmemh:

    rtl/yunit_window_row.hex   256 x 8 bits, address {page, row}: the row's
                               first segment (0: empty row)
    rtl/yunit_window_seg.hex   256 x 26 bits, a segment: [10:0] its first
                               character in the text ROM, [16:11] its
                               length, [22:17] its column, [24:23] its
                               colour (0 white, 1 yellow, 2 cyan, 3 gray),
                               [25] the row's last segment
    rtl/yunit_window_text.hex  2048 x 7 bits: the character codes - 32
                               (segments with the same text share it)
    rtl/yunit_window_font.hex  96 x 8 rows of 8 bits (bit x: column x),
                               characters 32-127: the MiSTer OSD's font
                               (Main_MiSTer charrom.cpp, GPL-3.0)
    rtl/yunit_window_bg.hex    127 x 200 entries of 5 bits: the background
                               at half the picture's resolution, a palette
                               index each
    rtl/yunit_window_pal.hex   32 x 24 bits: its palette (RGB, already dimmed)

The background comes from a capture of the title screen (--bg; the 4:3
picture is taken from the middle of the image, so a 1920 x 1080 capture
with black bars works as it is): scaled to 200 x 127, dimmed to DIM, 32
colours (median cut, no dither). The capture is not kept in the repo.

Usage:
    yunit_window.py --write             write the text ROM images
    yunit_window.py --bg capture.png    write the background
    yunit_window.py --check             the ROM images against the sources
    yunit_window.py --show [PAGE|all]   print pages as text

Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import yunit_fmoves as fm   # noqa: E402

OUT = {k: os.path.join(REPO, 'rtl', 'yunit_window_%s.hex' % k)
       for k in ('row', 'seg', 'text', 'font', 'bg', 'pal')}

COLS, ROWS = 56, 30
LEFT, RIGHT = 1, 54                 # the columns text uses
PAGES = 8                           # row ROM pages
SEG_SIZE = 256                      # segment ROM entries
TEXT_SIZE = 2048                    # text ROM characters
WHITE, YELLOW, CYAN, GRAY = range(4)
BG_W, BG_H, BG_COLOURS = 200, 127, 32
DIM = 0.30                          # background brightness

# Main_MiSTer charrom.cpp, characters 32-127: 8 bytes each, byte i column i,
# bit b row b (the top row bit 0)
FONT = [
    "0000000000000000 00006F6F00000000 0503000005030000 147F7F147F140000",  #  !"#
    "48DC745C76240000 4C2A166854320000 20744A5E34605000 0000050300000000",  # $%&'
    "00001C3E63410000 41633E1C00000000 082A1C1C2A080000 08083E3E08080000",  # ()*+
    "0000A06000000000 0808080808080000 0000606000000000 6030180C06030000",  # ,-./
    "3E7F415D7F3E0000 00017F7F00000000 717949494F460000 414949497F360000",  # 0123
    "1C1E137F7F100000 4F4F494979310000 3E7F494979310000 0101797D07030000",  # 4567
    "367F49497F360000 464F49497F3E0000 00006C6C00000000 0000AC6C00000000",  # 89:;
    "081C366341000000 0014141414000000 004163361C080000 060751590F060000",  # <=>?
    "3E7F415D5F4E0000 7E7F09097F7E0000 7F7F49497F360000 3E7F414141410000",  # @ABC
    "7F7F41417F3E0000 3E7F494941410000 7E7F090901010000 3E7F41497B7B0000",  # DEFG
    "7F7F08087F7F0000 00007F7F00000000 606040407F3F0000 7F7F081C77630000",  # HIJK
    "3F7F404040400000 7F7F060C067F7F00 7F7F0C187F7F0000 7E7F41417F3F0000",  # LMNO
    "7F7F09090F060000 7E7F41F1FF3F0000 7F7F09097F760000 464F494979310000",  # PQRS
    "01017F7F01010000 3F7F40407F7F0000 1F3F60603F1F0000 7F7F3018307F7F00",  # TUVW
    "63771C1C77630000 070F78780F070000 6171594D47430000 00007F7F41410000",  # XYZ[
    "03060C1830600000 41417F7F00000000 080C0603060C0800 8080808080808000",  # \\]^_
    "0000030500000000 387C44447C7C0000 3F7F44447C380000 387C444444440000",  # `abc
    "387C44447F3F0000 387C54545C580000 00087E7F09010000 98BCA4A4FC780000",  # defg
    "7F7F04047C780000 00007D7D00000000 8080FD7D00000000 7F7F10107C6C0000",  # hijk
    "00007F7F40000000 7C7C0C180C7C7800 7C7C04047C780000 387C44447C380000",  # lmno
    "F8FC44447C380000 387C4444FCF80000 7C7C080404040000 485C545474240000",  # pqrs
    "00043F7F44400000 3C7C40407C7C0000 1C3C60603C1C0000 3C7C6030607C3C00",  # tuvw
    "6C6C10106C6C0000 9CBCA0A0FC7C0000 646454544C4C0000 08083E7741410000",  # xyz{
    "0000777700000000 4141773E08080000 1008081810100800 7F7F7F7F7F7F7F00",  # |}~.
]


def font_rows():
    """96 x 8 row bytes (bit x: column x)"""
    cols = [bytes.fromhex(w) for line in FONT for w in line.split()]
    assert len(cols) == 96, len(cols)
    return [[sum(((c[x] >> y) & 1) << x for x in range(8)) for y in range(8)] for c in cols]


# ----------------------------------------------------------------------------
# Rows: (column, [(text, colour)]) or None
# ----------------------------------------------------------------------------

def row(*segs, col=LEFT):
    return (col, [s for s in segs if s[0]])


def at(*cells):
    """A row from (column, text, colour) cells."""
    segs, k = [], LEFT
    for col, text, colour in cells:
        if col < k:
            raise SystemExit('cells overlap: %r' % (cells,))
        if col > k:
            segs.append((' ' * (col - k), WHITE))
            k = col
        segs.append((text, colour))
        k += len(text)
    return row(*segs)


def width(r):
    return r[0] + sum(len(t) for t, _ in r[1]) - 1 if r else 0


def compose(label, head, body, foot):
    """A page: head, body, blank rows, footer at the bottom."""
    rows = head + body + [None] * (ROWS - len(head) - len(body) - len(foot)) + foot
    if len(rows) > ROWS:
        raise SystemExit('%s: %d rows' % (label, len(rows)))
    for r in rows:
        if r and width(r) > RIGHT:
            raise SystemExit('%s: too wide: %r' % (label, ''.join(t for t, _ in r[1])))
    return (label, rows)


# ----------------------------------------------------------------------------
# Move List
# ----------------------------------------------------------------------------

TITLE = 'MORTAL KOMBAT'
NOTATION = [
    [('F', YELLOW), (' toward the opponent, ', GRAY), ('B', YELLOW), (' away, ', GRAY),
     ('X+Y', YELLOW), (' together', GRAY)],
    [('(X) Y', YELLOW), (' or ', GRAY), ('(X Y)', YELLOW), (': hold X while you enter Y, then let go', GRAY)],
    [('Distance', YELLOW), (': ', GRAY), ('Sweep', YELLOW), (" = a sweep's reach, ", GRAY),
     ('Jump', YELLOW), (' = a jump away', GRAY)],
]
PAUSED = [('The game waits: set ', GRAY), ('Move List', YELLOW), (' to ', GRAY), ('Off', YELLOW),
          (' to play on', GRAY)]


def finish_name(mname, kind):
    return ('Fatality: ' + mname) if kind == fm.K_FATAL else mname


def note_rows(note, col, cmd_col, cmd, name_col):
    """A note after the command when it fits, else under it (or under the name)."""
    if cmd_col + len(cmd) + 2 + len(note) - 1 <= RIGHT:
        return None, (cmd_col + len(cmd) + 2, note, GRAY)
    return at((cmd_col if cmd_col + len(note) - 1 <= RIGHT else name_col + 2, note, GRAY)), None


def pages():
    """[(label, rows)]: a page per fighter, the Move List option's order."""
    fighters = fm.fighters()
    assert [n for n, _, _ in fighters] == [n for n, _, _ in fm.FIGHTERS]
    # one layout for all pages: the commands in one column, the distances
    # right-aligned
    w_name = max(len(m) for sp in fm.SPECIALS for m, _ in sp)
    w_name = max([w_name] + [len(finish_name(m[0], m[1])) for _, _, mv in fighters for m in mv])
    c_cmd = LEFT + w_name + 2
    foot = [row(*PAUSED), None] + [row(*f) for f in NOTATION]
    out = []
    for (name, cid, moves), sp in zip(fighters, fm.SPECIALS):
        head = [at((LEFT, name.upper(), CYAN), (RIGHT + 1 - len(TITLE), TITLE, GRAY)), None,
                at((LEFT, 'SPECIAL MOVES', CYAN), (c_cmd, 'COMMAND', GRAY))]
        body = []
        for m, c in sp:
            cells = [(LEFT, m, WHITE), (c_cmd, c, YELLOW)]
            note = fm.SPECIAL_NOTES.get((name, m))
            under = None
            if note:
                under, after = note_rows(note, LEFT, c_cmd, c, LEFT)
                if after:
                    cells.append(after)
            body.append(at(*cells))
            if under:
                body.append(under)
        body += [None, at((LEFT, 'FINISHING MOVES', CYAN), (c_cmd, 'COMMAND', GRAY),
                         (RIGHT + 1 - len('DISTANCE'), 'DISTANCE', GRAY))]
        for mname, kind, cmd, prog, dmin, dmax in moves:
            d = fm.dist_words(dmin, dmax)
            body.append(at((LEFT, finish_name(mname, kind), WHITE), (c_cmd, cmd, YELLOW),
                           (RIGHT + 1 - len(d), d, GRAY)))
            note = fm.FINISH_NOTES.get((name, mname)) or fm.FINISH_NOTES.get((None, mname))
            if note:
                if c_cmd + len(note) - 1 > RIGHT + 1 - len(d) - 2 and c_cmd + len(note) - 1 > RIGHT:
                    raise SystemExit('%s %s: note too long' % (name, mname))
                body.append(at((c_cmd, note, GRAY)))
        out.append(compose(name, head, body, foot))
    return out


# ----------------------------------------------------------------------------
# ROM images
# ----------------------------------------------------------------------------

def segments(r):
    """a row's runs of text: [(column, text, colour)]"""
    out, k = [], r[0]
    for t, colour in r[1]:
        lead = len(t) - len(t.lstrip(' '))
        if t.strip():
            out.append((k + lead, t.strip(), colour))
        k += len(t)
    return out


def images():
    text, seg, rows, lists = '', [0], [], {}
    pg = pages()
    if len(pg) > PAGES:
        raise SystemExit('%d pages (room for %d)' % (len(pg), PAGES))
    for _, page_rows in pg:
        for r in page_rows + [None] * (32 - ROWS):
            sg = tuple(segments(r)) if r else ()
            if not sg:
                rows.append(0)
                continue
            if sg not in lists:
                lists[sg] = len(seg)
                for n, (col, t, colour) in enumerate(sg):
                    at_ = text.find(t)
                    if at_ < 0:
                        at_ = len(text)
                        text += t
                    seg.append(at_ | (len(t) << 11) | (col << 17) | (colour << 23) | ((n == len(sg) - 1) << 25))
            rows.append(lists[sg])
    rows += [0] * (PAGES * 32 - len(rows))
    if len(seg) > SEG_SIZE or len(text) > TEXT_SIZE:
        raise SystemExit('%d segments (room for %d), %d characters (room for %d)'
                         % (len(seg), SEG_SIZE, len(text), TEXT_SIZE))
    used = (len(pg), len(seg) - 1, len(text))
    seg += [0] * (SEG_SIZE - len(seg))
    codes = [ord(ch) - 32 for ch in text] + [0] * (TEXT_SIZE - len(text))
    font = [b for ch in font_rows() for b in ch]
    return {'row': '\n'.join('%03X' % w for w in rows) + '\n',
            'seg': '\n'.join('%07X' % w for w in seg) + '\n',
            'text': '\n'.join('%02X' % w for w in codes) + '\n',
            'font': '\n'.join('%02X' % w for w in font) + '\n'}, used


def background(path):
    """A title screen as BG_W x BG_H palette indices and BG_COLOURS dimmed colours."""
    from PIL import Image
    im = Image.open(path).convert('RGB')
    w, h = im.size
    pw = min(w, h * 4 // 3)                  # the 4:3 picture in the middle
    im = im.crop(((w - pw) // 2, 0, (w - pw) // 2 + pw, h)).resize((BG_W, BG_H), Image.LANCZOS)
    im = im.point(lambda v: int(v * DIM + 0.5))
    q = im.quantize(colors=BG_COLOURS, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = q.getpalette()[:3 * BG_COLOURS]
    pal += [0] * (3 * BG_COLOURS - len(pal))
    return list(q.tobytes()), [tuple(pal[3 * i:3 * i + 3]) for i in range(BG_COLOURS)]


def write_bg(path):
    idx, pal = background(path)
    open(OUT['bg'], 'w', newline='\n').write(''.join('%02X\n' % v for v in idx))
    open(OUT['pal'], 'w', newline='\n').write(''.join('%02X%02X%02X\n' % c for c in pal))
    print('%s: %d entries, %s: %d colours' % (os.path.relpath(OUT['bg'], REPO), len(idx),
                                               os.path.relpath(OUT['pal'], REPO), len(pal)))


def show(rows):
    print('+' + '-' * COLS + '+')
    for r in rows:
        line = [' '] * COLS
        if r:
            k = r[0]
            for t, _ in r[1]:
                for ch in t:
                    line[k] = ch
                    k += 1
        print('|' + ''.join(line) + '|')
    print('+' + '-' * COLS + '+')


def main():
    a = sys.argv[1:]
    if a in (['--write'], ['--check']):
        img, used = images()
        bad = []
        for k, body in img.items():
            if a == ['--write']:
                open(OUT[k], 'w', newline='\n').write(body)
            elif not os.path.exists(OUT[k]) or open(OUT[k]).read() != body:
                bad.append(os.path.relpath(OUT[k], REPO))
        print('%d pages, %d of %d segments, %d of %d characters'
              % (used[0], used[1], SEG_SIZE - 1, used[2], TEXT_SIZE))
        if a == ['--check']:
            print('ROM images: ' + ('OK' if not bad else 'differ: ' + ', '.join(bad)))
            sys.exit(1 if bad else 0)
    elif a[:1] == ['--bg'] and len(a) == 2:
        write_bg(a[1])
    elif a[:1] == ['--show']:
        which = a[1] if len(a) > 1 else '0'
        for k, (lb, rows) in enumerate(pages()):
            if which == 'all' or which == str(k) or which.lower() in lb.lower():
                print('page %d: %s' % (k, lb))
                show(rows)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
