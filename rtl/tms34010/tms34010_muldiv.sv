//============================================================================
//  TMS34010 multiply / divide unit
//
//  Iterative shift-add multiplier and restoring divider shared by MPYS, MPYU,
//  DIVS, DIVU, MODS and MODU. Iterative rather than DSP-based because the
//  instructions are rare and slow on the real chip (20-40 machine cycles),
//  so a 64-clock worst case at clk_sys is far inside the time the cycle
//  budget allows, and it keeps the CPU free of long carry chains.
//
//  Results follow MAME's arithmetic (C truncating division, remainder takes
//  the sign of the dividend), which is what the games were verified against.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module tms34010_muldiv
(
	input             clk,
	input             ce,
	input             reset,

	input             start,       // pulse: begin operation
	input       [2:0] op,          // operation, see localparams below
	input      [31:0] a,           // multiplier / divisor (Rs)
	input      [31:0] b_hi,        // multiplicand (Rd) or dividend high word
	input      [31:0] b_lo,        // dividend low word (64-bit divides)

	output reg        busy,
	output reg        done,        // pulse: results valid
	output reg [31:0] res_hi,      // product high / quotient / remainder (MOD)
	output reg [31:0] res_lo,      // product low / remainder (64-bit divides)
	output reg        ovf,         // quotient does not fit (V flag)
	output reg        zero_div     // divisor was zero (V flag, no result)
);

localparam OP_MPYS   = 3'd0;
localparam OP_MPYU   = 3'd1;
localparam OP_DIVS64 = 3'd2;
localparam OP_DIVU64 = 3'd3;
localparam OP_DIVS32 = 3'd4;
localparam OP_DIVU32 = 3'd5;
localparam OP_MODS   = 3'd6;
localparam OP_MODU   = 3'd7;

reg  [2:0] cur_op;
reg  [6:0] cnt;
reg        neg_q;              // result (product or quotient) must be negated
reg        neg_r;              // remainder must be negated
reg [63:0] acc;                // product accumulator / dividend shift register
reg [31:0] mcand;              // multiplicand magnitude or divisor magnitude
reg [32:0] rem;                // partial remainder (one extra bit for the compare)

wire is_mul    = (cur_op == OP_MPYS) | (cur_op == OP_MPYU);
wire is_signed = (cur_op == OP_MPYS) | (cur_op == OP_DIVS64) | (cur_op == OP_DIVS32) | (cur_op == OP_MODS);

// One restoring-division step: shift in the next dividend bit and try to subtract.
wire [32:0] rem_sh  = {rem[31:0], acc[63]};
wire [32:0] rem_sub = rem_sh - {1'b0, mcand};
wire        q_bit   = ~rem_sub[32];

// Magnitudes for the signed operations, prepared at start.
wire        start_signed = (op == OP_MPYS) | (op == OP_DIVS64) | (op == OP_DIVS32) | (op == OP_MODS);
wire        start_div64  = (op == OP_DIVS64) | (op == OP_DIVU64);
wire [63:0] dividend_in  = start_div64 ? {b_hi, b_lo} :
                           (start_signed ? {{32{b_hi[31]}}, b_hi} : {32'd0, b_hi});
wire        dvd_neg      = start_signed & dividend_in[63];
wire [63:0] dvd_mag      = dvd_neg ? (~dividend_in + 64'd1) : dividend_in;
wire        dvs_neg      = start_signed & a[31];
wire [31:0] dvs_mag      = dvs_neg ? (~a + 32'd1) : a;
wire        mpl_neg      = start_signed & b_hi[31];
wire [31:0] mpl_mag      = mpl_neg ? (~b_hi + 32'd1) : b_hi;

// Final signed results (combinational from the finished accumulators).
wire [63:0] prod_s  = neg_q ? (~acc + 64'd1) : acc;
wire [63:0] quot_s  = neg_q ? (~acc + 64'd1) : acc;
wire [31:0] rem_s   = neg_r ? (~rem[31:0] + 32'd1) : rem[31:0];

always @(posedge clk) if (ce) begin
	done <= 1'b0;
	if (reset) begin
		busy <= 1'b0;
	end
	else if (start) begin
		cur_op   <= op;
		busy     <= 1'b1;
		ovf      <= 1'b0;
		zero_div <= 1'b0;
		rem      <= 33'd0;
		if ((op == OP_MPYS) | (op == OP_MPYU)) begin
			// multiply magnitudes, fix the sign at the end
			acc   <= {32'd0, dvs_mag};
			mcand <= mpl_mag;
			neg_q <= dvs_neg ^ mpl_neg;
			cnt   <= 7'd32;
		end
		else begin
			acc   <= dvd_mag;
			mcand <= dvs_mag;
			neg_q <= dvd_neg ^ dvs_neg;
			neg_r <= dvd_neg;
			cnt   <= 7'd64;
			if (a == 32'd0) begin
				zero_div <= 1'b1;
				cnt      <= 7'd0;
			end
		end
	end
	else if (busy) begin
		if (cnt != 7'd0) begin
			cnt <= cnt - 7'd1;
			if (is_mul) begin
				// shift-add: low half of acc holds the remaining multiplier bits
				if (acc[0])
					acc <= {({1'b0, acc[63:32]} + {1'b0, mcand}), acc[31:1]};
				else
					acc <= {1'b0, acc[63:1]};
			end
			else begin
				rem <= q_bit ? rem_sub : rem_sh;
				acc <= {acc[62:0], q_bit};
			end
		end
		else begin
			busy <= 1'b0;
			done <= 1'b1;
			case (cur_op)
				OP_MPYS, OP_MPYU: begin
					res_hi <= prod_s[63:32];
					res_lo <= prod_s[31:0];
				end
				OP_DIVS64: begin
					// quotient must fit a signed 32-bit result
					if (neg_q ? (acc > 64'h0000_0000_8000_0000) : (acc > 64'h0000_0000_7FFF_FFFF))
						ovf <= ~zero_div;
					res_hi <= quot_s[31:0];
					res_lo <= rem_s;
				end
				OP_DIVU64: begin
					if (acc[63:32] != 32'd0)
						ovf <= ~zero_div;
					res_hi <= acc[31:0];
					res_lo <= rem[31:0];
				end
				OP_DIVS32: begin
					res_hi <= quot_s[31:0];
					res_lo <= rem_s;
				end
				OP_DIVU32: begin
					res_hi <= acc[31:0];
					res_lo <= rem[31:0];
				end
				OP_MODS: res_hi <= rem_s;
				default: res_hi <= rem[31:0];   // OP_MODU
			endcase
		end
	end
end

endmodule
