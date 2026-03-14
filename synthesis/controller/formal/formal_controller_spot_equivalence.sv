module formal_controller_spot_equivalence;
  (* gclk *) reg clk;

  logic       rst_n;
  logic       start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;

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

  reg [4:0] step;

  controller baseline_controller (
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

  controller_spot_compat generated_controller (
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
    step = 5'd0;
  end

  always @* begin
    if (step < 5'd2) begin
      assume (!rst_n);
    end else begin
      assume (rst_n);
    end
  end

  always @(posedge clk) begin
    if (step < 5'd12) begin
      step <= step + 5'd1;
    end

    assert (generated_state == baseline_state);
    assert (generated_load_input == baseline_load_input);
    assert (generated_clear_acc == baseline_clear_acc);
    assert (generated_do_mac_hidden == baseline_do_mac_hidden);
    assert (generated_do_bias_hidden == baseline_do_bias_hidden);
    assert (generated_do_act_hidden == baseline_do_act_hidden);
    assert (generated_advance_hidden == baseline_advance_hidden);
    assert (generated_do_mac_output == baseline_do_mac_output);
    assert (generated_do_bias_output == baseline_do_bias_output);
    assert (generated_done == baseline_done);
    assert (generated_busy == baseline_busy);
  end
endmodule
