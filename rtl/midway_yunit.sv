//============================================================================
//  Williams/Midway Y Unit CPU board
//
//  TMS34010 plus everything on its local bus:
//    0x00000000-0x001FFFFF  frame store (VRAM, in DDR3)       entries 0-0x3FFFF
//    0x01000000-0x010FFFFF  main RAM, 128 KB
//    0x01400000-0x0140FFFF  CMOS, 8 KB window into 32 KB (4 pages)
//    0x01800000-0x0181FFFF  palette RAM
//    0x01A00000-0x01A0009F  DMA blitter registers (mirrored at +0x80000)
//    0x01C00000-0x01C0005F  input ports 0-5
//    0x01C00060-0x01C0007F  protection read / CMOS enable + protection write
//    0x01E00000-0x01E0001F  sound board command
//    0x01F00000-0x01F0001F  control register
//    0x02000000-0x05FFFFFF  graphics ROM read-back (pixels)
//    0xFF800000-0xFFFFFFFF  program ROM, 1 MB (SDRAM, through a cache)
//  (34010 bit addresses; unmapped reads return 0 as in MAME)
//
//  The program ROM is read through a 16 KB direct-mapped cache of 8-byte
//  SDRAM lines so the CPU rarely waits on SDRAM. VRAM writes from the CPU are
//  posted; reads wait for DDR3.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module midway_yunit
(
	input             clk,           // 96 MHz
	input             reset,
	input             pause,

	// game configuration
	input       [1:0] cpu_speed,     // 0: 40 MHz, 1: 48 MHz, 2: 50 MHz master clock
	input             bpp6,          // 6 bpp graphics/palette (else 4 bpp)
	input       [2:0] prot_id,       // protection data set (see prot_reset/prot_data)
	input       [2:0] t2_hack,       // Terminator 2 movie-freeze workaround variant
	input             t2_adc,        // input port 2 is the gun ADC
	input             t2_sound,      // T2 sound latch also answers at offset 1
	input             mk_turbo,      // MK Turbo hacks: counter GAL at 0xFFFFF400
	input             flip_x,
	input       [1:0] vtiming,       // MiSTer option: 0 native frame (54.7 Hz), 1 277 lines
	                                 // (57.1 Hz), 2 263 lines (60.1 Hz); see "Video timing"

	// inputs (active low as the CPU reads them), port 0-5
	input      [95:0] in_ports,
	input       [7:0] gun_p1_x,      // gun positions for the T2 ADC
	input       [7:0] gun_p1_y,
	input       [7:0] gun_p2_x,
	input       [7:0] gun_p2_y,

	// sound board command (one pulse per write)
	output reg        snd_wr,
	output reg [15:0] snd_data,

	// SDRAM: program ROM / graphics read-back (CPU) and blitter source
	output reg [24:3] cpu_sd_addr,
	output reg        cpu_sd_req,
	input             cpu_sd_ack,
	input      [63:0] cpu_sd_data,

	output     [24:3] dma_sd_addr,
	output            dma_sd_req,
	input             dma_sd_ack,
	input      [63:0] dma_sd_data,

	// DDR3 (VRAM)
	input             ddr_busy,
	output      [7:0] ddr_burstcnt,
	output     [28:0] ddr_addr,
	input      [63:0] ddr_dout,
	input             ddr_dout_ready,
	output            ddr_rd,
	output     [63:0] ddr_din,
	output      [7:0] ddr_be,
	output            ddr_we,

	// CMOS access for NVRAM load/save (word address, 16 K words)
	input      [13:0] nv_addr,
	input             nv_we,
	input      [15:0] nv_din,
	output     [15:0] nv_dout,
	output            cmos_write,    // the game wrote its CMOS (NVRAM needs saving)

	// video
	output            ce_pix,
	output      [7:0] vid_r,
	output      [7:0] vid_g,
	output      [7:0] vid_b,
	output            vid_hs,
	output            vid_vs,
	output            vid_hb,
	output            vid_vb,

	// debug; in the core dbg_wr / dbg_rd also tell the OSD's finishing-move
	// player and the Hidden Items page what the game does
	output     [31:0] dbg_pc,
	output            dbg_retire,
	output            dbg_wr,        // one pulse per CPU write as it completes
	output            dbg_rd,        // one pulse per CPU read as it completes
	output     [27:0] dbg_wa,        // its word address (bit address >> 4)
	output     [15:0] dbg_wdata,
	output     [15:0] dbg_rdata
);

// SDRAM byte addresses of the regions (see the ROM layout in the MRA files)
localparam [24:0] ROM_BASE = 25'h000_0000;
localparam [24:0] GFX_BASE = 25'h010_0000;

//----------------------------------------------------------------------------
// Clock enables
//
// Everything runs from one 24-step phase counter at 96 MHz:
//  - cpu_ce enables the 34010's logic on every other clock (48 MHz). Its
//    paths are constrained as two-cycle paths in the SDC, which is what lets
//    the instruction logic close timing.
//  - ce_cyc is the 34010 machine cycle (master clock / 8) from a fractional
//    divider stepped at 48 MHz, so it always falls in a cpu_ce cycle.
//  - VCLK is 4 MHz (24 MHz / 6) and the pixel clock 8 MHz, both exact
//    divisions of 96 MHz, and also aligned to cpu_ce cycles.
// Each enable is registered from the phase it will be high in.
//----------------------------------------------------------------------------

reg   [4:0] ph;
reg         cpu_ce, ce_vclk, ce_pix_r;
always @(posedge clk) begin
	ph       <= (ph == 5'd23) ? 5'd0 : ph + 5'd1;
	cpu_ce   <= ph[0];                               // next phase is even
	ce_vclk  <= (ph == 5'd23);                       // next phase 0
	ce_pix_r <= (ph == 5'd23) || (ph == 5'd11);      // next phase 0 or 12
end
assign ce_pix = ce_pix_r;

//----------------------------------------------------------------------------
// Video timing (MiSTer option for 15 kHz TVs)
//
// Every game runs a 289-line frame at 15.81 kHz: 54.7 Hz, which some TVs do
// not hold well. The shorter frames drop blank lines in the 34010's CRT
// controller (see tms34010.sv): 277 lines for 57.1 Hz or 263 for 60.1 Hz.
// The games count time in frames, so they run 289/277 (+4.3 %) or 289/263
// (+9.9 %) faster either way; the CPU's machine cycle and the blitter's
// completion time are sped up by the same ratio, so a frame still gets the
// real board's cycles. The sound board keeps its own clock (music and voices
// keep their pitch and tempo).
//----------------------------------------------------------------------------

wire  [1:0] vt = (vtiming == 2'd3) ? 2'd0 : vtiming;   // 3 is not used: native

reg   [9:0] frame_lines;
always @(posedge clk)
	frame_lines <= (vt == 2'd1) ? 10'd277 : (vt == 2'd2) ? 10'd263 : 10'd0;

reg  [16:0] cyc_acc;
reg         ce_cyc;

// step (master/8 in kHz, times 289/277 or 289/263 for the shorter frames) and
// the level at which a step wraps, registered from the game's speed setting
// so the accumulator update is one add or subtract and one compare
reg  [16:0] cyc_step, cyc_thr;
always @(posedge clk) begin
	case ({vt, cpu_speed})
		4'b01_00: cyc_step <= 17'd5217;    // 40 MHz board, 57 Hz
		4'b01_01: cyc_step <= 17'd6260;    // 48 MHz
		4'b01_10: cyc_step <= 17'd6521;    // 50 MHz
		4'b10_00: cyc_step <= 17'd5494;    // 40 MHz board, 60 Hz
		4'b10_01: cyc_step <= 17'd6593;
		4'b10_10: cyc_step <= 17'd6868;
		4'b00_10: cyc_step <= 17'd6250;    // native
		4'b00_01: cyc_step <= 17'd6000;
		default:  cyc_step <= 17'd5000;
	endcase
	cyc_thr  <= 17'd48000 - cyc_step;
end

// blitter completion time: one extra count off its timer at 289/277 - 1 or
// 289/263 - 1 of the clocks (16-bit fraction)
reg  [15:0] dma_frac, dma_fstep;
reg         dma_fast;
always @(posedge clk) begin
	dma_fstep <= (vt == 2'd1) ? 16'd2839 : (vt == 2'd2) ? 16'd6479 : 16'd0;
	{dma_fast, dma_frac} <= {1'b0, dma_frac} + {1'b0, dma_fstep};
end

always @(posedge clk) begin
	ce_cyc <= 1'b0;
	if (reset)
		cyc_acc <= 17'd0;
	else if (ph[0]) begin
		// steps of master/8 MHz out of 48 MHz: acc + step >= 48000 is
		// acc >= 48000 - step, and acc + step - 48000 is acc - (48000 - step)
		if (cyc_acc >= cyc_thr) begin
			cyc_acc <= cyc_acc - cyc_thr;
			ce_cyc  <= ~pause;
		end
		else
			cyc_acc <= cyc_acc + cyc_step;
	end
end

//----------------------------------------------------------------------------
// TMS34010
//----------------------------------------------------------------------------

wire [27:0] mem_addr;
wire [31:0] mem_baddr;
wire        mem_rd, mem_wr, mem_srt;
wire [15:0] mem_wdata;
reg  [15:0] mem_rdata;
reg         mem_ack;

wire        cpu_hs, cpu_vs, cpu_hb, cpu_vb, disp_en;
wire  [9:0] hcount, vcount, heblnk, hsblnk, cpu_vsblnk;
wire        line_start, line_vis;
wire [11:0] line_row;
wire [13:0] line_col;
wire        dma_irq;
wire [31:0] cpu_pc;
wire        cpu_retire;

tms34010 cpu
(
	.clk        (clk),
	.ce         (cpu_ce),
	.reset      (reset),
	.ce_cyc     (ce_cyc),
	.ce_vclk    (ce_vclk),
	.pause      (pause),
	.frame_lines(frame_lines),

	.mem_addr   (mem_addr),
	.mem_baddr  (mem_baddr),
	.mem_rd     (mem_rd),
	.mem_wr     (mem_wr),
	.mem_srt    (mem_srt),
	.mem_wdata  (mem_wdata),
	.mem_rdata  (mem_rdata),
	.mem_ack    (mem_ack),

	.int1       (dma_irq),
	.int2       (1'b0),

	.hsync      (cpu_hs),
	.vsync      (cpu_vs),
	.hblank     (cpu_hb),
	.vblank     (cpu_vb),
	.hcount     (hcount),
	.vcount     (vcount),
	.heblnk     (heblnk),
	.hsblnk     (hsblnk),
	.vsblnk     (cpu_vsblnk),
	.disp_en    (disp_en),
	.line_start (line_start),
	.line_vis   (line_vis),
	.line_row   (line_row),
	.line_col   (line_col),

	.dbg_pc     (cpu_pc),
	.dbg_st     (),
	.dbg_retire (cpu_retire),
	.dbg_cycles ()
);

assign dbg_pc = cpu_pc;

// CPU pulses last two clocks (one cpu_ce period); count them once
assign dbg_retire = cpu_retire & cpu_ce;

//----------------------------------------------------------------------------
// CPU bus, registered on the board side
//
// The CPU's request, address and data come straight out of its registers
// through its bus multiplexer and I/O range check. Decoding them on the same
// clock gave the longest single-clock paths at 96 MHz (CPU register ->
// address decode -> bus state machine), and the timing report failed by more
// than a nanosecond. The board now decodes a copy registered one clock
// later. That costs nothing on fast accesses: the CPU only looks at mem_ack
// on cpu_ce edges, every other clock, so an access accepted one clock later
// is still seen on the same cpu_ce edge.
//
// When the CPU takes an acknowledge (mem_ack high on a cpu_ce edge) it moves
// on at once, but the copy still holds the finished request for one more
// clock; b_stale keeps the state machine from serving it twice.
//----------------------------------------------------------------------------

reg         b_rd, b_wr, b_srt, b_stale;
reg  [27:0] b_addr;
reg  [20:3] b_baddr;
reg  [15:0] b_wdata;
reg  [31:0] b_pc;
always @(posedge clk) begin
	b_rd    <= mem_rd;
	b_wr    <= mem_wr;
	b_srt   <= mem_srt;
	b_addr  <= mem_addr;
	b_baddr <= mem_baddr[20:3];
	b_wdata <= mem_wdata;
	b_pc    <= cpu_pc;
	b_stale <= cpu_ce & mem_ack;
end

// Completed accesses: the CPU takes mem_ack on a cpu_ce edge, once per
// access; the registered copy still holds that access's address and data
assign dbg_wr    = cpu_ce & mem_ack & b_wr;
assign dbg_rd    = cpu_ce & mem_ack & b_rd;
assign dbg_wa    = b_addr;
assign dbg_wdata = b_wdata;
assign dbg_rdata = mem_rdata;

//----------------------------------------------------------------------------
// Address decode (word addresses, from the registered copy)
//----------------------------------------------------------------------------

wire [27:0] wa = b_addr;

wire sel_vram = (wa[27:17] == 11'd0);
wire sel_ram  = (wa[27:16] == 12'h010);
wire sel_cmos = (wa[27:12] == 16'h0140);
wire sel_pal  = (wa[27:13] == 15'h00C0);
wire sel_dma  = (wa[27:16] == 12'h01A) && (wa[14:4] == 11'd0) && (wa[3:0] <= 4'd9);
wire sel_in   = (wa[27:4]  == 24'h01C000) && (wa[3:0] <= 4'd5);
wire sel_prot = (wa[27:1]  == 27'h00E0003);              // words 0x1C0006-0x1C0007
wire sel_snd  = (wa[27:1]  == 27'h00F0000);              // words 0x1E0000-0x1E0001
wire sel_ctrl = (wa[27:1]  == 27'h00F8000);              // words 0x1F0000-0x1F0001
wire sel_gfx  = (wa[27:23] == 5'd0) && ((wa[22:21] == 2'b01) || (wa[22:21] == 2'b10));
wire sel_rom  = (wa[27:19] == 9'h1FF);
wire sel_turbo = mk_turbo && (wa == 28'hFFFFF40);

//----------------------------------------------------------------------------
// Main RAM (64 K x 16)
//----------------------------------------------------------------------------

reg  [15:0] ram [0:65535];
reg  [15:0] ram_q;
reg         ram_we;
reg  [15:0] ram_wa;
reg  [15:0] ram_wd;
reg  [15:0] ram_ra;

always @(posedge clk) begin
	if (ram_we) ram[ram_wa] <= ram_wd;
	ram_q <= ram[ram_ra];
end

//----------------------------------------------------------------------------
// CMOS (16 K x 16, 4 pages of 4 K words). Port B serves NVRAM load/save.
//
// This is an explicit altsyncram (true dual-port M10K) rather than an
// inferred array: Quartus 17 would not infer a true dual-port RAM from either
// the old-data or the new-data template here and fell back to 256 K
// registers. Both ports use clk; addresses and write data are registered
// inside the block and the outputs are not, so q_a/q_b hold the word
// addressed on the previous clock, exactly as the old array did.
//
// Same-port read-during-write returns the new data (the mode the M10K offers
// in this configuration); nothing reads a port on the clock it writes it.
// The mixed-port mode is don't care: an NVRAM save reading port B on the
// clock the CPU writes the same word through port A may get either value,
// but that CPU write marks the CMOS dirty again so the next save carries it.
//
// A behavioural model of altsyncram for simulation is not part of the core;
// Quartus supplies the real one.
//----------------------------------------------------------------------------

wire [15:0] cmos_q;
reg         cmos_we;
reg   [1:0] cmos_page;
wire [13:0] cmos_a = {cmos_page, b_addr[11:0]};

altsyncram #(
	.operation_mode                     ("BIDIR_DUAL_PORT"),
	.intended_device_family             ("Cyclone V"),
	.lpm_type                           ("altsyncram"),
	.ram_block_type                     ("M10K"),
	.width_a                            (16),
	.widthad_a                          (14),
	.numwords_a                         (16384),
	.width_b                            (16),
	.widthad_b                          (14),
	.numwords_b                         (16384),
	.width_byteena_a                    (1),
	.width_byteena_b                    (1),
	.address_reg_b                      ("CLOCK0"),
	.indata_reg_b                       ("CLOCK0"),
	.wrcontrol_wraddress_reg_b          ("CLOCK0"),
	.outdata_reg_a                      ("UNREGISTERED"),
	.outdata_reg_b                      ("UNREGISTERED"),
	.outdata_aclr_a                     ("NONE"),
	.outdata_aclr_b                     ("NONE"),
	.clock_enable_input_a               ("BYPASS"),
	.clock_enable_input_b               ("BYPASS"),
	.clock_enable_output_a              ("BYPASS"),
	.clock_enable_output_b              ("BYPASS"),
	.read_during_write_mode_port_a      ("NEW_DATA_NO_NBE_READ"),
	.read_during_write_mode_port_b      ("NEW_DATA_NO_NBE_READ"),
	.read_during_write_mode_mixed_ports ("DONT_CARE"),
	.power_up_uninitialized             ("FALSE")
) cmos_mem
(
	// port A: TMS34010 (CMOS window, page from the control register)
	.clock0         (clk),
	.address_a      (cmos_a),
	.data_a         (b_wdata),
	.wren_a         (cmos_we),
	.q_a            (cmos_q),

	// port B: NVRAM load/save and CMOS clear from the top level
	.clock1         (1'b1),
	.address_b      (nv_addr),
	.data_b         (nv_din),
	.wren_b         (nv_we),
	.q_b            (nv_dout),

	// unused controls
	.aclr0          (1'b0),
	.aclr1          (1'b0),
	.addressstall_a (1'b0),
	.addressstall_b (1'b0),
	.byteena_a      (1'b1),
	.byteena_b      (1'b1),
	.clocken0       (1'b1),
	.clocken1       (1'b1),
	.clocken2       (1'b1),
	.clocken3       (1'b1),
	.rden_a         (1'b1),
	.rden_b         (1'b1),
	.eccstatus      ()
);

assign cmos_write = cmos_we;

//----------------------------------------------------------------------------
// Palette RAM, CPU copy (8 K x 16). The display copy lives in yunit_video.
//----------------------------------------------------------------------------

reg  [15:0] palram [0:8191];
reg  [15:0] pal_q;
reg         pal_we;

always @(posedge clk) begin
	if (pal_we) palram[wa[12:0]] <= b_wdata;
	pal_q <= palram[wa[12:0]];
end

wire [11:0] pal_mask = bpp6 ? 12'hFFF : 12'h0FF;

//----------------------------------------------------------------------------
// Program ROM cache: 2048 lines of 8 bytes, direct mapped
//----------------------------------------------------------------------------

reg  [63:0] cache_data [0:2047];
reg   [6:0] cache_tag  [0:2047];      // {valid, tag}
reg  [63:0] cd_q;
reg   [6:0] ct_q;
reg         c_we;
reg  [10:0] c_wa;
reg  [63:0] c_wd;
reg   [6:0] c_wt;

wire [16:0] rom_line = wa[18:2];       // 8-byte line within the 1 MB ROM

always @(posedge clk) begin
	if (c_we) begin
		cache_data[c_wa] <= c_wd;
		cache_tag[c_wa]  <= c_wt;
	end
	cd_q <= cache_data[rom_line[10:0]];
	ct_q <= cache_tag[rom_line[10:0]];
end

// the cache is cleared by walking it after reset (a ROM reload is followed
// by a reset, so stale lines never survive a game change)
reg         c_clr;
reg  [10:0] c_clr_a;

//----------------------------------------------------------------------------
// Graphics ROM pixel extraction (same interleaved layout as the blitter)
//----------------------------------------------------------------------------

function automatic [7:0] line_pixel(input [63:0] line, input [2:0] k, input six);
	reg [1:0] p0, p1, p2;
	begin
		p0 = line[{1'b0, 1'b0, k[2], k[1:0], 1'b0} +: 2];
		p1 = line[{1'b0, 1'b1, k[2], k[1:0], 1'b0} +: 2];
		p2 = line[{1'b1, 1'b0, k[2], k[1:0], 1'b0} +: 2];
		line_pixel = {2'b00, six ? p2 : 2'b00, p1, p0};
	end
endfunction

// pixel index of the word being read back: (word - 0x200000) * 2
wire [22:0] gfx_pix = {wa[21:0] - 22'h200000, 1'b0};
wire  [7:0] gpx0    = line_pixel(cpu_sd_data, gfx_pix[2:0], bpp6);
wire  [7:0] gpx1    = line_pixel(cpu_sd_data, gfx_pix[2:0] | 3'd1, bpp6);
wire [15:0] gfx_word = bpp6 ? {gpx1, gpx0} : {gpx1[3:0], gpx1[3:0], gpx0[3:0], gpx0[3:0]};

//----------------------------------------------------------------------------
// Protection (MAME cmos_enable_w / protection_r)
//----------------------------------------------------------------------------

localparam P_NONE = 3'd0, P_TROG = 3'd1, P_HIIMPACT = 3'd2, P_SHIMPACT = 3'd3,
           P_STRKFORC = 3'd4, P_MK = 3'd5, P_TERM2 = 3'd6, P_TOTCARN = 3'd7;

function automatic [47:0] prot_reset(input [2:0] id);
	case (id)
		P_TROG:     prot_reset = {16'h0f00, 16'h0f00, 16'h0f00};
		P_HIIMPACT: prot_reset = {16'h0b00, 16'h0b00, 16'h0b00};
		P_SHIMPACT: prot_reset = {16'h0f00, 16'h0e00, 16'h0d00};
		P_MK:       prot_reset = {16'h0d00, 16'h0c00, 16'h0900};
		P_TERM2:    prot_reset = {16'h0f00, 16'h0f00, 16'h0f00};
		P_TOTCARN:  prot_reset = {16'h0f00, 16'h0f00, 16'h0f00};
		default:    prot_reset = 48'hFFFF_FFFF_FFFF;   // never matches
	endcase
endfunction

function automatic [15:0] prot_data(input [2:0] id, input [4:0] i);
	reg [15:0] v;
	begin
		v = 16'h0000;
		case (id)
			P_TROG: case (i)
				5'd0: v = 16'h3000; 5'd1: v = 16'h1000; 5'd2: v = 16'h2000; 5'd3: v = 16'h0000;
				5'd4: v = 16'h2000; 5'd5: v = 16'h3000; 5'd6: v = 16'h3000; 5'd7: v = 16'h1000;
				5'd8: v = 16'h0000; 5'd9: v = 16'h0000; 5'd10: v = 16'h2000; 5'd11: v = 16'h3000;
				5'd12: v = 16'h1000; 5'd13: v = 16'h1000; 5'd14: v = 16'h2000;
				default: v = 16'h0000;
			endcase
			P_HIIMPACT: case (i)
				5'd0: v = 16'h2000; 5'd1: v = 16'h4000; 5'd2: v = 16'h4000; 5'd3: v = 16'h0000;
				5'd4: v = 16'h6000; 5'd5: v = 16'h6000; 5'd6: v = 16'h2000; 5'd7: v = 16'h4000;
				5'd8: v = 16'h2000; 5'd9: v = 16'h4000; 5'd10: v = 16'h2000; 5'd11: v = 16'h0000;
				5'd12: v = 16'h4000; 5'd13: v = 16'h6000; 5'd14: v = 16'h2000;
				default: v = 16'h0000;
			endcase
			P_SHIMPACT: case (i)
				5'd0: v = 16'h0000; 5'd1: v = 16'h4000; 5'd2: v = 16'h2000; 5'd3: v = 16'h5000;
				5'd4: v = 16'h2000; 5'd5: v = 16'h1000; 5'd6: v = 16'h4000; 5'd7: v = 16'h6000;
				5'd8: v = 16'h3000; 5'd9: v = 16'h0000; 5'd10: v = 16'h2000; 5'd11: v = 16'h5000;
				5'd12: v = 16'h5000; 5'd13: v = 16'h5000; 5'd14: v = 16'h2000;
				default: v = 16'h0000;
			endcase
			P_MK: case (i)
				5'd0: v = 16'h4600; 5'd1: v = 16'hf600; 5'd2: v = 16'ha600; 5'd3: v = 16'h0600;
				5'd4: v = 16'h2600; 5'd5: v = 16'h9600; 5'd6: v = 16'hc600; 5'd7: v = 16'he600;
				5'd8: v = 16'h8600; 5'd9: v = 16'h7600; 5'd10: v = 16'h8600; 5'd11: v = 16'h8600;
				5'd12: v = 16'h9600; 5'd13: v = 16'hd600; 5'd14: v = 16'h6600; 5'd15: v = 16'hb600;
				5'd16: v = 16'hd600; 5'd17: v = 16'he600; 5'd18: v = 16'hf600; 5'd19: v = 16'h7600;
				5'd20: v = 16'hb600; 5'd21: v = 16'ha600; 5'd22: v = 16'h3600;
				default: v = 16'h0000;
			endcase
			P_TERM2: case (i)
				5'd0: v = 16'h4000; 5'd1: v = 16'hf000; 5'd2: v = 16'ha000;
				default: v = 16'h0000;
			endcase
			P_TOTCARN: case (i)
				5'd0: v = 16'h4a00; 5'd1: v = 16'h6a00; 5'd2: v = 16'hda00; 5'd3: v = 16'h6a00;
				5'd4: v = 16'h9a00; 5'd5: v = 16'h4a00; 5'd6: v = 16'h2a00; 5'd7: v = 16'h9a00;
				5'd8: v = 16'h1a00; 5'd9: v = 16'h8a00; 5'd10: v = 16'haa00;
				default: v = 16'h0000;
			endcase
			default: v = 16'h0000;
		endcase
		prot_data = v;
	end
endfunction

reg  [15:0] prot_seq0, prot_seq1, prot_seq2;
reg   [4:0] prot_index;
reg  [15:0] prot_result;

reg  [47:0] prot_rst_pat;        // reset sequence for this game (prot_id is static)
reg         prot_load;           // look up the next answer (the cycle after the write)
reg   [4:0] prot_load_idx;
always @(posedge clk) prot_rst_pat <= prot_reset(prot_id);

wire [15:0] prot_in   = b_wdata & 16'h0F00;
wire        prot_rst  = ({prot_seq1, prot_seq2, prot_in} == prot_rst_pat);
wire  [4:0] prot_idx0 = prot_rst ? 5'd0 : prot_index;

//----------------------------------------------------------------------------
// Terminator 2 gun ADC (ADC0844): a write selects a channel and starts a
// 40 us conversion, a read returns the last result
//----------------------------------------------------------------------------

reg   [3:0] adc_ch;
reg  [11:0] adc_timer;
reg   [7:0] adc_result;

reg         adc_start;
always @(posedge clk) begin
	if (reset) begin
		adc_timer  <= 12'd0;
		adc_result <= 8'd0;
	end
	else if (adc_start)
		adc_timer <= 12'd3840;
	else if (adc_timer != 12'd0) begin
		adc_timer <= adc_timer - 12'd1;
		if (adc_timer == 12'd1)
			case (adc_ch)
				4'h4:    adc_result <= gun_p1_x;
				4'h5:    adc_result <= gun_p1_y;
				4'h6:    adc_result <= gun_p2_x;
				4'h7:    adc_result <= gun_p2_y;
				default: adc_result <= 8'h00;
			endcase
	end
end

//----------------------------------------------------------------------------
// MK Turbo counter GAL (MAME returns random numbers; any changing value does)
//----------------------------------------------------------------------------

reg  [15:0] lfsr;
always @(posedge clk)
	lfsr <= reset ? 16'hACE1 : {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

//----------------------------------------------------------------------------
// Control register
//----------------------------------------------------------------------------

reg         videobank;          // 1: CPU accesses pixel bytes, 0: palette bytes
reg         autoerase_en;

//----------------------------------------------------------------------------
// DMA blitter
//----------------------------------------------------------------------------

reg         dma_reg_wr;
wire [15:0] dma_rdata;
wire        dma_wr_wait;
wire [15:0] dma_palette;

wire  [8:0] blt_row;
wire  [6:0] blt_lo, blt_hi, blt_raddr;
wire [63:0] blt_q;
wire  [7:0] blt_be;
wire        blt_req, blt_ack;
wire [22:3] dma_line;

yunit_dma dma
(
	.clk         (clk),
	.reset       (reset),
	.bpp6        (bpp6),
	.fast        (dma_fast),

	.reg_wr      (dma_reg_wr),
	.reg_idx     (wa[3:0]),
	.reg_wdata   (b_wdata),
	.reg_rdata   (dma_rdata),
	.reg_wr_wait (dma_wr_wait),
	.palette_reg (dma_palette),

	.irq         (dma_irq),

	.gfx_line    (dma_line),
	.gfx_req     (dma_sd_req),
	.gfx_ack     (dma_sd_ack),
	.gfx_data    (dma_sd_data),

	.blt_req     (blt_req),
	.blt_ack     (blt_ack),
	.blt_row     (blt_row),
	.blt_lo      (blt_lo),
	.blt_hi      (blt_hi),
	.blt_raddr   (blt_raddr),
	.blt_q       (blt_q),
	.blt_be      (blt_be)
);

assign dma_sd_addr = GFX_BASE[24:3] + {2'b00, dma_line};

//----------------------------------------------------------------------------
// VRAM controller
//----------------------------------------------------------------------------

wire        disp_req, disp_ack;
wire  [8:0] disp_row;
wire        lb_we;
wire  [6:0] lb_addr;
wire [63:0] lb_data;
wire        erase_req, erase_ack;
wire  [8:0] erase_dst, erase_src;

reg         srt_req;
wire        srt_ack;
reg         srt_wr;
reg  [17:0] srt_entry;
wire [15:0] srt_first;

reg         vcpu_req;
wire        vcpu_ack;
reg         vcpu_wr;
reg  [15:0] vcpu_qaddr;
reg         vcpu_half;
reg   [3:0] vcpu_be;
reg  [31:0] vcpu_wdata;
wire [31:0] vcpu_rdata;

yunit_vram vram
(
	.clk            (clk),
	.reset          (reset),

	.ddr_busy       (ddr_busy),
	.ddr_burstcnt   (ddr_burstcnt),
	.ddr_addr       (ddr_addr),
	.ddr_dout       (ddr_dout),
	.ddr_dout_ready (ddr_dout_ready),
	.ddr_rd         (ddr_rd),
	.ddr_din        (ddr_din),
	.ddr_be         (ddr_be),
	.ddr_we         (ddr_we),

	.disp_req       (disp_req),
	.disp_ack       (disp_ack),
	.disp_row       (disp_row),
	.lb_we          (lb_we),
	.lb_addr        (lb_addr),
	.lb_data        (lb_data),

	.erase_req      (erase_req),
	.erase_ack      (erase_ack),
	.erase_dst      (erase_dst),
	.erase_src      (erase_src),

	.srt_req        (srt_req),
	.srt_ack        (srt_ack),
	.srt_wr         (srt_wr),
	.srt_entry      (srt_entry),
	.srt_first      (srt_first),

	.blt_req        (blt_req),
	.blt_ack        (blt_ack),
	.blt_row        (blt_row),
	.blt_lo         (blt_lo),
	.blt_hi         (blt_hi),
	.blt_raddr      (blt_raddr),
	.blt_q          (blt_q),
	.blt_be         (blt_be),

	.cpu_req        (vcpu_req),
	.cpu_ack        (vcpu_ack),
	.cpu_wr         (vcpu_wr),
	.cpu_qaddr      (vcpu_qaddr),
	.cpu_half       (vcpu_half),
	.cpu_be         (vcpu_be),
	.cpu_wdata      (vcpu_wdata),
	.cpu_rdata      (vcpu_rdata)
);

wire vram_idle = (vcpu_req == vcpu_ack) && (srt_req == srt_ack);

//----------------------------------------------------------------------------
// Video
//----------------------------------------------------------------------------

reg         vpal_we;
reg  [11:0] vpal_addr;
reg  [14:0] vpal_data;

yunit_video video
(
	.clk          (clk),
	.reset        (reset),
	.ce_pix       (ce_pix_r),
	.ce_vclk      (ce_vclk),
	.bpp6         (bpp6),
	.flip_x       (flip_x),
	.autoerase_en (autoerase_en & ~pause),   // a paused picture must stay on screen

	.hcount       (hcount),
	.heblnk       (heblnk),
	.hsblnk       (hsblnk),
	.vcount       (vcount),
	.vsblnk       (cpu_vsblnk),
	.hsync_in     (cpu_hs),
	.vsync_in     (cpu_vs),
	.hblank_in    (cpu_hb),
	.vblank_in    (cpu_vb),
	.disp_en      (disp_en),
	.line_start   (line_start & cpu_ce),     // one clock per CPU pulse
	.line_vis     (line_vis),
	.line_row     (line_row),
	.line_col     (line_col),

	.pal_we       (vpal_we),
	.pal_addr     (vpal_addr),
	.pal_data     (vpal_data),

	.disp_req     (disp_req),
	.disp_ack     (disp_ack),
	.disp_row     (disp_row),
	.lb_we        (lb_we),
	.lb_addr      (lb_addr),
	.lb_data      (lb_data),

	.erase_req    (erase_req),
	.erase_ack    (erase_ack),
	.erase_dst    (erase_dst),
	.erase_src    (erase_src),

	.r            (vid_r),
	.g            (vid_g),
	.b            (vid_b),
	.hsync        (vid_hs),
	.vsync        (vid_vs),
	.hblank       (vid_hb),
	.vblank       (vid_vb)
);

//----------------------------------------------------------------------------
// Bus cycle state machine
//----------------------------------------------------------------------------

localparam S_IDLE    = 4'd0;
localparam S_BRAM    = 4'd1;     // block RAM read data arrives
localparam S_ROM     = 4'd2;     // cache tag check
localparam S_ROMFILL = 4'd3;     // waiting for the SDRAM line
localparam S_GFX     = 4'd4;     // graphics read-back from SDRAM
localparam S_VRAMRD  = 4'd5;     // VRAM read: wait for the bridge, then the data
localparam S_VRAMWR  = 4'd6;     // VRAM write: wait for a free slot
localparam S_SRT     = 4'd7;     // shift-register transfer
localparam S_DMAWAIT = 4'd8;     // blitter start held while it is busy
localparam S_PROT    = 4'd9;     // Strike Force protection reads main RAM
localparam S_PROT2   = 4'd10;

reg   [3:0] bstate;
reg   [1:0] bram_src;            // 0 RAM, 1 CMOS, 2 palette
reg         vram_sent;

// The CPU holds a request until it sees mem_ack in a cpu_ce cycle, so the ack
// is held until then; while it is up, and for the one clock after it is
// taken (b_stale), the same request is not served again.
wire        req = (b_rd | b_wr) & ~mem_ack & ~b_stale;

// Terminator 2 freeze workaround (MAME term2*_hack_w): one main RAM word is
// forced to zero when written by one specific instruction
wire        t2_hack_hit = (t2_hack != 3'd0) && sel_ram && (wa[15:1] == 15'h5507) &&
                          (((t2_hack == 3'd1) && wa[0]  && (b_pc == 32'hFFCE6520)) ||
                           ((t2_hack == 3'd2) && !wa[0] && (b_pc == 32'hFFCE5230)) ||
                           ((t2_hack == 3'd3) && !wa[0] && (b_pc == 32'hFFCE4B80)) ||
                           ((t2_hack == 3'd4) && !wa[0] && (b_pc == 32'hFFCE33F0)));

always @(*) begin
	ram_ra = wa[15:0];
	if (bstate == S_PROT) ram_ra = 16'hA439;   // 0x010A4390 >> 4
end

always @(posedge clk) begin
	if (cpu_ce)
		mem_ack <= 1'b0;
	ram_we     <= 1'b0;
	cmos_we    <= 1'b0;
	pal_we     <= 1'b0;
	vpal_we    <= 1'b0;
	c_we       <= 1'b0;
	snd_wr     <= 1'b0;
	dma_reg_wr <= 1'b0;
	adc_start  <= 1'b0;
	prot_load  <= 1'b0;

	if (reset) begin
		mem_ack     <= 1'b0;
		bstate      <= S_IDLE;
		cpu_sd_req  <= cpu_sd_ack;
		vcpu_req    <= vcpu_ack;
		srt_req     <= srt_ack;
		cmos_page   <= 2'd0;
		videobank   <= 1'b0;
		autoerase_en <= 1'b0;
		prot_seq0   <= 16'd0;
		prot_seq1   <= 16'd0;
		prot_seq2   <= 16'd0;
		prot_index  <= 5'd0;
		prot_result <= 16'd0;
		c_clr       <= 1'b1;
		c_clr_a     <= 11'd0;
		adc_ch      <= 4'd0;
		vram_sent   <= 1'b0;
	end
	else begin
		if (prot_load)
			prot_result <= prot_data(prot_id, prot_load_idx);

		// clear the ROM cache after reset
		if (c_clr) begin
			c_we    <= 1'b1;
			c_wa    <= c_clr_a;
			c_wt    <= 7'd0;
			c_clr_a <= c_clr_a + 11'd1;
			if (c_clr_a == 11'h7FF) c_clr <= 1'b0;
		end

		case (bstate)
			S_IDLE: if (req && !c_clr) begin
				if (b_srt) begin
					// VRAM shift-register transfer of two rows
					if (vram_idle) begin
						srt_wr    <= b_wr;
						srt_entry <= b_baddr[20:3];
						srt_req   <= ~srt_req;
						bstate    <= S_SRT;
					end
				end
				else if (b_wr) begin
					// ---- writes ----
					if (sel_vram)
						bstate <= S_VRAMWR;
					else if (sel_dma) begin
						dma_reg_wr <= 1'b1;
						bstate     <= S_DMAWAIT;
					end
					else if (sel_prot && prot_id == P_STRKFORC && prot_in == 16'h0500) begin
						// Strike Force: the answer comes from a main RAM word
						prot_seq0 <= prot_seq1;
						prot_seq1 <= prot_seq2;
						prot_seq2 <= prot_in;
						bstate    <= S_PROT;
					end
					else begin
						mem_ack <= 1'b1;
						if (sel_ram) begin
							ram_we <= 1'b1;
							ram_wa <= wa[15:0];
							ram_wd <= t2_hack_hit ? 16'h0000 : b_wdata;
						end
						if (sel_cmos)
							cmos_we <= 1'b1;
						if (sel_pal) begin
							pal_we    <= 1'b1;
							vpal_we   <= 1'b1;
							vpal_addr <= wa[11:0] & pal_mask;
							vpal_data <= b_wdata[14:0];
						end
						if (sel_ctrl) begin
							cmos_page    <= b_wdata[7:6];
							videobank    <= b_wdata[5];
							autoerase_en <= ~b_wdata[4];
						end
						if (sel_snd && (!wa[0] || t2_sound)) begin
							snd_wr   <= 1'b1;
							snd_data <= b_wdata;
							if (t2_adc && !wa[0]) begin
								adc_ch    <= {2'b01, b_wdata[13:12]};
								adc_start <= 1'b1;
							end
						end
						if (sel_prot && prot_id != P_NONE) begin
							// shift the sequence FIFO; the reset pattern restarts
							// the data, bit 11 going low clocks out the next word
							prot_seq0 <= prot_seq1;
							prot_seq1 <= prot_seq2;
							prot_seq2 <= prot_in;
							if (prot_id != P_STRKFORC) begin
								if (prot_seq2[11] && !prot_in[11]) begin
									prot_load     <= 1'b1;
									prot_load_idx <= prot_idx0;
									prot_index  <= (prot_idx0 == 5'd31) ? 5'd31 : prot_idx0 + 5'd1;
								end
								else
									prot_index  <= prot_idx0;
							end
						end
					end
				end
				else begin
					// ---- reads ----
					if (sel_ram || sel_cmos || sel_pal) begin
						bram_src <= sel_ram ? 2'd0 : sel_cmos ? 2'd1 : 2'd2;
						bstate   <= S_BRAM;
					end
					else if (sel_turbo) begin
						mem_ack   <= 1'b1;
						mem_rdata <= lfsr;
					end
					else if (sel_rom)
						bstate <= S_ROM;
					else if (sel_gfx) begin
						cpu_sd_addr <= GFX_BASE[24:3] + {2'b00, gfx_pix[22:3]};
						cpu_sd_req  <= ~cpu_sd_req;
						bstate      <= S_GFX;
					end
					else if (sel_vram)
						bstate <= S_VRAMRD;
					else begin
						mem_ack <= 1'b1;
						if (sel_dma)
							mem_rdata <= dma_rdata;
						else if (sel_in)
							mem_rdata <= (t2_adc && wa[3:0] == 4'd2) ? {8'hFF, adc_result} : in_ports[{wa[2:0], 4'b0000} +: 16];
						else if (sel_prot)
							mem_rdata <= prot_result;
						else
							mem_rdata <= 16'h0000;
					end
				end
			end

			S_BRAM: begin
				// the read address went to the RAMs with the request
				mem_ack   <= 1'b1;
				mem_rdata <= (bram_src == 2'd0) ? ram_q : (bram_src == 2'd1) ? cmos_q : pal_q;
				bstate    <= S_IDLE;
			end

			S_ROM: begin
				if (ct_q == {1'b1, rom_line[16:11]}) begin
					mem_ack   <= 1'b1;
					mem_rdata <= cd_q[{wa[1:0], 4'b0000} +: 16];
					bstate    <= S_IDLE;
				end
				else begin
					cpu_sd_addr <= ROM_BASE[24:3] + {5'd0, rom_line};
					cpu_sd_req  <= ~cpu_sd_req;
					bstate      <= S_ROMFILL;
				end
			end

			S_ROMFILL: if (cpu_sd_req == cpu_sd_ack) begin
				c_we      <= 1'b1;
				c_wa      <= rom_line[10:0];
				c_wd      <= cpu_sd_data;
				c_wt      <= {1'b1, rom_line[16:11]};
				mem_ack   <= 1'b1;
				mem_rdata <= cpu_sd_data[{wa[1:0], 4'b0000} +: 16];
				bstate    <= S_IDLE;
			end

			S_GFX: if (cpu_sd_req == cpu_sd_ack) begin
				mem_ack   <= 1'b1;
				mem_rdata <= gfx_word;
				bstate    <= S_IDLE;
			end

			S_VRAMWR: if (vram_idle) begin
				// two entries per CPU word: the pixel bytes carry the DMA
				// palette register along, the palette bytes leave pixels alone
				vcpu_wr    <= 1'b1;
				vcpu_qaddr <= wa[16:1];
				vcpu_half  <= wa[0];
				if (videobank) begin
					vcpu_be    <= 4'b1111;
					vcpu_wdata <= {dma_palette[15:8], b_wdata[15:8], dma_palette[7:0], b_wdata[7:0]};
				end
				else begin
					vcpu_be    <= 4'b1010;
					vcpu_wdata <= {b_wdata[15:8], 8'h00, b_wdata[7:0], 8'h00};
				end
				vcpu_req <= ~vcpu_req;
				mem_ack  <= 1'b1;                // posted
				bstate   <= S_IDLE;
			end

			S_VRAMRD: begin
				if (!vram_sent) begin
					if (vram_idle) begin
						vcpu_wr    <= 1'b0;
						vcpu_qaddr <= wa[16:1];
						vcpu_half  <= wa[0];
						vcpu_req   <= ~vcpu_req;
						vram_sent  <= 1'b1;
					end
				end
				else if (vcpu_req == vcpu_ack) begin
					vram_sent <= 1'b0;
					mem_ack   <= 1'b1;
					mem_rdata <= videobank ? {vcpu_rdata[23:16], vcpu_rdata[7:0]} : {vcpu_rdata[31:24], vcpu_rdata[15:8]};
					bstate    <= S_IDLE;
				end
			end

			S_SRT: if (srt_req == srt_ack) begin
				mem_ack   <= 1'b1;
				mem_rdata <= srt_first;
				bstate    <= S_IDLE;
			end

			S_DMAWAIT: begin
				// keep offering the write until the blitter takes it
				if (dma_wr_wait)
					dma_reg_wr <= 1'b1;
				else begin
					mem_ack <= 1'b1;
					bstate  <= S_IDLE;
				end
			end

			S_PROT:  bstate <= S_PROT2;      // RAM address presented

			S_PROT2: begin
				prot_result <= {ram_q[11:0], 4'h0};
				mem_ack     <= 1'b1;
				bstate      <= S_IDLE;
			end

			default: bstate <= S_IDLE;
		endcase
	end
end

endmodule
