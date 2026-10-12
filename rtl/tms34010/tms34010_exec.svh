//============================================================================
//  TMS34010 instruction execution (included inside the S_EXEC state)
//
//  Each class runs as a short sequence keyed by `step`. A memory access is
//  started with fu_read/fu_write (or srt_go) and the sequencer pauses until it
//  completes; the next step then sees the result in fu_q. Finishing an
//  instruction means setting `cycles` (MAME's count) and moving to S_DONE.
//
//  Register operands were latched at decode (rs_v/rd_v, indices rs_i/rd_i).
//  Writes to a register chosen by the opcode go through rf_wr() (two write
//  ports, the second request wins); fixed registers (SP, B-file graphics
//  registers) are written directly. Where an instruction reads and writes the
//  same register, the ordering below reproduces what MAME does for Rs == Rd.
//
//  Shared sub-sequences:
//    steps 16-17 : pixel read  (result in fu_q, continue at step 18)
//    steps 20-23 : pixel write (pw_addr / pw_data, then done with `cycles`;
//                  a raster op reads the destination, combines it in step 21
//                  and writes in step 23)
//    steps 24-27 : push / pop helpers are inlined per instruction instead
//============================================================================

case (cls)

	//------------------------------------------------------------------
	// no-ops and status
	//------------------------------------------------------------------
	I_UNIMPL, I_NOP: begin
		cycles <= 24'd1;
		state  <= S_DONE;
	end

	I_EMU: begin
		cycles <= 24'd6;
		state  <= S_DONE;
	end

	I_REV: begin
		rf_wr(rd_i, 32'd8);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_CLRC, I_SETC: begin
		st[ST_C] <= (cls == I_SETC);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_DINT, I_EINT: begin
		st[ST_IE] <= (cls == I_EINT);
		cycles    <= 24'd3;
		state     <= S_DONE;
	end

	I_GETST: begin
		rf_wr(rd_i, st);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_PUTST: begin
		st     <= rd_v;
		cycles <= 24'd3;
		state  <= S_DONE;
	end

	I_SETF: begin
		if (fbit) st[11:6] <= ir[5:0];
		else      st[5:0]  <= ir[5:0];
		cycles <= fbit ? 24'd2 : 24'd1;
		state  <= S_DONE;
	end

	I_EXGF: begin
		rf_wr(rd_i, {26'd0, fbit ? st[11:6] : st[5:0]});
		if (fbit) st[11:6] <= rd_v[5:0];
		else      st[5:0]  <= rd_v[5:0];
		cycles <= 24'd1;
		state  <= S_DONE;
	end

	//------------------------------------------------------------------
	// program counter
	//------------------------------------------------------------------
	I_GETPC: begin
		rf_wr(rd_i, pc);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_EXGPC: begin
		rf_wr(rd_i, pc);
		pc       <= rd_v & 32'hFFFF_FFF0;
		cycles   <= 24'd2;
		state    <= S_DONE;
	end

	I_JUMP: begin
		pc     <= rd_v & 32'hFFFF_FFF0;
		cycles <= 24'd2;
		state  <= S_DONE;
	end

	I_JX: begin
		if (cond_true) pc <= pc + d8s;
		cycles <= cond_true ? 24'd2 : 24'd1;
		state  <= S_DONE;
	end

	I_J0: begin
		if (disp8 != 8'h00) begin
			if (cond_true) pc <= pc + d8s;
			cycles <= cond_true ? 24'd2 : 24'd1;
		end
		else begin
			// 16-bit displacement, relative to the word after it
			if (cond_true) pc <= pc + {w0s[27:0], 4'd0};
			cycles <= cond_true ? 24'd3 : 24'd2;
		end
		state <= S_DONE;
	end

	I_J8: begin
		if (disp8 != 8'h80) begin
			if (cond_true) pc <= pc + d8s;
			cycles <= cond_true ? 24'd2 : 24'd1;
		end
		else begin
			// absolute jump
			if (cond_true) pc <= long1 & 32'hFFFF_FFF0;
			cycles <= cond_true ? 24'd3 : 24'd4;
		end
		state <= S_DONE;
	end

	I_DSJ, I_DSJEQ, I_DSJNE: begin
		if ((cls == I_DSJ) || ((cls == I_DSJEQ) && f_z) || ((cls == I_DSJNE) && !f_z)) begin
			rf_wr(rd_i, rd_v - 32'd1);
			if (rd_v != 32'd1) begin
				pc     <= pc + {w0s[27:0], 4'd0};
				cycles <= 24'd3;
			end
			else
				cycles <= 24'd2;
		end
		else
			cycles <= 24'd2;
		state <= S_DONE;
	end

	I_DSJS: begin
		rf_wr(rd_i, rd_v - 32'd1);
		if (rd_v != 32'd1) begin
			pc     <= ir[10] ? (pc - {23'd0, kfld, 4'd0}) : (pc + {23'd0, kfld, 4'd0});
			cycles <= 24'd2;
		end
		else
			cycles <= 24'd3;
		state <= S_DONE;
	end

	//------------------------------------------------------------------
	// calls, returns, traps (PUSH = SP -= 32 then write; POP = read then SP += 32)
	//------------------------------------------------------------------
	I_CALL, I_CALLR, I_CALLA: begin
		case (step)
			5'd0: begin
				rf[15] <= rf[15] - 32'd32;
				fu_write(rf[15] - 32'd32, 6'd32, pc);
				step <= 5'd1;
			end
			default: begin
				case (cls)
					// CALL reads Rd after the push, so CALL SP lands on the new SP
					I_CALL:  begin pc <= rf[rd_i] & 32'hFFFF_FFF0;    cycles <= 24'd3; end
					I_CALLR: begin pc <= pc + {w0s[27:0], 4'd0};      cycles <= 24'd3; end
					default: begin pc <= long1 & 32'hFFFF_FFF0;       cycles <= 24'd4; end
				endcase
				state <= S_DONE;
			end
		endcase
	end

	I_PUSHST: begin
		case (step)
			5'd0: begin
				rf[15] <= rf[15] - 32'd32;
				fu_write(rf[15] - 32'd32, 6'd32, st);
				step <= 5'd1;
			end
			default: begin
				cycles <= 24'd2;
				state  <= S_DONE;
			end
		endcase
	end

	I_POPST: begin
		case (step)
			5'd0: begin
				fu_read(rf[15], 6'd32, 1'b0);
				step <= 5'd1;
			end
			default: begin
				rf[15] <= rf[15] + 32'd32;
				st     <= fu_q;
				cycles <= 24'd8;
				state  <= S_DONE;
			end
		endcase
	end

	I_RETS: begin
		case (step)
			5'd0: begin
				fu_read(rf[15], 6'd32, 1'b0);
				step <= 5'd1;
			end
			default: begin
				pc     <= fu_q & 32'hFFFF_FFF0;
				rf[15] <= rf[15] + 32'd32 + {23'd0, ir[4:0], 4'd0};
				cycles <= 24'd7;
				state  <= S_DONE;
			end
		endcase
	end

	I_RETI: begin
		case (step)
			5'd0: begin
				fu_read(rf[15], 6'd32, 1'b0);
				step <= 5'd1;
			end
			5'd1: begin
				t0     <= fu_q;                       // ST
				rf[15] <= rf[15] + 32'd32;
				fu_read(rf[15] + 32'd32, 6'd32, 1'b0);
				step   <= 5'd2;
			end
			default: begin
				rf[15] <= rf[15] + 32'd32;
				pc     <= fu_q & 32'hFFFF_FFF0;
				st     <= t0;
				cycles <= 24'd11;
				state  <= S_DONE;
			end
		endcase
	end

	I_TRAP, I_ILLOP: begin
		// TRAP 0 is the reset vector and does not stack anything
		case (step)
			5'd0: begin
				if ((cls == I_TRAP) && (ir[4:0] == 5'd0))
					step <= 5'd2;
				else begin
					rf[15] <= rf[15] - 32'd32;
					fu_write(rf[15] - 32'd32, 6'd32, pc);
					step <= 5'd1;
				end
			end
			5'd1: begin
				rf[15] <= rf[15] - 32'd32;
				fu_write(rf[15] - 32'd32, 6'd32, st);
				step <= 5'd2;
			end
			5'd2: begin
				st <= 32'h0000_0010;
				if (cls == I_TRAP)
					fu_read(32'hFFFF_FFE0 - {22'd0, ir[4:0], 5'd0}, 6'd32, 1'b0);
				else
					fu_read(32'hFFFF_FC20, 6'd32, 1'b0);
				step <= 5'd3;
			end
			default: begin
				pc     <= (cls == I_TRAP) ? (fu_q & 32'hFFFF_FFF0) : fu_q;
				cycles <= 24'd16;
				state  <= S_DONE;
			end
		endcase
	end

	I_MMTM: begin
		// registers 0..15 of the selected file, list bit 15 = register 0
		case (step)
			5'd0: begin
				mlist  <= imm[0];
				mreg   <= 5'd0;
				t0     <= rd_v;          // running pointer
				cycles <= 24'd2;
				step   <= 5'd1;
			end
			5'd1: begin
				if (mreg == 5'd16) begin
					rf_wr(rd_i, t0);
					state    <= S_DONE;
				end
				else if (mlist[15]) begin
					// the stored value of the pointer itself is the decremented one
					t0       <= t0 - 32'd32;
					rf_wr(rd_i, t0 - 32'd32);
					fu_write(t0 - 32'd32, 6'd32,
					         (ridx(ir[4], mreg[3:0]) == rd_i) ? (t0 - 32'd32) : rf[ridx(ir[4], mreg[3:0])]);
					cycles <= cycles + 24'd4;
					mlist  <= {mlist[14:0], 1'b0};
					mreg   <= mreg + 5'd1;
				end
				else begin
					mlist <= {mlist[14:0], 1'b0};
					mreg  <= mreg + 5'd1;
				end
			end
			default: state <= S_DONE;
		endcase
	end

	I_MMFM: begin
		// registers 15..0 of the selected file, list bit 15 = register 15
		case (step)
			5'd0: begin
				mlist  <= imm[0];
				mreg   <= 5'd15;
				t0     <= rd_v;
				cycles <= 24'd3;
				step   <= 5'd1;
			end
			5'd1: begin
				if (mreg == 5'd31) begin
					state <= S_DONE;
				end
				else if (mlist[15]) begin
					fu_read(t0, 6'd32, 1'b0);
					step <= 5'd2;
				end
				else begin
					mlist <= {mlist[14:0], 1'b0};
					mreg  <= mreg - 5'd1;
				end
			end
			default: begin
				// load the register, then advance the pointer (which wins if they are the same)
				rf_wr(ridx(ir[4], mreg[3:0]), fu_q);
				if (ridx(ir[4], mreg[3:0]) == rd_i) begin
					rf_wr(rd_i, fu_q + 32'd32);
					t0       <= fu_q + 32'd32;
				end
				else begin
					rf_wr(rd_i, t0 + 32'd32);
					t0       <= t0 + 32'd32;
				end
				cycles <= cycles + 24'd4;
				mlist  <= {mlist[14:0], 1'b0};
				mreg   <= mreg - 5'd1;
				step   <= 5'd1;
			end
		endcase
	end

	//------------------------------------------------------------------
	// register arithmetic
	//------------------------------------------------------------------
	I_ADD, I_ADDC, I_ADDK, I_ADDI_W, I_ADDI_L: begin
		case (cls)
			I_ADD:    begin ba = rs_v;  bb = rs_v + rd_v;          cycles <= 24'd1; end
			I_ADDC:   begin ba = rs_v;  bb = rs_v + rd_v + {31'd0, f_c}; cycles <= 24'd1; end
			I_ADDK:   begin ba = kval;  bb = kval + rd_v;          cycles <= 24'd1; end
			I_ADDI_W: begin ba = w0s;   bb = w0s + rd_v;           cycles <= 24'd2; end
			default:  begin ba = long1; bb = long1 + rd_v;         cycles <= 24'd3; end
		endcase
		rf_wr(rd_i, bb);
		{st[ST_N], st[ST_C], st[ST_Z], st[ST_V]} <= f_add(ba, rd_v, bb);
		state <= S_DONE;
	end

	I_SUB, I_SUBB, I_SUBK, I_SUBI_W, I_SUBI_L, I_CMP, I_CMPI_W, I_CMPI_L: begin
		case (cls)
			I_SUB:    begin ba = rs_v;    cycles <= 24'd1; end
			I_SUBB:   begin ba = rs_v;    cycles <= 24'd1; end
			I_SUBK:   begin ba = kval;    cycles <= 24'd1; end
			I_SUBI_W: begin ba = ~w0s;    cycles <= 24'd2; end
			I_SUBI_L: begin ba = ~long1;  cycles <= 24'd3; end
			I_CMP:    begin ba = rs_v;    cycles <= 24'd1; end
			I_CMPI_W: begin ba = ~w0s;    cycles <= 24'd2; end
			default:  begin ba = ~long1;  cycles <= 24'd3; end
		endcase
		bb = rd_v - ba - ((cls == I_SUBB) ? {31'd0, f_c} : 32'd0);
		if ((cls != I_CMP) && (cls != I_CMPI_W) && (cls != I_CMPI_L))
			rf_wr(rd_i, bb);
		{st[ST_N], st[ST_C], st[ST_Z], st[ST_V]} <= f_sub(rd_v, ba, bb);
		state <= S_DONE;
	end

	I_NEG, I_NEGB: begin
		ba = rd_v + ((cls == I_NEGB) ? {31'd0, f_c} : 32'd0);
		bb = 32'd0 - ba;
		rf_wr(rd_i, bb);
		{st[ST_N], st[ST_C], st[ST_Z], st[ST_V]} <= f_sub(32'd0, ba, bb);
		cycles <= 24'd1;
		state  <= S_DONE;
	end

	I_ABS: begin
		bb = 32'd0 - rd_v;
		if ($signed(bb) > 0)
			rf_wr(rd_i, bb);
		st[ST_N] <= bb[31];
		st[ST_Z] <= (bb == 32'd0);
		st[ST_V] <= (bb == 32'h8000_0000);
		cycles <= 24'd1;
		state  <= S_DONE;
	end

	I_AND, I_ANDN, I_OR, I_XOR, I_NOT, I_ANDI, I_ORI, I_XORI: begin
		case (cls)
			I_AND:   begin bb = rd_v & rs_v;   cycles <= 24'd1; end
			I_ANDN:  begin bb = rd_v & ~rs_v;  cycles <= 24'd1; end
			I_OR:    begin bb = rd_v | rs_v;   cycles <= 24'd1; end
			I_XOR:   begin bb = rd_v ^ rs_v;   cycles <= 24'd1; end
			I_NOT:   begin bb = ~rd_v;         cycles <= 24'd1; end
			I_ANDI:  begin bb = rd_v & ~long1; cycles <= 24'd3; end
			I_ORI:   begin bb = rd_v | long1;  cycles <= 24'd3; end
			default: begin bb = rd_v ^ long1;  cycles <= 24'd3; end
		endcase
		rf_wr(rd_i, bb);
		st[ST_Z] <= (bb == 32'd0);
		state    <= S_DONE;
	end

	I_MOVE_RR, I_MOVE_RR_AX, I_MOVE_RR_BX, I_MOVI_W, I_MOVI_L: begin
		case (cls)
			I_MOVI_W: begin bb = w0s;   cycles <= 24'd2; end
			I_MOVI_L: begin bb = long1; cycles <= 24'd3; end
			default:  begin bb = rs_v;  cycles <= 24'd1; end
		endcase
		rf_wr(rd_i, bb);
		st[ST_N] <= bb[31];
		st[ST_Z] <= (bb == 32'd0);
		st[ST_V] <= 1'b0;
		state    <= S_DONE;
	end

	I_MOVK: begin
		rf_wr(rd_i, kval);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_BTST_K, I_BTST_R: begin
		st[ST_Z] <= ~rd_v[(cls == I_BTST_K) ? (5'd31 - kfld) : rs_v[4:0]];
		cycles   <= (cls == I_BTST_K) ? 24'd1 : 24'd2;
		state    <= S_DONE;
	end

	I_SEXT: begin
		bb = sext_fs(rd_v, fs);
		rf_wr(rd_i, bb);
		st[ST_N] <= bb[31];
		st[ST_Z] <= (bb == 32'd0);
		cycles   <= 24'd3;
		state    <= S_DONE;
	end

	I_ZEXT: begin
		bb = zext_fs(rd_v, fs);
		rf_wr(rd_i, bb);
		st[ST_Z] <= (bb == 32'd0);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_LMO: begin
		rf_wr(rd_i, lmo(rs_v));
		st[ST_Z] <= (rs_v == 32'd0);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	//------------------------------------------------------------------
	// shifts and rotate
	//------------------------------------------------------------------
	I_SLA_K, I_SLA_R: begin
		bb = (sh_kl != 5'd0) ? sll_res : rd_v;
		rf_wr(rd_i, bb);
		st[ST_N] <= bb[31];
		st[ST_Z] <= (bb == 32'd0);
		st[ST_C] <= sll_c;
		st[ST_V] <= sla_v;
		cycles   <= 24'd3;
		state    <= S_DONE;
	end

	I_SLL_K, I_SLL_R: begin
		bb = (sh_kl != 5'd0) ? sll_res : rd_v;
		rf_wr(rd_i, bb);
		st[ST_Z] <= (bb == 32'd0);
		st[ST_C] <= sll_c;
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_SRA_K, I_SRA_R: begin
		bb = (sh_kr != 5'd0) ? sra_res : rd_v;
		rf_wr(rd_i, bb);
		st[ST_N] <= bb[31];
		st[ST_Z] <= (bb == 32'd0);
		st[ST_C] <= srl_c;
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_SRL_K, I_SRL_R: begin
		bb = (sh_kr != 5'd0) ? srl_res : rd_v;
		rf_wr(rd_i, bb);
		st[ST_Z] <= (bb == 32'd0);
		st[ST_C] <= srl_c;
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_RL_K, I_RL_R: begin
		rf_wr(rd_i, rl_res);
		st[ST_Z] <= (rl_res == 32'd0);
		st[ST_C] <= sll_c;
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	//------------------------------------------------------------------
	// multiply / divide
	//------------------------------------------------------------------
	I_MPYS, I_MPYU, I_DIVS, I_DIVU, I_MODS, I_MODU: begin
		case (step)
			5'd0: begin
				md_start <= 1'b1;
				md_bhi   <= rd_v;
				md_blo   <= rf[ridx(ir[4], ir[3:0] + 4'd1)];
				md_a     <= rs_v;
				case (cls)
					I_MPYS: begin md_op <= 3'd0; md_a <= sext_fs(rs_v, st[10:6]); end
					I_MPYU: begin md_op <= 3'd1; md_a <= zext_fs(rs_v, st[10:6]); end
					I_DIVS: md_op <= ir[0] ? 3'd4 : 3'd2;
					I_DIVU: md_op <= ir[0] ? 3'd5 : 3'd3;
					I_MODS: md_op <= 3'd6;
					default: md_op <= 3'd7;
				endcase
				wait_md <= 1'b1;
				step    <= 5'd1;
			end
			default: begin
				case (cls)
					I_MPYS, I_MPYU: begin
						// high word to Rd, low word to Rd|1 (the same register if Rd is odd)
						rf_wr(rd_i, md_hi);
						rf_wr(ridx(ir[4], ir[3:0] | 4'd1), md_lo);
						st[ST_Z] <= ({md_hi, md_lo} == 64'd0);
						if (cls == I_MPYS) st[ST_N] <= md_hi[31];
						cycles <= (cls == I_MPYS) ? 24'd20 : 24'd21;
					end
					I_DIVS, I_DIVU: begin
						if (cls == I_DIVS) st[ST_N] <= 1'b0;
						st[ST_Z] <= 1'b0;
						st[ST_V] <= 1'b0;
						if (md_zero || md_ovf)
							st[ST_V] <= 1'b1;
						else begin
							rf_wr(rd_i, md_hi);
							if (!ir[0]) rf_wr(ridx(ir[4], ir[3:0] + 4'd1), md_lo);
							st[ST_Z] <= (md_hi == 32'd0);
							if (cls == I_DIVS) st[ST_N] <= md_hi[31];
						end
						cycles <= (cls == I_DIVU) ? 24'd37 : (ir[0] ? 24'd39 : 24'd40);
					end
					default: begin
						// MODS / MODU
						if (cls == I_MODS) st[ST_N] <= 1'b0;
						st[ST_Z] <= 1'b0;
						st[ST_V] <= 1'b0;
						if (md_zero)
							st[ST_V] <= 1'b1;
						else begin
							rf_wr(rd_i, md_hi);
							st[ST_Z] <= (md_hi == 32'd0);
							if (cls == I_MODS) st[ST_N] <= md_hi[31];
						end
						cycles <= (cls == I_MODS) ? 24'd40 : 24'd35;
					end
				endcase
				state <= S_DONE;
			end
		endcase
	end

	//------------------------------------------------------------------
	// XY arithmetic
	//------------------------------------------------------------------
	I_ADD_XY: begin
		rf_wr(rd_i, {addy, addx});
		st[ST_N] <= (addx == 16'd0);
		st[ST_C] <= addy[15];
		st[ST_Z] <= (addy == 16'd0);
		st[ST_V] <= addx[15];
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_SUB_XY: begin
		rf_wr(rd_i, {suby, subx});
		st[ST_N] <= (xs == xd);
		st[ST_C] <= ($signed(ys) > $signed(yd));
		st[ST_Z] <= (ys == yd);
		st[ST_V] <= ($signed(xs) > $signed(xd));
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_CMP_XY: begin
		st[ST_N] <= (subx == 16'd0);
		st[ST_V] <= subx[15];
		st[ST_Z] <= (suby == 16'd0);
		st[ST_C] <= suby[15];
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_CPW: begin
		bb = {23'd0,
		      ($signed(ys) > $signed(rf[B_WEND][31:16])),
		      ($signed(rf[B_WSTART][31:16]) > $signed(ys)),
		      ($signed(xs) > $signed(rf[B_WEND][15:0])),
		      ($signed(rf[B_WSTART][15:0]) > $signed(xs)),
		      5'd0};
		rf_wr(rd_i, bb);
		st[ST_V] <= (bb != 32'd0);
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_CVXYL: begin
		rf_wr(rd_i, xytol(rs_v, convdp_set, convdp_sh, pix_shift, rf[B_OFFSET]));
		cycles   <= 24'd3;
		state    <= S_DONE;
	end

	I_MOVX: begin
		rf_wr(rd_i, {rd_v[31:16], rs_v[15:0]});
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	I_MOVY: begin
		rf_wr(rd_i, {rs_v[31:16], rd_v[15:0]});
		cycles   <= 24'd1;
		state    <= S_DONE;
	end

	//------------------------------------------------------------------
	// field moves
	//------------------------------------------------------------------
	I_MOVE_RN, I_MOVB_RN: begin
		case (step)
			5'd0: begin
				fu_write(rd_v, (cls == I_MOVB_RN) ? 6'd8 : fsize, rs_v);
				step <= 5'd1;
			end
			default: begin
				cycles <= 24'd1;
				state  <= S_DONE;
			end
		endcase
	end

	I_MOVE_R_NI: begin
		case (step)
			5'd0: begin
				fu_write(rd_v, fsize, rs_v);
				step <= 5'd1;
			end
			default: begin
				rf_wr(rd_i, rd_v + finc);
				cycles   <= 24'd1;
				state    <= S_DONE;
			end
		endcase
	end

	I_MOVE_R_DN: begin
		case (step)
			5'd0: begin
				ba = rd_v - finc;
				rf_wr(rd_i, ba);
				fu_write(ba, fsize, (rs_i == rd_i) ? ba : rs_v);
				step <= 5'd1;
			end
			default: begin
				cycles <= 24'd2;
				state  <= S_DONE;
			end
		endcase
	end

	I_MOVE_R_NO, I_MOVB_R_NO: begin
		case (step)
			5'd0: begin
				fu_write(rd_v + w0s, (cls == I_MOVB_R_NO) ? 6'd8 : fsize, rs_v);
				step <= 5'd1;
			end
			default: begin
				cycles <= 24'd3;
				state  <= S_DONE;
			end
		endcase
	end

	I_MOVE_RA, I_MOVB_RA: begin
		// the register is encoded in the Rd field
		case (step)
			5'd0: begin
				fu_write(long1, (cls == I_MOVB_RA) ? 6'd8 : fsize, rd_v);
				step <= 5'd1;
			end
			default: begin
				cycles <= (cls == I_MOVB_RA) ? 24'd1 : 24'd3;
				state  <= S_DONE;
			end
		endcase
	end

	// memory to register: NZ from the loaded value, V cleared
	I_MOVE_NR, I_MOVB_NR, I_MOVE_NO_R, I_MOVB_NO_R, I_MOVE_AR, I_MOVB_AR, I_MOVE_NI_R, I_MOVE_DN_R: begin
		case (step)
			5'd0: begin
				case (cls)
					I_MOVE_NR:   fu_read(rs_v,         fsize, fe);
					I_MOVB_NR:   fu_read(rs_v,         6'd8,  1'b1);
					I_MOVE_NO_R: fu_read(rs_v + w0s,   fsize, fe);
					I_MOVB_NO_R: fu_read(rs_v + w0s,   6'd8,  1'b1);
					I_MOVE_AR:   fu_read(long1,        fsize, fe);
					I_MOVB_AR:   fu_read(long1,        6'd8,  1'b1);
					I_MOVE_NI_R: fu_read(rs_v,         fsize, fe);
					default:     fu_read(rs_v - finc,  fsize, fe);    // MOVE_DN_R
				endcase
				step <= 5'd1;
			end
			default: begin
				if (cls == I_MOVE_NI_R) rf_wr(rs_i, rs_v + finc);
				if (cls == I_MOVE_DN_R) rf_wr(rs_i, rs_v - finc);
				rf_wr(rd_i, fu_q);             // destination wins when Rs == Rd
				st[ST_N] <= fu_q[31];
				st[ST_Z] <= (fu_q == 32'd0);
				st[ST_V] <= 1'b0;
				case (cls)
					I_MOVE_NR, I_MOVB_NR, I_MOVE_NI_R: cycles <= 24'd3;
					I_MOVE_DN_R:                        cycles <= 24'd4;
					default:                            cycles <= 24'd5;
				endcase
				state <= S_DONE;
			end
		endcase
	end

	// memory to memory
	I_MOVE_NN, I_MOVB_NN, I_MOVE_NO_NO, I_MOVB_NO_NO, I_MOVE_AA, I_MOVB_AA,
	I_MOVE_NI_NI, I_MOVE_DN_DN, I_MOVE_NO_NI, I_MOVE_A_NI: begin
		case (step)
			5'd0: begin
				case (cls)
					I_MOVB_NN, I_MOVB_NO_NO, I_MOVB_AA: bs = 6'd8;
					default:                             bs = fsize;
				endcase
				case (cls)
					I_MOVE_NO_NO, I_MOVB_NO_NO, I_MOVE_NO_NI: fu_read(rs_v + w0s, bs, 1'b0);
					I_MOVE_AA, I_MOVB_AA, I_MOVE_A_NI:        fu_read(long1, bs, 1'b0);
					I_MOVE_DN_DN: begin
						rf_wr(rs_i, rs_v - finc);
						fu_read(rs_v - finc, bs, 1'b0);
					end
					I_MOVE_NI_NI: begin
						rf_wr(rs_i, rs_v + finc);
						fu_read(rs_v, bs, 1'b0);
					end
					default: fu_read(rs_v, bs, 1'b0);
				endcase
				step <= 5'd1;
			end
			5'd1: begin
				case (cls)
					I_MOVB_NN, I_MOVB_NO_NO, I_MOVB_AA: bs = 6'd8;
					default:                             bs = fsize;
				endcase
				// the destination pointer sees the source update when they are the same register
				case (cls)
					I_MOVE_NI_NI: ba = (rd_i == rs_i) ? (rs_v + finc) : rd_v;
					I_MOVE_DN_DN: ba = ((rd_i == rs_i) ? (rs_v - finc) : rd_v) - finc;
					default:      ba = rd_v;
				endcase
				case (cls)
					I_MOVE_NO_NO, I_MOVB_NO_NO: fu_write(rd_v + w1s, bs, fu_q);
					I_MOVE_AA, I_MOVB_AA:       fu_write(long2,      bs, fu_q);
					default:                    fu_write(ba,         bs, fu_q);
				endcase
				case (cls)
					I_MOVE_NI_NI, I_MOVE_NO_NI, I_MOVE_A_NI: rf_wr(rd_i, ba + finc);
					I_MOVE_DN_DN:                            rf_wr(rd_i, ba);
					default: ;
				endcase
				step <= 5'd2;
			end
			default: begin
				case (cls)
					I_MOVE_NN, I_MOVB_NN:                   cycles <= 24'd3;
					I_MOVE_NI_NI, I_MOVE_DN_DN:             cycles <= 24'd4;
					I_MOVB_AA:                              cycles <= 24'd6;
					I_MOVE_AA:                              cycles <= 24'd7;
					default:                                cycles <= 24'd5;
				endcase
				state <= S_DONE;
			end
		endcase
	end

	//------------------------------------------------------------------
	// pixel transfers
	//------------------------------------------------------------------
	I_PIXT_RI, I_PIXT_RIXY, I_PIXT_IR, I_PIXT_II, I_PIXT_IXYR, I_PIXT_IXYIXY, I_DRAV, I_LINE: begin
		case (step)
			5'd0: begin
				case (cls)
					I_PIXT_RI: begin
						pw_addr <= rd_v;
						pw_data <= rs_v;
						cycles  <= 24'd2;
						step    <= 5'd20;
					end
					I_PIXT_RIXY, I_DRAV: begin
						cycles <= 24'd4;
						if (cls == I_DRAV)
							rf_wr(rd_i, {addy, addx});
						if (win_mode != 2'd0) begin
							st[ST_V] <= outside_win(rd_v, rf[B_WSTART], rf[B_WEND]);
						end
						if ((win_mode != 2'd0) && (outside_win(rd_v, rf[B_WSTART], rf[B_WEND]) || (win_mode == 2'd1)))
							state <= S_DONE;
						else begin
							pw_addr <= xytol(rd_v, convdp_set, convdp_sh, pix_shift, rf[B_OFFSET]);
							pw_data <= (cls == I_DRAV) ? rf[B_COLOR1] : rs_v;
							step    <= 5'd20;
						end
					end
					I_PIXT_IXYIXY: begin
						cycles <= 24'd7;
						if (win_mode != 2'd0)
							st[ST_V] <= outside_win(rd_v, rf[B_WSTART], rf[B_WEND]);
						if ((win_mode != 2'd0) && (outside_win(rd_v, rf[B_WSTART], rf[B_WEND]) || (win_mode == 2'd1)))
							state <= S_DONE;
						else begin
							pw_addr <= xytol(rs_v, convsp_set, convsp_sh, pix_shift, rf[B_OFFSET]);
							step    <= 5'd16;
						end
					end
					I_PIXT_IR, I_PIXT_II: begin
						cycles  <= 24'd4;
						pw_addr <= rs_v;
						step    <= 5'd16;
					end
					I_PIXT_IXYR: begin
						cycles  <= 24'd6;
						pw_addr <= xytol(rs_v, convsp_set, convsp_sh, pix_shift, rf[B_OFFSET]);
						step    <= 5'd16;
					end
					default: begin
						// LINE: one pixel per execution; the opcode re-runs until COUNT is exhausted
						ba = st;
						if (!st[ST_P]) begin
							ba[ST_P] = 1'b1;
							rf[B_TEMP] <= {31'd0, ir[7]};
						end
						if ($signed(rf[B_COUNT]) > 0) begin
							rf[B_COUNT] <= rf[B_COUNT] - 32'd1;
							// Bresenham step against the boundary value in TEMP
							if ($signed(rf[B_SADDR]) >= $signed(st[ST_P] ? rf[B_TEMP] : {31'd0, ir[7]})) begin
								rf[B_SADDR] <= rf[B_SADDR] + {{15{rf[B_DYDX][31]}}, rf[B_DYDX][31:16], 1'b0}
								                           - {{15{rf[B_DYDX][15]}}, rf[B_DYDX][15:0], 1'b0};
								rf[B_DADDR] <= {rf[B_DADDR][31:16] + rf[B_INC1][31:16], rf[B_DADDR][15:0] + rf[B_INC1][15:0]};
							end
							else begin
								rf[B_SADDR] <= rf[B_SADDR] + {{15{rf[B_DYDX][31]}}, rf[B_DYDX][31:16], 1'b0};
								rf[B_DADDR] <= {rf[B_DADDR][31:16] + rf[B_INC2][31:16], rf[B_DADDR][15:0] + rf[B_INC2][15:0]};
							end
							pc     <= pc - 32'd16;
							cycles <= 24'd2;
							st     <= ba;
							if ((win_mode != 2'd3) || !outside_win(rf[B_DADDR], rf[B_WSTART], rf[B_WEND])) begin
								pw_addr <= xytol(rf[B_DADDR], convdp_set, convdp_sh, pix_shift, rf[B_OFFSET]);
								pw_data <= rf[B_COLOR1];
								step    <= 5'd20;
							end
							else
								state <= S_DONE;
						end
						else begin
							ba[ST_P] = 1'b0;
							st     <= ba;
							cycles <= 24'd0;
							state  <= S_DONE;
						end
					end
				endcase
			end

			// ---- pixel read ----
			5'd16: begin
				if (srt_mode) begin
					srt_go      <= 1'b1;
					srt_wr_in   <= 1'b0;
					srt_addr_in <= pw_addr;
					wait_fu     <= 1'b1;
				end
				else
					fu_read(pw_addr & pix_align, pix_bits, 1'b0);
				step <= 5'd17;
			end
			5'd17: begin
				case (cls)
					I_PIXT_IR, I_PIXT_IXYR: begin
						rf_wr(rd_i, fu_q);
						st[ST_V] <= (fu_q != 32'd0);
						state    <= S_DONE;
					end
					I_PIXT_II: begin
						pw_addr <= rd_v;
						pw_data <= fu_q;
						step    <= 5'd20;
					end
					default: begin
						// PIXT *XY,*XY
						pw_addr <= xytol(rd_v, convdp_set, convdp_sh, pix_shift, rf[B_OFFSET]);
						pw_data <= fu_q;
						step    <= 5'd20;
					end
				endcase
			end

			// ---- pixel write ----
			5'd20: begin
				if (srt_mode) begin
					srt_go      <= 1'b1;
					srt_wr_in   <= 1'b1;
					srt_addr_in <= pw_addr;
					wait_fu     <= 1'b1;
					step        <= 5'd22;
				end
				else if (rop_en) begin
					fu_read(pw_addr & pix_align, pix_bits, 1'b0);
					step <= 5'd21;
				end
				else begin
					// plain replace (transparency skips zero pixels)
					bb = pw_data & pix_keep;
					if (trans_en && (bb == 32'd0))
						state <= S_DONE;
					else begin
						fu_write(pw_addr & pix_align, pix_bits, bb);
						step <= 5'd22;
					end
				end
			end
			5'd21: begin
				// raster op on the destination just read; written in step 23
				t1   <= raster_op(ppop, pw_data & pix_keep, fu_q, rop_max) & pix_keep;
				step <= 5'd23;
			end
			5'd23: begin
				if (trans_en && (t1 == 32'd0))
					state <= S_DONE;
				else begin
					fu_write(pw_addr & pix_align, pix_bits, t1);
					step <= 5'd22;
				end
			end
			default: state <= S_DONE;
		endcase
	end

	//------------------------------------------------------------------
	// PIXBLT / FILL: handed to the graphics engine
	//------------------------------------------------------------------
	I_PIXBLT_L_L, I_PIXBLT_L_XY, I_PIXBLT_XY_L, I_PIXBLT_XY_XY, I_PIXBLT_B_L, I_PIXBLT_B_XY, I_FILL_L, I_FILL_XY: begin
		case (step)
			5'd0: begin
				gx_start <= 1'b1;
				case (cls)
					I_PIXBLT_L_L:   gx_kind <= 3'd0;
					I_PIXBLT_L_XY:  gx_kind <= 3'd1;
					I_PIXBLT_XY_L:  gx_kind <= 3'd2;
					I_PIXBLT_XY_XY: gx_kind <= 3'd3;
					I_PIXBLT_B_L:   gx_kind <= 3'd4;
					I_PIXBLT_B_XY:  gx_kind <= 3'd5;
					I_FILL_L:       gx_kind <= 3'd6;
					default:        gx_kind <= 3'd7;
				endcase
				wait_gx <= 1'b1;
				step    <= 5'd1;
			end
			default: begin
				if (gx_wr_saddr) rf[B_SADDR] <= gx_saddr;
				if (gx_wr_daddr) rf[B_DADDR] <= gx_daddr;
				if (gx_wr_dydx)  rf[B_DYDX]  <= gx_dydx;
				if (gx_clr_v)    st[ST_V]    <= 1'b0;
				if (gx_set_v)    st[ST_V]    <= 1'b1;
				if (gx_clr_p)    st[ST_P]    <= 1'b0;
				if (gx_wv) begin
					seq_set_intpend <= 1'b1;
					seq_intpend_or  <= 16'h0800;
				end
				cycles <= gx_cycles[23:0];
				state  <= S_DONE;
			end
		endcase
	end

	default: begin
		cycles <= 24'd1;
		state  <= S_DONE;
	end
endcase
