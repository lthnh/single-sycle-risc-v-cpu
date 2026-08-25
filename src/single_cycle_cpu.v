`include "common.vh"
`include "riscv_opcode.vh"

module single_cycle_cpu(
  input wire clk_in,
  input wire prog_enable_in,
  input wire [`WIDTH-1:0] instr_in,
  output wire [`WIDTH-1:0] instr_out
);
  wire [`WIDTH-1:0] next_instr_int, addr_instr_int, curr_instr_int;
  wire [`WIDTH-1:0] imm_ext_int, src_a_int, src_b_int, alu_res_int;
  wire [`WIDTH-1:0] mem_wrt_int, mem_rd_int, reg_wrt_int;
  wire [`WIDTH-1:0] instr_branch_to_int, curr_plus_four_instr_int;
  wire zero_int, pc_src_sel_int, alu_src_sel_int;
  wire mem_wrt_enable_int, reg_wrt_enable_int;
  wire [1:0] imm_src_sel_int, res_src_sel_int;
  wire [2:0] opctrl_int;

  control_unit cu (
    .zero_in        (zero_int),
    .op_in          (curr_instr_int[6:0]),
    .funct3_in      (curr_instr_int[14:12]),
    .funct7_bit5_in (curr_instr_int[30]),
    .pc_src_sel_out (pc_src_sel_int),
    .res_src_sel_out(res_src_sel_int),
    .mem_write_out  (mem_wrt_enable_int),
    .alu_src_sel_out(alu_src_sel_int),
    .imm_src_sel_out(imm_src_sel_int),
    .reg_write_out  (reg_wrt_enable_int),
    .opctrl_out     (opctrl_int)
  );

  mux21_32b mux_instr_src_sel (
    .a_in  (curr_plus_four_instr_int),
    .b_in  (instr_branch_to_int),
    .sel_in(pc_src_sel_int),
    .s_out (next_instr_int)
  );

  program_counter pc (
    .addr_in (next_instr_int),
    .clk_in  (clk_in),
    .addr_out(addr_instr_int)
  );

  instruction_increment instr_incr (
    .curr_pc_in           (curr_instr_int),
    .curr_plus_four_instr_out(curr_plus_four_instr_int)
  );

  instruction_memory instr_mem (
    .addr_in  (addr_instr_int),
    .prog_enable_in(prog_enable_in),
    .instr_in(instr_in),
    .clk_in(clk_in),
    .instr_out(curr_instr_int)
  );

  assign instr_out = curr_instr_int;

  register_file reg_file (
    .addr1_in        (curr_instr_int[19:15]),
    .addr2_in        (curr_instr_int[24:20]),
    .addr3_in        (curr_instr_int[11:7]),
    .word_data3_in   (reg_wrt_int),
    .write_enable3_in(reg_wrt_enable_int),
    .clk_in          (clk_in),
    .word_data1_out  (src_a_int),
    .word_data2_out  (mem_wrt_int)
  );

  immediate_sign_extend imm_sign_ext (
     .curr_instr_in (curr_instr_int),
     .imm_src_sel_in(imm_src_sel_int),
     .imm_ext_out   (imm_ext_int)
  );

  mux21_32b mux_alu_src_sel (
    .a_in  (mem_wrt_int),
    .b_in  (imm_ext_int),
    .sel_in(alu_src_sel_int),
    .s_out (src_b_int)
  );

  arithmetic_logic_unit alu (
    .operand_a_in        (src_a_int),
    .operand_b_in        (src_b_int),
    .operation_control_in(opctrl_int),
    .result_out          (alu_res_int),
    .zero                (zero_int)
  );

  data_memory dm (
    .addr_in        (alu_res_int),
    .write_data_in  (mem_wrt_int),
    .write_enable_in(mem_wrt_enable_int),
    .clk_in         (clk_in),
    .read_data_out  (mem_rd_int)
  );

  mux31_32b mux_res_src_sel (
    .a_in  (alu_res_int),
    .b_in  (mem_rd_int),
    .c_in  (curr_plus_four_instr_int),
    .sel_in(res_src_sel_int),
    .s_out (reg_wrt_int)
  );

  branch_target bt (
    .curr_pc_in     (curr_instr_int),
    .instr_br_offset_in(imm_ext_int),
    .instr_br_to_out   (instr_branch_to_int)
  );
endmodule
