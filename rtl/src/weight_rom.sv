module weight_rom (
  input  logic [3:0] hidden_idx,
  input  logic [3:0] input_idx,
  output logic signed [7:0]  w1_data,
  output logic signed [31:0] b1_data,
  output logic signed [7:0]  w2_data,
  output logic signed [31:0] b2_data
);
  // BEGIN AUTO-GENERATED ROM
  always_comb begin
    unique case ({hidden_idx, input_idx})
      8'h00: w1_data = 8'sd0;
      8'h01: w1_data = 8'sd0;
      8'h02: w1_data = 8'sd0;
      8'h03: w1_data = 8'sd0;
      8'h10: w1_data = 8'sd0;
      8'h11: w1_data = 8'sd0;
      8'h12: w1_data = 8'sd0;
      8'h13: w1_data = -8'sd1;
      8'h20: w1_data = 8'sd2;
      8'h21: w1_data = 8'sd1;
      8'h22: w1_data = 8'sd1;
      8'h23: w1_data = -8'sd1;
      8'h30: w1_data = 8'sd0;
      8'h31: w1_data = 8'sd0;
      8'h32: w1_data = 8'sd0;
      8'h33: w1_data = -8'sd1;
      8'h40: w1_data = -8'sd1;
      8'h41: w1_data = 8'sd0;
      8'h42: w1_data = 8'sd0;
      8'h43: w1_data = 8'sd0;
      8'h50: w1_data = -8'sd1;
      8'h51: w1_data = 8'sd1;
      8'h52: w1_data = -8'sd1;
      8'h53: w1_data = 8'sd1;
      8'h60: w1_data = 8'sd0;
      8'h61: w1_data = -8'sd1;
      8'h62: w1_data = 8'sd1;
      8'h63: w1_data = -8'sd1;
      8'h70: w1_data = 8'sd1;
      8'h71: w1_data = 8'sd2;
      8'h72: w1_data = 8'sd0;
      8'h73: w1_data = 8'sd0;
      default: w1_data = 8'sd0;
    endcase
  end

  always_comb begin
    unique case (hidden_idx)
      4'd0: b1_data = 32'sd0;
      4'd1: b1_data = 32'sd0;
      4'd2: b1_data = 32'sd1;
      4'd3: b1_data = 32'sd1;
      4'd4: b1_data = 32'sd0;
      4'd5: b1_data = 32'sd2;
      4'd6: b1_data = 32'sd1;
      4'd7: b1_data = -32'sd1;
      default: b1_data = 32'sd0;
    endcase
  end

  always_comb begin
    unique case (input_idx)
      4'd0: w2_data = 8'sd0;
      4'd1: w2_data = 8'sd0;
      4'd2: w2_data = 8'sd1;
      4'd3: w2_data = 8'sd0;
      4'd4: w2_data = -8'sd1;
      4'd5: w2_data = -8'sd1;
      4'd6: w2_data = 8'sd1;
      4'd7: w2_data = -8'sd1;
      default: w2_data = 8'sd0;
    endcase
  end

  assign b2_data = -32'sd1;
  // END AUTO-GENERATED ROM
endmodule
