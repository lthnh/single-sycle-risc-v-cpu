`include "common.vh"

module mux31_32b(
  input wire [`WIDTH-1:0] a_in,
  input wire [`WIDTH-1:0] b_in,
  input wire [`WIDTH-1:0] c_in,
  input wire [1:0] sel_in,
  output reg [`WIDTH-1:0] s_out
);
  always @* begin
    case (sel_in)
      2'b00: s_out = a_in;
      2'b01: s_out = b_in;
      2'b10: s_out = c_in;
      default: s_out = {`WIDTH{1'b0}};
    endcase
  end
endmodule

