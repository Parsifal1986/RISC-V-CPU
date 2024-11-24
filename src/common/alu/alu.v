module alu(
  input wire clk,

  input wire alu_ready,
  input wire[31:0] a,
  input wire[31:0] b,
  input wire[4:0] alu_op,
  input wire[3:0] tag,

  output reg[31:0] cdb_alu_data,
  output reg[3:0] cdb_alu_tag,
  output reg cdb_alu_done
);

reg signed [31:0] signed_a;
reg signed [31:0] signed_b;

always @(posedge clk) begin
  if (alu_ready) begin
    signed_a = a;
    signed_b = b;
    case (alu_op)
      0: 
        begin
          cdb_alu_data <= a + b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      1:
        begin
          cdb_alu_data <= a - b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      2:
        begin
          cdb_alu_data <= a & b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      3:
        begin
          cdb_alu_data <= a | b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      4:
        begin
          cdb_alu_data <= a ^ b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      5:
        begin
          cdb_alu_data <= a << b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      6:
        begin
          cdb_alu_data <= a >> b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      7:
        begin
          cdb_alu_data <= a >>> b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      8:
        begin
          cdb_alu_data <= signed_a < signed_b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      9:
        begin
          cdb_alu_data <= a < b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      10:
        begin
          cdb_alu_data <= a == b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      11:
        begin
          cdb_alu_data <= a != b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      12:
        begin
          cdb_alu_data <= signed_a >= signed_b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      13:
        begin
          cdb_alu_data <= a >= b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      14:
        begin
          cdb_alu_data <= signed_a < signed_b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      15:
        begin
          cdb_alu_data <= a < b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      16:
        begin
          cdb_alu_data <= a * b;
          cdb_alu_tag <= tag;
          cdb_alu_done <= 1;
        end
      default: 
        begin
          cdb_alu_data <= 0;
          cdb_alu_tag <= 0;
          cdb_alu_done <= 0;
          $display("ALU: Unknown operation %d", alu_op);
        end
    endcase
  end
end

endmodule