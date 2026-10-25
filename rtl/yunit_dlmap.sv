//============================================================================
//  ROM download -> SDRAM write channel
//
//  Takes the words of the ROM transfer (MRA index 0) and writes them to the
//  SDRAM. Everything lands at the byte address it has in the MRA, except the
//  graphics (MRA 0x100000-0x8FFFFF, MAME's "gfx" region), whose four 2 MB
//  chunks are interleaved per 16-bit word so one SDRAM line holds every
//  plane of 8 pixels (see the layout comment in Arcade-Midway-Y-Unit.sv).
//
//  Mortal Kombat "Victor bootleg of rev 3.0" (mkla3bl) ships its graphics
//  in three 2 MB files that MAME's init_mkla3bl rearranges into the normal
//  order: the bytes of the first two files alternate between two ROMs each
//
//     file  even byte (a-x)             odd byte (b-x)
//     m1-a  gfx 0x300000 + n  (a-2)     gfx 0x100000 + n  (b-2)
//     m1-b  gfx 0x200000 + n  (a-1)     gfx 0x000000 + n  (b-1)
//     m1-c  gfx 0x400000 + n  (c-1, c-2 in two halves; already in order)
//
//  With bl_gfx set, a word of the first two files is written as two single
//  byte writes (the SDRAM write port has byte enables) to the places those
//  bytes have in the normal order, so the game sees the graphics MAME gives
//  it. The ROM transfer waits (busy) until both writes are done.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_dlmap
(
	input             clk,
	input             bl_gfx,        // mkla3bl: unscramble the graphics

	input             wr,            // one clock: a word of the ROM transfer
	input      [26:0] addr,          // its byte address (even)
	input      [15:0] din,

	output reg [24:1] sd_addr,       // SDRAM write channel (level req/ack)
	output reg [15:0] sd_data,
	output reg  [1:0] sd_be,
	output reg        sd_req,
	input             sd_ack,

	output reg        busy           // hold the transfer (ioctl_wait)
);

// graphics: byte offset in the region, and the SDRAM address of a byte of it
wire [24:0] off  = addr[24:0] - 25'h010_0000;
wire        gfx  = (addr[26:20] >= 7'h01) && (addr[26:20] < 7'h09);
wire [24:0] sdb  = gfx ? (25'h010_0000 + {2'b00, off[20:1], off[22:21], 1'b0}) : addr[24:0];

// unscrambled files: MRA 0x100000-0x4FFFFF = m1-a (off[21] = 0) then m1-b
wire        scr  = bl_gfx && (addr[26:20] >= 7'h01) && (addr[26:20] <= 7'h04);
wire        fb   = off[21];
wire [19:0] n    = off[20:1];                        // word number in the file

// the graphics offsets g of the even byte (gl) and the odd byte (gh):
//   m1-a: 0x300000 + n, 0x100000 + n     m1-b: 0x200000 + n, n
wire [22:0] gl   = {2'b01, ~fb, n};
wire [22:0] gh   = {2'b00, ~fb, n};
wire [24:1] wl   = 24'h08_0000 + {1'b0, gl[20:1], gl[22:21]};   // SDRAM word of gl
wire [24:1] wh   = 24'h08_0000 + {1'b0, gh[20:1], gh[22:21]};   // SDRAM word of gh
wire  [1:0] lane = n[0] ? 2'b10 : 2'b01;                       // gl[0] = gh[0] = n[0]

reg         pend = 1'b0;                             // the odd byte still to write
reg [24:1]  pend_addr;
reg  [7:0]  pend_byte;

always @(posedge clk) begin
	if (wr) begin
		if (scr) begin
			sd_addr   <= wl;
			sd_data   <= {din[7:0], din[7:0]};
			sd_be     <= lane;
			pend      <= 1'b1;
			pend_addr <= wh;
			pend_byte <= din[15:8];
		end
		else begin
			sd_addr   <= sdb[24:1];
			sd_data   <= din;
			sd_be     <= 2'b11;
		end
		sd_req <= ~sd_req;
		busy   <= 1'b1;
	end
	else if (pend) begin
		if (sd_req == sd_ack) begin                  // the first byte is in
			sd_addr <= pend_addr;
			sd_data <= {pend_byte, pend_byte};
			sd_req  <= ~sd_req;
			pend    <= 1'b0;
		end
	end
	else if (sd_req == sd_ack)
		busy <= 1'b0;
end

endmodule
