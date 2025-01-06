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

reg [95:0] lsb_queue[15:0];

reg [3:0] head, tail, i;

reg [4:0] array_size, k;

integer rst_i;

reg stop;

reg flag;

reg [3:0] processing_pos;

always @(posedge clk) begin
  if (rst) begin
    stop = 0;
    head = 0;
    tail = 0;
    array_size = 0;
    oprand <= 0;
    addr <= 0;
    data <= 0;
    ls_done <= 0;
    ls_tag <= 0;
    ls_data <= 0;
    ls_ready <= 0;
    processing_pos = 0;
    for (rst_i = 0; rst_i < 16; rst_i = rst_i + 1) begin
      lsb_queue[rst_i] = 0;
    end
  end else if (!rdy) begin
  end else begin
    ls_done <= 0;
    ls_tag <= 0;
    ls_data <= 0;
    begin // WorkInput
      if (instruction[1:0]) begin
        lsb_queue[tail] = instruction;
        tail = tail + 1;
        array_size = array_size + 1;
      end

      flag = 0;
      if (ready[1]) begin
        // for (k = 0; k < 16; k = k + 1) begin : Loop1
        //   // if (k < array_size) begin
        //     i = k + head;
        //     if (lsb_queue[i][1:0] == 2'b10) begin
        lsb_queue[processing_pos][91:60] = mem_data;
        lsb_queue[processing_pos][1:0] = 2'b11;
              // disable Loop1;
            // end
          // end
        // end
      end

      if (array_size < 14) begin
        ls_ready <= 1;
      end else begin
        ls_ready <= 0;
      end
    end
    begin // WorkDependence
      if (cdb[36]) begin
        for (k = 0; k < 16; k = k + 1) begin
          if (lsb_queue[k][1:0] == 2'b01) begin
            if (lsb_queue[k][27] && lsb_queue[k][26:23] == cdb[35:32]) begin
              lsb_queue[k][91:60] = cdb[31:0];
              lsb_queue[k][27] = 0;
            end
            if (lsb_queue[k][22] && lsb_queue[k][21:18] == cdb[35:32]) begin
              lsb_queue[k][59:28] = cdb[31:0];
              lsb_queue[k][22] = 0;
            end
          end
        end
      end
      if (cdb[73]) begin
        for (k = 0; k < 16; k = k + 1) begin
          if (lsb_queue[k][1:0] == 2'b01) begin
            if (lsb_queue[k][27] && lsb_queue[k][26:23] == cdb[72:69]) begin
              lsb_queue[k][91:60] = cdb[68:37];
              lsb_queue[k][27] = 0;
            end
            if (lsb_queue[k][22] && lsb_queue[k][21:18] == cdb[72:69]) begin
              lsb_queue[k][59:28] = cdb[68:37];
              lsb_queue[k][22] = 0;
            end
          end
        end
      end
    end
    begin // WorkOutput
      ls_done <= 0;
      if (lsb_queue[head][1:0] == 2'b11 && array_size) begin
        ls_tag <= lsb_queue[head][5:2];
        ls_data <= lsb_queue[head][91:60];
        ls_done <= 1;
        head = head + 1;
        array_size = array_size - 1;
      end
    end
    begin // WorkMem
      flag = 0;
      oprand <= 0;
      addr <= 0;
      for (k = 0; k < 16; k = k + 1) begin
        if (k < array_size && !flag) begin
          i = k + head;
          if (lsb_queue[i][95] == 0) begin
            if (lsb_queue[i][27] == 0 && lsb_queue[i][22] == 0 && lsb_queue[i][1:0] == 2'b01 && ready && !stop) begin
              oprand <= {1'b1, lsb_queue[i][95:92]};
              addr <= $signed(lsb_queue[i][59:28]) + $signed(lsb_queue[i][17:6]);
              lsb_queue[i][1:0] = 2'b10;
              stop <= 1;
              flag = 1;
              processing_pos = i;
            end
          end else begin
            flag = 1;
          end
        end
      end
      // $display("lsb_queue[%d] = %b, its tag is : %d", head, lsb_queue[head], lsb_queue[head][5:2]);
      if (lsb_queue[head][95] && lsb_queue[head][1:0] == 2'b01 && head_tag == lsb_queue[head][5:2] && array_size && ready && !stop) begin
        oprand <= {1'b1, lsb_queue[head][95:92]};
        addr <= $signed(lsb_queue[head][59:28]) + $signed(lsb_queue[head][17:6]);
        data <= lsb_queue[head][91:60];
        lsb_queue[head][1:0] = 2'b10;
        processing_pos = head;
        stop <= 1;
      end
      if (stop) begin
        stop <= 0;
      end
    end
    begin // WorkFlush
      if (flush) begin
        head = 0;
        tail = 0;
        array_size = 0;
        oprand <= 0;
        ls_done <= 0;
      end
    end
  end
end

endmodule