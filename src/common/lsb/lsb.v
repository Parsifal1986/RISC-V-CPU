module load_store_buffer (
  input wire clk,
  input wire rst,
  input wire rdy,
  
  input [95:0] instruction,
  input [1:0] ready,
  input [31:0] mem_data,

  input [73:0] cdb,

  input flush,
  input [3:0] head_tag,

  output reg [4:0] oprand,
  output reg [31:0] addr,
  output reg [31:0] data,

  output reg ls_done,
  output reg [3:0] ls_tag,
  output reg [31:0] ls_data,

  output reg ls_ready
);

reg [1:0] lsb_queue_busy[15:0];
reg [3:0] lsb_queue_tag[15:0];
reg [11:0] lsb_queue_imm[15:0];
reg [4:0] lsb_queue_addr_reg[15:0];
reg [4:0] lsb_queue_data_reg[15:0];
reg [31:0] lsb_queue_addr[15:0];
reg [31:0] lsb_queue_data[15:0];
reg [3:0] lsb_queue_op[15:0];

reg [3:0] head, tail;

reg [4:0] array_size;

integer size_change;

reg stop;

initial begin : initialize
  integer i;
  for (i = 0; i < 16; i = i + 1) begin
    lsb_queue_op[i] <= 0;
    lsb_queue_busy[i] <= 0;
    lsb_queue_tag[i] <= 0;
    lsb_queue_imm[i] <= 0;
    lsb_queue_addr_reg[i] <= 0;
    lsb_queue_data_reg[i] <= 0;
    lsb_queue_data[i] <= 0;
    lsb_queue_addr[i] <= 0;
  end
end

always @(posedge clk) begin
  if (rst) begin
    stop <= 0;
    head <= 0;
    tail <= 0;
    array_size <= 0;
    oprand <= 0;
    addr <= 0;
    data <= 0;
    ls_done <= 0;
    ls_tag <= 0;
    ls_data <= 0;
    ls_ready <= 0;
  end else if (!rdy) begin
  end else begin
    begin // WorkInput
      size_change = 0;
      if (instruction[1:0]) begin
        lsb_queue_busy[tail] <= instruction[1:0];
        lsb_queue_tag[tail] <= instruction[5:2];
        lsb_queue_imm[tail] <= instruction[17:6];
        if (cdb[36] && instruction[22] && instruction[21:18] == cdb[35:32]) begin
          lsb_queue_addr[tail] <= cdb[31:0];
          lsb_queue_addr_reg[tail] <= 0;
        end else if (cdb[73] && instruction[22] && instruction[21:18] == cdb[72:69]) begin
          lsb_queue_addr[tail] <= cdb[68:37];
          lsb_queue_addr_reg[tail] <= 0;
        end else begin
          lsb_queue_addr[tail] <= instruction[59:28];
          lsb_queue_addr_reg[tail] <= instruction[22:18];
        end
        if (cdb[36] && instruction[27] && instruction[26:23] == cdb[35:32]) begin
          lsb_queue_data[tail] <= cdb[31:0];
          lsb_queue_data_reg[tail] <= 0;
        end else if (cdb[73] && instruction[27] && instruction[26:23] == cdb[72:69]) begin
          lsb_queue_data[tail] <= cdb[68:37];
          lsb_queue_data_reg[tail] <= 0;
        end else begin
          lsb_queue_data[tail] <= instruction[91:60];
          lsb_queue_data_reg[tail] <= instruction[27:23];
        end
        lsb_queue_op[tail] <= instruction[95:92];
        tail <= flush ? 0 : tail + 1;
        size_change = size_change + 1;;
      end else begin
        tail <= flush ? 0 : tail;
      end

      if (ready[1]) begin
        lsb_queue_busy[head] <= 2'b00;
        ls_tag <= lsb_queue_tag[head];
        ls_data <= mem_data;
        ls_done <= flush ? 0 : 1;
        head <= flush ? 0 : (head + 1);
        size_change = size_change - 1;
        stop <= 0;
      end else begin
        ls_done <= 0;
        head <= flush ? 0 : head;
        stop <= flush ? 0 : stop;
      end

      if (array_size < 13) begin
        ls_ready <= 1;
      end else begin
        ls_ready <= 0;
      end
    end
    begin // WorkDependence
      if (cdb[36]) begin : Loop1
        integer k;
        for (k = 0; k < 16; k = k + 1) begin
          if (lsb_queue_data_reg[k][4] && lsb_queue_data_reg[k][3:0] == cdb[35:32]) begin
            lsb_queue_data[k] <= cdb[31:0];
            lsb_queue_data_reg[k][4] <= 0;
          end
          if (lsb_queue_addr_reg[k][4] && lsb_queue_addr_reg[k][3:0] == cdb[35:32]) begin
            lsb_queue_addr[k] <= cdb[31:0];
            lsb_queue_addr_reg[k][4] <= 0;
          end
        end
      end
      if (cdb[73]) begin : Loop2
        integer k;
        for (k = 0; k < 16; k = k + 1) begin
          if (lsb_queue_data_reg[k][4] && lsb_queue_data_reg[k][3:0] == cdb[72:69]) begin
            lsb_queue_data[k] <= cdb[68:37];
            lsb_queue_data_reg[k][4] <= 0;
          end
          if (lsb_queue_addr_reg[k][4] && lsb_queue_addr_reg[k][3:0] == cdb[72:69]) begin
            lsb_queue_addr[k] <= cdb[68:37];
            lsb_queue_addr_reg[k][4] <= 0;
          end
        end
      end
    end
    begin // WorkMem
      if (|array_size && ready && !stop && !lsb_queue_addr_reg[head][4] && !lsb_queue_data_reg[head][4] && lsb_queue_busy[head] == 2'b01 && ((!lsb_queue_op[head][3] && (lsb_queue_addr[head] != 32'h00030000 || (lsb_queue_addr[head] == 32'h00030000 && head_tag == lsb_queue_tag[head]))) || (lsb_queue_op[head][3] && head_tag == lsb_queue_tag[head]))) begin
        oprand <= flush ? 0 : {1'b1, lsb_queue_op[head]};
        addr <= $signed(lsb_queue_addr[head]) + $signed(lsb_queue_imm[head]);
        data <= lsb_queue_data[head];
        lsb_queue_busy[head] <= 2'b10;
        stop <= 1;
      end else begin
        oprand <= 0;
      end
    end
    array_size <= flush ? 0 : array_size + size_change;
  end
end

endmodule