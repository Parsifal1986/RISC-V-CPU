module branch_predictor(
  input wire clk,
  
  input jp,
  input [3:0] tag,
  input [2:0] branch_type,
  input need_jump_in,

  input [73:0] cdb,

  input [2:0] which_predictor1,
  input [2:0] which_predictor2,

  input flush,

  output reg [4:0] bp_tag,
  output reg bp_flush,
  output wire jump1,
  output wire jump2,
  output wire need_jump_out
);

reg [8:0] bp_array[15:0]; // [8] = jp, [7:4] = tag, [3] = busy, [2:0] = branch_type
reg [3:0] i;
reg [3:0] array_size;
reg [1:0] predictor[7:0];
reg flag;
reg need_jump;

assign need_jump_out = need_jump;

assign jump1 = predictor[which_predictor1][1];
assign jump2 = predictor[which_predictor2][1];

always @(*) begin
  need_jump = need_jump_in;
end

always @(posedge clk) begin
  bp_tag <= 0;
  flag = 0;
  if (tag) begin
    for (i = 0; i < 16 && !flag; i = i + 1) begin
      if (!bp_array[i][3]) begin
        bp_array[i] = {jp, tag, 1'b1, branch_type};
        array_size = array_size + 1;
        flag = 1;
      end
    end
  end
  if (array_size && cdb[36]) begin
    for (i = 0; i < 16; i = i + 1) begin
      if (bp_array[i][3] && bp_array[i][7:4] == cdb[35:32]) begin
        if (cdb[31:0]) begin
          if (predictor[bp_array[i][2:0]] < 2'b11) begin
            predictor[bp_array[i][2:0]] = predictor[bp_array[i][2:0]] + 1;
          end
        end else begin
          if (predictor[bp_array[i][2:0]]) begin
            predictor[bp_array[i][2:0]] = predictor[bp_array[i][2:0]] - 1;
          end
        end
        bp_tag <= (cdb[0] == bp_array[i][8] ? 0 : {1'b1, bp_array[i][7:4]});
        array_size = array_size - 1;
        bp_array[i][3] = 0;
      end
    end
  end
  if (flush) begin
    array_size = 0;
    for (i = 0; i < 8; i = i + 1) begin
      bp_array[i] = 0;
    end
  end
end

endmodule