//============================================================================
//  TMS34010 graphics engine: PIXBLT and FILL
//
//  Runs one PIXBLT (L,L / L,XY / XY,L / XY,XY / B,L / B,XY) or FILL (L / XY)
//  to completion on behalf of the CPU sequencer, which hands over the memory
//  port while this is busy.
//
//  The loops are a direct translation of MAME's pixblt / pixblt_r / pixblt_b /
//  fill templates (34010gfx.hxx), including the order of word reads and writes.
//  That matters: overlapping source and destination blocks, and VRAM
//  shift-register mode (where a read loads the shift register), only give the
//  same result if every access happens in the same order.
//
//  Cycle counts are MAME's approximations; they are returned in `cycles` and
//  charged to the CPU's cycle budget. Clipped-away and window-mode-1 operations
//  cost nothing, as in MAME.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module tms34010_gfx
(
	input             clk,
	input             ce,
	input             reset,

	input             start,
	input       [2:0] kind,         // 0 L,L 1 L,XY 2 XY,L 3 XY,XY 4 B,L 5 B,XY 6 FILL L 7 FILL XY
	input             p_flag,       // ST.P at entry: the operation is being resumed
	output reg        busy,
	output reg        done,

	// implied B-file operands
	input      [31:0] saddr,
	input      [31:0] sptch,
	input      [31:0] daddr,
	input      [31:0] dptch,
	input      [31:0] offset,
	input      [31:0] wstart,
	input      [31:0] wend,
	input      [31:0] dydx,
	input      [31:0] color0,
	input      [31:0] color1,

	// I/O register state
	input      [15:0] control,
	input      [15:0] psize,
	input             srt_mode,     // DPYCTL.SRT: word accesses become shift-register transfers
	input             convsp_set,
	input       [4:0] convsp_sh,
	input             convdp_set,
	input       [4:0] convdp_sh,
	input       [2:0] pix_shift,    // XY-to-linear pixel shift (from PSIZE)

	// word memory port (shared with the CPU)
	output reg        mem_req,
	output reg        mem_wr,
	output reg        mem_srt,
	output reg [31:0] mem_baddr,
	output reg [15:0] mem_wdata,
	input             mem_ack,
	input      [15:0] mem_rdata,

	// results for the CPU
	output reg [31:0] new_saddr,
	output reg [31:0] new_daddr,
	output reg [31:0] new_dydx,
	output reg        wr_saddr,
	output reg        wr_daddr,
	output reg        wr_dydx,
	output reg        set_v,
	output reg        clr_v,
	output reg        raise_wv,     // window-violation interrupt request
	output reg        clr_p,        // operation completed: clear ST.P
	output reg [31:0] cycles
);

//----------------------------------------------------------------------------
// Static per-operation parameters
//----------------------------------------------------------------------------

// MAME's pixelsize_lookup: PSIZE & 0x1f -> 1/2/4/8/16 bits (so 32 means 1)
reg  [2:0] bpp_log;
always @(*) begin
	case (psize[4:0])
		5'd0, 5'd1:                                  bpp_log = 3'd0;
		5'd2, 5'd3:                                  bpp_log = 3'd1;
		5'd4, 5'd5, 5'd6, 5'd7:                      bpp_log = 3'd2;
		5'd8, 5'd9, 5'd10, 5'd11,
		5'd12, 5'd13, 5'd14, 5'd15:                  bpp_log = 3'd3;
		default:                                     bpp_log = 3'd4;
	endcase
end

// Pixel size figures, latched when an operation starts
reg   [2:0] lg;                       // log2(bits per pixel)
reg   [4:0] bpp;                      // bits per pixel
reg   [4:0] ppw;                      // pixels per word
reg  [15:0] pmask;                    // one pixel's worth of low bits

reg         trans;
reg   [4:0] rop;
reg         pbv;
reg   [1:0] wc;
reg         op_x;                     // a pixel processing op is active (needs the destination)
reg   [3:0] timing;                   // PIXEL_OP_TIMING for this variant

// MAME s_pixel_op_timing_table
wire [3:0] op_tab_t = (rop == 5'd0) ? 4'd2 :
                      (rop == 5'd17 || rop == 5'd18 || rop == 5'd20 || rop == 5'd21) ? 4'd5 :
                      (rop == 5'd19) ? 4'd6 :
                      (rop >= 5'd22) ? 4'd2 : 4'd4;

//----------------------------------------------------------------------------
// Pixel processing ops (MAME pixel_op00..21), evaluated on 32-bit operands
//----------------------------------------------------------------------------

function automatic [31:0] pixel_op(input [4:0] op, input [31:0] dst, input [31:0] mask, input [31:0] src);
	reg [31:0] tmp;
	case (op)
		5'd1:    pixel_op = src & dst;
		5'd2:    pixel_op = src & ~dst;
		5'd3:    pixel_op = 32'd0;
		5'd4:    pixel_op = (src | ~dst) & mask;
		5'd5:    pixel_op = ~(src ^ dst) & mask;
		5'd6:    pixel_op = ~dst & mask;
		5'd7:    pixel_op = ~(src | dst) & mask;
		5'd8:    pixel_op = (src | dst) & mask;
		5'd9:    pixel_op = dst & mask;
		5'd10:   pixel_op = (src ^ dst) & mask;
		5'd11:   pixel_op = (~src & dst) & mask;
		5'd12:   pixel_op = mask;
		5'd13:   pixel_op = (~src & dst) & mask;
		5'd14:   pixel_op = ~(src & dst) & mask;
		5'd15:   pixel_op = src ^ mask;
		5'd16:   pixel_op = (src + dst) & mask;
		5'd17: begin
			tmp = src + (dst & mask);
			pixel_op = (tmp > mask) ? mask : tmp;
		end
		5'd18:   pixel_op = (dst - src) & mask;
		5'd19: begin
			tmp = src - (dst & mask);
			pixel_op = tmp[31] ? 32'd0 : tmp;
		end
		5'd20: begin
			tmp = dst & mask;
			pixel_op = (src > tmp) ? src : tmp;
		end
		5'd21: begin
			tmp = dst & mask;
			pixel_op = (src < tmp) ? src : tmp;
		end
		default: pixel_op = src;
	endcase
endfunction

function automatic [31:0] gxytol(input [31:0] xy, input conv_set, input [4:0] conv_sh,
                                input [2:0] psh, input [31:0] offs);
	reg [31:0] y_term, x_term;
	y_term = conv_set ? ({{16{xy[31]}}, xy[31:16]} << conv_sh) : 32'd0;
	x_term = {{16{xy[15]}}, xy[15:0]} << psh;
	gxytol = y_term + x_term + offs;
endfunction

//----------------------------------------------------------------------------
// State
//----------------------------------------------------------------------------

localparam G_IDLE    = 5'd0;
localparam G_SETUP   = 5'd1;      // timing, window clip
localparam G_ADDR    = 5'd2;      // destination address
localparam G_CHECK   = 5'd3;      // clip / window-mode-1 exits, row setup
localparam G_MEM     = 5'd4;      // memory access in flight, continue at g_ret
localparam G_FROW    = 5'd5;      // forward PIXBLT: row start
localparam G_FROW1   = 5'd6;
localparam G_FROW2   = 5'd7;
localparam G_FPIX    = 5'd8;
localparam G_FPIX1   = 5'd9;
localparam G_FPIX2   = 5'd10;
localparam G_FPIX3   = 5'd11;
localparam G_FPIX4   = 5'd12;
localparam G_FEND    = 5'd13;
localparam G_FEND1   = 5'd14;
localparam G_FEND2   = 5'd15;
localparam G_NEXTROW = 5'd16;
localparam G_SROW    = 5'd17;     // segmented ops: row start
localparam G_SROW1   = 5'd18;
localparam G_SSEG    = 5'd19;     // segment start
localparam G_SSEG1   = 5'd20;
localparam G_SPIX    = 5'd21;
localparam G_SPIX1   = 5'd22;     // reverse PIXBLT: new source word
localparam G_SPIX2   = 5'd23;
localparam G_BSRC    = 5'd24;     // PIXBLT B: new source word
localparam G_SWR     = 5'd25;
localparam G_SWR1    = 5'd26;
localparam G_FINISH  = 5'd27;
localparam G_FIN1    = 5'd28;
localparam G_SROWC   = 5'd29;     // segmented ops: row cost from the geometry
localparam G_SROWD   = 5'd30;     // segmented ops: charge it

reg   [4:0] g_state, g_ret;

reg         src_lin, dst_lin;
reg         is_blt, is_b, is_fill, is_rev;

reg  [31:0] s0;                       // source start address after XY conversion / clipping
reg  [31:0] r_saddr, r_daddr;         // current row addresses
reg  [31:0] dstxy;
reg  signed [31:0] dx, dy;
reg  [31:0] gcyc;
reg  [31:0] rw;                       // forward PIXBLT access count
reg  [31:0] dxt;                      // dx * (timing - 2), per-row forward cost
reg  [15:0] yi;                       // row index
reg  [15:0] xi;                       // pixel index in row / segment

reg  [27:0] swa, dwa;                 // word addresses
reg   [5:0] sbit, dbit;
reg  [31:0] sword, dword;             // forward: 32-bit windows; segmented: low 16 bits used
reg  [15:0] smask, dmask;
reg  [31:0] pixv;                     // forward PIXBLT: source pixel at its destination position
reg  [31:0] fp_dm;                    // forward PIXBLT: destination pixel mask
reg  [31:0] wcyc_r;                   // window clipping cost, added in G_ADDR
reg  [31:0] row_cost;                 // segmented ops: cost of one row

// segmented-op row geometry
reg  [15:0] left_p, right_p, full_w;
reg   [3:0] bshift, bshift_alt;
reg   [1:0] seg;                      // 0 first partial, 1 full words, 2 last partial, 3 done
reg  [15:0] seg_cnt;                  // full words remaining
reg  [15:0] seg_pix;                  // pixels in current segment

reg  [15:0] m_q;                      // last word read

// MAME keeps m_gfxcycles between operations; an operation entered with P set
// (resumed after an interrupt, or P set by software) only pays what is left.
// Here the work is always finished in one go, so a resume charges the last
// operation's figure again, exactly as MAME's step-at-a-time path does.
reg  [31:0] last_cyc;

wire signed [31:0] wsx    = {{16{wstart[15]}}, wstart[15:0]};
wire signed [31:0] wsy    = {{16{wstart[31]}}, wstart[31:16]};
wire signed [31:0] wex    = {{16{wend[15]}}, wend[15:0]};
wire signed [31:0] wey    = {{16{wend[31]}}, wend[31:16]};
wire signed [31:0] dydx_x = {{16{dydx[15]}}, dydx[15:0]};
wire signed [31:0] dydx_y = {{16{dydx[31]}}, dydx[31:16]};
wire signed [31:0] dxy_x  = {{16{daddr[15]}}, daddr[15:0]};
wire signed [31:0] dxy_y  = {{16{daddr[31]}}, daddr[31:16]};
wire        [31:0] bpp_m1 = {27'd0, bpp} - 32'd1;

// products for the final register update (DYDX_Y * pitch)
reg signed [31:0] prod_s, prod_d;

task automatic mem_read(input [27:0] wa, input [4:0] ret);
	if (is_fill && srt_mode) begin
		// FILL in shift-register mode uses a dummy read that touches nothing
		m_q     <= 16'd0;
		g_state <= ret;
	end
	else begin
		mem_req   <= 1'b1;
		mem_wr    <= 1'b0;
		mem_srt   <= srt_mode;
		mem_baddr <= {wa, 4'd0};
		g_ret     <= ret;
		g_state   <= G_MEM;
	end
endtask

task automatic mem_write(input [27:0] wa, input [15:0] d, input [4:0] ret);
	mem_req   <= 1'b1;
	mem_wr    <= 1'b1;
	mem_srt   <= srt_mode;
	mem_baddr <= {wa, 4'd0};
	mem_wdata <= d;
	g_ret     <= ret;
	g_state   <= G_MEM;
endtask

// Segmented ops: the source pixel for the current destination position,
// latched in G_SPIX and merged in G_SPIX2
reg  [15:0] sp_p;
reg  [15:0] sp_src;
always @(*) begin
	if (is_rev) begin
		sp_src = sword[15:0] & smask;
		if (dmask > smask) sp_src = sp_src << bshift;
		else               sp_src = sp_src >> bshift_alt;
	end
	else if (is_b)
		sp_src = (((sword[15:0] & smask) != 16'd0) ? color1[15:0] : color0[15:0]) & dmask;
	else
		sp_src = color1[15:0] & dmask;
end

// Words touched by one row of a segmented operation (partials count as one)
wire [31:0] seg_words = {16'd0, full_w} + ((left_p != 16'd0) ? 32'd1 : 32'd0) + ((right_p != 16'd0) ? 32'd1 : 32'd0);

// Start a segmented row: source/destination word addresses and the first read
task automatic srow_start;
	bshift     <= r_daddr[3:0] - r_saddr[3:0];
	bshift_alt <= 4'd0 - (r_daddr[3:0] - r_saddr[3:0]);
	if (is_rev) begin
		// word addresses round up; the first source word is the one before
		swa <= r_saddr[31:4] + ((r_saddr[3:0] != 4'd0) ? 28'd1 : 28'd0) - 28'd1;
		dwa <= r_daddr[31:4] + ((r_daddr[3:0] != 4'd0) ? 28'd1 : 28'd0);
		mem_read(r_saddr[31:4] + ((r_saddr[3:0] != 4'd0) ? 28'd1 : 28'd0) - 28'd1, G_SROW1);
	end
	else if (is_b) begin
		swa <= r_saddr[31:4] + 28'd1;
		dwa <= r_daddr[31:4];
		mem_read(r_saddr[31:4], G_SROW1);
	end
	else begin
		dwa     <= r_daddr[31:4];
		g_state <= G_SROW1;
	end
endtask

always @(posedge clk) if (ce) begin
	done <= 1'b0;

	if (reset) begin
		g_state  <= G_IDLE;
		busy     <= 1'b0;
		mem_req  <= 1'b0;
		last_cyc <= 32'd0;
	end
	else begin
		case (g_state)
			G_IDLE: if (start) begin
				busy     <= 1'b1;
				lg       <= bpp_log;
				bpp      <= 5'd1 << bpp_log;
				ppw      <= 5'd16 >> bpp_log;
				case (bpp_log)
					3'd0:    pmask <= 16'h0001;
					3'd1:    pmask <= 16'h0003;
					3'd2:    pmask <= 16'h000F;
					3'd3:    pmask <= 16'h00FF;
					default: pmask <= 16'hFFFF;
				endcase
				trans    <= control[5];
				rop      <= control[14:10];
				pbv      <= control[9];
				wc       <= control[7:6];
				src_lin  <= (kind == 3'd0) || (kind == 3'd1) || (kind >= 3'd4);
				dst_lin  <= (kind == 3'd0) || (kind == 3'd2) || (kind == 3'd4) || (kind == 3'd6);
				is_blt   <= (kind < 3'd4);
				is_b     <= (kind == 3'd4) || (kind == 3'd5);
				is_fill  <= (kind >= 3'd6);
				is_rev   <= (kind < 3'd4) && control[8];
				op_x     <= (control[14:10] != 5'd0);
				wr_saddr <= 1'b0;
				wr_daddr <= 1'b0;
				wr_dydx  <= 1'b0;
				set_v    <= 1'b0;
				clr_v    <= 1'b0;
				raise_wv <= 1'b0;
				clr_p    <= 1'b0;
				dstxy    <= daddr;
				// source address (PIXBLT B and FILL take SADDR as is / not at all)
				if ((kind == 3'd2) || (kind == 3'd3))
					s0 <= gxytol(saddr, convsp_set, convsp_sh, pix_shift, offset);
				else
					s0 <= saddr;
				if (kind < 3'd4)
					gcyc <= ((kind == 3'd2) || (kind == 3'd3)) ? 32'd9 : 32'd7;
				else
					gcyc <= 32'd4;
				if (p_flag) begin
					// resume: nothing left to draw, just finish
					gcyc    <= last_cyc;
					g_state <= G_FINISH;
				end
				else
					g_state <= G_SETUP;
			end

			G_SETUP: begin
				// PIXEL_OP_TIMING for the selected variant
				if (!op_x) timing <= trans ? 4'd4 : 4'd2;
				else       timing <= trans ? (4'd2 + op_tab_t) : op_tab_t;

				if (dst_lin || (wc == 2'd0)) begin
					// no clipping: the reverse PIXBLT still aligns its source
					dx <= dydx_x;
					dy <= dydx_y;
					if (is_rev) s0 <= s0 & ~bpp_m1;
					if (!dst_lin)
						gcyc <= gcyc + 32'd2 + ((is_blt && !src_lin) ? 32'd1 : 32'd0);
					wcyc_r <= 32'd0;
				end
				else begin : apply_window
					// apply_window(): clip to WSTART/WEND, nudging the source address along
					reg signed [31:0] sx, sy, ex, ey;
					reg        [31:0] sa, wcyc;
					reg               v;
					sx   = dxy_x;
					sy   = dxy_y;
					ex   = dxy_x + dydx_x - 32'sd1;
					ey   = dxy_y + dydx_y - 32'sd1;
					sa   = is_rev ? (s0 & ~bpp_m1) : s0;
					v    = (wc == 2'd1);
					wcyc = 32'd3;
					if (wsx - sx > 0) begin
						if (is_blt) sa = sa + ((wsx - sx) << lg);
						if (is_b)   sa = sa + (wsx - sx);
						sx = wsx;
						v  = 1'b1;
					end
					if (ex - wex > 0) begin
						ex = wex;
						v  = 1'b1;
					end
					if (wsy - sy > 0) begin
						if (!is_fill && convsp_set) sa = sa + ((wsy - sy) << convsp_sh);
						sy = wsy;
						v  = 1'b1;
					end
					if (ey - wey > 0) begin
						ey = wey;
						v  = 1'b1;
					end
					if ((dydx_x != ex - sx + 32'sd1) || (dydx_y != ey - sy + 32'sd1))
						wcyc = wcyc + (((dxy_x != sx) || (dxy_y != sy)) ? 32'd11 : 32'd3);
					else if ((dxy_x != sx) || (dxy_y != sy))
						wcyc = wcyc + 32'd7;
					s0    <= sa;
					dx    <= ex - sx + 32'sd1;
					dy    <= ey - sy + 32'sd1;
					dstxy <= {sy[15:0], sx[15:0]};
					clr_v <= ~v;
					set_v <= v;
					gcyc   <= gcyc + 32'd2 + ((is_blt && !src_lin) ? 32'd1 : 32'd0);
					wcyc_r <= wcyc;
				end
				g_state <= G_ADDR;
			end

			G_ADDR: begin
				gcyc <= gcyc + wcyc_r;
				if (dst_lin)
					r_daddr <= daddr & ~bpp_m1;
				else
					r_daddr <= gxytol(dstxy, convdp_set, convdp_sh, pix_shift, offset) & ~bpp_m1;
				g_state <= G_CHECK;
			end

			G_CHECK: begin
				if ((dx <= 0) || (dy <= 0)) begin
					// clipped away: nothing drawn, no cycles, address registers untouched
					last_cyc <= gcyc;
					cycles  <= 32'd0;
					busy    <= 1'b0;
					done    <= 1'b1;
					g_state <= G_IDLE;
				end
				else if ((wc == 2'd1) && !dst_lin) begin
					// window hit detection only: report the clipped block
					clr_v     <= 1'b1;
					set_v     <= 1'b0;
					new_daddr <= dstxy;
					new_dydx  <= {dy[15:0], dx[15:0]};
					wr_daddr  <= 1'b1;
					wr_dydx   <= 1'b1;
					raise_wv  <= 1'b1;
					last_cyc  <= gcyc;
					cycles    <= 32'd0;
					busy      <= 1'b0;
					done      <= 1'b1;
					g_state   <= G_IDLE;
				end
				else begin
					yi  <= 16'd0;
					rw  <= 32'd0;
					dxt <= dx * ({28'd0, timing} - 32'd2);
					r_saddr <= s0;
					if (is_blt && !is_rev) begin
						if ((!src_lin || !dst_lin) && pbv) begin
							r_saddr <= s0 + (convsp_set ? ((dy - 32'sd1) << convsp_sh) : 32'd0);
							r_daddr <= r_daddr + (convdp_set ? ((dy - 32'sd1) << convdp_sh) : 32'd0);
						end
						g_state <= G_FROW;
					end
					else begin
						if (is_rev && (!src_lin || !dst_lin)) begin
							r_saddr <= s0 + (dx << lg) + ((pbv && convsp_set) ? ((dy - 32'sd1) << convsp_sh) : 32'd0);
							r_daddr <= r_daddr + (dx << lg) + ((pbv && convdp_set) ? ((dy - 32'sd1) << convdp_sh) : 32'd0);
						end
						if (is_fill) gcyc <= gcyc + 32'd2;
						g_state <= G_SROW;
					end
				end
			end

			//----------------------------------------------------------
			// memory access in flight
			//----------------------------------------------------------
			G_MEM: if (mem_ack) begin
				mem_req <= 1'b0;
				m_q     <= mem_rdata;
				g_state <= g_ret;
			end

			//----------------------------------------------------------
			// forward PIXBLT (left to right)
			//----------------------------------------------------------
			G_FROW: begin
				if (yi == dy[15:0]) begin
					gcyc    <= gcyc + (rw << 1);
					g_state <= G_FINISH;
				end
				else begin
					gcyc  <= gcyc + dxt;
					swa   <= r_saddr[31:4] + 28'd1;
					dwa   <= r_daddr[31:4];
					sbit  <= {2'd0, r_saddr[3:0]};
					dbit  <= {2'd0, r_daddr[3:0]};
					xi    <= 16'd0;
					rw    <= rw + 32'd1;
					mem_read(r_saddr[31:4], G_FROW1);
				end
			end

			G_FROW1: begin
				// initial source word; the destination word is only needed for ops,
				// transparency or an unaligned start
				sword <= {16'd0, m_q};
				dword <= 32'd0;
				if (op_x || trans || (dbit != 6'd0)) begin
					rw <= rw + 32'd1;
					mem_read(dwa, G_FROW2);
				end
				else
					g_state <= G_FPIX;
			end

			G_FROW2: begin
				dword   <= {16'd0, m_q};
				g_state <= G_FPIX;
			end

			G_FPIX: begin
				if (xi == dx[15:0])
					g_state <= G_FEND;
				else if (sbit + {1'b0, bpp} > 6'd16) begin
					rw  <= rw + 32'd1;
					swa <= swa + 28'd1;
					mem_read(swa, G_FPIX1);
				end
				else
					g_state <= G_FPIX2;
			end

			G_FPIX1: begin
				sword   <= sword | {m_q, 16'd0};
				g_state <= G_FPIX2;
			end

			G_FPIX2: begin
				// extract the source pixel and advance the source window
				// the pixel and its mask, already moved to the destination position
				pixv  <= ((sword >> sbit[4:0]) & {16'd0, pmask}) << dbit[4:0];
				fp_dm <= {16'd0, pmask} << dbit[4:0];
				if (sbit + {1'b0, bpp} > 6'd16) begin
					sbit  <= sbit + {1'b0, bpp} - 6'd16;
					sword <= sword >> 16;
				end
				else
					sbit <= sbit + {1'b0, bpp};
				if ((op_x || trans) && (dbit + {1'b0, bpp} > 6'd16)) begin
					rw <= rw + 32'd1;
					mem_read(dwa + 28'd1, G_FPIX3);
				end
				else
					g_state <= G_FPIX4;
			end

			G_FPIX3: begin
				dword   <= dword | {m_q, 16'd0};
				g_state <= G_FPIX4;
			end

			G_FPIX4: begin : fpix
				// merge the pixel into the destination window; flush a word once full
				reg [31:0] dw, dm, pv;
				dw = dword;
				dm = fp_dm;
				pv = pixv;
				if (op_x) pv = pixel_op(rop, dw, dm, pv);
				if (!trans || (pv != 32'd0))
					dw = (dw & ~dm) | pv;
				xi <= xi + 16'd1;
				if (dbit + {1'b0, bpp} > 6'd16) begin
					dbit  <= dbit + {1'b0, bpp} - 6'd16;
					dword <= dw >> 16;
					dwa   <= dwa + 28'd1;
					rw    <= rw + 32'd1;
					mem_write(dwa, dw[15:0], G_FPIX);
				end
				else begin
					dbit    <= dbit + {1'b0, bpp};
					dword   <= dw;
					g_state <= G_FPIX;
				end
			end

			G_FEND: begin
				// flush the last destination word of the row, merging a right partial
				if (dbit == 6'd0)
					g_state <= G_NEXTROW;
				else if (dbit != 6'd16) begin
					rw <= rw + 32'd1;
					mem_read(dwa, G_FEND1);
				end
				else
					g_state <= G_FEND2;
			end

			G_FEND1: begin
				dword[15:0] <= (dword[15:0] & ~(16'hFFFF << dbit[3:0])) | (m_q & (16'hFFFF << dbit[3:0]));
				g_state     <= G_FEND2;
			end

			G_FEND2: begin
				rw <= rw + 32'd1;
				mem_write(dwa, dword[15:0], G_NEXTROW);
			end

			G_NEXTROW: begin
				yi <= yi + 16'd1;
				if (!pbv || is_b || is_fill) begin
					r_saddr <= r_saddr + sptch;
					r_daddr <= r_daddr + dptch;
				end
				else begin
					r_saddr <= r_saddr - sptch;
					r_daddr <= r_daddr - dptch;
				end
				g_state <= (is_blt && !is_rev) ? G_FROW : G_SROW;
			end

			//----------------------------------------------------------
			// segmented operations: PIXBLT right-to-left, PIXBLT B, FILL
			//----------------------------------------------------------
			G_SROW: begin
				if (yi == dy[15:0])
					g_state <= G_FINISH;
				else if (is_rev || (yi == 16'd0)) begin : geom
					// Partial-word geometry. PIXBLT R works it out per row; PIXBLT B
					// and FILL use the first row's figures for every row, as MAME does.
					// The cost is charged in G_SROWC from the registered figures.
					reg signed [31:0] lp, rp, fw;
					reg [31:0] ppw32;
					ppw32 = {27'd0, ppw};
					if (is_rev) begin
						lp = (ppw32 - (((r_daddr - (dx << lg)) & 32'd15) >> lg)) & (ppw32 - 32'd1);
						rp = {28'd0, r_daddr[3:0]} >> lg;
					end
					else begin
						lp = (ppw32 - ({28'd0, r_daddr[3:0]} >> lg)) & (ppw32 - 32'd1);
						rp = ((r_daddr + (dx << lg)) & 32'd15) >> lg;
					end
					fw = dx - lp - rp;
					if (fw < 0) begin
						if (is_rev) begin rp = dx; lp = 32'sd0; end
						else        begin lp = dx; rp = 32'sd0; end
						fw = 32'sd0;
					end
					else
						fw = fw >>> (3'd4 - lg);      // full words: divide by pixels per word
					left_p  <= lp[15:0];
					right_p <= rp[15:0];
					full_w  <= fw[15:0];
					g_state <= G_SROWC;
				end
				else begin
					if (is_fill)
						gcyc <= gcyc + seg_words * {28'd0, timing};
					srow_start;
				end
			end

			G_SROWC: begin
				// cost of one row from the geometry just registered
				if (is_rev)
					row_cost <= seg_words * ({28'd0, timing} + 32'd2) + 32'd2;
				else if (is_fill)
					row_cost <= seg_words * {28'd0, timing};
				else
					row_cost <= seg_words * {28'd0, timing} + (((seg_words << lg) >> 4) << 1);
				g_state <= G_SROWD;
			end

			G_SROWD: begin
				// PIXBLT B charges every row up front
				if (is_rev || is_fill)
					gcyc <= gcyc + row_cost;
				else
					gcyc <= gcyc + row_cost * dy + 32'd2;
				srow_start;
			end

			G_SROW1: begin
				sword[15:0] <= m_q;
				if (is_rev)
					smask <= pmask << ((r_saddr[3:0] - bpp[3:0]) & 4'hF);
				else
					smask <= 16'd1 << r_saddr[3:0];
				seg     <= 2'd0;
				seg_cnt <= full_w;
				g_state <= G_SSEG;
			end

			G_SSEG: begin
				// next segment: first partial word, the full words, last partial word.
				// Right to left goes right partial -> full -> left partial and pre-decrements.
				case (seg)
					2'd0: begin
						seg_pix <= is_rev ? right_p : left_p;
						if ((is_rev ? right_p : left_p) == 16'd0)
							seg <= 2'd1;
						else if (is_rev) begin
							dmask <= pmask << ((r_daddr[3:0] - bpp[3:0]) & 4'hF);
							dwa   <= dwa - 28'd1;
							mem_read(dwa - 28'd1, G_SSEG1);
						end
						else begin
							dmask <= pmask << r_daddr[3:0];
							mem_read(dwa, G_SSEG1);
						end
					end
					2'd1: begin
						seg_pix <= {11'd0, ppw};
						if (seg_cnt == 16'd0)
							seg <= 2'd2;
						else if (is_fill && !op_x && !trans) begin
							// plain FILL: every pixel of a full word takes COLOR1, so
							// the word is written straight away (cycles are charged
							// per row, the speed here only has to keep up)
							seg_cnt <= seg_cnt - 16'd1;
							dwa     <= dwa + 28'd1;
							mem_write(dwa, color1[15:0], G_SSEG);
						end
						else begin
							seg_cnt <= seg_cnt - 16'd1;
							dmask   <= is_rev ? (pmask << (5'd16 - bpp)) : pmask;
							if (is_rev) dwa <= dwa - 28'd1;
							if (op_x || trans)
								mem_read(is_rev ? (dwa - 28'd1) : dwa, G_SSEG1);
							else begin
								m_q     <= 16'd0;
								g_state <= G_SSEG1;
							end
						end
					end
					2'd2: begin
						seg_pix <= is_rev ? left_p : right_p;
						if ((is_rev ? left_p : right_p) == 16'd0)
							seg <= 2'd3;
						else begin
							dmask <= is_rev ? (pmask << (5'd16 - bpp)) : pmask;
							if (is_rev) begin
								dwa <= dwa - 28'd1;
								mem_read(dwa - 28'd1, G_SSEG1);
							end
							else
								mem_read(dwa, G_SSEG1);
						end
					end
					default: g_state <= G_NEXTROW;
				endcase
			end

			G_SSEG1: begin
				dword[15:0] <= m_q;
				xi          <= 16'd0;
				g_state     <= G_SPIX;
			end

			G_SPIX: begin
				if (xi == seg_pix)
					g_state <= G_SWR;
				else if (is_rev && (smask == 16'd0)) begin
					swa <= swa - 28'd1;
					mem_read(swa - 28'd1, G_SPIX1);
				end
				else begin
					sp_p    <= sp_src;
					g_state <= G_SPIX2;
				end
			end

			G_SPIX1: begin
				sword[15:0] <= m_q;
				smask       <= pmask << (5'd16 - bpp);
				g_state     <= G_SPIX;
			end

			G_SPIX2: begin : spix
				reg [15:0] p, dw;
				reg [31:0] r;
				dw = dword[15:0];
				p  = sp_p;
				r = op_x ? pixel_op(rop, {16'd0, dw}, {16'd0, dmask}, {16'd0, p}) : {16'd0, p};
				p = r[15:0];
				if (!trans || (p != 16'd0))
					dw = (dw & ~dmask) | p;
				dword[15:0] <= dw;
				xi <= xi + 16'd1;
				if (is_rev) begin
					smask   <= (lg == 3'd4) ? 16'd0 : (smask >> bpp);
					dmask   <= (lg == 3'd4) ? 16'd0 : (dmask >> bpp);
					g_state <= G_SPIX;
				end
				else begin
					dmask <= dmask << bpp;
					if (is_b && smask[15]) begin
						// the source bit mask ran off the word: fetch the next one now
						smask <= 16'd1;
						swa   <= swa + 28'd1;
						mem_read(swa, G_BSRC);
					end
					else begin
						if (is_b) smask <= smask << 1;
						g_state <= G_SPIX;
					end
				end
			end

			G_BSRC: begin
				sword[15:0] <= m_q;
				g_state     <= G_SPIX;
			end

			G_SWR: begin
				// write the segment's destination word back
				if (!is_rev) dwa <= dwa + 28'd1;
				mem_write(dwa, dword[15:0], G_SWR1);
			end

			G_SWR1: begin
				if (seg == 2'd0)      seg <= 2'd1;
				else if (seg == 2'd2) seg <= 2'd3;
				g_state <= G_SSEG;
			end

			//----------------------------------------------------------
			// completion: P clears and the address registers advance
			//----------------------------------------------------------
			G_FINISH: begin
				prod_s  <= dydx_y * $signed(sptch);
				prod_d  <= dydx_y * $signed(dptch);
				g_state <= G_FIN1;
			end

			G_FIN1: begin
				if (!is_fill) begin
					wr_saddr  <= 1'b1;
					new_saddr <= src_lin ? (saddr + prod_s) : {saddr[31:16] + dydx[31:16], saddr[15:0]};
				end
				wr_daddr  <= 1'b1;
				new_daddr <= dst_lin ? (daddr + prod_d) : {daddr[31:16] + dydx[31:16], daddr[15:0]};
				cycles    <= gcyc;
				last_cyc  <= gcyc;
				clr_p     <= 1'b1;
				busy      <= 1'b0;
				done      <= 1'b1;
				g_state   <= G_IDLE;
			end

			default: g_state <= G_IDLE;
		endcase
	end
end

endmodule
