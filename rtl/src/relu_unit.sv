module relu_unit #(
  parameter int IN_WIDTH = 32,
  parameter int OUT_WIDTH = 16
) (
  input  logic signed [IN_WIDTH-1:0]  in_value,
  output logic signed [OUT_WIDTH-1:0] out_value
);
  logic signed [OUT_WIDTH-1:0] narrowed_value;

  assign narrowed_value = in_value[OUT_WIDTH-1:0];
  assign out_value = in_value < 0 ? '0 : narrowed_value;
endmodule
