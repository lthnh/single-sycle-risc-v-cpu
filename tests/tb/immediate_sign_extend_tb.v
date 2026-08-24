`include "common.vh"
`include "assert.vh"

`define N_INSTR_TYPES 4

module immediate_sign_extend_tb;
  reg [`WIDTH-1:0] curr_instr_in;
  reg [1:0] imm_src_sel_in;
  reg clk_in;
  wire [`WIDTH-1:0] imm_ext_out;

  immediate_sign_extend ise_dut (
    .curr_instr_in (curr_instr_in),
    .imm_src_sel_in(imm_src_sel_in),
    .imm_ext_out   (imm_ext_out)
  );

  reg [`WIDTH-1:0] test_instr_int [`N_INSTR_TYPES-1:0] =

  initial fork
    clk_in = 1'b0;
    forever #1 clk_in = ~clk_in;
  join

  initial begin
    $display("%m is passed!");
    $finish;
  end
endmodule
