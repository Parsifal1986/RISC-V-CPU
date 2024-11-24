// RISCV32 CPU top module
// port modification allowed for debugging purposes

`include "src/common/register_file/register_file.v"
`include "src/common/alu/alu.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
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

wire [73:0] cdb; // cdb[32:1] for alu_data, cdb[0] for alu_done, cdb[36:33] for alu_tag, cdb[69:38] for ls_data, cdb[37] for ls_done, cdb[73:70] for ls_tag

wire register_file_write_enable;
wire [4:0] register_file_write_addr;
wire [31:0] register_file_write_data;
wire [4:0] register_file_read_addr1;
wire [4:0] register_file_read_addr2;
wire [36:0] register_file_read_data1;
wire [36:0] register_file_read_data2;

reg [31:0] pc;
reg [31:0] jump;
reg [31:0] head_tag;
reg need_jump;
reg flush;

wire [31:0] alu_a;
wire [31:0] alu_b;
wire [4:0] alu_op;
wire [3:0] alu_tag;

register_file rf_unit(
  .clk(clk_in),
  .read_addr1(register_file_read_addr1),
  .read_addr2(register_file_read_addr2),
  .write_addr(register_file_write_addr),
  .write_enable(register_file_write_enable),
  .write_data(register_file_write_data),
  .read_data1(register_file_read_data1),
  .read_data2(register_file_read_data2)
);



alu alu_unit(
  .clk(clk_in),
  .a(alu_a),
  .b(alu_b),
  .alu_op(alu_op),
  .tag(alu_tag),
  .cdb_alu_data(cdb[31:0]),
  .cdb_alu_tag(cdb[35:32]),
  .cdb_alu_done(cdb[36])
);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule