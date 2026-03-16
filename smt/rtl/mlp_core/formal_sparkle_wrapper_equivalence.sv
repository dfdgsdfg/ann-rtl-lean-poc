module formal_sparkle_wrapper_equivalence;
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
  logic              formal_load_input;
  logic              formal_do_mac_hidden;
  logic              formal_do_bias_hidden;
  logic              formal_do_act_hidden;
  logic              formal_advance_hidden;
  logic              formal_do_mac_output;
  logic              formal_do_bias_output;
  logic signed [7:0] formal_input_reg0;
  logic signed [7:0] formal_input_reg1;
  logic signed [7:0] formal_input_reg2;
  logic signed [7:0] formal_input_reg3;
  logic              formal_hidden_input_case_hit;
  logic              formal_output_hidden_case_hit;
  logic              formal_hidden_weight_case_hit;
  logic              formal_output_weight_case_hit;
  logic signed [31:0] formal_acc_reg;
  logic signed [31:0] formal_mac_acc_out;
  logic signed [15:0] formal_mac_a;
  logic signed [31:0] formal_b2_data;

  logic              raw_rst;
  logic [298:0]      raw_packed_out;

  assign raw_rst = ~rst_n;

  mlp_core wrapped (
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
    .formal_load_input(formal_load_input),
    .formal_do_mac_hidden(formal_do_mac_hidden),
    .formal_do_bias_hidden(formal_do_bias_hidden),
    .formal_do_act_hidden(formal_do_act_hidden),
    .formal_advance_hidden(formal_advance_hidden),
    .formal_do_mac_output(formal_do_mac_output),
    .formal_do_bias_output(formal_do_bias_output),
    .formal_input_reg0(formal_input_reg0),
    .formal_input_reg1(formal_input_reg1),
    .formal_input_reg2(formal_input_reg2),
    .formal_input_reg3(formal_input_reg3),
    .formal_hidden_input_case_hit(formal_hidden_input_case_hit),
    .formal_output_hidden_case_hit(formal_output_hidden_case_hit),
    .formal_hidden_weight_case_hit(formal_hidden_weight_case_hit),
    .formal_output_weight_case_hit(formal_output_weight_case_hit),
    .formal_acc_reg(formal_acc_reg),
    .formal_mac_acc_out(formal_mac_acc_out),
    .formal_mac_a(formal_mac_a),
    .formal_b2_data(formal_b2_data)
  );

  MlpCore_sparkleMlpCorePacked raw (
    ._gen_start(start),
    ._gen_in0(in0),
    ._gen_in1(in1),
    ._gen_in2(in2),
    ._gen_in3(in3),
    .clk(clk),
    .rst(raw_rst),
    .out(raw_packed_out)
  );

  always @* begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  always @* begin
    assert (done == raw_packed_out[286]);
    assert (busy == raw_packed_out[285]);
    assert (out_bit == raw_packed_out[284]);

    assert (formal_state == raw_packed_out[298:295]);
    assert (formal_load_input == raw_packed_out[294]);
    assert (formal_do_mac_hidden == raw_packed_out[292]);
    assert (formal_do_bias_hidden == raw_packed_out[291]);
    assert (formal_do_act_hidden == raw_packed_out[290]);
    assert (formal_advance_hidden == raw_packed_out[289]);
    assert (formal_do_mac_output == raw_packed_out[288]);
    assert (formal_do_bias_output == raw_packed_out[287]);
    assert (formal_hidden_idx == raw_packed_out[283:280]);
    assert (formal_input_idx == raw_packed_out[279:276]);
    assert (formal_acc_reg == raw_packed_out[275:244]);
    assert (formal_mac_acc_out == raw_packed_out[243:212]);
    assert (formal_mac_a == raw_packed_out[211:196]);
    assert (formal_b2_data == raw_packed_out[195:164]);
    assert (formal_input_reg0 == raw_packed_out[163:156]);
    assert (formal_input_reg1 == raw_packed_out[155:148]);
    assert (formal_input_reg2 == raw_packed_out[147:140]);
    assert (formal_input_reg3 == raw_packed_out[139:132]);
    assert (formal_hidden_input_case_hit == raw_packed_out[3]);
    assert (formal_output_hidden_case_hit == raw_packed_out[2]);
    assert (formal_hidden_weight_case_hit == raw_packed_out[1]);
    assert (formal_output_weight_case_hit == raw_packed_out[0]);
  end
endmodule
