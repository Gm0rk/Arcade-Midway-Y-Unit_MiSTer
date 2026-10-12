//============================================================================
//  Y Unit video output
//
//  Turns the frame store into pixels the way MAME's scanline_update does:
//    - at the start of every displayed line the row the 34010 points at
//      (DPYADR) is fetched from VRAM into a line buffer
//    - pixels from HEBLNK to HSBLNK read consecutive entries of that row,
//      starting at the column address and wrapping at 512
//    - each 16-bit entry goes through the pen map (4 or 6 bpp boards wire the
//      palette address lines differently) and the 15-bit palette
//    - autoerase: once a row has been shown, row 510 or 511 (same parity) is
//      copied over it, and the row of the last visible line is erased at the
//      start of the following line
//
//  All video signals are delayed by one pixel so the line buffer and palette
//  RAM reads complete between pixel clocks.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_video
(
	input             clk,
	input             reset,

	input             ce_pix,        // 8 MHz pixel enable
	input             ce_vclk,       // 4 MHz VCLK (coincides with every other ce_pix)

	input             bpp6,          // 6 bpp pen map (else 4 bpp)
	input             flip_x,        // mirror the picture (Terminator 2 cabinet)
	input             autoerase_en,  // control register bit 4 (active low there)

	// timing and display address from the 34010
	input       [9:0] hcount,
	input       [9:0] heblnk,
	input       [9:0] hsblnk,
	input       [9:0] vcount,
	input       [9:0] vsblnk,
	input             hsync_in,
	input             vsync_in,
	input             hblank_in,
	input             vblank_in,
	input             disp_en,
	input             line_start,
	input             line_vis,
	input      [11:0] line_row,
	input      [13:0] line_col,

	// display palette write port (offset already masked to the palette size)
	input             pal_we,
	input      [11:0] pal_addr,
	input      [14:0] pal_data,

	// VRAM requests (see yunit_vram)
	output reg        disp_req,
	input             disp_ack,
	output reg  [8:0] disp_row,
	input             lb_we,
	input       [6:0] lb_addr,
	input      [63:0] lb_data,

	output reg        erase_req,
	input             erase_ack,
	output reg  [8:0] erase_dst,
	output      [8:0] erase_src,

	// video out
	output reg  [7:0] r,
	output reg  [7:0] g,
	output reg  [7:0] b,
	output reg        hsync,
	output reg        vsync,
	output reg        hblank,
	output reg        vblank
);

//----------------------------------------------------------------------------
// Line buffer: two banks of one 512-entry row (128 beats of 4 entries)
//----------------------------------------------------------------------------

reg  [63:0] linebuf [0:255];
reg         fill_bank;           // bank the current fetch writes
reg         show_bank;           // bank being displayed
reg   [7:0] lb_raddr;
reg  [63:0] lb_q;

always @(posedge clk) begin
	if (lb_we) linebuf[{fill_bank, lb_addr}] <= lb_data;
	lb_q <= linebuf[lb_raddr];
end

//----------------------------------------------------------------------------
// Display palette (4096 x 15). MAME writes a pen at (offset & mask), so with
// the 4 bpp mask several CPU words alias one pen and the last write wins.
//----------------------------------------------------------------------------

reg  [14:0] palram [0:4095];
reg  [11:0] pal_raddr;
reg  [14:0] pal_q;

always @(posedge clk) begin
	if (pal_we) palram[pal_addr] <= pal_data;
	pal_q <= palram[pal_raddr];
end

//----------------------------------------------------------------------------
// Row fetch and autoerase scheduling
//----------------------------------------------------------------------------

reg   [8:0] col_start;           // first entry of the line
reg         line_on;             // this line shows pixels
reg  [11:0] last_row;            // row of the last displayed line
reg         last_valid;
reg         erase_pend;
reg   [8:0] erase_pend_row;

// the erase source is row 510 or 511, keeping the parity of the erased row
assign erase_src = {8'hFF, erase_dst[0]};

// MAME only erases rows 0-509; row - 1 is taken on the full 12-bit address
wire [11:0] prev_row   = line_row - 12'd1;
wire        prev_erase = (prev_row < 12'd510);
wire        last_erase = (last_row < 12'd510);

always @(posedge clk) begin
	if (reset) begin
		disp_req   <= disp_ack;
		erase_req  <= erase_ack;
		fill_bank  <= 1'b0;
		show_bank  <= 1'b0;
		line_on    <= 1'b0;
		last_valid <= 1'b0;
		erase_pend <= 1'b0;
	end
	else begin
		if (line_start) begin
			line_on <= line_vis & disp_en;
			if (line_vis & disp_en) begin
				// fetch this line's row; it is shown from this line's HEBLNK on
				disp_row   <= line_row[8:0];
				disp_req   <= ~disp_req;
				fill_bank  <= ~fill_bank;
				show_bank  <= ~fill_bank;
				col_start  <= {line_col[7:0], 1'b0};
				last_row   <= line_row;
				last_valid <= 1'b1;
				// erase the row the previous line showed
				if (autoerase_en && prev_erase) begin
					erase_pend     <= 1'b1;
					erase_pend_row <= prev_row[8:0];
				end
			end
			else if (vcount == vsblnk && last_valid) begin
				// the last visible row is erased one line after it was shown
				last_valid <= 1'b0;
				if (autoerase_en && last_erase) begin
					erase_pend     <= 1'b1;
					erase_pend_row <= last_row[8:0];
				end
			end
		end

		// issue an erase once the previous one is done
		if (erase_pend && (erase_req == erase_ack)) begin
			erase_pend <= 1'b0;
			erase_dst  <= erase_pend_row;
			erase_req  <= ~erase_req;
		end
	end
end

//----------------------------------------------------------------------------
// Pixel pipeline
//
// The cycle after each ce_pix the beam position is captured (HCOUNT has moved
// on by then if a VCLK came with it) and the line buffer is addressed. The
// entry, pen and palette lookups finish well before the next ce_pix, which
// outputs the colour together with the timing signals captured with it.
//----------------------------------------------------------------------------

reg         ce_pix_d, vclk_d;
reg   [3:0] stage;
reg   [1:0] lane;
reg         a_hs, a_vs, a_hb, a_vb, a_on;
reg  [14:0] a_rgb;

wire [10:0] pix_pos  = {hcount, ~vclk_d};                 // pixel within the line
wire [10:0] act_x    = pix_pos - {heblnk, 1'b0};          // pixel within the active area
wire [10:0] act_w    = {hsblnk, 1'b0} - {heblnk, 1'b0};
wire [10:0] src_x    = flip_x ? (act_w - 11'd1 - act_x) : act_x;
wire  [8:0] entry    = col_start + src_x[8:0];

wire [15:0] ent      = lb_q[{lane, 4'b0000} +: 16];
wire [11:0] pen      = bpp6 ? {ent[11:8], ent[15:14], ent[5:0]} : {4'h0, ent[15:12], ent[3:0]};

function automatic [7:0] pal5(input [4:0] c);
	pal5 = {c, c[4:2]};
endfunction

always @(posedge clk) begin
	ce_pix_d <= ce_pix;
	if (ce_pix) vclk_d <= ce_vclk;

	stage <= {stage[2:0], 1'b0};

	if (ce_pix_d) begin
		a_hs     <= hsync_in;
		a_vs     <= vsync_in;
		a_hb     <= hblank_in;
		a_vb     <= vblank_in;
		a_on     <= line_on & ~hblank_in & ~vblank_in;
		lb_raddr <= {show_bank, entry[8:2]};
		lane     <= entry[1:0];
		stage[0] <= 1'b1;
	end
	if (stage[1])                       // line buffer data valid
		pal_raddr <= pen;
	if (stage[3])                       // palette data valid
		a_rgb <= a_on ? pal_q : 15'd0;

	if (ce_pix) begin
		r      <= pal5(a_rgb[14:10]);
		g      <= pal5(a_rgb[9:5]);
		b      <= pal5(a_rgb[4:0]);
		hsync  <= a_hs;
		vsync  <= a_vs;
		hblank <= a_hb;
		vblank <= a_vb;
	end
end

endmodule
