module icache_memctl(
  input wire clk,
  input wire rst,
  input wire rdy,

  input wire [31:0] mem_addr_in,
  input wire [31:0] oprand,
  input wire [31:0] mem_write_data,

  input wire [31:0] instruction_addr,
  input wire need_instruction,

  input wire [7:0] mem_data_in,

  input wire flush,

  output reg [7:0] mem_dout,
  output reg [31:0] mem_addr_out,
  output reg mem_wr,

  output reg [31:0] mem_data,
  output reg [1:0] mem_ready,
  output reg [31:0] instruction_data,
  output reg [31:0] instruction_addr_out,
  output reg [1:0] instruction_ready
);

reg has_next_instruction;
reg [7:0] cache [8191:0][1:0];
reg [18:0] cache_addr [8191:0][1:0];
reg [31:0] current_reading_instruction;
reg [31:0] current_reading_instruction_addr;
reg [31:0] next_reading_instruction_addr;
reg [3:0] current_reading_instruction_place;
reg current_mem_if_write;
reg [6:0] k;
reg victim;
reg [31:0] i, j;
reg [31:0] current_mem_length, current_mem_place;
reg current_mem_if_signed;
reg [31:0] current_mem_data;
reg [31:0] tmp, tmp2;
reg flag;
reg length;

reg [34:0] has_sent[1:0];

reg [33:0] mission [31:0]; // [33] = {is_instruction, is_read, addr}
reg [4:0] head, tail, array_size;

wire [33:0] mission_head;

assign mission_head = mission[head];

always @(posedge clk) begin
  if (rst) begin
    mem_dout <= 0;
    mem_addr_out <= 0;
    mem_wr <= 0;
    mem_data <= 0;
    mem_ready <= 0;
    instruction_data <= 0;
    instruction_addr_out <= 0;
    instruction_ready <= 0;
    for (i = 0; i < 8192; i = i + 1) begin
      for (j = 0; j < 2; j = j + 1) begin
        cache_addr[i][j] = 0;
        cache[i][j] = 0;
      end
    end
    current_reading_instruction = 0;
    current_reading_instruction_addr = 0;
    current_reading_instruction_place = 0;
    current_mem_length = 0;
    current_mem_place = 0;
    current_mem_if_signed = 0;
    current_mem_data = 0;
    current_mem_if_write = 0;
    tmp = 0;
    tmp2 = 0;
    flag = 0;
    victim = 0;
    head = 0;
    tail = 0;
    array_size = 0;
    has_sent[0] = 0;
    has_sent[1] = 0;
  end else if (!rdy) begin
  end else begin
    begin // WorkInstruction
      instruction_ready <= 0;
      instruction_data <= 0;
      mem_addr_out <= 0;
      mem_dout <= 0;
      flag = 0;
      if (need_instruction || has_next_instruction) begin
        if (!current_reading_instruction_place) begin
          if (has_next_instruction) begin
            has_next_instruction = 0;
          end
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2 && !flag; j = j + 1) begin
              tmp = instruction_addr[13:0] + i;
              if (cache_addr[tmp][j][18] && cache_addr[tmp][j][17:0] == instruction_addr[31:14]) begin
                // $display("cache_addr = %d, instruction_addr = %d", cache_addr[tmp][j][17:0], instruction_addr[31:0]);
                // $display("cache_data = %h", cache[tmp][j]);
                current_reading_instruction = (current_reading_instruction | cache[tmp][j] << (i << 3));
                flag = 1;
                // $display("current_reading_instruction = %h", current_reading_instruction);
              end
            end
            if (!flag) begin
              current_reading_instruction_place = current_reading_instruction_place | (1 << i);
              mission[tail] = {1'b1, 1'b1, instruction_addr[31:0] + i};
              tail = tail + 1;
              array_size = array_size + 1;
            end
            flag = 0;
          end
          if (current_reading_instruction_place) begin
            current_reading_instruction_addr = instruction_addr;
          end else begin
            instruction_ready[1] <= 1;
            instruction_data <= current_reading_instruction;
            instruction_addr_out <= instruction_addr;
            current_reading_instruction = 0;
            current_reading_instruction_addr = 0;
          end
          // for (i = 0; i < 8 && !flag; i = i + 1) begin // deprecated
          //   if (cache_addr[instruction_addr[10:4]][i] == instruction_addr[31:11]) begin
          //     instruction_ready <= 1;
          //     case (instruction_addr[3:2])
          //       2'b00: instruction_data <= cache[instruction_addr[10:4]][i][31:0];
          //       2'b01: instruction_data <= cache[instruction_addr[10:4]][i][63:32];
          //       2'b10: instruction_data <= cache[instruction_addr[10:4]][i][95:64];
          //       2'b11: instruction_data <= cache[instruction_addr[10:4]][i][127:96];
          //     endcase
          //     flag = 1;
          //   end
          // end
          // if (!flag) begin
          //   for (i = 0; i < 16; i = i + 1) begin
          //     mission[tail] = {1'b1, 1'b1, instruction_addr[31:4], i[3:0], 2'b00};
          //     tail = tail + 1;
          //     array_size = array_size + 1;
          //   end
          //   current_reading_instruction_addr = instruction_addr;
          //   current_reading_instruction_place = 0;
          //   instruction_ready <= 0;
          // end
        end else begin
          has_next_instruction = 1;
        end
      end
    end
    begin // WorkMem
      if (oprand[20]) begin
        current_mem_place = 0;
        if (!oprand[31]) begin
          current_mem_data = 0;
          current_mem_if_write = 0;
          current_mem_if_signed = 0;
          case (oprand[2:0])
            3'b000: begin
              mission[tail] = {1'b0, 1'b1, mem_addr_in};
              current_mem_length = 1;
              tail = tail + 1;
              array_size = array_size + 1;
            end
            3'b100: begin
              mission[tail] = {1'b0, 1'b1, mem_addr_in};
              current_mem_if_signed = 1;
              current_mem_length = 1;
              tail = tail + 1;
              array_size = array_size + 1;
            end
            3'b001: begin
              for (i = 0; i < 2; i = i + 1) begin
                mission[tail] = {1'b0, 1'b1, mem_addr_in + i};
                tail = tail + 1;
                array_size = array_size + 1;
              end
              current_mem_length = 2;
            end
            3'b101: begin
              for (i = 0; i < 2; i = i + 1) begin
                mission[tail] = {1'b0, 1'b1, mem_addr_in + i};
                tail = tail + 1;
                array_size = array_size + 1;
              end
              current_mem_if_signed = 1;
              current_mem_length = 2;
            end
            3'b010: begin
              for (i = 0; i < 4; i = i + 1) begin
                mission[tail] = {1'b0, 1'b1, mem_addr_in + i};
                tail = tail + 1;
                array_size = array_size + 1;
              end
              current_mem_length = 4;
            end
          endcase
        end else begin
          current_mem_data = mem_write_data;
          current_mem_if_write = 1;
          case (oprand[2:0])
            3'b000: begin
              current_mem_length = 1;
              mission[tail] = {1'b0, 1'b0, mem_addr_in};
              tail = tail + 1;
              array_size = array_size + 1;
            end
            3'b001: begin
              current_mem_length = 2;
              for (i = 0; i < 2; i = i + 1) begin
                mission[tail] = {1'b0, 1'b0, mem_addr_in + i};
                tail = tail + 1;
                array_size = array_size + 1;
              end
            end
            3'b010: begin
              current_mem_length = 4;
              for (i = 0; i < 4; i = i + 1) begin
                mission[tail] = {1'b0, 1'b0, mem_addr_in + i};
                tail = tail + 1;
                array_size = array_size + 1;
              end
            end
          endcase
        end
      end
    end
    begin // WorkFlush
      if (flush) begin
        has_next_instruction = 0;
        current_reading_instruction = 0;
        current_reading_instruction_addr = 0;
        next_reading_instruction_addr = 0;
        current_reading_instruction_place = 0;
        instruction_data <= 0;
        instruction_addr_out <= 0;
        instruction_ready <= 2'b01;
        current_mem_if_write = 0;
        current_mem_length = 0;
        current_mem_place = 0;
        current_mem_if_signed = 0;
        current_mem_data = 0;
        has_sent[0] = 0;
        has_sent[1] = 0;
        for (i = 0; i < 32; i++) begin
          mission [i] = 0;
        end
        head = 0;
        tail = 0;
        array_size = 0;
      end
    end
    begin // WorkMemRes
      mem_wr <= 0;
      if (has_sent[1][34]) begin
        if (!has_sent[1][33]) begin
          if (has_sent[1][32]) begin
            current_mem_data = (current_mem_data | mem_data_in << (current_mem_place << 3));
            current_mem_place = current_mem_place + 1;
          end
        end else begin
          tmp2 = current_reading_instruction_place & -current_reading_instruction_place;
          case (tmp2)
            4'b0001: current_reading_instruction = current_reading_instruction | mem_data_in;
            4'b0010: current_reading_instruction = current_reading_instruction | mem_data_in << 8;
            4'b0100: current_reading_instruction = current_reading_instruction | mem_data_in << 16;
            4'b1000: current_reading_instruction = current_reading_instruction | mem_data_in << 24;
          endcase
          current_reading_instruction_place = current_reading_instruction_place ^ tmp2[3:0];
          for (j = 0; j < 2 && !flag; j = j + 1) begin
            if (!cache_addr[has_sent[1][13:0]][j][18]) begin
              cache[has_sent[1][13:0]][j] = mem_data_in;
              cache_addr[has_sent[1][13:0]][j] = {1'b1, has_sent[1][31:14]};
              flag = 1;
            end
          end
          if (!flag) begin
            cache[has_sent[1][13:0]][victim] = mem_data_in;
            cache_addr[has_sent[1][13:0]][victim] = {1'b1, has_sent[1][31:14]};
            victim = !victim;
          end
          if (current_reading_instruction_place == 0) begin
            instruction_addr_out <= current_reading_instruction_addr;
            instruction_data <= current_reading_instruction;
            instruction_ready[1] <= 1;
            current_reading_instruction = 0;
            current_reading_instruction_addr = 0;
          end
        end
      end
      has_sent[1] = has_sent[0];
      has_sent[0] = 0;
      if (array_size) begin
        if (!mission[head][33]) begin
          if (mission[head][32]) begin
            mem_addr_out <= mission[head][31:0];
            has_sent[0] = {1'b1, mission[head]};
            head = head + 1;
            array_size = array_size - 1;
          end else begin
            // if (!has_sent[1]) begin
              mem_addr_out <= mission[head][31:0];
              mem_dout <= ((current_mem_data >> (current_mem_place << 3)) & 8'hFF);
              mem_wr <= 1;
              current_mem_place = current_mem_place + 1;
              head = head + 1;
              array_size = array_size - 1;
            // end
          end
        end else begin
          mem_addr_out <= mission[head][31:0];
          has_sent[0] = {1'b1, mission[head]};
          head = head + 1;
          array_size = array_size - 1;
        end
      end
    end
    begin // WorkMemOutput
      mem_ready <= 0;
      if (current_mem_place == current_mem_length) begin
        if (current_mem_length) begin
          mem_ready[1] <= 1;
        end
        if (!current_mem_if_write) begin
          if (current_mem_if_signed) begin
            case (current_mem_length)
              1: current_mem_data = current_mem_data[7] ? {24'hFFFFFF, current_mem_data[7:0]} : {24'h000000, current_mem_data[7:0]};
              2: current_mem_data = current_mem_data[15] ? {16'hFFFF, current_mem_data[15:0]} : {16'h0000, current_mem_data[15:0]};
            endcase
          end
          mem_data <= current_mem_data;
        end else begin
          mem_data <= 1;
        end
        current_mem_place = 0;
        current_mem_length = 0;;
        mem_ready[0] <= 1;
      end
    end
    begin // Work InstructionOutput
      if (current_reading_instruction_place == 0) begin
        instruction_ready[0] <= 1;
      end
    end
    // begin // WorkCache&InstructionOutput // deprecated
    //   flag = 0;
    //   if (current_reading_instruction_place == 2'b11) begin
    //     for (i = 0; i < 8 && !flag; i = i + 1) begin
    //       if (!cache_addr[current_reading_instruction_addr[10:4]][i]) begin
    //         cache[current_reading_instruction_addr[10:4]][i] = current_reading_instruction;
    //         cache_addr[current_reading_instruction_addr[10:4]][i] = current_reading_instruction_addr[31:11];
    //         flag = 1;
    //       end
    //     end
    //     if (!flag) begin
    //       cache[current_reading_instruction_addr[10:4]][victim] = current_reading_instruction;
    //       cache_addr[current_reading_instruction_addr[10:4]][victim] = current_reading_instruction_addr[31:11];
    //       victim = victim + 1;
    //     end
    //     instruction_ready <= 1;
    //     case (current_reading_instruction_addr[3:2])
    //       2'b00: instruction_data <= current_reading_instruction[31:0];
    //       2'b01: instruction_data <= current_reading_instruction[63:32];
    //       2'b10: instruction_data <= current_reading_instruction[95:64];
    //       2'b11: instruction_data <= current_reading_instruction[127:96];
    //     endcase
    //   end
    // end
  end
end

endmodule