`include "common.vh"

module program_counter (
  input wire [`WIDTH-1:0] addr_in,
  input wire clk_in, rstn_in,
  output reg [`WIDTH-1:0] addr_out
);
  always @(posedge clk_in or negedge rstn_in) begin
    if (rstn_in)
      addr_out <= addr_in;
    else
      addr_out <= 0;
  end
endmodule
