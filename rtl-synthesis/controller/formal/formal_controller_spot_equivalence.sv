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

  reg [6:0] step;
  logic history_valid;
  logic sampled_rst_n;
  logic sampled_start;
  logic [3:0] sampled_hidden_idx;
  logic [3:0] sampled_input_idx;
  logic [3:0] sampled_baseline_state;
  logic prev_sampled_rst_n;
  logic prev_sampled_start;
  logic [3:0] prev_sampled_hidden_idx;
  logic [3:0] prev_sampled_input_idx;
  logic [3:0] prev_sampled_baseline_state;

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
    history_valid = 1'b0;
    sampled_rst_n = 1'b0;
    sampled_start = 1'b0;
    sampled_hidden_idx = 4'd0;
    sampled_input_idx = 4'd0;
    sampled_baseline_state = IDLE;
    prev_sampled_rst_n = 1'b0;
    prev_sampled_start = 1'b0;
    prev_sampled_hidden_idx = 4'd0;
    prev_sampled_input_idx = 4'd0;
    prev_sampled_baseline_state = IDLE;
  end

  always @(negedge clk) begin
    sampled_rst_n <= rst_n;
    sampled_start <= start;
    sampled_hidden_idx <= hidden_idx;
    sampled_input_idx <= input_idx;
    sampled_baseline_state <= baseline_state;
  end

  always @* begin
    if (step < 7'd2) begin
      assume (!sampled_rst_n);
    end

    if (!sampled_rst_n) begin
      assume (sampled_hidden_idx == 4'd0);
      assume (sampled_input_idx == 4'd0);
    end else begin
      unique case (sampled_baseline_state)
        IDLE: begin
          assume (sampled_hidden_idx == 4'd0);
          if (history_valid && prev_sampled_rst_n && prev_sampled_baseline_state == DONE && !prev_sampled_start) begin
            assume (sampled_input_idx == HIDDEN_NEURONS_4B);
          end else begin
            assume (sampled_input_idx == 4'd0);
          end
        end
        LOAD_INPUT: begin
          assume (sampled_hidden_idx == 4'd0);
          assume (sampled_input_idx == 4'd0);
        end
        MAC_HIDDEN: begin
          assume (sampled_hidden_idx <= LAST_HIDDEN_IDX);
          assume (sampled_input_idx <= INPUT_NEURONS_4B);
        end
        BIAS_HIDDEN: begin
          assume (sampled_hidden_idx <= LAST_HIDDEN_IDX);
          assume (sampled_input_idx == INPUT_NEURONS_4B);
        end
        ACT_HIDDEN: begin
          assume (sampled_hidden_idx <= LAST_HIDDEN_IDX);
          assume (sampled_input_idx == INPUT_NEURONS_4B);
        end
        NEXT_HIDDEN: begin
          assume (sampled_hidden_idx <= LAST_HIDDEN_IDX);
          assume (sampled_input_idx == 4'd0);
        end
        MAC_OUTPUT: begin
          assume (sampled_hidden_idx == 4'd0);
          assume (sampled_input_idx <= HIDDEN_NEURONS_4B);
        end
        BIAS_OUTPUT: begin
          assume (sampled_hidden_idx == 4'd0);
          assume (sampled_input_idx == HIDDEN_NEURONS_4B);
        end
        DONE: begin
          assume (sampled_hidden_idx == 4'd0);
          assume (sampled_input_idx == HIDDEN_NEURONS_4B);
        end
        default: begin
          assume (1'b0);
        end
      endcase

      if (history_valid) begin
        if (!prev_sampled_rst_n && sampled_rst_n) begin
          assume (sampled_hidden_idx == 4'd0);
          assume (sampled_input_idx == 4'd0);
        end else if (prev_sampled_rst_n && sampled_rst_n) begin
          unique case (prev_sampled_baseline_state)
            IDLE: begin
              assume (sampled_hidden_idx == 4'd0);
              assume (sampled_input_idx == 4'd0);
            end
            LOAD_INPUT: begin
              assume (sampled_hidden_idx == 4'd0);
              assume (sampled_input_idx == 4'd0);
            end
            MAC_HIDDEN: begin
              assume (sampled_hidden_idx == prev_sampled_hidden_idx);
              if (prev_sampled_input_idx < INPUT_NEURONS_4B) begin
                assume (sampled_input_idx == prev_sampled_input_idx + 4'd1);
              end else begin
                assume (sampled_input_idx == INPUT_NEURONS_4B);
              end
            end
            BIAS_HIDDEN: begin
              assume (sampled_hidden_idx == prev_sampled_hidden_idx);
              assume (sampled_input_idx == INPUT_NEURONS_4B);
            end
            ACT_HIDDEN: begin
              assume (sampled_hidden_idx == prev_sampled_hidden_idx);
              assume (sampled_input_idx == 4'd0);
            end
            NEXT_HIDDEN: begin
              assume (sampled_input_idx == 4'd0);
              if (prev_sampled_hidden_idx == LAST_HIDDEN_IDX) begin
                assume (sampled_hidden_idx == 4'd0);
              end else begin
                assume (sampled_hidden_idx == prev_sampled_hidden_idx + 4'd1);
              end
            end
            MAC_OUTPUT: begin
              assume (sampled_hidden_idx == 4'd0);
              if (prev_sampled_input_idx < HIDDEN_NEURONS_4B) begin
                assume (sampled_input_idx == prev_sampled_input_idx + 4'd1);
              end else begin
                assume (sampled_input_idx == HIDDEN_NEURONS_4B);
              end
            end
            BIAS_OUTPUT: begin
              assume (sampled_hidden_idx == 4'd0);
              assume (sampled_input_idx == HIDDEN_NEURONS_4B);
            end
            DONE: begin
              assume (sampled_hidden_idx == 4'd0);
              assume (sampled_input_idx == HIDDEN_NEURONS_4B);
            end
            default: begin
              assume (1'b0);
            end
          endcase
        end
      end
    end
  end

  always @(posedge clk) begin
    if (step < 7'd80) begin
      step <= step + 7'd1;
    end

    assume (rst_n == sampled_rst_n);
    assume (start == sampled_start);
    assume (hidden_idx == sampled_hidden_idx);
    assume (input_idx == sampled_input_idx);

    if (!sampled_rst_n) begin
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
    end

    assert (generated_state == baseline_state);
    assert (generated_load_input == baseline_load_input);
    assert (generated_clear_acc == baseline_clear_acc);
    assert (generated_do_mac_hidden == baseline_do_mac_hidden);
    assert (generated_do_bias_hidden == baseline_do_bias_hidden);
    assert (generated_do_act_hidden == baseline_do_act_hidden);
    assert (generated_advance_hidden == baseline_advance_hidden);
    assert (generated_do_mac_output == baseline_do_mac_output);
    assert (generated_do_bias_output == baseline_do_bias_output);
    assert (generated_done == baseline_done);
    assert (generated_busy == baseline_busy);

    history_valid <= 1'b1;
    prev_sampled_rst_n <= sampled_rst_n;
    prev_sampled_start <= sampled_start;
    prev_sampled_hidden_idx <= sampled_hidden_idx;
    prev_sampled_input_idx <= sampled_input_idx;
    prev_sampled_baseline_state <= sampled_baseline_state;
  end
endmodule
