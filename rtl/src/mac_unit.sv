module mac_unit #(
  parameter int A_WIDTH = 16,
  parameter int B_WIDTH = 8,
  parameter int ACC_WIDTH = 32
) (
  input  logic signed [A_WIDTH-1:0]   a,
  input  logic signed [B_WIDTH-1:0]   b,
  input  logic signed [ACC_WIDTH-1:0] acc_in,
  output logic signed [ACC_WIDTH-1:0] acc_out
);
  logic signed [A_WIDTH+B_WIDTH-1:0] product;
  logic signed [ACC_WIDTH-1:0] product_ext;

  assign product = a * b;
  assign product_ext = $signed({{(ACC_WIDTH-(A_WIDTH+B_WIDTH)){product[A_WIDTH+B_WIDTH-1]}}, product});
  assign acc_out = acc_in + product_ext;
endmodule
