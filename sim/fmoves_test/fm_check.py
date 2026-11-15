#!/usr/bin/env python3
"""
fm_check.py - checks the finishing-move player (rtl/yunit_fmoves.sv)

    make && python3 fm_check.py [--mutants]

Builds fight situations from CPU writes (the real fight variables of a set,
made-up objects) and runs them through obj_dir/fm_tb with the real ROM index 1
words tools/yunit_fmoves.py makes for the set:

  - every fighter's move, P1 and P2 the winner: the direct finisher's patch
    (fp_en, fp_addr = the fighter's site) goes on before the first trigger
    tap, the controls are the trigger key only (five taps, 3 frames down and
    6 apart), the patch stays on while they play, goes off the frame the game
    takes the move (the finish flag), and is off before and after the program
  - not taken: the patch goes off with the program, the message follows: the
    game never ran the handler (the board never read the site), the site was
    read but is no jump, or it was turned round and the game still refused;
    a finish flag left from an earlier fatality does not count as taken (the
    game has to write it), nor does a write of 0; what the board saw before
    the move began does not count either
  - a set without sites (words 0x70-0x7D absent): the combination, the patch
    never on
  - the patch never on: another fighter wins, too far, the move cleared,
    a new pick, a reset, FINISH HIM over before the move started
  - --mutants: the player built with a deliberate fault (no stop when the move
    is taken, the patch left on after the program, always on, another
    fighter's site) must fail these checks

Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
"""

import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import yunit_fmoves as Y   # noqa: E402

TB = os.environ.get('FM_TB') or os.path.join(HERE, 'obj_dir', 'fm_tb')

SETNAME = os.environ.get('FM_SET', 'mkla4')
VARS = Y.VARS
LAY = Y.stored(SETNAME)
ADDR = {k: LAY[k] >> 4 for k in VARS}                  # word addresses
OBJ = {1: 0x105000, 2: 0x105100}                      # objects (word addresses)
PROC = {1: 0x105200, 2: 0x105300}                      # processes
IMG = {1: 0x105400, 2: 0x105500}                       # images
ANCHOR = 0x20
XOFF, FLOFF, WOFF, IMGOFF, ROFF = 9, 14, 18, 22, 14
DIZ, STANCE = LAY['diz'], LAY['stance']
BUSY = 0xFF8C0000
MSG = {k: n + 1 for n, (k, _) in enumerate(Y.MESSAGES)}
KEY = {'U': 0, 'D': 1, 'L': 2, 'R': 3, 'HP': 4, 'LP': 5, 'HK': 6, 'LK': 7, 'BL': 8}
LINE = {cid: li for li, (n, cid, mv) in enumerate(Y.osd_fighters())}  # the Fighter list's line of a character (alphabetical)
SITES = Y.direct_stored(SETNAME)
CHAR_NAME = {cid: n for n, cid, mv in Y.osd_fighters()}


def cfg_words(with_sites=True):
    data, _ = Y.build(6, SETNAME, None)
    w = [int.from_bytes(data[i:i + 2], 'little') for i in range(0, len(data), 2)]
    w += [0] * (Y.CFG_WORDS - len(w))
    if not with_sites:
        for i in range(Y.CFG_DIRECT, Y.CFG_WORDS):
            w[i] = 0
    return w


class Script:
    def __init__(self, with_sites=True):
        w = cfg_words(with_sites)
        self.l = ['g 1', 's']
        for i in range(0x10, 0x30):
            self.l.append('c %d %x' % (i - 0x10, w[i]))
        for i in range(Y.CFG_DIRECT, Y.CFG_WORDS):
            self.l.append('d %d %x' % (i - Y.CFG_DIRECT, w[i]))
        self.l.append('c 0 1')

    def w(self, a, v):
        self.l.append('w %x %x' % (a, v & 0xFFFF))

    def w32(self, a, v):
        self.w(a, v & 0xFFFF)
        self.w(a + 1, v >> 16)

    def var(self, k, v):
        self.w(ADDR[k], v)

    def fight(self, c1, c2, x1, x2, r1=STANCE, r2=DIZ, flip=(0, 1)):
        self.var('state', 0)
        self.var('flag', 0)
        self.var('p1c', c1)
        self.var('p2c', c2)
        self.var('p1e', 0xA1)
        self.var('p2e', 0xA1)
        for p in (1, 2):
            self.w32(ADDR['p%do' % p], OBJ[p] << 4)
            self.w32(ADDR['p%dp' % p], PROC[p] << 4)
            self.w(OBJ[p] + FLOFF, 0x10 if flip[p - 1] else 0)
            self.w(OBJ[p] + WOFF, 0x40)
            self.w32(OBJ[p] + IMGOFF, IMG[p] << 4)
            self.l.append('r %x %x' % (IMG[p] + 2, ANCHOR))
        self.x(x1, x2)
        self.w32(PROC[1] + ROFF, r1)
        self.w32(PROC[2] + ROFF, r2)

    def x(self, x1, x2):
        self.w(OBJ[1] + XOFF, x1)
        self.w(OBJ[2] + XOFF, x2)

    def finish(self, loser):
        self.var('p%de' % loser, 0)
        self.var('state', 3)

    def pick(self, line, slot):
        self.l.append('p %d %d' % (line, slot))

    def frames(self, n):
        self.l.append('f %d' % n)

    def reset(self):
        self.l.append('x')

    def run(self):
        out = subprocess.run([TB], input='\n'.join(self.l) + '\n', capture_output=True, text=True).stdout
        fr, msgs = [], []
        for line in out.splitlines():
            t = line.split()
            if t[0] == 'F':
                fr.append(dict(n=int(t[1]), drive=int(t[2]), keys=int(t[3], 16), fp=int(t[4]), addr=int(t[5], 16), seen=0))
            elif t[0] == 'E':
                fr[-1]['seen'] = 1
            elif t[0] == 'M':
                msgs.append((int(t[1]), int(t[2])))
        return fr, msgs


fails = 0


def check(cond, what):
    global fails
    if not cond:
        fails += 1
        print('FAIL', what)
    return cond


def runs(bits):
    """[(start, length)] of the runs of true in a list."""
    out, i = [], 0
    while i < len(bits):
        if bits[i]:
            j = i
            while j < len(bits) and bits[j]:
                j += 1
            out.append((i, j - i))
            i = j
        else:
            i += 1
    return out


def other(cid):
    return 1 if cid == 0 else 0


def dist_in(dmin, dmax):
    return 100 if dmax >= Y.FAR else (dmin + dmax) // 2


def move_of(cid):
    return Y.osd_fighters()[LINE[cid]][2][0]


def setup(cid, who=1, dist=None, sites=True, stale=False, stale_site=None):
    """A fight with fighter cid winning as player who, the set move picked,
    FINISH HIM just begun. Returns the script and the picked line."""
    name, c, moves = Y.osd_fighters()[LINE[cid]]
    mname, cmd, prog, dmin, dmax = moves[0]
    d = dist if dist is not None else dist_in(dmin, dmax)
    s = Script(sites)
    if who == 1:
        s.fight(cid, other(cid), 500, 500 + d)                 # P1 left, faces right
    else:
        s.fight(other(cid), cid, 500, 500 + d, r1=DIZ, r2=STANCE, flip=(0, 1))
    if stale:
        s.var('flag', 1)                                       # left from an earlier fatality
    s.pick(LINE[cid], 0)
    if stale_site:
        s.l.append('q %d %d' % stale_site)                     # the board's pulses before the move began
    s.frames(2)
    s.finish(2 if who == 1 else 1)
    return s, (dmin, dmax)


def play(cid, who=1, take_after=None, total=300, sites=True, dist=None):
    """Plays the fighter's move; take_after: the frame (counted from the first
    trigger tap) the game sets the finish flag. Returns the frames of the run
    after FINISH HIM and the messages."""
    s, _ = setup(cid, who, dist, sites)
    s.frames(120)                                    # to the ready point and the move
    return s, s.run()


def analyse(frames, who):
    """The driven port's key bits per frame and the patch."""
    keys = [f['keys'] if f['drive'] == who else 0 for f in frames]
    fp = [f['fp'] for f in frames]
    return keys, fp


def test_direct():
    for cid in range(7):
        trig = Y.DIRECT_TRIG[cid]
        name = CHAR_NAME[cid]
        for who in (1, 2):
            tag = '%s P%d' % (name, who)
            # --- taken at the first tap: the patch stops with the flag
            s, _ = setup(cid, who)
            s.frames(90)
            frames, msgs = s.run()
            keys, fp = analyse(frames, who)
            tap_runs = runs([bool(k & (1 << KEY[trig])) for k in keys])
            check(len(tap_runs) == Y.DIRECT_TAPS and all(l == 3 for _, l in tap_runs), tag + ' five taps of 3 frames: %s' % tap_runs)
            check(all(b - a == 6 for (a, _), (b, _) in zip(tap_runs, tap_runs[1:])), tag + ' taps 6 frames apart %s' % tap_runs)
            check(all(k & ~(1 << KEY[trig]) == 0 for k in keys), tag + ' only the trigger key %s' % sorted(set(keys)))
            on = runs(fp)
            check(len(on) == 1, tag + ' the patch comes on once: %s' % on)
            if on and tap_runs:
                a, l = on[0]
                t1 = tap_runs[0][0]
                last_end = tap_runs[-1][0] + tap_runs[-1][1]
                check(0 <= t1 - a <= 3, tag + ' patch on %d frames before the first tap' % (t1 - a))
                check(a + l >= last_end + 10, tag + ' patch stays on to the end of the program (%d..%d, taps end %d)' % (a, a + l, last_end))
                check(a + l <= last_end + 17, tag + ' patch off soon after the program (%d)' % (a + l - last_end))
            check(all(f['addr'] == SITES[cid] for f in frames if f['fp']), tag + ' the fighter\'s site %05x' % SITES[cid])
            check(not [m for f, m in msgs if f > 0], tag + ' messages %s' % msgs)

            # --- the game takes it at the first tap: the patch goes off at once, the controls too
            s, _ = setup(cid, who)
            s.frames(40)
            fr0 = s.run()[0]
            kk, _f = analyse(fr0, who)
            t1 = runs([bool(k & (1 << KEY[trig])) for k in kk])[0][0]     # the frame the first tap begins
            s, _ = setup(cid, who)
            s.frames(t1 + 2)
            s.var('flag', 1)                         # the game began the fatality
            s.frames(60)
            frames, msgs = s.run()
            keys, fp = analyse(frames, who)
            on = runs(fp)
            check(len(on) == 1 and on[0][0] + on[0][1] <= t1 + 2 + 2, tag + ' taken: patch off with the flag %s (taps began %d)' % (on, t1))
            check(frames[-1]['drive'] == 0 and frames[-1]['fp'] == 0, tag + ' taken: controls and patch let go')
            check(not [m for f, m in msgs if f > 0], tag + ' taken: messages %s' % msgs)
            # and FINISH HIM ends with it
            s, _ = setup(cid, who)
            s.frames(t1 + 2)
            s.var('flag', 1)
            s.var('state', 1)
            s.frames(250)
            frames, msgs = s.run()
            check(not [m for f, m in msgs if f > 0] and all(f['fp'] == 0 for f in frames[t1 + 6:]), tag + ' taken, FINISH HIM over: quiet %s' % msgs)

            # --- not taken: the patch goes off with the program, then the message
            # (what the board saw of the site says why)
            for pulses, name_ in ((None, 'NO_RUN'), ((1, 0), 'NOT_JUMP'), ((1, 1), 'REFUSED')):
                s, _ = setup(cid, who)
                s.frames(20)
                if pulses:
                    s.l.append('q %d %d' % pulses)
                s.frames(40)
                s.var('state', 3)
                s.frames(260)
                frames, msgs = s.run()
                keys, fp = analyse(frames, who)
                on = runs(fp)
                check(len(on) == 1, tag + ' not taken: one patch run %s' % on)
                check(sum(fp[on[0][0] + on[0][1]:]) == 0 if on else False, tag + ' not taken: patch off afterwards')
                check(msgs[-1][1] == MSG[name_] and msgs[-1][0] - (on[0][0] + on[0][1]) in range(185, 200),
                      tag + ' not taken, %s: message %s after patch run %s' % (name_, msgs, on))
                check([m for f, m in msgs if f > 0] == [MSG[name_]], tag + ' not taken, %s: one message %s' % (name_, msgs))

            # --- the flag a fatality left is not "taken"; a write of 0 is not either;
            # what the board saw before the move began does not count
            s, _ = setup(cid, who, stale=True, stale_site=(1, 1))
            s.frames(90)
            frames, msgs = s.run()
            keys, fp = analyse(frames, who)
            tap_runs = runs([bool(k & (1 << KEY[trig])) for k in keys])
            on = runs(fp)
            check(len(tap_runs) == Y.DIRECT_TAPS and len(on) == 1 and on[0][1] >= 30,
                  tag + ' stale flag: the move plays (taps %s, patch %s)' % (tap_runs, on))
            s, _ = setup(cid, who, stale=True, stale_site=(1, 1))
            s.frames(60)
            s.var('state', 3)
            s.frames(260)
            frames, msgs = s.run()
            check(msgs[-1][1] == MSG['NO_RUN'], tag + ' stale pulses: message %s' % msgs)
            s, _ = setup(cid, who)
            s.frames(20)
            s.var('flag', 0)                          # the game writes 0: not taken
            s.frames(60)
            frames, msgs = s.run()
            keys, fp = analyse(frames, who)
            check(len(runs(fp)) == 1 and runs(fp)[0][1] >= 30, tag + ' flag written 0: the patch stays on %s' % runs(fp))


def test_no_sites():
    for cid in range(7):
        name = CHAR_NAME[cid]
        s, _ = setup(cid, 1, sites=False)
        s.frames(120)
        frames, msgs = s.run()
        keys, fp = analyse(frames, 1)
        check(sum(fp) == 0 and not any(f['seen'] for f in frames), name + ' no sites: patch never on')
        # the combination is played (Block held first, the move's last key at the end)
        mname, cmd, prog, dmin, dmax = move_of(cid)
        check(any(keys), name + ' no sites: the combination plays')
        pressed = set()
        for k in keys:
            pressed |= {b for b in range(9) if k >> b & 1}
        need = {KEY[t.lstrip('[]')] for t in prog.split() if t[0] != 'w' and t.lstrip('[]') in KEY}
        check(pressed >= {b for b in need if b not in (KEY['L'], KEY['R'])}, name + ' no sites: every key of the combination %s' % prog)


def test_never_on():
    # another fighter wins: no taps, no patch
    s, _ = setup(0)
    s.pick(LINE[1], 0)                                # Kano's move set, Cage wins
    s.frames(100)
    fr, msgs = s.run()
    check(all(f['fp'] == 0 and f['drive'] == 0 for f in fr[-100:]) and not any(f['seen'] for f in fr),
          'another fighter wins: nothing played')
    check(MSG['NOT_THIS'] in [m for f, m in msgs], 'another fighter wins: message %s' % msgs)

    # too far: nothing until the distance fits, then the patch with the taps
    cid = 1
    name, c, moves = Y.osd_fighters()[LINE[cid]]
    dmin, dmax = moves[0][3], moves[0][4]
    s, _ = setup(cid, 1, dist=dmax + 60)
    s.frames(60)
    s.x(500, 500 + dmax - 20)
    s.frames(80)
    fr, msgs = s.run()
    check(all(f['fp'] == 0 and f['drive'] == 0 for f in fr[:60]) and not any(f['seen'] for f in fr[:60]), 'too far: no patch')
    check(MSG['FAR'] in [m for f, m in msgs], 'too far: message %s' % msgs)
    check(any(f['fp'] for f in fr[60:]), 'stepped in: the patch comes on')

    # cleared / re-picked / reset while the taps play: the patch goes
    for how in ('clear', 'repick', 'reset'):
        s, _ = setup(0)
        s.frames(14)
        on = any(f['fp'] for f in s.run()[0])
        s, _ = setup(0)
        s.frames(14)
        if how == 'clear':
            s.l.append('p 0 15')
        elif how == 'repick':
            s.pick(LINE[1], 0)
        else:
            s.reset()
        s.frames(40)
        fr, msgs = s.run()
        fr = fr[-40:]
        check(on, how + ': the patch was on')
        check(all(f['fp'] == 0 and not f['seen'] for f in fr[2:]), how + ': the patch goes off')

    # FINISH HIM over before the move started (still waiting for the loser to reel): nothing
    s = Script()
    s.fight(0, 1, 500, 570, r2=BUSY)
    s.pick(LINE[0], 0)
    s.frames(2)
    s.finish(2)
    s.frames(30)
    s.var('state', 1)
    s.frames(30)
    fr, msgs = s.run()
    check(not any(f['seen'] for f in fr) and MSG['OVER'] in [m for f, m in msgs], 'FINISH HIM over first: nothing, message %s' % msgs)


MUTANTS = [
    # (name, [(pattern, replacement, expected count)])
    ('no stop when the move is taken',
     [(r"assign fp_en   = dir_on && st == S_RUN && !taken;", "assign fp_en   = dir_on && st == S_RUN;", 1)]),
    ('patch left on after the program',
     [(r"assign fp_en   = dir_on && st == S_RUN && !taken;", "assign fp_en   = dir_on && !taken;", 1),
      (r"dir_on       <= 1'b0;", "", 2)]),
    ('on while running, DIRECT or not',
     [(r"assign fp_en   = dir_on && st == S_RUN && !taken;", "assign fp_en   = (st == S_RUN) && !taken;", 1)]),
    ('a stale flag or site pulse counts (not cleared at the move start)',
     [(r"if \(run_go\) begin", "if (1'b0) begin", 1)]),
    ('a write of 0 to the flag counts as taken',
     [(r"if \(w_a == c_a\[10\] && w_d != 16'd0\) took <= 1'b1;", "if (w_a == c_a[10]) took <= 1'b1;", 1)]),
    ('the message ignores what the board saw',
     [(r"msg     <= !ran_direct \? MSG_NOT_TAKEN :[^;]*;", "msg     <= MSG_NO_RUN;", 1)]),
    ("another fighter's site",
     [(r"m_site_a <= s_a\[m_char\];", "m_site_a <= s_a[0];", 1)]),
    ('site validity ignored',
     [(r"m_site_v <= \(m_char < 3'd7\) && s_v\[m_char\];", "m_site_v <= 1'b1;", 1)]),
]


def test_fighter_list():
    """The OSD Fighter list (the generated rtl/yunit_fmoves_osd.svh) is
    alphabetical, holds every fighter once, and each fighter's move line is
    shown for that fighter's place in the list (menu mask bits 8-10 = the
    option value, as the move records' line is)."""
    osd = open(os.path.join(HERE, '..', '..', 'rtl', 'yunit_fmoves_osd.svh')).read()
    m = re.search(r'O\[30:28\],Fighter,([^;"]*);', osd)
    names = m.group(1).split(',') if m else []
    check(names == sorted(names), 'the Fighter list is alphabetical')
    check(sorted(names) == sorted(n for n, c, mv in Y.fighters()), 'every fighter is in the Fighter list once')
    check(names == [n for n, c, mv in Y.osd_fighters()], 'the Fighter list is the generator\'s order')
    for li, (n, c, mv) in enumerate(Y.osd_fighters()):
        line = '"%s%sR[%d],%s' % (Y.sel_prefix(li), Y.PAGE_FM, Y.SLOT_BIT, mv[0][0])
        check(line in osd, '%s (list place %d): its move line is shown for that place' % (n, li))
        check(names[li] == n, '%s is at place %d in the list' % (n, li))


def run_tests():
    global fails
    fails = 0
    test_fighter_list()
    test_direct()
    test_no_sites()
    test_never_on()
    return fails


def mutants():
    src = open(os.path.join(HERE, '..', '..', 'rtl', 'yunit_fmoves.sv')).read()
    ok = True
    for name, edits in MUTANTS:
        d = os.path.join(HERE, 'obj_mut')
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
        new, bad = src, False
        for pat, rep, cnt in edits:
            new, n = re.subn(pat, lambda m: rep, new)
            if n != cnt:
                print('mutant "%s": pattern found %d times, not %d' % (name, n, cnt))
                bad = True
        if bad:
            ok = False
            continue
        open(os.path.join(d, 'yunit_fmoves.sv'), 'w').write(new)
        shutil.copy(os.path.join(HERE, '..', '..', 'rtl', 'yunit_fmoves_tab.svh'), d)
        r = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-O2', '-Wno-fatal', '-Wno-WIDTH', '-Wno-lint',
                            '--top-module', 'yunit_fmoves', '-I' + d, '-Mdir', os.path.join(d, 'obj'), '-o', 'fm_tb',
                            os.path.join(d, 'yunit_fmoves.sv'), os.path.join(HERE, 'fm_tb.cpp')], capture_output=True, text=True)
        tb = os.path.join(d, 'obj', 'fm_tb')
        if not os.path.exists(tb):
            print('mutant "%s": build failed\n%s' % (name, r.stderr[-400:]))
            ok = False
            continue
        global TB
        old, TB = TB, tb
        buf = sys.stdout
        import io
        sys.stdout = io.StringIO()
        n = run_tests()
        sys.stdout = buf
        TB = old
        print('mutant "%s": %s (%d checks failed)' % (name, 'caught' if n else 'NOT CAUGHT', n))
        ok &= n > 0
    shutil.rmtree(os.path.join(HERE, 'obj_mut'), ignore_errors=True)
    return ok


if __name__ == '__main__':
    n = run_tests()
    print('%s: %d checks failed' % (SETNAME, n) if n else '%s: all checks passed' % SETNAME)
    ok = n == 0
    if '--mutants' in sys.argv:
        ok &= mutants()
    sys.exit(0 if ok else 1)
