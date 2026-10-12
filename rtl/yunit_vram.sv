//============================================================================
//  Y Unit video RAM controller (DDR3)
//
//  The Y Unit frame store is 512 x 512 entries of 16 bits: the low byte is the
//  pixel the blitter or CPU wrote, the high byte the palette page it carried.
//  That is 512 KB, too big for block RAM next to everything else, so it lives
//  in DDR3 behind the MiSTer DDRAM port (64-bit Avalon, 4 entries per beat,
//  one row = 128 beats).
//
//  Clients, in priority order (a burst in progress is never interrupted):
//    1. display  - read one row into the scanline buffer at each line start
//    2. erase    - autoerase: copy row 510/511 over a row that was just shown
//    3. srt      - VRAM shift-register load/store for the CPU (two rows)
//    4. blitter  - write back one finished blitter row as a single burst
//    5. cpu      - 32-bit read or byte-masked write (two entries)
//
//  Write bursts take their data straight from the output register of the
//  source block RAM. Its address runs one beat ahead whenever the bridge
//  accepts a beat, so the next beat's data is on DDRAM_DIN the following cycle
//  and a burst streams at one beat per cycle.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_vram
(
	input             clk,
	input             reset,

	// DDR3 (MiSTer DDRAM port)
	input             ddr_busy,
	output reg  [7:0] ddr_burstcnt,
	output reg [28:0] ddr_addr,
	input      [63:0] ddr_dout,
	input             ddr_dout_ready,
	output reg        ddr_rd,
	output     [63:0] ddr_din,
	output      [7:0] ddr_be,
	output reg        ddr_we,

	// display: fetch one row into the scanline buffer
	input             disp_req,      // toggle
	output reg        disp_ack,
	input       [8:0] disp_row,
	output reg        lb_we,
	output reg  [6:0] lb_addr,
	output reg [63:0] lb_data,

	// autoerase: copy src row over dst row
	input             erase_req,     // toggle
	output reg        erase_ack,
	input       [8:0] erase_dst,
	input       [8:0] erase_src,

	// shift-register transfer (1024 entries starting at an entry index)
	input             srt_req,       // toggle
	output reg        srt_ack,
	input             srt_wr,        // 0: VRAM -> shift register, 1: shift register -> VRAM
	input      [17:0] srt_entry,
	output     [15:0] srt_first,     // shift register entry 0 (value a load returns)

	// blitter row write-back: qwords lo..hi of one row from the blitter's buffer
	input             blt_req,       // toggle
	output reg        blt_ack,
	input       [8:0] blt_row,
	input       [6:0] blt_lo,
	input       [6:0] blt_hi,
	output      [6:0] blt_raddr,     // read address into the blitter's row buffer
	input      [63:0] blt_q,         // its data, one cycle later
	input       [7:0] blt_be,

	// CPU: one 32-bit half of a beat
	input             cpu_req,       // toggle
	output reg        cpu_ack,
	input             cpu_wr,
	input      [15:0] cpu_qaddr,     // beat (qword) address
	input             cpu_half,      // 0: entries 0-1, 1: entries 2-3
	input       [3:0] cpu_be,
	input      [31:0] cpu_wdata,
	output reg [31:0] cpu_rdata
);

// VRAM sits at 0x30000000 in the HPS address space (DDRAM_ADDR counts beats)
localparam [28:0] BASE = 29'h0600_0000;

//----------------------------------------------------------------------------
// Local buffers
//----------------------------------------------------------------------------

// autoerase row (128 beats)
reg  [63:0] erase_buf [0:127];
reg   [6:0] eb_waddr;
reg  [63:0] eb_wdata;
reg         eb_we;
reg   [6:0] eb_raddr;
reg  [63:0] eb_q;
always @(posedge clk) begin
	if (eb_we) erase_buf[eb_waddr] <= eb_wdata;
	eb_q <= erase_buf[eb_raddr];
end

// shift register (1024 entries = 256 beats)
reg  [63:0] srt_buf [0:255];
reg   [7:0] sb_waddr;
reg  [63:0] sb_wdata;
reg         sb_we;
reg   [7:0] sb_raddr;
reg  [63:0] sb_q;
reg  [15:0] sr0;                 // copy of entry 0 for the CPU
always @(posedge clk) begin
	if (sb_we) srt_buf[sb_waddr] <= sb_wdata;
	sb_q <= srt_buf[sb_raddr];
end
assign srt_first = sr0;

//----------------------------------------------------------------------------
// Sequencer
//----------------------------------------------------------------------------

localparam V_IDLE   = 4'd0;
localparam V_RD     = 4'd1;      // read burst command
localparam V_RDDATA = 4'd2;      // receiving read beats
localparam V_WRPRE  = 4'd3;      // prime the source RAM for a write burst
localparam V_WR     = 4'd4;      // write beats
localparam V_DONE   = 4'd5;

localparam D_LINE  = 3'd0;       // destinations / sources
localparam D_ERASE = 3'd1;
localparam D_SRT   = 3'd2;
localparam D_BLT   = 3'd3;
localparam D_CPU   = 3'd4;

reg   [3:0] vstate;
reg   [2:0] dst;                 // where read data goes / write data comes from
reg   [2:0] op;                  // which client is being served
reg   [7:0] beats;               // beats in this burst
reg   [7:0] bi;                  // beat counter
reg   [7:0] src_idx;             // source RAM beat index for writes
reg         second;              // second half of a two-burst operation
reg  [28:0] next_addr;
reg   [6:0] blt_rd;

assign blt_raddr = blt_rd;

wire        wr_accept = ddr_we & ~ddr_busy;

// source RAM address runs one beat ahead when a beat is accepted
always @(*) begin
	eb_raddr = src_idx[6:0] + (wr_accept ? 7'd1 : 7'd0);
	sb_raddr = src_idx + (wr_accept ? 8'd1 : 8'd0);
	blt_rd   = blt_lo + src_idx[6:0] + (wr_accept ? 7'd1 : 7'd0);
end

wire [63:0] src_q  = (dst == D_ERASE) ? eb_q : (dst == D_SRT) ? sb_q : blt_q;
wire  [7:0] src_be = (dst == D_BLT) ? blt_be : 8'hFF;

reg  [63:0] cpu_din;
reg   [7:0] cpu_bemask;
assign ddr_din = (op == D_CPU) ? cpu_din    : src_q;
assign ddr_be  = (op == D_CPU) ? cpu_bemask : src_be;

always @(posedge clk) begin
	lb_we <= 1'b0;
	eb_we <= 1'b0;
	sb_we <= 1'b0;

	if (reset) begin
		vstate    <= V_IDLE;
		ddr_rd    <= 1'b0;
		ddr_we    <= 1'b0;
		disp_ack  <= disp_req;
		erase_ack <= erase_req;
		srt_ack   <= srt_req;
		blt_ack   <= blt_req;
		cpu_ack   <= cpu_req;
	end
	else begin
		case (vstate)
			V_IDLE: begin
				second  <= 1'b0;
				src_idx <= 8'd0;
				bi      <= 8'd0;
				if (disp_req != disp_ack) begin
					op           <= D_LINE;
					dst          <= D_LINE;
					ddr_addr     <= BASE | {13'd0, disp_row, 7'd0};
					ddr_burstcnt <= 8'd128;
					beats        <= 8'd128;
					vstate       <= V_RD;
				end
				else if (erase_req != erase_ack) begin
					// read the erase row first, then write it out
					op           <= D_ERASE;
					dst          <= D_ERASE;
					ddr_addr     <= BASE | {13'd0, erase_src, 7'd0};
					next_addr    <= BASE | {13'd0, erase_dst, 7'd0};
					ddr_burstcnt <= 8'd128;
					beats        <= 8'd128;
					vstate       <= V_RD;
				end
				else if (srt_req != srt_ack) begin
					op           <= D_SRT;
					dst          <= D_SRT;
					ddr_addr     <= BASE | {13'd0, srt_entry[17:2]};
					next_addr    <= BASE | {13'd0, srt_entry[17:2] + 16'd128};
					ddr_burstcnt <= 8'd128;
					beats        <= 8'd128;
					vstate       <= srt_wr ? V_WRPRE : V_RD;
				end
				else if (blt_req != blt_ack) begin
					op           <= D_BLT;
					dst          <= D_BLT;
					ddr_addr     <= BASE | {13'd0, blt_row, blt_lo};
					ddr_burstcnt <= {1'b0, blt_hi - blt_lo} + 8'd1;
					beats        <= {1'b0, blt_hi - blt_lo} + 8'd1;
					vstate       <= V_WRPRE;
				end
				else if (cpu_req != cpu_ack) begin
					op           <= D_CPU;
					dst          <= D_CPU;
					ddr_addr     <= BASE | {13'd0, cpu_qaddr};
					ddr_burstcnt <= 8'd1;
					beats        <= 8'd1;
					if (cpu_wr) begin
						ddr_we     <= 1'b1;
						cpu_din    <= {cpu_wdata, cpu_wdata};
						cpu_bemask <= cpu_half ? {cpu_be, 4'b0000} : {4'b0000, cpu_be};
						vstate     <= V_WR;
					end
					else
						vstate <= V_RD;
				end
			end

			V_RD: begin
				ddr_rd <= 1'b1;
				if (ddr_rd & ~ddr_busy) begin
					ddr_rd <= 1'b0;
					vstate <= V_RDDATA;
				end
			end

			V_RDDATA: if (ddr_dout_ready) begin
				case (dst)
					D_LINE: begin
						lb_we   <= 1'b1;
						lb_addr <= bi[6:0];
						lb_data <= ddr_dout;
					end
					D_ERASE: begin
						eb_we    <= 1'b1;
						eb_waddr <= bi[6:0];
						eb_wdata <= ddr_dout;
					end
					D_SRT: begin
						sb_we    <= 1'b1;
						sb_waddr <= {second, bi[6:0]};
						sb_wdata <= ddr_dout;
						if (!second && bi == 8'd0) sr0 <= ddr_dout[15:0];
					end
					default: cpu_rdata <= cpu_half ? ddr_dout[63:32] : ddr_dout[31:0];
				endcase
				bi <= bi + 8'd1;
				if (bi + 8'd1 == beats) begin
					bi <= 8'd0;
					if (dst == D_ERASE) begin
						// now write the copied row to its destination
						ddr_addr <= next_addr;
						src_idx  <= 8'd0;
						vstate   <= V_WRPRE;
					end
					else if (dst == D_SRT && !second) begin
						second   <= 1'b1;
						ddr_addr <= next_addr;
						vstate   <= V_RD;
					end
					else
						vstate <= V_DONE;
				end
			end

			V_WRPRE: begin
				// the source RAM sees src_idx this cycle; its data is on DIN next cycle
				ddr_we <= 1'b1;
				vstate <= V_WR;
			end

			V_WR: begin
				if (wr_accept) begin
					if (bi + 8'd1 == beats) begin
						ddr_we <= 1'b0;
						bi     <= 8'd0;
						if (op == D_SRT && !second) begin
							second   <= 1'b1;
							ddr_addr <= next_addr;
							src_idx  <= 8'd128;
							vstate   <= V_WRPRE;
						end
						else
							vstate <= V_DONE;
					end
					else begin
						bi      <= bi + 8'd1;
						src_idx <= src_idx + 8'd1;
					end
				end
			end

			V_DONE: begin
				case (op)
					D_LINE:  disp_ack  <= disp_req;
					D_ERASE: erase_ack <= erase_req;
					D_SRT:   srt_ack   <= srt_req;
					D_BLT:   blt_ack   <= blt_req;
					default: cpu_ack   <= cpu_req;
				endcase
				vstate <= V_IDLE;
			end

			default: vstate <= V_IDLE;
		endcase
	end
end

endmodule
