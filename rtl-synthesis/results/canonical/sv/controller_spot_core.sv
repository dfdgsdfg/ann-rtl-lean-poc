module controller_spot_core (
  clk,
  start,
  reset,
  hidden_mac_active,
  hidden_mac_guard,
  last_hidden,
  output_mac_active,
  output_mac_guard,
  hidden_mac_pos_b0,
  hidden_mac_pos_b1,
  hidden_mac_pos_b2,
  hidden_neuron_ord_b0,
  hidden_neuron_ord_b1,
  hidden_neuron_ord_b2,
  output_mac_pos_b0,
  output_mac_pos_b1,
  output_mac_pos_b2,
  output_mac_pos_b3,
  phase_idle,
  phase_load_input,
  phase_mac_hidden,
  phase_bias_hidden,
  phase_act_hidden,
  phase_next_hidden,
  phase_mac_output,
  phase_bias_output,
  phase_done
);
  input  clk;
  input  start;
  input  reset;
  input  hidden_mac_active;
  input  hidden_mac_guard;
  input  last_hidden;
  input  output_mac_active;
  input  output_mac_guard;
  input  hidden_mac_pos_b0;
  input  hidden_mac_pos_b1;
  input  hidden_mac_pos_b2;
  input  hidden_neuron_ord_b0;
  input  hidden_neuron_ord_b1;
  input  hidden_neuron_ord_b2;
  input  output_mac_pos_b0;
  input  output_mac_pos_b1;
  input  output_mac_pos_b2;
  input  output_mac_pos_b3;
  output phase_idle;
  output phase_load_input;
  output phase_mac_hidden;
  output phase_bias_hidden;
  output phase_act_hidden;
  output phase_next_hidden;
  output phase_mac_output;
  output phase_bias_output;
  output phase_done;

  localparam [3:0] IDLE        = 4'd0;
  localparam [3:0] LOAD_INPUT  = 4'd1;
  localparam [3:0] MAC_HIDDEN  = 4'd2;
  localparam [3:0] BIAS_HIDDEN = 4'd3;
  localparam [3:0] ACT_HIDDEN  = 4'd4;
  localparam [3:0] NEXT_HIDDEN = 4'd5;
  localparam [3:0] MAC_OUTPUT  = 4'd6;
  localparam [3:0] BIAS_OUTPUT = 4'd7;
  localparam [3:0] DONE        = 4'd8;

  reg [3:0] state;
  reg [3:0] next_state;

  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_INPUT;
        end else begin
          next_state = IDLE;
        end
      end
      LOAD_INPUT: begin
        next_state = MAC_HIDDEN;
      end
      MAC_HIDDEN: begin
        if (hidden_mac_guard) begin
          next_state = BIAS_HIDDEN;
        end else begin
          next_state = MAC_HIDDEN;
        end
      end
      BIAS_HIDDEN: begin
        next_state = ACT_HIDDEN;
      end
      ACT_HIDDEN: begin
        next_state = NEXT_HIDDEN;
      end
      NEXT_HIDDEN: begin
        if (last_hidden) begin
          next_state = MAC_OUTPUT;
        end else begin
          next_state = MAC_HIDDEN;
        end
      end
      MAC_OUTPUT: begin
        if (output_mac_guard) begin
          next_state = BIAS_OUTPUT;
        end else begin
          next_state = MAC_OUTPUT;
        end
      end
      BIAS_OUTPUT: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) begin
          next_state = DONE;
        end else begin
          next_state = IDLE;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase

    if (reset) begin
      next_state = IDLE;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  assign phase_idle = (state == IDLE);
  assign phase_load_input = (state == LOAD_INPUT);
  assign phase_mac_hidden = (state == MAC_HIDDEN);
  assign phase_bias_hidden = (state == BIAS_HIDDEN);
  assign phase_act_hidden = (state == ACT_HIDDEN);
  assign phase_next_hidden = (state == NEXT_HIDDEN);
  assign phase_mac_output = (state == MAC_OUTPUT);
  assign phase_bias_output = (state == BIAS_OUTPUT);
  assign phase_done = (state == DONE);
endmodule
