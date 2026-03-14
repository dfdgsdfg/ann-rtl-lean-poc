module formal_mlp_core_boundaries;
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN  = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;

  (* gclk *) reg clk;

  logic              rst_n;
  logic              start;
  logic signed [7:0] in0;
  logic signed [7:0] in1;
  logic signed [7:0] in2;
  logic signed [7:0] in3;
  logic              done;
  logic              busy;
  logic              out_bit;
  logic [3:0]        formal_state;
  logic [3:0]        formal_hidden_idx;
  logic [3:0]        formal_input_idx;
  logic              formal_do_mac_hidden;
  logic              formal_do_bias_hidden;
  logic              formal_do_act_hidden;
  logic              formal_advance_hidden;
  logic              formal_do_mac_output;
  logic              formal_do_bias_output;
  logic signed [31:0] formal_acc_reg;
  logic signed [31:0] formal_mac_acc_out;
  logic signed [15:0] formal_mac_a;
  logic signed [31:0] formal_b2_data;

  reg [6:0] step;

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
    .out_bit(out_bit),
    .formal_state(formal_state),
    .formal_hidden_idx(formal_hidden_idx),
    .formal_input_idx(formal_input_idx),
    .formal_do_mac_hidden(formal_do_mac_hidden),
    .formal_do_bias_hidden(formal_do_bias_hidden),
    .formal_do_act_hidden(formal_do_act_hidden),
    .formal_advance_hidden(formal_advance_hidden),
    .formal_do_mac_output(formal_do_mac_output),
    .formal_do_bias_output(formal_do_bias_output),
    .formal_acc_reg(formal_acc_reg),
    .formal_mac_acc_out(formal_mac_acc_out),
    .formal_mac_a(formal_mac_a),
    .formal_b2_data(formal_b2_data)
  );

  initial begin
    step = 7'd0;
  end

  always @* begin
    assume (rst_n == (step >= 7'd2));
    assume (start == (step == 7'd2));
    if (step == 7'd2) begin
      assume (formal_state == IDLE);
      assume (formal_hidden_idx == 4'd0);
      assume (formal_input_idx == 4'd0);
    end
  end

  always @(posedge clk) begin
    if (step < 7'd79) begin
      step <= step + 7'd1;
    end

    if (step == 7'd2) begin
      assert (formal_state == IDLE);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd0);
    end

    if (step == 7'd3) begin
      assert (formal_state == LOAD_INPUT);
    end

    if (step == 7'd8) begin
      assert (formal_state == MAC_HIDDEN);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd4);
      assert (!formal_do_mac_hidden);
      assert (formal_acc_reg == $past(formal_mac_acc_out));
    end

    if (step == 7'd9) begin
      assert (formal_state == BIAS_HIDDEN);
      assert (formal_do_bias_hidden);
    end

    if (step == 7'd64) begin
      assert (formal_state == MAC_HIDDEN);
      assert (formal_hidden_idx == 4'd7);
      assert (formal_input_idx == 4'd4);
      assert (!formal_do_mac_hidden);
      assert (formal_acc_reg == $past(formal_mac_acc_out));
    end

    if (step == 7'd65) begin
      assert (formal_state == BIAS_HIDDEN);
      assert (formal_hidden_idx == 4'd7);
      assert (formal_do_bias_hidden);
    end

    if (step == 7'd67) begin
      assert (formal_state == NEXT_HIDDEN);
      assert (formal_hidden_idx == 4'd7);
    end

    if (step == 7'd68) begin
      assert (formal_state == MAC_OUTPUT);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd0);
      assert (formal_do_mac_output);
    end

    if (step == 7'd76) begin
      assert (formal_state == MAC_OUTPUT);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd8);
      assert (!formal_do_mac_output);
      assert (formal_acc_reg == $past(formal_mac_acc_out));
    end

    if (step == 7'd77) begin
      assert (formal_state == BIAS_OUTPUT);
      assert (formal_do_bias_output);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd8);
    end

    if (step == 7'd78) begin
      assert (formal_state == DONE);
      assert (done);
      assert (!busy);
      assert (formal_hidden_idx == 4'd0);
      assert (formal_input_idx == 4'd8);
      assert (formal_acc_reg == ($past(formal_acc_reg) + $past(formal_b2_data)));
      assert (out_bit == ($signed($past(formal_acc_reg) + $past(formal_b2_data)) > 0));
    end
  end
endmodule
