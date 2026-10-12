//============================================================================
//  MC6821 Peripheral Interface Adapter
//
//  Register-level behaviour of MAME's pia6821_device, which the sound board
//  programs were tested against:
//    - port reads mix input pins and output latches by DDR
//    - reading a port clears both of its interrupt flags
//    - C1/C2 edge detection with selectable polarity, IRQ enables
//    - CA2/CB2 as outputs: set/reset mode or read/write strobe mode
//    - IRQ2 reads back only while C2 is an input
//
//  Accesses take one clk: rd/wr pulse once per CPU cycle with rs/din valid.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module pia6821
(
	input            clk,
	input            reset,

	// CPU side
	input            rd,            // read strobe (one clk per CPU cycle)
	input            wr,            // write strobe
	input      [1:0] rs,
	input      [7:0] din,
	output reg [7:0] dout,          // valid while rs is stable (combinational)

	// port A
	input      [7:0] pa_in,
	output     [7:0] pa_out,        // output latch merged with inputs by DDR
	input            ca1,
	input            ca2_in,
	output reg       ca2_out,

	// port B
	input      [7:0] pb_in,
	output     [7:0] pb_out,
	input            cb1,
	input            cb2_in,
	output reg       cb2_out,

	output           irqa,
	output           irqb
);

reg  [7:0] ora, orb, ddra, ddrb;
reg  [5:0] cra, crb;
reg        irqa1, irqa2, irqb1, irqb2;
reg        ca1_d, ca2_d, cb1_d, cb2_d;

wire [7:0] pa_val = (pa_in & ~ddra) | (ora & ddra);
wire [7:0] pb_val = (ddrb == 8'hFF) ? orb : ((orb & ddrb) | (pb_in & ~ddrb));

assign pa_out = (ddra == 8'hFF) ? ora : ((ora & ddra) | (pa_in & ~ddra));
assign pb_out = orb & ddrb;

assign irqa = (irqa1 & cra[0]) | (irqa2 & cra[3]);
assign irqb = (irqb1 & crb[0]) | (irqb2 & crb[3]);

always @(*) begin
	case (rs)
		2'd0:    dout = cra[2] ? pa_val : ddra;
		2'd1:    dout = {irqa1, irqa2 & ~cra[5], cra};
		2'd2:    dout = crb[2] ? pb_val : ddrb;
		default: dout = {irqb1, irqb2 & ~crb[5], crb};
	endcase
end

// active edge of a control input: bit 1 (C1) / bit 4 (C2) selects low-to-high
function automatic c_edge(input prev, input cur, input rising);
	c_edge = (prev != cur) && (cur == rising);
endfunction

always @(posedge clk) begin
	if (reset) begin
		ora     <= 8'h00;  orb  <= 8'h00;
		ddra    <= 8'h00;  ddrb <= 8'h00;
		cra     <= 6'h00;  crb  <= 6'h00;
		irqa1   <= 1'b0;   irqa2 <= 1'b0;
		irqb1   <= 1'b0;   irqb2 <= 1'b0;
		ca2_out <= 1'b1;   // pulled up
		cb2_out <= 1'b0;
		ca1_d   <= ca1;    ca2_d <= ca2_in;
		cb1_d   <= cb1;    cb2_d <= cb2_in;
	end
	else begin
		// ---- control line inputs ----
		ca1_d <= ca1;
		ca2_d <= ca2_in;
		cb1_d <= cb1;
		cb2_d <= cb2_in;

		if (c_edge(ca1_d, ca1, cra[1])) begin
			irqa1 <= 1'b1;
			// read strobe with C1 restore
			if (cra[5] && !cra[4] && !cra[3]) ca2_out <= 1'b1;
		end
		if (!cra[5] && c_edge(ca2_d, ca2_in, cra[4]))
			irqa2 <= 1'b1;
		if (c_edge(cb1_d, cb1, crb[1]))
			irqb1 <= 1'b1;
		if (!crb[5] && c_edge(cb2_d, cb2_in, crb[4]))
			irqb2 <= 1'b1;

		// ---- CPU reads (side effects) ----
		if (rd) begin
			if (rs == 2'd0 && cra[2]) begin
				irqa1 <= 1'b0;
				irqa2 <= 1'b0;
				// CA2 read strobe: low, or a one-cycle pulse when bit 3 is set
				if (cra[5] && !cra[4]) ca2_out <= cra[3];
			end
			if (rs == 2'd2 && crb[2]) begin
				if (irqb1 && !crb[4] && !crb[3]) cb2_out <= 1'b1;
				irqb1 <= 1'b0;
				irqb2 <= 1'b0;
			end
		end

		// ---- CPU writes ----
		if (wr) begin
			case (rs)
				2'd0: if (cra[2]) ora <= din; else ddra <= din;
				2'd1: begin
					cra <= din[5:0];
					if (din[5]) ca2_out <= din[4] ? din[3] : 1'b1;
					else        ca2_out <= 1'b1;   // input again: pulled up
				end
				2'd2: begin
					if (crb[2]) begin
						orb <= din;
						// CB2 write strobe
						if (!crb[4]) cb2_out <= crb[3];
					end
					else
						ddrb <= din;
				end
				default: begin
					crb     <= din[5:0];
					cb2_out <= din[4] ? din[3] : 1'b1;
				end
			endcase
		end
	end
end

endmodule
