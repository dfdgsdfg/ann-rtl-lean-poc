module sparkle_controller_wrapper #(
  parameter int INPUT_NEURONS = 4,
  parameter int HIDDEN_NEURONS = 8
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start,
  input  logic [3:0] hidden_idx,
  input  logic [3:0] input_idx,
  output logic [3:0] state,
  output logic       load_input,
  output logic       clear_acc,
  output logic       do_mac_hidden,
  output logic       do_bias_hidden,
  output logic       do_act_hidden,
  output logic       advance_hidden,
  output logic       do_mac_output,
  output logic       do_bias_output,
  output logic       done,
  output logic       busy
);
  logic        rst;
  logic [13:0] packed_out;
  localparam logic [3:0] INPUT_NEURONS_4B = INPUT_NEURONS[3:0];
  localparam logic [3:0] HIDDEN_NEURONS_4B = HIDDEN_NEURONS[3:0];
  localparam logic [3:0] LAST_HIDDEN_IDX = HIDDEN_NEURONS_4B - 4'd1;

  assign rst = ~rst_n;

  TinyMLP_sparkleControllerPacked u_sparkle_controller (
    ._gen_start(start),
    ._gen_hidden_idx(hidden_idx),
    ._gen_input_idx(input_idx),
    ._gen_inputNeurons4b(INPUT_NEURONS_4B),
    ._gen_hiddenNeurons4b(HIDDEN_NEURONS_4B),
    ._gen_lastHiddenIdx(LAST_HIDDEN_IDX),
    .clk(clk),
    .rst(rst),
    .out(packed_out)
  );

  assign state          = packed_out[13:10];
  assign load_input     = packed_out[9];
  assign clear_acc      = packed_out[8];
  assign do_mac_hidden  = packed_out[7];
  assign do_bias_hidden = packed_out[6];
  assign do_act_hidden  = packed_out[5];
  assign advance_hidden = packed_out[4];
  assign do_mac_output  = packed_out[3];
  assign do_bias_output = packed_out[2];
  assign done           = packed_out[1];
  assign busy           = packed_out[0];
endmodule
