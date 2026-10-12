//============================================================================
//  Y Unit DMA blitter
//
//  Copies a rectangle of graphics ROM pixels into the 512x512 frame store.
//  Each written entry is {palette byte, pixel byte}. Behaviour follows MAME's
//  midyunit dma_w / dma_draw, including details games depend on:
//    - register 0 bit 15 starts a blit and reads back set until it completes
//    - any write to register 0 drops the completion interrupt (INT1)
//    - completion is signalled 41 ns per drawn pixel after the start
//    - X flip mirrors around the right edge and starts the source early
//    - clipping trims width/height but leaves the source offset where it was
//    - rows whose source offset is at or beyond 0x06000000 are skipped
//
//  The graphics ROMs are stored as MAME loads them (four 2 MB chunks, each
//  holding two bits of every pixel) but with the chunks interleaved per 16-bit
//  word, so one 8-byte SDRAM line carries all planes of 8 pixels:
//      line byte 2*c + j = chunk c, byte 2*line + j
//  The plane bits are put back together here, as MAME's init_gfxrom does once
//  at start-up.
//
//  Rows are assembled in a double-buffered row RAM and handed to the VRAM
//  controller as one burst each, so a row costs one DDR3 transaction.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_dma
(
	input             clk,
	input             reset,

	input             bpp6,          // 6 bits per pixel (else 4)
	input             fast,          // count the completion timer down by 2 this clock
	                                 // (shorter video frames, see midway_yunit.sv)

	// register file (16-bit words 0-9), CPU side
	input             reg_wr,
	input       [3:0] reg_idx,
	input      [15:0] reg_wdata,
	output     [15:0] reg_rdata,
	output            reg_wr_wait,   // hold a new start until the current blit has drawn
	output     [15:0] palette_reg,   // DMA_PALETTE, also used by CPU VRAM writes

	output reg        irq,           // INT1

	// graphics ROM, 8-byte lines from SDRAM
	output reg [22:3] gfx_line,      // pixel index / 8
	output reg        gfx_req,       // toggle
	input             gfx_ack,
	input      [63:0] gfx_data,

	// VRAM row write-back (see yunit_vram)
	output reg        blt_req,       // toggle
	input             blt_ack,
	output reg  [8:0] blt_row,
	output reg  [6:0] blt_lo,
	output reg  [6:0] blt_hi,
	input       [6:0] blt_raddr,
	output reg [63:0] blt_q,
	output reg  [7:0] blt_be
);

//----------------------------------------------------------------------------
// Registers
//----------------------------------------------------------------------------

reg  [15:0] r [0:15];

assign reg_rdata   = (reg_idx <= 4'd9) ? r[reg_idx] : 16'h0000;
assign palette_reg = r[8];

//----------------------------------------------------------------------------
// Row buffers: 2 x 128 beats of {byte enables, data}
//----------------------------------------------------------------------------

reg  [71:0] rowbuf [0:255];
reg         rb_we;
reg   [7:0] rb_waddr;
reg  [71:0] rb_wdata;
reg         flush_bank;                 // bank the VRAM controller is reading

always @(posedge clk) begin
	if (rb_we) rowbuf[rb_waddr] <= rb_wdata;
	{blt_be, blt_q} <= rowbuf[{flush_bank, blt_raddr}];
end

//----------------------------------------------------------------------------
// Pixel extraction from an interleaved line
//----------------------------------------------------------------------------

function automatic [7:0] line_pixel(input [63:0] line, input [2:0] k, input six);
	reg [1:0] p0, p1, p2;
	begin
		p0 = line[{1'b0, 1'b0, k[2], k[1:0], 1'b0} +: 2];   // chunk 0, byte k[2]
		p1 = line[{1'b0, 1'b1, k[2], k[1:0], 1'b0} +: 2];   // chunk 1
		p2 = line[{1'b1, 1'b0, k[2], k[1:0], 1'b0} +: 2];   // chunk 2
		line_pixel = {2'b00, six ? p2 : 2'b00, p1, p0};
	end
endfunction

//----------------------------------------------------------------------------
// Blit engine
//----------------------------------------------------------------------------

localparam B_IDLE   = 4'd0;
localparam B_SETUP  = 4'd1;
localparam B_CLIP   = 4'd2;
localparam B_ROW    = 4'd3;
localparam B_PIX    = 4'd4;
localparam B_ROWEND = 4'd5;
localparam B_FLUSH  = 4'd6;
localparam B_DRAIN  = 4'd7;
localparam B_WAIT   = 4'd8;
localparam B_CLIP2  = 4'd9;      // second clipping step (far edges)
localparam B_CLIP3  = 4'd10;     // area and next state
localparam B_CLIP4  = 4'd11;     // completion time

reg   [3:0] bstate;
reg  [15:0] cmd;
reg  signed [31:0] rowbytes, xpos, ypos, width, height;
reg  [31:0] gfxoff;
reg  [15:0] pal;
reg  [15:0] color;
reg  [31:0] src;                        // pixel index of the next source pixel (MAME's o)
reg  [31:0] src_row;                    // pixel index of the next row (MAME's offset)
reg  [15:0] yi;
reg  [15:0] xi;
reg   [8:0] tx;                         // destination column
reg   [8:0] ty;
reg         fill_bank;                  // bank being filled
reg         flush_busy;                 // a flush request is outstanding
reg  [63:0] acc;                        // destination beat being assembled
reg   [7:0] acc_be;
reg   [6:0] acc_q;                      // its beat index in the row
reg         acc_valid;
reg         row_any;                    // something was written in this row
reg   [6:0] row_lo, row_hi;
reg  [31:0] timer;                      // clk cycles until completion may be signalled
reg  signed [31:0] area;                // clipped width x height
reg         start_pending;

// source line cache: l0 holds the line of src, l1 the prefetched next line
reg  [19:0] l0_tag, l1_tag;
reg  [63:0] l0_data, l1_data;
reg   [7:0] l0_zero, l1_zero;      // pixel k of the line is 0 (set with the line)
reg         l0_ok, l1_ok;
reg         fetching;
reg  [19:0] fetch_tag;

wire  [3:0] mode    = cmd[3:0];
wire        flip    = cmd[4];
reg         no_src;                // modes without source pixels, set at the start of a blit
wire [19:0] src_tag = src[22:3];
wire  [7:0] pix     = line_pixel(l0_data, src[2:0], bpp6);
wire        pix_z   = l0_zero[src[2:0]];
wire        have    = no_src || (l0_ok && (l0_tag == src_tag));

// Zero flags of the 8 pixels of a source line. They are worked out when a
// line is stored in the cache (from the SDRAM word or the prefetched line),
// so the per-pixel test below is a bit select instead of a pixel extraction
// followed by a compare: that chain into the write accumulator was the
// longest path in the DMA at 96 MHz.
function automatic [7:0] line_zero(input [63:0] line, input six);
	integer k;
	begin
		for (k = 0; k < 8; k = k + 1)
			line_zero[k] = (line_pixel(line, 3'(k), six) == 8'd0);
	end
endfunction

// what to do with this pixel (the cases of MAME's dma_draw)
reg         px_wr;
reg  [15:0] px_val;
always @(*) begin
	px_wr  = 1'b0;
	px_val = pal | {8'h00, pix};
	case (mode)
		4'd1:         begin px_wr = pix_z; px_val = pal; end
		4'd2:         px_wr = ~pix_z;
		4'd3:         px_wr = 1'b1;
		4'd4, 4'd5:   begin px_wr = pix_z; px_val = color; end
		4'd6, 4'd7:   begin px_wr = 1'b1; if (pix_z) px_val = color; end
		4'd8, 4'd10:  begin px_wr = ~pix_z; px_val = color; end
		4'd9, 4'd11:  begin px_wr = 1'b1; if (~pix_z) px_val = color; end
		4'd12, 4'd13,
		4'd14, 4'd15: begin px_wr = 1'b1; px_val = color; end
		default:      px_wr = 1'b0;
	endcase
end

// MAME draws a blit the moment it is started; here drawing takes time, so a
// second start that arrives while the first is still drawing is held off.
wire        start_wr    = reg_wr && (reg_idx == 4'd0) && reg_wdata[15];
assign reg_wr_wait      = start_wr && (bstate != B_IDLE) && (bstate != B_WAIT);

integer i;
always @(posedge clk) begin
	rb_we <= 1'b0;

	if (reset) begin
		for (i = 0; i < 16; i = i + 1)
			r[i] <= 16'd0;
		bstate        <= B_IDLE;
		irq           <= 1'b0;
		flush_busy    <= 1'b0;
		fill_bank     <= 1'b0;
		flush_bank    <= 1'b0;
		l0_ok         <= 1'b0;
		l1_ok         <= 1'b0;
		fetching      <= 1'b0;
		timer         <= 32'd0;
		blt_req       <= blt_ack;
		gfx_req       <= gfx_ack;
		start_pending <= 1'b0;
	end
	else begin
		if (fast && (timer > 32'd1))
			timer <= timer - 32'd2;
		else if (timer != 32'd0)
			timer <= timer - 32'd1;

		// ---- flush handshake ----
		if (flush_busy && (blt_req == blt_ack))
			flush_busy <= 1'b0;

		// ---- source line fetching: keep l0 = line of src, l1 = the next one ----
		if (fetching && (gfx_req == gfx_ack)) begin
			fetching <= 1'b0;
			if (fetch_tag == src_tag && !(l0_ok && l0_tag == src_tag)) begin
				l0_data <= gfx_data; l0_zero <= line_zero(gfx_data, bpp6); l0_tag <= fetch_tag; l0_ok <= 1'b1;
			end
			else begin
				l1_data <= gfx_data; l1_zero <= line_zero(gfx_data, bpp6); l1_tag <= fetch_tag; l1_ok <= 1'b1;
			end
		end
		else if (!fetching && (bstate == B_PIX) && !no_src) begin
			if (!(l0_ok && l0_tag == src_tag)) begin
				if (l1_ok && l1_tag == src_tag) begin
					// promote the prefetched line
					l0_data <= l1_data; l0_zero <= l1_zero; l0_tag <= l1_tag; l0_ok <= 1'b1; l1_ok <= 1'b0;
				end
				else begin
					fetching  <= 1'b1;
					fetch_tag <= src_tag;
					gfx_line  <= src_tag;
					gfx_req   <= ~gfx_req;
				end
			end
			else if (!(l1_ok && l1_tag == src_tag + 20'd1)) begin
				fetching  <= 1'b1;
				fetch_tag <= src_tag + 20'd1;
				gfx_line  <= src_tag + 20'd1;
				gfx_req   <= ~gfx_req;
			end
		end

		case (bstate)
			B_IDLE: if (start_pending) begin
				start_pending <= 1'b0;
				cmd      <= r[0];
				no_src   <= (r[0][3:0] >= 4'd12) || (r[0][3:0] == 4'd0);
				rowbytes <= {{16{r[1][15]}}, r[1]};
				gfxoff   <= {r[3], r[2]};
				xpos     <= {{16{r[4][15]}}, r[4]};
				ypos     <= {{16{r[5][15]}}, r[5]};
				width    <= {16'd0, r[6]};
				height   <= {16'd0, r[7]};
				pal      <= {r[8][7:0], 8'h00};
				color    <= {r[8][7:0], r[9][7:0]};
				bstate   <= B_SETUP;
			end

			B_SETUP: begin
				// source adjustments for X flip (computed on the unclipped width)
				if (flip) begin
					gfxoff   <= gfxoff - 32'((width - 32'sd1) << 3);
					rowbytes <= (rowbytes - width + 32'sd3) & ~32'sd3;
					xpos     <= xpos + width - 32'sd1;
				end
				else
					rowbytes <= (rowbytes + width + 32'sd3) & ~32'sd3;
				bstate <= B_CLIP;
			end

			// Clipping as MAME does it, spread over a few states so each one
			// stays a short add/compare chain at 96 MHz
			B_CLIP: begin
				// near edges (top, and left or the flipped right edge)
				if (ypos < 0) begin
					height <= height + ypos;
					ypos   <= 32'sd0;
				end
				if (!flip) begin
					if (xpos < 0) begin
						width <= width + xpos;
						xpos  <= 32'sd0;
					end
				end
				else if (xpos >= 32'sd512) begin
					width <= width - (xpos - 32'sd511);
					xpos  <= 32'sd511;
				end
				if (gfxoff < 32'h0200_0000)
					gfxoff <= gfxoff + 32'h0200_0000;
				bstate <= B_CLIP2;
			end

			B_CLIP2: begin
				// far edges
				if (ypos + height > 32'sd512)
					height <= 32'sd512 - ypos;
				if (!flip) begin
					if (xpos + width > 32'sd512)
						width <= 32'sd512 - xpos;
				end
				else if (xpos - width < 0)
					width <= xpos;
				src_row <= (gfxoff - 32'h0200_0000) >> 3;
				bstate  <= B_CLIP3;
			end

			B_CLIP3: begin
				area   <= width * height;
				yi     <= 16'd0;
				l0_ok  <= 1'b0;
				l1_ok  <= 1'b0;
				bstate <= B_CLIP4;
			end

			B_CLIP4: begin
				// completion time: 41 ns per pixel = 3.9375 clk at 96 MHz
				if ((width > 0) && (height > 0)) begin
					timer  <= 32'(((area << 6) - area) >>> 4);
					bstate <= (mode != 4'd0) ? B_ROW : B_WAIT;
				end
				else begin
					timer  <= 32'd0;
					bstate <= B_WAIT;
				end
			end

			B_ROW: begin
				if ($signed({16'd0, yi}) >= height)
					bstate <= B_DRAIN;
				else if (src_row >= 32'h0600_0000 && mode < 4'd12) begin
					// MAME's overrun guard: the row is skipped
					src_row <= src_row + rowbytes;
					yi      <= yi + 16'd1;
				end
				else begin
					ty        <= ypos[8:0] + yi[8:0];
					tx        <= xpos[8:0];
					src       <= src_row;
					xi        <= 16'd0;
					acc_valid <= 1'b0;
					acc_be    <= 8'd0;
					row_any   <= 1'b0;
					row_lo    <= xpos[8:2];
					row_hi    <= xpos[8:2];
					bstate    <= B_PIX;
				end
			end

			B_PIX: begin
				if ($signed({16'd0, xi}) >= width)
					bstate <= B_ROWEND;
				else if (have) begin
					// a new destination beat: store the finished one first
					if (acc_valid && (tx[8:2] != acc_q)) begin
						rb_we    <= 1'b1;
						rb_waddr <= {fill_bank, acc_q};
						rb_wdata <= {acc_be, acc};
					end
					if (!acc_valid || (tx[8:2] != acc_q)) begin
						acc_q     <= tx[8:2];
						acc_valid <= 1'b1;
						if (tx[8:2] < row_lo) row_lo <= tx[8:2];
						if (tx[8:2] > row_hi) row_hi <= tx[8:2];
					end
					if (px_wr) begin
						acc[{tx[1:0], 4'b0000} +: 16] <= px_val;
						row_any <= 1'b1;
						if (acc_valid && (tx[8:2] == acc_q))
							acc_be[{tx[1:0], 1'b0} +: 2] <= 2'b11;
						else
							acc_be <= 8'd3 << {tx[1:0], 1'b0};
					end
					else if (!(acc_valid && (tx[8:2] == acc_q)))
						acc_be <= 8'd0;
					xi  <= xi + 16'd1;
					src <= src + 32'd1;
					tx  <= flip ? (tx - 9'd1) : (tx + 9'd1);
				end
			end

			B_ROWEND: begin
				// store the last beat, then hand the row to the VRAM controller
				rb_we    <= 1'b1;
				rb_waddr <= {fill_bank, acc_q};
				rb_wdata <= {acc_be, acc};
				bstate   <= B_FLUSH;
			end

			B_FLUSH: if (!row_any || !flush_busy) begin
				// rows where nothing was drawn need no VRAM write at all
				if (row_any) begin
					flush_busy <= 1'b1;
					flush_bank <= fill_bank;
					fill_bank  <= ~fill_bank;
					blt_row    <= ty;
					blt_lo     <= row_lo;
					blt_hi     <= row_hi;
					blt_req    <= ~blt_req;
				end
				src_row <= src_row + rowbytes;
				yi      <= yi + 16'd1;
				bstate  <= B_ROW;
			end

			B_DRAIN: if (!flush_busy)
				bstate <= B_WAIT;

			B_WAIT: begin
				if (start_pending)
					bstate <= B_IDLE;            // restarted: the old completion is cancelled
				else if ((timer == 32'd0 || timer == 32'd1) && !start_wr) begin
					r[0][15] <= 1'b0;
					irq      <= 1'b1;
					bstate   <= B_IDLE;
				end
			end

			default: bstate <= B_IDLE;
		endcase

		// ---- CPU register writes (last, so they win over the completion) ----
		if (reg_wr && !reg_wr_wait) begin
			r[reg_idx] <= reg_wdata;
			if (reg_idx == 4'd0) begin
				irq <= 1'b0;                     // any command write acknowledges
				if (reg_wdata[15]) start_pending <= 1'b1;
			end
		end
	end
end

endmodule
