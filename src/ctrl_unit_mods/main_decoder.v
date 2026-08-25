`include "riscv_opcodes.vh"

module main_decoder(
  input wire [6:0] op_in,
  output reg [1:0] res_src_sel_out,
  output reg mem_write_out,
  output reg alu_src_sel_out,
  output reg [1:0] imm_src_sel_out,
  output reg reg_write_out,
  output reg br_out,
  output reg jmp_out,
  output reg [1:0] alu_op_out
);
  always @* begin
    case (op_in)
      `LW: begin
        reg_write_out = 1'b1;
        imm_src_sel_out = 2'b00;
        alu_src_sel_out = 1'b1;
        mem_write_out = 1'b0;
        res_src_sel_out = 2'b01;
        br_out = 1'b0;
        alu_op_out = 2'b00;
        jmp_out = 1'b0;
      end
      `SW: begin
        reg_write_out = 1'b0;
        res_src_sel_out = 2'b00;
        imm_src_sel_out = 2'b01;
        alu_src_sel_out = 1'b1;
        mem_write_out = 1'b1;
        br_out = 1'b0;
        alu_op_out = 2'b00;
        jmp_out = 1'b0;
      end
      `R_TYPE: begin
        reg_write_out = 1'b1;
        alu_src_sel_out = 1'b0;
        imm_src_sel_out = 2'b00;
        mem_write_out = 1'b0;
        res_src_sel_out = 2'b00;
        br_out = 1'b0;
        alu_op_out = 2'b10;
        jmp_out = 1'b0;
      end
      `BEQ: begin
        reg_write_out = 1'b0;
        imm_src_sel_out = 2'b10;
        alu_src_sel_out = 1'b0;
        mem_write_out = 1'b0;
        br_out = 1'b1;
        alu_op_out = 2'b01;
        jmp_out = 1'b0;
      end
      `ADDI: begin
        reg_write_out = 1'b1;
        imm_src_sel_out = 2'b00;
        alu_src_sel_out = 2'b01;
        mem_write_out = 1'b0;
        res_src_sel_out = 2'b00;
        br_out = 1'b0;
        alu_op_out = 2'b10;
        jmp_out = 1'b0;
      end
      `JAL: begin
        reg_write_out = 1'b1;
        imm_src_sel_out = 2'b11;
        mem_write_out = 1'b0;
        alu_src_sel_out = 2'b00;
        res_src_sel_out = 2'b10;
        br_out = 1'b0;
        jmp_out = 1'b1;
        alu_op_out = 2'b00;
      end
      default: begin
        reg_write_out = 1'b0;
        imm_src_sel_out = 2'b00;
        alu_src_sel_out = 1'b00;
        mem_write_out = 1'b0;
        res_src_sel_out = 2'b00;
        br_out = 1'b0;
        alu_op_out = 2'b00;
        jmp_out = 1'b0;
      end
    endcase
  end
endmodule

