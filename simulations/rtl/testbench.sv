`timescale 1ns/1ps

module testbench;
  `include "test_vectors_meta.svh"
  localparam int EXPECTED_CYCLES = 76;
  localparam int STABILITY_HOLD_CYCLES = 3;
  localparam int ACTIVE_WINDOW_START_PULSE_LATENCY = 4;

  logic clk;
  logic rst_n;
  logic start;
  logic signed [7:0] in0;
  logic signed [7:0] in1;
  logic signed [7:0] in2;
  logic signed [7:0] in3;
  logic done;
  logic busy;
  logic out_bit;

  logic [64:0] vectors [0:NUM_VECTORS-1];

  integer idx;
  integer output_errors;
  integer latency_errors;
  integer handshake_errors;
  integer coverage_errors;
  integer vectors_run;
  integer pass_count;
  integer failed_vectors;
  integer positive_cases;
  integer zero_cases;
  integer negative_cases;
  integer start_pulse_cases;
  integer lane_idx;
  integer hold;
  bit stop_run;
  bit boundary_neg128_seen [0:3];
  bit boundary_neg127_seen [0:3];
  bit boundary_pos127_seen [0:3];

  mlp_core dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .in0(in0),
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .done(done),
    .busy(busy),
    .out_bit(out_bit)
  );

  always #5 clk = ~clk;

  function automatic integer total_errors_count;
    total_errors_count = output_errors + latency_errors + handshake_errors + coverage_errors;
  endfunction

  task automatic drive_inputs(input logic [31:0] packed_word);
    begin
      in0 = packed_word[31:24];
      in1 = packed_word[23:16];
      in2 = packed_word[15:8];
      in3 = packed_word[7:0];
    end
  endtask

  task automatic record_suite_input_boundaries(input logic [31:0] packed_word);
    logic signed [7:0] lane0_value;
    logic signed [7:0] lane1_value;
    logic signed [7:0] lane2_value;
    logic signed [7:0] lane3_value;
    begin
      lane0_value = packed_word[31:24];
      lane1_value = packed_word[23:16];
      lane2_value = packed_word[15:8];
      lane3_value = packed_word[7:0];

      if (lane0_value == 8'sh80) boundary_neg128_seen[0] = 1'b1;
      if (lane0_value == -8'sd127) boundary_neg127_seen[0] = 1'b1;
      if (lane0_value == 8'sd127) boundary_pos127_seen[0] = 1'b1;

      if (lane1_value == 8'sh80) boundary_neg128_seen[1] = 1'b1;
      if (lane1_value == -8'sd127) boundary_neg127_seen[1] = 1'b1;
      if (lane1_value == 8'sd127) boundary_pos127_seen[1] = 1'b1;

      if (lane2_value == 8'sh80) boundary_neg128_seen[2] = 1'b1;
      if (lane2_value == -8'sd127) boundary_neg127_seen[2] = 1'b1;
      if (lane2_value == 8'sd127) boundary_pos127_seen[2] = 1'b1;

      if (lane3_value == 8'sh80) boundary_neg128_seen[3] = 1'b1;
      if (lane3_value == -8'sd127) boundary_neg127_seen[3] = 1'b1;
      if (lane3_value == 8'sd127) boundary_pos127_seen[3] = 1'b1;
    end
  endtask

  task automatic start_transaction(input bit hold_done);
    begin
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);

      if (busy !== 1'b1) begin
        $display("FAIL accept: busy must assert immediately after accepted start");
        handshake_errors = handshake_errors + 1;
      end
      if (done !== 1'b0) begin
        $display("FAIL accept: done must remain low during active execution");
        handshake_errors = handshake_errors + 1;
      end

      if (!hold_done) begin
        start = 1'b0;
      end
    end
  endtask

  task automatic wait_for_release(input integer vector_idx, input bit hold_done);
    logic saved_out;
    begin
      if (hold_done) begin
        saved_out = out_bit;
        for (hold = 0; hold < STABILITY_HOLD_CYCLES; hold = hold + 1) begin
          @(negedge clk);
          if (done !== 1'b1) begin
            $display("FAIL idx=%0d: done deasserted while start held high in DONE (hold=%0d)", vector_idx, hold);
            handshake_errors = handshake_errors + 1;
          end
          if (busy !== 1'b0) begin
            $display("FAIL idx=%0d: busy asserted while holding DONE (hold=%0d)", vector_idx, hold);
            handshake_errors = handshake_errors + 1;
          end
          if (out_bit !== saved_out) begin
            $display("FAIL idx=%0d: out_bit changed while DONE held high (hold=%0d)", vector_idx, hold);
            handshake_errors = handshake_errors + 1;
          end
        end

        start = 1'b0;
      end

      @(negedge clk);
      if (done !== 1'b0 || busy !== 1'b0) begin
        $display("FAIL idx=%0d: expected release to idle boundary with done=0 busy=0", vector_idx);
        handshake_errors = handshake_errors + 1;
      end

      @(negedge clk);
      if (done !== 1'b0 || busy !== 1'b0) begin
        $display("FAIL idx=%0d: expected stable idle signals after release", vector_idx);
        handshake_errors = handshake_errors + 1;
      end
    end
  endtask

  task automatic check_load_input_sampling;
    logic [64:0] sampled_vector;
    logic [31:0] early_inputs;
    logic [31:0] sampled_inputs;
    logic expected_out;
    integer latency;
    integer timeout_cycles;
    begin
      sampled_vector = vectors[0];
      early_inputs = 32'h11_22_33_44;
      sampled_inputs = sampled_vector[31:0];
      expected_out = sampled_vector[32];

      drive_inputs(early_inputs);
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);

      if (busy !== 1'b1 || done !== 1'b0) begin
        $display("FAIL capture: expected active handshake immediately after accepted start");
        handshake_errors = handshake_errors + 1;
      end

      drive_inputs(sampled_inputs);
      start = 1'b0;
      latency = 1;
      timeout_cycles = 0;

      while (done !== 1'b1 && timeout_cycles <= EXPECTED_CYCLES + 20) begin
        @(negedge clk);
        timeout_cycles = timeout_cycles + 1;
        latency = latency + 1;

        if (done !== 1'b1 && busy !== 1'b1) begin
          $display("FAIL capture: busy deasserted during capture-semantic transaction");
          handshake_errors = handshake_errors + 1;
        end
      end

      if (done !== 1'b1) begin
        $display("FAIL capture: timed out waiting for capture-semantic transaction to finish");
        handshake_errors = handshake_errors + 1;
        stop_run = 1'b1;
      end else begin
        if (latency != EXPECTED_CYCLES) begin
          $display("FAIL capture: expected latency=%0d got=%0d", EXPECTED_CYCLES, latency);
          latency_errors = latency_errors + 1;
        end
        if (out_bit !== expected_out) begin
          $display("FAIL capture: sampled LOAD_INPUT bus value did not determine the final output");
          output_errors = output_errors + 1;
        end
        wait_for_release(-1, 1'b0);
      end
    end
  endtask

  task automatic run_vector(
    input integer vector_idx,
    input bit hold_done,
    input bit pulse_start_during_active
  );
    logic [31:0] packed_inputs;
    logic expected_out;
    logic signed [31:0] expected_score;
    integer latency;
    integer timeout_cycles;
    integer starting_errors;
    bit timed_out;
    bit injected_active_start;
    bit clear_active_start;
    begin
      packed_inputs = vectors[vector_idx][31:0];
      expected_out = vectors[vector_idx][32];
      expected_score = $signed(vectors[vector_idx][64:33]);
      starting_errors = total_errors_count();
      vectors_run = vectors_run + 1;

      if ((expected_score > 0 && expected_out !== 1'b1) ||
          (expected_score == 0 && expected_out !== 1'b0) ||
          (expected_score < 0 && expected_out !== 1'b0)) begin
        $display("FAIL idx=%0d: vector payload is internally inconsistent score=%0d out=%0d", vector_idx, expected_score, expected_out);
        coverage_errors = coverage_errors + 1;
      end

      if (expected_score > 0) begin
        positive_cases = positive_cases + 1;
      end else if (expected_score == 0) begin
        zero_cases = zero_cases + 1;
      end else begin
        negative_cases = negative_cases + 1;
      end

      drive_inputs(packed_inputs);
      record_suite_input_boundaries(packed_inputs);
      start_transaction(hold_done);

      latency = 1;
      timeout_cycles = 0;
      timed_out = 1'b0;
      injected_active_start = 1'b0;
      clear_active_start = 1'b0;

      while (done !== 1'b1 && !timed_out) begin
        @(negedge clk);
        timeout_cycles = timeout_cycles + 1;
        latency = latency + 1;

        if (clear_active_start) begin
          start = 1'b0;
          clear_active_start = 1'b0;
        end else if (pulse_start_during_active &&
                     !injected_active_start &&
                     latency == ACTIVE_WINDOW_START_PULSE_LATENCY) begin
          start = 1'b1;
          clear_active_start = 1'b1;
          injected_active_start = 1'b1;
          start_pulse_cases = start_pulse_cases + 1;
        end

        if (done !== 1'b1 && busy !== 1'b1) begin
          $display("FAIL idx=%0d latency=%0d: busy deasserted during active computation", vector_idx, latency);
          handshake_errors = handshake_errors + 1;
        end

        if (timeout_cycles > EXPECTED_CYCLES + 20) begin
          $display("FAIL idx=%0d: timed out waiting for done after %0d cycles", vector_idx, timeout_cycles);
          handshake_errors = handshake_errors + 1;
          stop_run = 1'b1;
          timed_out = 1'b1;
        end
      end

      if (!timed_out) begin
        if (pulse_start_during_active && !injected_active_start) begin
          $display("FAIL idx=%0d: did not exercise active-window start pulse", vector_idx);
          coverage_errors = coverage_errors + 1;
        end

        if (busy !== 1'b0) begin
          $display("FAIL idx=%0d: busy asserted while done is high", vector_idx);
          handshake_errors = handshake_errors + 1;
        end

        if (latency != EXPECTED_CYCLES) begin
          $display("FAIL idx=%0d inputs=%h: expected latency=%0d got=%0d", vector_idx, packed_inputs, EXPECTED_CYCLES, latency);
          latency_errors = latency_errors + 1;
        end

        if (out_bit !== expected_out) begin
          $display("FAIL idx=%0d inputs=%h score=%0d expected=%0d got=%0d latency=%0d", vector_idx, packed_inputs, expected_score, expected_out, out_bit, latency);
          output_errors = output_errors + 1;
        end

        wait_for_release(vector_idx, hold_done);

        if (total_errors_count() == starting_errors) begin
          pass_count = pass_count + 1;
          $display("PASS idx=%0d inputs=%h score=%0d out=%0d latency=%0d", vector_idx, packed_inputs, expected_score, out_bit, latency);
        end
      end

      if (total_errors_count() != starting_errors) begin
        failed_vectors = failed_vectors + 1;
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    in0 = '0;
    in1 = '0;
    in2 = '0;
    in3 = '0;
    output_errors = 0;
    latency_errors = 0;
    handshake_errors = 0;
    coverage_errors = 0;
    vectors_run = 0;
    pass_count = 0;
    failed_vectors = 0;
    positive_cases = 0;
    zero_cases = 0;
    negative_cases = 0;
    start_pulse_cases = 0;
    stop_run = 1'b0;

    for (lane_idx = 0; lane_idx < 4; lane_idx = lane_idx + 1) begin
      boundary_neg128_seen[lane_idx] = 1'b0;
      boundary_neg127_seen[lane_idx] = 1'b0;
      boundary_pos127_seen[lane_idx] = 1'b0;
    end

    $readmemh("simulations/shared/test_vectors.mem", vectors);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    if (busy !== 1'b0 || done !== 1'b0) begin
      $display("FAIL reset: expected idle-visible outputs busy=0 done=0, got busy=%0d done=%0d", busy, done);
      handshake_errors = handshake_errors + 1;
    end

    check_load_input_sampling();

    if (!stop_run) begin
      for (idx = 0; idx < NUM_VECTORS; idx = idx + 1) begin
        run_vector(idx, idx == 0, idx == 1);
        if (stop_run) begin
          break;
        end
      end
    end

    if (!stop_run) begin
      if (positive_cases == 0) begin
        $display("FAIL suite: missing positive-score test vector");
        coverage_errors = coverage_errors + 1;
      end
      if (zero_cases == 0) begin
        $display("FAIL suite: missing zero-score test vector");
        coverage_errors = coverage_errors + 1;
      end
      if (negative_cases == 0) begin
        $display("FAIL suite: missing negative-score test vector");
        coverage_errors = coverage_errors + 1;
      end
      if (start_pulse_cases == 0) begin
        $display("FAIL suite: missing active-window start pulse regression");
        coverage_errors = coverage_errors + 1;
      end

      for (lane_idx = 0; lane_idx < 4; lane_idx = lane_idx + 1) begin
        if (!boundary_neg128_seen[lane_idx]) begin
          $display("FAIL suite: missing -128 boundary coverage on input lane %0d", lane_idx);
          coverage_errors = coverage_errors + 1;
        end
        if (!boundary_neg127_seen[lane_idx]) begin
          $display("FAIL suite: missing -127 boundary coverage on input lane %0d", lane_idx);
          coverage_errors = coverage_errors + 1;
        end
        if (!boundary_pos127_seen[lane_idx]) begin
          $display("FAIL suite: missing +127 boundary coverage on input lane %0d", lane_idx);
          coverage_errors = coverage_errors + 1;
        end
      end
    end else begin
      $display("INFO suite: skipped score-class coverage checks after early abort");
    end

    $display("---");
    $display("vectors:    %0d", vectors_run);
    $display("passes:     %0d", pass_count);
    $display("failures:   %0d", failed_vectors);
    $display("output:     %0d", output_errors);
    $display("latency:    %0d", latency_errors);
    $display("handshake:  %0d", handshake_errors);
    $display("coverage:   %0d", coverage_errors);

    if (total_errors_count() == 0) begin
      $display("PASS all vectors");
      $finish;
    end else begin
      $fatal(1, "FAIL total_errors=%0d", total_errors_count());
    end
  end
endmodule
