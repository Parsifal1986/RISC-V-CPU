module instruction(
  input wire clk,

  input wire instruction_ready,
  input wire[31:0] instruction_addr,
  input wire[31:0] instruction_data,
  input wire[31:0] jump_addr,
  
  output reg ready,
  output reg[31:0] addr,
  output reg[31:0] program_counter,
  output reg[31:0] instruction
);

always @(posedge clk) begin
  
end

endmodule