//============================================================================
//  yunit_window - Mortal Kombat's Move List window
//
//  With the OSD's "Move List" set to a fighter, this draws the page with that
//  fighter over the picture: the game's title screen, dimmed, and on it a
//  grid of 56 x 30 characters (7 x 8 dots each, the MiSTer OSD's font),
//  centred in the 400 x 254 picture. Two pages, four fighters then three, as
//  in the T-Unit core. tools/yunit_window.py writes the pages and the
//  background as ROM images. A row is a list of segments, runs of text in
//  one colour at a column:
//
//    row   256 x 8: {page, row} -> the row's first segment (0: empty)
//    seg   256 x 26: [10:0] the segment's first character in the text ROM,
//          [16:11] its length, [22:17] its column, [24:23] its colour
//          (0 white, 1 yellow, 2 cyan, 3 gray), [25] the row's last one
//    text  2048 x 7: the character codes - 32
//    font  768 x 8: {code - 32, glyph row} -> the row's dots, bit x column x
//    bg    127 x 200 x 5: the background at half the picture's resolution,
//          a palette index per 2 x 2 dots
//    pal   32 x 24: index -> RGB, already dimmed
//
//  The board's video changes with each ce_pix (every 12 clocks); the
//  counters here follow it so that they always name the dot on the outputs
//  now. While a character cell is on screen the next one is fetched (its
//  segment, character and glyph row: about 10 clocks of the 12 x 7 a cell
//  has), and taken over when the cell ends; in the horizontal blanking the
//  row's first segment and the line's first cell are. The background of the
//  next dot is read all the time (7 clocks) and taken over with it.
//  The picture goes through unchanged (same clock, no delay) when the window
//  is off, and the timing signals always do.
//
//  The T-Unit core's information window (Arcade-Midway-T-Unit,
//  rtl/tunit_window.sv) with one background and the Move List's pages only.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_window #(
	parameter ROW_HEX  = "rtl/yunit_window_row.hex",
	parameter SEG_HEX  = "rtl/yunit_window_seg.hex",
	parameter TEXT_HEX = "rtl/yunit_window_text.hex",
	parameter FONT_HEX = "rtl/yunit_window_font.hex",
	parameter BG_HEX   = "rtl/yunit_window_bg.hex",
	parameter PAL_HEX  = "rtl/yunit_window_pal.hex",
	parameter X0       = 4,          // the grid's first dot in the line
	parameter Y0       = 7           // the grid's first line in the picture
)
(
	input            clk,
	input            ce_pix,
	input            enable,         // the window is shown
	input      [2:0] page,           // the page (rtl/yunit_window_pages.svh)

	input      [7:0] r_in,
	input      [7:0] g_in,
	input      [7:0] b_in,
	input            hb_in,
	input            vb_in,

	output     [7:0] r_out,
	output     [7:0] g_out,
	output     [7:0] b_out
);

localparam COLS = 56, ROWS = 30, CW = 7, CH = 8;
localparam BG_W = 200, BG_H = 127;
// a line starts in cell CX0 (before the grid; X0 >= 1), at its dot PX0
localparam integer PX0 = (CW - X0 % CW) % CW;
localparam integer CX0 = -((X0 + CW - 1) / CW);

//----------------------------------------------------------------------------
// ROMs
//----------------------------------------------------------------------------

reg  [7:0] row_rom  [0:255];
reg [25:0] seg_rom  [0:255];
reg  [6:0] text_rom [0:2047];
reg  [7:0] font_rom [0:767];
(* max_depth = 2048 *)                   // 2048 x 5 blocks: 13 M10K
reg  [4:0] bg_rom   [0:BG_W * BG_H - 1];
reg [23:0] pal_rom  [0:31];

initial begin
	$readmemh(ROW_HEX, row_rom);
	$readmemh(SEG_HEX, seg_rom);
	$readmemh(TEXT_HEX, text_rom);
	$readmemh(FONT_HEX, font_rom);
	$readmemh(BG_HEX, bg_rom);
	$readmemh(PAL_HEX, pal_rom);
end

reg  [7:0] row_a;
reg  [7:0] seg_a;
reg [10:0] text_a;
reg  [9:0] font_a;
reg [14:0] bg_a;
reg  [4:0] pal_a;
reg  [7:0] row_q;
reg [25:0] seg_q;
reg  [6:0] text_q;
reg  [7:0] font_q;
reg  [4:0] bg_q;
reg [23:0] pal_q;

always @(posedge clk) begin
	row_q  <= row_rom[row_a];
	seg_q  <= seg_rom[seg_a];
	text_q <= text_rom[text_a];
	font_q <= font_rom[font_a];
	bg_q   <= bg_rom[bg_a];
	pal_q  <= pal_rom[pal_a];
end

//----------------------------------------------------------------------------
// The dot on the outputs. At each ce_pix the inputs still show the dot that
// ends: a blanked one starts the line again, the first blanked one after
// the picture ends a line.
//----------------------------------------------------------------------------

reg        hb_q;
reg  [8:0] y;                    // the line of the picture
reg  [8:0] dx;                   // the dot of the line
reg  [2:0] px;                   // the dot in the cell
reg  [6:0] cx;                   // the cell (negative before the grid)
reg        line_end;             // one clock: a line ended (fetch the first cell)
reg        cell_start;           // one clock: a cell started (fetch the next)

always @(posedge clk) begin
	line_end   <= 1'b0;
	cell_start <= 1'b0;
	if (ce_pix) begin
		hb_q <= hb_in;
		if (vb_in)
			y <= 9'd0;
		else if (hb_in & ~hb_q)
			y <= y + 9'd1;
		dx <= hb_in ? 9'd0 : dx + 9'd1;
		if (hb_in) begin
			px <= 3'(PX0);
			cx <= 7'(CX0);
			if (~hb_q)
				line_end <= 1'b1;
		end
		else if (px == 3'(CW - 1)) begin
			px <= 3'd0;
			cx <= cx + 7'd1;
			cell_start <= 1'b1;
		end
		else
			px <= px + 3'd1;
	end
end

wire [8:0] gy  = y - 9'(Y0);
wire [4:0] row = gy[7:3];
wire [2:0] ly  = gy[2:0];
wire       row_ok = (y >= 9'(Y0)) && (gy < 9'(ROWS * CH));

//----------------------------------------------------------------------------
// Fetch the next cell. At a line's end its row's first segment is read; for
// each cell the segments that end before it are passed over, then its
// character and glyph row are read.
//----------------------------------------------------------------------------

localparam F_IDLE = 4'd0, F_ROW = 4'd1, F_ROWQ = 4'd2, F_SEG = 4'd3, F_SEGQ = 4'd4,
           F_CELL = 4'd5, F_TEXT = 4'd6, F_TEXTQ = 4'd7, F_FONT = 4'd8, F_FONTQ = 4'd9;

reg  [3:0] fs;
reg  [6:0] f_col;                // the cell fetched (negative: before the grid)
reg        f_on;
reg  [1:0] f_colour;
reg        empty;                // the row has no segments
reg [10:0] s_text;               // the segment
reg  [5:0] s_len, s_col;
reg  [1:0] s_colour;
reg        s_last;
reg  [7:0] nx_dots, cur_dots;
reg  [1:0] nx_colour, cur_colour;

wire [6:0] s_end = {1'b0, s_col} + {1'b0, s_len};
wire [6:0] s_rel = f_col - {1'b0, s_col};
wire       f_neg = f_col[6];

always @(posedge clk) begin
	case (fs)
		F_IDLE:
			if (line_end) begin
				f_col <= cx + 7'd1;
				row_a <= {page, row};
				fs    <= F_ROW;
			end
			else if (cell_start) begin
				f_col <= cx + 7'd1;
				fs    <= F_CELL;
			end
		F_ROW:  fs <= F_ROWQ;
		F_ROWQ: begin
			empty <= row_q == 8'd0;
			seg_a <= row_q;
			fs    <= F_SEG;
		end
		F_SEG:  fs <= F_SEGQ;
		F_SEGQ: begin
			{s_last, s_colour, s_col, s_len, s_text} <= seg_q;
			fs <= F_CELL;
		end
		F_CELL:
			if (!empty && !s_last && !f_neg && f_col >= s_end) begin
				seg_a <= seg_a + 8'd1;           // past this segment: the next
				fs    <= F_SEG;
			end
			else begin
				f_on     <= row_ok && !empty && !f_neg && f_col < 7'(COLS) &&
				            f_col >= {1'b0, s_col} && f_col < s_end;
				f_colour <= s_colour;
				text_a   <= s_text + {5'd0, s_rel[5:0]};
				fs       <= F_TEXT;
			end
		F_TEXT:  fs <= F_TEXTQ;
		F_TEXTQ: begin
			font_a <= {text_q, ly};
			fs     <= F_FONT;
		end
		F_FONT:  fs <= F_FONTQ;
		F_FONTQ: begin
			nx_dots   <= f_on ? font_q : 8'd0;
			nx_colour <= f_colour;
			fs        <= F_IDLE;
		end
		default: fs <= F_IDLE;
	endcase

	// the fetched cell comes on screen
	if (ce_pix && !hb_in && px == 3'(CW - 1)) begin
		cur_dots   <= nx_dots;
		cur_colour <= nx_colour;
	end
end

//----------------------------------------------------------------------------
// Background: the next dot's (the first of the line while blanked) is read
// every clock, line y / 2, dot / 2; its colour is taken over with the dot.
// The line's start in the ROM (y / 2 x 200) is a stage of its own; it only
// changes in the horizontal blanking.
//----------------------------------------------------------------------------

wire [8:0] nx_dx = hb_in ? 9'd0 : dx + 9'd1;
reg  [6:0] by;
reg  [7:0] bx;
reg [14:0] by_base;
reg [23:0] nx_bg, cur_bg;

always @(posedge clk) begin
	by      <= (y[7:1] < 7'(BG_H)) ? y[7:1] : 7'(BG_H - 1);
	bx      <= (nx_dx[8:1] < 8'(BG_W)) ? nx_dx[8:1] : 8'(BG_W - 1);
	by_base <= {1'b0, by, 7'd0} + {2'b0, by, 6'd0} + {5'd0, by, 3'd0};   // y / 2 x 200
	bg_a    <= by_base + {7'd0, bx};
	pal_a   <= bg_q;
	nx_bg   <= pal_q;
	if (ce_pix)
		cur_bg <= nx_bg;
end

//----------------------------------------------------------------------------
// Out: the text over the background
//----------------------------------------------------------------------------

wire pic = ~hb_in & ~vb_in;
wire dot = cur_dots[px] & pic;

reg [23:0] ink;
always @(*) begin
	case (cur_colour)
		2'd0: ink = 24'hFFFFFF;    // white
		2'd1: ink = 24'hFFE040;    // yellow
		2'd2: ink = 24'h60E0FF;    // cyan
		default: ink = 24'hA0A0A0; // gray
	endcase
end

wire [23:0] win = dot ? ink : cur_bg;

assign r_out = (enable && pic) ? win[23:16] : r_in;
assign g_out = (enable && pic) ? win[15:8]  : g_in;
assign b_out = (enable && pic) ? win[7:0]   : b_in;

endmodule
