`include "common.vh"

module immediate_sign_extend(
  input wire [`WIDTH-1:0] curr_instr_in,
  input wire [1:0] imm_src_sel_in,
  output reg [`WIDTH-1:0] imm_ext_out
);
  always @* begin
    case (imm_src_sel_in)
      // I-type
      2'b00: imm_ext_out = {{20{curr_instr_in[31]}}, curr_instr_in[31:20]};
      // S-type
      2'b01: imm_ext_out = {{20{curr_instr_in[31]}}, curr_instr_in[31:25], curr_instr_in[11:7]};
      // B-type
      2'b10: imm_ext_out = {{20{curr_instr_in[31]}}, curr_instr_in[7], curr_instr_in[30:25], curr_instr_in[11:8], 1'b0};
      // J-type
      2'b11: imm_ext_out = {{12{curr_instr_in[31]}}, curr_instr_in[19:12], curr_instr_in[20], curr_instr_in[30:21], 1'b0};
      default:;
    endcase
  end
endmodule

