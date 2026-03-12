`timescale 1ns/1ps

module testbench;
  localparam int NUM_VECTORS = 16;
  localparam int EXPECTED_CYCLES = 76;
  localparam int STABILITY_HOLD_CYCLES = 3;

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

  logic [32:0] vectors [0:NUM_VECTORS-1];

  integer idx;
  integer errors;
  integer cycle_count;
  integer stability_errors;
  integer busy_errors;

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

  task automatic drive_inputs(input logic [31:0] packed);
    begin
      in0 = packed[31:24];
      in1 = packed[23:16];
      in2 = packed[15:8];
      in3 = packed[7:0];
    end
  endtask

  task automatic pulse_start;
    begin
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;
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
    errors = 0;
    stability_errors = 0;
    busy_errors = 0;

    $readmemh("simulations/rtl/test_vectors.mem", vectors);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // Check initial idle state: done=0, busy=0
    @(posedge clk);
    if (busy !== 1'b0 || done !== 1'b0) begin
      $display("FAIL idle state: expected busy=0 done=0, got busy=%0d done=%0d", busy, done);
      busy_errors = busy_errors + 1;
    end

    for (idx = 0; idx < NUM_VECTORS; idx = idx + 1) begin
      drive_inputs(vectors[idx][31:0]);
      pulse_start();

      // Count cycles from start to done
      cycle_count = 0;
      while (done !== 1'b1) begin
        @(posedge clk);
        cycle_count = cycle_count + 1;

        // Check busy is asserted during active computation
        if (busy !== 1'b1 && done !== 1'b1) begin
          $display("FAIL idx=%0d cycle=%0d: busy not asserted during active computation", idx, cycle_count);
          busy_errors = busy_errors + 1;
        end

        // Timeout guard
        if (cycle_count > EXPECTED_CYCLES + 20) begin
          $display("FAIL idx=%0d: timed out after %0d cycles", idx, cycle_count);
          errors = errors + 1;
          disable;
        end
      end

      // Now in DONE state: check busy is deasserted
      if (busy !== 1'b0) begin
        $display("FAIL idx=%0d: busy asserted in DONE state", idx);
        busy_errors = busy_errors + 1;
      end

      // Check output correctness
      @(posedge clk);
      if (out_bit !== vectors[idx][32]) begin
        $display("FAIL idx=%0d inputs=%h expected=%0d got=%0d cycles=%0d", idx, vectors[idx][31:0], vectors[idx][32], out_bit, cycle_count);
        errors = errors + 1;
      end else begin
        $display("PASS idx=%0d inputs=%h out=%0d cycles=%0d", idx, vectors[idx][31:0], out_bit, cycle_count);
      end

      // Check cycle count matches expected
      if (cycle_count != EXPECTED_CYCLES) begin
        $display("WARN idx=%0d: expected %0d cycles, got %0d", idx, EXPECTED_CYCLES, cycle_count);
      end

      // Output stability check: hold done for a few more cycles and verify out_bit doesn't change
      begin
        logic saved_out;
        integer hold;
        saved_out = out_bit;
        for (hold = 0; hold < STABILITY_HOLD_CYCLES; hold = hold + 1) begin
          @(posedge clk);
          if (done !== 1'b1) begin
            $display("FAIL idx=%0d: done deasserted during stability check at hold cycle %0d", idx, hold);
            stability_errors = stability_errors + 1;
          end
          if (out_bit !== saved_out) begin
            $display("FAIL idx=%0d: output changed during stability check at hold cycle %0d (was %0d, now %0d)", idx, hold, saved_out, out_bit);
            stability_errors = stability_errors + 1;
          end
          if (busy !== 1'b0) begin
            $display("FAIL idx=%0d: busy asserted during DONE stability check at hold cycle %0d", idx, hold);
            busy_errors = busy_errors + 1;
          end
        end
      end

      // Release: wait for done to deassert (machine returns to IDLE)
      wait (done === 1'b0);
    end

    // Final summary
    begin
      integer total_errors;
      total_errors = errors + stability_errors + busy_errors;
      $display("---");
      $display("vectors:    %0d", NUM_VECTORS);
      $display("output:     %0d pass, %0d fail", NUM_VECTORS - errors, errors);
      $display("stability:  %0d errors", stability_errors);
      $display("busy:       %0d errors", busy_errors);
      if (total_errors == 0) begin
        $display("PASS all vectors");
      end else begin
        $display("FAIL total_errors=%0d", total_errors);
      end
    end

    $finish;
  end
endmodule
