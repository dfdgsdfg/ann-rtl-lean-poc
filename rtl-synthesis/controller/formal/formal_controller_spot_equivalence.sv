module formal_controller_spot_equivalence;
  (* gclk *) reg clk;

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
  localparam logic [3:0] LAST_HIDDEN_IDX = HIDDEN_NEURONS_4B - 4'd1;
  localparam logic [6:0] START_STEP = 7'd2;
  localparam logic [6:0] DONE_HOLD_STEP = 7'd78;

  logic       rst_n;
  logic       start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;

  logic [3:0] baseline_state;
  logic       baseline_load_input;
  logic       baseline_clear_acc;
  logic       baseline_do_mac_hidden;
  logic       baseline_do_bias_hidden;
  logic       baseline_do_act_hidden;
  logic       baseline_advance_hidden;
  logic       baseline_do_mac_output;
  logic       baseline_do_bias_output;
  logic       baseline_done;
  logic       baseline_busy;

  logic [3:0] generated_state;
  logic       generated_load_input;
  logic       generated_clear_acc;
  logic       generated_do_mac_hidden;
  logic       generated_do_bias_hidden;
  logic       generated_do_act_hidden;
  logic       generated_advance_hidden;
  logic       generated_do_mac_output;
  logic       generated_do_bias_output;
  logic       generated_done;
  logic       generated_busy;

  logic [3:0] expected_state;
  logic [3:0] expected_hidden_idx;
  logic [3:0] expected_input_idx;
  logic [3:0] next_expected_state;
  logic [3:0] next_expected_hidden_idx;
  logic [3:0] next_expected_input_idx;
  logic       expected_load_input;
  logic       expected_clear_acc;
  logic       expected_do_mac_hidden;
  logic       expected_do_bias_hidden;
  logic       expected_do_act_hidden;
  logic       expected_advance_hidden;
  logic       expected_do_mac_output;
  logic       expected_do_bias_output;
  logic       expected_done;
  logic       expected_busy;

  reg [6:0] step;

  controller baseline_controller (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(baseline_state),
    .load_input(baseline_load_input),
    .clear_acc(baseline_clear_acc),
    .do_mac_hidden(baseline_do_mac_hidden),
    .do_bias_hidden(baseline_do_bias_hidden),
    .do_act_hidden(baseline_do_act_hidden),
    .advance_hidden(baseline_advance_hidden),
    .do_mac_output(baseline_do_mac_output),
    .do_bias_output(baseline_do_bias_output),
    .done(baseline_done),
    .busy(baseline_busy)
  );

  controller_spot_compat generated_controller (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(generated_state),
    .load_input(generated_load_input),
    .clear_acc(generated_clear_acc),
    .do_mac_hidden(generated_do_mac_hidden),
    .do_bias_hidden(generated_do_bias_hidden),
    .do_act_hidden(generated_do_act_hidden),
    .advance_hidden(generated_advance_hidden),
    .do_mac_output(generated_do_mac_output),
    .do_bias_output(generated_do_bias_output),
    .done(generated_done),
    .busy(generated_busy)
  );

  initial begin
    step = 7'd0;
    expected_state = IDLE;
    expected_hidden_idx = 4'd0;
    expected_input_idx = 4'd0;
  end

  always @* begin
    if (step < START_STEP) begin
      assume (!rst_n);
      assume (!start);
    end else begin
      assume (rst_n);
      if (step == START_STEP || step == DONE_HOLD_STEP) begin
        assume (start);
      end else begin
        assume (!start);
      end
    end

    if (!rst_n) begin
      assume (hidden_idx == 4'd0);
      assume (input_idx == 4'd0);
    end else begin
      assume (hidden_idx == expected_hidden_idx);
      assume (input_idx == expected_input_idx);
    end
  end

  always @* begin
    expected_load_input = 1'b0;
    expected_clear_acc = 1'b0;
    expected_do_mac_hidden = 1'b0;
    expected_do_bias_hidden = 1'b0;
    expected_do_act_hidden = 1'b0;
    expected_advance_hidden = 1'b0;
    expected_do_mac_output = 1'b0;
    expected_do_bias_output = 1'b0;
    expected_done = 1'b0;
    expected_busy = 1'b0;

    unique case (expected_state)
      IDLE: begin
      end
      LOAD_INPUT: begin
        expected_load_input = 1'b1;
        expected_clear_acc = 1'b1;
        expected_busy = 1'b1;
      end
      MAC_HIDDEN: begin
        expected_do_mac_hidden = (expected_input_idx < INPUT_NEURONS_4B);
        expected_busy = 1'b1;
      end
      BIAS_HIDDEN: begin
        expected_do_bias_hidden = 1'b1;
        expected_busy = 1'b1;
      end
      ACT_HIDDEN: begin
        expected_do_act_hidden = 1'b1;
        expected_busy = 1'b1;
      end
      NEXT_HIDDEN: begin
        expected_advance_hidden = 1'b1;
        expected_busy = 1'b1;
      end
      MAC_OUTPUT: begin
        expected_do_mac_output = (expected_input_idx < HIDDEN_NEURONS_4B);
        expected_busy = 1'b1;
      end
      BIAS_OUTPUT: begin
        expected_do_bias_output = 1'b1;
        expected_busy = 1'b1;
      end
      DONE: begin
        expected_done = 1'b1;
      end
      default: begin
      end
    endcase
  end

  always @* begin
    next_expected_state = expected_state;
    next_expected_hidden_idx = expected_hidden_idx;
    next_expected_input_idx = expected_input_idx;

    if (!rst_n) begin
      next_expected_state = IDLE;
      next_expected_hidden_idx = 4'd0;
      next_expected_input_idx = 4'd0;
    end else begin
      unique case (expected_state)
        IDLE: begin
          next_expected_hidden_idx = 4'd0;
          if (start) begin
            next_expected_state = LOAD_INPUT;
            next_expected_input_idx = 4'd0;
          end else begin
            next_expected_state = IDLE;
            next_expected_input_idx = 4'd0;
          end
        end
        LOAD_INPUT: begin
          next_expected_state = MAC_HIDDEN;
          next_expected_hidden_idx = 4'd0;
          next_expected_input_idx = 4'd0;
        end
        MAC_HIDDEN: begin
          next_expected_hidden_idx = expected_hidden_idx;
          if (expected_input_idx < INPUT_NEURONS_4B) begin
            next_expected_state = MAC_HIDDEN;
            next_expected_input_idx = expected_input_idx + 4'd1;
          end else begin
            next_expected_state = BIAS_HIDDEN;
            next_expected_input_idx = INPUT_NEURONS_4B;
          end
        end
        BIAS_HIDDEN: begin
          next_expected_state = ACT_HIDDEN;
          next_expected_hidden_idx = expected_hidden_idx;
          next_expected_input_idx = INPUT_NEURONS_4B;
        end
        ACT_HIDDEN: begin
          next_expected_state = NEXT_HIDDEN;
          next_expected_hidden_idx = expected_hidden_idx;
          next_expected_input_idx = 4'd0;
        end
        NEXT_HIDDEN: begin
          next_expected_input_idx = 4'd0;
          if (expected_hidden_idx == LAST_HIDDEN_IDX) begin
            next_expected_state = MAC_OUTPUT;
            next_expected_hidden_idx = 4'd0;
          end else begin
            next_expected_state = MAC_HIDDEN;
            next_expected_hidden_idx = expected_hidden_idx + 4'd1;
          end
        end
        MAC_OUTPUT: begin
          next_expected_hidden_idx = 4'd0;
          if (expected_input_idx < HIDDEN_NEURONS_4B) begin
            next_expected_state = MAC_OUTPUT;
            next_expected_input_idx = expected_input_idx + 4'd1;
          end else begin
            next_expected_state = BIAS_OUTPUT;
            next_expected_input_idx = HIDDEN_NEURONS_4B;
          end
        end
        BIAS_OUTPUT: begin
          next_expected_state = DONE;
          next_expected_hidden_idx = 4'd0;
          next_expected_input_idx = HIDDEN_NEURONS_4B;
        end
        DONE: begin
          next_expected_hidden_idx = 4'd0;
          if (start) begin
            next_expected_state = DONE;
            next_expected_input_idx = HIDDEN_NEURONS_4B;
          end else begin
            next_expected_state = IDLE;
            next_expected_input_idx = HIDDEN_NEURONS_4B;
          end
        end
        default: begin
          next_expected_state = IDLE;
          next_expected_hidden_idx = 4'd0;
          next_expected_input_idx = 4'd0;
        end
      endcase
    end
  end

  always @(posedge clk) begin
    if (step < 7'd80) begin
      step <= step + 7'd1;
    end

    if (!rst_n) begin
      assert (baseline_state == IDLE);
      assert (!baseline_load_input);
      assert (!baseline_clear_acc);
      assert (!baseline_do_mac_hidden);
      assert (!baseline_do_bias_hidden);
      assert (!baseline_do_act_hidden);
      assert (!baseline_advance_hidden);
      assert (!baseline_do_mac_output);
      assert (!baseline_do_bias_output);
      assert (!baseline_done);
      assert (!baseline_busy);

      assert (generated_state == IDLE);
      assert (!generated_load_input);
      assert (!generated_clear_acc);
      assert (!generated_do_mac_hidden);
      assert (!generated_do_bias_hidden);
      assert (!generated_do_act_hidden);
      assert (!generated_advance_hidden);
      assert (!generated_do_mac_output);
      assert (!generated_do_bias_output);
      assert (!generated_done);
      assert (!generated_busy);
    end else begin
      assert (baseline_state == expected_state);
      assert (baseline_load_input == expected_load_input);
      assert (baseline_clear_acc == expected_clear_acc);
      assert (baseline_do_mac_hidden == expected_do_mac_hidden);
      assert (baseline_do_bias_hidden == expected_do_bias_hidden);
      assert (baseline_do_act_hidden == expected_do_act_hidden);
      assert (baseline_advance_hidden == expected_advance_hidden);
      assert (baseline_do_mac_output == expected_do_mac_output);
      assert (baseline_do_bias_output == expected_do_bias_output);
      assert (baseline_done == expected_done);
      assert (baseline_busy == expected_busy);

      assert (generated_state == expected_state);
      assert (generated_load_input == expected_load_input);
      assert (generated_clear_acc == expected_clear_acc);
      assert (generated_do_mac_hidden == expected_do_mac_hidden);
      assert (generated_do_bias_hidden == expected_do_bias_hidden);
      assert (generated_do_act_hidden == expected_do_act_hidden);
      assert (generated_advance_hidden == expected_advance_hidden);
      assert (generated_do_mac_output == expected_do_mac_output);
      assert (generated_do_bias_output == expected_do_bias_output);
      assert (generated_done == expected_done);
      assert (generated_busy == expected_busy);
    end

    expected_state <= next_expected_state;
    expected_hidden_idx <= next_expected_hidden_idx;
    expected_input_idx <= next_expected_input_idx;
  end
endmodule
