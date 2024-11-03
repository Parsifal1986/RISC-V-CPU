module cdb(
  input wire[31:0] input_alu_tag,
  input wire[31:0] input_alu_result,
  input wire alu_ready,

  input wire[31:0] input_ls_tag,
  input wire[31:0] input_ls_result,
  input wire ls_ready,

  output reg[31:0] alu_tag,
  output reg[31:0] alu_result,
  output reg alu_done,

  output reg[31:0] ls_tag,
  output reg[31:0] ls_result,
  output reg ls_done
);

always @(*) begin
  if (alu_ready == 1) begin
    alu_tag <= input_alu_tag;
    alu_result <= input_alu_result;
    alu_done <= 1;
  end else begin
    alu_tag <= 0;
    alu_result <= 0;
    alu_done <= 0;
  end
end

always @(*) begin
  if (ls_ready == 1) begin
    ls_tag <= input_ls_tag;
    ls_result <= input_ls_result;
    ls_done <= 1;
  end else begin
    ls_tag <= 0;
    ls_result <= 0;
    ls_done <= 0;
  end
end

endmodule