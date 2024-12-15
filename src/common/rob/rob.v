module reorder_buffer(
  input clk,
  input wire rst,
  input wire rdy,
  
  input [31:0] instruction,
  input [31:0] instruction_pc,
  input is_half_instruction,
  input instruction_if_jumped,
  
  input alu_ready,
  input ls_ready,

  input [73:0] cdb,

  input [4:0] bp_tag_in,

  input [36:0] register_file_read_data1,

  input flush_input,

  output reg flush_output,
  output reg [3:0] head_tag,
  output reg need_jump,

  output reg [4:0] register_file_read_addr1,
  output reg register_file_write_enable1,
  output reg [4:0] register_file_write_addr1,
  output reg [36:0] register_file_write_data1,
  output reg register_file_write_enable2,
  output reg [4:0] register_file_write_addr2,
  output reg [36:0] register_file_write_data2,

  output reg instruction_ready,
  output reg [31:0] instruction_jump_pc,
  
  output reg [118:0] rs_instruction_out, // busy : 2([118:117]), op : 5([116:112]), vj : 32([110:79]), vk : 32([78:47]), qj : 5([46:42]), qk : 5([41:37]), a : 32(36:5), dest : 5([4:0])

  output reg [123:0] lsb_instruction_out, // complete : 2(1:0), tag : 4(5:2), imm : 12(17:6), rs1 : 5(22:18), rs2 : 5(27:23), addr : 32(59:28), data : 32(91:60), oprand : 32(123:92)

  output reg [3:0] branch_type,
  output reg [3:0] bp_tag_out,
  output reg bp_jump,
  output reg bp_has_predict
);

reg [3:0] head, tail, i;
reg [31:0] size;

reg [106:0] rob_queue[15:0]; //if_jump(106), is_half(105), busy : 1(104), instruction : 32(103:72), state : 2(71:70), dest : 5([69:65]), value : 32([64:33]), pc : 32([32:1]), flush : 1([0])
reg [31:0] current_instruction;

reg [118:0] rs_instruction;
reg [123:0] lsb_instruction;

wire [106:0] head_element;
wire [31:0] head_pc;

assign head_element = rob_queue[head];
assign head_pc = head_element[32:1];

reg stop;
reg wait_signal;
reg book;

integer rst_i;

// integer file_handle;

// initial begin
//   file_handle = $fopen("rob_queue", "w");
// end

always @(posedge clk) begin
  if (rst) begin
    head = 0;
    tail = 0;
    size = 0;
    flush_output = 0;
    head_tag = 0;
    need_jump = 0;
    register_file_read_addr1 = 0;
    register_file_write_enable1 = 0;
    register_file_write_addr1 = 0;
    register_file_write_data1 = 0;
    instruction_ready = 0;
    instruction_jump_pc = 0;
    rs_instruction = 0;
    lsb_instruction = 0;
    branch_type = 0;
    bp_tag_out = 0;
    bp_jump = 0;
    bp_has_predict = 0;
    stop = 0;
    wait_signal = 0;
    book = 0;
    for (rst_i = 0; rst_i < 16; rst_i = rst_i + 1) begin
      rob_queue[rst_i] = 0;
    end
  end else if (!rdy) begin
  end else begin
    if (register_file_write_enable1) begin
      register_file_write_enable1 <= 0;
    end
    if (register_file_write_enable2) begin
      register_file_write_enable2 <= 0;
    end
    begin // WorkBP
      if (bp_tag_in[4]) begin
          rob_queue[bp_tag_in[3:0]][0] = 1;
      end
    end
    begin // WorkCDBBackData
      if (cdb[36]) begin
        rob_queue[cdb[35:32]][64:33] = cdb[31:0];
        rob_queue[cdb[35:32]][71:70] = 2'b10;
      end
      if (cdb[73]) begin
        rob_queue[cdb[72:69]][64:33] = cdb[68:37];
        rob_queue[cdb[72:69]][71:70] = 2'b10;
      end
    end
    begin // WorkEnQueue
      if (instruction && !stop) begin
        rob_queue[tail][106] = instruction_if_jumped;
        rob_queue[tail][105] = is_half_instruction;
        rob_queue[tail][104] = 1;
        rob_queue[tail][103:72] = instruction;
        rob_queue[tail][71:70] = 0;
        rob_queue[tail][69:65] = instruction[11:7];
        rob_queue[tail][64:33] = 0;
        rob_queue[tail][32:1] = instruction_pc;
        rob_queue[tail][0] = 0;
        tail = tail + 1;
        size = size + 1;
      end
      if (size < 14) begin
        instruction_ready <= (1 & !stop);
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
        rs_instruction[4:0] <= 0;
        stop = 0;
        register_file_write_enable1 = 0;
        register_file_write_enable2 = 0;
      end
    end
    begin //WorkDecode
      bp_tag_out <= 0;
      lsb_instruction <= 0;
      rs_instruction <= 0;
      book = 0;
      bp_tag_out <= 0;
      bp_jump <= 0;
      bp_has_predict <= 0;
      // for (i = head; i != tail; i = i + 1) begin
      //   $display("rob_queue[%d].state = %d", i, rob_queue[i][71:70]);
      //   $display("rob_queue[%d].addr = %h", i, rob_queue[i][32:1]);
      //   $display("rob_queue[%d].instruction = %h", i, rob_queue[i][103:72]);
      // end
      // $display("");
      for (i = head; i != tail && !book; i = i + 1) begin
        current_instruction = rob_queue[i][103:72];
        if (rob_queue[i][104] == 1 && rob_queue[i][71:70] == 0) begin
          if (current_instruction[6:0] == 3 || current_instruction[6:0] == 35) begin
            if (ls_ready) begin
              lsb_instruction[5:2] = i;
              case (current_instruction[6:0])
                3:  begin
                  lsb_instruction[123:92] = current_instruction[14:12];
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      lsb_instruction[59:28] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      lsb_instruction[22:18] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    lsb_instruction[59:28] = register_file_read_data1[31:0];
                  end
                  lsb_instruction[17:6] = current_instruction[31:20];
                end
                35: begin
                  lsb_instruction[123:92] = current_instruction[14:12] | 32'h80000000;
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      lsb_instruction[59:28] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      lsb_instruction[22:18] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    lsb_instruction[59:28] = register_file_read_data1[31:0];
                  end
                  register_file_read_addr1 = current_instruction[24:20];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      lsb_instruction[91:60] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      lsb_instruction[27:23] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    lsb_instruction[91:60] = register_file_read_data1[31:0];
                  end
                  lsb_instruction[17:6] = {current_instruction[31:25], current_instruction[11:7]};
                end
              endcase
              rob_queue[i][71:70] = 2'b01;
              book = 1;
            end
          end else if (current_instruction[6:0] == 19 || current_instruction[6:0] == 51 ||
                      current_instruction[6:0] == 99 || current_instruction[6:0] == 103) begin
            if (alu_ready) begin
              case (current_instruction[6:0])
                19: begin
                  case (current_instruction[14:12])
                    3'b000: begin
                      rs_instruction[116:112] = 0;
                    end
                    3'b111: begin
                      rs_instruction[116:112] = 2;
                    end
                    3'b110: begin
                      rs_instruction[116:112] = 3;
                    end
                    3'b100: begin
                      rs_instruction[116:112] = 4;
                    end
                    3'b001: begin
                      rs_instruction[116:112] = 5;
                    end
                    3'b101: begin
                      rs_instruction[116:112] = 6;
                    end
                    3'b010: begin
                      rs_instruction[116:112] = 8;
                    end
                    3'b011: begin
                      rs_instruction[116:112] = 9;
                    end
                  endcase
                  if (current_instruction[14:12] == 3'b001 || current_instruction[14:12] == 3'b101) begin
                    if (current_instruction[31:25]) begin
                      rs_instruction[116:112] = 7;
                    end
                    rs_instruction[78:47] = current_instruction[24:20];
                  end else begin
                    rs_instruction[78:47] = $signed(current_instruction[31:20]);
                  end
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      rs_instruction[110:79] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      rs_instruction[46:42] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    rs_instruction[110:79] = register_file_read_data1[31:0];
                  end
                end
                51: begin
                  case (current_instruction[14:12]) 
                    3'b000: begin
                      if (current_instruction[31:25]) begin
                        rs_instruction[116:112] = 1;
                      end else begin
                        rs_instruction[116:112] = 0;
                      end
                    end
                    3'b111: begin
                      rs_instruction[116:112] = 2;
                    end
                    3'b110: begin
                      rs_instruction[116:112] = 3;
                    end
                    3'b100: begin
                      rs_instruction[116:112] = 4;
                    end
                    3'b001: begin
                      rs_instruction[116:112] = 5;
                    end
                    3'b101: begin
                      if (current_instruction[31:25]) begin
                        rs_instruction[116:112] = 7;
                      end else begin
                        rs_instruction[116:112] = 6;
                      end
                    end
                    3'b010: begin
                      rs_instruction[116:112] = 8;
                    end
                    3'b011: begin
                      rs_instruction[116:112] = 9;
                    end 
                  endcase
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      rs_instruction[110:79] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      rs_instruction[46:42] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    rs_instruction[110:79] = register_file_read_data1[31:0];
                  end
                  register_file_read_addr1 = current_instruction[24:20];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      rs_instruction[78:47] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      rs_instruction[41:37] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    rs_instruction[78:47] = register_file_read_data1[31:0];
                  end
                end
                99: begin
                  case (current_instruction[14:12])
                    3'b000: begin
                      rs_instruction[116:112] = 10;
                    end 
                    3'b001: begin
                      rs_instruction[116:112] = 11;
                    end
                    3'b101: begin
                      rs_instruction[116:112] = 12;
                    end
                    3'b111: begin
                      rs_instruction[116:112] = 13;
                    end
                    3'b100: begin
                      rs_instruction[116:112] = 14;
                    end
                    3'b110: begin
                      rs_instruction[116:112] = 15;
                    end
                  endcase
                  register_file_read_addr1 = current_instruction[19:15];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      rs_instruction[110:79] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      rs_instruction[46:42] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    rs_instruction[110:79] = register_file_read_data1[31:0];
                  end
                  register_file_read_addr1 = current_instruction[24:20];
                  if (register_file_read_data1[36:32]) begin
                    if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                      rs_instruction[78:47] = rob_queue[register_file_read_data1[35:32]][64:33];
                    end else begin
                      rs_instruction[41:37] = {1'b1, register_file_read_data1[35:32]};
                    end
                  end else begin
                    rs_instruction[78:47] = register_file_read_data1[31:0];
                  end
                  bp_tag_out <= i;
                  branch_type <= current_instruction[14:12];
                  bp_jump <= rob_queue[i][106];
                  bp_has_predict <= 1;
                end
                // 103: begin
                //   rs_instruction[116:112] = 0;
                //   register_file_read_addr1 = current_instruction[19:15];
                //   if (register_file_read_data1[36:32]) begin
                //     if (rob_queue[register_file_read_data1[35:32]][71:70] == 2'b10) begin
                //       rs_instruction[110:79] = rob_queue[register_file_read_data1[35:32]][64:33];
                //     end else begin
                //       rs_instruction[46:42] = {1'b1, register_file_read_data1[35:32]};
                //     end
                //   end else begin
                //     rs_instruction[110:79] = register_file_read_data1[31:0];
                //   end
                //   rs_instruction[78:47] = current_instruction[31:20];
                //   stop = 1;
                // end
              endcase
              rs_instruction[4:0] = i;
              rs_instruction[118:117] = 2'b01;
              rob_queue[i][71:70] = 2'b01;
              book = 1;
            end
          end else if (current_instruction[6:0] == 103) begin
            rob_queue[i][71:70] <= 2'b10;
            rob_queue[i][64:33] = rob_queue[i][32:1] + (3'b100 >> rob_queue[i][105]);
            stop = 1;
            // book = 1;
          end else if (current_instruction[6:0] == 111) begin
            rob_queue[i][71:70] <= 2'b10;
            rob_queue[i][64:33] = rob_queue[i][32:1] + (3'b100 >> rob_queue[i][105]);
            // book = 1;
          end else if (current_instruction[6:0] == 55) begin
            rob_queue[i][71:70] <= 2'b10;
            rob_queue[i][64:33] = current_instruction[31:12] << 12;
            // book = 1;
          end else if (current_instruction[6:0] == 23) begin
            rob_queue[i][71:70] <= 2'b10;
            rob_queue[i][64:33] = current_instruction[31:12] << 12 + rob_queue[i][32:1];
            // book = 1;
          end
          register_file_read_addr1 = rob_queue[i][69:65];
          if (current_instruction[6:0] != 7'b0100011 && current_instruction[6:0] != 7'b1100011) begin
            register_file_write_addr1 <= rob_queue[i][69:65];
            register_file_write_data1 <= {1'b1, i, register_file_read_data1[31:0]};
            register_file_write_enable1 <= 1;
          end
        end
      end
      lsb_instruction_out <= lsb_instruction;
      rs_instruction_out <= rs_instruction;
    end
    begin // WorkDeQueue
      flush_output <= 0;
      head_tag <= head;
      need_jump <= 0;
      if (size && rob_queue[head][71:70] == 2'b10) begin : DeQueue
        if (rob_queue[head][78:72] != 7'b0100011) begin
          if (rob_queue[head][78:76] != 3'b110) begin
            register_file_read_addr1 = rob_queue[head][69:65];
            register_file_write_enable2 <= 1;
            register_file_write_addr2 <= rob_queue[head][69:65];
            if (register_file_read_data1[36] && register_file_read_data1[35:32] == head) begin
              register_file_write_data2 <= {5'b00000, rob_queue[head][64:33]};
            end else begin
              register_file_write_data2 <= {register_file_read_data1[36:32], rob_queue[head][64:33]};
            end
          end else if (rob_queue[head][78:72] == 103 || rob_queue[head][78:72] == 111) begin
            register_file_read_addr1 = rob_queue[head][69:65];
            register_file_write_enable2 <= 1;
            register_file_write_addr2 <= rob_queue[head][69:65];
            if (register_file_read_data1[36] && register_file_read_data1[35:32] == head) begin
              register_file_write_data2 <= {5'b00000, rob_queue[head][64:33]};
            end else begin
              register_file_write_data2 <= {register_file_read_data1[36:32], rob_queue[head][64:33]};
            end
          end
        end
        if (rob_queue[head][78:72] == 103) begin
          stop = 0;
          current_instruction = rob_queue[head][103:72];
          register_file_read_addr1 = current_instruction[19:15];
          instruction_jump_pc <= register_file_read_data1[31:0] + current_instruction[31:20];
          need_jump <= 1;
          flush_output <= 1;
        end else if (rob_queue[head][78:72] == 99) begin
          if (!wait_signal) begin
            wait_signal = 1;
            disable DeQueue;
          end else begin
            wait_signal = 0;
          end
          if (rob_queue[head][0]) begin
            flush_output <= 1;
            if (!rob_queue[head][106]) begin
              instruction_jump_pc <= rob_queue[head][32:1] + {{20{rob_queue[head][103]}}, rob_queue[head][79], rob_queue[head][102:97], rob_queue[head][83:80], 1'b0};
            end else begin
              instruction_jump_pc <= rob_queue[head][32:1] + (3'b100 >> rob_queue[head][105]);
              // $display("rob_queue[head].addr = %d", rob_queue[head][32:1]);
            end
            // $display("instruction_jump_pc = %d", instruction_jump_pc);
            need_jump <= 1;
          end
        end
        rob_queue[head][71:70] = 2'b11;
        rob_queue[head][104] = 0;
        // $fdisplay(file_handle, "excute instruction %h", rob_queue[head][103:72]);
        // $fdisplay(file_handle, "%t", $time);
        head = head + 1;
        size = size - 1;
      end
    end
  end
end

endmodule