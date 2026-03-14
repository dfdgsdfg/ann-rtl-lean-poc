`timescale 1ns/1ps

module generated_controller_testbench;
  logic clk;
  logic rst_n;
  logic start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;

  logic [3:0] baseline_default_state;
  logic       baseline_default_load_input;
  logic       baseline_default_clear_acc;
  logic       baseline_default_do_mac_hidden;
  logic       baseline_default_do_bias_hidden;
  logic       baseline_default_do_act_hidden;
  logic       baseline_default_advance_hidden;
  logic       baseline_default_do_mac_output;
  logic       baseline_default_do_bias_output;
  logic       baseline_default_done;
  logic       baseline_default_busy;

  logic [3:0] generated_default_state;
  logic       generated_default_load_input;
  logic       generated_default_clear_acc;
  logic       generated_default_do_mac_hidden;
  logic       generated_default_do_bias_hidden;
  logic       generated_default_do_act_hidden;
  logic       generated_default_advance_hidden;
  logic       generated_default_do_mac_output;
  logic       generated_default_do_bias_output;
  logic       generated_default_done;
  logic       generated_default_busy;

  logic [3:0] baseline_alt_state;
  logic       baseline_alt_load_input;
  logic       baseline_alt_clear_acc;
  logic       baseline_alt_do_mac_hidden;
  logic       baseline_alt_do_bias_hidden;
  logic       baseline_alt_do_act_hidden;
  logic       baseline_alt_advance_hidden;
  logic       baseline_alt_do_mac_output;
  logic       baseline_alt_do_bias_output;
  logic       baseline_alt_done;
  logic       baseline_alt_busy;

  logic [3:0] generated_alt_state;
  logic       generated_alt_load_input;
  logic       generated_alt_clear_acc;
  logic       generated_alt_do_mac_hidden;
  logic       generated_alt_do_bias_hidden;
  logic       generated_alt_do_act_hidden;
  logic       generated_alt_advance_hidden;
  logic       generated_alt_do_mac_output;
  logic       generated_alt_do_bias_output;
  logic       generated_alt_done;
  logic       generated_alt_busy;

  integer errors;

  controller #(
    .INPUT_NEURONS(4),
    .HIDDEN_NEURONS(8)
  ) baseline_default (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(baseline_default_state),
    .load_input(baseline_default_load_input),
    .clear_acc(baseline_default_clear_acc),
    .do_mac_hidden(baseline_default_do_mac_hidden),
    .do_bias_hidden(baseline_default_do_bias_hidden),
    .do_act_hidden(baseline_default_do_act_hidden),
    .advance_hidden(baseline_default_advance_hidden),
    .do_mac_output(baseline_default_do_mac_output),
    .do_bias_output(baseline_default_do_bias_output),
    .done(baseline_default_done),
    .busy(baseline_default_busy)
  );

  sparkle_controller_wrapper #(
    .INPUT_NEURONS(4),
    .HIDDEN_NEURONS(8)
  ) generated_default (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(generated_default_state),
    .load_input(generated_default_load_input),
    .clear_acc(generated_default_clear_acc),
    .do_mac_hidden(generated_default_do_mac_hidden),
    .do_bias_hidden(generated_default_do_bias_hidden),
    .do_act_hidden(generated_default_do_act_hidden),
    .advance_hidden(generated_default_advance_hidden),
    .do_mac_output(generated_default_do_mac_output),
    .do_bias_output(generated_default_do_bias_output),
    .done(generated_default_done),
    .busy(generated_default_busy)
  );

  controller #(
    .INPUT_NEURONS(3),
    .HIDDEN_NEURONS(5)
  ) baseline_alt (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(baseline_alt_state),
    .load_input(baseline_alt_load_input),
    .clear_acc(baseline_alt_clear_acc),
    .do_mac_hidden(baseline_alt_do_mac_hidden),
    .do_bias_hidden(baseline_alt_do_bias_hidden),
    .do_act_hidden(baseline_alt_do_act_hidden),
    .advance_hidden(baseline_alt_advance_hidden),
    .do_mac_output(baseline_alt_do_mac_output),
    .do_bias_output(baseline_alt_do_bias_output),
    .done(baseline_alt_done),
    .busy(baseline_alt_busy)
  );

  sparkle_controller_wrapper #(
    .INPUT_NEURONS(3),
    .HIDDEN_NEURONS(5)
  ) generated_alt (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(generated_alt_state),
    .load_input(generated_alt_load_input),
    .clear_acc(generated_alt_clear_acc),
    .do_mac_hidden(generated_alt_do_mac_hidden),
    .do_bias_hidden(generated_alt_do_bias_hidden),
    .do_act_hidden(generated_alt_do_act_hidden),
    .advance_hidden(generated_alt_advance_hidden),
    .do_mac_output(generated_alt_do_mac_output),
    .do_bias_output(generated_alt_do_bias_output),
    .done(generated_alt_done),
    .busy(generated_alt_busy)
  );

  always #5 clk = ~clk;

  task automatic check_default(input string label);
    begin
      if (baseline_default_state !== generated_default_state ||
          baseline_default_load_input !== generated_default_load_input ||
          baseline_default_clear_acc !== generated_default_clear_acc ||
          baseline_default_do_mac_hidden !== generated_default_do_mac_hidden ||
          baseline_default_do_bias_hidden !== generated_default_do_bias_hidden ||
          baseline_default_do_act_hidden !== generated_default_do_act_hidden ||
          baseline_default_advance_hidden !== generated_default_advance_hidden ||
          baseline_default_do_mac_output !== generated_default_do_mac_output ||
          baseline_default_do_bias_output !== generated_default_do_bias_output ||
          baseline_default_done !== generated_default_done ||
          baseline_default_busy !== generated_default_busy) begin
        $display(
          "FAIL default %s state=%0d/%0d load=%0d/%0d clear=%0d/%0d mac_h=%0d/%0d bias_h=%0d/%0d act_h=%0d/%0d next_h=%0d/%0d mac_o=%0d/%0d bias_o=%0d/%0d done=%0d/%0d busy=%0d/%0d",
          label,
          baseline_default_state, generated_default_state,
          baseline_default_load_input, generated_default_load_input,
          baseline_default_clear_acc, generated_default_clear_acc,
          baseline_default_do_mac_hidden, generated_default_do_mac_hidden,
          baseline_default_do_bias_hidden, generated_default_do_bias_hidden,
          baseline_default_do_act_hidden, generated_default_do_act_hidden,
          baseline_default_advance_hidden, generated_default_advance_hidden,
          baseline_default_do_mac_output, generated_default_do_mac_output,
          baseline_default_do_bias_output, generated_default_do_bias_output,
          baseline_default_done, generated_default_done,
          baseline_default_busy, generated_default_busy
        );
        errors = errors + 1;
      end
    end
  endtask

  task automatic check_alt(input string label);
    begin
      if (baseline_alt_state !== generated_alt_state ||
          baseline_alt_load_input !== generated_alt_load_input ||
          baseline_alt_clear_acc !== generated_alt_clear_acc ||
          baseline_alt_do_mac_hidden !== generated_alt_do_mac_hidden ||
          baseline_alt_do_bias_hidden !== generated_alt_do_bias_hidden ||
          baseline_alt_do_act_hidden !== generated_alt_do_act_hidden ||
          baseline_alt_advance_hidden !== generated_alt_advance_hidden ||
          baseline_alt_do_mac_output !== generated_alt_do_mac_output ||
          baseline_alt_do_bias_output !== generated_alt_do_bias_output ||
          baseline_alt_done !== generated_alt_done ||
          baseline_alt_busy !== generated_alt_busy) begin
        $display(
          "FAIL alt %s state=%0d/%0d load=%0d/%0d clear=%0d/%0d mac_h=%0d/%0d bias_h=%0d/%0d act_h=%0d/%0d next_h=%0d/%0d mac_o=%0d/%0d bias_o=%0d/%0d done=%0d/%0d busy=%0d/%0d",
          label,
          baseline_alt_state, generated_alt_state,
          baseline_alt_load_input, generated_alt_load_input,
          baseline_alt_clear_acc, generated_alt_clear_acc,
          baseline_alt_do_mac_hidden, generated_alt_do_mac_hidden,
          baseline_alt_do_bias_hidden, generated_alt_do_bias_hidden,
          baseline_alt_do_act_hidden, generated_alt_do_act_hidden,
          baseline_alt_advance_hidden, generated_alt_advance_hidden,
          baseline_alt_do_mac_output, generated_alt_do_mac_output,
          baseline_alt_do_bias_output, generated_alt_do_bias_output,
          baseline_alt_done, generated_alt_done,
          baseline_alt_busy, generated_alt_busy
        );
        errors = errors + 1;
      end
    end
  endtask

  task automatic step_and_check_default(input string label);
    begin
      @(negedge clk);
      check_default(label);
    end
  endtask

  task automatic step_and_check_alt(input string label);
    begin
      @(negedge clk);
      check_alt(label);
    end
  endtask

  task automatic apply_reset;
    begin
      rst_n = 1'b0;
      start = 1'b0;
      hidden_idx = 4'd0;
      input_idx = 4'd0;
      repeat (2) begin
        @(negedge clk);
      end
      rst_n = 1'b1;
    end
  endtask

  task automatic run_default_trace;
    begin
      apply_reset();
      check_default("default_idle");

      start = 1'b1;
      step_and_check_default("default_accept");

      start = 1'b0;
      step_and_check_default("default_load_to_mac_hidden");

      input_idx = 4'd0; step_and_check_default("default_hidden_mac_0");
      input_idx = 4'd1; step_and_check_default("default_hidden_mac_1");
      input_idx = 4'd2; step_and_check_default("default_hidden_mac_2");
      input_idx = 4'd3; step_and_check_default("default_hidden_mac_3");
      input_idx = 4'd4; step_and_check_default("default_hidden_guard");
      step_and_check_default("default_bias_hidden");
      step_and_check_default("default_act_hidden");

      hidden_idx = 4'd0;
      step_and_check_default("default_next_hidden_not_last");

      input_idx = 4'd4;
      hidden_idx = 4'd7;
      step_and_check_default("default_last_hidden_to_output");

      input_idx = 4'd0; step_and_check_default("default_output_mac_0");
      input_idx = 4'd7; step_and_check_default("default_output_mac_7");
      input_idx = 4'd8; step_and_check_default("default_output_guard");
      step_and_check_default("default_bias_output");

      start = 1'b1;
      step_and_check_default("default_done_hold");

      start = 1'b0;
      step_and_check_default("default_done_release");
      step_and_check_default("default_idle_after_release");
    end
  endtask

  task automatic run_alt_trace;
    begin
      apply_reset();
      check_alt("alt_idle");

      start = 1'b1;
      step_and_check_alt("alt_accept");

      start = 1'b0;
      step_and_check_alt("alt_load_to_mac_hidden");

      input_idx = 4'd0; step_and_check_alt("alt_hidden_mac_0");
      input_idx = 4'd1; step_and_check_alt("alt_hidden_mac_1");
      input_idx = 4'd2; step_and_check_alt("alt_hidden_mac_2");
      input_idx = 4'd3; step_and_check_alt("alt_hidden_guard");
      step_and_check_alt("alt_bias_hidden");
      step_and_check_alt("alt_act_hidden");

      hidden_idx = 4'd0;
      step_and_check_alt("alt_next_hidden_not_last");

      input_idx = 4'd3;
      hidden_idx = 4'd4;
      step_and_check_alt("alt_last_hidden_to_output");

      input_idx = 4'd0; step_and_check_alt("alt_output_mac_0");
      input_idx = 4'd4; step_and_check_alt("alt_output_mac_4");
      input_idx = 4'd5; step_and_check_alt("alt_output_guard");
      step_and_check_alt("alt_bias_output");

      start = 1'b1;
      step_and_check_alt("alt_done_hold");

      start = 1'b0;
      step_and_check_alt("alt_done_release");
      step_and_check_alt("alt_idle_after_release");
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    hidden_idx = 4'd0;
    input_idx = 4'd0;
    errors = 0;

    run_default_trace();
    run_alt_trace();

    if (errors != 0) begin
      $display("FAIL generated controller comparison errors=%0d", errors);
      $finish_and_return(1);
    end

    $display("PASS generated controller comparison");
    $finish;
  end
endmodule
