// fm_tb.cpp - drives rtl/yunit_fmoves.sv from a script on stdin
//
//   g <mk>              loaded game (Mortal Kombat)
//   s                   ROM index 1 download starts
//   c <word> <hex>      ROM index 1 word 0x10 + word (the fight variables)
//   d <word> <hex>      ROM index 1 word 0x70 + word (the direct finishers' sites)
//   w <hex addr> <hex>  CPU write (word address)
//   r <hex addr> <hex>  CPU read of that word, which returned the data
//   q <rd> <flip>       the board read / turned round the direct site (one clock)
//   p <line> <slot>     OSD pick
//   x                   reset
//   f <n>               n running frames
// Prints "F <frame> <drive> <keys hex> <fp_en> <fp_addr hex>" for each frame
// and "M <frame> <msg>" for each message. "E <frame>" says fp_en was high at
// some clock of the frame.
//
// Copyright (C) 2026 Gm0rk - GPL-3.0-or-later

#include "Vyunit_fmoves.h"
#include "verilated.h"
#include <cstdio>
#include <cstring>

static Vyunit_fmoves *m;
static long frame_no;
static int fp_seen;

static void tick()
{
	m->clk = 0; m->eval();
	m->clk = 1; m->eval();
	if (m->msg_req) printf("M %ld %d\n", frame_no, m->msg);
	if (m->fp_en) fp_seen = 1;
	m->dl_start = 0; m->dl_wr = 0; m->dir_wr = 0; m->cpu_wr = 0; m->cpu_rd = 0; m->sel = 0; m->frame = 0;
	m->fp_rd = 0; m->fp_flip = 0;
}

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);
	m = new Vyunit_fmoves;
	m->reset = 1;
	for (int i = 0; i < 4; i++) tick();
	m->reset = 0;
	char cmd[16];
	while (scanf("%15s", cmd) == 1) {
		if (!strcmp(cmd, "g")) { int a; scanf("%d", &a); m->game_mk = a; tick(); }
		else if (!strcmp(cmd, "s")) { m->dl_start = 1; tick(); }
		else if (!strcmp(cmd, "c")) { unsigned a, v; scanf("%u %x", &a, &v); m->dl_wr = 1; m->dl_addr = a; m->dl_data = v; tick(); }
		else if (!strcmp(cmd, "d")) { unsigned a, v; scanf("%u %x", &a, &v); m->dir_wr = 1; m->dir_addr = a; m->dl_data = v; tick(); }
		else if (!strcmp(cmd, "w")) { unsigned a, v; scanf("%x %x", &a, &v); m->cpu_wr = 1; m->cpu_wa = a; m->cpu_wd = v; tick(); tick(); }
		else if (!strcmp(cmd, "r")) { unsigned a, v; scanf("%x %x", &a, &v); m->cpu_rd = 1; m->cpu_wa = a; m->cpu_rdata = v; tick(); tick(); }
		else if (!strcmp(cmd, "q")) { unsigned r, f; scanf("%u %u", &r, &f); m->fp_rd = r; m->fp_flip = f; tick(); }
		else if (!strcmp(cmd, "p")) { unsigned l, s; scanf("%u %u", &l, &s); m->sel = 1; m->sel_line = l; m->sel_slot = s; tick(); for (int i = 0; i < 4; i++) tick(); }
		else if (!strcmp(cmd, "x")) { m->reset = 1; for (int i = 0; i < 4; i++) tick(); m->reset = 0; tick(); }
		else if (!strcmp(cmd, "f")) {
			int n; scanf("%d", &n);
			for (int k = 0; k < n; k++) {
				fp_seen = m->fp_en;
				for (int i = 0; i < 6; i++) tick();
				m->frame = 1; tick();
				for (int i = 0; i < 3; i++) tick();
				printf("F %ld %d %03x %d %05x\n", frame_no, m->drive, m->keys, m->fp_en, m->fp_addr);
				if (fp_seen) printf("E %ld\n", frame_no);
				frame_no++;
			}
		}
	}
	delete m;
	return 0;
}
