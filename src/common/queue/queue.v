module queue #(parameter SIZE = 4, parameter DATA_WIDTH = 32) (
  input wire[DATA_WIDTH-1:0] push_data,
  input wire push,
  input wire pop,
  input wire[SIZE - 1:0] at,
  input wire change,
  input wire[DATA_WIDTH-1:0] change_data,
  input clear,
  output wire[DATA_WIDTH-1:0] head_data,
  output wire[DATA_WIDTH-1:0] at_data,
  output wire[31:0] queue_size
);

reg[31:0] head, tail, size;

reg[DATA_WIDTH-1:0] queue[SIZE-1:0];

assign head_data = queue[head];
assign at_data = queue[at];
assign queue_size = size;

always @(*) begin
  if (push) begin
    queue[tail] = push_data;
    tail = tail + 1;
    size = size + 1;
  end
  if (pop) begin
    head = head + 1;
    size = size - 1;
  end
  if (change) begin
    queue[at] = change_data;
  end
  if (clear) begin
    head = 0;
    tail = 0;
    size = 0;
  end
end

endmodule