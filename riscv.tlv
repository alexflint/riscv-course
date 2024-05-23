\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   //m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   //m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   //m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   //m4_asm(ADD, x14, x13, x14)           // Incremental summation
   //m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   //m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   //m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   //m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   //m4_asm(ADDI, x0, x0, 101) // Write value 5 to x0
   //m4_asm_end()
   //m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------

   m4_test_prog()

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   // get the "next" program counter computed during the last clock cycle
   $pc[31:0] = >>1$next_pc;
   
   // read next instruction from memory
   `READONLY_MEM($pc, $$instr[31:0])
   
   // decode instruction type from last 6 bits
   $opcode[6:0] = $instr[6:0];
   $optype[4:0] = $opcode[6:2];
   $is_r_instr = $optype == 5'b01011 || $optype == 5'b01100 || $optype == 5'b01110 || $optype == 5'b10100;
   $is_i_instr = $optype == 5'b00000 || $optype == 5'b00001 || $optype == 5'b00100 || $optype == 5'b00110 || $optype == 5'b11001;
   $is_s_instr = $optype ==? 5'b0100x;
   $is_b_instr = $optype == 5'b11000;
   $is_u_instr = $optype ==? 5'b0x101;  // "x" here is a wildcard
   $is_j_instr = $optype == 5'b11011;
   
   // decode other instruction parts
   $rd[4:0] = $instr[11:7];
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   
   $rs1[4:0] = $instr[19:15];
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   
   $rs2[4:0] = $instr[24:20];
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   
   $funct3[2:0] = $instr[14:12];
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:8], $instr[7] } :
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31], $instr[30:20], $instr[19:12], 12'b0 } :
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0 } :
                32'b0;  // default
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;

   `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $rs2 $rs2_valid $funct3 $funct3_valid $imm $imm_valid)

   // decode the specific operation
   $dec_bits[10:0] = {$instr[30], $funct3, $opcode};
   $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal   = $dec_bits ==? 11'bx_xxx_1101111;  // jump and link (PC + IMM)
   $is_jalr  = $dec_bits ==? 11'bx_000_1100111;  // jump and link register (SRC1 + IMM)

   $is_beq   = $dec_bits ==? 11'bx_000_1100011;
   $is_bne   = $dec_bits ==? 11'bx_001_1100011;
   $is_blt   = $dec_bits ==? 11'bx_100_1100011;
   $is_bge   = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu  = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu  = $dec_bits ==? 11'bx_111_1100011;
   
   //$is_lb    = $dec_bits ==? 11'bx_000_0000011;  // load byte
   //$is_lh    = $dec_bits ==? 11'bx_001_0000011;  // load half word
   //$is_lw    = $dec_bits ==? 11'bx_010_0000011;  // load word
   //$is_lbu   = $dec_bits ==? 11'bx_100_0000011;
   //$is_lhu   = $dec_bits ==? 11'bx_101_0000011;
   $is_load  = $dec_bits ==? 11'bx_xxx_0000011;  // any load instruction

   //$is_sb    = $dec_bits ==? 11'bx_000_0100011;  // store byte
   //$is_sh    = $dec_bits ==? 11'bx_001_0100011;  // store half word
   //$is_sw    = $dec_bits ==? 11'bx_010_0100011;  // store word
   $is_store = $dec_bits ==? 11'bx_xxx_0100011;  // any store instruction
   
   $is_addi  = $dec_bits ==? 11'bx_000_0010011;  // add immediate
   $is_slti  = $dec_bits ==? 11'bx_010_0010011;  // set if less than (unsigned)
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;  // set if less than immediate (unsigned)
   $is_xori  = $dec_bits ==? 11'bx_100_0010011;  // xor immediate
   $is_ori   = $dec_bits ==? 11'bx_110_0010011;  // or immediate
   $is_andi  = $dec_bits ==? 11'bx_111_0010011;  // and immediate
   $is_slli  = $dec_bits ==? 11'b0_001_0010011;
   $is_srli  = $dec_bits ==? 11'b0_101_0010011;
   $is_srai  = $dec_bits ==? 11'b1_101_0010011;  // shift right immediate
   
   $is_add   = $dec_bits ==? 11'b0_000_0110011;  // add
   $is_sub   = $dec_bits ==? 11'b1_000_0110011;  // subtract
   $is_sll   = $dec_bits ==? 11'b0_001_0110011;  // shift left?
   $is_slt   = $dec_bits ==? 11'b0_010_0110011;  // shift left and truncate?
   $is_sltu  = $dec_bits ==? 11'b0_011_0110011;  // shift left and truncate upper?
   $is_xor   = $dec_bits ==? 11'b0_100_0110011;  // xor
   $is_srl   = $dec_bits ==? 11'b0_101_0110011;  // shift right?
   $is_sra   = $dec_bits ==? 11'b1_101_0110011;  // shift right?
   $is_or    = $dec_bits ==? 11'b0_110_0110011;  // or
   $is_and   = $dec_bits ==? 11'b0_111_0110011;  // and
   
   
   `BOGUS_USE($dec_bits $is_beq $is_bne $is_blt $is_bge $is_bgeu $is_bltu $is_add $is_addi);

   // read from registers
   $src1_enable = $rs1_valid;
   $src1_index[4:0] = $rs1;
   
   $src2_enable = $rs2_valid;
   $src2_index[4:0] = $rs2;
   
   // compute less-than markers (signed)
   $slt_bit  = ($src1_value[31] == $src2_value[31]) ? $src1_value < $src2_value : $src1_value[31];
   $slti_bit = ($src1_value[31] == $imm[31]) ? $src1_value < $imm : $src1_value[31];

   // compute less-than markers (unsigned)
   $sltu_bit  = $src1_value < $src2_value;
   $sltiu_bit = $src1_value < $imm;

   // compute right-shift values
   $sign_extended_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
   $sra_result[63:0] = $sign_extended_src1 >> $src2_value[4:0];
   $srai_result[63:0] = $sign_extended_src1 >> $imm[4:0];
   
   // compute arithmetic result
   $result[31:0] = $is_andi  ? $src1_value & $imm :
                   $is_ori   ? $src1_value | $imm :
                   $is_xori  ? $src1_value ^ $imm :
                   $is_addi  ? $src1_value + $imm :
                   $is_slli  ? $src1_value << $imm[5:0] :
                   $is_srli  ? $src1_value >> $imm[5:0] :
                   $is_and   ? $src1_value & $src2_value :
                   $is_or    ? $src1_value | $src2_value :
                   $is_xor   ? $src1_value ^ $src2_value :
                   $is_add   ? $src1_value + $src2_value :
                   $is_sub   ? $src1_value - $src2_value :
                   $is_sll   ? $src1_value << $src2_value[4:0] :
                   $is_srl   ? $src1_value >> $src2_value[4:0] :
                   $is_slt   ? {31'b0, $slt_bit} :
                   $is_slti  ? {31'b0, $slti_bit} :
                   $is_sltu  ? {31'b0, $sltu_bit} :
                   $is_sltiu ? {31'b0, $sltiu_bit} :
                   $is_lui   ? {$imm[31:12], 12'b0} :
                   $is_auipc ? $pc + $imm :
                   $is_jal   ? $pc + 32'd4 :
                   $is_jalr  ? $pc + 32'd4 :
                   $is_sra   ? $sra_result[31:0] :
                   $is_srai  ? $srai_result[31:0] :
                   $is_load  ? $src1_value + $imm :  // TODO: read this memory location
                   $is_store ? $src1_value + $imm :  // TODO: store src2_value to this memory location
                   32'b0;
   
   // compute values for writing to register file
   $write_enable = $rd == 0 ? 0 : $rd_valid;  // never write to register 0
   $write_index[4:0] = $rd;                             // index of register to write to
   $write_value[31:0] = $is_load ? $ld_data : $result;        // value to write to register
   
   // determine whether the branch condition is met
   $taken_br = $is_beq  ? ($src1_value == $src2_value) :
               $is_bne  ? ($src1_value != $src2_value) :
               $is_blt  ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :   // signed
               $is_bge  ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :  // signed
               $is_bltu ? ($src1_value < $src2_value) :
               $is_bgeu ? ($src1_value >= $src2_value) :
               0;
   
   // compute the next program counter in the case that we are branching
   $br_tgt_pc[31:0] = $pc + $imm;
   
   // compute the next program counter in the case of jump and link (same as branch)
   $jal_tgt_pc[31:0] = $pc + $imm;
   
   // compute the next program counter in the case of jump and link register
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   
   // compute the next program counter
   $next_pc[31:0] = $reset ? 0 :               // upon reset, go to instruction 0
                    $taken_br ? $br_tgt_pc :   // upon branch, go to branch target
                    $is_jal ? $jal_tgt_pc :    // upon jump-and-link, go to target
                    $is_jalr ? $jalr_tgt_pc :  // upon jump and link register, go to target
                    $pc + 4;                   // default: go to next instruction
   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   m4+rf(32, 32, $reset, $write_enable, $write_index[4:0], $write_value[31:0], $src1_enable, $src1_index[4:0], $src1_value, $src2_enable, $src2_index[4:0], $src2_value)
   m4+dmem(32, 32, $reset, $result[6:2], $is_store, $src2_value[31:0], $is_load, $ld_data)
   m4+cpu_viz()
\SV
   endmodule