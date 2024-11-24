`include "src/common/queue/queue.v"

module ReorderBuffer(
  input clk,
  
  input [31:0] instruction,
  input [31:0] instruction_pc,
  
  input [31:0] alu_ready,
  input [31:0] ls_ready,

  input [73:0] cdb,

  input [4:0] bp_tag_in,

  input [36:0] register_file_read_data1,

  input flush_input,
  input if_jump,

  output reg flush_output,
  output reg [3:0] head_tag,
  output reg need_jump,

  output reg [4:0] register_file_read_addr1,
  output reg register_file_write_enable,
  output reg [4:0] register_file_write_addr,
  output reg [31:0] register_file_write_data,

  output reg [31:0] instruction_ready,
  output reg [31:0] instruction_jump_pc,
  
  output reg [118:0] rs_instruction, // busy : 2([118:117]), op : 5([116:112]), vj : 32([111:79]), vk : 32([78:47]), qj : 5([46:42]), qk : 5([41:37]), a : 32(36:5), dest : 5([4:0])

  output reg [123:0] lsb_instruction, // complete : 2(1:0), tag : 4(5:2), imm : 12(17:6), rs1 : 5(22:18), rd : 5(27:23), addr : 32(59:28), data : 32(91:60), oprand : 32(123:92)

  output reg [3:0] bp_tag_out,
  output reg bp_jump
);

reg [3:0] head, tail, i;
reg [31:0] size;

reg [105:0] rob_queue[15:0];  // busy : 1(104), instruction : 32(103:72), state : 2(71:70), dest : 5([69:65]), value : 32([64:33]), pc : 32([32:1]), flush : 1([0])
reg [31:0] current_instruction;

reg stop;
reg wait_signal;
reg book;

always @(posedge clk) begin
  if (register_file_write_enable) begin
    register_file_write_enable <= 0;
  end
  begin // WorkBP
    if (bp_tag_in[4]) begin
        rob_queue[bp_tag_in[3:0]][0] = 1;
    end
  end
  begin // WorkCDBBackData
    if (cdb[0]) begin
      rob_queue[cdb[36:33]][64:33] = cdb[31:0];
      rob_queue[cdb[36:33]][71:70] = 2'b10;
    end
    if (cdb[37]) begin
      rob_queue[cdb[73:70]][64:33] = cdb[69:38];
      rob_queue[cdb[73:70]][71:70] = 2'b10;
    end
  end
  begin // WorkEnQueue
    if (instruction && !stop) begin
      rob_queue[tail][104] = 1;
      rob_queue[tail][103:72] = instruction;
      rob_queue[tail][72:71] = 0;
      rob_queue[tail][70:66] = instruction[11:7];
      rob_queue[tail][65:34] = 0;
      rob_queue[tail][33:1] = instruction_pc;
      rob_queue[tail][0] = 0;
      tail = tail + 1;
      size = size + 1;
    end
    if (size < 14) begin
      instruction_ready <= 1;
    end else begin
      instruction_ready <= 0;
    end
  end
  begin //WorkFlush
    if (flush_input) begin
      head = 0;
      tail = 0;
      size = 0;
      bp_tag_out <= 0;
      lsb_instruction[5:2] <= 0;
      stop = 0;
    end
  end
  begin //WorkDecode
    bp_tag_out <= 0;
    lsb_instruction <= 0;
    rs_instruction <= 0;
    for (i = head; i != tail; i = i + 1) begin
      current_instruction = rob_queue[i][103:72];
      if (!book) begin
        if (rob_queue[i][104] == 0 && rob_queue[i][71:70] == 0) begin
            if (ls_ready) begin
          if (current_instruction[6:0] == 3 || current_instruction[6:0] == 35) begin
              lsb_instruction[5:2] <= i;
              case (current_instruction[6:0])
                3: 
                  begin
                    lsb_instruction[123:92] <= current_instruction[14:12];
                    register_file_read_addr1 = current_instruction[19:15];
                    if (register_file_read_data1[36:32]) begin
                      if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                        lsb_instruction[59:28] <= rob_queue[register_file_read_data1[36:32]][64:33];
                      end else begin
                        lsb_instruction[27:23] <= {1'b1, register_file_read_data1[36:32]};
                      end
                    end else begin
                      lsb_instruction[59:28] <= register_file_read_data1;
                    end
                    lsb_instruction[17:6] <= current_instruction[31:20];
                  end
                35:
                  begin
                    lsb_instruction[123:92] <= current_instruction[14:12] | 32'h10000000;
                    register_file_read_addr1 = current_instruction[19:15];
                    if (register_file_read_data1[36:32]) begin
                      if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                        lsb_instruction[59:28] <= rob_queue[register_file_read_data1[36:32]][64:33];
                      end else begin
                        lsb_instruction[27:23] <= {1'b1, register_file_read_data1[36:32]};
                      end
                    end else begin
                      lsb_instruction[59:28] <= register_file_read_data1;
                    end
                    register_file_read_addr1 = current_instruction[24:20];
                    if (register_file_read_data1[36:32]) begin
                      if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                        lsb_instruction[91:60] <= rob_queue[register_file_read_data1[36:32]][64:33];
                      end else begin
                        lsb_instruction[22:18] <= {1'b1, register_file_read_data1[36:32]};
                      end
                    end else begin
                      lsb_instruction[91:60] <= register_file_read_data1;
                    end
                    lsb_instruction[17:6] <= current_instruction[31] ? 32'hfffff000 | (current_instruction[31:25] << 5)
                                           | current_instruction[11:7] : current_instruction[31:25] << 5 | current_instruction[11:7];
                  end
              endcase
            end
          end else if (current_instruction[6:0] == 19 || current_instruction[6:0] == 51 ||
                      current_instruction[6:0] == 99 || current_instruction[6:0] == 103) begin
            if (alu_ready) begin
              case (current_instruction[6:0])
                19: begin
                  case (current_instruction[14:12])
                    3'b000: begin
                      rs_instruction[116:112] <= 0;
                    end
                    3'b111: begin
                      rs_instruction[116:112] <= 2;
                    end
                    3'b110: begin
                      rs_instruction[116:112] <= 3;
                    end
                    3'b100: begin
                      rs_instruction[116:112] <= 4;
                    end
                    3'b001: begin
                      rs_instruction[116:112] <= 5;
                    end
                    3'b101: begin
                      rs_instruction[116:112] <= 6;
                    end
                    3'b010: begin
                      rs_instruction[116:112] <= 8;
                    end
                    3'b011: begin
                      rs_instruction[116:112] <= 9;
                    end
                  endcase
                  if (current_instruction[14:12] == 3'b001 || current_instruction[14:12] == 3'b101) begin
                    rs_instruction[78:47] <= current_instruction[24:20];
                    if (current_instruction[31:25]) begin
                      rs_instruction[116:112] <= 7;
                    end
                  end else begin
                    rs_instruction[78:47] <= current_instruction[31:20];
                  end
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[111:79] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[46:42] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[111:79] <= register_file_read_data1[31:0];
                  end
                end
                51: begin
                  case (current_instruction[14:12]) 
                    3'b000: begin
                      if (current_instruction[31:25]) begin
                        rs_instruction[116:112] <= 1;
                      end else begin
                        rs_instruction[116:112] <= 0;
                      end
                    end
                    3'b111: begin
                      rs_instruction[116:112] <= 2;
                    end
                    3'b110: begin
                      rs_instruction[116:112] <= 3;
                    end
                    3'b100: begin
                      rs_instruction[116:112] <= 4;
                    end
                    3'b001: begin
                      rs_instruction[116:112] <= 5;
                    end
                    3'b101: begin
                      if (current_instruction[31:25]) begin
                        rs_instruction[116:112] <= 7;
                      end else begin
                        rs_instruction[116:112] <= 6;
                      end
                    end
                    3'b010: begin
                      rs_instruction[116:112] <= 8;
                    end
                    3'b011: begin
                      rs_instruction[116:112] <= 9;
                    end 
                  endcase
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[111:79] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[46:42] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[111:79] <= register_file_read_data1[31:0];
                  end
                  register_file_read_addr1 = current_instruction[24:20];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[78:47] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[41:37] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[78:47] <= register_file_read_data1[31:0];
                  end
                end
                99: begin
                  case (current_instruction[14:12])
                    3'b000: begin
                      rs_instruction[116:112] <= 10;
                    end 
                    3'b001: begin
                      rs_instruction[116:112] <= 11;
                    end
                    3'b101: begin
                      rs_instruction[116:112] <= 12;
                    end
                    3'b111: begin
                      rs_instruction[116:112] <= 13;
                    end
                    3'b100: begin
                      rs_instruction[116:112] <= 14;
                    end
                    3'b110: begin
                      rs_instruction[116:112] <= 15;
                    end
                  endcase
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[111:79] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[46:42] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[111:79] <= register_file_read_data1[31:0];
                  end
                  register_file_read_addr1 = current_instruction[24:20];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[78:47] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[41:37] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[78:47] <= register_file_read_data1[31:0];
                  end
                  bp_tag_out <= i;
                  bp_jump <= if_jump;
                end
                103: begin
                  rs_instruction[116:112] <= 0;
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[36:32]][71:70] == 2'b10) begin
                      rs_instruction[111:79] <= rob_queue[register_file_read_data1[36:32]][64:33];
                    end else begin
                      rs_instruction[46:42] <= {1'b1, register_file_read_data1[36:32]};
                    end
                  end else begin
                    rs_instruction[111:79] <= register_file_read_data1[31:0];
                  end
                  rs_instruction[78:47] <= current_instruction[31:20];
                  stop = 1;
                end
              endcase
              rs_instruction[4:0] <= i;
              rs_instruction[118:117] <= 2'b01;
            end
          end else if (current_instruction[6:0] == 111) begin
            rob_queue[i][71:70] = 2'b10;
            rob_queue[i][64:33] = rob_queue[i][32:1];
          end else if (current_instruction[6:0] == 55) begin
            rob_queue[i][71:70] = 2'b10;
            rob_queue[i][64:33] = current_instruction[31:12] << 12;
          end else if (current_instruction[6:0] == 23) begin
            rob_queue[i][71:70] = 2'b10;
            rob_queue[i][64:33] = current_instruction[31:12] << 12 + rob_queue[i][32:1];
          end
          register_file_read_addr1 = rob_queue[i][69:65];
          if (current_instruction[6:0] != 7'b0100011 && current_instruction[6:0] != 7'b1100011) begin
            register_file_write_addr <= rob_queue[i][69:65];
            register_file_write_data <= {i, register_file_read_data1[31:0]};
            register_file_write_enable <= 1;
          end
        end
      end
    end
  end
  begin // WorkDeQueue
    flush_output <= 0;
    head_tag <= head;
    need_jump <= 0;
    if (size && rob_queue[head][71:70] == 2'b10) begin
      if (rob_queue[head][103:72] == 32'h00000000) begin
        if (rob_queue[head][78:72] != 7'b0100011) begin
          if (rob_queue[head][78:76] != 3'b010 || rob_queue[head][78:72] == 103 || rob_queue[head][78:72] == 111) begin
            register_file_read_addr1 = rob_queue[head][69:65];
            register_file_write_enable <= 1;
            register_file_write_addr <= rob_queue[head][69:65];
            if (register_file_read_data1[36:32] == head) begin
              register_file_write_data <= rob_queue[head][64:33];
            end else begin
              register_file_write_data <= {register_file_read_data1[36:32], rob_queue[head][64:33]};
            end
          end
        end
        if (rob_queue[head][787:72] == 103) begin
          stop = 0;
          instruction_jump_pc <= rob_queue[head][64:33];
          need_jump <= 1;
          flush_output <= 1;
        end else if (rob_queue[head][78:72] == 99) begin
          if (!wait_signal) begin
            wait_signal = 1;
          end else begin
            wait_signal = 0;
          end
          if (rob_queue[head][0]) begin
            flush_output <= 0;
            if (rob_queue[head][64:33]) begin
              instruction_jump_pc <= rob_queue[head][32:1] + (rob_queue[head][103] ? 32'hfffff000 : 0) | (rob_queue[head][79] << 11) | (rob_queue[head][102:97] << 5) | (rob_queue[head][83:80] << 1);
            end else begin
              instruction_jump_pc <= rob_queue[head][32:1] + 4;
            end
            need_jump <= 1;
          end
        end
      end
      rob_queue[head][71:70] = 2'b11;
      rob_queue[head][104] = 0;
      head = head + 1;
      size = size - 1;
    end
  end
end

endmodule