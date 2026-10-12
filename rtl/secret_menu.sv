//============================================================================
//  Hidden developer menus: OSD shortcut
//
//  Three Y Unit games hide a developer menu behind a button code that the
//  game only accepts in attract mode. The OSD items "EJB Menu" and "Octopus
//  Bookkeeping" (Hidden Items page) play the code on the player controls, so
//  it does not have to be entered by hand. The codes were found in the program
//  ROMs and checked against MAME.
//
//  Mortal Kombat (every revision except prototype 4.0): EJB Menu
//    27 presses of P1 Block ('0') and P2 Block ('1'):
//        0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0 0 0
//    Accepted at any time in attract mode. Each press has to follow the
//    previous one within 16 frames or the game starts over.
//    The menu: diagnostic tests, coin bookkeeping, game audits, "Hello",
//    enter initials, character endings.
//
//  Super High Impact (LA2, LA1): Octopus Bookkeeping
//    The same 27 presses on the Action buttons of the two middle players
//    (4 players: P2 = '0', P3 = '1'; 2 players: P1 = '0', P2 = '1').
//    Accepted only while attract mode shows HIGHEST PAID SUPERSTARS (about
//    8 seconds, roughly half a minute into each attract cycle).
//
//  High Impact Football (LA1-LA5): Octopus Bookkeeping
//    Two switch combinations in attract mode. Each has to be exact: no
//    other player switch may be closed.
//      4 players: hold P2 Down + P3 Up and press P3 Action (held over 48
//                 frames); release; within 64 frames hold P2 Right + P3 Left
//                 and press P2 Action.
//      2 players: the same with P1 Down + P2 Up + P2 Action, then
//                 P1 Right + P2 Left + P1 Action.
//
//  Timing. A code step is 3 frames pressed and 3 released (the games read
//  their switches once a frame; MAME accepts 2 + 3). High Impact runs the
//  schedule MAME was checked with:
//      frame   0- 99  stage 1 directions
//      frame  20- 99  stage 1 Action
//      frame 110-189  stage 2 directions
//      frame 120-189  stage 2 Action
//  Frames are counted on the "frame" strobe, which the top level gives only
//  while the game runs, so with "Pause when OSD is open" the code plays once
//  the OSD is closed.
//
//  While "active" is set the top level replaces the player controls with
//  in0/in1 (active-high port images, same bits as the MAME input ports) and
//  releases every other player switch, so a held stick cannot spoil a code.
//
//  Messages. The MRA sends where the set keeps its game state word (ROM
//  index 1 words 0x30-0x34, tools/yunit_fmoves.py), and the module follows
//  it through the CPU's writes (the board's dbg_wr). Mortal Kombat is in its
//  attract mode while the word is 1, High Impact while it is 4, Super High
//  Impact shows HIGHEST PAID SUPERSTARS while it is 4 and the attract page
//  word is 1; every menu sets it to 12. A trigger at another time does not
//  play the code and says when it works (when_attract / when_shi); a code
//  played is followed by ok (the menu opened during the code or the 90
//  frames after it) or fail. Word 0x34: 0 no data (an older MRA: the code
//  plays, no messages), 1 the set has the menu, 2 it does not (not_here).
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module secret_menu
(
	input             clk,
	input             reset,

	input             frame,         // one clock at the start of each running frame
	input             trigger,       // OSD item (the code starts on its rising edge)
	input       [1:0] game,          // 0 none, 1 Mortal Kombat, 2 Super High Impact,
	                                 // 3 High Impact Football
	input             four_p,        // High Impact "Players" DIP set to 4

	// ROM index 1 words 0x30-0x34: the game state word
	input             dl_start,      // pulse: ROM index 1 is about to arrive
	input             dl_wr,
	input       [2:0] dl_addr,
	input      [15:0] dl_data,

	// CPU writes (the board's dbg_wr, dbg_wa, dbg_wdata)
	input             cpu_wr,
	input      [27:0] cpu_wa,
	input      [15:0] cpu_wd,

	output reg        active,        // the code owns the player controls
	output reg [15:0] in0,           // port 0 image (active high)
	output reg [15:0] in1,           // port 1 image (active high), bits 9-15 used

	// one clock each: the menu opened / did not, the trigger came at the
	// wrong time (attract mode; Super High Impact: HIGHEST PAID SUPERSTARS),
	// the loaded revision has no menu
	output reg        ok,
	output reg        fail,
	output reg        when_attract,
	output reg        when_shi,
	output reg        not_here
);

localparam GM_NONE = 2'd0, GM_MK = 2'd1, GM_SHI = 2'd2, GM_HI = 2'd3;

// the 27-press code, first press in bit 0:
// 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0 0 0 read right to left
localparam [26:0] CODE = 27'b000011100100111111111100000;

reg        trig_d;
reg  [7:0] t;                        // frames since the start (High Impact)
reg  [2:0] ph;                       // frame within a code step, 0-5
reg  [4:0] k;                        // code step, 0-26

//----------------------------------------------------------------------------
// The game state word (CPU writes)
//----------------------------------------------------------------------------

reg [27:0] c_state, c_page;          // word addresses
reg  [1:0] c_mode;                   // word 0x34
reg        w_v;
reg [27:0] w_a;
reg [15:0] w_d;
reg [15:0] v_state, v_page;

always @(posedge clk) begin
	w_v <= cpu_wr;
	w_a <= cpu_wa;
	w_d <= cpu_wd;

	if (dl_start) begin
		c_state <= 28'd0;
		c_page  <= 28'd0;
		c_mode  <= 2'd0;
	end
	else if (dl_wr) begin
		case (dl_addr)
			3'd0: c_state[15:0]  <= dl_data;
			3'd1: c_state[27:16] <= dl_data[11:0];
			3'd2: c_page[15:0]   <= dl_data;
			3'd3: c_page[27:16]  <= dl_data[11:0];
			3'd4: c_mode         <= dl_data[1:0];
			default: ;
		endcase
	end

	if (reset) begin
		v_state <= 16'd0;
		v_page  <= 16'd0;
	end
	else if (w_v) begin
		if (w_a == c_state && c_state != 28'd0) v_state <= w_d;
		if (w_a == c_page  && c_page  != 28'd0) v_page  <= w_d;
	end
end

localparam [15:0] ST_MENU = 16'd12;

wire state_ok = (game == GM_MK)  ? (v_state == 16'd1) :
                (game == GM_SHI) ? (v_state == 16'd4 && v_page == 16'd1) :
                                   (v_state == 16'd4);

//----------------------------------------------------------------------------
// Sequencer: start on the OSD trigger, advance once per running frame
//----------------------------------------------------------------------------

wire last_frame = (game == GM_HI) ? (t == 8'd199) : (k == 5'd26 && ph == 3'd5);

reg        watch;                    // waiting for the menu
reg        seen;                     // the menu opened
reg  [6:0] after;                    // frames left to wait after the code

always @(posedge clk) begin
	trig_d       <= trigger;
	ok           <= 1'b0;
	fail         <= 1'b0;
	when_attract <= 1'b0;
	when_shi     <= 1'b0;
	not_here     <= 1'b0;

	if (reset) begin
		active <= 1'b0;
		watch  <= 1'b0;
	end
	else if (trigger & ~trig_d & (game != GM_NONE)) begin
		if (c_mode == 2'd2)
			not_here <= 1'b1;
		else if (c_mode == 2'd1 && !state_ok) begin
			when_attract <= (game != GM_SHI);
			when_shi     <= (game == GM_SHI);
		end
		else begin
			// (re)start from the first step
			active <= 1'b1;
			watch  <= (c_mode == 2'd1);
			seen   <= 1'b0;
			after  <= 7'd90;
			t      <= 8'd0;
			ph     <= 3'd0;
			k      <= 5'd0;
		end
	end
	else begin
		if (watch && v_state == ST_MENU && !seen) begin
			seen <= 1'b1;
			ok   <= 1'b1;
		end

		if (active && frame) begin
			if (last_frame) active <= 1'b0;
			t <= t + 8'd1;
			if (ph == 3'd5) begin
				ph <= 3'd0;
				k  <= k + 5'd1;
			end
			else
				ph <= ph + 3'd1;
		end
		else if (watch && !active && frame) begin
			if (seen)
				watch <= 1'b0;
			else if (after == 7'd0) begin
				watch <= 1'b0;
				fail  <= 1'b1;
			end
			else
				after <= after - 7'd1;
		end
	end
end

//----------------------------------------------------------------------------
// Switch images
//----------------------------------------------------------------------------

// code games: which of the two buttons is down this frame
wire push = (ph < 3'd3);
wire b0   = push & ~CODE[k];         // '0' button
wire b1   = push &  CODE[k];         // '1' button

// High Impact: the two stages
wire s1dir = (t < 8'd100);
wire s1btn = (t >= 8'd20)  && (t < 8'd100);
wire s2dir = (t >= 8'd110) && (t < 8'd190);
wire s2btn = (t >= 8'd120) && (t < 8'd190);

// High Impact port bits (MAME layout): port 0 = P1 {Action, R, L, D, U} in
// bits 4-0 and P2 in bits 12-8; port 1 = P3 {Action, R, L, D, U} in bits 15-11.
always @(*) begin
	in0 = 16'h0000;
	in1 = 16'h0000;

	case (game)
		GM_MK: begin
			in0[5]  = b0;                        // P1 Block
			in0[13] = b1;                        // P2 Block
		end
		GM_SHI: begin
			if (four_p) begin
				in0[12] = b0;                    // P2 Action
				in1[15] = b1;                    // P3 Action
			end
			else begin
				in0[4]  = b0;                    // P1 Action
				in0[12] = b1;                    // P2 Action
			end
		end
		GM_HI: begin
			if (four_p) begin
				in0[9]  = s1dir;                 // P2 Down
				in1[11] = s1dir;                 // P3 Up
				in1[15] = s1btn;                 // P3 Action
				in0[11] = s2dir;                 // P2 Right
				in1[13] = s2dir;                 // P3 Left
				in0[12] = s2btn;                 // P2 Action
			end
			else begin
				in0[1]  = s1dir;                 // P1 Down
				in0[8]  = s1dir;                 // P2 Up
				in0[12] = s1btn;                 // P2 Action
				in0[3]  = s2dir;                 // P1 Right
				in0[10] = s2dir;                 // P2 Left
				in0[4]  = s2btn;                 // P1 Action
			end
		end
		default: ;
	endcase
end

endmodule
