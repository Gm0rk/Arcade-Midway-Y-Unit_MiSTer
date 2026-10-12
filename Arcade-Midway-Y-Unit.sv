//============================================================================
//  Williams/Midway Y Unit for MiSTer
//
//  Top level (emu): HPS interface, ROM loading, memories, per-game
//  configuration and inputs, video output with CRT Adjust, audio.
//
//  Clocks: everything runs from one 96 MHz clock (clk_sys). The 34010, the
//  pixel clock (8 MHz), the sound CPU (2 MHz E clock), the YM2151 and the
//  OKI are clock enables derived from it.
//
//  Memory:
//    SDRAM  program ROM, graphics ROM, sound CPU ROM, OKI samples
//    DDR3   the 512 KB frame store (VRAM)
//    BRAM   main RAM, CMOS, palette, caches and line buffers
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  Copyright (C) 2026 Gm0rk
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1        = 0;
assign VGA_SCALER    = 0;
assign VGA_DISABLE   = 0;
assign HDMI_FREEZE   = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

//////////////////////////////////////////////////////////////////
// OSD
//////////////////////////////////////////////////////////////////

`include "build_id.v"
`include "rtl/yunit_fmoves_osd.svh"
localparam CONF_STR = {
	"A.MIDWAYY;;",
	"P1,Video Settings;",
	"P1-;",
	"P1O[2:1],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1O[7:6],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O[15:14],Video Timing,Native 54.7Hz,57Hz,60Hz;",
	"P1O[101],CRT Adjust,Off,On;",
	"H1P1O[102],CRT Auto-Width,Off,On;",
	"H1P1O[100:96],CRT H-Size,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[85:79],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,+32,+33,+34,+35,+36,+37,+38,+39,+40,+41,+42,+43,+44,+45,+46,+47,+48,-48,-47,-46,-45,-44,-43,-42,-41,-40,-39,-38,-37,-36,-35,-34,-33,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[78:74],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[107:104],CRT V-Size,0,+1,+2,+3,+4,+5,+6,+7,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[108],CRT V-Size Mode,PVM,Cabinet;",
	"-;",
	`FMOVES_MENU,
	"H5-;",
	"DIP;",
	"H4P2,Hidden Items;",
	"P2-;",
	"H2P2T[16],EJB Menu;",
	"H3P2T[16],Octopus Bookkeeping;",
	"O[9],Service Mode,Off,On;",
	"O[8],Pause when OSD is open,On,Off;",
	`FMOVES_PAGES,
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,B1,B2,B3,B4,B5,B6,Start,Coin,Test,Pause;",
	"jn,A,B,X,Y,L,R,Start,Select,,;",
	`CORE_INFO,
	"V,v",`BUILD_DATE
};

wire        forced_scandoubler;
wire        direct_video;
wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;
wire [31:0] joy0, joy1, joy2, joy3;
wire [15:0] joy0_a, joy1_a, joy0_ra, joy1_ra;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire        ioctl_rd;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire [15:0] ioctl_din;
reg         ioctl_wait;

reg   [4:0] game_id;
wire        is_t2;
wire        sec_ejb, sec_octo;              // the game has a hidden menu (see secret_menu.sv)
wire        is_mk;                          // Mortal Kombat: Move List and Finishing Moves
wire        info_req;
wire  [7:0] info;

hps_io #(.CONF_STR(CONF_STR), .CONF_STR_BRAM(1), .WIDE(1)) hps_io
(
	.clk_sys             (clk_sys),
	.HPS_BUS             (HPS_BUS),
	.EXT_BUS             (),
	.gamma_bus           (gamma_bus),

	.forced_scandoubler  (forced_scandoubler),
	.direct_video        (direct_video),

	.buttons             (buttons),
	.status              (status),
	.status_menumask     ({5'd0, status[30:28], 2'd0, ~is_mk, ~(sec_ejb | sec_octo), ~sec_octo, ~sec_ejb, ~status[101], 1'b0}),
	.info_req            (info_req),
	.info                (info),

	.ps2_key             (ps2_key),
	.ps2_mouse           (ps2_mouse),

	.joystick_0          (joy0),
	.joystick_1          (joy1),
	.joystick_2          (joy2),
	.joystick_3          (joy3),
	.joystick_l_analog_0 (joy0_a),
	.joystick_l_analog_1 (joy1_a),
	.joystick_r_analog_0 (joy0_ra),
	.joystick_r_analog_1 (joy1_ra),

	.ioctl_download      (ioctl_download),
	.ioctl_upload        (ioctl_upload),
	.ioctl_upload_req    (ioctl_upload_req),
	.ioctl_upload_index  (8'd2),
	.ioctl_index         (ioctl_index),
	.ioctl_wr            (ioctl_wr),
	.ioctl_rd            (ioctl_rd),
	.ioctl_addr          (ioctl_addr),
	.ioctl_dout          (ioctl_dout),
	.ioctl_din           (ioctl_din),
	.ioctl_wait          (ioctl_wait)
);

//////////////////////////////////////////////////////////////////
// Clocks and reset
//////////////////////////////////////////////////////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk   (CLK_50M),
	.rst      (1'b0),
	.outclk_0 (clk_sys),
	.locked   (pll_locked)
);

wire rom_download = ioctl_download && (ioctl_index == 16'd0);
reg  rom_loaded = 1'b0;
reg  rom_was_dl;

// the core runs once a complete ROM set has arrived
always @(posedge clk_sys) begin
	rom_was_dl <= rom_download;
	if (rom_download)    rom_loaded <= 1'b0;
	else if (rom_was_dl) rom_loaded <= 1'b1;
end

// The NVRAM file follows the ROMs in a separate transfer. Hold the board in
// reset for half a second after a ROM or NVRAM download so the game never
// boots on an empty CMOS that is about to be replaced. DIP switch transfers
// (index 254, sent each time a switch is changed in the OSD) do not reset
// the game: the DIP menu says "Reset to apply", and Service Credit and Tilt
// live there.
reg  [25:0] boot_hold;
always @(posedge clk_sys) begin
	if (ioctl_download && ioctl_index != 16'd254)
		boot_hold <= 26'd48_000_000;
	else if (boot_hold != 26'd0)
		boot_hold <= boot_hold - 26'd1;
end

wire reset = RESET | status[0] | buttons[1] | rom_download | ~rom_loaded | (boot_hold != 26'd0);

//////////////////////////////////////////////////////////////////
// Game configuration
//
// MRA ROM index 1 carries the game id. Hardware differences between the
// boards and revisions are all selected from it.
//////////////////////////////////////////////////////////////////

localparam G_TROG     = 5'd0;    // Trog (4-way joystick)
localparam G_TROGPA4  = 5'd1;    // Trog prototype rev 4.00 (8-way)
localparam G_SMASHTV  = 5'd2;
localparam G_HIIMPACT = 5'd3;
localparam G_SHIMPACT = 5'd4;
localparam G_STRKFORC = 5'd5;    // Strike Force, Saurian Front
localparam G_MK       = 5'd6;    // Mortal Kombat rev 1-4
localparam G_MKPROT   = 5'd7;    // Mortal Kombat prototypes (50 MHz board)
localparam G_MKTURBO  = 5'd8;    // Mortal Kombat Turbo hacks
localparam G_TERM2    = 5'd9;    // Terminator 2 LA4
localparam G_TERM2LA3 = 5'd10;
localparam G_TERM2LA2 = 5'd11;
localparam G_TERM2LA1 = 5'd12;   // LA1, PA2, LG1
localparam G_TOTCARN  = 5'd13;

reg   [1:0] cfg_speed;           // 0: 40 MHz, 1: 48 MHz, 2: 50 MHz
reg         cfg_bpp6;
reg         cfg_adpcm;
reg   [2:0] cfg_prot;
reg   [2:0] cfg_t2hack;
reg   [1:0] cfg_sprot_mode;
reg  [15:0] cfg_sprot_start;
reg  [15:0] cfg_sprot_end;
reg         cfg_turbo;
reg   [2:0] cfg_layout;

localparam L_TROG = 3'd0, L_HIIMP = 3'd1, L_SMASH = 3'd2, L_STRK = 3'd3, L_MK = 3'd4, L_T2 = 3'd5;

always @(posedge clk_sys) begin
	cfg_speed       <= 2'd0;
	cfg_bpp6        <= 1'b1;
	cfg_adpcm       <= 1'b0;
	cfg_prot        <= 3'd0;
	cfg_t2hack      <= 3'd0;
	cfg_sprot_mode  <= 2'd0;
	cfg_sprot_start <= 16'h0000;
	cfg_sprot_end   <= 16'h0000;
	cfg_turbo       <= 1'b0;
	cfg_layout      <= L_TROG;

	case (game_id)
		G_TROG, G_TROGPA4: begin
			cfg_bpp6 <= 1'b0;
			cfg_prot <= 3'd1;
			cfg_sprot_mode <= 2'd1; cfg_sprot_start <= 16'h9EAF; cfg_sprot_end <= 16'h9ED9;
		end
		G_SMASHTV: begin
			cfg_sprot_mode <= 2'd1; cfg_sprot_start <= 16'h9CF6; cfg_sprot_end <= 16'h9D21;
			cfg_layout <= L_SMASH;
		end
		G_HIIMPACT: begin
			cfg_prot <= 3'd2;
			cfg_sprot_mode <= 2'd2; cfg_sprot_start <= 16'h9B79; cfg_sprot_end <= 16'h9BA3;
			cfg_layout <= L_HIIMP;
		end
		G_SHIMPACT: begin
			cfg_prot <= 3'd3;
			cfg_sprot_mode <= 2'd2; cfg_sprot_start <= 16'h9C06; cfg_sprot_end <= 16'h9C15;
			cfg_layout <= L_HIIMP;
		end
		G_STRKFORC: begin
			cfg_speed <= 2'd1;
			cfg_bpp6  <= 1'b0;
			cfg_prot  <= 3'd4;
			cfg_sprot_mode <= 2'd1; cfg_sprot_start <= 16'h9F7D; cfg_sprot_end <= 16'h9FA7;
			cfg_layout <= L_STRK;
		end
		G_MK, G_MKPROT, G_MKTURBO: begin
			cfg_speed <= (game_id == G_MKPROT) ? 2'd2 : 2'd1;
			cfg_adpcm <= 1'b1;
			cfg_prot  <= 3'd5;
			cfg_turbo <= (game_id == G_MKTURBO);
			cfg_sprot_mode <= 2'd2; cfg_sprot_start <= 16'hFB9C; cfg_sprot_end <= 16'hFBC6;
			cfg_layout <= L_MK;
		end
		G_TERM2, G_TERM2LA3, G_TERM2LA2, G_TERM2LA1: begin
			cfg_speed  <= 2'd2;
			cfg_adpcm  <= 1'b1;
			cfg_prot   <= 3'd6;
			cfg_t2hack <= 3'(game_id - G_TERM2 + 5'd1);
			cfg_sprot_mode <= 2'd2; cfg_sprot_start <= 16'hFA8D; cfg_sprot_end <= 16'hFA9C;
			cfg_layout <= L_T2;
		end
		G_TOTCARN: begin
			cfg_speed <= 2'd1;
			cfg_adpcm <= 1'b1;
			cfg_prot  <= 3'd7;
			cfg_sprot_mode <= 2'd2; cfg_sprot_start <= 16'hFC04; cfg_sprot_end <= 16'hFC2E;
			cfg_layout <= L_SMASH;
		end
		default: ;
	endcase
end

assign is_t2 = (cfg_layout == L_T2);

//////////////////////////////////////////////////////////////////
// Downloads: ROMs (index 0), game id (1), NVRAM (2), DIP switches (254)
//
// ROM layout (byte addresses, same in the MRA and in SDRAM except for the
// graphics, whose four 2 MB chunks are interleaved per 16-bit word so one
// SDRAM line holds every plane of 8 pixels):
//   0x000000  program, 1 MB (16-bit little endian)
//   0x100000  graphics, 8 MB (MAME "gfx" region)
//   0x900000  sound CPU, from MAME region offset 0x10000
//   0xA00000  OKI samples, 1 MB (ADPCM games)
//////////////////////////////////////////////////////////////////

reg  [63:0] dsw;

always @(posedge clk_sys) begin
	if (ioctl_wr && ioctl_index == 16'd1 && ioctl_addr == 27'd0)
		game_id <= ioctl_dout[4:0];
	if (ioctl_wr && ioctl_index == 16'd254 && ioctl_addr[26:3] == 24'd0)
		dsw[{ioctl_addr[2:1], 4'b0000} +: 16] <= ioctl_dout;
end

// DIP bits 0-15 are the board's switches (input port 3). The MRAs add
// MiSTer entries to the same OSD DIP menu in bits 16-19:
//   16  Service Credit  } buttons: every selection flips the bit, which is
//   17  Tilt            } taken as one press (both values read "Press")
//   18  Gun Control (Terminator 2): 0 joystick, 1 mouse
//   19  Crosshair   (Terminator 2): 0 on, 1 off
// The first DIP transfer after a ROM load only sets the reference for the
// two buttons (it is the saved setting, not a press).
reg  [1:0] dip_btn_ref;
reg        dip_btn_armed;
reg  [1:0] dip_btn_hit;                    // one-clock press: {Tilt, Service Credit}

always @(posedge clk_sys) begin
	dip_btn_hit <= 2'b00;
	if (rom_download)
		dip_btn_armed <= 1'b0;
	else if (ioctl_wr && ioctl_index == 16'd254 && ioctl_addr[26:1] == 26'd1) begin
		dip_btn_ref   <= ioctl_dout[1:0];
		dip_btn_armed <= 1'b1;
		if (dip_btn_armed) dip_btn_hit <= ioctl_dout[1:0] ^ dip_btn_ref;
	end
end

wire gun_mouse = dsw[18];                   // Terminator 2 DIP "Gun Control"
wire xhair_off = dsw[19];                   // Terminator 2 DIP "Crosshair"

wire [24:0] dl_off  = ioctl_addr[24:0] - 25'h010_0000;
wire        dl_gfx  = (ioctl_addr[26:20] >= 7'h01) && (ioctl_addr[26:20] < 7'h09);
wire [24:0] dl_sdram = dl_gfx ? (25'h010_0000 + {2'b00, dl_off[20:1], dl_off[22:21], 1'b0}) : ioctl_addr[24:0];

reg  [24:1] sd_wr_addr;
reg  [15:0] sd_wr_data;
reg         sd_wr_req;
wire        sd_wr_ack;

always @(posedge clk_sys) begin
	if (ioctl_wr && rom_download) begin
		sd_wr_addr <= dl_sdram[24:1];
		sd_wr_data <= ioctl_dout;
		sd_wr_req  <= ~sd_wr_req;
		ioctl_wait <= 1'b1;
	end
	else if (sd_wr_req == sd_wr_ack)
		ioctl_wait <= 1'b0;
end

// NVRAM (CMOS): loaded through port B of the CMOS RAM, cleared when a new
// ROM set arrives so a game never sees another game's settings
reg  [13:0] cmos_clr_addr;
reg         cmos_clr;
reg         cmos_dirty;
reg         osd_open_d;                    // OSD_STATUS one clock late (save request)
wire [15:0] nv_dout;
wire        cmos_write;

wire        nv_dl = ioctl_download && ioctl_index == 16'd2;

always @(posedge clk_sys) begin
	if (rom_download && !rom_was_dl) begin
		cmos_clr      <= 1'b1;
		cmos_clr_addr <= 14'd0;
	end
	else if (cmos_clr) begin
		cmos_clr_addr <= cmos_clr_addr + 14'd1;
		if (cmos_clr_addr == 14'h3FFF) cmos_clr <= 1'b0;
	end

	// note that the game has changed its CMOS since the last save
	if (cmos_write) cmos_dirty <= 1'b1;
	else if (ioctl_upload && ioctl_index == 16'd2) cmos_dirty <= 1'b0;

	osd_open_d <= OSD_STATUS;
end

// Main_MiSTer looks for a save request each time it draws the core's main OSD
// page, which it does after every change made in the OSD. The request is
// raised only for the clock the OSD opens (hps_io latches it until the HPS
// reads it), so the CMOS is saved once, on opening, when it has changed.
assign ioctl_upload_req = cmos_dirty & OSD_STATUS & ~osd_open_d;
assign ioctl_din        = nv_dout;

wire [13:0] nv_addr = cmos_clr ? cmos_clr_addr : ioctl_addr[14:1];
wire        nv_we   = cmos_clr | (nv_dl & ioctl_wr);
wire [15:0] nv_din  = cmos_clr ? 16'h0000 : ioctl_dout;

//////////////////////////////////////////////////////////////////
// Inputs
//
// Joystick bits: 0 R, 1 L, 2 D, 3 U, 4-9 B1-B6, 10 Start, 11 Coin, 12 Test,
// 13 Pause. Ports are active low. The layouts follow MAME's input ports.
//
// Service Credit and Tilt are not on the controllers: they are entries in
// the OSD DIP Switches menu, handled in "OSD service credit and tilt" below.
// The hidden-menu shortcut ("Hidden developer menus" below) replaces the
// player controls while its button code plays.
//////////////////////////////////////////////////////////////////

wire [31:0] joy [0:3];
assign joy[0] = joy0;
assign joy[1] = joy1;
assign joy[2] = joy2;
assign joy[3] = joy3;

// 4-way joysticks (Trog): on a diagonal the axis pressed last wins
reg   [3:0] dir4 [0:3];
reg   [3:0] last_raw [0:3];
integer p;
always @(posedge clk_sys) begin
	for (p = 0; p < 4; p = p + 1) begin
		last_raw[p] <= joy[p][3:0];
		if ((joy[p][3] | joy[p][2]) && (joy[p][1] | joy[p][0])) begin
			// keep the axis of the newly pressed direction
			if ((joy[p][3:2] & ~last_raw[p][3:2]) != 2'b00)
				dir4[p] <= {joy[p][3:2], 2'b00};
			else if ((joy[p][1:0] & ~last_raw[p][1:0]) != 2'b00)
				dir4[p] <= {2'b00, joy[p][1:0]};
		end
		else
			dir4[p] <= joy[p][3:0];
	end
end

// {U, D, L, R} in MAME bit order (up, down, left, right) for player n
function automatic [3:0] udlr(input [3:0] j);
	udlr = {j[0], j[1], j[2], j[3]};      // bit0 U, bit1 D, bit2 L, bit3 R
endfunction

wire [3:0] pdir [0:3];
genvar gi;
generate
	for (gi = 0; gi < 4; gi = gi + 1) begin : g_dir
		assign pdir[gi] = udlr(((game_id == G_TROG) ? dir4[gi] : joy[gi][3:0]));
	end
endgenerate

// twin-stick games: fire directions from B1-B4 or the right analog stick
function automatic [3:0] fire_dir(input [31:0] j, input [15:0] ra);
	reg signed [7:0] ax, ay;
	begin
		ax = ra[7:0];
		ay = ra[15:8];
		fire_dir[0] = j[4] | (ay < -8'sd64);    // up
		fire_dir[1] = j[5] | (ay >  8'sd64);    // down
		fire_dir[2] = j[6] | (ax < -8'sd64);    // left
		fire_dir[3] = j[7] | (ax >  8'sd64);    // right
	end
endfunction

wire [3:0] fire1 = fire_dir(joy0, joy0_ra);
wire [3:0] fire2 = fire_dir(joy1, joy1_ra);

wire       test_sw = status[9] | joy0[12] | joy1[12];
reg  [3:0] svc_cnt  = 4'd0;                 // service credit held while non-zero
reg  [3:0] tilt_cnt = 4'd0;                 // slam tilt held while non-zero
wire       svc_sw  = |svc_cnt;
wire       tilt_sw = |tilt_cnt;
wire       adpcm_irq;
wire       sec_active;
wire [15:0] sec_in0, sec_in1;

// finishing-move player (OSD Finishing Moves page): while it plays a move it
// replaces the winner's controls
wire  [1:0] fm_drive;
wire  [8:0] fm_keys;                        // {BL, LK, HK, LP, HP, Right, Left, Down, Up}

// active-high port images, inverted at the end
reg  [15:0] in0, in1, in2;
always @(*) begin
	in0 = 16'h0000;
	in1 = 16'h0000;
	in2 = 16'h0000;

	// common to every board
	in1[0] = joy0[11];               // coin 1
	in1[1] = joy1[11];               // coin 2
	in1[2] = joy0[10];               // start 1
	in1[3] = tilt_sw;                // tilt (slam switch)
	in1[4] = test_sw;                // test
	in1[5] = joy1[10];               // start 2
	in1[6] = svc_sw;                 // service credit

	case (cfg_layout)
		L_TROG, L_HIIMP: begin
			in0[3:0]   = pdir[0];  in0[4]  = joy0[4];
			in0[11:8]  = pdir[1];  in0[12] = joy1[4];
			in1[9]     = joy2[10];            // start 3
			in1[10]    = joy3[10];            // start 4
			in1[14:11] = pdir[2];  in1[15] = joy2[4];
			in2[3:0]   = pdir[3];  in2[4]  = joy3[4];
			if (cfg_layout == L_TROG)
				in2[5] = joy2[11];            // coin 3
			else begin
				in1[7] = joy2[11];            // coin 3
				in2[5] = joy3[11];            // coin 4
			end
		end
		L_SMASH: begin
			in0[3:0]   = pdir[0];  in0[7:4]   = fire1;
			in0[11:8]  = pdir[1];  in0[15:12] = fire2;
			in1[9]     = joy2[11];            // coin 3
			in1[14]    = adpcm_irq;           // Total Carnage: sound IRQ pending
		end
		L_STRK: begin
			// B1 fire, B2 weapon, B3 weapon select
			in0[3:0]   = pdir[0];  in0[6:4]   = joy0[6:4];
			in0[11:8]  = pdir[1];  in0[14:12] = joy1[6:4];
			in1[7]     = joy2[11];            // coin 3
			in1[9]     = joy3[11];            // coin 4
		end
		L_MK: begin
			// B1 high punch, B2 low punch, B3 high kick, B4 low kick, B5 block,
			// in the order of the MRA's button list. The cabinet has one block
			// button per player; the board's second block input (MAME "Block 2",
			// IN1 bits 11 and 15) stays open.
			in0[3:0]   = pdir[0];
			in0[4]     = joy0[4];                 // P1 high punch
			in1[12]    = joy0[5];                 // P1 low punch
			in0[6]     = joy0[6];                 // P1 high kick
			in1[13]    = joy0[7];                 // P1 low kick
			in0[5]     = joy0[8];                 // P1 block
			in0[11:8]  = pdir[1];
			in0[12]    = joy1[4];                 // P2 high punch
			in1[9]     = joy1[5];                 // P2 low punch
			in0[14]    = joy1[6];                 // P2 high kick
			in1[10]    = joy1[7];                 // P2 low kick
			in0[13]    = joy1[8];                 // P2 block
			in1[8]     = joy2[11];                // coin 3
			in1[14]    = adpcm_irq;
		end
		L_T2: begin
			in0[4]  = joy0[4] | mouse_btn[0];  in0[5]  = joy0[5] | mouse_btn[1];
			in0[12] = joy1[4];                 in0[13] = joy1[5];
			in1[7]  = joy2[11];                // coin 3
			in1[9]  = joy3[11];                // coin 4
			in1[14] = adpcm_irq;
		end
		default: ;
	endcase

	// finishing moves: the winner's controls replaced by the move's
	if (cfg_layout == L_MK) begin
		if (fm_drive[0]) begin
			in0[6:0]   = {fm_keys[6], fm_keys[8], fm_keys[4], fm_keys[3:0]};   // HK, BL, HP, R L D U
			in1[13:12] = {fm_keys[7], fm_keys[5]};                             // LK, LP
		end
		if (fm_drive[1]) begin
			in0[14:8]  = {fm_keys[6], fm_keys[8], fm_keys[4], fm_keys[3:0]};
			in1[10:9]  = {fm_keys[7], fm_keys[5]};
		end
	end

	// hidden menu shortcut: while the code plays it owns the player controls
	// (every other player switch released, coins and service switches kept)
	if (sec_active) begin
		in0 = sec_in0;
		if (cfg_layout == L_MK) begin
			in1[13:9] = 5'd0;
			in1[15]   = 1'b0;
		end
		else begin
			in1[2]    = 1'b0;                 // start 1
			in1[5]    = 1'b0;                 // start 2
			in1[15:9] = sec_in1[15:9];        // starts 3/4, P3
			in2[4:0]  = 5'd0;                 // P4
		end
	end
end

wire [95:0] in_ports = {16'hFFFF, 16'hFFFF, dsw[15:0], ~in2, ~in1, ~in0};

//////////////////////////////////////////////////////////////////
// Terminator 2 guns
//
// Joystick: the left analog stick points directly, the d-pad moves the
// sight. Mouse: player 1 follows the mouse. Positions are 0-255 across the
// picture; the ADC sees X reversed (MAME PORT_REVERSE) because the cabinet
// shows a mirrored picture.
//////////////////////////////////////////////////////////////////

reg   [7:0] gun_x [0:1];
reg   [7:0] gun_y [0:1];
reg   [1:0] mouse_btn;
reg         mouse_tog;
reg  [17:0] gun_tick;

wire [15:0] gun_a [0:1];
assign gun_a[0] = joy0_a;
assign gun_a[1] = joy1_a;

function automatic [7:0] clamp_add(input [7:0] v, input signed [9:0] d);
	reg signed [10:0] s;
	begin
		s = $signed({3'b000, v}) + d;
		clamp_add = (s < 0) ? 8'd0 : (s > 11'sd255) ? 8'd255 : s[7:0];
	end
endfunction

integer gp;
always @(posedge clk_sys) begin
	gun_tick <= gun_tick + 18'd1;
	mouse_tog <= ps2_mouse[24];

	if (reset) begin
		gun_x[0] <= 8'd128; gun_y[0] <= 8'd128;
		gun_x[1] <= 8'd128; gun_y[1] <= 8'd128;
	end
	else begin
		for (gp = 0; gp < 2; gp = gp + 1) begin
			if (!(gun_mouse && gp == 0)) begin
				if (gun_a[gp] != 16'h0000) begin
					gun_x[gp] <= gun_a[gp][7:0]  + 8'd128;
					gun_y[gp] <= gun_a[gp][15:8] + 8'd128;
				end
				else if (gun_tick == 18'd0) begin
					// about 370 steps per second across the screen
					if (joy[gp][0]) gun_x[gp] <= clamp_add(gun_x[gp],  10'sd1);
					if (joy[gp][1]) gun_x[gp] <= clamp_add(gun_x[gp], -10'sd1);
					if (joy[gp][2]) gun_y[gp] <= clamp_add(gun_y[gp],  10'sd1);
					if (joy[gp][3]) gun_y[gp] <= clamp_add(gun_y[gp], -10'sd1);
				end
			end
		end

		if (gun_mouse && (mouse_tog != ps2_mouse[24])) begin
			gun_x[0]  <= clamp_add(gun_x[0], $signed({ps2_mouse[4], ps2_mouse[4], ps2_mouse[15:8]}));
			gun_y[0]  <= clamp_add(gun_y[0], -$signed({ps2_mouse[5], ps2_mouse[5], ps2_mouse[23:16]}));
			mouse_btn <= ps2_mouse[1:0];
		end
		if (!gun_mouse)
			mouse_btn <= 2'b00;
	end
end

//////////////////////////////////////////////////////////////////
// Pause
//////////////////////////////////////////////////////////////////

reg  pause_toggle;
reg  pause_btn_d;
always @(posedge clk_sys) begin
	pause_btn_d <= joy0[13] | joy1[13];
	if (reset) pause_toggle <= 1'b0;
	else if ((joy0[13] | joy1[13]) & ~pause_btn_d) pause_toggle <= ~pause_toggle;
end

// Mortal Kombat's Move List window (see Video) holds the game too
wire [2:0] movelist_sel = status[43:41];         // Off, then a fighter
wire       movelist_on  = is_mk && movelist_sel != 3'd0;
wire pause = pause_toggle | (OSD_STATUS & ~status[8]) | movelist_on;

//////////////////////////////////////////////////////////////////
// Y Unit board
//////////////////////////////////////////////////////////////////

wire [24:3] cpu_sd_addr, dma_sd_addr, snd_sd_addr, oki_sd_addr;
wire        cpu_sd_req, dma_sd_req, snd_sd_req, oki_sd_req;
wire        cpu_sd_ack, dma_sd_ack, snd_sd_ack, oki_sd_ack;
wire [63:0] cpu_sd_data, dma_sd_data, snd_sd_data, oki_sd_data;

wire        snd_wr;
wire [15:0] snd_data;

wire        ce_pix;
wire  [7:0] brd_r, brd_g, brd_b;          // the board's picture
wire  [7:0] core_r, core_g, core_b;       // with the Move List window
wire        core_hs, core_vs, core_hb, core_vb;

//////////////////////////////////////////////////////////////////
// OSD service credit and tilt
//
// Both are "Press" entries in the OSD DIP Switches menu (see dip_btn_hit
// above). A press holds the matching cabinet switch closed for 8 frames
// (about 150 ms), long enough for the game's switch scan to accept it, like
// a real coin or slam switch. Frames are counted only while the game runs,
// so with "Pause when OSD is open" the switch closes when the OSD is shut.
//////////////////////////////////////////////////////////////////

reg        osd_vb_d;
wire       osd_frame = core_vb & ~osd_vb_d & ~pause;   // start of a running frame

always @(posedge clk_sys) begin
	osd_vb_d <= core_vb;

	if (reset) begin
		svc_cnt  <= 4'd0;
		tilt_cnt <= 4'd0;
	end
	else begin
		if (dip_btn_hit[0])              svc_cnt  <= 4'd8;
		else if (osd_frame && svc_sw)    svc_cnt  <= svc_cnt - 4'd1;

		if (dip_btn_hit[1])              tilt_cnt <= 4'd8;
		else if (osd_frame && tilt_sw)   tilt_cnt <= tilt_cnt - 4'd1;
	end
end

//////////////////////////////////////////////////////////////////
// Hidden developer menus
//
// "EJB Menu" (Mortal Kombat) and "Octopus Bookkeeping" (High Impact
// Football, Super High Impact) on the Hidden Items page share trigger bit 16.
// Only the item for the loaded game is shown, and the page only for games
// that have one (menu mask bits 2, 3 and 4). Selecting it plays the
// game's button code on the controls, one step per running frame; the
// game accepts it in attract mode (Super High Impact: only while HIGHEST
// PAID SUPERSTARS is on screen). Revisions without the menu ignore it.
//////////////////////////////////////////////////////////////////

assign sec_ejb  = (game_id == G_MK) | (game_id == G_MKPROT) | (game_id == G_MKTURBO);
assign sec_octo = (game_id == G_HIIMPACT) | (game_id == G_SHIMPACT);
assign is_mk    = sec_ejb;

// the board's completed CPU accesses (the menus and the fight, followed by
// secret_menu.sv and yunit_fmoves.sv)
wire        cpu_wr, cpu_rd;
wire [27:0] cpu_wa;
wire [15:0] cpu_wd, cpu_rdata;

// ROM index 1 (tools/yunit_fmoves.py): word 0 the game id, words 0x10-0x2F
// the finishing moves' fight variables, 0x30-0x34 the Hidden Items page's
// state word
reg  cfg1_dl_d = 1'b0;
wire cfg1_dl   = ioctl_download && ioctl_index == 16'd1;
always @(posedge clk_sys) cfg1_dl_d <= cfg1_dl;
wire        cfg1_start = cfg1_dl & ~cfg1_dl_d;
wire        cfg1_wr    = ioctl_wr && ioctl_index == 16'd1;
wire  [7:0] cfg1_word  = ioctl_addr[8:1];

wire        sec_ok, sec_fail, sec_when, sec_when_shi, sec_not_here;

secret_menu secret_menu
(
	.clk          (clk_sys),
	.reset        (reset),
	.frame        (osd_frame),
	.trigger      (status[16]),
	.game         (sec_ejb ? 2'd1 : (game_id == G_SHIMPACT) ? 2'd2 : (game_id == G_HIIMPACT) ? 2'd3 : 2'd0),
	.four_p       (dsw[7]),                // High Impact "Players" DIP (1 = 4 players)

	.dl_start     (cfg1_start),
	.dl_wr        (cfg1_wr && ioctl_addr[26:9] == 18'd0 && cfg1_word >= 8'h30 && cfg1_word <= 8'h34),
	.dl_addr      (3'(cfg1_word - 8'h30)),
	.dl_data      (ioctl_dout),

	.cpu_wr       (cpu_wr),
	.cpu_wa       (cpu_wa),
	.cpu_wd       (cpu_wd),

	.active       (sec_active),
	.in0          (sec_in0),
	.in1          (sec_in1),

	.ok           (sec_ok),
	.fail         (sec_fail),
	.when_attract (sec_when),
	.when_shi     (sec_when_shi),
	.not_here     (sec_not_here)
);

//////////////////////////////////////////////////////////////////
// Finishing moves (Mortal Kombat)
//
// The Finishing Moves page picks a fighter (O[30:28]; the menu mask's bits
// 8-10 show that fighter's lines) and one of its moves (R[32] the fatality,
// R[33] The Pit; R[40] clears the set move). (The main page's Move List,
// O[43:41], is a window over the picture: see Video.) rtl/yunit_fmoves.sv
// plays the set move at the winner's next FINISH HIM, following the fight
// through the CPU's accesses to the variables the MRA gives (ROM index 1
// words 0x10-0x2F).
//////////////////////////////////////////////////////////////////

reg   [8:0] fm_bits_d;
reg         fm_sel;
reg   [3:0] fm_slot;
wire        fm_msg_req;
wire  [4:0] fm_msg;

integer fi;
always @(posedge clk_sys) begin
	fm_bits_d <= status[40:32];
	fm_sel    <= 1'b0;
	for (fi = 8; fi >= 0; fi = fi - 1)
		if (status[32 + fi] & ~fm_bits_d[fi]) begin
			fm_sel  <= 1'b1;
			fm_slot <= (fi == 8) ? 4'd15 : fi[3:0];
		end
end

yunit_fmoves fmoves
(
	.clk       (clk_sys),
	.reset     (reset),
	.game_mk   (is_mk),

	.dl_start  (cfg1_start),
	.dl_wr     (cfg1_wr && ioctl_addr[26:9] == 18'd0 && cfg1_word >= 8'h10 && cfg1_word <= 8'h2F),
	.dl_addr   (5'(cfg1_word - 8'h10)),
	.dl_data   (ioctl_dout),

	.sel       (fm_sel),
	.sel_line  (status[30:28]),
	.sel_slot  (fm_slot),
	.frame     (osd_frame),

	.cpu_wr    (cpu_wr),
	.cpu_rd    (cpu_rd),
	.cpu_wa    (cpu_wa),
	.cpu_wd    (cpu_wd),
	.cpu_rdata (cpu_rdata),

	.drive     (fm_drive),
	.keys      (fm_keys),
	.msg_req   (fm_msg_req),
	.msg       (fm_msg)
);

//////////////////////////////////////////////////////////////////
// OSD messages (CONF_STR "I" line, rtl/yunit_fmoves_osd.svh)
//
// The finishing-move player's and the Hidden Items page's. Main_MiSTer shows
// a message for 2 s, and only with the OSD closed: messages wait in a set
// (lowest number first) and go out one every 2.2 s, starting 0.3 s after
// the OSD closes.
//////////////////////////////////////////////////////////////////

localparam [27:0] MSG_GAP   = 28'd211_200_000;     // 2.2 s at 96 MHz
localparam [27:0] MSG_DELAY = 28'd28_800_000;      // 0.3 s

reg  [31:1] msg_pend;
reg  [27:0] msg_timer;
reg         msg_out;
reg   [4:0] msg_num;             // the lowest waiting message
reg   [4:0] msg_num_q;           // the one going out

integer mi;
always @(*) begin
	msg_num = 5'd0;
	for (mi = 31; mi >= 1; mi = mi - 1)
		if (msg_pend[mi]) msg_num = mi[4:0];
end

always @(posedge clk_sys) begin
	msg_out <= 1'b0;

	if (fm_msg_req)   msg_pend[fm_msg] <= 1'b1;
	if (sec_ok)       msg_pend[sec_ejb ? MSG_EJB_OK : MSG_OCTO_OK] <= 1'b1;
	if (sec_fail)     msg_pend[MSG_CODE_FAIL] <= 1'b1;
	if (sec_when)     msg_pend[MSG_WHEN_ATTRACT] <= 1'b1;
	if (sec_when_shi) msg_pend[MSG_WHEN_SHI] <= 1'b1;
	if (sec_not_here) msg_pend[MSG_NOT_HERE] <= 1'b1;

	if (rom_download)
		msg_pend <= 31'd0;
	else if (OSD_STATUS) begin
		if (msg_timer < MSG_DELAY) msg_timer <= MSG_DELAY;
	end
	else if (msg_timer != 28'd0)
		msg_timer <= msg_timer - 28'd1;
	else if (msg_num != 5'd0) begin
		msg_out  <= 1'b1;
		msg_pend[msg_num] <= 1'b0;
		msg_timer <= MSG_GAP;
	end
end

always @(posedge clk_sys) if (!msg_out) msg_num_q <= msg_num;

assign info_req = msg_out;
assign info     = {3'd0, msg_num_q};

midway_yunit board
(
	.clk            (clk_sys),
	.reset          (reset),
	.pause          (pause),

	.cpu_speed      (cfg_speed),
	.bpp6           (cfg_bpp6),
	.prot_id        (cfg_prot),
	.t2_hack        (cfg_t2hack),
	.t2_adc         (is_t2),
	.t2_sound       (is_t2),
	.mk_turbo       (cfg_turbo),
	.flip_x         (is_t2),
	.vtiming        (status[15:14]),    // 54.7 / 57 / 60 Hz frames (see midway_yunit.sv)

	.in_ports       (in_ports),
	.gun_p1_x       (~gun_x[0]),
	.gun_p1_y       (gun_y[0]),
	.gun_p2_x       (~gun_x[1]),
	.gun_p2_y       (gun_y[1]),

	.snd_wr         (snd_wr),
	.snd_data       (snd_data),

	.cpu_sd_addr    (cpu_sd_addr),
	.cpu_sd_req     (cpu_sd_req),
	.cpu_sd_ack     (cpu_sd_ack),
	.cpu_sd_data    (cpu_sd_data),

	.dma_sd_addr    (dma_sd_addr),
	.dma_sd_req     (dma_sd_req),
	.dma_sd_ack     (dma_sd_ack),
	.dma_sd_data    (dma_sd_data),

	.ddr_busy       (DDRAM_BUSY),
	.ddr_burstcnt   (DDRAM_BURSTCNT),
	.ddr_addr       (DDRAM_ADDR),
	.ddr_dout       (DDRAM_DOUT),
	.ddr_dout_ready (DDRAM_DOUT_READY),
	.ddr_rd         (DDRAM_RD),
	.ddr_din        (DDRAM_DIN),
	.ddr_be         (DDRAM_BE),
	.ddr_we         (DDRAM_WE),

	.nv_addr        (nv_addr),
	.nv_we          (nv_we),
	.nv_din         (nv_din),
	.nv_dout        (nv_dout),
	.cmos_write     (cmos_write),

	.ce_pix         (ce_pix),
	.vid_r          (brd_r),
	.vid_g          (brd_g),
	.vid_b          (brd_b),
	.vid_hs         (core_hs),
	.vid_vs         (core_vs),
	.vid_hb         (core_hb),
	.vid_vb         (core_vb),

	.dbg_pc         (),
	.dbg_retire     (),
	.dbg_wr         (cpu_wr),
	.dbg_rd         (cpu_rd),
	.dbg_wa         (cpu_wa),
	.dbg_wdata      (cpu_wd),
	.dbg_rdata      (cpu_rdata)
);

assign DDRAM_CLK = clk_sys;

//////////////////////////////////////////////////////////////////
// Sound board
//////////////////////////////////////////////////////////////////

wire signed [15:0] audio;

williams_sound sound
(
	.clk        (clk_sys),
	.reset      (reset),
	.pause      (pause),

	.adpcm      (cfg_adpcm),
	.prot_mode  (cfg_sprot_mode),
	.prot_start (cfg_sprot_start),
	.prot_end   (cfg_sprot_end),

	.cmd_wr     (snd_wr),
	.cmd_data   (snd_data),
	.irq_state  (adpcm_irq),

	.rom_addr   (snd_sd_addr),
	.rom_req    (snd_sd_req),
	.rom_ack    (snd_sd_ack),
	.rom_data   (snd_sd_data),

	.oki_addr   (oki_sd_addr),
	.oki_req    (oki_sd_req),
	.oki_ack    (oki_sd_ack),
	.oki_data   (oki_sd_data),

	.audio      (audio)
);

assign AUDIO_L   = audio;
assign AUDIO_R   = audio;
assign AUDIO_S   = 1'b1;
assign AUDIO_MIX = 2'd0;

//////////////////////////////////////////////////////////////////
// SDRAM: sound CPU first (it cannot wait long), then the 34010, the
// blitter and the OKI; ROM downloads use the write port
//////////////////////////////////////////////////////////////////

sdram sdram
(
	.init        (~pll_locked),
	.clk         (clk_sys),

	.SDRAM_DQ    (SDRAM_DQ),
	.SDRAM_A     (SDRAM_A),
	.SDRAM_DQML  (SDRAM_DQML),
	.SDRAM_DQMH  (SDRAM_DQMH),
	.SDRAM_BA    (SDRAM_BA),
	.SDRAM_nCS   (SDRAM_nCS),
	.SDRAM_nWE   (SDRAM_nWE),
	.SDRAM_nRAS  (SDRAM_nRAS),
	.SDRAM_nCAS  (SDRAM_nCAS),
	.SDRAM_CKE   (SDRAM_CKE),
	.SDRAM_CLK   (SDRAM_CLK),

	.ch0_addr    (snd_sd_addr),
	.ch0_req     (snd_sd_req),
	.ch0_ack     (snd_sd_ack),
	.ch0_dout    (snd_sd_data),

	.ch1_addr    (cpu_sd_addr),
	.ch1_req     (cpu_sd_req),
	.ch1_ack     (cpu_sd_ack),
	.ch1_dout    (cpu_sd_data),

	.ch2_addr    (dma_sd_addr),
	.ch2_req     (dma_sd_req),
	.ch2_ack     (dma_sd_ack),
	.ch2_dout    (dma_sd_data),

	.ch3_addr    (oki_sd_addr),
	.ch3_req     (oki_sd_req),
	.ch3_ack     (oki_sd_ack),
	.ch3_dout    (oki_sd_data),

	.wr_addr     (sd_wr_addr),
	.wr_data     (sd_wr_data),
	.wr_be       (2'b11),
	.wr_req      (sd_wr_req),
	.wr_ack      (sd_wr_ack)
);

//////////////////////////////////////////////////////////////////
// Video
//////////////////////////////////////////////////////////////////

// beam position on the output, for the crosshair and CRT Adjust
reg  [9:0] out_x, out_y, act_w, act_h;
reg        hb_d, vb_d, hs_d;
always @(posedge clk_sys) begin
	if (ce_pix) begin
		hb_d <= core_hb;
		hs_d <= core_hs;
		if (!core_hb) out_x <= out_x + 10'd1;
		if (core_hb & ~hb_d) begin
			act_w <= out_x;
			out_x <= 10'd0;
			if (!core_vb) out_y <= out_y + 10'd1;
		end
		vb_d <= core_vb;
		if (core_vb & ~vb_d) begin
			act_h <= out_y;
			out_y <= 10'd0;
		end
	end
end

// T2 crosshairs: positions scaled from 0-255 to the active picture
reg  [17:0] ch_x0, ch_y0, ch_x1, ch_y1;
always @(posedge clk_sys) begin
	ch_x0 <= gun_x[0] * act_w;
	ch_y0 <= gun_y[0] * act_h;
	ch_x1 <= gun_x[1] * act_w;
	ch_y1 <= gun_y[1] * act_h;
end

function automatic xhair(input [9:0] x, input [9:0] y, input [9:0] cx, input [9:0] cy);
	xhair = ((x == cx) && (y + 10'd4 >= cy) && (y <= cy + 10'd4)) ||
	        ((y == cy) && (x + 10'd4 >= cx) && (x <= cx + 10'd4));
endfunction

wire ch_on0 = is_t2 && !xhair_off && xhair(out_x, out_y, ch_x0[17:8], ch_y0[17:8]);
wire ch_on1 = is_t2 && !xhair_off && xhair(out_x, out_y, ch_x1[17:8], ch_y1[17:8]);

// ---- Move List window (rtl/yunit_window.sv) ----
//
// Mortal Kombat's Move List (O[43:41]: Off, then a fighter in the Fighter
// option's order) draws that fighter's page over the game's dimmed title
// screen in place of the picture; the game waits behind it (pause above).

yunit_window yunit_window
(
	.clk     (clk_sys),
	.ce_pix  (ce_pix),
	.enable  (movelist_on),
	.page    (movelist_sel - 3'd1),

	.r_in    (brd_r),
	.g_in    (brd_g),
	.b_in    (brd_b),
	.hb_in   (core_hb),
	.vb_in   (core_vb),

	.r_out   (core_r),
	.g_out   (core_g),
	.b_out   (core_b)
);

// Black while the board is held in reset (a ROM or NVRAM download and the
// half second after it, OSD Reset): the video keeps scanning the frame store
// and palette, which still hold the previous game's picture
reg        vid_mute = 1'b1;
always @(posedge clk_sys) vid_mute <= reset;

wire [7:0] av_r = vid_mute ? 8'h00 : ch_on0 ? 8'hFF : ch_on1 ? 8'h00 : core_r;
wire [7:0] av_g = vid_mute ? 8'h00 : ch_on0 ? 8'h00 : ch_on1 ? 8'hFF : core_g;
wire [7:0] av_b = vid_mute ? 8'h00 : ch_on0 ? 8'h00 : ch_on1 ? 8'h00 : core_b;

// ---- analog CRT stage: centred sync, CRT V-Size, CRT Adjust, Auto-Width (rtl/video/yunit_crt.sv) ----
//
// The analog sync is always the centred one (picture in the middle of a
// standard 15 kHz line and frame); HDMI sees the same picture either way.
// CRT Adjust is off while a scandoubler effect is on (its read rate assumes
// native 15 kHz).

wire scandoubler = (status[5:3] != 3'd0) || forced_scandoubler;

wire       c_hs, c_vs;
wire       crt_on, rd_ce, de_osd;
wire [7:0] str_r, str_g, str_b;
wire       str_hs, str_vs;

yunit_crt yunit_crt
(
	.clk         (clk_sys),
	.ce_pix      (ce_pix),

	.crt_en      (status[101]),
	.autow       (status[102]),
	.scandoubler (scandoubler),
	.hsize_osd   (status[100:96]),
	.hpos_osd    (status[85:79]),
	.vshift_osd  (status[78:74]),
	.vsize_osd   (status[107:104]),
	.vsize_cab   (status[108]),

	.r_in        (av_r),
	.g_in        (av_g),
	.b_in        (av_b),
	.hs_in       (core_hs),
	.vs_in       (core_vs),
	.hb_in       (core_hb),
	.vb_in       (core_vb),

	.c_hs        (c_hs),
	.c_vs        (c_vs),

	.crt_on      (crt_on),
	.rd_ce       (rd_ce),
	.r_out       (str_r),
	.g_out       (str_g),
	.b_out       (str_b),
	.hs_out      (str_hs),
	.vs_out      (str_vs),
	.de_osd      (de_osd),

	.centred     (),
	.pic_dots    (),
	.h_eff       (),
	.str_act     ()
);

// ---- scandoubler / gamma (native stream) ----

wire [7:0] mix_r, mix_g, mix_b;
wire       mix_hs, mix_vs, mix_de;
wire [1:0] mix_sl;
wire       mix_ce;

arcade_video #(.WIDTH(512), .DW(24), .GAMMA(1)) arcade_video
(
	.clk_video          (clk_sys),
	.ce_pix             (ce_pix),

	.RGB_in             ({av_r, av_g, av_b}),
	.HBlank             (core_hb),
	.VBlank             (core_vb),
	.HSync              (c_hs),               // centred sync
	.VSync              (c_vs),

	.CLK_VIDEO          (CLK_VIDEO),
	.CE_PIXEL           (mix_ce),
	.VGA_R              (mix_r),
	.VGA_G              (mix_g),
	.VGA_B              (mix_b),
	.VGA_HS             (mix_hs),
	.VGA_VS             (mix_vs),
	.VGA_DE             (mix_de),
	.VGA_SL             (mix_sl),

	.fx                 (status[5:3]),
	.forced_scandoubler (forced_scandoubler),
	.gamma_bus          (gamma_bus)
);

assign CE_PIXEL = crt_on ? rd_ce  : mix_ce;
assign VGA_R    = crt_on ? str_r  : mix_r;
assign VGA_G    = crt_on ? str_g  : mix_g;
assign VGA_B    = crt_on ? str_b  : mix_b;
assign VGA_HS   = crt_on ? str_hs : mix_hs;
assign VGA_VS   = crt_on ? str_vs : mix_vs;
assign VGA_SL   = crt_on ? 2'd0   : mix_sl;

wire [1:0] ar = status[2:1];

video_freak video_freak
(
	.CLK_VIDEO   (CLK_VIDEO),
	.CE_PIXEL    (CE_PIXEL),
	.VGA_VS      (VGA_VS),
	.HDMI_WIDTH  (HDMI_WIDTH),
	.HDMI_HEIGHT (HDMI_HEIGHT),
	.VGA_DE      (VGA_DE),
	.VIDEO_ARX   (VIDEO_ARX),
	.VIDEO_ARY   (VIDEO_ARY),

	.VGA_DE_IN   (crt_on ? de_osd : mix_de),
	.ARX         ((ar == 2'd0) ? 12'd4 : ({10'd0, ar} - 12'd1)),
	.ARY         ((ar == 2'd0) ? 12'd3 : 12'd0),
	.CROP_SIZE   (12'd0),
	.CROP_OFF    (5'd0),
	.SCALE       ({1'b0, status[7:6]})
);

//////////////////////////////////////////////////////////////////

reg [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;
assign LED_USER = rom_download ? act_cnt[23] : 1'b0;

endmodule
