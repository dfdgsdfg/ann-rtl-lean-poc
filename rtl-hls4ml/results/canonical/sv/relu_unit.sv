// Reused ReLU unit for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/relu_unit.sv

module relu_unit #(
  parameter IN_WIDTH  = 32,
  parameter OUT_WIDTH = 16
) (
  input  logic signed [IN_WIDTH-1:0]  in_value,
  output logic signed [OUT_WIDTH-1:0] out_value
);
  assign out_value = (in_value[IN_WIDTH-1]) ? {OUT_WIDTH{1'b0}}
                                            : in_value[OUT_WIDTH-1:0];
endmodule
