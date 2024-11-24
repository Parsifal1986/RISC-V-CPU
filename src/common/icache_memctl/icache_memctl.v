module icache_memctl(
  input wire clk,

  input wire [31:0] mem_addr_in,
  input wire [2:0] oprand,
  input wire [31:0] mem_data_in,
  input wire [31:0] instruction_addr,
  input wire need_instruction,

  input wire [7:0] mem_din,
  output reg [7:0] mem_dout,
  output reg [31:0] mem_addr_out,
  output reg mem_wr,

  output reg [31:0] mem_data,
  output reg [31:0] mem_ready,
  output reg [31:0] instruciton_data,
  output reg [31:0] instruciton_ready
);

reg [127:0] cache [127:0][8:0];
reg [20:0] cache_addr [127:0][8:0];
reg [127:0] current_reading_instruction;
reg [31:0] current_reading_instruction_addr;
reg [6:0] current_reading_instruction_place, k;
reg [2:0] victim;
reg [31:0] i;
reg [1:0] current_mem_length, current_mem_place;
reg current_mem_if_signed;
reg [31:0] current_mem_data;
reg flag;
reg length;

reg has_sent;

reg [33:0] mission [31:0]; // [33] = {is_instruction, is_read, addr}
reg [4:0] head, tail, array_size;

always @(posedge clk) begin
  begin // WorkInstruction
    instruciton_ready <= 0;
    flag = 0;
    if (need_instruction && !current_reading_instruction_addr) begin
      for (i = 0; i < 8 && !flag; i = i + 1) begin
        if (cache_addr[instruction_addr[10:4]][i] == instruction_addr[31:11]) begin
          instruciton_ready <= 1;
          case (instruction_addr[3:2])
            2'b00: instruciton_data <= cache[instruction_addr[10:4]][i][31:0];
            2'b01: instruciton_data <= cache[instruction_addr[10:4]][i][63:32];
            2'b10: instruciton_data <= cache[instruction_addr[10:4]][i][95:64];
            2'b11: instruciton_data <= cache[instruction_addr[10:4]][i][127:96];
          endcase
          flag = 1;
        end
      end
      if (!flag) begin
        for (i = 0; i < 16; i = i + 1) begin
          mission[tail] = {1'b1, 1'b1, instruction_addr[31:4], i[3:0], 2'b00};
          tail = tail + 1;
          array_size = array_size + 1;
        end
        current_reading_instruction_addr = instruction_addr;
        current_reading_instruction_place = 0;
        instruciton_ready <= 0;
      end
    end
  end
  begin // WorkMem
    if (oprand[20]) begin
      mem_ready <= 0;
      if (oprand[31]) begin
        current_mem_place = 0;
        case (oprand[2:0])
          3'b000: begin
            mission[tail] = {1'b0, 1'b1, mem_addr_in};
            tail = tail + 1;
            array_size = array_size + 1;
            current_mem_length = 1;
          end
          3'b100: begin
            mission[tail] = {1'b0, 1'b1, mem_addr_in};
            current_mem_if_signed = 1;
            tail = tail + 1;
            array_size = array_size + 1;
            current_mem_length = 1;
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
              current_mem_if_signed = 1;
              tail = tail + 1;
              array_size = array_size + 1;
            end
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
        current_mem_place = 0;
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
  begin // WorkMemRes
    if (array_size) begin
      if (has_sent) begin
        if (mission[head][33]) begin
          if (mission[head][32]) begin
            mem_addr_out <= mission[head][31:0];
            mem_wr <= 0;
            current_mem_data = (current_mem_data | mem_data_in << (current_mem_place << 3));
            current_mem_place = current_mem_place + 1;
            head = head + 1;
            array_size = array_size - 1;
            has_sent = 0;
          end
        end else begin
            mem_addr_out <= mission[head][31:0];
            mem_wr <= 0;
            current_reading_instruction = current_mem_data | mem_data_in << (current_mem_place << 3);
            current_reading_instruction_place = current_reading_instruction_place + 1;
            head = head + 1;
            array_size = array_size - 1;
            current_mem_data = 0;
            has_sent = 0;
        end
      end
      if (!has_sent) begin
        if (mission[head][33]) begin
          if (mission[head][32]) begin
            mem_addr_out <= mission[head][31:0];
            mem_wr <= 0;
            has_sent = 1;
          end else begin
            mem_addr_out <= mission[head][31:0];
            mem_dout <= ((current_mem_data >> (current_mem_place << 3)) & 8'hFF);
            mem_wr <= 1;
            current_mem_place = current_mem_place + 1;
            head = head + 1;
            array_size = array_size - 1;
            has_sent = 0;
          end
        end else begin
          mem_addr_out <= mission[head][31:0];
          mem_wr <= 0;
          has_sent = 1;
        end
      end
    end
  end
  begin // WorkMemOutput
    if (current_mem_place + 1 == current_mem_length) begin
      if (current_mem_if_signed) begin
        case (current_mem_length)
          1: current_mem_data <= $signed(current_mem_data[7]) ? {24'hFFFFFF, current_mem_data[7:0]} : {24'h000000, current_mem_data[7:0]};
          2: current_mem_data <= $signed(current_mem_data[15]) ? {16'hFFFF, current_mem_data[15:0]} : {16'h0000, current_mem_data[15:0]};
        endcase
      end
      mem_data <= current_mem_data;
      mem_ready <= 1;
    end
  end
  begin // WorkCache&InstructionOutput
    flag = 0;
    if (current_reading_instruction_place == 2'b11) begin
      for (i = 0; i < 8 && !flag; i = i + 1) begin
        if (!cache_addr[current_reading_instruction_addr[10:4]][i]) begin
          cache[current_reading_instruction_addr[10:4]][i] = current_reading_instruction;
          cache_addr[current_reading_instruction_addr[10:4]][i] = current_reading_instruction_addr[31:11];
          flag = 1;
        end
      end
      if (!flag) begin
        cache[current_reading_instruction_addr[10:4]][victim] = current_reading_instruction;
        cache_addr[current_reading_instruction_addr[10:4]][victim] = current_reading_instruction_addr[31:11];
        victim = victim + 1;
      end
      instruciton_ready <= 1;
      case (current_reading_instruction_addr[3:2])
        2'b00: instruciton_data <= current_reading_instruction[31:0];
        2'b01: instruciton_data <= current_reading_instruction[63:32];
        2'b10: instruciton_data <= current_reading_instruction[95:64];
        2'b11: instruciton_data <= current_reading_instruction[127:96];
      endcase
    end
  end
end

endmodule