//============================================================================
//  HC-55516 CVSD decoder
//
//  Digital model of the Harris HC-55516 as written for MAME by Jonathan Gevaryahu
//  (syllabic and integrator filters on the chip's own bit widths). The sound
//  CPU clocks the chip in software: one write clears the clock and presents a
//  data bit, another sets the clock. The rising edge shifts the bit in and
//  updates the syllabic filter; both edges move the integrator.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module hc55516
(
	input                    clk,
	input                    reset,

	input                    clock_w,     // pulse: set the CVSD clock to clock_val
	input                    clock_val,
	input                    digit_w,     // pulse: latch the next data bit
	input                    digit_val,

	output reg signed [15:0] sample
);

localparam [11:0] SYLMASK  = 12'hFC0;
localparam        SYLSHIFT = 6;
localparam [11:0] SYLADD   = 12'hFC1;
localparam        INTSHIFT = 4;

reg         last_clock;
reg         buffered_bit;
reg   [2:0] shiftreg;
reg  [11:0] sylfilter;
reg  signed [9:0] intfilter;

// sign-extend from 10 bits, as MAME's util::sext(x, 10)
/* verilator lint_off UNUSEDSIGNAL */
function automatic signed [9:0] sext10(input [31:0] v);
	sext10 = v[9:0];
endfunction
/* verilator lint_on UNUSEDSIGNAL */

always @(posedge clk) begin
	if (reset) begin
		last_clock   <= 1'b0;
		buffered_bit <= 1'b0;
		shiftreg     <= 3'd0;
		sylfilter    <= 12'h03F;
		intfilter    <= 10'sd0;
		sample       <= 16'sd0;
	end
	else begin
		if (digit_w)
			buffered_bit <= digit_val;

		if (clock_w) begin
			last_clock <= clock_val;
			if (clock_val != last_clock) begin : process_bit
				reg        frozen;
				reg  [2:0] sr;
				reg [11:0] syl;
				reg [31:0] sum;
				reg [11:0] s6;
				reg signed [9:0] inew;

				frozen = ((intfilter >= 10'sd384) && !buffered_bit) ||
				         ((intfilter <= -10'sd384) && buffered_bit);
				sr  = shiftreg;
				syl = sylfilter;

				if (clock_val) begin
					// active (rising) edge: shift in the bit, update the syllabic filter
					sr = {shiftreg[1:0], buffered_bit};
					if (!frozen) begin
						if (sr == 3'b000 || sr == 3'b111)
							syl = syl + (((~syl) & SYLMASK) >> SYLSHIFT);
						else
							syl = syl + (((~syl) & SYLMASK) >> SYLSHIFT) + SYLADD;
					end
					// MAME: sext(((~intfilter) >> intshift) + 1, 10)
					sum = 32'(($signed(~{{22{intfilter[9]}}, intfilter}) >>> INTSHIFT) + 1);
				end
				else begin
					// inactive edge: step the integrator by the syllabic level
					s6 = ((syl >> 6) < 12'd2) ? 12'd2 : (syl >> 6);
					if (shiftreg[0])
						sum = 32'((~{20'd0, s6}) + 32'd1);
					else
						sum = {20'd0, s6};
				end

				inew = intfilter;
				if (!frozen)
					inew = sext10(32'($signed({{22{intfilter[9]}}, intfilter}) + $signed(32'(sext10(sum)))));

				shiftreg  <= sr;
				sylfilter <= syl;
				intfilter <= inew;
				// scale -512..511 to 16 bits the way MAME does
				sample    <= {inew, ~inew[9], inew[8:4]};
			end
		end
	end
end

endmodule
