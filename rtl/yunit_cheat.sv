//============================================================================
//  Cheat engine for the Y Unit board
//
//  The MRA's <cheats size="8" max="16"> section holds one hex string per
//  cheat, one or more 8-byte units each. Main_MiSTer sends the units of every
//  enabled cheat in one transfer (ioctl index 255) each time a cheat is
//  switched in the Cheats menu: the whole table is replaced. A unit is four
//  16-bit words (the bytes of each word low byte first, as in the MRA):
//
//    word 0   word address [15:0]   (CPU bit address >> 4)
//    word 1   bit 15: poke (one-shot write); bits 11:0: word address [27:16]
//    word 2   data
//    word 3   mask: the bits of the word the cheat controls
//
//  Reads. While a cheat is on, every CPU read of its word returns
//  (game word & ~mask) | (data & mask), so a cheat can change one byte or a
//  few bits and leave the rest of the word to the game. Entries on main RAM
//  (0x01000000-0x010FFFFF) act on any read. Entries on the program ROM
//  (0xFF800000 up) act on instruction fetches only (the CPU's PC is the word
//  read or up to two words before it, for immediates), so the games' ROM
//  checksums, which read the ROM as data, still see the ROM unchanged. Units
//  that hit the same word are ORed; cheats should not overlap.
//
//  Pokes. A unit with the poke flag writes (word & ~mask) | data to main RAM
//  once, when it first appears in a transfer. Main_MiSTer re-sends all
//  enabled cheats whenever any cheat is toggled, so the unit is compared with
//  the pokes of the previous transfer and only a new one fires. The write
//  waits for a bus cycle in which the CPU does not use main RAM.
//
//  Capacity: N read units and NP pokes; more are dropped and `ovf` is set.
//  A new ROM download (`clr`) forgets everything. `en` low (the test menu is
//  selected) switches reads and pokes off without losing the table.
//============================================================================

module yunit_cheat #(parameter N = 16, parameter NP = 4)
(
	input             clk,
	input             reset,          // board reset: no pokes
	input             clr,            // ROM download: forget the table
	input             en,

	// transfer (ioctl index 255, 16-bit words)
	input             dl,
	input             dl_wr,
	input      [25:0] dl_wi,          // word index = ioctl_addr[26:1]
	input      [15:0] dl_data,

	// read side: registered bus word address and the instruction-fetch flag
	input      [27:0] wa,
	input             fetch,
	output reg [15:0] ch_mask,
	output reg [15:0] ch_data,

	// poke side
	input             bus_free,       // no CPU access in progress or pending
	input      [15:0] ram_q,          // main RAM read data (one clock after pk_rd)
	output            pk_rd,          // read pk_wa now (main RAM address override)
	output     [15:0] pk_wa,
	output            pk_we,          // write pk_wd to pk_wa this clock
	output     [15:0] pk_wd,

	output reg        ovf,            // a transfer had more units than the table holds
	output reg  [5:0] units           // units held (reads + pokes)
);

//----------------------------------------------------------------------------
// Tables
//----------------------------------------------------------------------------

reg  [27:0] e_addr [0:N-1];
reg  [15:0] e_data [0:N-1];
reg  [15:0] e_mask [0:N-1];
reg [N-1:0] e_valid;
reg [N-1:0] e_rom;
reg [N-1:0] e_hit;

reg  [27:0] p_addr [0:NP-1];
reg  [15:0] p_data [0:NP-1];
reg  [15:0] p_mask [0:NP-1];
reg [NP-1:0] p_valid;
// the pokes of the previous transfer (to tell a new poke from a re-sent one)
reg  [27:0] q_addr [0:NP-1];
reg  [15:0] q_data [0:NP-1];
reg  [15:0] q_mask [0:NP-1];
reg [NP-1:0] q_valid;
reg [NP-1:0] p_pend;

//----------------------------------------------------------------------------
// Transfer
//----------------------------------------------------------------------------

reg   [1:0] pj;                      // poke being written
reg         pk_done;
reg         dl_d;
reg  [15:0] s0, s1, s2;
reg   [5:0] ne;                      // read units taken in this transfer
reg   [3:0] np;                      // pokes taken
reg         cmp_go;
reg  [NP*NP-1:0] same;               // new poke j equals old poke i

wire [1:0]  w = dl_wi[1:0];
wire [27:0] u_addr = {s1[11:0], s0};
wire [15:0] u_mask = dl_data;
wire [15:0] u_data = s2 & dl_data;
wire        u_poke = s1[15];

integer i, j;
always @(posedge clk) begin
	dl_d   <= dl;
	cmp_go <= 1'b0;

	if (clr) begin
		e_valid <= {N{1'b0}};
		p_valid <= {NP{1'b0}};
		q_valid <= {NP{1'b0}};
		p_pend  <= {NP{1'b0}};
		ne      <= 6'd0;
		np      <= 4'd0;
		ovf     <= 1'b0;
	end
	else begin
		// a new transfer replaces the table
		if (dl && !dl_d) begin
			e_valid <= {N{1'b0}};
			q_valid <= p_valid;
			for (i = 0; i < NP; i = i + 1) begin
				q_addr[i] <= p_addr[i];
				q_data[i] <= p_data[i];
				q_mask[i] <= p_mask[i];
			end
			p_valid <= {NP{1'b0}};
			p_pend  <= {NP{1'b0}};
			ne      <= 6'd0;
			np      <= 4'd0;
			ovf     <= 1'b0;
		end

		if (dl && dl_wr) begin
			case (w)
				2'd0: s0 <= dl_data;
				2'd1: s1 <= dl_data;
				2'd2: s2 <= dl_data;
				default: begin
					// fourth word: the unit is complete
					if (u_poke) begin
						if (np < NP) begin
							p_addr[np[1:0]]  <= u_addr;
							p_data[np[1:0]]  <= u_data;
							p_mask[np[1:0]]  <= u_mask;
							p_valid[np[1:0]] <= 1'b1;
							np <= np + 4'd1;
						end
						else ovf <= 1'b1;
					end
					else begin
						if (ne < N) begin
							e_addr[ne[3:0]]  <= u_addr;
							e_data[ne[3:0]]  <= u_data;
							e_mask[ne[3:0]]  <= u_mask;
							e_rom[ne[3:0]]   <= (u_addr[27:19] == 9'h1FF);
							e_valid[ne[3:0]] <= 1'b1;
							ne <= ne + 6'd1;
						end
						else ovf <= 1'b1;
					end
				end
			endcase
		end

		// end of the transfer: which pokes are new
		if (!dl && dl_d) begin
			for (j = 0; j < NP; j = j + 1)
				for (i = 0; i < NP; i = i + 1)
					same[j*NP + i] <= q_valid[i] && p_valid[j] &&
					                  q_addr[i] == p_addr[j] && q_data[i] == p_data[j] &&
					                  q_mask[i] == p_mask[j];
			cmp_go <= 1'b1;
		end
		if (cmp_go) begin
			for (j = 0; j < NP; j = j + 1)
				p_pend[j] <= p_valid[j] && !(|same[j*NP +: NP]);
		end

		// poke done
		if (pk_done)
			p_pend[pj] <= 1'b0;
	end

	units <= ne[5:0] + {2'b00, np};
end

//----------------------------------------------------------------------------
// Read side: the match is registered from the bus address (as the board's
// program ROM patches are) and the combine follows it
//----------------------------------------------------------------------------

integer k;
always @(posedge clk) begin
	for (k = 0; k < N; k = k + 1)
		e_hit[k] <= en && e_valid[k] && (wa == e_addr[k]) && (!e_rom[k] || fetch);
end

integer m;
always @(*) begin
	ch_mask = 16'h0000;
	ch_data = 16'h0000;
	for (m = 0; m < N; m = m + 1)
		if (e_hit[m]) begin
			ch_mask = ch_mask | e_mask[m];
			ch_data = ch_data | e_data[m];
		end
end

//----------------------------------------------------------------------------
// Pokes: read the word, write the merged word, both in clocks the CPU leaves
// main RAM alone; a CPU access appearing in between sends the poke back to
// the read.
//----------------------------------------------------------------------------

localparam PK_IDLE = 2'd0, PK_RD = 2'd1, PK_WR = 2'd2;

reg   [1:0] pk_st;

wire        pk_go   = en && !reset && bus_free;
wire        pend_any = |p_pend;
wire [1:0]  pend_first = p_pend[0] ? 2'd0 : p_pend[1] ? 2'd1 : p_pend[2] ? 2'd2 : 2'd3;

assign pk_rd = (pk_st == PK_RD) && pk_go;
assign pk_wa = p_addr[pj][15:0];
assign pk_we = (pk_st == PK_WR) && pk_go;
assign pk_wd = (ram_q & ~p_mask[pj]) | p_data[pj];

always @(posedge clk) begin
	pk_done <= 1'b0;
	if (clr || reset)
		pk_st <= PK_IDLE;
	else case (pk_st)
		PK_IDLE: if (pend_any && en && !pk_done) begin
			pj <= pend_first;
			if (p_addr[pend_first][27:16] == 12'h010)
				pk_st <= PK_RD;
			else
				pk_done <= 1'b1;      // not main RAM: drop it
		end
		PK_RD: if (!en)
			pk_st <= PK_IDLE;
		else if (pk_go)
			pk_st <= PK_WR;
		PK_WR: if (!en)
			pk_st <= PK_IDLE;
		else if (pk_go) begin
			pk_done <= 1'b1;
			pk_st   <= PK_IDLE;
		end
		else
			pk_st <= PK_RD;
		default: pk_st <= PK_IDLE;
	endcase
end

endmodule
