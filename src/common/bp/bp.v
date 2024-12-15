module branch_predictor(
  input wire clk,
  input wire rst,
  input wire rdy,
  
  input jp,
  input has_predict,
  input [3:0] tag,
  input [3:0] branch_type,

  input [73:0] cdb,

  input [3:0] which_predictor,

  input flush,

  output reg [4:0] bp_tag,
  output wire jump
);

reg [9:0] bp_array[15:0]; // [9] = jp, [8:5] = tag, [4] = busy, [3:0] = branch_type
reg [31:0] i;
reg [3:0] array_size;
reg [1:0] predictor[7:0];
reg flag;

wire [9:0] bp_first;

assign bp_first = bp_array[0];
assign jump = predictor[which_predictor][1];

always @(posedge clk) begin
  if (rst) begin
    bp_tag <= 0;
    for (i = 0; i < 16; i = i + 1) begin
      predictor[i] = 0;
    end
    array_size = 0;
    for (i = 0; i < 16; i = i + 1) begin
      bp_array[i] = 0;
    end
    i = 0;
    flag = 0;
  end else if (!rdy) begin
  end else begin
    bp_tag <= 0;
    flag = 0;
    if (has_predict) begin
      for (i = 0; i < 16 && !flag; i = i + 1) begin
        if (!bp_array[i][4]) begin
          bp_array[i] = {jp, tag, 1'b1, branch_type};
          array_size = array_size + 1;
          flag = 1;
        end
      end
    end
    if (array_size && cdb[36]) begin
      for (i = 0; i < 16; i = i + 1) begin
        if (bp_array[i][4] && bp_array[i][8:5] == cdb[35:32]) begin
          if (cdb[31:0]) begin
            if (predictor[bp_array[i][3:0]] < 2'b11) begin
              predictor[bp_array[i][3:0]] = predictor[bp_array[i][3:0]] + 1;
            end
          end else begin
            if (predictor[bp_array[i][3:0]]) begin
              predictor[bp_array[i][3:0]] = predictor[bp_array[i][3:0]] - 1;
            end
          end
          // $display("predictor[%d] = %d, cdb[0] = %d, bp_array[i][9]= %d", bp_array[i][3:0], predictor[bp_array[i][3:0]], cdb[0], bp_array[i][9]);
          bp_tag <= (cdb[0] == bp_array[i][9] ? 0 : {1'b1, bp_array[i][8:5]});
          array_size = array_size - 1;
          bp_array[i][4] = 0;
        end
      end
    end
    if (flush) begin
      array_size = 0;
      for (i = 0; i < 16; i = i + 1) begin
        bp_array[i] = 0;
      end
    end
  end
end

endmodule