module register_file(
  input wire clk,

  input wire[4:0] read_addr1,
  input wire[4:0] read_addr2,
  input wire[4:0] write_addr,
  input wire write_enable,
  input wire[31:0] write_data,
  output wire[36:0] read_data1,
  output wire[36:0] read_data2
);

reg [31:0] registers[31:0];
reg [31:0] reg_state[31:0];

assign read_data1 = {reg_state[read_addr1], registers[read_addr1]};
assign read_data2 = {reg_state[read_addr2], registers[read_addr2]};

always @(posedge clk) begin
  if (write_enable) begin
    registers[write_addr] <= write_data;
  end
end

endmodule