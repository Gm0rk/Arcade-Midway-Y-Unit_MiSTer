//============================================================================
//  TMS34010 Graphics System Processor
//
//  A from-scratch implementation of the TI TMS34010 as used on the Williams /
//  Midway Y Unit. Instruction semantics, flag behaviour and cycle counts follow
//  MAME's tms34010 core (Alex Pasadyn, Zsolt Vasvari, Aaron Giles) because that
//  is the behaviour every supported game has been tested against.
//
//  Execution model
//  ---------------
//  The core is a multi-cycle state machine on clk_sys with a logic enable
//  (`ce`). On the Y Unit it is enabled on every other clk_sys cycle and its
//  internal paths are constrained as two-cycle paths, which is what lets the
//  wide instruction logic meet timing.
//
//  It runs each instruction as fast as its memory accesses allow, then adds the
//  instruction's documented machine-cycle count to a cycle "debt" paid off by ce_cyc
//  (one pulse per machine cycle, CLKIN/8). The next instruction only starts once
//  the debt is paid, so the program sees the same timing as on the real chip
//  (and in MAME) while memory latency stays hidden. A small negative debt is
//  allowed so time lost to a slow memory access is caught up afterwards.
//
//  Memory interface
//  ----------------
//  The 34010 is bit addressed. All external traffic is 16-bit words: field
//  reads/writes are assembled here with read-modify-write, exactly as the chip's
//  local memory interface does it. A request goes straight out from the
//  requester's registers and stays up until mem_ack is seen in a ce cycle.
//  mem_srt marks a VRAM shift-register transfer (DPYCTL.SRT set): a read loads
//  the shift register from the row at mem_baddr and returns its first entry, a
//  write stores the shift register to that row.
//
//  The internal I/O registers (0xC0000000-0xC00001FF) never reach the bus.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module tms34010
(
	input             clk,
	input             ce,           // logic enable: every register here changes only when ce is high
	input             reset,

	input             ce_cyc,       // machine-cycle tick (CLKIN / 8), asserted in a ce cycle
	input             ce_vclk,      // video clock tick (one per 2 pixels on Y Unit), in a ce cycle
	input             pause,        // hold at the next instruction boundary
	input       [9:0] frame_lines,  // MiSTer option, not part of the chip: 0 = the
	                                // game's own frame, else blank lines are dropped
	                                // until a frame is this many lines (see below)

	// local memory bus, word oriented. A request (mem_rd / mem_wr with its
	// address and data) stays up until a ce cycle sees mem_ack; the board must
	// hold mem_ack until that ce cycle and drop it right after.
	output     [27:0] mem_addr,     // word address (bit address >> 4)
	output     [31:0] mem_baddr,    // bit address, used by shift-register transfers
	output            mem_rd,
	output            mem_wr,
	output            mem_srt,      // shift-register transfer instead of a data access
	output     [15:0] mem_wdata,
	input      [15:0] mem_rdata,
	input             mem_ack,

	// external interrupts (active high levels)
	input             int1,
	input             int2,

	// video timing from the on-chip CRT controller
	output            hsync,
	output            vsync,
	output            hblank,
	output            vblank,
	output      [9:0] hcount,       // in VCLK units
	output      [9:0] vcount,
	output      [9:0] heblnk,       // screen window (hblank), VCLK units
	output      [9:0] hsblnk,
	output      [9:0] vsblnk,       // first line after the picture
	output            disp_en,      // DPYCTL.ENV
	output reg        line_start,   // pulse at the start of every scanline
	output reg        line_vis,     // that line is inside VEBLNK..VSBLNK
	output reg [11:0] line_row,     // display row address for this line
	output reg [13:0] line_col,     // display column address for this line
	output reg  [9:0] line_heblnk,  // HEBLNK/HSBLNK when this line started
	output reg  [9:0] line_hsblnk,

	// debug / verification
	output     [31:0] dbg_pc,
	output     [31:0] dbg_st,
	output reg        dbg_retire,   // pulse when an instruction or interrupt completes
	output reg [15:0] dbg_cycles    // machine cycles charged for it
);

import tms34010_pkg::*;

//----------------------------------------------------------------------------
// Architectural state
//----------------------------------------------------------------------------

// rf[0..14] = A0-A14, rf[15] = SP, rf[16..30] = B0-B14
reg  [31:0] rf [0:31] /* verilator public_flat_rw */;
reg  [31:0] pc /* verilator public_flat_rw */;
reg  [31:0] st /* verilator public_flat_rw */;
reg  [15:0] ioreg [0:31] /* verilator public_flat_rw */;

localparam ST_N  = 31;
localparam ST_C  = 30;
localparam ST_Z  = 29;
localparam ST_V  = 28;
localparam ST_P  = 25;
localparam ST_IE = 21;

localparam R_HESYNC  = 5'd0;
localparam R_HEBLNK  = 5'd1;
localparam R_HSBLNK  = 5'd2;
localparam R_HTOTAL  = 5'd3;
localparam R_VESYNC  = 5'd4;
localparam R_VEBLNK  = 5'd5;
localparam R_VSBLNK  = 5'd6;
localparam R_VTOTAL  = 5'd7;
localparam R_DPYCTL  = 5'd8;
localparam R_DPYSTRT = 5'd9;
localparam R_DPYINT  = 5'd10;
localparam R_CONTROL = 5'd11;
localparam R_HSTCTLL = 5'd15;
localparam R_HSTCTLH = 5'd16;
localparam R_INTENB  = 5'd17;
localparam R_INTPEND = 5'd18;
localparam R_CONVSP  = 5'd19;
localparam R_CONVDP  = 5'd20;
localparam R_PSIZE   = 5'd21;
localparam R_DPYTAP  = 5'd27;
localparam R_HCOUNT  = 5'd28;
localparam R_VCOUNT  = 5'd29;
localparam R_DPYADR  = 5'd30;
localparam R_REFCNT  = 5'd31;

localparam INT_X1 = 1;
localparam INT_X2 = 2;
localparam INT_HI = 9;
localparam INT_DI = 10;
localparam INT_WV = 11;

assign dbg_pc = pc;
assign dbg_st = st;

// B-file register numbers used implicitly by the graphics instructions
function automatic [4:0] ridx(input file_b, input [3:0] r);
	ridx = file_b ? ((r == 4'd15) ? 5'd15 : {1'b1, r}) : {1'b0, r};
endfunction

localparam [4:0] B_SADDR  = 5'd16;
localparam [4:0] B_SPTCH  = 5'd17;
localparam [4:0] B_DADDR  = 5'd18;
localparam [4:0] B_DPTCH  = 5'd19;
localparam [4:0] B_OFFSET = 5'd20;
localparam [4:0] B_WSTART = 5'd21;
localparam [4:0] B_WEND   = 5'd22;
localparam [4:0] B_DYDX   = 5'd23;
localparam [4:0] B_COLOR0 = 5'd24;
localparam [4:0] B_COLOR1 = 5'd25;
localparam [4:0] B_COUNT  = 5'd26;
localparam [4:0] B_INC1   = 5'd27;
localparam [4:0] B_INC2   = 5'd28;
localparam [4:0] B_TEMP   = 5'd30;

//----------------------------------------------------------------------------
// Derived control register views
//----------------------------------------------------------------------------

wire [15:0] r_control = ioreg[R_CONTROL];
wire [15:0] r_dpyctl  = ioreg[R_DPYCTL];
wire [15:0] r_psize   = ioreg[R_PSIZE];

wire  [1:0] win_mode  = r_control[7:6];     // window checking mode
wire        trans_en  = r_control[5];       // transparency
wire  [4:0] ppop      = r_control[14:10];   // pixel processing (raster) op
wire        rop_en    = (ppop != 5'd0) && (ppop < 5'd22);
wire        srt_mode  = r_dpyctl[11];

// MAME treats any PSIZE other than 1/2/4/8/16/32 as 1 bit for pixel access,
// and uses a pixel shift of 0 for PSIZE=32 (the 34010 has no such case).
// PSIZE only changes through an I/O write, after which the sequencer is busy
// for several cycles, so these helpers are registered to keep them off the
// pixel instruction paths.
reg  [5:0] pix_bits;
reg  [2:0] pix_shift;
reg [31:0] pix_mask;         // one pixel's worth of low bits
reg [31:0] pix_align;        // clears the bit address below a pixel boundary
reg [31:0] rop_max;          // saturation value for the ADDS raster op
reg [31:0] pix_keep;         // pixel data mask: one pixel below 16 bits, else all
always @(posedge clk) if (ce) begin
	case (r_psize)
		16'd2:   begin pix_bits <= 6'd2;  pix_shift <= 3'd1; pix_mask <= 32'h0000_0003; pix_align <= ~32'd1;  end
		16'd4:   begin pix_bits <= 6'd4;  pix_shift <= 3'd2; pix_mask <= 32'h0000_000F; pix_align <= ~32'd3;  end
		16'd8:   begin pix_bits <= 6'd8;  pix_shift <= 3'd3; pix_mask <= 32'h0000_00FF; pix_align <= ~32'd7;  end
		16'd16:  begin pix_bits <= 6'd16; pix_shift <= 3'd4; pix_mask <= 32'h0000_FFFF; pix_align <= ~32'd15; end
		16'd32:  begin pix_bits <= 6'd32; pix_shift <= 3'd0; pix_mask <= 32'hFFFF_FFFF; pix_align <= ~32'd31; end
		default: begin pix_bits <= 6'd1;  pix_shift <= 3'd0; pix_mask <= 32'h0000_0001; pix_align <= ~32'd0;  end
	endcase
	rop_max  <= 32'hFFFF_FFFF >> (6'd32 - r_psize[5:0]);
	pix_keep <= (pix_bits < 6'd16) ? pix_mask : 32'hFFFF_FFFF;
end

// CONVSP/CONVDP give the pitch as 1 << (~reg & 31). They read as zero until
// written, which makes XY addressing collapse to the X term, as in MAME.
reg  [4:0] convsp_sh /* verilator public_flat_rw */, convdp_sh /* verilator public_flat_rw */;
reg        convsp_set /* verilator public_flat_rw */, convdp_set /* verilator public_flat_rw */;

function automatic [31:0] xytol(input [31:0] xy, input conv_set, input [4:0] conv_sh,
                                input [2:0] psh, input [31:0] offset);
	reg [31:0] y_term, x_term;
	y_term = conv_set ? ({{16{xy[31]}}, xy[31:16]} << conv_sh) : 32'd0;
	x_term = {{16{xy[15]}}, xy[15:0]} << psh;
	xytol  = y_term + x_term + offset;
endfunction

//----------------------------------------------------------------------------
// Raster operations used by single-pixel writes (MAME raster_op_1..21)
//----------------------------------------------------------------------------

function automatic [31:0] raster_op(input [4:0] op, input [31:0] n, input [31:0] o, input [31:0] maxv);
	case (op)
		5'd1:    raster_op = n & o;
		5'd2:    raster_op = n & ~o;
		5'd3:    raster_op = 32'd0;
		5'd4:    raster_op = n | ~o;
		5'd5:    raster_op = ~(n ^ o);
		5'd6:    raster_op = ~o;
		5'd7:    raster_op = ~(n | o);
		5'd8:    raster_op = n | o;
		5'd9:    raster_op = o;
		5'd10:   raster_op = n ^ o;
		5'd11:   raster_op = ~n & o;
		5'd12:   raster_op = 32'h0000_FFFF;
		5'd13:   raster_op = ~n | o;
		5'd14:   raster_op = ~(n & o);
		5'd15:   raster_op = ~n;
		5'd16:   raster_op = n + o;
		5'd17:   raster_op = ((n + o) > maxv) ? maxv : (n + o);
		5'd18:   raster_op = o - n;
		5'd19:   raster_op = (o > n) ? (o - n) : 32'd0;
		5'd20:   raster_op = (o > n) ? o : n;
		5'd21:   raster_op = (o > n) ? n : o;
		default: raster_op = n;
	endcase
endfunction

//----------------------------------------------------------------------------
// Word port: the field unit and the graphics engine both talk to memory
// through this. I/O register accesses are satisfied internally.
//----------------------------------------------------------------------------

reg         wp_req;          // from the field unit
reg         wp_wr;
reg         wp_srt;
reg  [31:0] wp_baddr;        // bit address (word address = [31:4])
reg  [15:0] wp_wdata;
wire        wp_ack;
wire [15:0] wp_rdata;

wire        gx_req;          // from the graphics engine
wire        gx_wr;
wire        gx_srt;
wire [31:0] gx_baddr;
wire [15:0] gx_wdata;
wire        gx_busy;

// The graphics engine owns the port while it runs; the main sequencer is
// idle then, so the two never collide.
wire        p_req   = gx_busy ? gx_req   : wp_req;
wire        p_wr    = gx_busy ? gx_wr    : wp_wr;
wire        p_srt   = gx_busy ? gx_srt   : wp_srt;
wire [31:0] p_baddr = gx_busy ? gx_baddr : wp_baddr;
wire [15:0] p_wdata = gx_busy ? gx_wdata : wp_wdata;

wire        p_io    = (p_baddr[31:9] == 23'h600000) & ~p_srt;    // 0xC0000000-0xC00001FF
wire  [4:0] p_ioidx = p_baddr[8:4];

reg         io_ack;
reg  [15:0] io_q;
reg         io_wr_strobe;
reg   [4:0] io_wr_idx;
reg  [15:0] io_wr_data;
wire [15:0] io_rd_value;

// External requests go straight out: both requesters hold request, address
// and data in registers until they see the acknowledge, so the bus signals
// are stable for the whole access and no extra pipeline stage is spent here.
assign mem_rd    = p_req & ~p_io & ~p_wr;
assign mem_wr    = p_req & ~p_io &  p_wr;
assign mem_srt   = p_srt;
assign mem_addr  = p_baddr[31:4];
assign mem_baddr = p_baddr;
assign mem_wdata = p_wdata;

assign wp_ack   = io_ack | mem_ack;
assign wp_rdata = io_ack ? io_q : mem_rdata;

// I/O registers answer one cycle after the request
always @(posedge clk) if (ce) begin
	io_ack       <= 1'b0;
	io_wr_strobe <= 1'b0;
	if (!reset && p_req && p_io && !io_ack) begin
		io_ack <= 1'b1;
		io_q   <= io_rd_value;
		if (p_wr) begin
			io_wr_strobe <= 1'b1;
			io_wr_idx    <= p_ioidx;
			io_wr_data   <= p_wdata;
		end
	end
end

//----------------------------------------------------------------------------
// Field unit
//
// Reads or writes a 1..32 bit field at any bit address. A field touches up to
// three words. Writes read back only the words they cover partially, merge,
// then write every covered word (the 34010 has no byte strobes).
//----------------------------------------------------------------------------

reg         srt_go;          // shift-register transfer request (one cycle)
reg         srt_wr_in;
reg  [31:0] srt_addr_in;

reg         fu_go;           // request from the sequencer (one cycle)
reg         fu_wr_in;
reg  [31:0] fu_addr_in;
reg   [5:0] fu_size_in;      // 1..32
reg         fu_sext_in;
reg  [31:0] fu_data_in;

reg         fu_busy;
reg  [31:0] fu_q;            // read result

reg   [3:0] fu_state;
reg  [27:0] fu_wbase;
reg   [3:0] fu_shift;
reg   [5:0] fu_size;
reg         fu_sext;
reg         fu_wr;
reg   [1:0] fu_nw;           // number of words touched
reg   [1:0] fu_i;
reg  [47:0] fu_buf;
reg  [47:0] fu_mask;
reg  [47:0] fu_data;
reg   [2:0] fu_needrd;       // which words must be read first

localparam FU_IDLE  = 4'd0;
localparam FU_RD    = 4'd1;
localparam FU_RDW   = 4'd2;
localparam FU_WR    = 4'd3;
localparam FU_WRW   = 4'd4;
localparam FU_DONE  = 4'd5;
localparam FU_SRT   = 4'd6;
localparam FU_FAST  = 4'd7;      // aligned 16/32-bit read
localparam FU_FASTW = 4'd8;      // aligned 16/32-bit write

wire [6:0]  fu_total_in = {3'd0, fu_addr_in[3:0]} + {1'b0, fu_size_in};
wire [47:0] fu_mask_in  = (((fu_size_in == 6'd32) ? 48'h0000_FFFF_FFFF : ((48'd1 << fu_size_in) - 48'd1)) << fu_addr_in[3:0]);

function automatic covers(input [47:0] m, input [1:0] w);
	covers = (m[w*16 +: 16] == 16'hFFFF);
endfunction

// Extracted, masked and optionally sign-extended read result
wire [47:0] fu_sh      = fu_buf >> fu_shift;
wire [31:0] fu_zmask   = (fu_size == 6'd32) ? 32'hFFFF_FFFF : ((32'd1 << fu_size) - 32'd1);
wire [31:0] fu_raw     = fu_sh[31:0] & fu_zmask;
wire        fu_signbit = fu_raw[fu_size[4:0] - 5'd1];   // size 32 wraps to bit 31
wire [31:0] fu_result  = (fu_sext & fu_signbit & (fu_size != 6'd32)) ? (fu_raw | ~fu_zmask) : fu_raw;

always @(posedge clk) if (ce) begin
	if (reset) begin
		fu_state <= FU_IDLE;
		fu_busy  <= 1'b0;
		wp_req   <= 1'b0;
		wp_srt   <= 1'b0;
	end
	else begin
		case (fu_state)
			FU_IDLE: if (fu_go && (fu_addr_in[3:0] == 4'd0) && ((fu_size_in == 6'd16) || (fu_size_in == 6'd32))) begin
				// Aligned word or long (every opcode and immediate fetch, most
				// data): straight to the bus one word after the other, no
				// masking, merging or read-back needed
				fu_busy  <= 1'b1;
				fu_sext  <= fu_sext_in;
				fu_nw    <= (fu_size_in == 6'd32) ? 2'd2 : 2'd1;
				fu_i     <= 2'd0;
				fu_data  <= {16'd0, fu_data_in};
				wp_req   <= 1'b1;
				wp_wr    <= fu_wr_in;
				wp_baddr <= fu_addr_in;
				wp_wdata <= fu_data_in[15:0];
				fu_state <= fu_wr_in ? FU_FASTW : FU_FAST;
			end
			else if (fu_go) begin
				fu_busy  <= 1'b1;
				fu_wbase <= fu_addr_in[31:4];
				fu_shift <= fu_addr_in[3:0];
				fu_size  <= fu_size_in;
				fu_sext  <= fu_sext_in;
				fu_wr    <= fu_wr_in;
				fu_nw    <= (fu_total_in > 7'd32) ? 2'd3 : ((fu_total_in > 7'd16) ? 2'd2 : 2'd1);
				fu_mask  <= fu_mask_in;
				fu_data  <= {16'd0, fu_data_in} << fu_addr_in[3:0];
				fu_buf   <= 48'd0;
				fu_i     <= 2'd0;
				if (fu_wr_in)
					fu_needrd <= {~covers(fu_mask_in, 2'd2) & (fu_total_in > 7'd32),
					              ~covers(fu_mask_in, 2'd1) & (fu_total_in > 7'd16),
					              ~covers(fu_mask_in, 2'd0)};
				else
					fu_needrd <= 3'b111;
				fu_state <= FU_RD;
			end

			FU_RD: begin
				// issue the next needed read, or move on to writing
				if (fu_i == fu_nw) begin
					fu_i     <= 2'd0;
					fu_state <= fu_wr ? FU_WR : FU_DONE;
				end
				else if (fu_needrd[fu_i]) begin
					wp_req   <= 1'b1;
					wp_wr    <= 1'b0;
					wp_baddr <= {fu_wbase + {26'd0, fu_i}, 4'd0};
					fu_state <= FU_RDW;
				end
				else
					fu_i <= fu_i + 2'd1;
			end

			FU_RDW: if (wp_ack) begin
				wp_req <= 1'b0;
				fu_buf[fu_i*16 +: 16] <= wp_rdata;
				fu_i     <= fu_i + 2'd1;
				fu_state <= FU_RD;
			end

			FU_WR: begin
				if (fu_i == fu_nw)
					fu_state <= FU_DONE;
				else begin
					wp_req   <= 1'b1;
					wp_wr    <= 1'b1;
					wp_baddr <= {fu_wbase + {26'd0, fu_i}, 4'd0};
					wp_wdata <= (fu_buf[fu_i*16 +: 16] & ~fu_mask[fu_i*16 +: 16]) |
					            (fu_data[fu_i*16 +: 16] & fu_mask[fu_i*16 +: 16]);
					fu_state <= FU_WRW;
				end
			end

			FU_WRW: if (wp_ack) begin
				wp_req   <= 1'b0;
				fu_i     <= fu_i + 2'd1;
				fu_state <= FU_WR;
			end

			FU_DONE: begin
				fu_q     <= fu_result;
				fu_busy  <= 1'b0;
				fu_state <= FU_IDLE;
			end

			FU_FAST: if (wp_ack) begin
				if (fu_nw == 2'd2 && fu_i == 2'd0) begin
					// low word in; the request stays up for the high word
					fu_buf[15:0] <= wp_rdata;
					fu_i         <= 2'd1;
					wp_baddr     <= wp_baddr + 32'd16;
				end
				else begin
					wp_req   <= 1'b0;
					fu_q     <= (fu_nw == 2'd2) ? {wp_rdata, fu_buf[15:0]} : {{16{fu_sext & wp_rdata[15]}}, wp_rdata};
					fu_busy  <= 1'b0;
					fu_state <= FU_IDLE;
				end
			end

			FU_FASTW: if (wp_ack) begin
				if (fu_nw == 2'd2 && fu_i == 2'd0) begin
					fu_i     <= 2'd1;
					wp_baddr <= wp_baddr + 32'd16;
					wp_wdata <= fu_data[31:16];
				end
				else begin
					wp_req   <= 1'b0;
					fu_busy  <= 1'b0;
					fu_state <= FU_IDLE;
				end
			end

			FU_SRT: if (wp_ack) begin
				// a shift-register load returns the first entry of the register
				wp_req   <= 1'b0;
				wp_srt   <= 1'b0;
				fu_q     <= {16'd0, wp_rdata};
				fu_busy  <= 1'b0;
				fu_state <= FU_IDLE;
			end

			default: fu_state <= FU_IDLE;
		endcase

		// shift-register transfers bypass the field logic: one bus cycle
		if (srt_go) begin
			fu_busy  <= 1'b1;
			wp_req   <= 1'b1;
			wp_wr    <= srt_wr_in;
			wp_srt   <= 1'b1;
			wp_baddr <= srt_addr_in;
			fu_state <= FU_SRT;
		end
	end
end

//----------------------------------------------------------------------------
// Multiply / divide unit
//----------------------------------------------------------------------------

reg         md_start;
reg   [2:0] md_op;
reg  [31:0] md_a, md_bhi, md_blo;
wire        md_busy, md_done, md_ovf, md_zero;
wire [31:0] md_hi, md_lo;

tms34010_muldiv muldiv
(
	.clk      (clk),
	.ce       (ce),
	.reset    (reset),
	.start    (md_start),
	.op       (md_op),
	.a        (md_a),
	.b_hi     (md_bhi),
	.b_lo     (md_blo),
	.busy     (md_busy),
	.done     (md_done),
	.res_hi   (md_hi),
	.res_lo   (md_lo),
	.ovf      (md_ovf),
	.zero_div (md_zero)
);

//----------------------------------------------------------------------------
// Graphics engine (PIXBLT / FILL)
//----------------------------------------------------------------------------

reg         gx_start;
reg   [2:0] gx_kind;
wire        gx_done;
wire [31:0] gx_saddr, gx_daddr, gx_dydx;
wire        gx_wr_saddr, gx_wr_daddr, gx_wr_dydx;
wire        gx_set_v, gx_clr_v, gx_wv, gx_clr_p;
wire [31:0] gx_cycles;

tms34010_gfx gfx
(
	.clk        (clk),
	.ce         (ce),
	.reset      (reset),
	.start      (gx_start),
	.kind       (gx_kind),
	.p_flag     (st[ST_P]),
	.busy       (gx_busy),
	.done       (gx_done),

	.saddr      (rf[B_SADDR]),
	.sptch      (rf[B_SPTCH]),
	.daddr      (rf[B_DADDR]),
	.dptch      (rf[B_DPTCH]),
	.offset     (rf[B_OFFSET]),
	.wstart     (rf[B_WSTART]),
	.wend       (rf[B_WEND]),
	.dydx       (rf[B_DYDX]),
	.color0     (rf[B_COLOR0]),
	.color1     (rf[B_COLOR1]),

	.control    (r_control),
	.psize      (r_psize),
	.srt_mode   (srt_mode),
	.convsp_set (convsp_set),
	.convsp_sh  (convsp_sh),
	.convdp_set (convdp_set),
	.convdp_sh  (convdp_sh),
	.pix_shift  (pix_shift),

	.mem_req    (gx_req),
	.mem_wr     (gx_wr),
	.mem_srt    (gx_srt),
	.mem_baddr  (gx_baddr),
	.mem_wdata  (gx_wdata),
	.mem_ack    (wp_ack),
	.mem_rdata  (wp_rdata),

	.new_saddr  (gx_saddr),
	.new_daddr  (gx_daddr),
	.new_dydx   (gx_dydx),
	.wr_saddr   (gx_wr_saddr),
	.wr_daddr   (gx_wr_daddr),
	.wr_dydx    (gx_wr_dydx),
	.set_v      (gx_set_v),
	.clr_v      (gx_clr_v),
	.raise_wv   (gx_wv),
	.clr_p      (gx_clr_p),
	.cycles     (gx_cycles)
);

//----------------------------------------------------------------------------
// Video timing (the 34010's on-chip CRT controller)
//
// HCOUNT counts VCLKs and wraps after HTOTAL; VCOUNT advances at each wrap.
// Sync runs from count 0 to xESYNC, blanking from xSBLNK to xEBLNK. The display
// address handling copies MAME's scanline callback: VCOUNT is published, the
// display interrupt fires on DPYINT, DPYADR reloads from DPYSTRT at VSBLNK, and
// every visible line hands the board its row/column then steps DPYADR.
//
// Until the game programs sane timing (at power-up and in reset all registers
// are zero) the generator runs the Y Unit's usual 506x289 raster so the
// display stays locked; it keeps counting while the CPU is held in reset.
//
// Games write HEBLNK/HSBLNK during the picture for effects: Total Carnage's
// high score wave sets HEBLNK on every line, from HSBLNK-1 or HSBLNK (nothing
// shown) back down to the normal value. As MAME does, the screen window
// (hblank) stays put and only takes new HEBLNK/HSBLNK values that are valid
// and have been left alone for a few frames (any timing change other than
// HEBLNK/HSBLNK takes them at once). Each line is drawn from the
// HEBLNK/HSBLNK in effect when it starts (line_heblnk/line_hsblnk), so a write
// after VCOUNT reads n changes line n+1, as in MAME.
//----------------------------------------------------------------------------

reg   [9:0] hcnt, vcnt;

// The timing values are registered (two stages): they only change through
// I/O writes, and the beam logic that compares against them stays shallow.
reg         tim_ok, t_hok;
reg   [9:0] t_htotal, t_hesync, t_heblnk, t_hsblnk;
reg   [9:0] t_vtotal, t_vesync, t_veblnk, t_vsblnk;
always @(posedge clk) if (ce) begin
	tim_ok   <= (ioreg[R_HTOTAL] > 16'd100) && (ioreg[R_HTOTAL] < 16'd1000) &&
	            (ioreg[R_VTOTAL] > 16'd100) && (ioreg[R_VTOTAL] < 16'd1000) &&
	            (ioreg[R_VSBLNK] > ioreg[R_VEBLNK]);
	t_htotal <= tim_ok ? ioreg[R_HTOTAL][9:0] : 10'd252;
	t_hesync <= tim_ok ? ioreg[R_HESYNC][9:0] : 10'd18;
	t_heblnk <= tim_ok ? ioreg[R_HEBLNK][9:0] : 10'd45;
	t_hsblnk <= tim_ok ? ioreg[R_HSBLNK][9:0] : 10'd250;
	t_vtotal <= tim_ok ? ioreg[R_VTOTAL][9:0] : 10'd288;
	t_vesync <= tim_ok ? ioreg[R_VESYNC][9:0] : 10'd3;
	t_veblnk <= tim_ok ? ioreg[R_VEBLNK][9:0] : 10'd20;
	t_vsblnk <= tim_ok ? ioreg[R_VSBLNK][9:0] : 10'd276;
	// a usable window: it starts before it ends and ends inside the line
	t_hok    <= (ioreg[R_HSBLNK] > ioreg[R_HEBLNK]) && (ioreg[R_HSBLNK] <= ioreg[R_HTOTAL] + 16'd1);
end

// Screen window (see above): taken with a new raster, else after 3 steady frames
reg   [9:0] w_heblnk, w_hsblnk;      // hblank window
reg   [1:0] w_stable;                // frames HEBLNK/HSBLNK have held (saturates at 3)
reg  [39:0] w_vkey;                  // the rest of the timing the window was taken with
wire [39:0] t_vkey = {t_htotal, t_vtotal, t_veblnk, t_vsblnk};

assign hcount  = hcnt;
assign vcount  = vcnt;
assign heblnk  = w_heblnk;
assign hsblnk  = w_hsblnk;
assign vsblnk  = t_vsblnk;
assign hsync   = (hcnt < t_hesync);
assign vsync   = (vcnt < t_vesync);
assign hblank  = (hcnt < w_heblnk) | (hcnt >= w_hsblnk);
assign vblank  = (vcnt < t_veblnk) | (vcnt >= t_vsblnk);
assign disp_en = r_dpyctl[15];

// REFCNT: MAME returns (total cycles / 16) & 0xfffc
reg  [19:0] refcnt;

// Live HCOUNT read value: MAME scales the beam position and offsets it by HEBLNK;
// returning the true counter is what the hardware does.
assign io_rd_value = (p_ioidx == R_HCOUNT) ? {6'd0, hcnt} :
                     (p_ioidx == R_REFCNT) ? {refcnt[19:6], 2'b00} :
                     (p_ioidx == R_INTPEND) ? {ioreg[R_INTPEND][15:3], int2, int1, ioreg[R_INTPEND][0]} :
                     ioreg[p_ioidx];

//----------------------------------------------------------------------------
// I/O register file
//
// One always block owns every I/O register so CPU writes, video updates and
// interrupt bookkeeping cannot race. CPU writes follow MAME's io_register_w.
//----------------------------------------------------------------------------

reg         seq_set_intpend;     // sequencer-side updates
reg  [15:0] seq_intpend_or;
reg         seq_nmi_ack;

wire        line_wrap = ce_vclk && (hcnt >= t_htotal);
wire  [9:0] vcnt_next = (vcnt >= t_vtotal) ? 10'd0 : vcnt + 10'd1;

//----------------------------------------------------------------------------
// Shorter frames (MiSTer option for 15 kHz TVs, not part of the chip)
//
// Every Y Unit game runs a 289-line frame (54.7 Hz). With frame_lines set,
// blank lines are dropped until a frame is frame_lines long (277: 57.1 Hz,
// 263: 60.1 Hz); the line itself is unchanged. Lines are dropped in frame
// order, starting right after VSBLNK and running on to the end of the frame,
// then from VESYNC up to VEBLNK. Never dropped:
//   - the picture (VEBLNK..VSBLNK-1);
//   - VSBLNK, where DPYADR reloads from DPYSTRT;
//   - the board's VSync lines (0..VESYNC-1);
//   - the line in DPYINT. The games chain display interrupts (each handler
//     writes the next DPYINT, e.g. Smash T.V. 154 -> 282 -> 154), so the
//     interrupt line must come every frame.
// So every interrupt and picture line comes in the same order and the
// picture is untouched; only the blank time between them is shorter. The
// board speeds the CPU and the blitter up by the same ratio (289 / lines),
// so each frame still gets the cycles of the real board.
//
// When the next line is droppable, a run of droppable lines (ending before
// DPYINT or at the end of its zone) is skipped at once, as far as this
// frame's budget allows. The jump is worked out during the line in
// registered steps, from values that only change at line starts (DPYINT a
// few cycles before the end of a line would not be seen; no game writes it
// that late before a blank line).
//----------------------------------------------------------------------------

reg   [9:0] t_drop;              // lines to drop per frame (0: native frame)
reg   [9:0] drop_left;           // lines still to drop in this frame
reg   [9:0] sk_n0, sk_zend, sk_dp, sk_rend, sk_run, sk_k, sk_tgt;
reg         sk_fz, sk_bz, sk_fz2, sk_fz3, sk_ok, sk_ok2;
always @(posedge clk) if (ce) begin
	t_drop  <= ((frame_lines != 10'd0) && (t_vtotal + 10'd1 > frame_lines)) ?
	           (t_vtotal + 10'd1 - frame_lines) : 10'd0;
	// 1: the normal next line and the zone it is in
	sk_n0   <= vcnt_next;
	sk_fz   <= (vcnt_next > t_vsblnk) && (vcnt_next <= t_vtotal);      // after VSBLNK
	sk_bz   <= (vcnt_next >= t_vesync) && (vcnt_next < t_veblnk);      // after VSync
	sk_zend <= ((vcnt_next > t_vsblnk) && (vcnt_next <= t_vtotal)) ? t_vtotal : t_veblnk - 10'd1;
	sk_dp   <= (ioreg[R_DPYINT][15:10] == 6'd0) ? ioreg[R_DPYINT][9:0] : 10'h3FF;
	// 2: last line of the run (before the DPYINT line when it is in the run)
	sk_rend <= ((sk_dp >= sk_n0) && (sk_dp <= sk_zend)) ? sk_dp - 10'd1 : sk_zend;
	sk_ok   <= (sk_fz | sk_bz) && (t_drop != 10'd0);
	sk_fz2  <= sk_fz;
	// 3: run length (0 when the next line is the DPYINT line)
	sk_run  <= sk_rend - sk_n0 + 10'd1;
	sk_ok2  <= sk_ok;
	sk_fz3  <= sk_fz2;
	// 4: lines to skip and where the jump lands
	sk_k    <= !sk_ok2 ? 10'd0 : (drop_left < sk_run) ? drop_left : sk_run;
	sk_tgt  <= sk_n0 + ((drop_left < sk_run) ? drop_left : sk_run);
end
// the front zone ends with the frame: a jump past VTOTAL lands on line 0
wire  [9:0] sk_land  = (sk_fz3 && (sk_tgt > t_vtotal)) ? 10'd0 : sk_tgt;
wire  [9:0] vcnt_new = (sk_k != 10'd0) ? sk_land : vcnt_next;

// DPYADR to row/column, as get_display_params() does it
wire [15:0] dpyadr_cur = ioreg[R_DPYADR];
wire [15:0] dpyadr_vis = r_dpyctl[10] ? dpyadr_cur : (dpyadr_cur ^ 16'hFFFC);

integer k;
always @(posedge clk) if (ce) begin
	line_start <= 1'b0;

	if (reset) begin
		for (k = 0; k < 32; k = k + 1)
			ioreg[k] <= 16'd0;
		convsp_set <= 1'b0;
		convdp_set <= 1'b0;
		convsp_sh  <= 5'd0;
		convdp_sh  <= 5'd0;
		// the CRT timing keeps running (the default raster, the registers
		// being zero) so the display stays locked while the board is held
		// in reset, e.g. during a ROM download
		if (ce_vclk)
			hcnt <= line_wrap ? 10'd0 : hcnt + 10'd1;
		if (line_wrap)
			vcnt <= (vcnt >= t_vtotal) ? 10'd0 : vcnt + 10'd1;
		drop_left  <= 10'd0;
		refcnt     <= 20'd0;
		line_vis   <= 1'b0;
		w_heblnk   <= 10'd45;
		w_hsblnk   <= 10'd250;
		w_stable   <= 2'd0;
		w_vkey     <= 40'd0;
		line_heblnk <= 10'd45;
		line_hsblnk <= 10'd250;
	end
	else begin
		if (ce_cyc)
			refcnt <= refcnt + 20'd1;

		// ---- CRT timing ----
		if (ce_vclk)
			hcnt <= line_wrap ? 10'd0 : hcnt + 10'd1;

		if (line_wrap) begin
			vcnt <= vcnt_new;
			ioreg[R_VCOUNT] <= {6'd0, vcnt_new};

			// shorter frames: the budget restarts at VSBLNK, where the blank begins
			drop_left <= (vcnt_new == t_vsblnk) ? t_drop : drop_left - sk_k;

			if (r_dpyctl[15] && ({6'd0, vcnt_new} == ioreg[R_DPYINT]))
				ioreg[R_INTPEND][INT_DI] <= 1'b1;

			line_start <= 1'b1;
			line_vis   <= ({6'd0, vcnt_new} >= ioreg[R_VEBLNK]) && ({6'd0, vcnt_new} < ioreg[R_VSBLNK]);
			line_heblnk <= t_heblnk;
			line_hsblnk <= t_hsblnk;

			// the screen window: with a new raster at once (the next line),
			// otherwise at the start of a frame once HEBLNK/HSBLNK have held
			if (!tim_ok) begin
				w_heblnk <= 10'd45;
				w_hsblnk <= 10'd250;
				w_vkey   <= 40'd0;
			end
			else if (t_hok) begin
				if ((w_vkey != t_vkey) || ((vcnt_new == 10'd0) && (w_stable == 2'd3))) begin
					w_heblnk <= t_heblnk;
					w_hsblnk <= t_hsblnk;
					w_vkey   <= t_vkey;
				end
				if ((vcnt_new == 10'd0) && (w_stable != 2'd3))
					w_stable <= w_stable + 2'd1;
			end

			if ({6'd0, vcnt_new} == ioreg[R_VSBLNK]) begin
				ioreg[R_DPYADR] <= ioreg[R_DPYSTRT];
				line_row <= r_dpyctl[10] ? ioreg[R_DPYSTRT][15:4] : (ioreg[R_DPYSTRT][15:4] ^ 12'hFFF);
			end
			else begin
				line_row <= dpyadr_vis[15:4];
				// MAME: ((dpyadr & 0x7c) << 4) | DPYTAP (DPYADR bits 6:2 at column bits 10:6)
				line_col <= {3'd0, dpyadr_vis[6:2], 6'd0} | ioreg[R_DPYTAP][13:0];
				if (({6'd0, vcnt_new} >= ioreg[R_VEBLNK]) && ({6'd0, vcnt_new} < ioreg[R_VSBLNK])) begin
					// step to the next display line by DUDATE
					if (dpyadr_cur[1:0] == 2'b00)
						ioreg[R_DPYADR] <= ((dpyadr_cur & 16'hFFFC) - (r_dpyctl & 16'h03FC)) | (ioreg[R_DPYSTRT] & 16'h0003);
					else
						ioreg[R_DPYADR] <= {dpyadr_cur[15:2], dpyadr_cur[1:0] - 2'd1};
				end
			end
		end

		// ---- sequencer side effects ----
		// bit by bit, so a display interrupt raised at this clock's line
		// start (above) is not overwritten by the old INTPEND value
		if (seq_set_intpend)
			for (k = 0; k < 16; k = k + 1)
				if (seq_intpend_or[k]) ioreg[R_INTPEND][k] <= 1'b1;
		if (seq_nmi_ack)
			ioreg[R_HSTCTLH][8] <= 1'b0;

		// ---- CPU writes ----
		if (io_wr_strobe) begin
			case (io_wr_idx)
				R_INTPEND: begin
					// WVP and DIP clear when written with 0; the rest are read only
					if (~io_wr_data[INT_WV]) ioreg[R_INTPEND][INT_WV] <= 1'b0;
					if (~io_wr_data[INT_DI]) ioreg[R_INTPEND][INT_DI] <= 1'b0;
				end
				R_HSTCTLL: begin
					// the 34010 may change MSGOUT, set INTOUT and clear INTIN
					ioreg[R_HSTCTLL] <= (((ioreg[R_HSTCTLL] & 16'hFF8F) | (io_wr_data & 16'h0070)) |
					                     (io_wr_data & 16'h0080)) & (io_wr_data | ~16'h0008);
					if (ioreg[R_HSTCTLL][3] & ~io_wr_data[3])
						ioreg[R_INTPEND][INT_HI] <= 1'b0;
				end
				R_CONVSP: begin
					ioreg[R_CONVSP] <= io_wr_data;
					convsp_set <= 1'b1;
					convsp_sh  <= ~io_wr_data[4:0];
				end
				R_CONVDP: begin
					ioreg[R_CONVDP] <= io_wr_data;
					convdp_set <= 1'b1;
					convdp_sh  <= ~io_wr_data[4:0];
				end
				default:
					ioreg[io_wr_idx] <= io_wr_data;
			endcase
			// a new HEBLNK/HSBLNK value restarts the window's wait
			if (((io_wr_idx == R_HEBLNK) || (io_wr_idx == R_HSBLNK)) && (io_wr_data != ioreg[io_wr_idx]))
				w_stable <= 2'd0;
		end
	end
end

//----------------------------------------------------------------------------
// Interrupt detection
//----------------------------------------------------------------------------

wire [15:0] intpend_live = {ioreg[R_INTPEND][15:3], int2, int1, ioreg[R_INTPEND][0]};
wire [15:0] int_act      = intpend_live & ioreg[R_INTENB];
wire        nmi_pend     = ioreg[R_HSTCTLH][8];
wire        irq_pend     = st[ST_IE] && (int_act[INT_HI] | int_act[INT_DI] | int_act[INT_WV] | int_act[INT_X1] | int_act[INT_X2]);
wire [31:0] irq_vector   = int_act[INT_HI] ? 32'hFFFFFEC0 :
                           int_act[INT_DI] ? 32'hFFFFFEA0 :
                           int_act[INT_WV] ? 32'hFFFFFE80 :
                           int_act[INT_X1] ? 32'hFFFFFFC0 : 32'hFFFFFFA0;
wire        halted       = ioreg[R_HSTCTLH][15];

//----------------------------------------------------------------------------
// Instruction sequencer
//----------------------------------------------------------------------------

localparam S_RESET  = 4'd0;
localparam S_RESETV = 4'd1;
localparam S_BOUND  = 4'd2;      // instruction boundary: wait for the debt, take interrupts
localparam S_DECODE = 4'd4;      // opcode in fu_q
localparam S_IMM    = 4'd5;
localparam S_EXEC   = 4'd6;
localparam S_INT    = 4'd7;
localparam S_DONE   = 4'd8;

reg   [3:0] state /* verilator public_flat_rw */;
reg   [4:0] step;
reg  [15:0] ir;
wire [15:0] op_in  = fu_q[15:0];      // the opcode word, valid in S_DECODE
wire  [8:0] dec_ir = decode(op_in);  // {class, F}

// Register operands. MOVE Rs,Rd across files (0x4E00-0x4FFF) is the one
// exception to "both registers come from the file selected by bit 4": there
// bit 4 picks the source file and the destination is in the other one.
wire        op_cross = (op_in[15:9] == 7'b0100111);
wire  [4:0] op_rs    = ridx(op_in[4], op_in[8:5]);
wire  [4:0] op_rd    = ridx(op_in[4] ^ op_cross, op_in[3:0]);

// Immediate words after the opcode, decoded from the opcode bits directly
wire  [2:0] op_icode = imm_code(op_in);
reg   [2:0] op_nimm;
always @(*) begin
	case (op_icode)
		3'd1:    op_nimm = 3'd1;
		3'd2:    op_nimm = 3'd2;
		3'd3:    op_nimm = 3'd4;
		3'd4:    op_nimm = (op_in[7:0] == 8'h00) ? 3'd1 : 3'd0;    // JRcc with a 16-bit displacement
		3'd5:    op_nimm = (op_in[7:0] == 8'h80) ? 3'd2 : 3'd0;    // JAcc
		default: op_nimm = 3'd0;
	endcase
end
reg   [7:0] cls;
reg         fbit;
reg   [4:0] rs_i, rd_i;
reg  [31:0] rs_v, rd_v;
reg  [15:0] imm [0:3];
reg   [2:0] imm_n, imm_k;
reg  [23:0] cycles;           // machine cycles of the instruction finishing (PIXBLT/FILL can be long)
reg  signed [23:0] debt /* verilator public_flat_rw */;
reg  [31:0] t0, t1;          // scratch kept across steps
reg  [31:0] ba, bb;          // combinational temporaries inside one step
reg   [5:0] bs;
reg  [15:0] mlist;           // MMTM/MMFM register list
reg   [4:0] mreg;            // MMTM/MMFM current register number
reg         wait_fu, wait_md, wait_gx;
reg  [31:0] int_vec;
reg         int_nmi;

wire [31:0] w0s   = {{16{imm[0][15]}}, imm[0]};
wire [31:0] w1s   = {{16{imm[1][15]}}, imm[1]};
wire [31:0] long1 = {imm[1], imm[0]};
wire [31:0] long2 = {imm[3], imm[2]};

// field size/sign for this instruction's F bit (FS=0 means 32)
wire  [4:0] fs     = fbit ? st[10:6] : st[4:0];
wire        fe     = fbit ? st[11]   : st[5];
wire  [5:0] fsize  = (fs == 5'd0) ? 6'd32 : {1'b0, fs};
wire [31:0] finc   = {26'd0, fsize};

wire  [4:0] kfld   = ir[9:5];
wire [31:0] kval   = (kfld == 5'd0) ? 32'd32 : {27'd0, kfld};
wire  [7:0] disp8  = ir[7:0];
wire [31:0] d8s    = {{20{disp8[7]}}, disp8, 4'd0};

// jump condition from opcode bits 11:8
wire        f_n = st[ST_N], f_c = st[ST_C], f_z = st[ST_Z], f_v = st[ST_V];
reg         cond_true;
always @(*) begin
	case (ir[11:8])
		4'h0: cond_true = 1'b1;
		4'h1: cond_true = ~f_n & ~f_z;
		4'h2: cond_true = f_c | f_z;
		4'h3: cond_true = ~f_c & ~f_z;
		4'h4: cond_true = f_n ^ f_v;
		4'h5: cond_true = ~(f_n ^ f_v);
		4'h6: cond_true = (f_n ^ f_v) | f_z;
		4'h7: cond_true = ~(f_n ^ f_v) & ~f_z;
		4'h8: cond_true = f_c;
		4'h9: cond_true = ~f_c;
		4'hA: cond_true = f_z;
		4'hB: cond_true = ~f_z;
		4'hC: cond_true = f_v;
		4'hD: cond_true = ~f_v;
		4'hE: cond_true = f_n;
		default: cond_true = ~f_n;
	endcase
end


// ALU flag helpers (MAME SET_NZCV_ADD / SET_NZCV_SUB semantics)
function automatic [3:0] f_add(input [31:0] a, input [31:0] b, input [31:0] r);
	// {N, C, Z, V}
	reg [31:0] v;
	v = ~(a ^ b) & (a ^ r);
	f_add = {r[31], (~a < b), (r == 32'd0), v[31]};
endfunction
function automatic [3:0] f_sub(input [31:0] a, input [31:0] b, input [31:0] r);
	reg [31:0] v;
	v = (a ^ b) & (a ^ r);
	f_sub = {r[31], (b > a), (r == 32'd0), v[31]};
endfunction

// sign extend / zero extend a register to an FS-bit field (FS=0 means 32)
function automatic [31:0] sext_fs(input [31:0] v, input [4:0] w);
	// kept out of a ?: so the arithmetic shift stays signed
	reg signed [31:0] t;
	t = $signed(v << (6'd32 - {1'b0, w}));
	t = t >>> (6'd32 - {1'b0, w});
	sext_fs = (w == 5'd0) ? v : t;
endfunction
function automatic [31:0] zext_fs(input [31:0] v, input [4:0] w);
	zext_fs = (w == 5'd0) ? v : (v & ((32'd1 << w) - 32'd1));
endfunction

// leftmost-one: number of leading zeros (0 for a zero operand, as in MAME).
// Built as four byte-wide priority encoders and a 4-way select so it stays
// a few logic levels deep.
function automatic [2:0] lz8(input [7:0] v);
	casez (v)
		8'b1???????: lz8 = 3'd0;
		8'b01??????: lz8 = 3'd1;
		8'b001?????: lz8 = 3'd2;
		8'b0001????: lz8 = 3'd3;
		8'b00001???: lz8 = 3'd4;
		8'b000001??: lz8 = 3'd5;
		8'b0000001?: lz8 = 3'd6;
		default:     lz8 = 3'd7;
	endcase
endfunction

function automatic [31:0] lmo(input [31:0] v);
	if      (v[31:24] != 8'd0) lmo = {27'd0, 2'd0, lz8(v[31:24])};
	else if (v[23:16] != 8'd0) lmo = {27'd0, 2'd1, lz8(v[23:16])};
	else if (v[15:8]  != 8'd0) lmo = {27'd0, 2'd2, lz8(v[15:8])};
	else if (v[7:0]   != 8'd0) lmo = {27'd0, 2'd3, lz8(v[7:0])};
	else                       lmo = 32'd0;
endfunction

// window test on an XY register (signed 16-bit components)
function automatic outside_win(input [31:0] xy, input [31:0] ws, input [31:0] we);
	outside_win = ($signed(xy[15:0]) < $signed(ws[15:0])) || ($signed(xy[15:0]) > $signed(we[15:0])) ||
	              ($signed(xy[31:16]) < $signed(ws[31:16])) || ($signed(xy[31:16]) > $signed(we[31:16]));
endfunction


// shift results (computed combinationally from the latched operands)
wire  [4:0] sh_k_imm = kfld;
wire  [4:0] sh_k_reg = rs_v[4:0];
reg         sh_isreg;        // shift count from Rs (set at decode)
wire  [4:0] sh_kl    = sh_isreg ? sh_k_reg : sh_k_imm;                     // left shift / rotate count
wire  [4:0] sh_kr    = sh_isreg ? (5'd0 - rs_v[4:0]) : (5'd0 - kfld);     // right shift count (2's complement field)
wire [31:0] sll_res  = rd_v << sh_kl;
wire        sll_c    = (sh_kl != 5'd0) && rd_v[5'd0 - sh_kl];      // last bit shifted out: bit 32-k
wire [31:0] srl_res  = rd_v >> sh_kr;
wire        srl_c    = (sh_kr != 5'd0) && rd_v[sh_kr - 5'd1];
wire [31:0] sra_res  = $signed(rd_v) >>> sh_kr;
wire [31:0] rl_res   = (sh_kl == 5'd0) ? rd_v : ((rd_v << sh_kl) | (rd_v >> (6'd32 - {1'b0, sh_kl})));
wire [31:0] sla_mask = (32'hFFFF_FFFF << (5'd31 - sh_kl)) & 32'h7FFF_FFFF;
wire [31:0] sla_res2 = rd_v[31] ? (rd_v ^ sla_mask) : rd_v;
wire        sla_v    = (sh_kl != 5'd0) && ((sla_res2 & sla_mask) != 32'd0);

// XY arithmetic
wire [15:0] xs = rs_v[15:0], ys = rs_v[31:16];
wire [15:0] xd = rd_v[15:0], yd = rd_v[31:16];
wire [15:0] addx = xd + xs, addy = yd + ys;
wire [15:0] subx = xd - xs, suby = yd - ys;


// Sequencer helper tasks (kept as macros of assignments inside the clocked block)
task automatic fu_read(input [31:0] a, input [5:0] sz, input sx);
	fu_go      <= 1'b1;
	fu_wr_in   <= 1'b0;
	fu_addr_in <= a;
	fu_size_in <= sz;
	fu_sext_in <= sx;
	wait_fu    <= 1'b1;
endtask
task automatic fu_write(input [31:0] a, input [5:0] sz, input [31:0] d);
	fu_go      <= 1'b1;
	fu_wr_in   <= 1'b1;
	fu_addr_in <= a;
	fu_size_in <= sz;
	fu_data_in <= d;
	wait_fu    <= 1'b1;
endtask

// Pixel access operands for the shared read/write sub-sequences in S_EXEC
reg [31:0] pw_addr, pw_data;

// The sequencer stalls while a unit it started is still working. The test is
// on the units' own status so the state that needs the result runs in the
// very cycle the result appears.
wire seq_wait = (wait_fu & (fu_go | srt_go | fu_busy)) |
                (wait_md & ~md_done) |
                (wait_gx & ~gx_done);

// Debt after charging the instruction that is finishing in S_DONE
// The floor only limits how much lost time is caught up afterwards; while an
// instruction runs (a long PIXBLT/FILL included) every machine cycle counts.
wire signed [23:0] debt_sum  = debt + $signed(cycles) - (ce_cyc ? 24'sd1 : 24'sd0);
wire signed [23:0] debt_done = (debt_sum < -24'sd64) ? -24'sd64 : debt_sum;

// Instruction boundary: take a pending interrupt or start the next fetch
// (opcode fetches ignore PC[3:0], as the word bus does)
task automatic boundary;
	if (nmi_pend) begin
		int_nmi <= 1'b1;
		int_vec <= 32'hFFFF_FEE0;
		step    <= 5'd0;
		state   <= S_INT;
	end
	else if (irq_pend) begin
		int_nmi <= 1'b0;
		int_vec <= irq_vector;
		step    <= 5'd0;
		state   <= S_INT;
	end
	else begin
		fu_read(pc & 32'hFFFF_FFF0, 6'd16, 1'b0);
		state <= S_DECODE;
	end
endtask

// Register file write ports. A write to a register picked by the opcode is
// requested with rf_wr() and lands at the end of the cycle; one shared data
// path per port keeps the 32 registers from each getting a copy of every
// instruction's result multiplexer. When an instruction writes two registers
// the second request wins if they are the same (MPY with an odd Rd, MMFM
// loading its own pointer, MOVE *Rs+,Rd with Rs == Rd).
reg         rfa_en, rfb_en;
reg   [4:0] rfa_idx, rfb_idx;
reg  [31:0] rfa_dat, rfb_dat;

task automatic rf_wr(input [4:0] idx, input [31:0] dat);
	if (!rfa_en) begin
		rfa_en  = 1'b1;
		rfa_idx = idx;
		rfa_dat = dat;
	end
	else begin
		rfb_en  = 1'b1;
		rfb_idx = idx;
		rfb_dat = dat;
	end
endtask

always @(posedge clk) if (ce) begin
	rfa_en  = 1'b0;
	rfb_en  = 1'b0;
	rfa_idx = 5'd0;
	rfb_idx = 5'd0;
	rfa_dat = 32'd0;
	rfb_dat = 32'd0;

	fu_go           <= 1'b0;
	srt_go          <= 1'b0;
	md_start        <= 1'b0;
	gx_start        <= 1'b0;
	seq_set_intpend <= 1'b0;
	seq_nmi_ack     <= 1'b0;
	dbg_retire      <= 1'b0;

	// machine cycles drain the debt; waiting at a boundary it stops at the floor
	if (ce_cyc && ((state != S_BOUND) || (debt > -24'sd64)))
		debt <= debt - 24'sd1;

	if (reset) begin
		state   <= S_RESET;
		debt    <= 24'sd0;
		wait_fu <= 1'b0;
		wait_md <= 1'b0;
		wait_gx <= 1'b0;
		st      <= 32'h0000_0010;
		pc      <= 32'd0;
		for (k = 0; k < 32; k = k + 1)
			rf[k] <= 32'd0;
	end
	else if (!seq_wait) begin
		// a state that starts a unit sets its wait flag again below
		wait_fu <= 1'b0;
		wait_md <= 1'b0;
		wait_gx <= 1'b0;
		case (state)
			S_RESET: begin
				fu_read(32'hFFFF_FFE0, 6'd32, 1'b0);
				state <= S_RESETV;
			end

			S_RESETV: begin
				pc    <= fu_q & 32'hFFFF_FFF0;
				st    <= 32'h0000_0010;
				debt  <= 24'sd0;
				state <= S_BOUND;
			end

			S_BOUND: begin
				// wait for the time already spent, then take interrupts or fetch
				if (!halted && !pause && (debt <= 24'sd0))
					boundary;
			end

			S_DECODE: begin
				ir    <= op_in;
				pc    <= pc + 32'd16;
				{cls, fbit} <= dec_ir;
				sh_isreg <= (dec_ir[8:1] == I_SLA_R) || (dec_ir[8:1] == I_SLL_R) || (dec_ir[8:1] == I_SRA_R) ||
				            (dec_ir[8:1] == I_SRL_R) || (dec_ir[8:1] == I_RL_R);
				rs_i  <= op_rs;
				rd_i  <= op_rd;
				rs_v  <= rf[op_rs];
				rd_v  <= rf[op_rd];
				imm_n <= op_nimm;
				imm_k <= 3'd0;
				step  <= 5'd0;
				if (op_nimm != 3'd0) begin
					fu_read((pc + 32'd16) & 32'hFFFF_FFF0, 6'd16, 1'b0);
					state <= S_IMM;
				end
				else
					state <= S_EXEC;
			end

			S_IMM: begin
				// collect the parameter words that follow the opcode
				imm[imm_k[1:0]] <= fu_q[15:0];
				pc         <= pc + 32'd16;
				imm_k      <= imm_k + 3'd1;
				if (imm_k + 3'd1 == imm_n)
					state <= S_EXEC;
				else
					fu_read((pc + 32'd16) & 32'hFFFF_FFF0, 6'd16, 1'b0);
			end

			S_INT: begin
				// PUSH PC, PUSH ST, ST = 0x10, PC = vector (NMI may skip the pushes)
				case (step)
					5'd0: begin
						if (int_nmi) seq_nmi_ack <= 1'b1;
						if (int_nmi && ioreg[R_HSTCTLH][9])
							step <= 5'd2;
						else begin
							rf[15] <= rf[15] - 32'd32;
							fu_write(rf[15] - 32'd32, 6'd32, pc);
							step <= 5'd1;
						end
					end
					5'd1: begin
						rf[15] <= rf[15] - 32'd32;
						fu_write(rf[15] - 32'd32, 6'd32, st);
						step <= 5'd2;
					end
					5'd2: begin
						st <= 32'h0000_0010;
						fu_read(int_vec, 6'd32, 1'b0);
						step <= 5'd3;
					end
					default: begin
						pc     <= fu_q;
						cycles <= 24'd16;
						state  <= S_DONE;
					end
				endcase
			end

			S_EXEC: begin
				`include "tms34010_exec.svh"
			end

			S_DONE: begin
				debt       <= debt_done;
				dbg_retire <= 1'b1;
				dbg_cycles <= cycles[15:0];
				// go straight on when the time is already paid; an interrupt the
				// instruction itself just raised is left for S_BOUND to see
				if (!halted && !pause && (debt_done <= 24'sd0) && !seq_set_intpend)
					boundary;
				else
					state <= S_BOUND;
			end

			default: state <= S_RESET;
		endcase
	end

	if (rfa_en) rf[rfa_idx] <= rfa_dat;
	if (rfb_en) rf[rfb_idx] <= rfb_dat;
end

endmodule
