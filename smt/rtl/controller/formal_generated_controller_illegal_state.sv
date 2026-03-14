`ifndef INPUT_NEURONS_VALUE
`define INPUT_NEURONS_VALUE 4
`endif

`ifndef HIDDEN_NEURONS_VALUE
`define HIDDEN_NEURONS_VALUE 8
`endif

module formal_generated_controller_illegal_state;
  (* gclk *) reg clk;
  localparam int INPUT_NEURONS = `INPUT_NEURONS_VALUE;
  localparam int HIDDEN_NEURONS = `HIDDEN_NEURONS_VALUE;

  logic       rst_n;
  logic       start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;
  (* anyconst *) logic [3:0] invalid_state;

  logic [3:0] baseline_state;
  logic       baseline_load_input;
  logic       baseline_clear_acc;
  logic       baseline_do_mac_hidden;
  logic       baseline_do_bias_hidden;
  logic       baseline_do_act_hidden;
  logic       baseline_advance_hidden;
  logic       baseline_do_mac_output;
  logic       baseline_do_bias_output;
  logic       baseline_done;
  logic       baseline_busy;

  logic [3:0] generated_state;
  logic       generated_load_input;
  logic       generated_clear_acc;
  logic       generated_do_mac_hidden;
  logic       generated_do_bias_hidden;
  logic       generated_do_act_hidden;
  logic       generated_advance_hidden;
  logic       generated_do_mac_output;
  logic       generated_do_bias_output;
  logic       generated_done;
  logic       generated_busy;

  reg       past_valid;
  reg [6:0] step;

  controller #(
    .INPUT_NEURONS(INPUT_NEURONS),
    .HIDDEN_NEURONS(HIDDEN_NEURONS)
  ) baseline (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(baseline_state),
    .load_input(baseline_load_input),
    .clear_acc(baseline_clear_acc),
    .do_mac_hidden(baseline_do_mac_hidden),
    .do_bias_hidden(baseline_do_bias_hidden),
    .do_act_hidden(baseline_do_act_hidden),
    .advance_hidden(baseline_advance_hidden),
    .do_mac_output(baseline_do_mac_output),
    .do_bias_output(baseline_do_bias_output),
    .done(baseline_done),
    .busy(baseline_busy)
  );

  sparkle_controller_wrapper #(
    .INPUT_NEURONS(INPUT_NEURONS),
    .HIDDEN_NEURONS(HIDDEN_NEURONS)
  ) generated (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(generated_state),
    .load_input(generated_load_input),
    .clear_acc(generated_clear_acc),
    .do_mac_hidden(generated_do_mac_hidden),
    .do_bias_hidden(generated_do_bias_hidden),
    .do_act_hidden(generated_do_act_hidden),
    .advance_hidden(generated_advance_hidden),
    .do_mac_output(generated_do_mac_output),
    .do_bias_output(generated_do_bias_output),
    .done(generated_done),
    .busy(generated_busy)
  );

  initial begin
    past_valid = 1'b0;
    step = 7'd0;
  end

  always @* begin
    assume (rst_n);
    assume (invalid_state > 4'd8);
  end

  always @(posedge clk) begin
    past_valid <= 1'b1;
    if (step < 7'd82) begin
      step <= step + 7'd1;
    end

    if (!past_valid) begin
      assume (baseline_state == invalid_state);
      assume (generated_state == invalid_state);
      assert (baseline_busy);
      assert (generated_busy);
      assert (!baseline_done);
      assert (!generated_done);
    end else if (step == 7'd1) begin
      assert (baseline_state == 4'd0);
      assert (generated_state == 4'd0);
      assert (!baseline_busy);
      assert (!generated_busy);
      assert (!baseline_done);
      assert (!generated_done);
    end

    assert (baseline_state == generated_state);
    assert (baseline_load_input == generated_load_input);
    assert (baseline_clear_acc == generated_clear_acc);
    assert (baseline_do_mac_hidden == generated_do_mac_hidden);
    assert (baseline_do_bias_hidden == generated_do_bias_hidden);
    assert (baseline_do_act_hidden == generated_do_act_hidden);
    assert (baseline_advance_hidden == generated_advance_hidden);
    assert (baseline_do_mac_output == generated_do_mac_output);
    assert (baseline_do_bias_output == generated_do_bias_output);
    assert (baseline_done == generated_done);
    assert (baseline_busy == generated_busy);
  end
endmodule
