//============================================================================
//  Yawdim bootleg sound board (Mortal Kombat bootlegs mkyawdim 1-4)
//
//  A Z80 at 4 MHz (8 MHz / 2), an OKI M6295 at 1 MHz (8 MHz / 8, pin 7 high)
//  and a command latch; no YM2151, no DAC. MAME (midyunit.cpp,
//  yawdim_sound_map / yawdim2_sound_map):
//
//    0000-7FFF  ROM (32 KB)
//    8000-87FF  RAM (2 KB)
//    9000-97FF  W: OKI bank
//    9800-9FFF  OKI M6295
//    A000-A7FF  R: command latch
//
//  Main board: a 16-bit write to 0x01E00000 (words 0x1E0000) puts the low byte
//  in the latch and interrupts the Z80.
//    sets 1, 3, 4 (set2 = 0): every write pulses NMI. OKI bank (2 bits): the
//                 write sets it when D2 is high.
//    set 2 (set2 = 1):        NMI is asserted while the latch holds a command
//                 that has not been read (the read releases it). OKI bank
//                 (3 bits): D3, D1, D0, always set by the write; D2 low also
//                 resets the OKI.
//  The OKI sees the sample ROM in banks of 256 KB (bank * 0x40000 + address).
//
//  The Z80 program is kept in a block RAM that the ROM transfer fills (the
//  top level hands over the words it writes to 0x900000-0x907FFF); the OKI
//  samples come from the SDRAM (0xA00000, up to 2 MB).
//
//  Timing: the Z80 (rtl/tv80, with a clock enable) gets one clock enable
//  every 24 clk. Its address and control outputs are looked at 8 clk after
//  the enable, the read data is held from 4 clk after it (the SDC treats
//  these as multicycle paths).
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yawdim_sound
(
	input             clk,             // 96 MHz
	input             reset,
	input             pause,

	input             set2,            // 1: set 2 (latch drives NMI, 3-bit OKI bank)

	// command from the main board
	input             cmd_wr,
	input      [15:0] cmd_data,

	// Z80 program words from the ROM transfer
	input             zrom_we,
	input      [13:0] zrom_wa,         // word number (byte address / 2)
	input      [15:0] zrom_wd,

	// SDRAM: OKI samples
	output reg [24:3] oki_addr,
	output reg        oki_req,
	input             oki_ack,
	input      [63:0] oki_data,

	output reg signed [15:0] audio
);

localparam [24:0] OKI_BASE = 25'h0A0_0000;

//----------------------------------------------------------------------------
// Clock enables: Z80 (4 MHz), OKI (1 MHz)
//----------------------------------------------------------------------------

reg   [4:0] cc;              // clk since the last Z80 clock enable edge
reg         cen;
always @(posedge clk) begin
	cen <= 1'b0;
	if (reset)
		cc <= 5'd0;
	else begin
		cc <= (cc == 5'd23) ? 5'd0 : cc + 5'd1;
		if (cc == 5'd22 && !pause)
			cen <= 1'b1;
	end
end

reg   [6:0] oki_div;
reg         oki_cen;
always @(posedge clk) begin
	oki_cen <= 1'b0;
	if (reset)
		oki_div <= 7'd0;
	else if (oki_div == 7'd95) begin
		oki_div <= 7'd0;
		oki_cen <= ~pause;
	end
	else
		oki_div <= oki_div + 7'd1;
end

//----------------------------------------------------------------------------
// Z80
//----------------------------------------------------------------------------

wire        z_mreq_n, z_rd_n, z_wr_n, z_iorq_n;
wire [15:0] za;
wire  [7:0] zdo;
reg   [7:0] din_r;           // read data, registered every clk
reg         nmi_n;

tv80cen z80
(
	.reset_n (~reset),
	.clk     (clk),
	.cen     (cen),
	.wait_n  (1'b1),
	.int_n   (1'b1),
	.nmi_n   (nmi_n),
	.busrq_n (1'b1),
	.m1_n    (),
	.mreq_n  (z_mreq_n),
	.iorq_n  (z_iorq_n),
	.rd_n    (z_rd_n),
	.wr_n    (z_wr_n),
	.rfsh_n  (),
	.halt_n  (),
	.busak_n (),
	.A       (za),
	.di      (din_r),
	.dout    (zdo)
);

// address map
wire a_rom  = !za[15];                       // 0000-7FFF
wire a_ram  = (za[15:11] == 5'b10000);       // 8000-87FF
wire a_bank = (za[15:11] == 5'b10010);       // 9000-97FF
wire a_oki  = (za[15:11] == 5'b10011);       // 9800-9FFF
wire a_lat  = (za[15:11] == 5'b10100);       // A000-A7FF

// bus cycles are taken 8 clk after the Z80's clock enable, once per cycle
reg         wr_s, rd_s;
wire        z_wr = !z_mreq_n && !z_wr_n;
wire        z_rd = !z_mreq_n && !z_rd_n;
wire        ev_wr = (cc == 5'd8) && z_wr && !wr_s;
wire        ev_rd = (cc == 5'd8) && z_rd && !rd_s;
always @(posedge clk) begin
	if (reset) begin
		wr_s <= 1'b0;
		rd_s <= 1'b0;
	end
	else if (cc == 5'd8) begin
		wr_s <= z_wr;
		rd_s <= z_rd;
	end
end

//----------------------------------------------------------------------------
// Memory
//----------------------------------------------------------------------------

reg  [15:0] rom [0:16383];
reg  [15:0] rom_q;
always @(posedge clk) begin
	if (zrom_we)
		rom[zrom_wa] <= zrom_wd;
	rom_q <= rom[za[14:1]];
end

reg   [7:0] ram [0:2047];
reg   [7:0] ram_q;
always @(posedge clk) begin
	if (ev_wr && a_ram)
		ram[za[10:0]] <= zdo;
	ram_q <= ram[za[10:0]];
end

// command latch
reg   [7:0] latch;
reg         pending;
reg         nmi_pulse;           // sets 1, 3, 4: one NMI per write, still to send
always @(posedge clk) begin
	if (reset) begin
		latch     <= 8'h00;
		pending   <= 1'b0;
		nmi_pulse <= 1'b0;
	end
	else begin
		if (cmd_wr) begin
			latch     <= cmd_data[7:0];
			pending   <= 1'b1;
			nmi_pulse <= 1'b1;
		end
		else begin
			if (ev_rd && a_lat)
				pending <= 1'b0;
			if (cen && nmi_pulse && nmi_n)
				nmi_pulse <= 1'b0;
		end
	end
end

// NMI line (active low). Sets 1, 3, 4: low for one Z80 clock per write, with
// a high clock between pulses. Set 2: low while a command is pending.
always @(posedge clk) begin
	if (reset)
		nmi_n <= 1'b1;
	else if (set2)
		nmi_n <= ~pending;
	else if (cen) begin
		if (!nmi_n)
			nmi_n <= 1'b1;
		else if (nmi_pulse)
			nmi_n <= 1'b0;
	end
end

//----------------------------------------------------------------------------
// OKI M6295
//----------------------------------------------------------------------------

reg   [2:0] oki_bank;
reg         oki_wr;
reg         oki_rst;
reg   [3:0] oki_rst_cnt;
always @(posedge clk) begin
	oki_wr <= 1'b0;
	if (reset) begin
		oki_bank    <= 3'd0;
		oki_rst_cnt <= 4'd0;
	end
	else begin
		if (ev_wr && a_oki)
			oki_wr <= 1'b1;
		if (ev_wr && a_bank) begin
			if (set2) begin
				oki_bank <= {zdo[3], zdo[1:0]};
				if (!zdo[2])
					oki_rst_cnt <= 4'd8;
			end
			else if (zdo[2])
				oki_bank <= {1'b0, zdo[1:0]};
		end
		if (oki_rst_cnt != 4'd0)
			oki_rst_cnt <= oki_rst_cnt - 4'd1;
	end
	oki_rst <= (oki_rst_cnt != 4'd0);
end

wire  [7:0] oki_dout;
wire [17:0] oki_rom_a;
reg   [7:0] oki_rom_d;
reg         oki_rom_ok;
wire signed [13:0] oki_snd;

jt6295 #(.INTERPOL(0), .IGNORE_BUSY(1)) oki
(
	.rst      (reset | oki_rst),
	.clk      (clk),
	.cen      (oki_cen),
	.ss       (1'b1),
	.wrn      (~oki_wr),
	.din      (zdo),
	.dout     (oki_dout),
	.rom_addr (oki_rom_a),
	.rom_data (oki_rom_d),
	.rom_ok   (oki_rom_ok),
	.sound    (oki_snd),
	.sample   ()
);

// sample ROM: 64-bit lines from the SDRAM, one line kept
wire [20:0] oki_off = {oki_bank, oki_rom_a};
reg  [17:0] oki_tag;
reg         oki_tag_ok;
reg  [63:0] oki_line;
reg         oki_busy;

always @(posedge clk) begin
	if (reset) begin
		oki_tag_ok <= 1'b0;
		oki_busy   <= 1'b0;
		oki_req    <= oki_ack;
	end
	else begin
		if (oki_busy) begin
			if (oki_req == oki_ack) begin
				oki_busy   <= 1'b0;
				oki_line   <= oki_data;
				oki_tag_ok <= 1'b1;
			end
		end
		else if (!(oki_tag_ok && oki_tag == oki_off[20:3])) begin
			oki_tag    <= oki_off[20:3];
			oki_tag_ok <= 1'b0;
			oki_addr   <= OKI_BASE[24:3] + {4'd0, oki_off[20:3]};
			oki_req    <= ~oki_req;
			oki_busy   <= 1'b1;
		end
	end
	oki_rom_d  <= oki_line[{oki_off[2:0], 3'b000} +: 8];
	oki_rom_ok <= oki_tag_ok && (oki_tag == oki_off[20:3]) && !oki_busy;
end

//----------------------------------------------------------------------------
// Z80 read data, and the output
//----------------------------------------------------------------------------

reg         za0_r;
always @(posedge clk) begin
	za0_r <= za[0];
	if (a_rom)
		din_r <= za0_r ? rom_q[15:8] : rom_q[7:0];
	else if (a_ram)
		din_r <= ram_q;
	else if (a_oki)
		din_r <= oki_dout;
	else if (a_lat)
		din_r <= latch;
	else
		din_r <= 8'h00;
end

// MAME routes the OKI to the speaker at 1.0; one voice at full volume is
// full scale (jt6295's 14-bit sum, four bits up), the sum clips like MAME's
wire signed [17:0] oki_s = {oki_snd, 4'b0000};
always @(posedge clk) begin
	if (oki_s > 18'sd32767)
		audio <= 16'sd32767;
	else if (oki_s < -18'sd32768)
		audio <= 16'sh8000;
	else
		audio <= oki_s[15:0];
end

endmodule
