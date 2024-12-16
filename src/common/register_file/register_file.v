module register_file(
  input wire clk,
  input wire rst,
  input wire rdy,

  input wire[4:0] read_addr1,
  input wire[4:0] read_addr2,
  input wire[4:0] write_addr1,
  input wire write_enable1,
  input wire[36:0] write_data1,
  input wire[4:0] write_addr2,
  input wire write_enable2,
  input wire[36:0] write_data2,
  input wire flush,
  output wire[36:0] read_data1,
  output wire[36:0] read_data2
);

reg [31:0] registers[31:0];
reg [4:0] reg_state[31:0];

// wire [36:0] x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;

assign read_data1 = {reg_state[read_addr1], registers[read_addr1]};
assign read_data2 = {reg_state[read_addr2], registers[read_addr2]};

// assign x0 = {reg_state[0], registers[0]};
// assign x1 = {reg_state[1], registers[1]};
// assign x2 = {reg_state[2], registers[2]};
// assign x3 = {reg_state[3], registers[3]}; 
// assign x4 = {reg_state[4], registers[4]};
// assign x5 = {reg_state[5], registers[5]};
// assign x6 = {reg_state[6], registers[6]};
// assign x7 = {reg_state[7], registers[7]};
// assign x8 = {reg_state[8], registers[8]};
// assign x9 = {reg_state[9], registers[9]};
// assign x10 = {reg_state[10], registers[10]};
// assign x11 = {reg_state[11], registers[11]};
// assign x12 = {reg_state[12], registers[12]};
// assign x13 = {reg_state[13], registers[13]};
// assign x14 = {reg_state[14], registers[14]};
// assign x15 = {reg_state[15], registers[15]};
// assign x16 = {reg_state[16], registers[16]};
// assign x17 = {reg_state[17], registers[17]};
// assign x18 = {reg_state[18], registers[18]};
// assign x19 = {reg_state[19], registers[19]};
// assign x20 = {reg_state[20], registers[20]};
// assign x21 = {reg_state[21], registers[21]};
// assign x22 = {reg_state[22], registers[22]};
// assign x23 = {reg_state[23], registers[23]};
// assign x24 = {reg_state[24], registers[24]};
// assign x25 = {reg_state[25], registers[25]};
// assign x26 = {reg_state[26], registers[26]};
// assign x27 = {reg_state[27], registers[27]};
// assign x28 = {reg_state[28], registers[28]};
// assign x29 = {reg_state[29], registers[29]};
// assign x30 = {reg_state[30], registers[30]};
// assign x31 = {reg_state[31], registers[31]};

integer i;

always @(negedge clk) begin
  if (write_enable2) begin
    registers[write_addr2] = write_data2[31:0];
    reg_state[write_addr2] = write_data2[36:32];
  end
  if (write_enable1) begin
    reg_state[write_addr1] = write_data1[36:32];
  end
  registers[0] = 0;
  reg_state[0] = 0;
end

always @(posedge clk) begin
  if (rst) begin
    for (i = 0; i < 32; i = i + 1) begin
      registers[i] = 0;
      reg_state[i] = 0;
    end
  end else if (!rdy) begin
  end else begin
    if (flush) begin
      for (i = 0; i < 32; i = i + 1) begin
        reg_state[i] = 0;
      end
    end
  end
end

endmodule