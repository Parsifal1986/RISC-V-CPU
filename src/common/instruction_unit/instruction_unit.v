module instruction_unit(
  input wire clk,
  input wire rst,
  input wire rdy,

  input wire rob_ready,
  input wire[1:0] icache_ready,
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
  output reg [31:0] instruction_pc,
  output reg is_half_instruction,
  output reg if_jump_out,

  output reg [3:0] which_predictor
);

reg [65:0] instruction_queue [15:0];

reg [15:0] half_instruction;

reg [31:0] full_instruction;

reg [3:0] head, tail;

reg [31:0] next;

reg abandon;

reg [7:0] array_size;

reg [31:0] output_expanded;

reg [31:0] need_ins_pc;

reg flag;

initial begin : initialize
  integer i;
  for (i = 0; i < 16; i = i + 1) begin
    instruction_queue[i] = 0;
  end
end

always @(posedge clk) begin
  if (rst) begin
    head = 0;
    tail = 0;
    array_size = 0;
    instruction <= 0;
    addr <= 0;
    ready <= 0;
    program_counter <= 0;
    which_predictor <= 0;
    half_instruction = 0;
    full_instruction = 0;
    abandon = 0;
    next = 0;
  end else if (!rdy) begin
  end else begin
    begin // InputWork
      next = pc;
      if (icache_ready[1]) begin
        if (!abandon || (abandon && need_ins_pc == instruction_addr)) begin
          abandon = 0;
          if (!half_instruction) begin
            if (instruction_data[1:0] == 2'b11) begin
              instruction_queue[tail] = {instruction_data, instruction_addr};
              casez (instruction_data[6:0])
                7'b1100011: begin
                  which_predictor = instruction_data[14:12];
                  instruction_queue[tail][65] = if_jump;
                  if (if_jump) begin
                    next = instruction_addr + {{20{instruction_data[31]}}, instruction_data[7], instruction_data[30:25], instruction_data[11:8], 1'b0};
                    abandon = 1;
                    need_ins_pc = next;
                  end else begin
                    next = pc;
                  end
                end
                7'b1101111: begin
                  next = instruction_addr + {{12{instruction_data[31]}}, instruction_data[19:12], instruction_data[20], instruction_data[30:21], 1'b0};
                  abandon = 1;
                  need_ins_pc = next;
                end
                default: begin
                  
                end
              endcase
              tail = tail + 1;
              array_size = array_size + 1;
            end else begin
              flag = 0;
              RISCVC_To_RISCV(instruction_data[15:0], output_expanded);
              instruction_queue[tail] = {1'b1, output_expanded, instruction_addr};
              casez (output_expanded[6:0])
                7'b1100011: begin
                  which_predictor = output_expanded[14:12];
                  instruction_queue[tail][65] = if_jump;
                  if (if_jump) begin
                    next = instruction_addr + {{20{output_expanded[31]}}, output_expanded[7], output_expanded[30:25], output_expanded[11:8], 1'b0};
                    abandon = 1;
                    flag = 1;
                    need_ins_pc = next;
                  end else begin
                    next = pc;
                  end
                end
                7'b1101111: begin
                  next = instruction_addr + {{12{output_expanded[31]}}, output_expanded[19:12], output_expanded[20], output_expanded[30:21], 1'b0};
                  abandon = 1;
                  need_ins_pc = next;
                  flag = 1;
                end
                default: begin
                  
                end
              endcase
              tail = tail + 1;
              array_size = array_size + 1;
              if (!flag) begin
                if (instruction_data[17:16] == 2'b11) begin
                  half_instruction = instruction_data[31:16];
                end else begin
                  RISCVC_To_RISCV(instruction_data[31:16], output_expanded);
                  instruction_queue[tail] = {1'b1, output_expanded, instruction_addr + 2'b10};
                  casez (output_expanded[6:0])
                    7'b1100011: begin
                      which_predictor = output_expanded[14:12];
                      instruction_queue[tail][65] = if_jump;
                      if (if_jump) begin
                        next = instruction_addr + 2'b10 + {{20{output_expanded[31]}}, output_expanded[7], output_expanded[30:25], output_expanded[11:8], 1'b0};
                        abandon = 1;
                        need_ins_pc = next;
                      end else begin
                        next = pc;
                      end
                    end 
                    7'b1101111: begin
                      next = instruction_addr + 2'b10 + {{12{output_expanded[31]}}, output_expanded[19:12], output_expanded[20], output_expanded[30:21], 1'b0};
                      abandon = 1;
                      need_ins_pc = next;
                    end
                    default: begin
                      
                    end
                  endcase
                  tail = tail + 1;
                  array_size = array_size + 1;
                end
              end
            end
          end else begin
            flag = 0;
            full_instruction = {instruction_data[15:0], half_instruction};
            instruction_queue[tail] = {full_instruction, instruction_addr - 2'b10};
            half_instruction = 0;
            casez (full_instruction[6:0])
              7'b1100011: begin
                which_predictor = full_instruction[14:12];
                instruction_queue[tail][65] = if_jump;
                if (if_jump) begin
                  next = instruction_addr - 2'b10 + {{20{full_instruction[31]}}, full_instruction[7], full_instruction[30:25], full_instruction[11:8], 1'b0};
                  abandon = 1;
                  flag = 1;
                  need_ins_pc = next;
                end else begin
                  next = pc;
                end
              end
              7'b1101111: begin
                next = instruction_addr - 2'b10 + {{12{full_instruction[31]}}, full_instruction[19:12], full_instruction[20], full_instruction[30:21], 1'b0};
                abandon = 1;
                need_ins_pc = next;
                flag = 1;
              end
              default: begin
                
              end
            endcase
            tail = tail + 1;
            array_size = array_size + 1;
            if (!flag) begin
              if (instruction_data[17:16] == 2'b11) begin
                half_instruction = instruction_data[31:16];
              end else begin
                RISCVC_To_RISCV(instruction_data[31:16], output_expanded);
                instruction_queue[tail] = {1'b1, output_expanded, instruction_addr + 2'b10};
                casez (output_expanded[6:0])
                  7'b1100011: begin
                    which_predictor = output_expanded[14:12];
                    instruction_queue[tail][65] = if_jump;
                    if (if_jump) begin
                      next = instruction_addr + 2'b10 + {{20{output_expanded[31]}}, output_expanded[7], output_expanded[30:25], output_expanded[11:8], 1'b0};
                      abandon = 1;
                      need_ins_pc = next;
                    end else begin
                      next = pc;
                    end
  
                  end  
                  7'b1101111: begin
                    next = instruction_addr + 2'b10 + {{12{output_expanded[31]}}, output_expanded[19:12], output_expanded[20], output_expanded[30:21], 1'b0};
                    abandon = 1;
                    need_ins_pc = next;
  
                  end
                  default: begin
                    
                  end
                endcase
                tail = tail + 1;
                array_size = array_size + 1;
              end
            end
          end
        end
      end
      if (need_jump) begin
        next = jump_addr;
      end
      if (array_size < 14 && icache_ready) begin
        addr <= next;
        program_counter <= (next + 4); 
        ready <= 1;
      end else begin
        program_counter <= next;
        ready <= 0;
      end
    end
    begin // QueueWork
      if (array_size == 0 || !rob_ready) begin
        instruction <= 0;
      end else begin
        instruction <= instruction_queue[head][63:32];
        instruction_pc <= instruction_queue[head][31:0];
        is_half_instruction <= instruction_queue[head][64];
        if_jump_out <= instruction_queue[head][65];
        head = head + 1;
        array_size = array_size - 1;
      end
    end
    begin // Flush
      if (flush) begin
        abandon = 0;
        array_size = 0;
        head = 0;
        tail = 0;
        instruction <= 0;
        half_instruction = 0;
        full_instruction = 0;
      end
    end
  end
end

task RISCVC_To_RISCV (
    input [15:0] compressed_instr,  // 输入压缩指令 (16 位)
    output reg [31:0] expanded_instr     // 输出扩展指令 (32 位)
);

begin
    // $display("Compressed instruction: %b", compressed_instr);
    casez (compressed_instr[1:0])
        2'b00: begin
            decode_opcode_00(compressed_instr, expanded_instr);
        end
        2'b01: begin
            decode_opcode_01(compressed_instr, expanded_instr);
        end
        2'b10: begin
            decode_opcode_10(compressed_instr, expanded_instr);
        end
        default: expanded_instr = 0;
    endcase
end


endtask

task decode_opcode_00(
    input [15:0] compressed_instr,
    output reg [31:0] expanded_instr
);
begin
    casez (compressed_instr[15:13])
        3'b000: begin // C.ADDI4SPN
            expanded_instr = {
                2'b00, compressed_instr[10:7], compressed_instr[12:11], compressed_instr[5], compressed_instr[6], 2'b00, // Immediate
                5'b00010, // rs1 = x2 (sp)
                3'b000, 2'b01, compressed_instr[4:2], // rd
                7'b0010011 // ADDI opcode
            };
        end
        3'b010: begin // C.LW
            expanded_instr = {
                5'b00000, compressed_instr[5], compressed_instr[12:10], compressed_instr[6], 2'b00, // Immediate
                2'b01, compressed_instr[9:7], // rs1
                3'b010, // funct3
                2'b01, compressed_instr[4:2], // rd
                7'b0000011 // LW opcode
            };
        end
        3'b110: begin // C.SW
            expanded_instr = {
                5'b00000, compressed_instr[5], compressed_instr[12], // Immediate
                2'b01, compressed_instr[4:2], // rs2
                2'b01, compressed_instr[9:7], // rs1
                3'b010, // funct3
                compressed_instr[11:10], compressed_instr[6], 2'b00, // Immediate (split)
                7'b0100011 // SW opcode
            };
        end
        default: expanded_instr = 0; // NOP
    endcase
end
endtask

task decode_opcode_01(
    input [15:0] compressed_instr,
    output reg [31:0] expanded_instr
);
    begin
        casez (compressed_instr[15:13])
            3'b000: begin // C.ADDI
                expanded_instr = {
                    {7{compressed_instr[12]}}, compressed_instr[6:2], // Immediate (sign-extended)
                    compressed_instr[11:7], // rd
                    3'b000, compressed_instr[11:7], // rs1
                    7'b0010011 // ADDI opcode
                };
            end
            3'b001: begin // C.JAL
                expanded_instr = {
                    compressed_instr[12], compressed_instr[8], compressed_instr[10:9], compressed_instr[6], compressed_instr[7], compressed_instr[2], compressed_instr[11], compressed_instr[5:3], {9{compressed_instr[12]}}, // Sign-extended immediate
                    5'b00001, // rd = ra
                    7'b1101111 // JAL opcode
                };
            end
            3'b101: begin // C.J
                expanded_instr = {
                    compressed_instr[12], compressed_instr[8], compressed_instr[10:9], compressed_instr[6], compressed_instr[7], compressed_instr[2], compressed_instr[11], compressed_instr[5:3], {9{compressed_instr[12]}}, // Sign-extended immediate
                    5'b00000, // rd = x0
                    7'b1101111 // JAL opcode
                };
            end
            3'b110: begin // C.BEQZ
                expanded_instr = {
                    {4{compressed_instr[12]}}, compressed_instr[6:5], compressed_instr[2], // Immediate1
                    5'b00000, // rs2 = x0
                    2'b01, compressed_instr[9:7], // rs1
                    3'b000, // BEQZ
                    compressed_instr[11:10], compressed_instr[4:3], compressed_instr[12], // Immediate2
                    7'b1100011 // BRANCH opcode
                };
            end
            3'b111: begin // C.BNEZ
                expanded_instr = {
                    {4{compressed_instr[12]}}, compressed_instr[6:5], compressed_instr[2], // Immediate1
                    5'b00000, // rs2 = x0
                    2'b01, compressed_instr[9:7], // rs1
                    3'b001, // BNEZ
                    compressed_instr[11:10], compressed_instr[4:3], compressed_instr[12], // Immediate2
                    7'b1100011 // BRANCH opcode
                };
            end
            3'b010: begin // C.LI
                expanded_instr = {
                    {7{compressed_instr[12]}}, compressed_instr[6:2], // Immediate
                    5'b00000, // rs1 = x0
                    3'b000, compressed_instr[11:7], // rd
                    7'b0010011 // ADDI opcode
                };
            end
            3'b011: begin // C.LUI
                if (compressed_instr[11:7] && compressed_instr[11:7] != 5'b00010) begin
                    expanded_instr = {
                        {15{compressed_instr[12]}}, compressed_instr[6:2], compressed_instr[11:7], // rd
                        7'b0110111 // LUI opcode
                    };
                end else begin // C.ADDI16SP
                    expanded_instr = {
                        {3{compressed_instr[12]}}, compressed_instr[4:3], compressed_instr[5], compressed_instr[2], compressed_instr[6], 4'b0000, // Immediate (sign-extended)
                        5'b00010, // rd
                        3'b000, 5'b00010, // rs1
                        7'b0010011 // ADDI opcode
                    };
                end
            end
            3'b100: begin
                casez (compressed_instr[11:10])
                    2'b00: begin
                        expanded_instr = {
                            6'b000000, compressed_instr[12], compressed_instr[6:2], // Immediate
                            2'b01, compressed_instr[9:7], // rd
                            3'b101, 2'b01, compressed_instr[9:7], // rs1
                            7'b0010011 // SRLI opcode
                        };
                    end
                    2'b01: begin
                        expanded_instr = {
                            6'b010000, compressed_instr[12], compressed_instr[6:2], // Immediate
                            2'b01, compressed_instr[9:7], // rd
                            3'b101, 2'b01, compressed_instr[9:7], // rs1
                            7'b0010011 // SRAI opcode
                        };
                    end
                    2'b10: begin
                        expanded_instr = {
                            {7{compressed_instr[12]}}, compressed_instr[6:2], // Immediate
                            2'b01, compressed_instr[9:7], // rd
                            3'b111, 2'b01, compressed_instr[9:7], // rs1
                            7'b0010011 // ANDI opcode
                        };
                    end
                    3'b11: begin
                      casez (compressed_instr[6:5])
                        2'b11: begin
                            expanded_instr = {
                                7'b0000000, 2'b01, compressed_instr[4:2], // rs2
                                2'b01, compressed_instr[9:7], // rs1
                                3'b000, 2'b01, compressed_instr[9:7], // rd
                                7'b0110011 // AND opcode
                            };
                        end
                        2'b10: begin
                            expanded_instr = {
                                7'b0100000, 2'b01, compressed_instr[4:2], // rs2
                                2'b01, compressed_instr[9:7], // rs1
                                3'b110, 2'b01, compressed_instr[9:7], // rd
                                7'b0110011 // OR opcode
                            };
                        end
                        2'b01: begin
                            expanded_instr = {
                                7'b0000000, 2'b01, compressed_instr[4:2], // rs2
                                2'b01, compressed_instr[9:7], // rs1
                                3'b100, 2'b01, compressed_instr[9:7], // rd
                                7'b0110011 // XOR opcode
                            };
                        end
                        2'b00: begin
                            expanded_instr = {
                                7'b0100000, 2'b01, compressed_instr[4:2], // rs2
                                2'b01, compressed_instr[9:7], // rs1
                                3'b000, 2'b01, compressed_instr[9:7], // rd
                                7'b0110011 // SUB opcode
                            };
                        end
                        default: begin
                          
                        end
                      endcase
                    end
                    default: begin
                      
                    end
                endcase
            end
            default: expanded_instr = 0; // NOP
        endcase
    end
endtask

task decode_opcode_10(
    input [15:0] compressed_instr,
    output reg [31:0] expanded_instr
);
    begin
        casez (compressed_instr[15:13])
            3'b000: begin // C.SLLI
                expanded_instr = {
                    6'b000000, compressed_instr[12], compressed_instr[6:2], // Immediate
                    compressed_instr[11:7], // rd
                    3'b001, compressed_instr[11:7], // rs1
                    7'b0010011 // SLLI opcode
                };
            end
            3'b100: begin
                casez (compressed_instr[12])
                    1'b0: begin // C.JR | C.MV
                        if (compressed_instr[6:2]) begin
                            expanded_instr = {
                                7'b0000000, compressed_instr[6:2], // rs2
                                5'b00000, // rs1
                                3'b000, compressed_instr[11:7], // rd
                                7'b0110011 // ADD opcode
                            };
                        end else begin
                            expanded_instr = {
                                12'b000000000000, // imm
                                compressed_instr[11:7], // rs1
                                3'b000, 5'b00000, // rd
                                7'b1100111 // JALR opcode
                            };
                        end
                    end
                    1'b1: begin // C.JALR | C.ADD
                        if (compressed_instr[6:2]) begin
                            expanded_instr = {
                                7'b0000000, compressed_instr[6:2], // rs2
                                compressed_instr[11:7], // rs1
                                3'b000, compressed_instr[11:7], // rd
                                7'b0110011 // ADD opcode
                            };
                        end else begin
                            expanded_instr = {
                                12'b000000000000, // imm
                                compressed_instr[11:7], // rs1
                                3'b000, 5'b00001, // rd
                                7'b1100111 // JALR opcode
                            };
                        end
                    end
                    default: expanded_instr = 0; // NOP
                endcase
            end
            3'b010: begin
              expanded_instr = {
                4'b0000, compressed_instr[3:2], compressed_instr[12], compressed_instr[6:4], 2'b00,
                5'b00010, 3'b010, compressed_instr[11:7], 7'b0000011
              };
            end
            3'b110: begin
              expanded_instr = {
                4'b0000, compressed_instr[8:7], compressed_instr[12],
                compressed_instr[6:2], 5'b00010, 3'b010, compressed_instr[11:9], 2'b00,
                7'b0100011
              };
            end
            default: expanded_instr = 0; // NOP
        endcase
    end
endtask

endmodule