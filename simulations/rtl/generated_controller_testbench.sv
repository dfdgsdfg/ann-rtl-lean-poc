`timescale 1ns/1ps

module generated_controller_testbench;
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN  = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;

  logic clk;
  logic rst_n;
  logic start;
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

  integer errors;

  controller baseline (
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

  sparkle_controller_wrapper generated (
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

  always #5 clk = ~clk;

  task automatic check_match(input string label);
    begin
      if (baseline_state !== generated_state ||
          baseline_load_input !== generated_load_input ||
          baseline_clear_acc !== generated_clear_acc ||
          baseline_do_mac_hidden !== generated_do_mac_hidden ||
          baseline_do_bias_hidden !== generated_do_bias_hidden ||
          baseline_do_act_hidden !== generated_do_act_hidden ||
          baseline_advance_hidden !== generated_advance_hidden ||
          baseline_do_mac_output !== generated_do_mac_output ||
          baseline_do_bias_output !== generated_do_bias_output ||
          baseline_done !== generated_done ||
          baseline_busy !== generated_busy) begin
        $display(
          "FAIL %s state=%0d/%0d load=%0d/%0d clear=%0d/%0d mac_h=%0d/%0d bias_h=%0d/%0d act_h=%0d/%0d next_h=%0d/%0d mac_o=%0d/%0d bias_o=%0d/%0d done=%0d/%0d busy=%0d/%0d",
          label,
          baseline_state, generated_state,
          baseline_load_input, generated_load_input,
          baseline_clear_acc, generated_clear_acc,
          baseline_do_mac_hidden, generated_do_mac_hidden,
          baseline_do_bias_hidden, generated_do_bias_hidden,
          baseline_do_act_hidden, generated_do_act_hidden,
          baseline_advance_hidden, generated_advance_hidden,
          baseline_do_mac_output, generated_do_mac_output,
          baseline_do_bias_output, generated_do_bias_output,
          baseline_done, generated_done,
          baseline_busy, generated_busy
        );
        errors = errors + 1;
      end
    end
  endtask

  task automatic step_and_check(input string label);
    begin
      @(negedge clk);
      check_match(label);
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    hidden_idx = 4'd0;
    input_idx = 4'd0;
    errors = 0;

    repeat (2) begin
      step_and_check("reset");
    end

    rst_n = 1'b1;
    step_and_check("idle");

    start = 1'b1;
    step_and_check("accept");

    start = 1'b0;
    step_and_check("load_to_mac_hidden");

    input_idx = 4'd0; step_and_check("hidden_mac_0");
    input_idx = 4'd1; step_and_check("hidden_mac_1");
    input_idx = 4'd2; step_and_check("hidden_mac_2");
    input_idx = 4'd3; step_and_check("hidden_mac_3");
    input_idx = 4'd4; step_and_check("hidden_guard");
    step_and_check("bias_hidden");
    step_and_check("act_hidden");

    hidden_idx = 4'd0;
    step_and_check("next_hidden_not_last");

    input_idx = 4'd4;
    hidden_idx = 4'd7;
    step_and_check("last_hidden_to_output");

    input_idx = 4'd0; step_and_check("output_mac_0");
    input_idx = 4'd7; step_and_check("output_mac_7");
    input_idx = 4'd8; step_and_check("output_guard");
    step_and_check("bias_output");

    start = 1'b1;
    step_and_check("done_hold");

    start = 1'b0;
    step_and_check("done_release");
    step_and_check("idle_after_release");

    if (errors != 0) begin
      $display("FAIL generated controller comparison errors=%0d", errors);
      $finish_and_return(1);
    end

    $display("PASS generated controller comparison");
    $finish;
  end
endmodule
