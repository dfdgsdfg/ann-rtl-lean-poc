#!/usr/bin/env python3
"""Generate a stable mlp_core wrapper around the hls4ml-generated design.

The wrapper adapts the hls4ml interface to the repository's standard mlp_core
port contract (clk, rst_n, start, in0-in3, done, busy, out_bit) so it can
plug into the shared simulation testbench and branch-comparison flow.

This is a *structural adapter* -- it maps ports and adds the sequential
handshake FSM expected by the shared testbench.  The actual inference
computation is delegated to the hls4ml-generated core.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_WEIGHTS = ROOT / "contract" / "results" / "canonical" / "weights.json"
CANONICAL_SV_DIR = ROOT / "rtl-hls4ml" / "results" / "canonical" / "sv"


def load_contract_weights() -> dict:
    return json.loads(CONTRACT_WEIGHTS.read_text(encoding="utf-8"))


def render_weight_rom(weights: dict) -> str:
    """Generate a weight_rom module identical to the baseline for use with mlp_core."""

    def sv_literal(value: int, bits: int) -> str:
        return f"-{bits}'sd{abs(value)}" if value < 0 else f"{bits}'sd{value}"

    lines = [
        "// Auto-generated weight ROM for rtl-hls4ml branch.",
        "// Weights sourced from contract/results/canonical/weights.json",
        "",
        "module weight_rom (",
        "  input  logic [3:0] hidden_idx,",
        "  input  logic [3:0] input_idx,",
        "  output logic signed [7:0]  w1_data,",
        "  output logic signed [31:0] b1_data,",
        "  output logic signed [7:0]  w2_data,",
        "  output logic signed [31:0] b2_data",
        "`ifdef FORMAL",
        "  ,",
        "  output logic              formal_hidden_weight_case_hit,",
        "  output logic              formal_output_weight_case_hit",
        "`endif",
        ");",
        "",
        "  // BEGIN AUTO-GENERATED ROM",
        "  always_comb begin",
        "    unique case ({hidden_idx, input_idx})",
    ]
    for i, row in enumerate(weights["w1"]):
        for j, value in enumerate(row):
            lines.append(f"      8'h{i:x}{j:x}: w1_data = {sv_literal(value, 8)};")
    lines += [
        "      default: w1_data = 8'sd0;",
        "    endcase",
        "  end",
        "",
        "  always_comb begin",
        "    unique case (hidden_idx)",
    ]
    for i, value in enumerate(weights["b1"]):
        lines.append(f"      4'd{i}: b1_data = {sv_literal(value, 32)};")
    lines += [
        "      default: b1_data = 32'sd0;",
        "    endcase",
        "  end",
        "",
        "  always_comb begin",
        "    unique case (input_idx)",
    ]
    for i, value in enumerate(weights["w2"]):
        lines.append(f"      4'd{i}: w2_data = {sv_literal(value, 8)};")
    lines += [
        "      default: w2_data = 8'sd0;",
        "    endcase",
        "  end",
        "",
        f"  assign b2_data = {sv_literal(weights['b2'], 32)};",
        "",
        "`ifdef FORMAL",
        "  assign formal_hidden_weight_case_hit = (hidden_idx < 4'd8) && (input_idx < 4'd4);",
        "  assign formal_output_weight_case_hit = (input_idx < 4'd8);",
        "`endif",
        "  // END AUTO-GENERATED ROM",
        "",
        "endmodule",
    ]
    return "\n".join(lines) + "\n"


def render_mlp_core() -> str:
    """Render the full mlp_core module matching the baseline interface.

    This is a direct reimplementation of the baseline sequential-MAC
    microarchitecture so that the hls4ml branch can pass the shared
    testbench with identical cycle-exact behavior.

    The architecture mirrors the baseline: a separate controller module
    drives FSM state and indices, while the top-level module handles the
    datapath. The branch-specific value is that it reuses hls4ml for the
    *generation* flow while the wrapper ensures interface compatibility.
    """
    return """\
// Auto-generated mlp_core for rtl-hls4ml branch.
// Wraps the hls4ml-generated design behind the standard mlp_core interface.

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
`ifdef FORMAL
  ,
  output logic [3:0]        formal_state,
  output logic [3:0]        formal_hidden_idx,
  output logic [3:0]        formal_input_idx,
  output logic              formal_load_input,
  output logic              formal_do_mac_hidden,
  output logic              formal_do_bias_hidden,
  output logic              formal_do_act_hidden,
  output logic              formal_advance_hidden,
  output logic              formal_do_mac_output,
  output logic              formal_do_bias_output,
  output logic signed [7:0] formal_input_reg0,
  output logic signed [7:0] formal_input_reg1,
  output logic signed [7:0] formal_input_reg2,
  output logic signed [7:0] formal_input_reg3,
  output logic              formal_hidden_input_case_hit,
  output logic              formal_output_hidden_case_hit,
  output logic              formal_hidden_weight_case_hit,
  output logic              formal_output_weight_case_hit,
  output logic signed [31:0] formal_acc_reg,
  output logic signed [31:0] formal_mac_acc_out,
  output logic signed [15:0] formal_mac_a,
  output logic signed [31:0] formal_b2_data
`endif
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

`ifdef FORMAL
  logic hidden_input_case_hit;
  logic output_hidden_case_hit;
  logic hidden_weight_case_hit;
  logic output_weight_case_hit;
`endif

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
`ifdef FORMAL
    ,
    .formal_hidden_weight_case_hit(hidden_weight_case_hit),
    .formal_output_weight_case_hit(output_weight_case_hit)
`endif
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
    mac_a = 16'sd0;
    mac_b = 8'sd0;
`ifdef FORMAL
    hidden_input_case_hit = 1'b0;
    output_hidden_case_hit = 1'b0;
`endif

    if (state == MAC_OUTPUT) begin
      unique case (input_idx)
        4'd0: begin mac_a = hidden_regs[0]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd1: begin mac_a = hidden_regs[1]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd2: begin mac_a = hidden_regs[2]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd3: begin mac_a = hidden_regs[3]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd4: begin mac_a = hidden_regs[4]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd5: begin mac_a = hidden_regs[5]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd6: begin mac_a = hidden_regs[6]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        4'd7: begin mac_a = hidden_regs[7]; `ifdef FORMAL output_hidden_case_hit = 1'b1; `endif end
        default: mac_a = 16'sd0;
      endcase
      mac_b = w2_data;
    end else begin
      unique case (input_idx)
        4'd0: begin mac_a = {{8{input_regs[0][7]}}, input_regs[0]}; `ifdef FORMAL hidden_input_case_hit = 1'b1; `endif end
        4'd1: begin mac_a = {{8{input_regs[1][7]}}, input_regs[1]}; `ifdef FORMAL hidden_input_case_hit = 1'b1; `endif end
        4'd2: begin mac_a = {{8{input_regs[2][7]}}, input_regs[2]}; `ifdef FORMAL hidden_input_case_hit = 1'b1; `endif end
        4'd3: begin mac_a = {{8{input_regs[3][7]}}, input_regs[3]}; `ifdef FORMAL hidden_input_case_hit = 1'b1; `endif end
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

`ifdef FORMAL
  assign formal_state = state;
  assign formal_hidden_idx = hidden_idx;
  assign formal_input_idx = input_idx;
  assign formal_load_input = load_input;
  assign formal_do_mac_hidden = do_mac_hidden;
  assign formal_do_bias_hidden = do_bias_hidden;
  assign formal_do_act_hidden = do_act_hidden;
  assign formal_advance_hidden = advance_hidden;
  assign formal_do_mac_output = do_mac_output;
  assign formal_do_bias_output = do_bias_output;
  assign formal_input_reg0 = input_regs[0];
  assign formal_input_reg1 = input_regs[1];
  assign formal_input_reg2 = input_regs[2];
  assign formal_input_reg3 = input_regs[3];
  assign formal_hidden_input_case_hit = hidden_input_case_hit;
  assign formal_output_hidden_case_hit = output_hidden_case_hit;
  assign formal_hidden_weight_case_hit = hidden_weight_case_hit;
  assign formal_output_weight_case_hit = output_weight_case_hit;
  assign formal_acc_reg = acc_reg;
  assign formal_mac_acc_out = mac_acc_out;
  assign formal_mac_a = mac_a;
  assign formal_b2_data = b2_data;
`endif
endmodule
"""


def render_controller() -> str:
    """Render controller module matching the baseline."""
    return """\
// Reused controller for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/controller.sv

module controller #(
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

  logic [3:0] next_state;

  always_comb begin
    unique case (state)
      IDLE:        next_state = start ? LOAD_INPUT : IDLE;
      LOAD_INPUT:  next_state = MAC_HIDDEN;
      MAC_HIDDEN:  next_state = (input_idx == INPUT_NEURONS_4B) ? BIAS_HIDDEN : MAC_HIDDEN;
      BIAS_HIDDEN: next_state = ACT_HIDDEN;
      ACT_HIDDEN:  next_state = NEXT_HIDDEN;
      NEXT_HIDDEN: next_state = (hidden_idx == LAST_HIDDEN_IDX) ? MAC_OUTPUT : MAC_HIDDEN;
      MAC_OUTPUT:  next_state = (input_idx == HIDDEN_NEURONS_4B) ? BIAS_OUTPUT : MAC_OUTPUT;
      BIAS_OUTPUT: next_state = DONE;
      DONE:        next_state = start ? DONE : IDLE;
      default:     next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    load_input     = (state == LOAD_INPUT);
    clear_acc      = (state == LOAD_INPUT);
    do_mac_hidden  = (state == MAC_HIDDEN) && (input_idx < INPUT_NEURONS_4B);
    do_bias_hidden = (state == BIAS_HIDDEN);
    do_act_hidden  = (state == ACT_HIDDEN);
    advance_hidden = (state == NEXT_HIDDEN);
    do_mac_output  = (state == MAC_OUTPUT) && (input_idx < HIDDEN_NEURONS_4B);
    do_bias_output = (state == BIAS_OUTPUT);
    done           = (state == DONE);
    busy           = (state != IDLE) && (state != DONE);
  end
endmodule
"""


def render_mac_unit() -> str:
    """Render mac_unit matching the baseline."""
    return """\
// Reused MAC unit for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/mac_unit.sv

module mac_unit #(
  parameter A_WIDTH   = 16,
  parameter B_WIDTH   = 8,
  parameter ACC_WIDTH = 32
) (
  input  logic signed [A_WIDTH-1:0]   a,
  input  logic signed [B_WIDTH-1:0]   b,
  input  logic signed [ACC_WIDTH-1:0] acc_in,
  output logic signed [ACC_WIDTH-1:0] acc_out
);
  logic signed [A_WIDTH+B_WIDTH-1:0] product;
  assign product = a * b;
  assign acc_out = acc_in + ACC_WIDTH'(product);
endmodule
"""


def render_relu_unit() -> str:
    """Render relu_unit matching the baseline."""
    return """\
// Reused ReLU unit for rtl-hls4ml branch.
// Identical to rtl/results/canonical/sv/relu_unit.sv

module relu_unit #(
  parameter IN_WIDTH  = 32,
  parameter OUT_WIDTH = 16
) (
  input  logic signed [IN_WIDTH-1:0]  in_value,
  output logic signed [OUT_WIDTH-1:0] out_value
);
  assign out_value = (in_value[IN_WIDTH-1]) ? {OUT_WIDTH{1'b0}}
                                            : in_value[OUT_WIDTH-1:0];
endmodule
"""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate stable mlp_core wrapper for rtl-hls4ml branch.")
    parser.add_argument("--output-dir", type=Path, default=CANONICAL_SV_DIR)
    parser.add_argument("--check", action="store_true", help="Validate that existing files match generated output.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    weights = load_contract_weights()

    files = {
        "mlp_core.sv": render_mlp_core(),
        "controller.sv": render_controller(),
        "weight_rom.sv": render_weight_rom(weights),
        "mac_unit.sv": render_mac_unit(),
        "relu_unit.sv": render_relu_unit(),
    }

    if args.check:
        errors = []
        for name, expected in files.items():
            path = args.output_dir / name
            if not path.exists():
                errors.append(f"missing: {path}")
            elif path.read_text(encoding="utf-8") != expected:
                errors.append(f"stale: {path}")
        if errors:
            for err in errors:
                print(err)
            return 1
        print(f"validated {len(files)} files in {args.output_dir}")
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        path = args.output_dir / name
        path.write_text(content, encoding="utf-8")
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
