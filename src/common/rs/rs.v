module reservation_station(
  input clk,
  input [118:0] rs_instruction,
  input [73:0] cdb,
  input flush,

  output reg rs_ready,
  output reg [5:0] alu_oprand,
  output reg [31:0] a,
  output reg [31:0] b,
  output reg [3:0] alu_tag,
  output reg alu_ready
);

reg [3:0] i;
reg [117:0] rs_array[15:0];
reg [3:0] array_size;
reg flag;

always @(posedge clk) begin
  begin // WorkInstruction
    flag = 0;
    if (rs_instruction) begin
      for (i = 0; i < 16 && !flag; i = i + 1) begin
        if (!rs_array[i][117]) begin
          rs_array[i] = rs_instruction;
          array_size = array_size + 1;
          flag = 1;
        end
      end
    end
  end
  begin // WorkArray
    flag = 0;
    alu_ready <= 0;
    for (i = 0; i < 16 && !flag; i = i + 1) begin
      if (rs_array[i][117]) begin
        if (!rs_array[i][46] && !rs_array[i][41]) begin
          alu_ready <= 1;
          alu_oprand <= rs_array[i][116:112];
          a <= rs_array[i][37:4];
          b <= rs_array[i][73:40];
          alu_tag <= rs_array[i][3:0];
          flag = 1;
          rs_array[i][118:117] = 2'b10;
        end
      end
    end
    if (array_size < 14) begin
      rs_ready <= 1;
    end else begin
      rs_ready <= 0;
    end
  end
  begin // WorkCDB
    if (cdb[36]) begin
      for (i = 0; i < 16; i = i + 1) begin
        if (rs_array[i][118:117]) begin
          if (rs_array[i][3:0] == cdb[35:32]) begin
            rs_array[i][36:5] = cdb[31:0];
            rs_array[i][118:117] = 0;
            array_size = array_size - 1;
          end
          if (rs_array[i][46] && rs_array[i][45:42] == cdb[35:32]) begin
            rs_array[i][111:79] = cdb[31:0];
            rs_array[i][46] = 0;
          end
          if (rs_array[i][41] && rs_array[i][40:37] == cdb[35:32]) begin
            rs_array[i][36:5] = cdb[31:0];
            rs_array[i][41] = 0;
          end
        end
      end
    end
    if (cdb[73]) begin
      for (i = 0; i < 16; i = i + 1) begin
        if (rs_array[i][118:117]) begin
          if (rs_array[i][3:0] == cdb[72:69]) begin
            rs_array[i][73:40] = cdb[68:37];
            rs_array[i][118:117] = 0;
            array_size = array_size - 1;
          end
          if (rs_array[i][46] && rs_array[i][45:42] == cdb[72:69]) begin
            rs_array[i][111:79] = cdb[68:37];
            rs_array[i][46] = 0;
          end
          if (rs_array[i][41] && rs_array[i][40:37] == cdb[72:69]) begin
            rs_array[i][73:40] = cdb[68:37];
            rs_array[i][41] = 0;
          end
        end
      end
    end
  end
  begin // WorkFlush
    if (flush) begin
      for (i = 0; i < 16; i = i + 1) begin
        rs_array[i] = 0;
      end
      array_size = 0;
      alu_ready <= 0;
    end
  end
end

endmodule