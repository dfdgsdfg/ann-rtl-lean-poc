#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PackedField:
    target: str
    width: int


@dataclass(frozen=True)
class RawPort:
    direction: str
    name: str
    width: int


PACKED_FIELDS = [
    PackedField("state", 4),
    PackedField("load_input", 1),
    PackedField("clear_acc", 1),
    PackedField("do_mac_hidden", 1),
    PackedField("do_bias_hidden", 1),
    PackedField("do_act_hidden", 1),
    PackedField("advance_hidden", 1),
    PackedField("do_mac_output", 1),
    PackedField("do_bias_output", 1),
    PackedField("done", 1),
    PackedField("busy", 1),
    PackedField("out_bit", 1),
    PackedField("hidden_idx", 4),
    PackedField("input_idx", 4),
    PackedField("acc_reg", 32),
    PackedField("mac_acc_out", 32),
    PackedField("mac_a", 16),
    PackedField("b2_data", 32),
    PackedField("input_regs[0]", 8),
    PackedField("input_regs[1]", 8),
    PackedField("input_regs[2]", 8),
    PackedField("input_regs[3]", 8),
    PackedField("hidden_regs[0]", 16),
    PackedField("hidden_regs[1]", 16),
    PackedField("hidden_regs[2]", 16),
    PackedField("hidden_regs[3]", 16),
    PackedField("hidden_regs[4]", 16),
    PackedField("hidden_regs[5]", 16),
    PackedField("hidden_regs[6]", 16),
    PackedField("hidden_regs[7]", 16),
    PackedField("hidden_input_case_hit", 1),
    PackedField("output_hidden_case_hit", 1),
    PackedField("hidden_weight_case_hit", 1),
    PackedField("output_weight_case_hit", 1),
]

FORMAL_ALIASES = [
    ("formal_state", "state"),
    ("formal_hidden_idx", "hidden_idx"),
    ("formal_input_idx", "input_idx"),
    ("formal_load_input", "load_input"),
    ("formal_do_mac_hidden", "do_mac_hidden"),
    ("formal_do_bias_hidden", "do_bias_hidden"),
    ("formal_do_act_hidden", "do_act_hidden"),
    ("formal_advance_hidden", "advance_hidden"),
    ("formal_do_mac_output", "do_mac_output"),
    ("formal_do_bias_output", "do_bias_output"),
    ("formal_input_reg0", "input_regs[0]"),
    ("formal_input_reg1", "input_regs[1]"),
    ("formal_input_reg2", "input_regs[2]"),
    ("formal_input_reg3", "input_regs[3]"),
    ("formal_hidden_input_case_hit", "hidden_input_case_hit"),
    ("formal_output_hidden_case_hit", "output_hidden_case_hit"),
    ("formal_hidden_weight_case_hit", "hidden_weight_case_hit"),
    ("formal_output_weight_case_hit", "output_weight_case_hit"),
    ("formal_acc_reg", "acc_reg"),
    ("formal_mac_acc_out", "mac_acc_out"),
    ("formal_mac_a", "mac_a"),
    ("formal_b2_data", "b2_data"),
]

EXPECTED_RAW_PORTS = [
    RawPort("input", "_gen_start", 1),
    RawPort("input", "_gen_in0", 8),
    RawPort("input", "_gen_in1", 8),
    RawPort("input", "_gen_in2", 8),
    RawPort("input", "_gen_in3", 8),
    RawPort("input", "clk", 1),
    RawPort("input", "rst", 1),
    RawPort("output", "out", sum(field.width for field in PACKED_FIELDS)),
]

MODULE_RE = re.compile(r"module\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((?P<ports>.*?)\)\s*;", re.DOTALL)
PORT_RE = re.compile(
    r"\b(input|output)\s+logic(?:\s+signed)?(?:\s*\[(\d+):0\])?\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the stable Sparkle mlp_core wrapper.")
    parser.add_argument("--raw", type=Path, required=True, help="Path to the raw Sparkle-emitted RTL module.")
    parser.add_argument("--wrapper", type=Path, required=True, help="Path to the generated stable wrapper.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate the raw module interface and verify that the wrapper matches the generated output.",
    )
    return parser.parse_args()


def render_slice(hi: int, lo: int) -> str:
    if hi == lo:
        return f"[{hi}]"
    return f"[{hi}:{lo}]"


def logic_decl(name: str) -> str:
    if name in {"state", "hidden_idx", "input_idx"}:
        return f"  logic [3:0] {name};"
    if name.startswith("input_regs["):
        return ""
    if name.startswith("hidden_regs["):
        return ""
    if name in {"acc_reg", "mac_acc_out", "b2_data"}:
        return f"  logic signed [31:0] {name};"
    if name == "mac_a":
        return "  logic signed [15:0] mac_a;"
    if name in {"done", "busy", "out_bit"}:
        return ""
    if name.endswith("_case_hit") or name.startswith("do_") or name in {"load_input", "clear_acc", "advance_hidden"}:
        return f"  logic {name};"
    raise ValueError(f"unknown internal signal declaration for {name}")


def render_assignments() -> str:
    total_width = sum(field.width for field in PACKED_FIELDS)
    next_hi = total_width - 1
    lines: list[str] = []
    for field in PACKED_FIELDS:
        lo = next_hi - field.width + 1
        lines.append(f"  assign {field.target:<23} = packed_out{render_slice(next_hi, lo)};")
        next_hi = lo - 1
    return "\n".join(lines)


def render_wrapper(raw_module_name: str, packed_width: int) -> str:
    expected_width = sum(field.width for field in PACKED_FIELDS)
    if packed_width != expected_width:
        raise ValueError(
            f"raw module packed width mismatch: expected {expected_width}, found {packed_width}"
        )

    decl_lines = [logic_decl(field.target) for field in PACKED_FIELDS if not field.target.startswith(("input_regs[", "hidden_regs["))]
    decl_lines = [line for line in decl_lines if line]

    formal_lines = [f"  assign {formal:<31} = {target};" for formal, target in FORMAL_ALIASES]

    return (
        "// Auto-generated by rtl-formalize-synthesis/scripts/generate_wrapper.py\n"
        "// Stable mlp_core wrapper around the raw Sparkle packed module.\n"
        "\n"
        "module mlp_core (\n"
        "  input  logic              clk,\n"
        "  input  logic              rst_n,\n"
        "  input  logic              start,\n"
        "  input  logic signed [7:0] in0,\n"
        "  input  logic signed [7:0] in1,\n"
        "  input  logic signed [7:0] in2,\n"
        "  input  logic signed [7:0] in3,\n"
        "  output logic              done,\n"
        "  output logic              busy,\n"
        "  output logic              out_bit\n"
        "`ifdef FORMAL\n"
        "  ,\n"
        "  output logic [3:0]        formal_state,\n"
        "  output logic [3:0]        formal_hidden_idx,\n"
        "  output logic [3:0]        formal_input_idx,\n"
        "  output logic              formal_load_input,\n"
        "  output logic              formal_do_mac_hidden,\n"
        "  output logic              formal_do_bias_hidden,\n"
        "  output logic              formal_do_act_hidden,\n"
        "  output logic              formal_advance_hidden,\n"
        "  output logic              formal_do_mac_output,\n"
        "  output logic              formal_do_bias_output,\n"
        "  output logic signed [7:0] formal_input_reg0,\n"
        "  output logic signed [7:0] formal_input_reg1,\n"
        "  output logic signed [7:0] formal_input_reg2,\n"
        "  output logic signed [7:0] formal_input_reg3,\n"
        "  output logic              formal_hidden_input_case_hit,\n"
        "  output logic              formal_output_hidden_case_hit,\n"
        "  output logic              formal_hidden_weight_case_hit,\n"
        "  output logic              formal_output_weight_case_hit,\n"
        "  output logic signed [31:0] formal_acc_reg,\n"
        "  output logic signed [31:0] formal_mac_acc_out,\n"
        "  output logic signed [15:0] formal_mac_a,\n"
        "  output logic signed [31:0] formal_b2_data\n"
        "`endif\n"
        ");\n"
        "  logic rst;\n"
        f"  logic [{packed_width - 1}:0] packed_out;\n"
        "\n"
        + "\n".join(decl_lines)
        + "\n"
        "  logic signed [7:0] input_regs [0:3];\n"
        "  logic signed [15:0] hidden_regs [0:7];\n"
        "\n"
        "  assign rst = ~rst_n;\n"
        "\n"
        f"  {raw_module_name} u_sparkle_mlp_core (\n"
        "    ._gen_start(start),\n"
        "    ._gen_in0(in0),\n"
        "    ._gen_in1(in1),\n"
        "    ._gen_in2(in2),\n"
        "    ._gen_in3(in3),\n"
        "    .clk(clk),\n"
        "    .rst(rst),\n"
        "    .out(packed_out)\n"
        "  );\n"
        "\n"
        "  // Packed as:\n"
        "  // {state, load_input, clear_acc, do_mac_hidden, do_bias_hidden, do_act_hidden,\n"
        "  //  advance_hidden, do_mac_output, do_bias_output, done, busy, out_bit,\n"
        "  //  hidden_idx, input_idx, acc_reg, mac_acc_out, mac_a, b2_data,\n"
        "  //  input_reg0, input_reg1, input_reg2, input_reg3,\n"
        "  //  hidden_reg0..hidden_reg7,\n"
        "  //  hidden_input_case_hit, output_hidden_case_hit,\n"
        "  //  hidden_weight_case_hit, output_weight_case_hit}\n"
        + render_assignments()
        + "\n\n"
        "`ifdef FORMAL\n"
        + "\n".join(formal_lines)
        + "\n`endif\n"
        "endmodule\n"
    )


def parse_raw_module(raw_text: str, raw_path: Path) -> tuple[str, list[RawPort]]:
    module_match = MODULE_RE.search(raw_text)
    if module_match is None:
        raise SystemExit(f"could not find raw module declaration in {raw_path}")
    raw_module_name = module_match.group(1)
    port_block = module_match.group("ports")
    raw_ports = [
        RawPort(
            direction=match.group(1),
            width=int(match.group(2)) + 1 if match.group(2) is not None else 1,
            name=match.group(3),
        )
        for match in PORT_RE.finditer(port_block)
    ]
    if not raw_ports:
        raise SystemExit(f"could not parse raw module ports in {raw_path}")
    return raw_module_name, raw_ports


def validate_raw_ports(raw_ports: list[RawPort], raw_path: Path) -> int:
    expected_by_name = {port.name: port for port in EXPECTED_RAW_PORTS}
    actual_by_name = {port.name: port for port in raw_ports}

    problems: list[str] = []
    missing = sorted(name for name in expected_by_name if name not in actual_by_name)
    unexpected = sorted(name for name in actual_by_name if name not in expected_by_name)
    if missing:
        problems.append(f"missing ports: {', '.join(missing)}")
    if unexpected:
        problems.append(f"unexpected ports: {', '.join(unexpected)}")

    for name, expected in expected_by_name.items():
        actual = actual_by_name.get(name)
        if actual is None:
            continue
        if actual.direction != expected.direction or actual.width != expected.width:
            problems.append(
                f"port {name} mismatch: expected {expected.direction} width {expected.width}, "
                f"found {actual.direction} width {actual.width}"
            )

    if problems:
        detail = "\n".join(f"- {problem}" for problem in problems)
        raise SystemExit(f"raw module interface validation failed for {raw_path}:\n{detail}")
    return expected_by_name["out"].width


def check_wrapper(wrapper_path: Path, expected_text: str) -> None:
    if not wrapper_path.exists():
        raise SystemExit(f"wrapper file does not exist: {wrapper_path}")
    actual_text = wrapper_path.read_text(encoding="utf-8")
    if actual_text == expected_text:
        return
    diff = "\n".join(
        difflib.unified_diff(
            actual_text.splitlines(),
            expected_text.splitlines(),
            fromfile=str(wrapper_path),
            tofile="generated-wrapper",
            lineterm="",
        )
    )
    if not diff:
        diff = "wrapper contents differ from generated output"
    raise SystemExit(
        f"wrapper check failed for {wrapper_path}; regenerate with the wrapper generator.\n{diff}"
    )


def main() -> int:
    args = parse_args()
    raw_text = args.raw.read_text(encoding="utf-8")
    raw_module_name, raw_ports = parse_raw_module(raw_text, args.raw)
    packed_width = validate_raw_ports(raw_ports, args.raw)

    wrapper_text = render_wrapper(raw_module_name, packed_width)
    if args.check:
        check_wrapper(args.wrapper, wrapper_text)
        print(f"validated {args.raw} and verified {args.wrapper}")
        return 0
    args.wrapper.parent.mkdir(parents=True, exist_ok=True)
    args.wrapper.write_text(wrapper_text, encoding="utf-8")
    print(f"wrote {args.wrapper}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
