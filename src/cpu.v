// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [14:0]          dbg_info,
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire [73:0] cdb; // cdb[31:0] for alu_data, cdb[36] for alu_done, cdb[35:32] for alu_tag, cdb[68:37] for ls_data, cdb[73] for ls_done, cdb[72:69] for ls_tag

reg [31:0] pc;
reg [3:0] head_tag;
reg need_jump;
wire flush;

wire [31:0] alu_a;
wire [31:0] alu_b;
wire [4:0] alu_op;
wire [3:0] alu_tag;

wire [31:0] instruction_rob_instruction;
wire [31:0] instruction_rob_instruction_addr;

wire [31:0] icache_instruction_data;
wire [31:0] icache_instruction_addr;

wire rs_rob_alu_ready;
wire lsb_rob_ls_ready;

wire [4:0] bp_rob_tag_in;

wire bp_if_jump;

wire rob_instruction_flush;

wire ins_if_jump;

wire rob_instruction_instruction_ready;
wire [31:0] rob_instruction_instruction_jump_pc;

wire [118:0] rob_rs_instruction;

wire [95:0] rob_lsb_instruction;

wire [3:0] rob_bp_tag_out;

wire rs_alu_ready;

wire [1:0] icache_instruction_ready;

wire [3:0] branch_type;
wire [3:0] which_predictor;

wire [31:0] instruction_unit_icache_addr;

wire [1:0] memctl_lsb_mem_ready;

wire [4:0] lsb_memctl_oprand;
wire [31:0] lsb_memctl_addr;
wire [31:0] lsb_memctl_data;

wire [31:0] memctl_lsb_data;

wire instruction_unit_icache_ready;

wire rob_bp_has_predict;

wire [3:0] rob_head_tag_set;
wire rob_need_jump_set;

wire [31:0] pc_set;

wire instruction_unit_rob_is_half_instruction;

wire instruction_rob_if_jump;
wire [14:0] first_pc;
wire [31:0] dbg_data;

assign flush = rob_instruction_flush;

alu alu_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  
  .alu_ready(rs_alu_ready),
  .a(alu_a),
  .b(alu_b),
  .alu_op(alu_op),
  .tag(alu_tag),
  .flush(flush),

  .cdb_alu_data(cdb[31:0]),
  .cdb_alu_tag(cdb[35:32]),
  .cdb_alu_done(cdb[36])
);

branch_predictor bp(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .has_predict(rob_bp_has_predict),
  .jp(ins_if_jump),
  .tag(rob_bp_tag_out),
  .branch_type(branch_type),
  
  .cdb(cdb),
  
  .which_predictor(which_predictor),
  
  .flush(flush),
  
  .bp_tag(bp_rob_tag_in),
  .jump(bp_if_jump)
);

load_store_buffer lsb_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .instruction(rob_lsb_instruction),
  .ready(memctl_lsb_mem_ready),
  .mem_data(memctl_lsb_data),

  .cdb(cdb),
  .flush(flush),
  .head_tag(head_tag),

  .oprand(lsb_memctl_oprand),
  .addr(lsb_memctl_addr),
  .data(lsb_memctl_data),

  .ls_done(cdb[73]),
  .ls_tag(cdb[72:69]),
  .ls_data(cdb[68:37]),

  .ls_ready(lsb_rob_ls_ready)
);

reorder_buffer rob_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .instruction(instruction_rob_instruction),
  .instruction_pc(instruction_rob_instruction_addr),
  .is_half_instruction(instruction_unit_rob_is_half_instruction),
  .instruction_if_jumped(instruction_rob_if_jump),
  
  .alu_ready(rs_rob_alu_ready),
  .ls_ready(lsb_rob_ls_ready),
  
  .cdb(cdb),
  
  .bp_tag_in(bp_rob_tag_in),
  
  .flush_input(flush),
  
  .flush_output(rob_instruction_flush),
  .head_tag(rob_head_tag_set),
  .need_jump(rob_need_jump_set),

  .instruction_ready(rob_instruction_instruction_ready),
  .instruction_jump_pc(rob_instruction_instruction_jump_pc),

  .rs_instruction_out(rob_rs_instruction),

  .lsb_instruction_out(rob_lsb_instruction),
  
  .branch_type(branch_type),
  .bp_tag_out(rob_bp_tag_out),
  .bp_jump(ins_if_jump),
  .bp_has_predict(rob_bp_has_predict),
  .first_ins_pc(first_pc)
);

reservation_station rs_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .rs_instruction(rob_rs_instruction),
  .cdb(cdb),
  .flush(flush),
  .rs_ready(rs_rob_alu_ready),
  .alu_oprand(alu_op),
  .a(alu_a),
  .b(alu_b),
  .alu_tag(alu_tag),
  .alu_ready(rs_alu_ready)
);

icache_memctl icache_memctl_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .mem_addr_in(lsb_memctl_addr),
  .oprand(lsb_memctl_oprand),
  .mem_data_in(mem_din),
  .mem_write_data(lsb_memctl_data),
  .instruction_addr(instruction_unit_icache_addr),
  .need_instruction(instruction_unit_icache_ready),
  .io_buffer_full(io_buffer_full),

  .mem_dout(mem_dout),
  .mem_addr_out(mem_a),
  .mem_wr(mem_wr),
  .flush(flush),
  
  .mem_data(memctl_lsb_data),
  .mem_ready(memctl_lsb_mem_ready),
  .instruction_data(icache_instruction_data),
  .instruction_addr_out(icache_instruction_addr),
  .instruction_ready(icache_instruction_ready)
);

instruction_unit instruction_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  
  .rob_ready(rob_instruction_instruction_ready),
  .icache_ready(icache_instruction_ready),
  .instruction_addr(icache_instruction_addr),
  .instruction_data(icache_instruction_data),
  .jump_addr(rob_instruction_instruction_jump_pc),

  .if_jump(bp_if_jump),
  .need_jump(need_jump),

  .flush(flush),

  .pc(pc),

  .addr(instruction_unit_icache_addr),
  .ready(instruction_unit_icache_ready),
  .program_counter(pc_set),
  .instruction(instruction_rob_instruction),
  .instruction_pc(instruction_rob_instruction_addr),
  .is_half_instruction(instruction_unit_rob_is_half_instruction),
  .if_jump_out(instruction_rob_if_jump),
  
  .which_predictor(which_predictor)
);

always @(negedge clk_in) begin
  need_jump = rob_need_jump_set;
  head_tag = rob_head_tag_set;
  pc = pc_set;
end

endmodule