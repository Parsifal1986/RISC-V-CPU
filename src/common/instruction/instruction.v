module instruction_data(
  input wire clk,

  input wire instruction_ready,
  input wire[31:0] instruction_addr,
  input wire[31:0] instruction_data,
  input wire[31:0] jump_addr,

  input wire if_jump,
  input wire need_jump,

  input flush,

  input wire [31:0] pc,
  
  output reg [31:0] addr,
  output reg ready,
  output reg [31:0] program_counter,
  output reg [31:0] instruction,

  output reg [2:0] which_predictor
);

reg [63:0] instruction_queue [127:0];

reg [6:0] head, tail;

reg [31:0] next;

reg abandon;

reg [7:0] array_size;

always @(posedge clk) begin
  begin // InputWork
    next = pc;
    if (instruction_data && !abandon) begin
      instruction_queue[tail] = {instruction_data, instruction_addr};
      tail = tail + 1;
      array_size = array_size + 1;
      if (instruction_data[6:4] == 3'b110) begin
        if (instruction_data[6:0] == 7'b1100011) begin
          which_predictor = instruction_data[14:12];
          next = if_jump ? instruction_addr + ((instruction_data[31] ? 32'hfffff000 : 0) | (instruction_data[7] << 11) | (instruction_data[30:25] << 5) | (instruction_data[11:8] << 1)) : pc;
          program_counter <= next;
          if (if_jump) begin
            abandon <= 1;
          end
        end else if (instruction_data[6:0] == 7'b1101111) begin
          next = instruction_addr + ((instruction_data[31] ? 32'hfff00000 : 0) | (instruction_data[19:12] << 12) | (instruction_data[20] << 11) | (instruction_data[30:21] << 1));
          abandon <= 1;
          program_counter <= next;
        end
      end
      if (instruction_data == 32'h0ff00513) begin
        abandon <= 1;
        ready <= 0;
        // need a return command
      end
      if (need_jump) begin
        next = jump_addr;
        program_counter <= next;
        abandon <= 1;
      end
      if (abandon) begin
        abandon <= 0;
      end
      if (array_size) begin
        addr <= next;
        program_counter <= (next + 4);
        ready <= 1;
      end else begin
        ready <= 0;
      end
    end
  end
  begin // QueueWork
    if (array_size == 0 || !ready) begin
      instruction <= 0;
    end
    instruction <= instruction_queue[head][63:32];
    program_counter <= instruction_queue[head][31:0];
    head = head + 1;
    array_size = array_size - 1;
  end
  begin // Flush
    if (flush) begin
      abandon = 0;
      array_size = 0;
      head = 0;
      tail = 0;
      instruction <= 0;
    end
  end
end

endmodule