`include "common.vh"

module register_file(
  input wire [4:0] addr1_in, addr2_in, addr3_in,
  input wire [`WIDTH-1:0] word_data3_in,
  input wire write_enable3_in,
  input wire clk_in,
  output wire [`WIDTH-1:0] word_data1_out, word_data2_out
);
  localparam REG_FILE_SIZE = 32;

  reg [`WIDTH-1:0] registers[REG_FILE_SIZE-1:0];

  assign word_data1_out = (addr1_in == 5'b0) ? `WIDTH'b0 : registers[addr1_in];
  assign word_data2_out = (addr2_in == 5'b0) ? `WIDTH'b0 : registers[addr2_in];

  always @(posedge clk_in) begin
      if (addr3_in != 5'b0 && write_enable3_in) registers[addr3_in] <= word_data3_in;
  end
endmodule
