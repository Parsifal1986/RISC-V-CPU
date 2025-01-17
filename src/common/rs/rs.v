module reservation_station(
  input clk,
  input wire rst,
  input wire rdy,

  input [118:0] rs_instruction,
  input [73:0] cdb,
  input flush,

  output reg rs_ready,
  output reg [4:0] alu_oprand,
  output reg [31:0] a,
  output reg [31:0] b,
  output reg [3:0] alu_tag,
  output reg alu_ready
);

reg [1:0] rs_array_busy[15:0];
reg [31:0] rs_array_vj[15:0];
reg [31:0] rs_array_vk[15:0];
reg [4:0] rs_array_qj[15:0];
reg [4:0] rs_array_qk[15:0];
reg [31:0] rs_array_a[15:0];
reg [4:0] rs_array_tag[15:0];
reg [4:0] rs_array_op[15:0];

reg [3:0] array_size;

integer flag;

wire [15:0] output_flag;
wire [15:0] input_flag;

reg [4:0] work_output;
reg [4:0] work_input;

generate
  genvar j;
  for (j = 0; j < 16; j = j + 1) begin : buf_flag_generate
    assign input_flag[j] = !rs_array_busy[j];
    assign output_flag[j] = rs_array_busy[j] == 1 && !rs_array_qj[j][4] && !rs_array_qk[j][4];
  end
endgenerate

initial begin : initialize
  integer i;
  for (i = 0; i < 16; i = i + 1) begin
    rs_array_busy[i] <= 0;
    rs_array_vj[i] <= 0;
    rs_array_vk[i] <= 0;
    rs_array_qj[i] <= 0;
    rs_array_qk[i] <= 0;
    rs_array_a[i] <= 0;
    rs_array_tag[i] <= 0;
    rs_array_op[i] <= 0;
  end
end

always @(*) begin
  casez (input_flag)
    16'b0000000000000000 : work_input = 16;
    16'b????_????_????_???1 : work_input = 0;
    16'b????_????_????_??10 : work_input = 1;
    16'b????_????_????_?100 : work_input = 2;
    16'b????_????_????_1000 : work_input = 3;
    16'b????_????_???1_0000 : work_input = 4;
    16'b????_????_??10_0000 : work_input = 5;
    16'b????_????_?100_0000 : work_input = 6;
    16'b????_????_1000_0000 : work_input = 7;
    16'b????_???1_0000_0000 : work_input = 8;
    16'b????_??10_0000_0000 : work_input = 9;
    16'b????_?100_0000_0000 : work_input = 10;
    16'b????_1000_0000_0000 : work_input = 11;
    16'b???1_0000_0000_0000 : work_input = 12;
    16'b??10_0000_0000_0000 : work_input = 13;
    16'b?100_0000_0000_0000 : work_input = 14;
    16'b1000_0000_0000_0000 : work_input = 15;
  endcase
end

always @(*) begin
  casez (output_flag)
    16'b0000000000000000 : work_output = 16;
    16'b????_????_????_???1 : work_output = 0;
    16'b????_????_????_??10 : work_output = 1;
    16'b????_????_????_?100 : work_output = 2;
    16'b????_????_????_1000 : work_output = 3;
    16'b????_????_???1_0000 : work_output = 4;
    16'b????_????_??10_0000 : work_output = 5;
    16'b????_????_?100_0000 : work_output = 6;
    16'b????_????_1000_0000 : work_output = 7;
    16'b????_???1_0000_0000 : work_output = 8;
    16'b????_??10_0000_0000 : work_output = 9;
    16'b????_?100_0000_0000 : work_output = 10;
    16'b????_1000_0000_0000 : work_output = 11;
    16'b???1_0000_0000_0000 : work_output = 12;
    16'b??10_0000_0000_0000 : work_output = 13;
    16'b?100_0000_0000_0000 : work_output = 14;
    16'b1000_0000_0000_0000 : work_output = 15;
  endcase
end

always @(posedge clk) begin
  if (rst) begin : reset
    integer i;
    for (i = 0; i < 16; i = i + 1) begin
      rs_array_busy[i] <= 0;
    end
    array_size = 0;
    alu_ready <= 0;
    a <= 0;
    b <= 0;
    alu_tag <= 0;
    rs_ready <= 0;
  end else if (!rdy) begin
  end else begin
    begin // WorkInstruction
      if (rs_instruction) begin
        if (work_input != 16) begin
          rs_array_busy[work_input] <= 1;
          rs_array_op[work_input] <= rs_instruction[116:112];
          if (cdb[36] && rs_instruction[46] && rs_instruction[45:42] == cdb[35:32]) begin
            rs_array_vj[work_input] <= cdb[31:0];
            rs_array_qj[work_input] <= 0;
          end else if (cdb[73] && rs_instruction[46] && rs_instruction[45:42] == cdb[72:69]) begin
            rs_array_vj[work_input] <= cdb[68:37];
            rs_array_qj[work_input] <= 0;
          end else begin
            rs_array_vj[work_input] <= rs_instruction[110:79];
            rs_array_qj[work_input] <= rs_instruction[46:42];
          end
          if (cdb[36] && rs_instruction[41] && rs_instruction[40:37] == cdb[35:32]) begin
            rs_array_vk[work_input] <= cdb[31:0];
            rs_array_qk[work_input] <= 0;
          end else if (cdb[73] && rs_instruction[41] && rs_instruction[40:37] == cdb[72:69]) begin
            rs_array_vk[work_input] <= cdb[68:37];
            rs_array_qk[work_input] <= 0;
          end else begin
            rs_array_vk[work_input] <= rs_instruction[78:47];
            rs_array_qk[work_input] <= rs_instruction[41:37];
          end
          rs_array_a[work_input] <= rs_instruction[36:5];
          rs_array_tag[work_input] <= rs_instruction[3:0];
          array_size = array_size + 1;
        end
      end
    end
    begin // WorkArray
      if (work_output != 16) begin
        alu_ready <= 1;
        alu_oprand <= rs_array_op[work_output];
        a <= rs_array_vj[work_output];
        b <= rs_array_vk[work_output];
        alu_tag <= rs_array_tag[work_output];
        rs_array_busy[work_output] <= 0;
        array_size = array_size - 1;
      end else begin
        alu_ready <= 0;
      end
      if (array_size < 14) begin
        rs_ready <= 1;
      end else begin
        rs_ready <= 0;
      end
    end
    begin // WorkCDB
      if (cdb[36]) begin : WorkCDBSignalFromALU
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
          if (rs_array_busy[i]) begin
            if (rs_array_qj[i][4] && rs_array_qj[i][3:0] == cdb[35:32]) begin
              rs_array_vj[i] <= cdb[31:0];
              rs_array_qj[i][4] <= 0;
            end
            if (rs_array_qk[i][4] && rs_array_qk[i][3:0] == cdb[35:32]) begin
              rs_array_vk[i] <= cdb[31:0];
              rs_array_qk[i][4] <= 0;
            end
          end
        end
      end
      if (cdb[73]) begin : WorkCDBSignalFromLSB
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
          if (rs_array_busy[i]) begin
            if (rs_array_qj[i][4] && rs_array_qj[i][3:0] == cdb[72:69]) begin
              rs_array_vj[i] <= cdb[68:37];
              rs_array_qj[i][4] <= 0;
            end
            if (rs_array_qk[i][4] && rs_array_qk[i][3:0] == cdb[72:69]) begin
              rs_array_vk[i] <= cdb[68:37];
              rs_array_qk[i][4] <= 0;
            end
          end
        end
      end
    end
    begin // WorkFlush
      if (flush) begin
        rs_array_busy[0] <= 0;
        rs_array_busy[1] <= 0;
        rs_array_busy[2] <= 0;
        rs_array_busy[3] <= 0;
        rs_array_busy[4] <= 0;
        rs_array_busy[5] <= 0;
        rs_array_busy[6] <= 0;
        rs_array_busy[7] <= 0;
        rs_array_busy[8] <= 0;
        rs_array_busy[9] <= 0;
        rs_array_busy[10] <= 0;
        rs_array_busy[11] <= 0;
        rs_array_busy[12] <= 0;
        rs_array_busy[13] <= 0;
        rs_array_busy[14] <= 0;
        rs_array_busy[15] <= 0;
        array_size = 0;
        alu_ready <= 0;
      end
    end
  end
end

endmodule