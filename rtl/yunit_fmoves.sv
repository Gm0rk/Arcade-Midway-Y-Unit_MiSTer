//============================================================================
//  Finishing moves (Mortal Kombat), from the OSD
//
//  The OSD's "Finishing Moves" page lists each fighter's fatality and The
//  Pit. A pick sets the move; this module enters it on the winner's controls
//  at the next FINISH HIM where the winner is that fighter, and says in an
//  OSD message when it cannot (another fighter, The Pit on another stage,
//  too far or too close, FINISH HIM over, not taken). It is the T-Unit
//  core's player (rtl/tunit_fmoves.sv there) measuring the distance the way
//  the game does.
//
//  Following the fight. The module keeps copies of the game's fight
//  variables by watching the CPU's writes (the board's dbg_wr): the round
//  state (3 = FINISH HIM), both fighters' character, energy, object and
//  process pointers, the stage and the finish flag the game sets when a
//  fatality starts. Their addresses differ between revisions; the MRA sends
//  them (ROM index 1, words 0x10-0x2F; tools/yunit_fmoves.py). Through the
//  pointers it follows where each fighter's process resumes (process words
//  14-15): the finisher's stance loop and the loser's dizzy loop tell when a
//  move can start; until then the game drops it.
//
//  Distance. The game measures |center1 - center2|, a fighter's center
//  being its object's x (word 9) plus the anchor of its current image
//  (image header word 2; the image pointer is object words 22-23), or with
//  the object flipped (word 14 bit 4) its width (word 18) - 1 - the anchor.
//  The bare x jumps with each image (the dizzy loser's sway, blocking), the
//  center stays put. The anchor is in the program ROM: the module takes it
//  from the CPU's own reads of the header (the board's dbg_rd), which the
//  game makes several times a frame.
//
//  The winner is the fighter whose energy is not 0 at FINISH HIM. A move
//  starts when its fighter is the winner, the stage fits (The Pit), the
//  distance is in the move's window and both fighters are ready; the module
//  then takes that player's controls (the player's own are ignored) for a
//  few frames so the finisher comes to rest, and plays the move's program.
//  Out of the window it says so once and waits, leaving the controls to the
//  player, who can step in or out: the move starts when the distance fits.
//
//  Programs (rtl/yunit_fmoves_tab.svh, from tools/yunit_fmoves.py): steps
//  {op[2:0], arg[12:0]}, one starting per frame at most:
//    0 END
//    1 TAP      keys arg[8:0] for arg[12:9] + 1 frames, then 3 frames up
//    2 PRESS    hold keys arg[8:0] (next step on the next frame)
//    3 RELEASE  let go of keys arg[8:0], then 3 frames
//    4 WAIT     arg frames
//    5 READY    wait for the loser dizzy, the finisher in its stance (unless
//               a button is held) and the distance in the window
//  Keys {BL, LK, HK, LP, HP, B, F, D, U}; F and B are toward and away from
//  the loser, turned into Right / Left each frame from the two centers.
//
//  After the program the finish flag says whether the game took the move
//  (The Pit: the round state leaving FINISH HIM soon after the uppercut).
//  Taken, the move is done; not taken, a message says so. Either way the
//  set move is cleared. A move set outside FINISH HIM (or for another
//  fighter) waits for the right one; a FINISH HIM that ends first leaves it
//  set.
//
//  Frames are running frames (the top level's osd_frame), so with "Pause
//  when OSD is open" a pick made at FINISH HIM starts when the OSD closes.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_fmoves
(
	input             clk,
	input             reset,
	input             game_mk,       // Mortal Kombat is loaded

	// ROM index 1 words 0x10-0x2F: the set's fight variables
	input             dl_start,      // pulse: ROM index 1 is about to arrive
	input             dl_wr,
	input       [4:0] dl_addr,
	input      [15:0] dl_data,

	// OSD
	input             sel,           // one clock: a pick
	input       [2:0] sel_line,      // the page's fighter (its line in the Fighter list)
	input       [3:0] sel_slot,      // the move's line, 15 = clear the set move
	input             frame,         // one clock at the start of each running frame

	// CPU accesses as they complete (the board's dbg_wr / dbg_rd, word
	// address dbg_wa, data dbg_wdata / dbg_rdata)
	input             cpu_wr,
	input             cpu_rd,
	input      [27:0] cpu_wa,
	input      [15:0] cpu_wd,
	input      [15:0] cpu_rdata,

	// controls: while drive[n], player n+1's controls are keys (active high)
	output      [1:0] drive,
	output reg  [8:0] keys,          // {BL, LK, HK, LP, HP, Right, Left, Down, Up}
	output reg        msg_req,       // one clock: show OSD message msg
	output reg  [4:0] msg
);

`include "yunit_fmoves_tab.svh"

localparam K_FATAL = 1'b0, K_MKPIT = 1'b1;
localparam OP_END = 3'd0, OP_TAP = 3'd1, OP_PRESS = 3'd2, OP_RELEASE = 3'd3, OP_WAIT = 3'd4,
           OP_READY = 3'd5;
localparam [12:0] GAP = 13'd3;            // frames up after a tap or a release
localparam [7:0] CHECK_FRAMES = 8'd192;
localparam [7:0] PIT_FRAMES = 8'd40;      // The Pit: the round must end this soon after the program
localparam [2:0] SETTLE = 3'd4;

// object and image word offsets (the game's center routine, every revision)
localparam [27:0] O_X = 28'd9, O_FLAGS = 28'd14, O_W = 28'd18, O_IMG = 28'd22, I_ANCHOR = 28'd2;
localparam [27:0] P_RESUME = 28'd14;      // process: where it resumes (32-bit)

//----------------------------------------------------------------------------
// The set's addresses
//----------------------------------------------------------------------------

// word addresses: 0 round state, 1-2 P1 / P2 character, 3-4 energy,
// 5-6 object pointer, 7-8 process pointer, 9 stage, 10 finish flag
reg  [27:0] c_a  [0:10];
reg  [27:0] c_a1 [0:10];         // each + 1 (high word of a pointer)
reg  [31:0] c_diz, c_stance;
reg         c_ok;

integer i;
always @(posedge clk) begin
	for (i = 0; i < 11; i = i + 1) c_a1[i] <= c_a[i] + 28'd1;

	if (dl_start)
		c_ok <= 1'b0;
	else if (dl_wr) begin
		if (dl_addr == 5'd0) c_ok <= (dl_data == 16'd1);
		for (i = 0; i < 11; i = i + 1) begin
			if ({27'd0, dl_addr} == 2 + 2 * i) c_a[i][15:0]  <= dl_data;
			if ({27'd0, dl_addr} == 3 + 2 * i) c_a[i][27:16] <= dl_data[11:0];
		end
		if (dl_addr == 5'd24) c_diz[15:0]     <= dl_data;
		if (dl_addr == 5'd25) c_diz[31:16]    <= dl_data;
		if (dl_addr == 5'd26) c_stance[15:0]  <= dl_data;
		if (dl_addr == 5'd27) c_stance[31:16] <= dl_data;
	end
end

//----------------------------------------------------------------------------
// The fight, from the CPU's writes and reads
//----------------------------------------------------------------------------

reg         w_v, r_v;
reg  [27:0] w_a;                 // the access's word address (a read's too)
reg  [15:0] w_d, r_d;
always @(posedge clk) begin
	w_v <= cpu_wr & c_ok;
	r_v <= cpu_rd & c_ok;
	w_a <= cpu_wa;
	w_d <= cpu_wd;
	r_d <= cpu_rdata;
end

reg  [15:0] v_state, v_c1, v_c2, v_e1, v_e2, v_stage, v_flag;
reg  [31:0] v_o [1:2];            // object pointers (bit addresses)
reg  [31:0] v_p [1:2];            // process pointers
reg  [15:0] v_x [1:2], v_fl [1:2], v_w [1:2], v_ax [1:2];
reg  [31:0] v_img [1:2];          // image pointers
reg  [31:0] v_r [1:2];            // where the processes resume
reg   [2:1] v_xv, v_flv, v_wv, v_imgv, v_axv, v_rv;   // seen since the pointer last changed

// the watched addresses, from the pointers (registered)
reg  [27:0] a_x [1:2], a_fl [1:2], a_w [1:2], a_img [1:2], a_imgh [1:2], a_ax [1:2], a_r [1:2], a_rh [1:2];

integer p;
always @(posedge clk) begin
	for (p = 1; p <= 2; p = p + 1) begin
		a_x[p]    <= v_o[p][31:4] + O_X;
		a_fl[p]   <= v_o[p][31:4] + O_FLAGS;
		a_w[p]    <= v_o[p][31:4] + O_W;
		a_img[p]  <= v_o[p][31:4] + O_IMG;
		a_imgh[p] <= v_o[p][31:4] + O_IMG + 28'd1;
		a_ax[p]   <= v_img[p][31:4] + I_ANCHOR;
		a_r[p]    <= v_p[p][31:4] + P_RESUME;
		a_rh[p]   <= v_p[p][31:4] + P_RESUME + 28'd1;
	end

	if (reset || !c_ok) begin
		v_state <= 16'd0;
		v_flag  <= 16'd0;
		v_xv    <= 2'b00;
		v_flv   <= 2'b00;
		v_wv    <= 2'b00;
		v_imgv  <= 2'b00;
		v_axv   <= 2'b00;
		v_rv    <= 2'b00;
	end
	else begin
		if (w_v) begin
			if (w_a == c_a[0])  v_state <= w_d;
			if (w_a == c_a[1])  v_c1    <= w_d;
			if (w_a == c_a[2])  v_c2    <= w_d;
			if (w_a == c_a[3])  v_e1    <= w_d;
			if (w_a == c_a[4])  v_e2    <= w_d;
			if (w_a == c_a[9])  v_stage <= w_d;
			if (w_a == c_a[10]) v_flag  <= w_d;
			for (p = 1; p <= 2; p = p + 1) begin
				// a new object: nothing of it known yet
				if (w_a == c_a[4 + p] || w_a == c_a1[4 + p]) begin
					if (w_a == c_a[4 + p]) v_o[p][15:0]  <= w_d;
					else                   v_o[p][31:16] <= w_d;
					v_xv[p]   <= 1'b0;
					v_flv[p]  <= 1'b0;
					v_wv[p]   <= 1'b0;
					v_imgv[p] <= 1'b0;
					v_axv[p]  <= 1'b0;
				end
				if (w_a == c_a[6 + p] || w_a == c_a1[6 + p]) begin
					if (w_a == c_a[6 + p]) v_p[p][15:0]  <= w_d;
					else                   v_p[p][31:16] <= w_d;
					v_rv[p] <= 1'b0;
				end
				if (w_a == a_x[p])  begin v_x[p]  <= w_d; v_xv[p]  <= 1'b1; end
				if (w_a == a_fl[p]) begin v_fl[p] <= w_d; v_flv[p] <= 1'b1; end
				if (w_a == a_w[p])  begin v_w[p]  <= w_d; v_wv[p]  <= 1'b1; end
				// a new image: its anchor comes with the next read of its header
				if (w_a == a_img[p])  begin v_img[p][15:0]  <= w_d; v_imgv[p] <= 1'b1; v_axv[p] <= 1'b0; end
				if (w_a == a_imgh[p]) begin v_img[p][31:16] <= w_d; v_imgv[p] <= 1'b1; v_axv[p] <= 1'b0; end
				if (w_a == a_r[p])  begin v_r[p][15:0]  <= w_d; v_rv[p] <= 1'b1; end
				if (w_a == a_rh[p]) begin v_r[p][31:16] <= w_d; v_rv[p] <= 1'b1; end
			end
		end
		if (r_v) begin
			for (p = 1; p <= 2; p = p + 1)
				if (v_imgv[p] && w_a == a_ax[p]) begin
					v_ax[p]  <= r_d;
					v_axv[p] <= 1'b1;
				end
		end
	end
end

//----------------------------------------------------------------------------
// The finisher and the loser (registered each clock)
//----------------------------------------------------------------------------

// centers: x + anchor, or flipped x + width - 1 - anchor (16 bits, as the game)
reg  [15:0] ctr [1:2];
reg   [2:1] ctr_ok;
always @(posedge clk)
	for (p = 1; p <= 2; p = p + 1) begin
		ctr[p]    <= v_fl[p][4] ? v_x[p] + v_w[p] - 16'd1 - v_ax[p] : v_x[p] + v_ax[p];
		ctr_ok[p] <= v_xv[p] & v_flv[p] & v_wv[p] & v_imgv[p] & v_axv[p];
	end

wire [15:0] cdiff = ctr[1] - ctr[2];

reg         fin;                 // FINISH HIM with a known winner
reg         who;                 // the winner: 0 P1, 1 P2
reg  [15:0] fin_char;
reg  [15:0] sep;
reg         sep_ok;              // both centers known
reg         fwd_right;           // the loser is to the winner's right
reg         opp_dizzy, fin_stance;

always @(posedge clk) begin
	fin        <= (v_state == 16'd3) && ((v_e1 == 16'd0) != (v_e2 == 16'd0));
	who        <= (v_e1 == 16'd0);
	fin_char   <= (v_e1 == 16'd0) ? v_c2 : v_c1;
	sep        <= cdiff[15] ? 16'd0 - cdiff : cdiff;
	sep_ok     <= ctr_ok[1] & ctr_ok[2];
	// winner's center left of the loser's: forward is Right
	fwd_right  <= (v_e1 == 16'd0) ? cdiff[15] == 1'b0 && cdiff != 16'd0 : cdiff[15];
	opp_dizzy  <= (v_e1 == 16'd0) ? v_rv[1] && v_r[1] == c_diz    : v_rv[2] && v_r[2] == c_diz;
	fin_stance <= (v_e1 == 16'd0) ? v_rv[2] && v_r[2] == c_stance : v_rv[1] && v_r[1] == c_stance;
end

//----------------------------------------------------------------------------
// The set move
//----------------------------------------------------------------------------

reg         sel_d;
reg   [5:0] sel_id;
reg         sel_clr;
wire [30:0] rec = fm_rec(sel_id);

reg         m_kind;
reg   [2:0] m_char;
reg   [8:0] m_dmin, m_dmax;
reg   [7:0] m_start;

wire        stage_ok  = (m_kind == K_MKPIT) ? (v_stage == 16'd3) : 1'b1;
wire        too_close = sep < {7'd0, m_dmin};
wire        too_far   = sep > {7'd0, m_dmax};
wire        in_window = sep_ok & ~too_close & ~too_far;
wire        mine      = fin && fin_char == {13'd0, m_char};

//----------------------------------------------------------------------------
// Player
//----------------------------------------------------------------------------

localparam S_IDLE = 2'd0, S_ARMED = 2'd1, S_RUN = 2'd2, S_CHECK = 2'd3;

reg   [1:0] st;
reg         skip;                // this FINISH HIM does not fit the move
reg   [1:0] warned;              // distance messages given this FINISH HIM: [0] too far, [1] too close
reg         own;                 // the controls are the move's
reg   [2:0] settle;
reg   [7:0] ptr;
reg  [15:0] stp;
reg  [12:0] wait_n;
reg   [3:0] tap_n;
reg   [7:0] chk_n;
reg   [8:0] held, tap;           // relative keys {BL, LK, HK, LP, HP, B, F, D, U}
reg         pwho;                // whose controls
reg         begun;               // past the ready point: the move is being entered
reg         ended_in_fin;        // the program ended with FINISH HIM still on

wire        taken = (v_flag != 16'd0) ||
                    (m_kind == K_MKPIT && v_state != 16'd3 && (!ended_in_fin || chk_n > CHECK_FRAMES - PIT_FRAMES));

assign drive = own ? (pwho ? 2'b10 : 2'b01) : 2'b00;

always @(posedge clk) stp <= fm_step(ptr);

wire  [2:0] op       = stp[15:13];
wire  [8:0] arg_keys = stp[8:0];

// relative keys to the port's
wire  [8:0] rk = held | tap;
always @(posedge clk)
	keys <= {rk[8:4],
	         fwd_right ? rk[2] : rk[3],        // Right
	         fwd_right ? rk[3] : rk[2],        // Left
	         rk[1], rk[0]};

// out of the window: a message once per change
wire        warn_far   = sep_ok && too_far   && !warned[0];
wire        warn_close = sep_ok && too_close && !warned[1];
wire        both_ready = opp_dizzy && (fin_stance || held != 9'd0);

always @(posedge clk) begin
	msg_req <= 1'b0;
	sel_d   <= sel;
	sel_id  <= {sel_line, sel_slot[2:0]};
	sel_clr <= (sel_slot == 4'd15);

	if (reset || !game_mk) begin
		st   <= S_IDLE;
		own  <= 1'b0;
		held <= 9'd0;
		tap  <= 9'd0;
	end
	else if (sel_d && c_ok) begin
		own  <= 1'b0;
		held <= 9'd0;
		tap  <= 9'd0;
		skip <= 1'b0;
		if (sel_clr) begin
			if (st != S_IDLE) begin msg_req <= 1'b1; msg <= MSG_CLEARED; end
			st <= S_IDLE;
		end
		else if (rec[30]) begin
			{m_kind, m_char, m_dmin, m_dmax, m_start} <= rec[29:0];
			st <= S_ARMED;
			if (!fin) begin
				msg_req <= 1'b1;
				msg     <= MSG_SET;
			end
			else if (fin_char != {13'd0, rec[28:26]}) begin
				msg_req <= 1'b1;
				msg     <= MSG_NOT_THIS;
			end
		end
	end
	else if (frame) begin
		if (!fin) skip <= 1'b0;

		case (st)
			S_ARMED: begin
				// the move's fighter wins: go when the stage fits
				if (mine && !skip) begin
					if (!stage_ok) begin
						msg_req <= 1'b1;
						msg     <= MSG_MKPIT;
						skip    <= 1'b1;
					end
					else begin
						st     <= S_RUN;
						ptr    <= m_start;
						pwho   <= who;
						wait_n <= 13'd0;
						tap_n  <= 4'd0;
						held   <= 9'd0;
						tap    <= 9'd0;
						settle <= 3'd0;
						warned <= 2'd0;
						begun  <= 1'b0;
					end
				end
			end

			S_RUN: begin
				if (!fin && !begun) begin
					// FINISH HIM over before the move started: it stays set
					msg_req <= 1'b1;
					msg     <= MSG_OVER;
					st      <= S_ARMED;
					own     <= 1'b0;
					held    <= 9'd0;
					tap     <= 9'd0;
				end
				else if (!fin) begin
					// over while it played (The Pit's uppercut, a hit): see what came of it
					st           <= S_CHECK;
					chk_n        <= CHECK_FRAMES;
					ended_in_fin <= 1'b0;
					own          <= 1'b0;
					held         <= 9'd0;
					tap          <= 9'd0;
				end
				else begin
					// a tap's keys go up after its frames
					if (tap_n != 4'd0) tap_n <= tap_n - 4'd1;
					else tap <= 9'd0;

					if (wait_n != 13'd0)
						wait_n <= wait_n - 13'd1;
					else case (op)
						OP_TAP: begin
							tap    <= arg_keys;
							tap_n  <= stp[12:9];
							wait_n <= {9'd0, stp[12:9]} + GAP;
							ptr    <= ptr + 8'd1;
						end
						OP_PRESS: begin
							own  <= 1'b1;
							held <= held | arg_keys;
							ptr  <= ptr + 8'd1;
						end
						OP_RELEASE: begin
							held   <= held & ~arg_keys;
							wait_n <= GAP - 13'd1;
							ptr    <= ptr + 8'd1;
						end
						OP_WAIT: begin
							wait_n <= stp[12:0] - 13'd1;
							ptr    <= ptr + 8'd1;
						end
						OP_READY: begin
							if (!both_ready) begin
								// the loser still reels or gets up, the finisher recovers
							end
							else if (!in_window) begin
								// hand the controls back so the player can move, and
								// start again when it fits
								if (warn_far | warn_close) begin
									msg_req <= 1'b1;
									msg     <= warn_far ? MSG_FAR : MSG_CLOSE;
									warned  <= warned | {warn_close, warn_far};
								end
								own    <= 1'b0;
								held   <= 9'd0;
								settle <= 3'd0;
								ptr    <= m_start;
							end
							else begin
								if (!own) begin
									own    <= 1'b1;            // take over, let the finisher stand
									settle <= SETTLE;
								end
								else if (settle != 3'd0)
									settle <= settle - 3'd1;
								else begin
									wait_n <= 13'd1;
									ptr    <= ptr + 8'd1;
									begun  <= 1'b1;
								end
							end
						end
						default: begin                     // END
							st           <= S_CHECK;
							chk_n        <= CHECK_FRAMES;
							ended_in_fin <= 1'b1;
							own          <= 1'b0;
							held         <= 9'd0;
							tap          <= 9'd0;
						end
					endcase
				end
			end

			S_CHECK: begin
				if (taken)
					st <= S_IDLE;
				else if (chk_n == 8'd0) begin
					msg_req <= 1'b1;
					msg     <= MSG_NOT_TAKEN;
					st      <= S_IDLE;
				end
				else
					chk_n <= chk_n - 8'd1;
			end

			default: ;
		endcase
	end
end

endmodule
