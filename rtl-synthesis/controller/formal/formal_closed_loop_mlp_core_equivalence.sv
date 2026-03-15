module formal_closed_loop_mlp_core_equivalence;
  (* gclk *) reg clk;

  logic              rst_n;
  logic              start;
  logic signed [7:0] in0;
  logic signed [7:0] in1;
  logic signed [7:0] in2;
  logic signed [7:0] in3;

  logic baseline_done;
  logic baseline_busy;
  logic baseline_out_bit;

  logic generated_done;
  logic generated_busy;
  logic generated_out_bit;

  reg [6:0] step;

  baseline_mlp_core baseline_dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .in0(in0),
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .done(baseline_done),
    .busy(baseline_busy),
    .out_bit(baseline_out_bit)
  );

  generated_mlp_core generated_dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .in0(in0),
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .done(generated_done),
    .busy(generated_busy),
    .out_bit(generated_out_bit)
  );

  initial begin
    step = 7'd0;
  end

  always @* begin
    assume (rst_n == (step >= 7'd2));
    if (step < 7'd2) begin
      assume (!start);
    end else if (step == 7'd2) begin
      assume (start);
    end else begin
      assume (!start);
    end
  end

  always @(posedge clk) begin
    if (step < 7'd82) begin
      step <= step + 7'd1;
    end

    if (step >= 7'd2) begin
      assert (generated_done == baseline_done);
      assert (generated_busy == baseline_busy);
      assert (generated_out_bit == baseline_out_bit);
    end
  end
endmodule
