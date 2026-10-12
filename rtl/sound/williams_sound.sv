//============================================================================
//  Williams CVSD / ADPCM sound boards (Y Unit)
//
//  Both boards are a 6809E at 2 MHz with a YM2151 and an 8-bit DAC. The CVSD
//  board adds an HC-55516 speech decoder and talks to the main board through
//  a 6821 PIA; the ADPCM board adds an OKI M6295 and a plain command latch.
//  One instance serves either board: `adpcm` selects the memory map.
//
//  CVSD board (MAME williams_cvsd_sound_device)
//    0000-1FFF  RAM, 2 KB mirrored
//    2000-3FFF  YM2151
//    4000-5FFF  PIA (PA: DAC, PB: command in, CA1: YM IRQ, CA2: YM reset,
//               CB1: command strobe, IRQA: FIRQ, IRQB: NMI)
//    6000-67FF  W: CVSD clock low + data bit
//    6800-6FFF  W: CVSD clock high
//    7800-7FFF  W: ROM bank (D0-1: chip, D2-3: A15-A16)
//    8000-FFFF  banked ROM
//
//  ADPCM board (MAME williams_adpcm_sound_device)
//    0000-1FFF  RAM, 8 KB
//    2000-23FF  W: ROM bank (0-7)
//    2400-27FF  YM2151 (IRQ: FIRQ)
//    2800-2BFF  W: DAC
//    2C00-2FFF  OKI M6295
//    3000-33FF  R: command (clears IRQ)
//    3400-37FF  W: OKI bank
//    3C00-3FFF  W: talkback
//    4000-BFFF  banked ROM, C000-FFFF fixed ROM
//
//  ROM comes from SDRAM; the region starts at what MAME calls offset 0x10000
//  of the sound CPU region. Games protect their sound program with a small
//  window that is RAM (hidden RAM) or that writes into the ROM image of bank 0
//  (smaller CVSD games); both are an overlay RAM here.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module williams_sound
(
	input             clk,             // 96 MHz
	input             reset,
	input             pause,

	input             adpcm,           // 1: ADPCM board, 0: CVSD board
	input       [1:0] prot_mode,       // 0: none, 1: writes into bank 0 ROM, 2: hidden RAM
	input      [15:0] prot_start,
	input      [15:0] prot_end,

	// command from the main board
	input             cmd_wr,
	input      [15:0] cmd_data,
	output            irq_state,       // ADPCM: command pending (read by the main CPU)

	// SDRAM: sound CPU ROM and OKI samples
	output reg [24:3] rom_addr,
	output reg        rom_req,
	input             rom_ack,
	input      [63:0] rom_data,

	output reg [24:3] oki_addr,
	output reg        oki_req,
	input             oki_ack,
	input      [63:0] oki_data,

	output reg signed [15:0] audio
);

localparam [24:0] SND_BASE = 25'h090_0000;
localparam [24:0] OKI_BASE = 25'h0A0_0000;

//----------------------------------------------------------------------------
// Clock enables: E/Q for the 6809 (2 MHz), YM2151 (3.579545 MHz), OKI (1 MHz)
//----------------------------------------------------------------------------

reg   [5:0] ecnt;
reg         fallE, fallQ;
reg         mem_ready;

// A CPU cycle is 48 clk. The E edge is held back while a ROM read is still
// in flight; the time lost is made up by shortening the following cycles
// (to no less than 32 clk) so the average rate stays at 2 MHz.
//
// Settling times: the 6809 core works out its next address and register
// values combinationally (many logic levels), so nothing samples them until
// A_SETTLE clk after an E edge, and the read data is latched into din_r at
// least D_SETTLE clk before the E edge that takes it. The SDC declares the
// matching multicycle paths for the sound CPU.
localparam [5:0] A_SETTLE = 6'd8;
localparam [3:0] D_SETTLE = 4'd8;

reg   [7:0] lag;
reg         din_ok;              // read data latched for this cycle
reg   [3:0] din_age;             // clk since then
wire  [5:0] shorten = (lag > 8'd15) ? 6'd15 : lag[5:0];
reg   [5:0] cyc_end;             // last clk of this cycle (lag only changes at the E edge)
always @(posedge clk) cyc_end <= 6'd47 - shorten;
wire        e_fire  = !pause && (ecnt >= cyc_end) && din_ok && (din_age >= D_SETTLE - 4'd1);   // last clk of the cycle

always @(posedge clk) begin
	fallE <= 1'b0;
	fallQ <= 1'b0;
	if (reset) begin
		ecnt <= 6'd0;
		lag  <= 8'd0;
	end
	else if (!pause) begin
		if (ecnt == cyc_end - 6'd12)
			fallQ <= 1'b1;
		if (e_fire) begin
			fallE <= 1'b1;
			ecnt  <= 6'd0;
			lag   <= lag - {2'd0, shorten} + {2'd0, ecnt - cyc_end};
		end
		else if (ecnt != 6'd63)
			ecnt <= ecnt + 6'd1;
	end
end

reg  [26:0] fm_acc;
reg         fm_cen, fm_cen_p1, fm_half;
always @(posedge clk) begin
	fm_cen    <= 1'b0;
	fm_cen_p1 <= 1'b0;
	if (reset) begin
		fm_acc  <= 27'd0;
		fm_half <= 1'b0;
	end
	else if (fm_acc + 27'd3579545 >= 27'd96000000) begin
		fm_acc    <= fm_acc + 27'd3579545 - 27'd96000000;
		fm_cen    <= ~pause;
		fm_half   <= ~fm_half;
		fm_cen_p1 <= ~pause & fm_half;
	end
	else
		fm_acc <= fm_acc + 27'd3579545;
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
// Command interface and board reset
//
// Bit 8 low holds the sound CPU in reset (and selects bank 0). CVSD: bits 0-7
// go to PIA port B and bit 9 to CB1. ADPCM: bits 0-7 are latched and bit 9
// low raises the CPU IRQ.
//----------------------------------------------------------------------------

reg         cpu_hold;            // reset requested by the main board
reg   [7:0] cmd_latch;
reg         cmd_cb1;
reg         snd_irq;             // ADPCM command IRQ
reg         int_state;           // ADPCM: visible to the main CPU
reg  [10:0] int_clr_timer;       // 10 us after a command read

assign irq_state = int_state;

wire        cpu_rnw;
wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
reg   [7:0] cpu_din;             // read data mux (settles during the cycle)
reg   [7:0] din_r;               // what the CPU sees, latched before the E edge
reg   [3:0] bank;
reg   [2:0] oki_bank;

reg         cmd_read;            // ADPCM command register read this cycle

always @(posedge clk) begin
	if (reset) begin
		cpu_hold      <= 1'b0;
		cmd_latch     <= 8'h00;
		cmd_cb1       <= 1'b0;
		snd_irq       <= 1'b0;
		int_state     <= 1'b0;
		int_clr_timer <= 11'd0;
	end
	else begin
		if (int_clr_timer != 11'd0) begin
			int_clr_timer <= int_clr_timer - 11'd1;
			if (int_clr_timer == 11'd1) int_state <= 1'b0;
		end
		if (cmd_read) begin
			snd_irq       <= 1'b0;
			int_clr_timer <= 11'd960;
		end
		if (cmd_wr) begin
			cpu_hold  <= ~cmd_data[8];
			cmd_latch <= cmd_data[7:0];
			cmd_cb1   <= cmd_data[9];
			if (!cmd_data[8]) begin
				// device_reset: interrupt lines and the ADPCM IRQ state drop
				snd_irq       <= 1'b0;
				int_state     <= 1'b0;
				int_clr_timer <= 11'd0;
			end
			if (adpcm && !cmd_data[9]) begin
				snd_irq   <= 1'b1;
				int_state <= 1'b1;
			end
		end
	end
end

//----------------------------------------------------------------------------
// 6809E
//----------------------------------------------------------------------------

wire        pia_irqa, pia_irqb;
wire        ym_irq_n;
reg         cpu_reset_n;

always @(posedge clk)
	cpu_reset_n <= ~(reset | cpu_hold);

mc6809is cpu
(
	.CLK      (clk),
	.fallE_en (fallE),
	.fallQ_en (fallQ),
	.OP       (8'h00),
	.D        (din_r),
	.DOut     (cpu_dout),
	.ADDR     (cpu_addr),
	.RnW      (cpu_rnw),
	.BS       (),
	.BA       (),
	.nIRQ     (~(adpcm & snd_irq)),
	.nFIRQ    (adpcm ? ym_irq_n : ~pia_irqa),
	.nNMI     (adpcm ? 1'b1 : ~pia_irqb),
	.AVMA     (),
	.BUSY     (),
	.LIC      (),
	.nHALT    (1'b1),
	.nRESET   (cpu_reset_n),
	.nDMABREQ (1'b1),
	.RegData  ()
);

//----------------------------------------------------------------------------
// Address decode
//----------------------------------------------------------------------------

wire a_ram   = adpcm ? (cpu_addr[15:13] == 3'b000) : (cpu_addr[15:13] == 3'b000);
wire a_ym    = adpcm ? (cpu_addr[15:10] == 6'b001001) : (cpu_addr[15:13] == 3'b001);
wire a_pia   = !adpcm && (cpu_addr[15:13] == 3'b010);
wire a_cvsdd = !adpcm && (cpu_addr[15:11] == 5'b01100);          // 6000-67FF
wire a_cvsdc = !adpcm && (cpu_addr[15:11] == 5'b01101);          // 6800-6FFF
wire a_bank  = adpcm ? (cpu_addr[15:10] == 6'b001000) : (cpu_addr[15:11] == 5'b01111);
wire a_dac   = adpcm && (cpu_addr[15:10] == 6'b001010);          // 2800
wire a_oki   = adpcm && (cpu_addr[15:10] == 6'b001011);          // 2C00
wire a_cmd   = adpcm && (cpu_addr[15:10] == 6'b001100);          // 3000
wire a_okibk = adpcm && (cpu_addr[15:10] == 6'b001101);          // 3400
wire a_rom   = adpcm ? (cpu_addr[15:14] != 2'b00) : cpu_addr[15];

// ROM byte offset from the start of the sound region in SDRAM
wire [19:0] rom_off = adpcm ?
	((cpu_addr[15:14] == 2'b11) ? (20'h3C000 + {6'd0, cpu_addr[13:0]})
	                            : ({2'd0, bank[2:0], 15'd0} + {4'd0, cpu_addr} - 20'h04000)) :
	({1'b0, bank[1:0], 17'd0} + {3'd0, bank[3:2], 15'd0} + {5'd0, cpu_addr[14:0]});
// (CVSD: 0x20000 * bank[1:0] + 0x8000 * bank[3:2] + A14-A0)

reg  [7:0] pram [0:63];
reg [63:0] pram_v;
reg  [7:0] pram_q;
wire [5:0] pram_a = 6'(cpu_addr - prot_start);
reg        pram_we;

wire a_prot  = (prot_mode != 2'd0) && (cpu_addr >= prot_start) && (cpu_addr <= prot_end);
// reads see the overlay: always for hidden RAM, for bank 0 bytes once written otherwise
wire a_prot_rd = a_prot && ((prot_mode == 2'd2) || (bank == 4'd0 && pram_v[pram_a]));

//----------------------------------------------------------------------------
// RAMs
//----------------------------------------------------------------------------

reg  [7:0] ram [0:8191];
reg  [7:0] ram_q;
wire [12:0] ram_a = adpcm ? cpu_addr[12:0] : {2'b00, cpu_addr[10:0]};
reg        ram_we;

always @(posedge clk) begin
	if (ram_we) ram[ram_a] <= cpu_dout;
	ram_q <= ram[ram_a];
end

// protection overlay: 64 bytes, each with a "written" flag so bank-0 ROM
// writes only shadow the bytes actually written

always @(posedge clk) begin
	if (pram_we) pram[pram_a] <= cpu_dout;
	pram_q <= pram[pram_a];
end

//----------------------------------------------------------------------------
// Peripherals
//----------------------------------------------------------------------------

reg        pia_rd, pia_wr;
wire [7:0] pia_dout;
wire [7:0] pia_pa;
wire       pia_ca2;

pia6821 pia
(
	.clk     (clk),
	.reset   (reset),
	.rd      (pia_rd),
	.wr      (pia_wr),
	.rs      (cpu_addr[1:0]),
	.din     (cpu_dout),
	.dout    (pia_dout),
	.pa_in   (8'hFF),
	.pa_out  (pia_pa),
	.ca1     (ym_irq_n),
	.ca2_in  (1'b1),
	.ca2_out (pia_ca2),
	.pb_in   (cmd_latch),
	.pb_out  (),
	.cb1     (cmd_cb1),
	.cb2_in  (1'b0),
	.cb2_out (),
	.irqa    (pia_irqa),
	.irqb    (pia_irqb)
);

reg        ym_wr;
wire [7:0] ym_dout;
wire signed [15:0] ym_l, ym_r;

// CVSD: PIA CA2 is the YM2151 /IC line
reg ym_rst;
always @(posedge clk)
	ym_rst <= reset | (~adpcm & ~pia_ca2);

jt51 ym
(
	.rst     (ym_rst),
	.clk     (clk),
	.cen     (fm_cen),
	.cen_p1  (fm_cen_p1),
	.cs_n    (~ym_wr),
	.wr_n    (~ym_wr),
	.a0      (cpu_addr[0]),
	.din     (cpu_dout),
	.dout    (ym_dout),
	.ct1     (),
	.ct2     (),
	.irq_n   (ym_irq_n),
	.sample  (),
	.left    (ym_l),
	.right   (ym_r),
	.xleft   (),
	.xright  ()
);

reg         cvsd_clk_w, cvsd_dig_w, cvsd_clk_v;
wire signed [15:0] cvsd_out;

hc55516 cvsd
(
	.clk       (clk),
	.reset     (reset),
	.clock_w   (cvsd_clk_w),
	.clock_val (cvsd_clk_v),
	.digit_w   (cvsd_dig_w),
	.digit_val (cpu_dout[0]),
	.sample    (cvsd_out)
);

reg  [7:0] dac;                  // ADPCM board DAC latch

reg        oki_wr;
wire [7:0] oki_dout;
wire [17:0] oki_rom_a;
reg  [7:0] oki_rom_d;
reg        oki_rom_ok;
wire signed [13:0] oki_snd;

jt6295 #(.INTERPOL(0)) oki
(
	.rst      (reset | ~adpcm),
	.clk      (clk),
	.cen      (oki_cen),
	.ss       (1'b1),
	.wrn      (~oki_wr),
	.din      (cpu_dout),
	.dout     (oki_dout),
	.rom_addr (oki_rom_a),
	.rom_data (oki_rom_d),
	.rom_ok   (oki_rom_ok),
	.sound    (oki_snd),
	.sample   ()
);

//----------------------------------------------------------------------------
// CPU bus cycle
//
// The address is stable from one E falling edge to the next. ROM reads are
// started once it has settled; everything else is answered from block RAM
// or registers. Side effects (writes, read-clear registers) happen once, on
// the clk before the E edge that ends the cycle.
//----------------------------------------------------------------------------

reg        rom_pending;
reg  [7:0] rom_byte;
reg  [2:0] rom_sel;

wire       addr_ok  = (ecnt == A_SETTLE);    // the new address has settled
wire       din_take = !din_ok && mem_ready && (ecnt > A_SETTLE) &&
                      ({1'b0, ecnt} + {3'd0, D_SETTLE} >= {1'b0, cyc_end});

always @(posedge clk) begin
	pia_rd     <= 1'b0;
	pia_wr     <= 1'b0;
	ym_wr      <= 1'b0;
	ram_we     <= 1'b0;
	pram_we    <= 1'b0;
	oki_wr     <= 1'b0;
	cvsd_clk_w <= 1'b0;
	cvsd_dig_w <= 1'b0;
	cmd_read   <= 1'b0;

	if (reset) begin
		rom_pending <= 1'b0;
		mem_ready   <= 1'b1;
		din_ok      <= 1'b0;
		rom_req     <= rom_ack;
		bank        <= 4'd0;
		oki_bank    <= 3'd0;
		dac         <= 8'h80;
		pram_v      <= 64'd0;
	end
	else begin
		if (cmd_wr && !cmd_data[8])
			bank <= 4'd0;

		// read data for the E edge
		if (fallE)
			din_ok <= 1'b0;
		else if (din_take) begin
			din_r   <= cpu_din;
			din_ok  <= 1'b1;
			din_age <= 4'd0;
		end
		else if (din_ok && din_age != 4'd15)
			din_age <= din_age + 4'd1;

		// address settled: fetch ROM bytes from SDRAM
		if (addr_ok) begin
			if (cpu_rnw && a_rom && !a_prot_rd) begin
				rom_addr    <= SND_BASE[24:3] + {5'd0, rom_off[19:3]};
				rom_sel     <= rom_off[2:0];
				rom_req     <= ~rom_req;
				rom_pending <= 1'b1;
				mem_ready   <= 1'b0;
			end
		end

		if (rom_pending && rom_req == rom_ack) begin
			rom_pending <= 1'b0;
			rom_byte    <= rom_data[{rom_sel, 3'b000} +: 8];
			mem_ready   <= 1'b1;
		end

		// last clk of the cycle: perform the access
		if (e_fire) begin
			if (!cpu_rnw && cpu_reset_n) begin
				if (a_prot) begin
					pram_we <= 1'b1;
					pram_v[pram_a] <= 1'b1;
				end
				else if (a_ram)
					ram_we <= 1'b1;
				if (a_ym)    ym_wr  <= 1'b1;
				if (a_pia)   pia_wr <= 1'b1;
				if (a_oki)   oki_wr <= 1'b1;
				if (a_dac)   dac    <= cpu_dout;
				if (a_bank)  bank   <= adpcm ? {1'b0, cpu_dout[2:0]} : cpu_dout[3:0];
				if (a_okibk) oki_bank <= cpu_dout[2:0];
				if (a_cvsdd) begin
					// clock low, then latch the data bit
					cvsd_clk_w <= 1'b1;
					cvsd_clk_v <= 1'b0;
					cvsd_dig_w <= 1'b1;
				end
				if (a_cvsdc) begin
					cvsd_clk_w <= 1'b1;
					cvsd_clk_v <= 1'b1;
				end
			end
			else if (cpu_rnw && cpu_reset_n) begin
				if (a_pia) pia_rd   <= 1'b1;
				if (a_cmd) cmd_read <= 1'b1;
			end
		end
	end
end

// read data (stable before the E edge)
always @(*) begin
	cpu_din = 8'hFF;
	if (a_prot_rd)
		cpu_din = pram_q;
	else if (a_rom)
		cpu_din = rom_byte;
	else if (a_ram)
		cpu_din = ram_q;
	else if (a_ym)
		cpu_din = ym_dout;
	else if (a_pia)
		cpu_din = pia_dout;
	else if (a_oki)
		cpu_din = oki_dout;
	else if (a_cmd)
		cpu_din = cmd_latch;
end

//----------------------------------------------------------------------------
// OKI sample ROM: one cached SDRAM line
//
// Bank map (MAME): 0x00000-0x1FFFF banked, 0x20000-0x3FFFF fixed at 0x60000.
//----------------------------------------------------------------------------

// Every bank base is a multiple of 0x20000, so the offset is the bank's top
// three bits in front of the 17-bit sample address
reg   [2:0] oki_hi;
always @(*) begin
	case (oki_bank)
		3'd0, 3'd1: oki_hi = 3'b010;    // 0x40000
		3'd2:       oki_hi = 3'b001;    // 0x20000
		3'd3:       oki_hi = 3'b000;    // 0x00000
		3'd4:       oki_hi = 3'b111;    // 0xE0000
		3'd5:       oki_hi = 3'b110;    // 0xC0000
		3'd6:       oki_hi = 3'b101;    // 0xA0000
		default:    oki_hi = 3'b100;    // 0x80000
	endcase
end
wire [19:0] oki_off = {oki_rom_a[17] ? 3'b011 : oki_hi, oki_rom_a[16:0]};   // fixed half at 0x60000

reg  [16:0] oki_tag;
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
		else if (!(oki_tag_ok && oki_tag == oki_off[19:3]) && adpcm) begin
			oki_tag    <= oki_off[19:3];
			oki_tag_ok <= 1'b0;
			oki_addr   <= OKI_BASE[24:3] + {5'd0, oki_off[19:3]};
			oki_req    <= ~oki_req;
			oki_busy   <= 1'b1;
		end
	end
	oki_rom_d  <= oki_line[{oki_off[2:0], 3'b000} +: 8];
	oki_rom_ok <= oki_tag_ok && (oki_tag == oki_off[19:3]) && !oki_busy;
end

//----------------------------------------------------------------------------
// Mixer (MAME route gains)
//   CVSD:  YM2151 0.10 per channel, DAC 0.25, CVSD 0.60
//   ADPCM: YM2151 0.10 per channel, DAC 0.10, OKI 0.15 (then x2 for level)
//----------------------------------------------------------------------------

wire signed [15:0] dac_s = adpcm ? {~dac[7], dac[6:0], 8'h00} : {~pia_pa[7], pia_pa[6:0], 8'h00};
// OKI: jt6295 sums its four voices, 12 bits each, into 14 bits. MAME counts
// one voice at full volume as full scale (ADPCM value x volume / 2048), so
// one voice must reach +-32768 here: 4 bits up, 18 bits for four voices.
// (Shifted only 2 bits up, the voices were 12 dB too quiet against the music.)
wire signed [17:0] oki_s = {oki_snd, 4'b0000};

// Registered steps, so no clock period holds more than one multiply or one
// sum (until Build 10 the products and their sum were one step: two DSP
// multipliers and an adder in series, the design's worst timing path):
//   1. sources registered (the YM2151 outputs come through its log-to-linear
//      conversion combinationally), gains registered (they only change with
//      the board type);
//   2. one product per source;
//   3. the sum of the products;
//   4. clipped into the 16-bit output.
// Same output values as before, one 96 MHz clock later.
reg signed [15:0] m_yl, m_yr, m_dac;
reg signed [17:0] m_x;                    // ADPCM board: OKI, CVSD board: CVSD
reg signed  [8:0] g_ym, g_dac, g_x;
reg signed [25:0] p_yl, p_yr, p_dac, p_x;
reg signed [25:0] mix;
always @(posedge clk) begin
	m_yl  <= ym_l;
	m_yr  <= ym_r;
	m_dac <= dac_s;
	m_x   <= adpcm ? oki_s : {{2{cvsd_out[15]}}, cvsd_out};

	g_ym  <= adpcm ? 9'sd52 : 9'sd26;      // YM2151: 0.10 per channel
	g_dac <= adpcm ? 9'sd52 : 9'sd64;      // DAC: 0.10 / 0.25
	g_x   <= adpcm ? 9'sd77 : 9'sd154;     // OKI 0.15 / CVSD 0.60

	p_yl  <= 26'(m_yl)  * 26'(g_ym);
	p_yr  <= 26'(m_yr)  * 26'(g_ym);
	p_dac <= 26'(m_dac) * 26'(g_dac);
	p_x   <= 26'(m_x)   * 26'(g_x);

	mix   <= p_yl + p_yr + p_dac + p_x;

	if (mix > 26'sd8388352)
		audio <= 16'sd32767;
	else if (mix < -26'sd8388608)
		audio <= 16'sh8000;        // -32768 (written in hex: 32768 does not fit a 16-bit signed literal)
	else
		audio <= mix[23:8];
end

endmodule
