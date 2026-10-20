#!/usr/bin/env python3
"""
yunit_fmoves.py - Mortal Kombat finishing moves, move list and the per-set
data the core needs for them and for the Hidden Items page's messages

    python3 tools/yunit_fmoves.py --gen                 write the RTL tables
    python3 tools/yunit_fmoves.py --scan <prog.bin>...  addresses found in program ROMs
    python3 tools/yunit_fmoves.py --docs                docs/MortalKombat.md tables

The OSD's "Finishing Moves" page picks a fighter; rtl/yunit_fmoves.sv enters
the fighter's fatality on the winner's controls at the next FINISH HIM it
fits. (The Pit is not entered for you: it is the uppercut, D+HP; the Move
List says so.) The main page's "Move List" option (Off, On) shows the
fighters' special moves and fatalities, with the distance each needs, in a
window over the picture, two pages that the controllers' Left and Right flip
(tools/yunit_window.py makes the pages from the lists here,
rtl/yunit_window.sv draws them, rtl/yunit_listpage.sv flips them). This
script holds the lists and makes from them:

  - rtl/yunit_fmoves_tab.svh: the move records and their programs (the
    controls they press), included by rtl/yunit_fmoves.sv
  - rtl/yunit_fmoves_osd.svh: the Move List option, the Finishing Moves
    page and the core's info messages (CONF_STR lines), included by the
    top level
  - for tools/mra_gen.py, each set's ROM index 1 words (build()): the RAM
    addresses the move player follows, the game state word the Hidden
    Items page's messages look at, and the program patches of the Hidden
    Items page's Reptile options (see "Reptile" below)

The finishing-move player is the T-Unit core's (Arcade-Midway-T-Unit,
rtl/tunit_fmoves.sv, written for MK rev 5.0, the T-Unit port of the same
program) with one change: it measures the distance the way the game does.

Where things are (34010 bit addresses, rev 4.0 / mkla4; every Y Unit set has
the same code, the protos and Nifty Kombat their own addresses):

  round state    @0104D700, 3 = FINISH HIM (set by the finish routine)
  fighters       P1 / P2 character @0104CFB0 / @0104D290, energy @0104D020 /
                 @0104D300, object pointer @0104CF50 / @0104D230, process
                 pointer @0104CF90 / @0104D270
  stage          @0104D540 (3 = The Pit)
  finish flag    @0104D5A0, set when a fatality starts
  dizzy loop     where the loser's process resumes while it reels
                 (process 32-bit word 0xE0), FFDF3660
  stance loop    the same for the finisher standing, FFCE54B0

  The fatality checks (button and direction handlers per character: tables
  at FFD99770 on, one 32-bit pointer per character): FINISH HIM, the
  joystick history matched against a table (FFD9D010: up to six presses,
  most recent first, within 0x30-0x38 frames; two versions for the two
  sides), then the distance, then the opponent standing. The distance is
  |center1 - center2| (FFCECBE0), a fighter's center being its object's x
  (word 0x90) plus the anchor of its current image (image header word 0x20,
  the image pointer at object word 0x160; with the object flipped, bit 4 of
  word 0xE0, the image width (object word 0x120) - 1 - anchor). The bare x
  moves with each image (blocking moves it back 20 pixels, the dizzy
  loser's sway 30), the center does not: the player computes the centers,
  taking the anchor from the CPU's own reads of the image header.

  Limits (center distance), all revisions: Johnny Cage <= 0x48, Kano
  <= 0x68, Sub-Zero <= 0x65, Raiden 0x48-0x88, Scorpion 0x75-0xA0 (proto
  4.0 0x70-0xA0), Sonya and Liu Kang anywhere. (The Pit, not entered by the
  core: the uppercut has to connect, up to 88.) The windows below keep 2
  pixels from each limit.

Each move was played in MAME 0.289 on every Y Unit set at center distances
from the closest the fighters get (about 62) to 300, P1 and P2 the winner:
taken inside the window, not outside it.

Program tokens (also the MAME harness's): "U D F B" tap a direction (F / B
toward / away from the opponent), "HP LP HK LK BL" tap a button, "[X" press
and hold, "]X" let go, "wN" wait N frames, "|" wait until the loser is
dizzy, the finisher stands and the distance fits (programs start here when
they have no "|"). Taps are 3 frames down, 3 up.

Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
"""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# --------------------------------------------------------------------------
# Moves
# --------------------------------------------------------------------------

FAR = 511                        # no upper distance limit

# select screen order: (name, character id, [(osd name, OSD command, program,
# min distance, max distance)])
FIGHTERS = [
    ("Johnny Cage", 0, [("Decapitation", "F F F HP", "[BL F F F ]BL HP", 0, 70)]),
    ("Kano", 1, [("Heart Rip", "B D F LP", "[BL B D F ]BL LP", 0, 102)]),
    ("Sub-Zero", 5, [("Spine Rip", "F D F HP", "[BL F D F ]BL HP", 0, 99)]),
    ("Sonya", 6, [("Kiss of Death", "F F B B BL", "[BL F F B B ]BL BL", 0, FAR)]),
    ("Raiden", 2, [("Electrocution", "F B B B HP", "[BL F B B B ]BL HP", 74, 134)]),
    ("Liu Kang", 3, [("Cartwheel", "D B U F D", "[BL D B U F ]BL D", 0, FAR)]),
    ("Scorpion", 4, [("Fire Breath", "(BL) U U", "[BL U U ]BL", 119, 158)]),
]
# The Pit is not a Finishing Moves entry (it is the uppercut, D+HP, which the
# player does); it is only named in the Move List's footer: (name, command,
# min distance, max distance)
PIT = ("The Pit", "D+HP uppercut", 0, 80)

# Move List window: each fighter's special moves, shown only. Same order as the
# fighters. Found in the move handlers (rev 4.0: per button and direction at
# FFD99770 on, matcher FFD9D010) and the T-Unit core's list for MK 5.0.
# "(BL B F)": Block held over the directions.
SPECIALS = [
    [("Green Bolt", "B F LP"), ("Shadow Kick", "B F LK"), ("Split Punch", "LP+BL")],
    [("Knife Throw", "(BL B F)"), ("Cannonball", "F D B U")],
    [("Freeze", "D F LP"), ("Slide", "B+LP+LK+BL")],
    [("Ring Toss", "LP B LP"), ("Leg Grab", "D+LP+LK+BL"), ("Square Wave", "F B HP")],
    [("Lightning", "D F LP"), ("Teleport", "D U"), ("Torpedo", "B B F")],
    [("Fireball", "F F HP"), ("Flying Kick", "F F HK")],
    [("Spear", "B B LP"), ("Teleport", "D B HP")],
]
SPECIAL_NOTES = {
    ('Sonya', 'Ring Toss'): 'quickly (all within about 0.4 s)',
}
# Move List window: a line under a finishing move (by fighter and move name)
FINISH_NOTES = {
    ('Raiden', 'Electrocution'): 'not when touching',
    (None, 'The Pit'): 'on its stage',
}

# Distances in words (Move List window). The windows are center distances
# (see above); in MAME 0.289 (mkla4, from FINISH HIM states) the fighters
# stand no closer than about 62, and a sweep (B+LK) hits the dizzy loser up
# to 128 and misses at 132 (Johnny Cage, Kano, Scorpion). The zones: Close up
# to 103 (touching to a little apart), Sweep 104-131 (out to a sweep's
# reach), Jump 132-199 (beyond the sweep, within about a jump), Half screen
# 200-259, Full screen 260 or more. The T-Unit core's words, its zones moved
# to the center distance.
DIST_ZONES = [(0, 'Close'), (104, 'Sweep'), (132, 'Jump'), (200, 'Half screen'), (260, 'Full screen')]
DIST_REACH = 8                   # a window names a zone it reaches this far into


def dist_words(dmin, dmax):
    """A move's distance window in words: its zone, 'A to b', 'A or farther'
    or 'Anywhere'."""
    def zone(x):
        return max(k for k, (edge, _) in enumerate(DIST_ZONES) if x >= edge)
    lo = zone(dmin)
    if dmax >= FAR:
        if lo == 0:
            return 'Anywhere'
        return DIST_ZONES[lo][1] + ('' if lo == len(DIST_ZONES) - 1 else ' or farther')
    hi = max(lo, zone(dmax - DIST_REACH))
    if hi == lo:
        return DIST_ZONES[lo][1]
    return DIST_ZONES[lo][1] + ' to ' + DIST_ZONES[hi][1].lower()


def fighters():
    """(name, id, moves) per OSD line: one fatality each."""
    return [(n, c, list(m)) for n, c, m in FIGHTERS]


# --------------------------------------------------------------------------
# Programs
# --------------------------------------------------------------------------

KEYS = {'U': 0, 'D': 1, 'F': 2, 'B': 3, 'HP': 4, 'LP': 5, 'HK': 6, 'LK': 7, 'BL': 8}
OP_END, OP_TAP, OP_PRESS, OP_RELEASE, OP_WAIT, OP_READY = range(6)


def compile_prog(prog):
    """Program text to 16-bit steps: {op[15:13], arg[12:0]}; a tap's arg is
    {length - 1 [12:9], keys [8:0]}."""
    toks = prog.split()
    if '|' not in toks:
        toks = ['|'] + toks
    steps = []
    for t in toks:
        c = t[0]
        if c == '|':
            steps.append(OP_READY << 13)
        elif c == 'w':
            steps.append(OP_WAIT << 13 | int(t[1:]))
        elif c in '[]':
            steps.append((OP_PRESS if c == '[' else OP_RELEASE) << 13 | 1 << KEYS[t[1:]])
        else:
            keys, _, n = t.partition('*')
            m = 0
            for k in keys.split('+'):
                m |= 1 << KEYS[k]
            n = int(n) if n else 3
            steps.append(OP_TAP << 13 | (n - 1) << 9 | m)
    steps.append(OP_END << 13)
    return steps


# --------------------------------------------------------------------------
# Per-set addresses (ROM index 1)
# --------------------------------------------------------------------------

X = None                         # wildcard in a signature


class Prog:
    """The program ROM (1 MB at FF800000) as 16-bit words."""

    def __init__(self, data):
        self.w = struct.unpack('<%dH' % (len(data) // 2), data[:len(data) // 2 * 2])

    def find(self, pat):
        w, n, res = self.w, len(pat), []
        for i in range(len(w) - n):
            if w[i] != pat[0]:
                continue
            if all(p is None or w[i + j] == p for j, p in enumerate(pat)):
                res.append(i)
        return res

    def u32(self, i):
        return self.w[i] | (self.w[i + 1] << 16)


def stance(p):
    """Where a fighter's process resumes in its stance loop:
    MOVI 1,A0 / CALLA sleep / CALLR / JRC / CALLR / BTST 3,A0 / JRNE / BTST 2,A0."""
    h = p.find([0x09C0, 0x0001, 0x0D5F, X, X, 0x0D3F, X, 0xC800, X, 0x0D3F, X, 0x1F80, 0xCB00, X, 0x1FA0])
    return 0xFF800000 + (h[0] + 5) * 16 if len(h) == 1 else None


def mk_addresses(p):
    """The fight variables of an MK program ROM (the T-Unit core's search),
    or None."""
    r = {}
    # MOVE @P2 char,A2 / MOVI 7,A0 / MOVI 8,A1 / CALLA / JREQ / MOVE @P1 char,A2
    h = p.find([0x05A2, X, X, 0x09C0, 0x0007, 0x09C1, 0x0008, 0x0D5F, X, X, X, 0x05A2, X, X])
    # MOVE @..,A0 / JRxx / MOVK 3,A0 / MOVE A0,@state (the finish routine)
    s = sorted(set(p.u32(k + 6) for k in p.find([0x05A0, X, X, X, 0x1860, 0x0580, X, X]) if p.w[k + 3] >> 12 == 0xC))
    # MOVI P1 energy,A0 / MOVI ..,A1 / MOVE @P1 obj,A2,1 / CMP A2,A8 / JREQ / MOVI P2 energy,A0
    e = p.find([0x09E0, X, X, 0x09E1, X, X, 0x07A2, X, X, 0x4848, X, 0x09E0, X, X])
    st = sorted(set(p.u32(k + 1) for k in p.find([0x05A3, X, X, 0x2483, 0x0B23])))
    # the finish routine's wait: MOVI 1,A0 / CALLA sleep / MOVE @flag,A0 / JRNE
    fl = [k for k in p.find([0x09C0, 0x0001, 0x0D5F, X, X, 0x05A0, X, X, X]) if p.w[k + 8] >> 8 == 0xCB]
    if len(h) != 1 or len(s) != 1 or len(e) != 1 or len(st) != 1 or len(fl) != 1:
        return None
    r['p2c'], r['p1c'], r['state'] = p.u32(h[0] + 1), p.u32(h[0] + 12), s[0]
    r['p1e'], r['p1o'], r['p2e'] = p.u32(e[0] + 1), p.u32(e[0] + 7), p.u32(e[0] + 12)
    gap = r['p2e'] - r['p1e']
    r['p2o'] = r['p1o'] + gap
    r['p1p'], r['p2p'] = r['p1o'] + 0x40, r['p1o'] + 0x40 + gap
    r['stage'], r['flag'] = st[0], p.u32(fl[0] + 6)
    # the loser's dizzy loop: MOVI 2,A0 / CALLA sleep / CALLA / MOVE @state,A0 /
    # CMPI 3,A0 / JREQ (resumes after the sleep)
    d = p.find([0x09C0, 0x0002, 0x0D5F, X, X, 0x0D5F, X, X, 0x05A0, r['state'] & 0xFFFF, r['state'] >> 16, 0x0B40, 0xFFFC])
    if len(d) != 1:
        return None
    r['diz'] = 0xFF800000 + (d[0] + 5) * 16
    r['stance'] = stance(p)
    # the object layout of the center routine (FFC7FE60): x 0x80, image
    # pointer 0x160, size 0x120, flags 0xE0, the anchor at image + 0x20
    c = p.find([0x098F, 0x4B00, 0xB701, 0x0160, 0xB702, 0x0120, 0xB504, 0x00E0, 0x0D3F, X, 0xB703, 0x0080])
    a = p.find([0x098F, 0x3000, 0xB626, 0x0020, 0x56E7])
    if not r['stance'] or len(c) != 1 or len(a) != 1:
        return None
    return r


def menu_state(p):
    """The game state word the EJB menu sets to 12: MOVK 0Ch,A0 / MOVE A0,@state."""
    h = p.find([0x1980, 0x0580, X, X])
    return p.u32(h[0] + 2) if len(h) == 1 else None


# Hidden Items page state words (rtl/secret_menu.sv): the menus set them to
# 12. Super High Impact and High Impact keep them at one address in every
# revision (01051360 with the attract page at 01051DC0; 010528A0).
SHI_STATE, SHI_PAGE, HI_STATE = 0x01051360, 0x01051DC0, 0x010528A0

# What --scan found in each set's program ROM (MAME 0.289); mra_gen.py uses
# it when the ROMs are not at hand and checks it when they are.
MK_SETS = {
    'mkla4': ('mkla', 'FFDF3660', 'FFCE54B0'), 'mkla3': ('mkla', 'FFDF3280', 'FFCE51A0'),
    'mkla2': ('mkla', 'FFDECBE0', 'FFCE12E0'), 'mkla1': ('mkla', 'FFDE8200', 'FFCE0EE0'),
    'mkyturbo': ('mkla', 'FFDF3280', 'FFCE51A0'), 'mkyturboe': ('mkla', 'FFDF3280', 'FFCE51A0'),
    'mkprot9': ('proto', 'FFDDBFA0', 'FFCDE780'), 'mkprot8': ('proto', 'FFDD7850', 'FFCDB6E0'),
    'mknifty': ('proto', 'FFDDBFA0', 'FFCDE780'), 'mknifty666': ('proto', 'FFDDBFA0', 'FFCDE780'),
    'mkprot4': ('proto4', 'FFDCCC20', 'FFCD9070'),
}
MK_LAYOUT = {
    # state, p1c, p2c, p1e, p2e, p1o, p2o, p1p, p2p, stage, flag, menu state
    'mkla': (0x0104D700, 0x0104CFB0, 0x0104D290, 0x0104D020, 0x0104D300, 0x0104CF50, 0x0104D230,
             0x0104CF90, 0x0104D270, 0x0104D540, 0x0104D5A0, 0x0104CEB0),
    'proto': (0x0104D6E0, 0x0104CF90, 0x0104D270, 0x0104D000, 0x0104D2E0, 0x0104CF30, 0x0104D210,
              0x0104CF70, 0x0104D250, 0x0104D520, 0x0104D580, 0x0104CE90),
    'proto4': (0x0104D6F0, 0x0104CF90, 0x0104D270, 0x0104D000, 0x0104D2E0, 0x0104CF30, 0x0104D210,
               0x0104CF70, 0x0104D250, 0x0104D520, 0x0104D590, None),
}
VARS = ['state', 'p1c', 'p2c', 'p1e', 'p2e', 'p1o', 'p2o', 'p1p', 'p2p', 'stage', 'flag']


def stored(setname):
    """The stored addresses of an MK set, or None."""
    if setname not in MK_SETS:
        return None
    lay, diz, stc = MK_SETS[setname]
    v = MK_LAYOUT[lay]
    r = dict(zip(VARS, v[:11]))
    r['diz'], r['stance'], r['menu'] = int(diz, 16), int(stc, 16), v[11]
    return r


def scan(prog_bytes):
    """Addresses found in an MK program ROM, or None."""
    p = Prog(prog_bytes)
    r = mk_addresses(p)
    if r:
        r['menu'] = menu_state(p)
    return r


# ROM index 1 (words, little endian), read by the top level:
#   0x00         game id (low byte)
#   0x10-0x2F    finishing moves (rtl/yunit_fmoves.sv, its config words 0-31):
#                  0 format (1), 1 reserved, 2-23 word addresses (bit address
#                  >> 4, low word first) of the round state, P1 and P2
#                  character, energy, object pointer and process pointer, the
#                  stage and the finish flag; 24-25 the dizzy loop, 26-27 the
#                  stance loop (32-bit resume addresses)
#   0x30-0x34    Hidden Items page (rtl/secret_menu.sv): word addresses of
#                the game state and the attract page (0 = none); 1 the set
#                has the hidden menu, 2 it does not (0: no data, older MRAs)
#   0x40-0x5F    Reptile (Mortal Kombat, the sets that have him): 8 program
#                ROM patches of 4 words, {ROM word [15:0]}, {option [10:8],
#                ROM word [18:16]}, new word, original word (option 0: no
#                patch, 1 Reptile Fight Next, 2 Moon Silhouettes Always, 3
#                Reptile Hints Always; rtl/midway_yunit.sv applies them)
#   0x60-0x61    the word address of the Reptile flag (set when his fight
#                starts: Reptile Fight Next is then used up)
# Only as many words as hold data are written (at least up to 0x34).
CFG_FM = 0x10
CFG_SEC = 0x30
CFG_REP = 0x40
CFG_REP_FLAG = 0x60
CFG_WORDS = 0x62
CFG_MIN_WORDS = 0x35

# sets whose program has the hidden menu's code (the others of the family
# show the OSD item, which then says so)
NO_MENU = {'mkprot4', 'shimpactp4', 'shimpactp5', 'shimpactp6', 'hiimpactp', 'yunittst'}
FORMAT = 1


# --------------------------------------------------------------------------
# Reptile (Hidden Items page: Reptile Fight Next, Moon Silhouettes Always,
# Reptile Hints Always)
# --------------------------------------------------------------------------
#
# Rev 3.0, 4.0 and the Turbo hacks have Reptile; the older revisions, the
# prototypes and Nifty Kombo do not. In rev 4.0 (mkla4; rev 3.0 the same
# with other addresses):
#
#   - After each match the player wins, the next-stage routine (FFCB1050)
#     advances the stage (@0104D540, 3 = The Pit) and counts down the
#     Reptile cooldown @0104D6C0 (40 matches after power-up; reloaded with
#     40 when it has reached 0 and the match just won was on The Pit), then
#     calls the Reptile check (FFCB1BE0): one player (FFCA5030), the match
#     just won on The Pit, the cooldown just reloaded, no block pressed
#     (@0104E670), two flawless rounds (@0104D040 / @0104D320), a fatality
#     (@0104D5A0). Carry set: the Reptile fight (FFCB5140, which sets
#     @0104E660 to 1 and counts REPTILE BATTLES, audit 0x24).
#   - The Pit's background (FFCB8820) starts the silhouettes crossing the
#     moon (process FFCB8B80) when the cooldown is 0, outside attract mode:
#     the silhouette is the sign that the check can pass.
#   - Before each round (FFCA11A0) the GREEN NINJA COUNTER (audit 0x10)
#     counts up; at 2000 Reptile drops in with one of nine hints (process
#     FFCA14F0, table FFCA1FA0), and the game clears all the audits (FFE12910,
#     audits 1-0x2C; rev 3.0 FFE12540) and counts REPTILE APPEARANCES (0x23).
#
# The options patch the program as the CPU reads it:
#   Reptile Fight Next      the check returns "yes" right after its
#                           one-player test (SETC, RETS): Reptile comes after
#                           the next match won in a one-player game
#   Moon Silhouettes Always the moon's cooldown test and the check's are
#                           NOPs: the silhouettes cross on every Pit match and
#                           the check needs only its other conditions
#   Reptile Hints Always    the counter's test is a NOP and a jump skips the
#                           audit clearing: a hint before every round
# Turbo 3.1 and 3.0 (hacks) changed the check (no one-player test, Turbo
# 3.0 no cooldown or block test, Turbo 3.1 The Pit or the second stage, no
# flawless rounds); the patches follow what is there. Checked in MAME 0.289
# on mkla4, mkla3, mkyturbo and mkyturboe (work/reptile/rverify.py).

OPT_NEXT, OPT_MOON, OPT_HINT = 1, 2, 3
NOP, SETC, RETS = 0x0300, 0x0DE0, 0x0960


def _find(p, pat, lo=0, hi=None):
    w, n = p.w, len(pat)
    hi = len(w) - n if hi is None else min(hi, len(w) - n)
    return [i for i in range(lo, hi)
            if (pat[0] is None or w[i] == pat[0]) and all(q is None or w[i + j] == q for j, q in enumerate(pat))]


def _s16(v):
    return v - 0x10000 if v & 0x8000 else v


def reptile_scan(p):
    """([(option, ROM word, new, original)], flag address) of an MK program
    ROM, or None (no Reptile)."""
    w = p.w
    out = []
    # the Reptile fight: MMFM SP,A0 / MOVI 24h,A0 / CALLA (REPTILE BATTLES),
    # entered by CALLR check / JRC fight
    chk = setup = None
    for s in _find(p, [0x09AF, 0x0001, 0x09C0, 0x0024, 0x0D5F, X, X]):
        for i in _find(p, [0xC800, X]):
            if i + 2 + _s16(w[i + 1]) == s and w[i - 2] == 0x0D3F:
                chk, setup = i + _s16(w[i - 1]), s
    if chk is None:
        return None
    # check: CALLR one player / MOVE A0,A0 / JREQ (Turbo: NOP) / MOVE @stage,A0 ...
    if not (w[chk] == 0x0D3F and w[chk + 2] == 0x4C00 and (w[chk + 3] >> 8 == 0xCA or w[chk + 3] == NOP)
            and w[chk + 4] == 0x05A0):
        return None
    out += [(OPT_NEXT, chk + 4, SETC, w[chk + 4]), (OPT_NEXT, chk + 5, RETS, w[chk + 5])]
    fl = _find(p, [0x1820, 0x0580, X, X], setup, setup + 80)      # MOVK 1,A0 / MOVE A0,@flag
    if not fl:
        return None
    flag = p.u32(fl[0] + 2)
    # moon: MOVE @state / CMPI 1 / JREQ / MOVE @cooldown / JRNE / MOVI 2000h,A1 / MOVI proc,A7 / CALLA
    m = _find(p, [0x05A0, X, X, 0x0B40, 0xFFFE, X, 0x05A0, X, X, X, 0x09C1, 0x2000, 0x09E7, X, X, 0x0D5F])
    if len(m) != 1 or w[m[0] + 9] >> 8 != 0xCB:
        return None
    out.append((OPT_MOON, m[0] + 9, NOP, w[m[0] + 9]))
    for i in _find(p, [0x05A0, w[m[0] + 7], w[m[0] + 8], 0x0B40, 0xFFD7, X], chk, chk + 40):
        if w[i + 5] >> 8 == 0xCB:                                  # check: CMPI 28h / JRNE
            out.append((OPT_MOON, i + 5, NOP, w[i + 5]))
    # hints: CMPI 7D0h,A1 / JRC / MMFM SP,A0 / MOVE A0,-*A12 / MOVI 10h,A0 / CALLA clear ...
    # MOVI 201Eh,A1 (the hint process)
    h = _find(p, [0x0B41, 0xF82F, X, 0x09AF, 0x0001, 0xA20C, 0x09C0, 0x0010])
    if len(h) != 1 or w[h[0] + 2] >> 8 != 0xC8:
        return None
    out.append((OPT_HINT, h[0] + 2, NOP, w[h[0] + 2]))
    t = _find(p, [0x09C1, 0x201E], h[0] + 6, h[0] + 30)
    disp = t[0] - (h[0] + 7) if len(t) == 1 else 0
    if not 0 < disp < 0x80:
        return None
    out.append((OPT_HINT, h[0] + 6, 0xC000 | disp, w[h[0] + 6]))   # JR over the clearing
    return out, flag


# What reptile_scan finds in each set (MAME 0.289), used when the ROMs are not
# at hand: "option:ROM word=new:original ..." and the flag address
REP_SETS = {
    'mkla4': ('1:04B1C2=0DE0:05A0 1:04B1C3=0960:D540 2:04B88B=0300:CB08 2:04B1CD=0300:CB1A '
              '3:04A130=0300:C81D 3:04A134=C009:09C0', 0x0104E660),
    'mkla3': ('1:04B1A2=0DE0:05A0 1:04B1A3=0960:D540 2:04B86B=0300:CB08 2:04B1AD=0300:CB1A '
              '3:04A11C=0300:C81D 3:04A120=C009:09C0', 0x0104E660),
    'mkyturbo': ('1:04B1A2=0DE0:05A0 1:04B1A3=0960:D540 2:04B86B=0300:CB08 '
                 '3:04A11C=0300:C81D 3:04A120=C009:09C0', 0x0104E660),
    'mkyturboe': ('1:04B1A2=0DE0:05A0 1:04B1A3=0960:D540 2:04B86B=0300:CB08 '
                  '3:04A11C=0300:C81D 3:04A120=C009:09C0', 0x0104E660),
}


def reptile_stored(setname):
    if setname not in REP_SETS:
        return None
    txt, flag = REP_SETS[setname]
    out = []
    for t in txt.split():
        o, rest = t.split(':', 1)
        a, nw = rest.split('=')
        n, v = nw.split(':')
        out.append((int(o), int(a, 16), int(n, 16), int(v, 16)))
    return out, flag


def build(gid, setname, prog_bytes=None):
    """ROM index 1 words (bytes) and notes. gid: the MRA game id (6-8 MK, 3
    High Impact, 4 Super High Impact)."""
    w = [0] * CFG_WORDS
    w[0] = gid
    notes = []
    sec, page = None, None
    if gid in (6, 7, 8):
        r = stored(setname)
        if prog_bytes is not None:
            s = scan(prog_bytes)
            if r and s and any(s[k] != r[k] for k in VARS + ['diz', 'stance', 'menu']):
                raise ValueError('%s: ROM addresses differ from the stored ones' % setname)
            r = r or s
        if r:
            w[CFG_FM] = FORMAT
            for n, k in enumerate(VARS):
                a = r[k] >> 4
                w[CFG_FM + 2 + 2 * n], w[CFG_FM + 3 + 2 * n] = a & 0xFFFF, a >> 16
            for n, k in enumerate(['diz', 'stance']):
                w[CFG_FM + 24 + 2 * n], w[CFG_FM + 25 + 2 * n] = r[k] & 0xFFFF, r[k] >> 16
            notes.append('finishing moves: round state %08X, P1 character %08X, object pointer %08X'
                         % (r['state'], r['p1c'], r['p1o']))
            sec = r['menu']
    elif gid == 4:
        sec, page = SHI_STATE, SHI_PAGE
    elif gid == 3:
        sec = HI_STATE
    if gid in (6, 7, 8):
        rp = reptile_stored(setname)
        if prog_bytes is not None:
            sc = reptile_scan(Prog(prog_bytes))
            if rp != sc and not (rp is None and sc is None):
                raise ValueError('%s: Reptile patches differ from the stored ones' % setname)
        if rp:
            patches, flag = rp
            for n, (o, a, nw, v) in enumerate(patches):
                w[CFG_REP + 4 * n:CFG_REP + 4 * n + 4] = [a & 0xFFFF, o << 8 | a >> 16, nw, v]
            w[CFG_REP_FLAG], w[CFG_REP_FLAG + 1] = (flag >> 4) & 0xFFFF, flag >> 20
            notes.append('Reptile: %d program patches, flag %08X' % (len(patches), flag))
    if gid in (3, 4, 6, 7, 8):
        if setname in NO_MENU:
            w[CFG_SEC + 4] = 2
            notes.append('no hidden menu')
        elif sec:
            w[CFG_SEC], w[CFG_SEC + 1] = (sec >> 4) & 0xFFFF, sec >> 20
            if page:
                w[CFG_SEC + 2], w[CFG_SEC + 3] = (page >> 4) & 0xFFFF, page >> 20
            w[CFG_SEC + 4] = 1
            notes.append('game state %08X' % sec)
    n = max([CFG_MIN_WORDS] + [i + 1 for i, v in enumerate(w) if v])
    return struct.pack('<%dH' % n, *w[:n]), notes


# --------------------------------------------------------------------------
# Messages (OSD info, CONF_STR "I" line; numbers 1-31)
# --------------------------------------------------------------------------

MESSAGES = [
    ('SET', "Finishing move set: it plays\nat the next FINISH HIM"),
    ('NOT_THIS', "Not this fighter's FINISH HIM:\nthe move waits for a later one"),
    ('FAR', "Too far: step closer"),
    ('CLOSE', "Too close: step back"),
    ('OVER', "FINISH HIM is over: the move\nwaits for the next one"),
    ('NOT_TAKEN', "Move not taken"),
    ('CLEARED', "Finishing move cleared"),
    ('EJB_OK', "EJB Menu: code entered"),
    ('OCTO_OK', "Octopus Bookkeeping:\ncode entered"),
    ('CODE_FAIL', "Code not taken: try again"),
    ('WHEN_ATTRACT', "Not now: the code works in\nthe attract mode"),
    ('WHEN_SHI', "Not now: the code works while\nthe attract mode shows\nHIGHEST PAID SUPERSTARS"),
    ('NOT_HERE', "Not in this revision\nof the game"),
    ('REPT_SET', "Reptile fight set: win a match\nin a 1-player game"),
    ('REPT_CLEARED', "Reptile fight cleared"),
]

N_FM_MESSAGES = 7                # the move player's (rtl/yunit_fmoves.sv)

# OSD status bits (top level)
SEL_BITS = (30, 28)              # O[30:28] fighter
SLOT_BIT = 32                    # R[32] + slot: the fighter's moves
CLEAR_BIT = 40                   # R[40]: clear the set move
LIST_BIT = 41                    # O[41] Move List: Off, On
LIST_PAGES = 2                   # tools/yunit_window.py's pages (it checks)
MASK_SEL = 8                     # status_menumask bits 8-10: the page's fighter
PAGE_FM = 'P3'


def sv_str(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


def sel_prefix(li):
    """Hide prefixes that show a line only for fighter li (menu mask bits
    8-10 = the Fighter option)."""
    pre = ''
    for b in range(3):
        pre += ('h' if li >> b & 1 else 'H') + '0123456789ABCDEF'[MASK_SEL + b]
    return pre


def label(name, cmd):
    s = '%-12s %s' % (name, cmd) if cmd else name
    if len(s) > 27 or ',' in s or ';' in s:
        raise ValueError('label too long or with , / ;: ' + s)
    return s


def osd_lines():
    """CONF_STR lines: the main page's Move List option and Finishing Moves
    entry, the Finishing Moves page, and the I line."""
    names = ','.join(n for n, _, _ in FIGHTERS)
    fopt = 'O[%d:%d],Fighter,%s;' % (SEL_BITS[0], SEL_BITS[1], names)
    out = []
    out.append('H5O[%d],Move List,Off,On;' % LIST_BIT)
    out.append('H5%s,Finishing Moves;' % PAGE_FM)
    out.append('%s-;' % PAGE_FM)
    out.append(PAGE_FM + fopt)
    out.append('%s-;' % PAGE_FM)
    for li, (name, cid, moves) in enumerate(fighters()):
        pre = sel_prefix(li)
        for slot, (mname, cmd, prog, dmin, dmax) in enumerate(moves):
            out.append('%s%sR[%d],%s;' % (pre, PAGE_FM, SLOT_BIT + slot, label(mname, cmd)))
    out.append('%s-;' % PAGE_FM)
    out.append('%sR[%d],Clear the set move;' % (PAGE_FM, CLEAR_BIT))
    out.append('%s-;' % PAGE_FM)
    out.append('%s-,The move plays at the;' % PAGE_FM)
    out.append('%s-,winner\'s FINISH HIM;' % PAGE_FM)
    info = 'I,' + ','.join(m for _, m in MESSAGES) + ';'
    return out, info


# --------------------------------------------------------------------------
# Generated files
# --------------------------------------------------------------------------

def tables():
    """Move records and steps: records[(line, slot)] and the step list."""
    steps, recs = [], {}
    for li, (name, cid, moves) in enumerate(fighters()):
        for slot, (mname, cmd, prog, dmin, dmax) in enumerate(moves):
            recs[(li, slot)] = dict(char=cid, dmin=dmin, dmax=dmax, start=len(steps),
                                    name='%s: %s' % (name, mname))
            steps += compile_prog(prog)
    return recs, steps


HEADER = '// Copyright (C) 2026 Gm0rk - GPL-3.0-or-later'


def gen_tab():
    recs, steps = tables()
    o = []
    o.append('// yunit_fmoves_tab.svh - finishing moves: records and programs')
    o.append('// Generated by tools/yunit_fmoves.py --gen; do not edit.')
    o.append('//')
    o.append('// fm_rec({line, slot}): {valid, character[2:0], min distance[8:0],')
    o.append('//   max distance[8:0], first step[7:0]}')
    o.append('// fm_step(n): {op[2:0], arg[12:0]} (rtl/yunit_fmoves.sv)')
    o.append('//')
    o.append(HEADER)
    o.append('')
    o.append('function automatic [29:0] fm_rec(input [5:0] id);')
    o.append('\tcase (id)')
    for (li, slot), r in sorted(recs.items()):
        idv = li << 3 | slot
        o.append("\t\t6'h%02X: fm_rec = {1'b1, 3'd%d, 9'd%d, 9'd%d, 8'd%d};   // %s"
                 % (idv, r['char'], r['dmin'], r['dmax'], r['start'], r['name']))
    o.append("\t\tdefault: fm_rec = 30'd0;")
    o.append('\tendcase')
    o.append('endfunction')
    o.append('')
    o.append('// %d steps' % len(steps))
    o.append('')
    o.append('function automatic [15:0] fm_step(input [7:0] n);')
    o.append('\tcase (n)')
    for i, s in enumerate(steps):
        o.append("\t\t8'd%d: fm_step = 16'h%04X;" % (i, s))
    o.append("\t\tdefault: fm_step = 16'h0000;")
    o.append('\tendcase')
    o.append('endfunction')
    o.append('')
    o.append('// the move player\'s messages (CONF_STR I line)')
    for n, (k, m) in enumerate(MESSAGES[:N_FM_MESSAGES]):
        o.append("localparam [4:0] MSG_%s = 5'd%d;" % (k, n + 1))
    return '\n'.join(o) + '\n'


def gen_osd():
    lines, info = osd_lines()
    o = []
    o.append('// yunit_fmoves_osd.svh - the Move List option, the Finishing Moves page,')
    o.append('// the info messages')
    o.append('// Generated by tools/yunit_fmoves.py --gen; do not edit.')
    o.append('//')
    o.append(HEADER)
    o.append('')
    o.append('`define FMOVES_MENU \\')
    o.append('\t"%s", \\' % sv_str(lines[0]))
    o.append('\t"%s"' % sv_str(lines[1]))
    o.append('')
    o.append('`define FMOVES_PAGES \\')
    for l in lines[2:]:
        o.append('\t"%s", \\' % sv_str(l))
    o[-1] = o[-1].rstrip(' \\').rstrip(',')
    o.append('')
    o.append('`define CORE_INFO "%s"' % sv_str(info))
    o.append('')
    o.append('// message numbers (the I line\'s fields)')
    for n, (k, m) in enumerate(MESSAGES):
        o.append("localparam [4:0] MSG_%s = 5'd%d;" % (k, n + 1))
    return '\n'.join(o) + '\n'


def docs():
    """The finishing move and move list tables of docs/MortalKombat.md."""
    def dist(dmin, dmax):
        if dmin == 0 and dmax >= FAR:
            return 'any'
        if dmin == 0:
            return 'close (up to %d)' % dmax
        return '%d-%d' % (dmin, dmax)
    o = ['| Fighter | Move | Command | Distance |', '|---|---|---|---|']
    for name, cid, moves in FIGHTERS:
        for n, (mname, cmd, prog, dmin, dmax) in enumerate(moves):
            o.append('| %s | %s | %s | %s |' % (name if n == 0 else '', mname, cmd, dist(dmin, dmax)))
    o.append('')
    # the Move List window's pages (tools/yunit_window.py) as a table
    o.append('| Fighter | Move | Command | Distance |')
    o.append('|---|---|---|---|')
    for (name, _, fat), moves in zip(FIGHTERS, SPECIALS):
        rows = []
        for mname, cmd in moves:
            note = SPECIAL_NOTES.get((name, mname))
            rows.append((mname, cmd + (', ' + note if note else ''), ''))
        for mname, cmd, prog, dmin, dmax in fat:
            note = FINISH_NOTES.get((name, mname))
            rows.append(('Fatality: ' + mname, cmd, dist_words(dmin, dmax) + (', ' + note if note else '')))
        for n, r in enumerate(rows):
            o.append('| %s | %s | %s | %s |' % ((name if n == 0 else '',) + r))
    o.append('')
    mname, cmd, dmin, dmax = PIT
    o.append('Every fighter, on %s stage only: an uppercut (D+HP), %s. The core does not enter it.' % (
        mname, dist_words(dmin, dmax).lower()))
    return '\n'.join(o)


def main():
    a = sys.argv[1:]
    if a and a[0] == '--gen':
        open(os.path.join(ROOT, 'rtl', 'yunit_fmoves_tab.svh'), 'w', newline='\n').write(gen_tab())
        open(os.path.join(ROOT, 'rtl', 'yunit_fmoves_osd.svh'), 'w', newline='\n').write(gen_osd())
        lines, info = osd_lines()
        n = sum(len(l) for l in lines) + len(info)
        print('OSD %d bytes, %d lines; %d steps' % (n, len(lines), len(tables()[1])))
    elif a and a[0] == '--docs':
        print(docs())
    elif len(a) >= 2 and a[0] == '--scan':
        for f in a[1:]:
            r = scan(open(f, 'rb').read())
            print(f, ' '.join('%s %08X' % (k, v) for k, v in r.items() if v is not None) if r else 'not found')
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
