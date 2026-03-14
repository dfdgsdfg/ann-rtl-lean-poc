module weight_rom (
  input  logic [3:0] hidden_idx,
  input  logic [3:0] input_idx,
  output logic signed [7:0]  w1_data,
  output logic signed [31:0] b1_data,
  output logic signed [7:0]  w2_data,
  output logic signed [31:0] b2_data
`ifdef FORMAL
  ,
  output logic               formal_hidden_weight_case_hit,
  output logic               formal_output_weight_case_hit
`endif
);
  // BEGIN AUTO-GENERATED ROM
  always_comb begin
`ifdef FORMAL
    formal_hidden_weight_case_hit = 1'b0;
`endif
    unique case ({hidden_idx, input_idx})
      8'h00: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h01: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h02: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h03: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h10: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h11: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h12: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h13: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h20: begin w1_data = 8'sd2; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h21: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h22: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h23: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h30: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h31: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h32: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h33: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h40: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h41: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h42: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h43: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h50: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h51: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h52: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h53: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h60: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h61: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h62: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h63: begin w1_data = -8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h70: begin w1_data = 8'sd1; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h71: begin w1_data = 8'sd2; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h72: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
      8'h73: begin w1_data = 8'sd0; `ifdef FORMAL formal_hidden_weight_case_hit = 1'b1; `endif end
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
`ifdef FORMAL
    formal_output_weight_case_hit = 1'b0;
`endif
    unique case (input_idx)
      4'd0: begin w2_data = 8'sd0; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd1: begin w2_data = 8'sd0; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd2: begin w2_data = 8'sd1; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd3: begin w2_data = 8'sd0; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd4: begin w2_data = -8'sd1; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd5: begin w2_data = -8'sd1; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd6: begin w2_data = 8'sd1; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      4'd7: begin w2_data = -8'sd1; `ifdef FORMAL formal_output_weight_case_hit = 1'b1; `endif end
      default: w2_data = 8'sd0;
    endcase
  end

  assign b2_data = -32'sd1;
  // END AUTO-GENERATED ROM
endmodule
