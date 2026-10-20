#!/usr/bin/env python3
"""
yunit_window.py - the pages of the information window: Mortal Kombat's
Move List and Total Carnage's Passwords

With the OSD's "Move List" On (Mortal Kombat) or "Passwords" on (Total
Carnage), rtl/yunit_window.sv draws the page over the picture, on the game's
title screen dimmed so the text reads. The Move List's two pages are flipped
with a controller's Left or Right while the OSD is closed (rtl/
yunit_listpage.sv), so the pages say so.

Move List (pages 0 and 1): the T-Unit core's pages for MK (Arcade-Midway-
T-Unit tools/tunit_window.py): each fighter's special moves and fatality
with the distance it needs, in words (Close, Sweep, Jump; tools/
yunit_fmoves.py has the moves and the distances), as many fighters to a
page as fit (four, then three), The Pit (the uppercut, which the core does
not enter for you) in the footer, and under the title how to flip the pages
and to leave.

Passwords (page 2): Total Carnage's warp codes. The game checks the code
entered at the warp disc at the start against a list in its program ROM
(rev LA1 FFD719F0, "BOOF++++TOIDGOOBZULU...", FFD696A0 the compare; the
"++++" entries cannot be entered): a match warps there, anything else
costs a life. Each code's destination was checked in MAME 0.289 (code
poked into the entry, 0x010FBAF0-0x010FBB20 letters A = 1, 0x010FBB30 done),
and the entry itself (20-count timer, left stick the arrow, right stick
up / down the letter, END) by playing it.

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
    rtl/yunit_window_bg.hex    2 x 127 x 200 entries of 5 bits: the
                               backgrounds (Mortal Kombat, then Total
                               Carnage) at half the picture's resolution, a
                               palette index each
    rtl/yunit_window_pal.hex   2 x 32 x 24 bits: their palettes (RGB,
                               already dimmed)

A background comes from a capture of the game's title screen (--bg; the
4:3 picture is taken from the middle of the image, so a 1920 x 1080
capture with black bars works as it is): scaled to 200 x 127, dimmed to
DIM (0.30 Mortal Kombat, 0.20 Total Carnage), 32 colours (median cut, no
dither). The captures are not kept in the
repo; --bg replaces one game's half of the two files.

Usage:
    yunit_window.py --write                 write the text ROM images
    yunit_window.py --bg mk|tc capture.png  write that game's background
    yunit_window.py --check                 the ROM images against the sources
    yunit_window.py --show [PAGE|all]       print pages as text

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
BG_GAMES = ['mk', 'tc']             # the backgrounds, in ROM order (yunit_window.sv input bg)
DIM = {'mk': 0.30, 'tc': 0.20}      # background brightness (Total Carnage's title is brighter)
TC_PAGE = 2                         # Total Carnage's page (the top level's window page)

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


def pit_footer():
    """The Pit, the same for every fighter: in the footer."""
    mname, cmd, dmin, dmax = fm.PIT
    return [(mname, YELLOW), (' (all): %s, %s, %s' % (cmd, fm.dist_words(dmin, dmax).lower(),
                                                       fm.FINISH_NOTES[(None, mname)]), GRAY)]


def special_rows(name, sp, col, cmd_col):
    """A fighter's special moves: name at col, command at cmd_col, a note
    after the command, under it, or under the name."""
    out = []
    for m, c in sp:
        note = fm.SPECIAL_NOTES.get((name, m))
        r = at((col, m, WHITE), (cmd_col, c, YELLOW))
        if note and width(r) + 2 + len(note) <= RIGHT:
            r = at((col, m, WHITE), (cmd_col, c, YELLOW), (cmd_col + len(c) + 2, note, GRAY))
            note = None
        out.append(r)
        if note:
            out.append(at((cmd_col if cmd_col + len(note) - 1 <= RIGHT else col + 2, note, GRAY)))
    return out


def pages():
    """The Move List as the T-Unit core has it for MK: as many fighters to a
    page as fit (the Move List option's order), each with the special moves
    and the fatality; The Pit, the same for all, in the footer. The OSD's
    Move List option names the pages (yunit_fmoves.LIST_PAGES)."""
    foot = [row(*f) for f in NOTATION] + [row(*pit_footer())]
    fighters = [(n, moves) for n, _, moves in fm.fighters()]
    c_name = LEFT + 2
    w_name = max(len(m) for sp in fm.SPECIALS for m, _ in sp)
    w_name = max([w_name] + [len('Fatality: ' + m[0]) for _, fat in fighters for m in fat])
    c_cmd = c_name + w_name + 2
    dists = [fm.dist_words(m[3], m[4]) for _, fat in fighters for m in fat]
    c_dist = RIGHT + 1 - max(max(len(d) for d in dists), len('DISTANCE'))
    blocks = []
    for (name, fat), sp in zip(fighters, fm.SPECIALS):
        b = [row((name.upper(), CYAN))] + special_rows(name, sp, c_name, c_cmd)
        for mname, cmd, prog, dmin, dmax in fat:
            b.append(at((c_name, 'Fatality: ' + mname, WHITE), (c_cmd, cmd, YELLOW),
                        (c_dist, fm.dist_words(dmin, dmax), GRAY)))
            note = fm.FINISH_NOTES.get((name, mname))
            if note:
                b.append(at((c_cmd, note, GRAY)))
        blocks.append((name, b))
    room = ROWS - 3 - 1 - len(foot)          # title, hint, header ... blank, footer
    groups, cur = [], []
    for name, b in blocks:
        rows_ = sum(len(x) + 1 for _, x in cur) + len(b)
        if cur and rows_ > room:
            groups.append(cur)
            cur = []
        cur.append((name, b))
    groups.append(cur)
    if len(groups) != fm.LIST_PAGES:
        raise SystemExit('%d pages: set yunit_fmoves.LIST_PAGES and --gen' % len(groups))
    out = []
    for k, g in enumerate(groups):
        body = []
        for name, b in g:
            body += ([None] if body else []) + b
        head = [at((LEFT, 'MOVE LIST' + ('  %d/%d' % (k + 1, len(groups)) if len(groups) > 1 else ''), CYAN),
                   (RIGHT + 1 - len(TITLE), TITLE, GRAY)),
                at((LEFT, 'LEFT/RIGHT', YELLOW), (LEFT + 10, ': other page   ', GRAY),
                   (LEFT + 25, 'OSD > Move List > Off', YELLOW), (LEFT + 46, ': play', GRAY)),
                at((c_name, 'MOVE', GRAY), (c_cmd, 'COMMAND', GRAY), (c_dist, 'DISTANCE', GRAY))]
        out.append(compose(', '.join(n for n, _ in g), head, body, foot))
    return out


# ----------------------------------------------------------------------------
# Passwords (Total Carnage)
# ----------------------------------------------------------------------------

TC_TITLE = 'TOTAL CARNAGE'
TC_HOW = ('At the start of a game walk onto the red and white disc (PASSWORD REQUIRED), '
          'pick YES and press Start. Within 20 seconds: the left stick moves the arrow, '
          'the right stick up or down changes the letter, END enters the code. A wrong '
          'code costs a life.')
# (group, code, where it warps to, note): the game's order; checked in MAME
TC_CODES = [
    ('MISSION 1', 'GOOB', 'The gate', ''),
    ('', 'ZULU', 'The bunker', '+ Weasel Warp Bonus'),
    ('', 'ORCS', 'Past Orcus', '+ Orcus Warp Bonus'),
    ('MISSION 2', 'ROAD', 'The first road', ''),
    ('', 'LIPS', 'The airport gate', ''),
    ('', 'LICK', 'The airfield', ''),
    ('', 'FIRE', 'The hangar', ''),
    ('', 'SHOK', "Akhboob's electric chair", ''),
    ('MISSION 3', 'FOOD', 'The second road', ''),
    ('', 'EATS', 'The mutant transmission', ''),
    ('', 'TOID', 'The road to the factory', ''),
    ('', 'BOOF', 'The reactor', ''),
    ('', 'MARK', 'The reactor basement', ''),
    ('ENDINGS', 'DOME', 'Akhboob escapes', '(no keys)'),
    ('', 'WORM', 'Akhboob is fried', '(no keys)'),
    ('', 'AZAZ', 'The Pleasure Domes', '(500 keys)'),
]
TC_BONUS = [
    ('ZULU', 'Weasel Warp Bonus: 40,000 points, 50 hostages,', '50 flags, 50 gems, 10 keys'),
    ('ORCS', 'Orcus Warp Bonus: 50,000 points, 100 hostages,', '100 flags, 100 gems, 10 keys'),
]
# the codes in the program ROM's list (rev LA1 and the prototypes), in its
# order; --check compares them with TC_CODES
TC_ROM_LIST = 'BOOF++++TOIDGOOBZULUORCSROADLIPSLICKSHOK++++FIREFOODEATS++++MARKDOMEWORMAZAZ'


def tc_page():
    """Total Carnage's warp codes on one page: how to enter one, the codes
    by mission and where each warps to, the two warp bonuses."""
    codes = sorted(TC_ROM_LIST[i:i + 4] for i in range(0, len(TC_ROM_LIST), 4) if '+' not in TC_ROM_LIST[i:i + 4])
    if codes != sorted(c for _, c, _, _ in TC_CODES):
        raise SystemExit('TC_CODES and the ROM list differ')
    c_grp, c_code = LEFT, LEFT + 11
    c_where = c_code + 6
    head = [at((LEFT, 'PASSWORDS', CYAN), (RIGHT + 1 - len(TC_TITLE), TC_TITLE, GRAY)), None]
    import textwrap
    head += [row((t, GRAY)) for t in textwrap.wrap(TC_HOW, RIGHT - LEFT + 1)] + [None]
    head.append(at((c_code, 'CODE', GRAY), (c_where, 'WARPS TO', GRAY)))
    body = []
    for grp, code, where, note in TC_CODES:
        cells = [(c_code, code, YELLOW), (c_where, where, WHITE)]
        if grp:
            cells.insert(0, (c_grp, grp, CYAN))
        if note:
            cells.append((c_where + len(where) + 1, note, GRAY))
        body.append(at(*cells))
    foot = []
    for code, l1, l2 in TC_BONUS:
        foot += [at((LEFT, code, YELLOW), (LEFT + 6, l1, GRAY)), at((LEFT + 6, l2, GRAY))]
    return compose('Passwords', head, body, foot)


def all_pages():
    """Every page in ROM order: the Move List, then the Passwords."""
    pg = pages()
    if len(pg) != TC_PAGE:
        raise SystemExit('Passwords page at %d: set TC_PAGE and the top level' % len(pg))
    return pg + [tc_page()]


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
    pg = all_pages()
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


def background(path, dim):
    """A title screen as BG_W x BG_H palette indices and BG_COLOURS dimmed colours."""
    from PIL import Image
    im = Image.open(path).convert('RGB')
    w, h = im.size
    pw = min(w, h * 4 // 3)                  # the 4:3 picture in the middle
    im = im.crop(((w - pw) // 2, 0, (w - pw) // 2 + pw, h)).resize((BG_W, BG_H), Image.LANCZOS)
    im = im.point(lambda v: int(v * dim + 0.5))
    q = im.quantize(colors=BG_COLOURS, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = q.getpalette()[:3 * BG_COLOURS]
    pal += [0] * (3 * BG_COLOURS - len(pal))
    return list(q.tobytes()), [tuple(pal[3 * i:3 * i + 3]) for i in range(BG_COLOURS)]


def read_hex(path, n, width):
    """A ROM image's entries (missing or short: zeros)."""
    try:
        v = [int(l, 16) for l in open(path) if l.strip()]
    except OSError:
        v = []
    return (v + [0] * n)[:n] if width else v


def write_bg(game, path):
    """Replace one game's background and palette in the two files."""
    k = BG_GAMES.index(game)
    idx, pal = background(path, DIM[game])
    n_bg, n_pal = BG_W * BG_H, BG_COLOURS
    bg = read_hex(OUT['bg'], n_bg * len(BG_GAMES), 1)
    pl = read_hex(OUT['pal'], n_pal * len(BG_GAMES), 1)
    bg[k * n_bg:(k + 1) * n_bg] = idx
    pl[k * n_pal:(k + 1) * n_pal] = [r << 16 | g << 8 | b for r, g, b in pal]
    open(OUT['bg'], 'w', newline='\n').write(''.join('%02X\n' % v for v in bg))
    open(OUT['pal'], 'w', newline='\n').write(''.join('%06X\n' % c for c in pl))
    print('%s background: %s %d entries, %s %d colours' % (game, os.path.relpath(OUT['bg'], REPO), len(bg),
                                                          os.path.relpath(OUT['pal'], REPO), len(pl)))


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
    elif a[:1] == ['--bg'] and len(a) == 3 and a[1] in BG_GAMES:
        write_bg(a[1], a[2])
    elif a[:1] == ['--show']:
        which = a[1] if len(a) > 1 else '0'
        for k, (lb, rows) in enumerate(all_pages()):
            if which == 'all' or which == str(k) or which.lower() in lb.lower():
                print('page %d: %s' % (k, lb))
                show(rows)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
