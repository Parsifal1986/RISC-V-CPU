module load_store_buffer (
  input wire clk,
  input wire rst,
  input wire rdy,
  
  input [123:0] instruction,
  input [1:0] ready,
  input [31:0] mem_data,

  input [73:0] cdb,

  input flush,
  input [3:0] head_tag,

  output reg [31:0] oprand,
  output reg [31:0] addr,
  output reg [31:0] data,

  output reg ls_done,
  output reg [3:0] ls_tag,
  output reg [31:0] ls_data,

  output reg ls_ready
);

reg [123:0] lsb_queue[15:0];

reg [3:0] head, tail;

reg [3:0] array_size = 0, i;

integer rst_i;

reg stop = 0;

reg flag;

always @(posedge clk) begin
  if (rst) begin
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
    for (rst_i = 0; rst_i < 16; rst_i = rst_i + 1) begin
      lsb_queue[rst_i] = 0;
    end
  end else if (!rdy) begin
  end else begin
    ls_done <= 0;
    ls_tag <= 0;
    ls_data <= 0;
    begin // WorkInput
      if (instruction) begin
        lsb_queue[tail] = instruction;
        tail = tail + 1;
        array_size = array_size + 1;
      end

      flag = 0;
      if (ready[1]) begin
        for (i = head; i != tail && !flag; i = i + 1) begin
          if (lsb_queue[i][1:0] == 2'b01) begin
            lsb_queue[i][91:60] = mem_data;
            lsb_queue[i][1:0] = 2'b10;
            flag = 1;
          end
        end
      end

      if (array_size < 14) begin
        ls_ready <= 1;
      end else begin
        ls_ready <= 0;
      end
    end
    begin // WorkDependence
      if (cdb[36]) begin
        for (i = head; i != tail; i = i + 1) begin
          if (!lsb_queue[i][1:0]) begin
            if (lsb_queue[i][26:23] == cdb[35:32] && lsb_queue[i][27]) begin
              lsb_queue[i][91:60] = cdb[31:0];
              lsb_queue[i][27] = 0;
            end
            if (lsb_queue[i][21:18] == cdb[35:32] && lsb_queue[i][22]) begin
              lsb_queue[i][59:28] = cdb[31:0];
              lsb_queue[i][22] = 0;
            end
          end
        end
      end
      if (cdb[73]) begin
        // $display("cdb[72:69] = %d", cdb[72:69]);
        // for (i = head; i != tail; i = i + 1) begin
        //   $display("lsb_queue[%d] = %b, its dependency : %d", i, lsb_queue[i], lsb_queue[i][26:23]);
        // end
        for (i = head; i != tail; i = i + 1) begin
          if (!lsb_queue[i][1:0]) begin
            if (lsb_queue[i][26:23] == cdb[72:69] && lsb_queue[i][27]) begin
              lsb_queue[i][91:60] = cdb[68:37];
              lsb_queue[i][27] = 0;
              // $display("lsb_queue[%d] = %b, its dependency : %d", i, lsb_queue[i], lsb_queue[i][26:23]);
            end
            if (lsb_queue[i][21:18] == cdb[72:69] && lsb_queue[i][22]) begin
              lsb_queue[i][59:28] = cdb[68:37];
              lsb_queue[i][22] = 0;
            end
          end
        end
      end
    end
    begin // WorkOutput
      ls_done <= 0;
      if (lsb_queue[head][1:0] == 2'b10 && array_size) begin
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
      for (i = head; i != tail && !flag; i = i + 1) begin
        // $display("lsb_queue[%d] = %b, its tag is : %d, its denpendency : %d", i, lsb_queue[i], lsb_queue[i][5:2], lsb_queue[i][21:18]);
        if (!lsb_queue[i][123]) begin
          if (!lsb_queue[i][27] && !lsb_queue[i][22] && !lsb_queue[i][1:0]) begin
            if (ready && !stop) begin
              oprand <= lsb_queue[i][123:92] | (1<<20);
              addr <= $signed(lsb_queue[head][59:28]) + $signed(lsb_queue[head][17:6]);
              lsb_queue[i][1:0] = 2'b01;
              flag = 1;
              stop <= 1;
            end
          end
        end else begin
          flag = 1;
        end
      end
      // $display("lsb_queue[%d] = %b, its tag is : %d", head, lsb_queue[head], lsb_queue[head][5:2]);
      if (lsb_queue[head][123] && !lsb_queue[head][1:0] && head_tag == lsb_queue[head][5:2] && array_size) begin
        if (ready && !stop) begin
          oprand <= lsb_queue[head][123:92] | (1<<20);
          addr <= $signed(lsb_queue[head][59:28]) + $signed(lsb_queue[head][17:6]);
          data <= lsb_queue[head][91:60];
          lsb_queue[head][1:0] = 2'b01;
          stop <= 1;
        end
      end
      if (stop) begin
        stop = 0;
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