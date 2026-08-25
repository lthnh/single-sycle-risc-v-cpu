`include "common.vh"
`include "assert.vh"

`define SAMPLE_SIZE 100

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

  reg [`WIDTH-1:0] imm_ext_ref;

  always @(*) begin
    case (imm_src_sel_in)
      2'b00: imm_ext_ref = {{20{curr_instr_in[31]}}, curr_instr_in[31:20]};
      2'b01: imm_ext_ref = {{20{curr_instr_in[31]}}, curr_instr_in[31:25], curr_instr_in[11:7]};
      2'b10: imm_ext_ref = {{20{curr_instr_in[31]}}, curr_instr_in[7], curr_instr_in[30:25], curr_instr_in[11:8], 1'b0};
      2'b11: imm_ext_ref = {{12{curr_instr_in[31]}}, curr_instr_in[19:12], curr_instr_in[20], curr_instr_in[30:21], 1'b0};
      default: imm_ext_ref = {`WIDTH{1'b0}};
    endcase
  end

  integer i, j;
  initial begin
    for (i = 0; i < `SAMPLE_SIZE; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        curr_instr_in = $unsigned($random);
        imm_src_sel_in = j[1:0];
        #1;
        `assert_eq_fmt(imm_ext_out, imm_ext_ref, %d)
      end
    end
    $display("%m is passed!");
    $finish;
  end

  initial fork
    $dumpvars();
    clk_in = 1'b0;
    forever #1 clk_in = ~clk_in;
  join
endmodule
