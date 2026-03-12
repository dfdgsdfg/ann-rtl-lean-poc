module mlp_core (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic signed [7:0] in0,
  input  logic signed [7:0] in1,
  input  logic signed [7:0] in2,
  input  logic signed [7:0] in3,
  output logic              done,
  output logic              busy,
  output logic              out_bit
);
  localparam logic [3:0] IDLE       = 4'd0;
  localparam logic [3:0] MAC_OUTPUT = 4'd6;

  logic [3:0] state;
  logic       load_input;
  logic       clear_acc;
  logic       do_mac_hidden;
  logic       do_bias_hidden;
  logic       do_act_hidden;
  logic       advance_hidden;
  logic       do_mac_output;
  logic       do_bias_output;

  logic signed [7:0] input_regs [0:3];
  logic signed [15:0] hidden_regs [0:7];
  logic signed [31:0] acc_reg;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;

  logic signed [7:0]  w1_data;
  logic signed [31:0] b1_data;
  logic signed [7:0]  w2_data;
  logic signed [31:0] b2_data;

  logic signed [15:0] mac_a;
  logic signed [7:0]  mac_b;
  logic signed [31:0] mac_acc_out;
  logic signed [15:0] relu_hidden;

  integer i;

  controller u_controller (
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

  weight_rom u_weight_rom (
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .w1_data(w1_data),
    .b1_data(b1_data),
    .w2_data(w2_data),
    .b2_data(b2_data)
  );

  mac_unit #(
    .A_WIDTH(16),
    .B_WIDTH(8),
    .ACC_WIDTH(32)
  ) u_mac (
    .a(mac_a),
    .b(mac_b),
    .acc_in(acc_reg),
    .acc_out(mac_acc_out)
  );

  relu_unit #(
    .IN_WIDTH(32),
    .OUT_WIDTH(16)
  ) u_relu (
    .in_value(acc_reg),
    .out_value(relu_hidden)
  );

  always_comb begin
    if (state == MAC_OUTPUT) begin
      mac_a = hidden_regs[input_idx[2:0]];
      mac_b = w2_data;
    end else begin
      unique case (input_idx)
        4'd0: mac_a = {{8{input_regs[0][7]}}, input_regs[0]};
        4'd1: mac_a = {{8{input_regs[1][7]}}, input_regs[1]};
        4'd2: mac_a = {{8{input_regs[2][7]}}, input_regs[2]};
        4'd3: mac_a = {{8{input_regs[3][7]}}, input_regs[3]};
        default: mac_a = 16'sd0;
      endcase
      mac_b = w1_data;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_reg <= 32'sd0;
      hidden_idx <= 4'd0;
      input_idx <= 4'd0;
      out_bit <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        input_regs[i] <= 8'sd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        hidden_regs[i] <= 16'sd0;
      end
    end else begin
      if (load_input) begin
        input_regs[0] <= in0;
        input_regs[1] <= in1;
        input_regs[2] <= in2;
        input_regs[3] <= in3;
        acc_reg <= 32'sd0;
        hidden_idx <= 4'd0;
        input_idx <= 4'd0;
        out_bit <= 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
          hidden_regs[i] <= 16'sd0;
        end
      end else begin
        if (clear_acc) begin
          acc_reg <= 32'sd0;
        end

        if (do_mac_hidden || do_mac_output) begin
          acc_reg <= mac_acc_out;
          input_idx <= input_idx + 4'd1;
        end

        if (do_bias_hidden) begin
          acc_reg <= acc_reg + b1_data;
        end

        if (do_act_hidden) begin
          hidden_regs[hidden_idx[2:0]] <= relu_hidden;
          acc_reg <= 32'sd0;
          input_idx <= 4'd0;
        end

        if (advance_hidden) begin
          if (hidden_idx == 4'd7) begin
            hidden_idx <= 4'd0;
            input_idx <= 4'd0;
          end else begin
            hidden_idx <= hidden_idx + 4'd1;
          end
        end

        if (do_bias_output) begin
          acc_reg <= acc_reg + b2_data;
          out_bit <= ($signed(acc_reg + b2_data) > 0);
          input_idx <= 4'd8;
          hidden_idx <= 4'd0;
        end

        if (state == IDLE && !start) begin
          input_idx <= 4'd0;
          hidden_idx <= 4'd0;
        end
      end
    end
  end
endmodule
