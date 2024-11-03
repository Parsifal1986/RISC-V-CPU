module queue #(parameter SIZE = 16, parameter DATA_WIDTH = 32) (
  input wire[DATA_WIDTH-1:0] push_data,
  input wire push,
  input wire pop,
  output wire[DATA_WIDTH-1:0] pop_data
);

reg[31:0] head, tail;

reg[DATA_WIDTH-1:0] queue[SIZE-1:0];



endmodule