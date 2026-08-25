`include "common.vh"

module data_memory #(
  parameter MEM_SIZE = 512,
  parameter BUS_WIDTH = $clog2(MEM_SIZE)
)
(
  input wire [BUS_WIDTH-1:0] addr_in,
  input wire [`WIDTH-1:0] write_data_in,
  input wire write_enable_in,
  input wire clk_in,
  output wire [`WIDTH-1:0] read_data_out
);
  reg [`WIDTH-1:0] data_mem[MEM_SIZE-1:0];

  assign read_data_out = data_mem[addr_in];

  always @(posedge clk_in) begin
    if (write_enable_in) data_mem[addr_in] <= write_data_in;
  end
endmodule
