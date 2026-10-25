//============================================================================
//  yunit_crt.sv — analog CRT output stage for the Y Unit core
//
//  Copyright (C) 2026 Gm0rk. Distributed under GNU GPL v3 or later.
//
//  Everything between the board's video and the core's analog output that
//  makes the picture sit right on a 15 kHz CRT:
//
//   - centred sync (sync_center): new HSync/VSync placed around the board's
//     picture at the broadcast position. Always used for the analog sync,
//     with or without CRT Adjust; HDMI sees the same picture as before
//     (only the sync moves).
//   - CRT Adjust (rmonic79's crt_adjust, content-shift mode) fed with the
//     centred sync, so H-Position and V-Shift 0 are the centre of the screen.
//   - H-Size about the middle: CRT Adjust stretches from HSync, so a centring
//     table moves the content back by -m x H / (base + H) dots.
//   - CRT V-Size (rmonic79's crt_vsize, experimental): vertical size, between
//     the centred sync and CRT Adjust. PVM mode retimes the line count per
//     frame (every line kept, HSync moves about 0.35 % per line); Cabinet
//     mode keeps the timing native and resamples the lines (gamma-correct
//     blend of two neighbours).
//   - the OSD/HDMI window (DE) while CRT Adjust is on.
//
//  Ported from Arcade-ITech8 following its porting notes ("CRT Adjust and
//  Auto-Width: Porting Handoff"; the Auto-Width part is not used). The Y Unit
//  has one dot rate, 8 MHz, on the 96 MHz clk, so the constants are ITech8's
//  8 MHz set:
//    base 48 (4 x 12 clocks per dot), T2 572, HW 38, m 286,
//    line 506 dots, frame 289 lines.
//
//  Read clock: CRT Adjust reads one source dot every (base + h_eff)
//  quarter-clocks, so a dot lasts (48 + h_eff) / 384 us (12 clocks at 0).
//  The accumulator restarts on the rise of crt_adjust's hs_ref_out so the
//  read rate and its read counter start on the same edge.
//============================================================================

module yunit_crt
(
	input             clk,           // 96 MHz video clock
	input             ce_pix,        // 8 MHz dot enable

	// OSD settings
	input             crt_en,        // CRT Adjust on
	input             scandoubler,   // any scandoubler effect: CRT Adjust off (read rate assumes 15 kHz)
	input       [4:0] hsize_osd,     // H-Size, 5-bit two's complement
	input       [6:0] hpos_osd,      // H-Position: 0..48 = 0..+48, 49..96 = -48..-1
	input       [4:0] vshift_osd,    // V-Shift, 5-bit two's complement
	input       [3:0] vsize_osd,     // V-Size steps: 0..7 = 0..+7, 8..14 = -7..-1 ("+" = taller)
	input             vsize_cab,     // V-Size mode: 0 PVM (line retimer), 1 Cabinet (native timing)

	// board video (RGB after overlays), active-high sync and blanking
	input       [7:0] r_in,
	input       [7:0] g_in,
	input       [7:0] b_in,
	input             hs_in,
	input             vs_in,
	input             hb_in,
	input             vb_in,

	// centred sync for the native path (arcade_video)
	output            c_hs,
	output            c_vs,

	// CRT Adjust path
	output reg        crt_on,
	output            rd_ce,         // CE_PIXEL while CRT Adjust is on
	output      [7:0] r_out,
	output      [7:0] g_out,
	output      [7:0] b_out,
	output            hs_out,
	output            vs_out,
	output reg        de_osd,        // VGA_DE_IN for video_freak while CRT Adjust is on

	// status, for simulation and debugging
	output            centred,
	output     [10:0] pic_dots,
	output reg signed [6:0] h_eff,
	output            str_act        // CRT Adjust's picture area (~hb_out)
);

localparam [7:0] RD_BASE = 8'd48;    // 4 x 96 MHz / 8 MHz

//----------------------------------------------------------------------------
// Settings, latched on the dot enable
//----------------------------------------------------------------------------

reg  signed [4:0] hsize_s;
reg         [6:0] hpos_d;
reg  signed [5:0] vshift_s;
reg  signed [5:0] vsize_s;           // crt_vsize's lines added to the frame (+ = shorter)
reg               vsize_cab_q;
// V-Size: one OSD step is 3 lines (about 1 %), the OSD's "+" makes the
// picture taller (crt_vsize's +N makes it shorter, hence the minus). The OSD
// list has 15 entries, so 8..14 are -7..-1 (not 4-bit two's complement):
// +-7 steps = +-21 lines, the most crt_vsize's 46-line ring takes.
wire signed [4:0] vsize_step = (vsize_osd <= 4'd7) ? $signed({1'b0, vsize_osd})
                                                   : $signed({1'b0, vsize_osd}) - 5'sd15;
always @(posedge clk) if (ce_pix) begin
	crt_on      <= crt_en & ~scandoubler;
	hsize_s     <= $signed(hsize_osd);
	hpos_d      <= hpos_osd;
	vshift_s    <= $signed({vshift_osd[4], vshift_osd});
	vsize_s     <= -($signed({vsize_step[4], vsize_step}) * 6'sd3);
	vsize_cab_q <= vsize_cab;
end

// H-Position: 0..48 right, 49..96 = -48..-1 left
wire signed [8:0] hpos_usr = (hpos_d <= 7'd48) ? $signed({2'b00, hpos_d})
                                               : $signed({2'b00, hpos_d}) - 9'sd97;

//----------------------------------------------------------------------------
// Centred sync
//----------------------------------------------------------------------------

wire c_vb;

wire [9:0] fr_lines;               // measured lines per frame (0 until measured)

sync_center #(.T2(572), .HW(38), .VC(138), .VW(3)) sync_center
(
	.clk      (clk),
	.ce       (ce_pix),
	.hs_in    (hs_in),
	.vs_in    (vs_in),
	.hb_in    (hb_in),
	.vb_in    (vb_in),
	.vlate    (crt_on),              // CRT Adjust sends the picture a line late
	.hs_out   (c_hs),
	.vs_out   (c_vs),
	.vb_out   (c_vb),
	.centred  (centred),
	.pic_dots (pic_dots),
	.frame_lines (fr_lines)
);

//----------------------------------------------------------------------------
// H-Size in use: the OSD's value (-16..+15), sign-extended
//----------------------------------------------------------------------------

initial h_eff = 7'sd0;
always @(posedge clk) h_eff <= {{2{hsize_s[4]}}, hsize_s};

//----------------------------------------------------------------------------
// Read clock: one dot every (base + h_eff) quarter-clocks
//----------------------------------------------------------------------------

wire       hs_ref;
reg        hs_ref_d;
always @(posedge clk) hs_ref_d <= hs_ref;
wire       hs_ref_rise = hs_ref & ~hs_ref_d;

reg  [7:0] rd_period = RD_BASE;
always @(posedge clk) rd_period <= RD_BASE + {h_eff[6], h_eff};
reg  [7:0] rd_acc = 8'd0;
wire       rd_tick = (rd_acc + 8'd4) >= rd_period;
always @(posedge clk) begin
	if (hs_ref_rise)  rd_acc <= 8'd0;
	else if (rd_tick) rd_acc <= rd_acc + 8'd4 - rd_period;
	else              rd_acc <= rd_acc + 8'd4;
end
assign rd_ce = crt_on ? rd_tick : ce_pix;

//----------------------------------------------------------------------------
// H-Size about the middle: CRT Adjust stretches the line from HSync, which
// would move a wider picture right (from about +5 its right edge passed the
// next HSync). HMID[H] = round(-m x H / (base + H)) dots, m = 286 (35.75 us,
// the picture's middle after the centred HSync), for H = -16..+31, 9-bit
// signed, H = +31 first; index H + 16. The -1 makes up for the dot CRT
// Adjust's read pipeline adds.
//----------------------------------------------------------------------------

localparam [48*9-1:0] HMID = {
	9'h190, 9'h192, 9'h194, 9'h197, 9'h199, 9'h19C, 9'h19E, 9'h1A1,
	9'h1A3, 9'h1A6, 9'h1A9, 9'h1AC, 9'h1AF, 9'h1B2, 9'h1B5, 9'h1B8,
	9'h1BC, 9'h1BF, 9'h1C3, 9'h1C7, 9'h1CB, 9'h1CF, 9'h1D3, 9'h1D7,
	9'h1DC, 9'h1E0, 9'h1E5, 9'h1EA, 9'h1EF, 9'h1F5, 9'h1FA, 9'h000,
	9'h006, 9'h00C, 9'h013, 9'h01A, 9'h021, 9'h029, 9'h031, 9'h039,
	9'h042, 9'h04B, 9'h055, 9'h05F, 9'h06A, 9'h076, 9'h082, 9'h08F
};

wire        [5:0] h_idx = 6'(h_eff + 7'sd16);
reg  signed [8:0] hmid = 9'sd0;
reg  signed [8:0] hpos_off = 9'sd0;
always @(posedge clk) begin
	hmid     <= $signed(HMID[h_idx * 9 +: 9]);
	hpos_off <= hpos_usr + hmid - 9'sd1;
end

//----------------------------------------------------------------------------
// CRT V-Size (experimental), first stage of the CRT Adjust chain: centred
// stream -> crt_vsize -> crt_adjust. It measures everything itself (frame
// and line periods, dot period, sync widths, picture window) and is a
// registered pass-through (one dot later) while CRT Adjust is off, V-Size
// is 0 or the measurement is not yet stable. Everything after it runs on
// its stream, including its dot enable and its regenerated VBlank.
//   ring: 46 lines (|V-Size| <= 21 lines) x 416 dots (widest picture 410)
//----------------------------------------------------------------------------

wire [7:0] vz_r, vz_g, vz_b;
wire       vz_hs, vz_vs, vz_de, vz_vb, vz_ce;

crt_vsize #(
	.RING_LINES (46),
	.LINE_PX    (416)
) crt_vsize (
	.clk        (clk),
	.pxl_cen    (ce_pix),            // 8 MHz on 96 MHz: 12 clocks a dot (needs >= 8)
	.active     (crt_on),
	.tube_mode  (vsize_cab_q),
	.vsize      (vsize_s),
	.r_in       (r_in),
	.g_in       (g_in),
	.b_in       (b_in),
	.hs_in      (c_hs),
	.vs_in      (c_vs),
	.de_in      (~(hb_in | vb_in)),
	.vb_in      (c_vb),              // the true VBlank (centred), never ~DE
	.r_out      (vz_r),
	.g_out      (vz_g),
	.b_out      (vz_b),
	.hs_out     (vz_hs),
	.vs_out     (vz_vs),
	.de_out     (vz_de),
	.vb_out     (vz_vb),
	.ce_out     (vz_ce)
);

// Lines per frame of that stream, for CRT Adjust's negative V-Shift (a delay
// of frame - N lines): PVM V-Size changes the count. HSync rises from one
// VSync rise to the next; an HSync rising with VSync starts the new frame.
reg       vz_hs_d = 1'b0, vz_vs_d = 1'b0;
reg [9:0] vz_lc = 10'd0, vz_lines = 10'd0;
always @(posedge clk) if (vz_ce) begin
	vz_hs_d <= vz_hs;
	vz_vs_d <= vz_vs;
	if (vz_vs & ~vz_vs_d) begin
		vz_lines <= vz_lc;
		vz_lc    <= (vz_hs & ~vz_hs_d) ? 10'd1 : 10'd0;
	end
	else if (vz_hs & ~vz_hs_d && vz_lc != 10'h3FF)
		vz_lc <= vz_lc + 10'd1;
end

//----------------------------------------------------------------------------
// CRT Adjust, fed with the centred sync (through crt_vsize). Its line buffer
// samples VBlank at HSync, which now comes before the board's own line
// starts, so VBlank comes from sync_center (vb_out, passed on by crt_vsize)
// to keep the first picture line.
// VTOTAL sizes its V-Shift line register: 289 lines + 21 for the shortest
// V-Size picture (PVM adds lines).
//----------------------------------------------------------------------------

wire       str_hb, str_vb;
wire [7:0] str_r, str_g, str_b;

crt_adjust #(
	.VTOTAL    (312),
	.HTOTAL    (506),
	.HPOS_MODE (1)                   // content shift: the Y Unit picture is wide
) crt_adjust (
	.clk        (clk),
	.pxl_cen    (vz_ce),
	.pxl2_cen   (rd_ce),
	.active     (crt_on),
	.hsize      (h_eff[4:0]),        // not used inside (the read rate comes from rd_ce)
	.hoffset    (hpos_off),
	.voffset    (vshift_s),
	.vtotal_in  (vz_lines),          // 57 Hz video timing and PVM V-Size change the frame
	.r_in       (vz_r),
	.g_in       (vz_g),
	.b_in       (vz_b),
	.hs_in      (vz_hs),
	.vs_in      (vz_vs),
	.hb_in      (~vz_de),
	.vb_in      (vz_vb),
	.r_out      (str_r),
	.g_out      (str_g),
	.b_out      (str_b),
	.hs_out     (hs_out),
	.vs_out     (vs_out),
	.hb_out     (str_hb),
	.vb_out     (str_vb),
	.hs_ref_out (hs_ref)
);

//----------------------------------------------------------------------------
// OSD/HDMI window while CRT Adjust is on: CRT Adjust's own picture area.
// ITech8 used the native active area OR CRT Adjust's; on the Y Unit the
// native area is a line earlier than CRT Adjust's (late) picture and, when a
// negative H-Size narrows the picture, wider than it, so the union added a
// black line and black columns to the HDMI frame. CRT Adjust's area follows the
// picture through every H-Size, H-Position and V-Shift, and the frame inside
// it is the plain picture, dot for dot.
//----------------------------------------------------------------------------

//
// Room on the line: the Y Unit picture fills about 81 % of its 63.25 us line
// and its middle is 35.75 us after HSync, so it can reach at most 27.5 us
// right of the middle before the next HSync (Smash T.V., 410 dots: about
// H-Size +3, or H-Position +12 at H-Size 0). Beyond that its right edge is
// cut where the line ends, and the dot being read when the next HSync starts
// would go out during sync; picture and window are blanked while HSync is
// high so nothing is ever sent during sync.
//
//----------------------------------------------------------------------------

// VSync on the picture. With the board's own 289-line frame there are 33
// blank lines; the 57 Hz video timing leaves 21, so a V-Shift can put
// VSync on the picture. The picture is then split:
// lines after VSync are drawn at the top of the new field, lines before it
// at the bottom of the old one. The smaller part would wrap to the wrong
// edge of the screen (and the HDMI frame would wrap the same way), so it is
// blanked: lines from VSync on when VSync is in the lower half of the
// picture, lines before VSync when it is in the upper half. The position is
// measured on one picture and used on the next (it only moves with a
// setting). Lines are counted at the end of HSync; a line is a picture line
// when CRT Adjust's picture area was open in it.
reg        hs_out_d = 1'b0, vs_line = 1'b0, seen = 1'b0, seen_prev = 1'b0;
reg  [8:0] pl = 9'd0;                // picture line index of the current line
reg  [8:0] np_c = 9'd0, np_m = 9'd0; // picture lines (this one / last one)
reg  [8:0] vp_c = 9'd0, vp_m = 9'd0; // VSync's line inside the picture
reg        vi_c = 1'b0, vi_m = 1'b0; // VSync came inside the picture
always @(posedge clk) begin
	hs_out_d <= hs_out;
	if (~str_hb) seen <= 1'b1;
	if (~hs_out & hs_out_d) begin                  // end of HSync: a new line
		seen      <= 1'b0;
		seen_prev <= seen;
		vs_line   <= vs_out;
		pl        <= seen ? pl + 9'd1 : 9'd0;
		if (seen) np_c <= pl + 9'd1;
		if (vs_out & ~vs_line & seen) begin         // VSync starts right after a picture line
			vp_c <= pl + 9'd1;
			vi_c <= 1'b1;
		end
		if (~seen & seen_prev) begin                // the picture ended on the line before
			np_m <= np_c;
			vp_m <= vp_c;
			vi_m <= vi_c;
			vi_c <= 1'b0;
		end
	end
end
wire vcut = vi_m && ((vp_m > {1'b0, np_m[8:1]}) ? (pl >= vp_m) : (pl < vp_m));

wire str_vis = ~str_hb & ~hs_out & ~vs_out & ~vcut;
assign r_out   = str_vis ? str_r : 8'd0;
assign g_out   = str_vis ? str_g : 8'd0;
assign b_out   = str_vis ? str_b : 8'd0;
assign str_act = str_vis;
always @(posedge clk) de_osd <= str_vis;

endmodule
