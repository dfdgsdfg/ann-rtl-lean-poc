module formal_controller_interface;
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN  = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;
  localparam logic [3:0] INPUT_NEURONS_4B = 4'd4;
  localparam logic [3:0] HIDDEN_NEURONS_4B = 4'd8;
  localparam logic [3:0] LAST_HIDDEN_IDX = 4'd7;

  (* gclk *) reg clk;

  logic       rst_n;
  logic       start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;
  logic [3:0] state;
  logic       load_input;
  logic       clear_acc;
  logic       do_mac_hidden;
  logic       do_bias_hidden;
  logic       do_act_hidden;
  logic       advance_hidden;
  logic       do_mac_output;
  logic       do_bias_output;
  logic       done;
  logic       busy;

  reg       past_valid;
  reg [3:0] step;

  controller dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(state),
    .load_input(load_input),
    .clear_acc(clear_acc),
    .do_mac_hidden(do_mac_hidden),
    .do_bias_hidden(do_bias_hidden),
    .do_act_hidden(do_act_hidden),
    .advance_hidden(advance_hidden),
    .do_mac_output(do_mac_output),
    .do_bias_output(do_bias_output),
    .done(done),
    .busy(busy)
  );

  function automatic logic [3:0] expected_next_state(
    input logic [3:0] current_state,
    input logic       current_start,
    input logic [3:0] current_hidden_idx,
    input logic [3:0] current_input_idx
  );
    begin
      unique case (current_state)
        IDLE:        expected_next_state = current_start ? LOAD_INPUT : IDLE;
        LOAD_INPUT:  expected_next_state = MAC_HIDDEN;
        MAC_HIDDEN:  expected_next_state = (current_input_idx == INPUT_NEURONS_4B) ? BIAS_HIDDEN : MAC_HIDDEN;
        BIAS_HIDDEN: expected_next_state = ACT_HIDDEN;
        ACT_HIDDEN:  expected_next_state = NEXT_HIDDEN;
        NEXT_HIDDEN: expected_next_state = (current_hidden_idx == LAST_HIDDEN_IDX) ? MAC_OUTPUT : MAC_HIDDEN;
        MAC_OUTPUT:  expected_next_state = (current_input_idx == HIDDEN_NEURONS_4B) ? BIAS_OUTPUT : MAC_OUTPUT;
        BIAS_OUTPUT: expected_next_state = DONE;
        DONE:        expected_next_state = current_start ? DONE : IDLE;
        default:     expected_next_state = IDLE;
      endcase
    end
  endfunction

  initial begin
    past_valid = 1'b0;
    step = 4'd0;
  end

  always @* begin
    if (step < 4'd2) begin
      assume (!rst_n);
    end else begin
      assume (rst_n);
    end
  end

  always @(posedge clk) begin
    past_valid <= 1'b1;
    if (step < 4'd12) begin
      step <= step + 4'd1;
    end

    if (step < 4'd3) begin
      assert (state == IDLE);
    end else begin
      assert (state == expected_next_state($past(state), $past(start), $past(hidden_idx), $past(input_idx)));
    end

    assert (load_input == (state == LOAD_INPUT));
    assert (clear_acc == (state == LOAD_INPUT));
    assert (do_mac_hidden == ((state == MAC_HIDDEN) && (input_idx < INPUT_NEURONS_4B)));
    assert (do_bias_hidden == (state == BIAS_HIDDEN));
    assert (do_act_hidden == (state == ACT_HIDDEN));
    assert (advance_hidden == (state == NEXT_HIDDEN));
    assert (do_mac_output == ((state == MAC_OUTPUT) && (input_idx < HIDDEN_NEURONS_4B)));
    assert (do_bias_output == (state == BIAS_OUTPUT));
    assert (done == (state == DONE));
    assert (busy == ((state != IDLE) && (state != DONE)));

    if (past_valid && (step >= 4'd3) && ($past(state) == DONE) && $past(start)) begin
      assert (state == DONE);
    end

    if (past_valid && (step >= 4'd3) && ($past(state) == DONE) && !$past(start)) begin
      assert (state == IDLE);
    end
  end
endmodule
