#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
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
        "--subset-manifest",
        type=Path,
        help="Optional JSON manifest describing the declared emitted subset and semantics-preservation statement.",
    )
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


def collect_port_problems(actual_ports: list[RawPort], expected_ports: list[RawPort]) -> list[str]:
    expected_by_name = {port.name: port for port in expected_ports}
    actual_by_name = {port.name: port for port in actual_ports}

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
    return problems


def validate_raw_ports(raw_ports: list[RawPort], raw_path: Path) -> int:
    problems = collect_port_problems(raw_ports, EXPECTED_RAW_PORTS)
    if problems:
        detail = "\n".join(f"- {problem}" for problem in problems)
        raise SystemExit(f"raw module interface validation failed for {raw_path}:\n{detail}")
    return next(port.width for port in EXPECTED_RAW_PORTS if port.name == "out")


def manifest_error(manifest_path: Path, message: str) -> SystemExit:
    return SystemExit(f"verification manifest validation failed for {manifest_path}: {message}")


def require_manifest_str(value: object, manifest_path: Path, *, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise manifest_error(manifest_path, f"{label} must be a non-empty string")
    return value


def require_manifest_str_list(value: object, manifest_path: Path, *, label: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
        raise manifest_error(manifest_path, f"{label} must be a non-empty list of strings")
    return list(value)


def require_manifest_object(value: object, manifest_path: Path, *, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise manifest_error(manifest_path, f"{label} must be an object")
    return dict(value)


def require_manifest_port_list(value: object, manifest_path: Path, *, label: str) -> list[RawPort]:
    if not isinstance(value, list) or not value:
        raise manifest_error(manifest_path, f"{label} must be a non-empty list")
    ports: list[RawPort] = []
    for index, entry in enumerate(value):
        if not isinstance(entry, dict):
            raise manifest_error(manifest_path, f"{label}[{index}] must be an object")
        direction = entry.get("direction")
        name = entry.get("name")
        width = entry.get("width")
        if direction not in {"input", "output"}:
            raise manifest_error(manifest_path, f"{label}[{index}].direction must be 'input' or 'output'")
        if not isinstance(name, str) or not name:
            raise manifest_error(manifest_path, f"{label}[{index}].name must be a non-empty string")
        if not isinstance(width, int) or width < 1:
            raise manifest_error(manifest_path, f"{label}[{index}].width must be a positive integer")
        ports.append(RawPort(direction=direction, name=name, width=width))
    return ports


def validate_subset_manifest(
    raw_text: str,
    raw_module_name: str,
    raw_ports: list[RawPort],
    raw_path: Path,
    manifest_path: Path,
) -> None:
    if not manifest_path.exists():
        raise manifest_error(manifest_path, "file does not exist")
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise manifest_error(manifest_path, f"invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise manifest_error(manifest_path, "top-level payload must be an object")
    if payload.get("schema_version") != 2:
        raise manifest_error(manifest_path, "schema_version must equal 2")

    proof_endpoint = require_manifest_object(payload.get("proof_endpoint"), manifest_path, label="proof_endpoint")
    require_manifest_str(proof_endpoint.get("kind"), manifest_path, label="proof_endpoint.kind")
    require_manifest_str(proof_endpoint.get("typed_backend_ir"), manifest_path, label="proof_endpoint.typed_backend_ir")
    require_manifest_str(proof_endpoint.get("lean_theorem"), manifest_path, label="proof_endpoint.lean_theorem")
    require_manifest_str(proof_endpoint.get("decl_name"), manifest_path, label="proof_endpoint.decl_name")

    declared_subset = payload.get("declared_emitted_subset")
    if not isinstance(declared_subset, dict):
        raise manifest_error(manifest_path, "declared_emitted_subset must be an object")
    require_manifest_str(declared_subset.get("entrypoint"), manifest_path, label="declared_emitted_subset.entrypoint")
    require_manifest_str(
        declared_subset.get("raw_artifact"),
        manifest_path,
        label="declared_emitted_subset.raw_artifact",
    )
    require_manifest_str_list(
        declared_subset.get("emit_source_paths"),
        manifest_path,
        label="declared_emitted_subset.emit_source_paths",
    )
    expected_module_name = require_manifest_str(
        declared_subset.get("raw_module_name"),
        manifest_path,
        label="declared_emitted_subset.raw_module_name",
    )
    expected_header_comments = require_manifest_str_list(
        declared_subset.get("required_header_comments"),
        manifest_path,
        label="declared_emitted_subset.required_header_comments",
    )
    expected_ports = require_manifest_port_list(
        declared_subset.get("expected_raw_ports"),
        manifest_path,
        label="declared_emitted_subset.expected_raw_ports",
    )

    feature_slice = require_manifest_object(payload.get("sparkle_feature_slice"), manifest_path, label="sparkle_feature_slice")
    require_manifest_str(
        feature_slice.get("compiler_entrypoint"),
        manifest_path,
        label="sparkle_feature_slice.compiler_entrypoint",
    )
    require_manifest_str(
        feature_slice.get("backend_renderer"),
        manifest_path,
        label="sparkle_feature_slice.backend_renderer",
    )
    require_manifest_str(
        feature_slice.get("typed_backend_ir"),
        manifest_path,
        label="sparkle_feature_slice.typed_backend_ir",
    )
    require_manifest_str_list(
        feature_slice.get("constructs"),
        manifest_path,
        label="sparkle_feature_slice.constructs",
    )
    require_manifest_str(
        feature_slice.get("emit_payload_shape"),
        manifest_path,
        label="sparkle_feature_slice.emit_payload_shape",
    )

    exact_emit_path = require_manifest_object(payload.get("exact_emit_path"), manifest_path, label="exact_emit_path")
    require_manifest_str(exact_emit_path.get("decl_name"), manifest_path, label="exact_emit_path.decl_name")
    require_manifest_str(
        exact_emit_path.get("vendor_revision"),
        manifest_path,
        label="exact_emit_path.vendor_revision",
    )
    require_manifest_str(
        exact_emit_path.get("local_patch_id"),
        manifest_path,
        label="exact_emit_path.local_patch_id",
    )
    require_manifest_str(
        exact_emit_path.get("top_module"),
        manifest_path,
        label="exact_emit_path.top_module",
    )
    if not isinstance(exact_emit_path.get("module_count"), int) or exact_emit_path["module_count"] <= 0:
        raise manifest_error(manifest_path, "exact_emit_path.module_count must be a positive integer")
    require_manifest_str(
        exact_emit_path.get("elaborated_design_fingerprint"),
        manifest_path,
        label="exact_emit_path.elaborated_design_fingerprint",
    )
    require_manifest_str(
        exact_emit_path.get("backend_ast_fingerprint"),
        manifest_path,
        label="exact_emit_path.backend_ast_fingerprint",
    )
    require_manifest_str(
        exact_emit_path.get("verilog_render_fingerprint"),
        manifest_path,
        label="exact_emit_path.verilog_render_fingerprint",
    )
    require_manifest_str(
        exact_emit_path.get("raw_artifact_fingerprint"),
        manifest_path,
        label="exact_emit_path.raw_artifact_fingerprint",
    )

    semantics = payload.get("semantics_preservation_statement")
    if not isinstance(semantics, dict):
        raise manifest_error(manifest_path, "semantics_preservation_statement must be an object")
    require_manifest_str(
        semantics.get("source_model"),
        manifest_path,
        label="semantics_preservation_statement.source_model",
    )
    require_manifest_str(
        semantics.get("target_artifact"),
        manifest_path,
        label="semantics_preservation_statement.target_artifact",
    )
    require_manifest_str(
        semantics.get("verification_scope"),
        manifest_path,
        label="semantics_preservation_statement.verification_scope",
    )
    require_manifest_str_list(
        semantics.get("residual_validation_surfaces"),
        manifest_path,
        label="semantics_preservation_statement.residual_validation_surfaces",
    )

    if raw_module_name != expected_module_name:
        raise SystemExit(
            "emitted subset validation failed for "
            f"{raw_path} against {manifest_path}: expected raw module {expected_module_name}, "
            f"found {raw_module_name}"
        )

    header_lines: list[str] = []
    for line in raw_text.splitlines():
        stripped = line.strip()
        if not stripped and not header_lines:
            continue
        if line.startswith("//"):
            header_lines.append(line)
            continue
        break
    actual_header_prefix = header_lines[: len(expected_header_comments)]
    if actual_header_prefix != expected_header_comments:
        raise SystemExit(
            "emitted subset validation failed for "
            f"{raw_path} against {manifest_path}: expected leading header comments "
            f"{expected_header_comments!r}, found {actual_header_prefix!r}"
        )

    problems = collect_port_problems(raw_ports, expected_ports)
    if problems:
        detail = "\n".join(f"- {problem}" for problem in problems)
        raise SystemExit(
            "emitted subset validation failed for "
            f"{raw_path} against {manifest_path}:\n{detail}"
        )


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
    if args.subset_manifest is not None:
        validate_subset_manifest(raw_text, raw_module_name, raw_ports, args.raw, args.subset_manifest)

    wrapper_text = render_wrapper(raw_module_name, packed_width)
    if args.check:
        check_wrapper(args.wrapper, wrapper_text)
        if args.subset_manifest is not None:
            print(
                f"validated {args.raw}, verified declared emitted subset via {args.subset_manifest}, "
                f"and verified {args.wrapper}"
            )
        else:
            print(f"validated {args.raw} and verified {args.wrapper}")
        return 0
    args.wrapper.parent.mkdir(parents=True, exist_ok=True)
    args.wrapper.write_text(wrapper_text, encoding="utf-8")
    print(f"wrote {args.wrapper}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
