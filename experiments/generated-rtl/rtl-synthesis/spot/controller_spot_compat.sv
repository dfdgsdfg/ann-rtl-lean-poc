module controller_spot_compat #(
  parameter int INPUT_NEURONS = 4,
  parameter int HIDDEN_NEURONS = 8
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start,
  input  logic [3:0] hidden_idx,
  input  logic [3:0] input_idx,
  output logic [3:0] state,
  output logic       load_input,
  output logic       clear_acc,
  output logic       do_mac_hidden,
  output logic       do_bias_hidden,
  output logic       do_act_hidden,
  output logic       advance_hidden,
  output logic       do_mac_output,
  output logic       do_bias_output,
  output logic       done,
  output logic       busy
);
  localparam logic [3:0] IDLE        = 4'd0;
  localparam logic [3:0] LOAD_INPUT  = 4'd1;
  localparam logic [3:0] MAC_HIDDEN  = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN  = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT  = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE        = 4'd8;
  localparam logic [3:0] INPUT_NEURONS_4B = INPUT_NEURONS[3:0];
  localparam logic [3:0] HIDDEN_NEURONS_4B = HIDDEN_NEURONS[3:0];
  localparam logic [3:0] LAST_HIDDEN_IDX = HIDDEN_NEURONS_4B - 4'd1;

  // Latch any async reset pulse until the synthesized core samples it on clk.
  logic core_reset;
  logic reset_pending;
  logic hidden_mac_active;
  logic hidden_mac_guard;
  logic last_hidden;
  logic output_mac_active;
  logic output_mac_guard;
  logic [2:0] hidden_mac_pos;
  logic [2:0] hidden_neuron_ord;
  logic [3:0] output_mac_pos;

  logic core_phase_idle;
  logic core_phase_load_input;
  logic core_phase_mac_hidden;
  logic core_phase_bias_hidden;
  logic core_phase_act_hidden;
  logic core_phase_next_hidden;
  logic core_phase_mac_output;
  logic core_phase_bias_output;
  logic core_phase_done;

  logic phase_idle;
  logic phase_load_input;
  logic phase_mac_hidden;
  logic phase_bias_hidden;
  logic phase_act_hidden;
  logic phase_next_hidden;
  logic phase_mac_output;
  logic phase_bias_output;
  logic phase_done;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reset_pending <= 1'b1;
    end else begin
      reset_pending <= 1'b0;
    end
  end

  assign core_reset = !rst_n || reset_pending;
  assign hidden_mac_active = (input_idx < INPUT_NEURONS_4B);
  assign hidden_mac_guard = (input_idx == INPUT_NEURONS_4B);
  assign last_hidden = (hidden_idx == LAST_HIDDEN_IDX);
  assign output_mac_active = (input_idx < HIDDEN_NEURONS_4B);
  assign output_mac_guard = (input_idx == HIDDEN_NEURONS_4B);
  assign hidden_mac_pos = hidden_mac_active ? input_idx[2:0] : INPUT_NEURONS_4B[2:0];
  assign hidden_neuron_ord = (hidden_idx < HIDDEN_NEURONS_4B) ? hidden_idx[2:0] : LAST_HIDDEN_IDX[2:0];
  assign output_mac_pos = output_mac_active ? input_idx : HIDDEN_NEURONS_4B;

  controller_spot_core u_controller_spot_core (
    .clk(clk),
    .start(start),
    .reset(core_reset),
    .hidden_mac_active(hidden_mac_active),
    .hidden_mac_guard(hidden_mac_guard),
    .last_hidden(last_hidden),
    .output_mac_active(output_mac_active),
    .output_mac_guard(output_mac_guard),
    .hidden_mac_pos_b0(hidden_mac_pos[0]),
    .hidden_mac_pos_b1(hidden_mac_pos[1]),
    .hidden_mac_pos_b2(hidden_mac_pos[2]),
    .hidden_neuron_ord_b0(hidden_neuron_ord[0]),
    .hidden_neuron_ord_b1(hidden_neuron_ord[1]),
    .hidden_neuron_ord_b2(hidden_neuron_ord[2]),
    .output_mac_pos_b0(output_mac_pos[0]),
    .output_mac_pos_b1(output_mac_pos[1]),
    .output_mac_pos_b2(output_mac_pos[2]),
    .output_mac_pos_b3(output_mac_pos[3]),
    .phase_idle(core_phase_idle),
    .phase_load_input(core_phase_load_input),
    .phase_mac_hidden(core_phase_mac_hidden),
    .phase_bias_hidden(core_phase_bias_hidden),
    .phase_act_hidden(core_phase_act_hidden),
    .phase_next_hidden(core_phase_next_hidden),
    .phase_mac_output(core_phase_mac_output),
    .phase_bias_output(core_phase_bias_output),
    .phase_done(core_phase_done)
  );

  always_comb begin
    if (core_reset) begin
      phase_idle = 1'b1;
      phase_load_input = 1'b0;
      phase_mac_hidden = 1'b0;
      phase_bias_hidden = 1'b0;
      phase_act_hidden = 1'b0;
      phase_next_hidden = 1'b0;
      phase_mac_output = 1'b0;
      phase_bias_output = 1'b0;
      phase_done = 1'b0;
    end else begin
      phase_idle = core_phase_idle;
      phase_load_input = core_phase_load_input;
      phase_mac_hidden = core_phase_mac_hidden;
      phase_bias_hidden = core_phase_bias_hidden;
      phase_act_hidden = core_phase_act_hidden;
      phase_next_hidden = core_phase_next_hidden;
      phase_mac_output = core_phase_mac_output;
      phase_bias_output = core_phase_bias_output;
      phase_done = core_phase_done;
    end
  end

  always_comb begin
    unique case (1'b1)
      phase_idle:        state = IDLE;
      phase_load_input:  state = LOAD_INPUT;
      phase_mac_hidden:  state = MAC_HIDDEN;
      phase_bias_hidden: state = BIAS_HIDDEN;
      phase_act_hidden:  state = ACT_HIDDEN;
      phase_next_hidden: state = NEXT_HIDDEN;
      phase_mac_output:  state = MAC_OUTPUT;
      phase_bias_output: state = BIAS_OUTPUT;
      phase_done:        state = DONE;
      default:           state = IDLE;
    endcase

    load_input = phase_load_input;
    clear_acc = phase_load_input;
    do_mac_hidden = phase_mac_hidden && hidden_mac_active;
    do_bias_hidden = phase_bias_hidden;
    do_act_hidden = phase_act_hidden;
    advance_hidden = phase_next_hidden;
    do_mac_output = phase_mac_output && output_mac_active;
    do_bias_output = phase_bias_output;
    done = phase_done;
    busy = !(phase_idle || phase_done);
  end
endmodule
