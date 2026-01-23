module test_nested_ifs (
  input CLK,
  input RST,
  input [1:0] sel,
  output reg [31:0] out
);

  always @(posedge CLK) begin
    if (RST) begin
      out <= 0;
    end
    else begin
      if (sel == 0) begin
        out <= 1;
      end
      if (sel == 1) begin
        out <= 2;
      end
      if (sel == 2) begin
        out <= 3;
      end
    end
  end

endmodule
