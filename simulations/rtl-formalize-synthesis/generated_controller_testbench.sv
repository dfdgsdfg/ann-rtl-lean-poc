`timescale 1ns/1ps

module generated_controller_testbench;
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;

  localparam int DEFAULT_INPUT_NEURONS = 4;
  localparam int DEFAULT_HIDDEN_NEURONS = 8;
  localparam logic [3:0] DEFAULT_HIDDEN_NEURONS_4B = DEFAULT_HIDDEN_NEURONS[3:0];
  localparam logic [3:0] DEFAULT_LAST_HIDDEN_IDX = DEFAULT_HIDDEN_NEURONS_4B - 4'd1;

  localparam int ALT_INPUT_NEURONS = 3;
  localparam int ALT_HIDDEN_NEURONS = 5;
  localparam logic [3:0] ALT_HIDDEN_NEURONS_4B = ALT_HIDDEN_NEURONS[3:0];
  localparam logic [3:0] ALT_LAST_HIDDEN_IDX = ALT_HIDDEN_NEURONS_4B - 4'd1;

  logic clk;
  logic rst_n;
  logic start;

  logic [3:0] baseline_default_hidden_idx;
  logic [3:0] baseline_default_input_idx;
  logic [3:0] generated_default_hidden_idx;
  logic [3:0] generated_default_input_idx;

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

  logic [3:0] baseline_alt_hidden_idx;
  logic [3:0] baseline_alt_input_idx;
  logic [3:0] generated_alt_hidden_idx;
  logic [3:0] generated_alt_input_idx;

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

  // Mirror the datapath-owned counter updates so the controllers are checked
  // as a closed loop instead of against hand-authored index samples.
  function automatic logic [7:0] compute_next_indices(
    input logic [3:0] current_hidden_idx,
    input logic [3:0] current_input_idx,
    input logic [3:0] current_state,
    input logic       current_start,
    input logic       current_load_input,
    input logic       current_do_mac_hidden,
    input logic       current_do_act_hidden,
    input logic       current_advance_hidden,
    input logic       current_do_mac_output,
    input logic       current_do_bias_output,
    input logic [3:0] hidden_neurons_4b,
    input logic [3:0] last_hidden_idx
  );
    logic [3:0] next_hidden_idx;
    logic [3:0] next_input_idx;
    begin
      next_hidden_idx = current_hidden_idx;
      next_input_idx = current_input_idx;

      if (current_load_input) begin
        next_hidden_idx = 4'd0;
        next_input_idx = 4'd0;
      end else begin
        if (current_do_mac_hidden || current_do_mac_output) begin
          next_input_idx = current_input_idx + 4'd1;
        end

        if (current_do_act_hidden) begin
          next_input_idx = 4'd0;
        end

        if (current_advance_hidden) begin
          if (current_hidden_idx == last_hidden_idx) begin
            next_hidden_idx = 4'd0;
            next_input_idx = 4'd0;
          end else begin
            next_hidden_idx = current_hidden_idx + 4'd1;
          end
        end

        if (current_do_bias_output) begin
          next_hidden_idx = 4'd0;
          next_input_idx = hidden_neurons_4b;
        end

        if ((current_state == IDLE) && !current_start) begin
          next_hidden_idx = 4'd0;
          next_input_idx = 4'd0;
        end
      end

      compute_next_indices = {next_hidden_idx, next_input_idx};
    end
  endfunction

  controller #(
    .INPUT_NEURONS(DEFAULT_INPUT_NEURONS),
    .HIDDEN_NEURONS(DEFAULT_HIDDEN_NEURONS)
  ) baseline_default (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(baseline_default_hidden_idx),
    .input_idx(baseline_default_input_idx),
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
    .INPUT_NEURONS(DEFAULT_INPUT_NEURONS),
    .HIDDEN_NEURONS(DEFAULT_HIDDEN_NEURONS)
  ) generated_default (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(generated_default_hidden_idx),
    .input_idx(generated_default_input_idx),
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
    .INPUT_NEURONS(ALT_INPUT_NEURONS),
    .HIDDEN_NEURONS(ALT_HIDDEN_NEURONS)
  ) baseline_alt (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(baseline_alt_hidden_idx),
    .input_idx(baseline_alt_input_idx),
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
    .INPUT_NEURONS(ALT_INPUT_NEURONS),
    .HIDDEN_NEURONS(ALT_HIDDEN_NEURONS)
  ) generated_alt (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(generated_alt_hidden_idx),
    .input_idx(generated_alt_input_idx),
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baseline_default_hidden_idx <= 4'd0;
      baseline_default_input_idx <= 4'd0;
    end else begin
      {baseline_default_hidden_idx, baseline_default_input_idx} <= compute_next_indices(
        baseline_default_hidden_idx,
        baseline_default_input_idx,
        baseline_default_state,
        start,
        baseline_default_load_input,
        baseline_default_do_mac_hidden,
        baseline_default_do_act_hidden,
        baseline_default_advance_hidden,
        baseline_default_do_mac_output,
        baseline_default_do_bias_output,
        DEFAULT_HIDDEN_NEURONS_4B,
        DEFAULT_LAST_HIDDEN_IDX
      );
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      generated_default_hidden_idx <= 4'd0;
      generated_default_input_idx <= 4'd0;
    end else begin
      {generated_default_hidden_idx, generated_default_input_idx} <= compute_next_indices(
        generated_default_hidden_idx,
        generated_default_input_idx,
        generated_default_state,
        start,
        generated_default_load_input,
        generated_default_do_mac_hidden,
        generated_default_do_act_hidden,
        generated_default_advance_hidden,
        generated_default_do_mac_output,
        generated_default_do_bias_output,
        DEFAULT_HIDDEN_NEURONS_4B,
        DEFAULT_LAST_HIDDEN_IDX
      );
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baseline_alt_hidden_idx <= 4'd0;
      baseline_alt_input_idx <= 4'd0;
    end else begin
      {baseline_alt_hidden_idx, baseline_alt_input_idx} <= compute_next_indices(
        baseline_alt_hidden_idx,
        baseline_alt_input_idx,
        baseline_alt_state,
        start,
        baseline_alt_load_input,
        baseline_alt_do_mac_hidden,
        baseline_alt_do_act_hidden,
        baseline_alt_advance_hidden,
        baseline_alt_do_mac_output,
        baseline_alt_do_bias_output,
        ALT_HIDDEN_NEURONS_4B,
        ALT_LAST_HIDDEN_IDX
      );
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      generated_alt_hidden_idx <= 4'd0;
      generated_alt_input_idx <= 4'd0;
    end else begin
      {generated_alt_hidden_idx, generated_alt_input_idx} <= compute_next_indices(
        generated_alt_hidden_idx,
        generated_alt_input_idx,
        generated_alt_state,
        start,
        generated_alt_load_input,
        generated_alt_do_mac_hidden,
        generated_alt_do_act_hidden,
        generated_alt_advance_hidden,
        generated_alt_do_mac_output,
        generated_alt_do_bias_output,
        ALT_HIDDEN_NEURONS_4B,
        ALT_LAST_HIDDEN_IDX
      );
    end
  end

  task automatic compare_pair(
    input string label,
    input string family,
    input logic [3:0] baseline_state,
    input logic [3:0] generated_state,
    input logic [3:0] baseline_hidden_idx,
    input logic [3:0] generated_hidden_idx,
    input logic [3:0] baseline_input_idx,
    input logic [3:0] generated_input_idx,
    input logic       baseline_load_input,
    input logic       generated_load_input,
    input logic       baseline_clear_acc,
    input logic       generated_clear_acc,
    input logic       baseline_do_mac_hidden,
    input logic       generated_do_mac_hidden,
    input logic       baseline_do_bias_hidden,
    input logic       generated_do_bias_hidden,
    input logic       baseline_do_act_hidden,
    input logic       generated_do_act_hidden,
    input logic       baseline_advance_hidden,
    input logic       generated_advance_hidden,
    input logic       baseline_do_mac_output,
    input logic       generated_do_mac_output,
    input logic       baseline_do_bias_output,
    input logic       generated_do_bias_output,
    input logic       baseline_done,
    input logic       generated_done,
    input logic       baseline_busy,
    input logic       generated_busy
  );
    begin
      if (baseline_state !== generated_state ||
          baseline_hidden_idx !== generated_hidden_idx ||
          baseline_input_idx !== generated_input_idx ||
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
          "FAIL %s %s state=%0d/%0d hidden_idx=%0d/%0d input_idx=%0d/%0d load=%0d/%0d clear=%0d/%0d mac_h=%0d/%0d bias_h=%0d/%0d act_h=%0d/%0d next_h=%0d/%0d mac_o=%0d/%0d bias_o=%0d/%0d done=%0d/%0d busy=%0d/%0d",
          family,
          label,
          baseline_state, generated_state,
          baseline_hidden_idx, generated_hidden_idx,
          baseline_input_idx, generated_input_idx,
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

  task automatic check_pair(input bit select_default, input string family, input string label);
    begin
      if (select_default) begin
        compare_pair(
          label,
          family,
          baseline_default_state,
          generated_default_state,
          baseline_default_hidden_idx,
          generated_default_hidden_idx,
          baseline_default_input_idx,
          generated_default_input_idx,
          baseline_default_load_input,
          generated_default_load_input,
          baseline_default_clear_acc,
          generated_default_clear_acc,
          baseline_default_do_mac_hidden,
          generated_default_do_mac_hidden,
          baseline_default_do_bias_hidden,
          generated_default_do_bias_hidden,
          baseline_default_do_act_hidden,
          generated_default_do_act_hidden,
          baseline_default_advance_hidden,
          generated_default_advance_hidden,
          baseline_default_do_mac_output,
          generated_default_do_mac_output,
          baseline_default_do_bias_output,
          generated_default_do_bias_output,
          baseline_default_done,
          generated_default_done,
          baseline_default_busy,
          generated_default_busy
        );
      end else begin
        compare_pair(
          label,
          family,
          baseline_alt_state,
          generated_alt_state,
          baseline_alt_hidden_idx,
          generated_alt_hidden_idx,
          baseline_alt_input_idx,
          generated_alt_input_idx,
          baseline_alt_load_input,
          generated_alt_load_input,
          baseline_alt_clear_acc,
          generated_alt_clear_acc,
          baseline_alt_do_mac_hidden,
          generated_alt_do_mac_hidden,
          baseline_alt_do_bias_hidden,
          generated_alt_do_bias_hidden,
          baseline_alt_do_act_hidden,
          generated_alt_do_act_hidden,
          baseline_alt_advance_hidden,
          generated_alt_advance_hidden,
          baseline_alt_do_mac_output,
          generated_alt_do_mac_output,
          baseline_alt_do_bias_output,
          generated_alt_do_bias_output,
          baseline_alt_done,
          generated_alt_done,
          baseline_alt_busy,
          generated_alt_busy
        );
      end
    end
  endtask

  task automatic sample_pair(
    input bit select_default,
    output logic [3:0] state_value,
    output logic [3:0] hidden_idx_value,
    output logic [3:0] input_idx_value,
    output logic       do_mac_hidden_value,
    output logic       do_mac_output_value,
    output logic       done_value,
    output logic       busy_value
  );
    begin
      if (select_default) begin
        state_value = baseline_default_state;
        hidden_idx_value = baseline_default_hidden_idx;
        input_idx_value = baseline_default_input_idx;
        do_mac_hidden_value = baseline_default_do_mac_hidden;
        do_mac_output_value = baseline_default_do_mac_output;
        done_value = baseline_default_done;
        busy_value = baseline_default_busy;
      end else begin
        state_value = baseline_alt_state;
        hidden_idx_value = baseline_alt_hidden_idx;
        input_idx_value = baseline_alt_input_idx;
        do_mac_hidden_value = baseline_alt_do_mac_hidden;
        do_mac_output_value = baseline_alt_do_mac_output;
        done_value = baseline_alt_done;
        busy_value = baseline_alt_busy;
      end
    end
  endtask

  task automatic step_and_check_pair(input bit select_default, input string family, input string label);
    begin
      @(negedge clk);
      check_pair(select_default, family, label);
    end
  endtask

  task automatic apply_reset;
    begin
      rst_n = 1'b0;
      start = 1'b0;
      repeat (2) begin
        @(negedge clk);
      end
      rst_n = 1'b1;
    end
  endtask

  task automatic run_closed_loop_trace(
    input bit    select_default,
    input string family,
    input int    input_neurons,
    input int    hidden_neurons,
    input bit    inject_done_hold
  );
    logic [3:0] state_value;
    logic [3:0] hidden_idx_value;
    logic [3:0] input_idx_value;
    logic [3:0] input_neurons_4b;
    logic [3:0] hidden_neurons_4b;
    logic       do_mac_hidden_value;
    logic       do_mac_output_value;
    logic       done_value;
    logic       busy_value;
    integer expected_done_cycle;
    integer cycle;
    bit saw_hidden_guard;
    bit saw_output_entry;
    bit saw_output_guard;
    bit armed_done_hold;
    begin
      input_neurons_4b = input_neurons[3:0];
      hidden_neurons_4b = hidden_neurons[3:0];
      expected_done_cycle = 4 + hidden_neurons * (input_neurons + 5);
      saw_hidden_guard = 1'b0;
      saw_output_entry = 1'b0;
      saw_output_guard = 1'b0;
      armed_done_hold = 1'b0;

      apply_reset();
      check_pair(select_default, family, "idle_after_reset");
      sample_pair(
        select_default,
        state_value,
        hidden_idx_value,
        input_idx_value,
        do_mac_hidden_value,
        do_mac_output_value,
        done_value,
        busy_value
      );
      if (state_value !== IDLE || hidden_idx_value !== 4'd0 || input_idx_value !== 4'd0 ||
          done_value !== 1'b0 || busy_value !== 1'b0) begin
        $display(
          "FAIL %s idle_after_reset state=%0d hidden_idx=%0d input_idx=%0d done=%0d busy=%0d",
          family,
          state_value,
          hidden_idx_value,
          input_idx_value,
          done_value,
          busy_value
        );
        errors = errors + 1;
      end

      start = 1'b1;
      step_and_check_pair(select_default, family, "accept");
      start = 1'b0;

      sample_pair(
        select_default,
        state_value,
        hidden_idx_value,
        input_idx_value,
        do_mac_hidden_value,
        do_mac_output_value,
        done_value,
        busy_value
      );
      if (state_value !== LOAD_INPUT || hidden_idx_value !== 4'd0 || input_idx_value !== 4'd0 ||
          done_value !== 1'b0 || busy_value !== 1'b1) begin
        $display(
          "FAIL %s accept state=%0d hidden_idx=%0d input_idx=%0d done=%0d busy=%0d",
          family,
          state_value,
          hidden_idx_value,
          input_idx_value,
          done_value,
          busy_value
        );
        errors = errors + 1;
      end

      for (cycle = 2; cycle <= expected_done_cycle; cycle = cycle + 1) begin
        sample_pair(
          select_default,
          state_value,
          hidden_idx_value,
          input_idx_value,
          do_mac_hidden_value,
          do_mac_output_value,
          done_value,
          busy_value
        );

        if (inject_done_hold && !armed_done_hold && (state_value == BIAS_OUTPUT)) begin
          start = 1'b1;
          armed_done_hold = 1'b1;
        end

        step_and_check_pair(select_default, family, $sformatf("cycle_%0d", cycle));

        sample_pair(
          select_default,
          state_value,
          hidden_idx_value,
          input_idx_value,
          do_mac_hidden_value,
          do_mac_output_value,
          done_value,
          busy_value
        );

        if ((state_value == MAC_HIDDEN) && (input_idx_value == input_neurons_4b) && !do_mac_hidden_value) begin
          saw_hidden_guard = 1'b1;
        end

        if ((state_value == MAC_OUTPUT) && (hidden_idx_value == 4'd0) && (input_idx_value == 4'd0)) begin
          saw_output_entry = 1'b1;
        end

        if ((state_value == MAC_OUTPUT) && (input_idx_value == hidden_neurons_4b) && !do_mac_output_value) begin
          saw_output_guard = 1'b1;
        end

        if (done_value && (cycle != expected_done_cycle)) begin
          $display("FAIL %s done_timing expected_cycle=%0d actual_cycle=%0d", family, expected_done_cycle, cycle);
          errors = errors + 1;
        end
      end

      sample_pair(
        select_default,
        state_value,
        hidden_idx_value,
        input_idx_value,
        do_mac_hidden_value,
        do_mac_output_value,
        done_value,
        busy_value
      );
      if (state_value !== DONE || done_value !== 1'b1 || busy_value !== 1'b0) begin
        $display("FAIL %s done_cycle state=%0d done=%0d busy=%0d", family, state_value, done_value, busy_value);
        errors = errors + 1;
      end
      if (inject_done_hold && !armed_done_hold) begin
        $display("FAIL %s done_hold was never armed before DONE", family);
        errors = errors + 1;
      end
      if (!saw_hidden_guard) begin
        $display("FAIL %s hidden_guard was never observed", family);
        errors = errors + 1;
      end
      if (!saw_output_entry) begin
        $display("FAIL %s output_entry was never observed", family);
        errors = errors + 1;
      end
      if (!saw_output_guard) begin
        $display("FAIL %s output_guard was never observed", family);
        errors = errors + 1;
      end

      if (inject_done_hold) begin
        step_and_check_pair(select_default, family, "done_hold");
        sample_pair(
          select_default,
          state_value,
          hidden_idx_value,
          input_idx_value,
          do_mac_hidden_value,
          do_mac_output_value,
          done_value,
          busy_value
        );
        if (state_value !== DONE || done_value !== 1'b1 || busy_value !== 1'b0) begin
          $display("FAIL %s done_hold state=%0d done=%0d busy=%0d", family, state_value, done_value, busy_value);
          errors = errors + 1;
        end
        start = 1'b0;
      end

      step_and_check_pair(select_default, family, "done_release");
      sample_pair(
        select_default,
        state_value,
        hidden_idx_value,
        input_idx_value,
        do_mac_hidden_value,
        do_mac_output_value,
        done_value,
        busy_value
      );
      if (state_value !== IDLE || hidden_idx_value !== 4'd0 || input_idx_value !== hidden_neurons_4b ||
          done_value !== 1'b0 || busy_value !== 1'b0) begin
        $display(
          "FAIL %s done_release state=%0d hidden_idx=%0d input_idx=%0d done=%0d busy=%0d",
          family,
          state_value,
          hidden_idx_value,
          input_idx_value,
          done_value,
          busy_value
        );
        errors = errors + 1;
      end

      step_and_check_pair(select_default, family, "idle_cleanup");
      sample_pair(
        select_default,
        state_value,
        hidden_idx_value,
        input_idx_value,
        do_mac_hidden_value,
        do_mac_output_value,
        done_value,
        busy_value
      );
      if (state_value !== IDLE || hidden_idx_value !== 4'd0 || input_idx_value !== 4'd0 ||
          done_value !== 1'b0 || busy_value !== 1'b0) begin
        $display(
          "FAIL %s idle_cleanup state=%0d hidden_idx=%0d input_idx=%0d done=%0d busy=%0d",
          family,
          state_value,
          hidden_idx_value,
          input_idx_value,
          done_value,
          busy_value
        );
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    errors = 0;

    run_closed_loop_trace(1'b1, "default_auto_release", DEFAULT_INPUT_NEURONS, DEFAULT_HIDDEN_NEURONS, 1'b0);
    run_closed_loop_trace(1'b1, "default_done_hold", DEFAULT_INPUT_NEURONS, DEFAULT_HIDDEN_NEURONS, 1'b1);
    run_closed_loop_trace(1'b0, "alt_auto_release", ALT_INPUT_NEURONS, ALT_HIDDEN_NEURONS, 1'b0);
    run_closed_loop_trace(1'b0, "alt_done_hold", ALT_INPUT_NEURONS, ALT_HIDDEN_NEURONS, 1'b1);

    if (errors != 0) begin
      $display("FAIL generated controller comparison errors=%0d", errors);
      $finish_and_return(1);
    end

    $display("PASS generated controller comparison");
    $finish;
  end
endmodule
