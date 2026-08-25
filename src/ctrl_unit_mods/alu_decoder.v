module alu_decoder(
  input wire [1:0] alu_op_in,
  input wire [6:0] op_in,
  input wire [14:12] funct3_in,
  input wire funct7_bit5_in,
  output reg [2:0] opctrl_out
);
  always @* begin
    case (alu_op_in)
      2'b00: opctrl_out = 3'b000;
      2'b01: opctrl_out = 3'b001;
      2'b10: begin
        case (funct3_in)
          3'b000: begin
            if (!(op_in[5] && funct7_bit5_in))
              opctrl_out = 3'b000;
            else
              opctrl_out = 3'b001;
          end
          3'b010: opctrl_out = 3'b101;
          3'b110: opctrl_out = 3'b011;
          3'b111: opctrl_out = 3'b010;
          default: opctrl_out = 3'b000;
        endcase
      end
      default:;
    endcase
  end
endmodule

