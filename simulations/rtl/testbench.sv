`timescale 1ns/1ps

module testbench;
  `include "test_vectors_meta.svh"
  localparam int EXPECTED_CYCLES = 76;
  localparam int STABILITY_HOLD_CYCLES = 3;
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;

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
  integer boundary_errors;
  integer coverage_errors;
  integer pass_count;
  integer positive_cases;
  integer zero_cases;
  integer negative_cases;
  bit stop_run;

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
    total_errors_count = output_errors + latency_errors + handshake_errors + boundary_errors + coverage_errors;
  endfunction

  task automatic drive_inputs(input logic [31:0] packed);
    begin
      in0 = packed[31:24];
      in1 = packed[23:16];
      in2 = packed[15:8];
      in3 = packed[7:0];
    end
  endtask

  task automatic start_transaction(input bit hold_done);
    begin
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);

      if (dut.state !== LOAD_INPUT) begin
        $display("FAIL accept: expected LOAD_INPUT immediately after start, got state=%0d", dut.state);
        handshake_errors = handshake_errors + 1;
      end
      if (busy !== 1'b1) begin
        $display("FAIL accept: busy must assert immediately after accepted start");
        handshake_errors = handshake_errors + 1;
      end

      if (!hold_done) begin
        start = 1'b0;
      end
    end
  endtask

  task automatic run_vector(input integer vector_idx, input bit hold_done, input bit check_boundaries);
    logic [31:0] packed_inputs;
    logic expected_out;
    logic signed [31:0] expected_score;
    logic saved_out;
    logic [3:0] prev_state;
    logic [3:0] prev_hidden_idx;
    logic [3:0] prev_input_idx;
    logic prev_do_mac_hidden;
    logic prev_do_mac_output;
    integer latency;
    integer hold;
    integer timeout_cycles;
    integer starting_errors;
    bit timed_out;
    bit saw_hidden_guard;
    bit saw_hidden_to_output;
    bit saw_output_guard;
    bit saw_bias_to_done;
    begin
      packed_inputs = vectors[vector_idx][31:0];
      expected_out = vectors[vector_idx][32];
      expected_score = $signed(vectors[vector_idx][64:33]);
      starting_errors = total_errors_count();

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
      start_transaction(hold_done);

      prev_state = dut.state;
      prev_hidden_idx = dut.hidden_idx;
      prev_input_idx = dut.input_idx;
      prev_do_mac_hidden = dut.do_mac_hidden;
      prev_do_mac_output = dut.do_mac_output;
      latency = 1;
      timeout_cycles = 0;
      timed_out = 1'b0;
      saw_hidden_guard = 1'b0;
      saw_hidden_to_output = 1'b0;
      saw_output_guard = 1'b0;
      saw_bias_to_done = 1'b0;

      while (done !== 1'b1 && !timed_out) begin
        @(negedge clk);
        timeout_cycles = timeout_cycles + 1;
        latency = latency + 1;

        if (busy !== 1'b1 && done !== 1'b1) begin
          $display("FAIL idx=%0d latency=%0d: busy deasserted during active computation", vector_idx, latency);
          handshake_errors = handshake_errors + 1;
        end

        if (check_boundaries) begin
          if (prev_state == MAC_HIDDEN &&
              prev_do_mac_hidden === 1'b1 &&
              prev_input_idx == 4'd3 &&
              dut.state == MAC_HIDDEN &&
              dut.do_mac_hidden === 1'b0 &&
              dut.input_idx == 4'd4) begin
            saw_hidden_guard = 1'b1;
          end

          if (prev_state == NEXT_HIDDEN &&
              prev_hidden_idx == 4'd7 &&
              dut.state == MAC_OUTPUT &&
              dut.hidden_idx == 4'd0 &&
              dut.input_idx == 4'd0) begin
            saw_hidden_to_output = 1'b1;
          end

          if (prev_state == MAC_OUTPUT &&
              prev_do_mac_output === 1'b1 &&
              prev_input_idx == 4'd7 &&
              dut.state == MAC_OUTPUT &&
              dut.do_mac_output === 1'b0 &&
              dut.input_idx == 4'd8) begin
            saw_output_guard = 1'b1;
          end

          if (prev_state == BIAS_OUTPUT &&
              dut.state == DONE &&
              done === 1'b1) begin
            saw_bias_to_done = 1'b1;
          end
        end

        if (timeout_cycles > EXPECTED_CYCLES + 20) begin
          $display("FAIL idx=%0d: timed out waiting for done after %0d cycles", vector_idx, timeout_cycles);
          handshake_errors = handshake_errors + 1;
          stop_run = 1'b1;
          timed_out = 1'b1;
        end

        prev_state = dut.state;
        prev_hidden_idx = dut.hidden_idx;
        prev_input_idx = dut.input_idx;
        prev_do_mac_hidden = dut.do_mac_hidden;
        prev_do_mac_output = dut.do_mac_output;
      end

      if (!timed_out) begin
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

        if (check_boundaries) begin
          if (!saw_hidden_guard) begin
            $display("FAIL idx=%0d: missing hidden MAC guard-cycle transition", vector_idx);
            boundary_errors = boundary_errors + 1;
          end
          if (!saw_hidden_to_output) begin
            $display("FAIL idx=%0d: missing final hidden-neuron handoff into MAC_OUTPUT", vector_idx);
            boundary_errors = boundary_errors + 1;
          end
          if (!saw_output_guard) begin
            $display("FAIL idx=%0d: missing output MAC guard-cycle transition", vector_idx);
            boundary_errors = boundary_errors + 1;
          end
          if (!saw_bias_to_done) begin
            $display("FAIL idx=%0d: missing BIAS_OUTPUT to DONE visibility transition", vector_idx);
            boundary_errors = boundary_errors + 1;
          end
        end

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
          @(negedge clk);
          if (done !== 1'b0 || busy !== 1'b0 || dut.state !== IDLE) begin
            $display("FAIL idx=%0d: expected one-cycle return to IDLE after dropping start in DONE", vector_idx);
            handshake_errors = handshake_errors + 1;
          end
        end else begin
          @(negedge clk);
          if (done !== 1'b0 || busy !== 1'b0 || dut.state !== IDLE) begin
            $display("FAIL idx=%0d: expected automatic return to IDLE after DONE with start low", vector_idx);
            handshake_errors = handshake_errors + 1;
          end
        end

        if (total_errors_count() == starting_errors) begin
          pass_count = pass_count + 1;
          $display("PASS idx=%0d inputs=%h score=%0d out=%0d latency=%0d", vector_idx, packed_inputs, expected_score, out_bit, latency);
        end
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
    boundary_errors = 0;
    coverage_errors = 0;
    pass_count = 0;
    positive_cases = 0;
    zero_cases = 0;
    negative_cases = 0;
    stop_run = 1'b0;

    $readmemh("simulations/rtl/test_vectors.mem", vectors);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    if (busy !== 1'b0 || done !== 1'b0 || dut.state !== IDLE) begin
      $display("FAIL reset: expected IDLE with busy=0 done=0, got state=%0d busy=%0d done=%0d", dut.state, busy, done);
      handshake_errors = handshake_errors + 1;
    end

    for (idx = 0; idx < NUM_VECTORS; idx = idx + 1) begin
      run_vector(idx, idx == 0, idx == 0);
      if (stop_run) begin
        break;
      end
    end

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

    $display("---");
    $display("vectors:    %0d", NUM_VECTORS);
    $display("passes:     %0d", pass_count);
    $display("output:     %0d", output_errors);
    $display("latency:    %0d", latency_errors);
    $display("handshake:  %0d", handshake_errors);
    $display("boundary:   %0d", boundary_errors);
    $display("coverage:   %0d", coverage_errors);

    if (total_errors_count() == 0) begin
      $display("PASS all vectors");
      $finish;
    end else begin
      $fatal(1, "FAIL total_errors=%0d", total_errors_count());
    end
  end
endmodule
