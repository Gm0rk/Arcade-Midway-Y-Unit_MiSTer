//============================================================================
//  sync_center.sv — centred analog sync for a 15 kHz arcade raster
//
//  Copyright (C) 2026 Gm0rk. Distributed under GNU GPL v3 or later.
//
//  Each game programs its own raster, so the picture rarely sits in the
//  middle of a standard 15 kHz line or frame: the HSync and VSync pulses are
//  wherever the board puts them, and the picture is off-centre on a CRT by
//  a few microseconds and a few lines. This module measures where the
//  board's picture is and makes new HSync and VSync pulses at the standard
//  place around it (SMPTE 170M broadcast placement):
//
//   - HSync leading edge 35.75 us before the middle of the picture
//     (4.7 us sync + 4.7 us back porch + half of a 52.7 us line);
//   - VSync leading edge VC = 138 lines before the middle of the active
//     lines (3 + 15 + 120 lines), VSync VW = 3 lines long.
//
//  Only the sync moves: the picture, its blanking and the DE that HDMI and
//  the OSD use are untouched. Ported from the "centred sync" of Arcade-ITech8
//  (it8_sync_center.sv) following its porting notes; this version has one
//  dot rate, set by parameters.
//
//  How it works (everything on the dot enable `ce`):
//   1. `pos` counts dots from the board's HSync leading edge. Each line
//      records its length `len`, the first active dot `a0` (HBlank falls)
//      and the first blank dot after the picture `a1` (HBlank rises).
//   2. The new HSync starts at s = (a0 + a1)/2 - 35.75 us, worked out in
//      doubled units so a half-dot middle stays exact (T2 = 2 x 35.75 us).
//      A negative s, the usual case, wraps into the end of the previous line
//      (len + s), never earlier than a1 so a pulse never starts inside the
//      picture. The pulse is HW dots long.
//   3. Every line VBlank is sampled at dot a0, well clear of the line's
//      edges. Lines are counted from the first active one, giving the frame
//      length `fl` and the number of active lines `na`.
//   4. VSync starts with the new HSync of line na/2 + fl - VC (modulo fl),
//      kept off the picture and with its last line before the next frame's
//      picture. With `vlate` high it starts one line later: CRT Adjust's line
//      buffer sends the picture a line late. While the board blanks whole
//      frames the line count wraps at the measured frame length, so VSync
//      keeps coming at the same rate.
//   5. `vb_out` is the VBlank of the line each new HSync begins, changed
//      together with the pulse. CRT Adjust samples VBlank at HSync, and the
//      new HSync can come before the board's own line starts, so it needs
//      this rather than the board's VBlank.
//   6. Until two lines and two frames have been measured the same, or when
//      the numbers stop making sense (a game reprogramming its raster), the
//      board's own sync passes through and `centred` is low.
//
//  `pic_dots` = a1 - a0, the picture width in dots (0 until measured), is
//  what CRT Auto-Width uses.
//
//  The outputs are registers updated on `ce`, so they change one dot after
//  the dot that decides them; the pulses are therefore triggered on the dot
//  BEFORE their position, and land exactly on it.
//
//  Timing: the measurements change only on `ce` (every 12 clocks at 96 MHz)
//  and most only once a line or a frame, so every value derived from them
//  (pulse position, VSync line, the "next dot" matches, the sanity checks)
//  is worked out in registered steps between two dot enables, a short
//  add or compare per clock instead of one long chain.
//============================================================================

module sync_center #(
	parameter integer T2 = 572,      // 2 x 35.75 us in dots (8 MHz: 572)
	parameter integer HW = 38,       // HSync width in dots (8 MHz: 4.75 us)
	parameter integer VC = 138,      // lines from VSync leading edge to the middle of the picture
	parameter integer VW = 3         // VSync width in lines
)
(
	input             clk,
	input             ce,            // one-clock dot enable; inputs stable while it is high

	input             hs_in,         // board sync and blanking, active high;
	input             vs_in,         // HBlank must mark exactly the visible dots
	input             hb_in,
	input             vb_in,

	input             vlate,         // 1 = VSync one line later (CRT Adjust on)

	output reg        hs_out,        // centred sync (the inputs until measured)
	output reg        vs_out,
	output reg        vb_out,        // VBlank aligned to hs_out, for CRT Adjust's vb_in
	output reg        centred,       // 1 while the new pulses are in use
	output reg [10:0] pic_dots,      // picture width in dots, 0 until measured
	output reg  [9:0] frame_lines    // lines per frame, 0 until measured
);

//----------------------------------------------------------------------------
// Horizontal measurement
//----------------------------------------------------------------------------

reg         hs_d = 1'b0, hb_d = 1'b1;   // previous dot's board signals; hs_d, vs_d and
reg         vs_d = 1'b0, vb_d = 1'b1;   // vb_d are also the pass-through outputs
reg  [10:0] pos = 11'd0;             // position of the previous dot
wire        hs_rise = hs_in & ~hs_d;
wire [10:0] cur = hs_rise ? 11'd0 : pos + 11'd1;   // position of this dot

reg  [10:0] len_m = 11'd0;           // measured line length
reg  [10:0] a0_c = 11'd0;            // this line's first active dot
reg         a0_seen = 1'b0;
reg  [10:0] a0_m = 11'd0, a1_m = 11'd0;   // last line's picture edges
reg   [1:0] lines_ok = 2'd0;         // lines measured the same, saturating at 2

always @(posedge clk) if (ce) begin
	hs_d <= hs_in;
	hb_d <= hb_in;
	vs_d <= vs_in;
	vb_d <= vb_in;
	pos  <= cur;

	if (hs_rise) begin
		if (len_m != pos + 11'd1) lines_ok <= 2'd0;
		len_m   <= pos + 11'd1;
		a0_seen <= 1'b0;
	end

	if (hb_d & ~hb_in) begin                     // HBlank falls: first active dot
		a0_c    <= cur;
		a0_seen <= 1'b1;
	end

	if (~hb_d & hb_in & a0_seen) begin           // HBlank rises: one picture measured
		if (a0_m != a0_c || a1_m != cur) lines_ok <= 2'd0;
		else if (lines_ok != 2'd2)        lines_ok <= lines_ok + 2'd1;
		a0_m <= a0_c;
		a1_m <= cur;
	end
end

// new HSync position: s = (a0 + a1 - T2) / 2, wrapped into the previous
// line when negative but never before a1 (three registered steps)
localparam signed [12:0] T2S = 13'(T2);
reg  signed [12:0] s_r = 13'sd0, s_wrap = 13'sd0;
reg  [10:0] hs_pos = 11'd0;
always @(posedge clk) begin
	s_r    <= ($signed({2'b00, a0_m}) + $signed({2'b00, a1_m}) - T2S) >>> 1;
	s_wrap <= $signed({2'b00, len_m}) + s_r;
	hs_pos <= (s_r >= 0)                              ? s_r[10:0] :
	          (s_wrap < $signed({2'b00, a1_m}))       ? a1_m      : s_wrap[10:0];
end

// The HSync pulse is set on the dot before hs_pos, i.e. when the NEXT dot is
// hs_pos. Both cases are prepared between dot enables from the registered
// position: this dot continues the line (next = pos + 2, or 0 at the line's
// end), or the board's HSync starts here (this dot is 0, next is 1).
reg         go_cont = 1'b0, go_rise = 1'b0;
reg         a0_cont = 1'b0, a0_rise = 1'b0;   // this dot is a0 (VBlank sample)
always @(posedge clk) begin
	go_cont <= (((pos + 11'd2 == len_m) ? 11'd0 : pos + 11'd2) == hs_pos);
	go_rise <= (((len_m == 11'd1) ? 11'd0 : 11'd1) == hs_pos);
	a0_cont <= (pos + 11'd1 == a0_m);
	a0_rise <= (a0_m == 11'd0);
end
wire        hs_go  = hs_rise ? go_rise : go_cont;
wire        a0_hit = hs_rise ? a0_rise : a0_cont;

//----------------------------------------------------------------------------
// Vertical measurement (VBlank sampled at dot a0 of every line)
//----------------------------------------------------------------------------

reg         vb_s = 1'b1;             // VBlank of the last line sampled
reg   [9:0] ln = 10'd0;              // index of the last sampled line, 0 = first active
reg   [9:0] na_c = 10'd0;            // active lines so far this frame
reg   [9:0] fl_m = 10'd0, na_m = 10'd0;
reg   [1:0] frames_ok = 2'd0;

always @(posedge clk) if (ce) begin
	if (a0_hit) begin
		vb_s <= vb_in;
		if (vb_s & ~vb_in) begin                 // first active line of a frame
			if (fl_m != ln + 10'd1 || na_m != na_c) frames_ok <= 2'd0;
			else if (frames_ok != 2'd2)             frames_ok <= frames_ok + 2'd1;
			fl_m <= ln + 10'd1;
			na_m <= na_c;
			ln   <= 10'd0;
			na_c <= 10'd1;
		end
		else begin
			// Once the frame is measured (frames_ok), a frame start that does
			// not come where it is due (the board blanking whole frames)
			// wraps the count into a new frame of the measured length, so the
			// centred VSync keeps its cadence. A frame that returns in step
			// passes the frame check as usual; one that returns elsewhere
			// fails it and is measured again. (Never while measuring: a
			// partial first frame would shrink every frame after it.)
			ln <= (frames_ok == 2'd2 && ln + 10'd1 == fl_m) ? 10'd0 : ln + 10'd1;
			if (!vb_in) na_c <= na_c + 10'd1;
		end
	end

	// a line that measures differently (the game reprogramming its raster)
	// also restarts the frame check, so the centred pulses never come back
	// on new line numbers with the old frame's
	if (lines_ok != 2'd2) frames_ok <= 2'd0;
end

// VSync line, relative to the first active line: na/2 - VC modulo fl,
// then kept between the end of the picture and fl - VW (registered steps)
localparam signed [11:0] VCS = 12'(VC);
wire signed [11:0] fl_s  = $signed({2'b00, fl_m});
reg  signed [11:0] l_raw = 12'sd0, l_mod = 12'sd0;
reg   [9:0] vs_lim  = 10'd0;
reg   [9:0] vs_line = 10'd0;
always @(posedge clk) begin
	l_raw   <= $signed({3'b000, na_m[9:1]}) + fl_s - VCS;
	l_mod   <= (l_raw < 0)     ? l_raw + fl_s :
	           (l_raw >= fl_s) ? l_raw - fl_s : l_raw;
	vs_lim  <= (l_mod < $signed({2'b00, na_m})) ? na_m :
	           (l_mod > fl_s - 12'(VW))         ? fl_m - 10'(VW) : l_mod[9:0];
	vs_line <= vs_lim + {9'd0, vlate};
end

// Index of the line the next new HSync begins (always the line after the
// last sampled one, see the notes above), and what that line needs. ln moves
// at the line's a0 sample, at least 15 dots before the next pulse, so these
// registered results are ready in time.
reg   [9:0] begin_ln = 10'd0;
reg         begin_vb = 1'b1, begin_vs = 1'b0;
always @(posedge clk) begin
	begin_ln <= (ln + 10'd1 >= fl_m) ? ln + 10'd1 - fl_m : ln + 10'd1;
	begin_vb <= (begin_ln >= na_m);
	begin_vs <= (begin_ln == vs_line);
end

//----------------------------------------------------------------------------
// Sanity and outputs
//----------------------------------------------------------------------------

reg sane_h = 1'b0, sane_w = 1'b0, sane_v = 1'b0;
always @(posedge clk) begin
	sane_h <= (len_m >= 11'd128) && (a0_m < a1_m) && (a1_m <= len_m);
	sane_w <= (a1_m - a0_m >= 11'd16);
	sane_v <= (fl_m >= 10'd128) && (na_m >= 10'd16) && (na_m + 10'(VW) < fl_m);
end
wire sane = sane_h & sane_w & sane_v;

reg  [7:0] hcnt = 8'd0;              // HSync dots left
reg  [3:0] vcnt = 4'd0;              // VSync lines left after the first
reg        hs_c = 1'b0, vs_c = 1'b0, vb_c = 1'b1;

always @(posedge clk) if (ce) begin
	centred  <= sane && (lines_ok == 2'd2) && (frames_ok == 2'd2);
	pic_dots <= (lines_ok == 2'd2) ? a1_m - a0_m : 11'd0;
	frame_lines <= (frames_ok == 2'd2) ? fl_m : 10'd0;

	if (hs_go) begin
		hs_c <= 1'b1;
		hcnt <= 8'(HW - 1);
		vb_c <= begin_vb;
		if (begin_vs) begin
			vs_c <= 1'b1;
			vcnt <= 4'(VW - 1);
		end
		else if (vcnt != 4'd0) begin
			vs_c <= 1'b1;
			vcnt <= vcnt - 4'd1;
		end
		else
			vs_c <= 1'b0;
	end
	else if (hcnt != 8'd0)
		hcnt <= hcnt - 8'd1;
	else
		hs_c <= 1'b0;
end

// board sync passes through (one dot late, like the pulses) until measured
always @(*) begin
	hs_out = centred ? hs_c : hs_d;
	vs_out = centred ? vs_c : vs_d;
	vb_out = centred ? vb_c : vb_d;
end

endmodule
