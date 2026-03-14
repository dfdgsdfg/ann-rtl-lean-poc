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

  reg [4:0] step;
  logic history_valid;
  logic prev_rst_n;
  logic prev_start;
  logic [3:0] prev_baseline_state;
  logic [3:0] prev_hidden_idx;
  logic [3:0] prev_input_idx;
  logic sampled_rst_n;
  logic sampled_start;
  logic [3:0] sampled_hidden_idx;
  logic [3:0] sampled_input_idx;

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
    step = 5'd0;
    history_valid = 1'b0;
    prev_rst_n = 1'b0;
    prev_start = 1'b0;
    prev_baseline_state = IDLE;
    prev_hidden_idx = 4'd0;
    prev_input_idx = 4'd0;
    sampled_rst_n = 1'b0;
    sampled_start = 1'b0;
    sampled_hidden_idx = 4'd0;
    sampled_input_idx = 4'd0;
  end

  always @* begin
    if (step < 5'd2) begin
      assume (!rst_n);
    end else begin
      assume (rst_n);
    end

    if (!rst_n) begin
      assume (hidden_idx == 4'd0);
      assume (input_idx == 4'd0);
    end else begin
      unique case (baseline_state)
        IDLE: begin
          assume (hidden_idx == 4'd0);
          if (history_valid && prev_rst_n && prev_baseline_state == DONE && !prev_start) begin
            assume (input_idx == HIDDEN_NEURONS_4B);
          end else begin
            assume (input_idx == 4'd0);
          end
        end
        LOAD_INPUT: begin
          assume (hidden_idx == 4'd0);
          assume (input_idx == 4'd0);
        end
        MAC_HIDDEN: begin
          assume (hidden_idx <= LAST_HIDDEN_IDX);
          assume (input_idx <= INPUT_NEURONS_4B);
        end
        BIAS_HIDDEN: begin
          assume (hidden_idx <= LAST_HIDDEN_IDX);
          assume (input_idx == INPUT_NEURONS_4B);
        end
        ACT_HIDDEN: begin
          assume (hidden_idx <= LAST_HIDDEN_IDX);
          assume (input_idx == INPUT_NEURONS_4B);
        end
        NEXT_HIDDEN: begin
          assume (hidden_idx <= LAST_HIDDEN_IDX);
          assume (input_idx == 4'd0);
        end
        MAC_OUTPUT: begin
          assume (hidden_idx == 4'd0);
          assume (input_idx <= HIDDEN_NEURONS_4B);
        end
        BIAS_OUTPUT: begin
          assume (hidden_idx == 4'd0);
          assume (input_idx == HIDDEN_NEURONS_4B);
        end
        DONE: begin
          assume (hidden_idx == 4'd0);
          assume (input_idx == HIDDEN_NEURONS_4B);
        end
        default: begin
          assume (1'b0);
        end
      endcase

      if (history_valid && prev_rst_n) begin
        unique case (prev_baseline_state)
          IDLE: begin
            assume (hidden_idx == 4'd0);
            assume (input_idx == 4'd0);
          end
          LOAD_INPUT: begin
            assume (hidden_idx == 4'd0);
            assume (input_idx == 4'd0);
          end
          MAC_HIDDEN: begin
            assume (hidden_idx == prev_hidden_idx);
            if (prev_input_idx < INPUT_NEURONS_4B) begin
              assume (input_idx == prev_input_idx + 4'd1);
            end else begin
              assume (input_idx == INPUT_NEURONS_4B);
            end
          end
          BIAS_HIDDEN: begin
            assume (hidden_idx == prev_hidden_idx);
            assume (input_idx == INPUT_NEURONS_4B);
          end
          ACT_HIDDEN: begin
            assume (hidden_idx == prev_hidden_idx);
            assume (input_idx == 4'd0);
          end
          NEXT_HIDDEN: begin
            assume (input_idx == 4'd0);
            if (prev_hidden_idx == LAST_HIDDEN_IDX) begin
              assume (hidden_idx == 4'd0);
            end else begin
              assume (hidden_idx == prev_hidden_idx + 4'd1);
            end
          end
          MAC_OUTPUT: begin
            assume (hidden_idx == 4'd0);
            if (prev_input_idx < HIDDEN_NEURONS_4B) begin
              assume (input_idx == prev_input_idx + 4'd1);
            end else begin
              assume (input_idx == HIDDEN_NEURONS_4B);
            end
          end
          BIAS_OUTPUT: begin
            assume (hidden_idx == 4'd0);
            assume (input_idx == HIDDEN_NEURONS_4B);
          end
          DONE: begin
            assume (hidden_idx == 4'd0);
            assume (input_idx == HIDDEN_NEURONS_4B);
          end
          default: begin
            assume (1'b0);
          end
        endcase
      end
    end
  end

  always @(posedge clk) begin
    if (step < 5'd12) begin
      step <= step + 5'd1;
    end

    history_valid <= 1'b1;
    prev_rst_n <= rst_n;
    prev_start <= start;
    prev_baseline_state <= baseline_state;
    prev_hidden_idx <= hidden_idx;
    prev_input_idx <= input_idx;
    sampled_rst_n <= rst_n;
    sampled_start <= start;
    sampled_hidden_idx <= hidden_idx;
    sampled_input_idx <= input_idx;
  end

  always @(negedge clk) begin
    if (history_valid) begin
      assume (rst_n == sampled_rst_n);
      assume (start == sampled_start);
      assume (hidden_idx == sampled_hidden_idx);
      assume (input_idx == sampled_input_idx);

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
    end
  end
endmodule
