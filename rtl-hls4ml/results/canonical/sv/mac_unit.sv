// Reused MAC unit for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/mac_unit.sv

module mac_unit #(
  parameter A_WIDTH   = 16,
  parameter B_WIDTH   = 8,
  parameter ACC_WIDTH = 32
) (
  input  logic signed [A_WIDTH-1:0]   a,
  input  logic signed [B_WIDTH-1:0]   b,
  input  logic signed [ACC_WIDTH-1:0] acc_in,
  output logic signed [ACC_WIDTH-1:0] acc_out
);
  logic signed [A_WIDTH+B_WIDTH-1:0] product;
  assign product = a * b;
  assign acc_out = acc_in + ACC_WIDTH'(product);
endmodule
