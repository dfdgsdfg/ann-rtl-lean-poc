module formal_closed_loop_mlp_core_equivalence;
  localparam logic [3:0] IDLE = 4'd0;

  (* gclk *) reg clk;

  logic              rst_n;
  logic              start;
  logic signed [7:0] in0;
  logic signed [7:0] in1;
  logic signed [7:0] in2;
  logic signed [7:0] in3;

  logic              baseline_done;
  logic              baseline_busy;
  logic              baseline_out_bit;
  logic [3:0]        baseline_formal_state;
  logic [3:0]        baseline_formal_hidden_idx;
  logic [3:0]        baseline_formal_input_idx;
  logic              baseline_formal_load_input;
  logic              baseline_formal_do_mac_hidden;
  logic              baseline_formal_do_bias_hidden;
  logic              baseline_formal_do_act_hidden;
  logic              baseline_formal_advance_hidden;
  logic              baseline_formal_do_mac_output;
  logic              baseline_formal_do_bias_output;
  logic signed [7:0] baseline_formal_input_reg0;
  logic signed [7:0] baseline_formal_input_reg1;
  logic signed [7:0] baseline_formal_input_reg2;
  logic signed [7:0] baseline_formal_input_reg3;
  logic signed [31:0] baseline_formal_acc_reg;

  logic              generated_done;
  logic              generated_busy;
  logic              generated_out_bit;
  logic [3:0]        generated_formal_state;
  logic [3:0]        generated_formal_hidden_idx;
  logic [3:0]        generated_formal_input_idx;
  logic              generated_formal_load_input;
  logic              generated_formal_do_mac_hidden;
  logic              generated_formal_do_bias_hidden;
  logic              generated_formal_do_act_hidden;
  logic              generated_formal_advance_hidden;
  logic              generated_formal_do_mac_output;
  logic              generated_formal_do_bias_output;
  logic signed [7:0] generated_formal_input_reg0;
  logic signed [7:0] generated_formal_input_reg1;
  logic signed [7:0] generated_formal_input_reg2;
  logic signed [7:0] generated_formal_input_reg3;
  logic signed [31:0] generated_formal_acc_reg;

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
    .out_bit(baseline_out_bit),
    .formal_state(baseline_formal_state),
    .formal_hidden_idx(baseline_formal_hidden_idx),
    .formal_input_idx(baseline_formal_input_idx),
    .formal_load_input(baseline_formal_load_input),
    .formal_do_mac_hidden(baseline_formal_do_mac_hidden),
    .formal_do_bias_hidden(baseline_formal_do_bias_hidden),
    .formal_do_act_hidden(baseline_formal_do_act_hidden),
    .formal_advance_hidden(baseline_formal_advance_hidden),
    .formal_do_mac_output(baseline_formal_do_mac_output),
    .formal_do_bias_output(baseline_formal_do_bias_output),
    .formal_input_reg0(baseline_formal_input_reg0),
    .formal_input_reg1(baseline_formal_input_reg1),
    .formal_input_reg2(baseline_formal_input_reg2),
    .formal_input_reg3(baseline_formal_input_reg3),
    .formal_hidden_input_case_hit(),
    .formal_output_hidden_case_hit(),
    .formal_hidden_weight_case_hit(),
    .formal_output_weight_case_hit(),
    .formal_acc_reg(baseline_formal_acc_reg),
    .formal_mac_acc_out(),
    .formal_mac_a(),
    .formal_b2_data()
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
    .out_bit(generated_out_bit),
    .formal_state(generated_formal_state),
    .formal_hidden_idx(generated_formal_hidden_idx),
    .formal_input_idx(generated_formal_input_idx),
    .formal_load_input(generated_formal_load_input),
    .formal_do_mac_hidden(generated_formal_do_mac_hidden),
    .formal_do_bias_hidden(generated_formal_do_bias_hidden),
    .formal_do_act_hidden(generated_formal_do_act_hidden),
    .formal_advance_hidden(generated_formal_advance_hidden),
    .formal_do_mac_output(generated_formal_do_mac_output),
    .formal_do_bias_output(generated_formal_do_bias_output),
    .formal_input_reg0(generated_formal_input_reg0),
    .formal_input_reg1(generated_formal_input_reg1),
    .formal_input_reg2(generated_formal_input_reg2),
    .formal_input_reg3(generated_formal_input_reg3),
    .formal_hidden_input_case_hit(),
    .formal_output_hidden_case_hit(),
    .formal_hidden_weight_case_hit(),
    .formal_output_weight_case_hit(),
    .formal_acc_reg(generated_formal_acc_reg),
    .formal_mac_acc_out(),
    .formal_mac_a(),
    .formal_b2_data()
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
      assume (baseline_formal_state == IDLE);
      assume (baseline_formal_hidden_idx == 4'd0);
      assume (baseline_formal_input_idx == 4'd0);
      assume (!baseline_done);
      assume (!baseline_busy);
      assume (!baseline_out_bit);
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
      assert (generated_formal_state == baseline_formal_state);
      assert (generated_formal_hidden_idx == baseline_formal_hidden_idx);
      assert (generated_formal_input_idx == baseline_formal_input_idx);
      assert (generated_formal_load_input == baseline_formal_load_input);
      assert (generated_formal_do_mac_hidden == baseline_formal_do_mac_hidden);
      assert (generated_formal_do_bias_hidden == baseline_formal_do_bias_hidden);
      assert (generated_formal_do_act_hidden == baseline_formal_do_act_hidden);
      assert (generated_formal_advance_hidden == baseline_formal_advance_hidden);
      assert (generated_formal_do_mac_output == baseline_formal_do_mac_output);
      assert (generated_formal_do_bias_output == baseline_formal_do_bias_output);
      assert (generated_formal_input_reg0 == baseline_formal_input_reg0);
      assert (generated_formal_input_reg1 == baseline_formal_input_reg1);
      assert (generated_formal_input_reg2 == baseline_formal_input_reg2);
      assert (generated_formal_input_reg3 == baseline_formal_input_reg3);
      assert (generated_formal_acc_reg == baseline_formal_acc_reg);
    end
  end
endmodule
