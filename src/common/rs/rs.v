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

reg [31:0] i;

reg [118:0] rs_array[15:0];

reg [3:0] array_size;

integer flag;

always @(posedge clk) begin
  if (rst) begin
    for (i = 0; i < 16; i = i + 1) begin
      rs_array[i] = 0;
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
      flag = 16;
      if (rs_instruction) begin
        for (i = 0; i < 16; i = i + 1) begin
          if (!rs_array[i][118:117]) begin
            flag = i;
          end
        end
        if (flag != 16) begin
          rs_array[flag] = rs_instruction;
          array_size = array_size + 1;
        end
      end
    end
    begin // WorkArray
      flag = 16;
      alu_ready <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        if (rs_array[i][118:117] == 1 && !rs_array[i][46] && !rs_array[i][41]) begin
          flag = i;
        end
      end
      if (flag != 16) begin
        alu_ready <= 1;
        alu_oprand <= rs_array[flag][116:112];
        a <= rs_array[flag][110:79];
        b <= rs_array[flag][78:47];
        alu_tag <= rs_array[flag][3:0];
        rs_array[flag][118:117] = 2'b10;
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
              rs_array[i][110:79] = cdb[31:0];
              rs_array[i][46] = 0;
            end
            if (rs_array[i][41] && rs_array[i][40:37] == cdb[35:32]) begin
              rs_array[i][78:47] = cdb[31:0];
              rs_array[i][41] = 0;
            end
          end
        end
      end
      if (cdb[73]) begin
        for (i = 0; i < 16; i = i + 1) begin
          if (rs_array[i][118:117]) begin
            if (rs_array[i][3:0] == cdb[72:69]) begin
              rs_array[i][36:5] = cdb[68:37];
              rs_array[i][118:117] = 0;
              array_size = array_size - 1;
            end
            if (rs_array[i][46] && rs_array[i][45:42] == cdb[72:69]) begin
              rs_array[i][110:79] = cdb[68:37];
              rs_array[i][46] = 0;
            end
            if (rs_array[i][41] && rs_array[i][40:37] == cdb[72:69]) begin
              rs_array[i][78:47] = cdb[68:37];
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
end

endmodule