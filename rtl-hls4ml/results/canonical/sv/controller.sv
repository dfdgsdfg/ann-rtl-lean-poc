// Reused controller for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/controller.sv

module controller #(
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
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN  = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;
  localparam logic [3:0] INPUT_NEURONS_4B = INPUT_NEURONS[3:0];
  localparam logic [3:0] HIDDEN_NEURONS_4B = HIDDEN_NEURONS[3:0];
  localparam logic [3:0] LAST_HIDDEN_IDX = HIDDEN_NEURONS_4B - 4'd1;

  logic [3:0] next_state;

  always_comb begin
    unique case (state)
      IDLE:        next_state = start ? LOAD_INPUT : IDLE;
      LOAD_INPUT:  next_state = MAC_HIDDEN;
      MAC_HIDDEN:  next_state = (input_idx == INPUT_NEURONS_4B) ? BIAS_HIDDEN : MAC_HIDDEN;
      BIAS_HIDDEN: next_state = ACT_HIDDEN;
      ACT_HIDDEN:  next_state = NEXT_HIDDEN;
      NEXT_HIDDEN: next_state = (hidden_idx == LAST_HIDDEN_IDX) ? MAC_OUTPUT : MAC_HIDDEN;
      MAC_OUTPUT:  next_state = (input_idx == HIDDEN_NEURONS_4B) ? BIAS_OUTPUT : MAC_OUTPUT;
      BIAS_OUTPUT: next_state = DONE;
      DONE:        next_state = start ? DONE : IDLE;
      default:     next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    load_input     = (state == LOAD_INPUT);
    clear_acc      = (state == LOAD_INPUT);
    do_mac_hidden  = (state == MAC_HIDDEN) && (input_idx < INPUT_NEURONS_4B);
    do_bias_hidden = (state == BIAS_HIDDEN);
    do_act_hidden  = (state == ACT_HIDDEN);
    advance_hidden = (state == NEXT_HIDDEN);
    do_mac_output  = (state == MAC_OUTPUT) && (input_idx < HIDDEN_NEURONS_4B);
    do_bias_output = (state == BIAS_OUTPUT);
    done           = (state == DONE);
    busy           = (state != IDLE) && (state != DONE);
  end
endmodule
