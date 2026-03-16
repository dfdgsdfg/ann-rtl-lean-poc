from __future__ import annotations

from pathlib import Path

from .artifacts import CONTRACT_MODEL_MD_PATH, ROOT

WEIGHT_ROM_PATH = ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv"
LEAN_SPEC_PATH = ROOT / "formalize" / "src" / "TinyMLP" / "Defs" / "SpecCore.lean"
SPARKLE_CONTRACT_DATA_PATH = ROOT / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle" / "ContractData.lean"
DEFAULT_MODEL_DOC_TEMPLATE = """# Tiny MLP ASIC Canonical Specification

## Topology

- input neurons: 4
- hidden neurons: 8
- output neurons: 1
- activation: ReLU
- decision rule: `out = (score > 0)`

## Arithmetic

- inputs: signed `int8`
- first-layer weights: signed `int8`
- hidden activations: signed `int16`
- hidden products: `int8 * int8 -> int16`, then sign-extended into the `int32` accumulator
- output-layer weights: signed `int8`
- output products: `int16 * int8 -> int24`, then sign-extended into the `int32` accumulator
- accumulators and biases: signed `int32`
- overflow policy: signed two's complement wraparound
- quantization rounding: round half away from zero
- quantization clipping: signed saturation to the destination width

## Verified Boundedness

<!-- BEGIN AUTO-GENERATED BOUNDEDNESS -->
<!-- END AUTO-GENERATED BOUNDEDNESS -->

## Canonical Weights

<!-- BEGIN AUTO-GENERATED WEIGHTS -->
<!-- END AUTO-GENERATED WEIGHTS -->

## Sequential-MAC Microarchitecture

The RTL computes one hidden neuron at a time:

```text
IDLE
  -> LOAD_INPUT
  -> MAC_HIDDEN   (4 MAC operations, 5 clock cycles per hidden neuron)
  -> BIAS_HIDDEN
  -> ACT_HIDDEN
  -> NEXT_HIDDEN
  -> MAC_OUTPUT   (8 MAC operations, 9 clock cycles)
  -> BIAS_OUTPUT
  -> DONE
```

Each MAC phase includes one transition cycle after the last MAC operation where the index has reached its terminal value and the FSM advances to the next state without performing a MAC.

Cycle budget for one inference:

- `1` cycle: `IDLE -> LOAD_INPUT`
- `1` cycle: `LOAD_INPUT -> MAC_HIDDEN`
- `8 * (5 + 1 + 1 + 1) = 64` cycles: all hidden neurons (5 MAC_HIDDEN + 1 BIAS + 1 ACT + 1 NEXT per neuron)
- `9 + 1 = 10` cycles: output accumulation (9 MAC_OUTPUT + 1 BIAS_OUTPUT)

Total: `76` cycles from the abstract Lean machine's `initialState` to `DONE`.
"""


def _replace_block(text: str, begin: str, end: str, body: str) -> str:
    start = text.index(begin) + len(begin)
    finish = text.index(end)
    return text[:start] + "\n" + body.rstrip() + "\n" + text[finish:]


def _sv_literal(value: int, bits: int) -> str:
    return f"-{bits}'sd{abs(value)}" if value < 0 else f"{bits}'sd{value}"


def _lean_call_literal(value: int) -> str:
    return f"({value})" if value < 0 else str(value)


def _lean_w1_block(weights: dict[str, object]) -> str:
    lines = ["def w1At : Nat → Nat → Int"]
    for i, row in enumerate(weights["w1"]):
        for j, value in enumerate(row):
            lines.append(f"  | {i}, {j} => {value}")
    lines.append("  | _, _ => 0")
    lines.append("")
    lines.append("def b1At : Nat → Int")
    for i, value in enumerate(weights["b1"]):
        lines.append(f"  | {i} => {value}")
    lines.append("  | _ => 0")
    lines.append("")
    lines.append("def w2At : Nat → Int")
    for i, value in enumerate(weights["w2"]):
        lines.append(f"  | {i} => {value}")
    lines.append("  | _ => 0")
    lines.append("")
    lines.append(f"def b2 : Int := {weights['b2']}")
    return "\n".join(lines)


def _weight_rom_block(weights: dict[str, object]) -> str:
    lines = [
        "  always_comb begin",
        "    unique case ({hidden_idx, input_idx})",
    ]
    for i, row in enumerate(weights["w1"]):
        for j, value in enumerate(row):
            lines.append(f"      8'h{i:x}{j:x}: w1_data = {_sv_literal(value, 8)};")
    lines.extend(
        [
            "      default: w1_data = 8'sd0;",
            "    endcase",
            "  end",
            "",
            "  always_comb begin",
            "    unique case (hidden_idx)",
        ]
    )
    for i, value in enumerate(weights["b1"]):
        lines.append(f"      4'd{i}: b1_data = {_sv_literal(value, 32)};")
    lines.extend(
        [
            "      default: b1_data = 32'sd0;",
            "    endcase",
            "  end",
            "",
            "  always_comb begin",
            "    unique case (input_idx)",
        ]
    )
    for i, value in enumerate(weights["w2"]):
        lines.append(f"      4'd{i}: w2_data = {_sv_literal(value, 8)};")
    lines.extend(
        [
            "      default: w2_data = 8'sd0;",
            "    endcase",
            "  end",
            "",
            f"  assign b2_data = {_sv_literal(weights['b2'], 32)};",
            "",
            "`ifdef FORMAL",
            "  assign formal_hidden_weight_case_hit = (hidden_idx < 4'd8) && (input_idx < 4'd4);",
            "  assign formal_output_weight_case_hit = (input_idx < 4'd8);",
            "`endif",
        ]
    )
    return "\n".join(lines)


def _sparkle_contract_data_block(weights: dict[str, object]) -> str:
    lines = [
        "def w1Data {dom : DomainConfig}",
        "    (hidden_idx input_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 8) :=",
        "  hw_cond (Signal.pure (bv8 0))",
    ]
    for i, row in enumerate(weights["w1"]):
        for j, value in enumerate(row):
            lines.append(
                "    | "
                f"(hidden_idx === Signal.pure (bv4 {i})) &&& (input_idx === Signal.pure (bv4 {j})) => "
                f"Signal.pure (bv8 {_lean_call_literal(value)})"
            )
    lines.extend(
        [
            "",
            "def b1Data {dom : DomainConfig}",
            "    (hidden_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 32) :=",
            "  hw_cond (Signal.pure (bv32 0))",
        ]
    )
    for i, value in enumerate(weights["b1"]):
        lines.append(f"    | hidden_idx === Signal.pure (bv4 {i}) => Signal.pure (bv32 {_lean_call_literal(value)})")
    lines.extend(
        [
            "",
            "def w2Data {dom : DomainConfig}",
            "    (input_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 8) :=",
            "  hw_cond (Signal.pure (bv8 0))",
        ]
    )
    for i, value in enumerate(weights["w2"]):
        lines.append(f"    | input_idx === Signal.pure (bv4 {i}) => Signal.pure (bv8 {_lean_call_literal(value)})")
    lines.extend(
        [
            "",
            "def b2Data {dom : DomainConfig} : Signal dom (BitVec 32) :=",
            f"  Signal.pure (bv32 {_lean_call_literal(weights['b2'])})",
        ]
    )
    return "\n".join(lines)


def _model_md_block(weights: dict[str, object]) -> str:
    lines = [
        "`W1` (`8 x 4`)",
        "",
        "| hidden | x0 | x1 | x2 | x3 |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for i, row in enumerate(weights["w1"]):
        lines.append(f"| h{i} | {row[0]:2d} | {row[1]:2d} | {row[2]:2d} | {row[3]:2d} |")
    lines.extend(
        [
            "",
            "`b1`",
            "",
            "```text",
            str(weights["b1"]),
            "```",
            "",
            "`W2`",
            "",
            "```text",
            str(weights["w2"]),
            "```",
            "",
            "`b2`",
            "",
            "```text",
            str(weights["b2"]),
            "```",
        ]
    )
    return "\n".join(lines)


def _boundedness_block(weights: dict[str, object]) -> str:
    boundedness = weights["boundedness"]
    input_range = boundedness["input_range"]
    hidden_product = boundedness["hidden_product"]
    hidden_pre = boundedness["hidden_pre_activation"]
    hidden_activation = boundedness["hidden_activation"]
    output_product = boundedness["output_product"]
    output_accumulator = boundedness["output_accumulator"]

    return "\n".join(
        [
            f"- checked scope: all signed `int8` inputs `[{input_range['min']}, {input_range['max']}]`",
            f"- hidden products: safe bound `[{hidden_product['min_bound']}, {hidden_product['max_bound']}]` within signed `int{hidden_product['bits']}`",
            f"- hidden pre-activations: safe bound `[{hidden_pre['min_bound']}, {hidden_pre['max_bound']}]` within signed `int{hidden_pre['bits']}`",
            f"- hidden activations after ReLU: safe bound `[{hidden_activation['min_bound']}, {hidden_activation['max_bound']}]` within signed `int{hidden_activation['bits']}`",
            f"- output products: safe bound `[{output_product['min_bound']}, {output_product['max_bound']}]` within signed `int{output_product['bits']}`",
            f"- output accumulator: safe bound `[{output_accumulator['min_bound']}, {output_accumulator['max_bound']}]` within signed `int{output_accumulator['bits']}`",
            "",
            "These verified bounds justify treating the current frozen fixed-point model as range-safe for the generated RTL and Lean artifacts.",
        ]
    )


def render_weight_rom_text(weights: dict[str, object]) -> str:
    weight_rom_text = WEIGHT_ROM_PATH.read_text(encoding="utf-8")
    return _replace_block(
        weight_rom_text,
        "  // BEGIN AUTO-GENERATED ROM",
        "  // END AUTO-GENERATED ROM",
        _weight_rom_block(weights),
    )


def render_lean_spec_text(weights: dict[str, object]) -> str:
    lean_spec_text = LEAN_SPEC_PATH.read_text(encoding="utf-8")
    return _replace_block(
        lean_spec_text,
        "/- BEGIN AUTO-GENERATED WEIGHTS -/",
        "/- END AUTO-GENERATED WEIGHTS -/",
        _lean_w1_block(weights),
    )


def render_sparkle_contract_data_text(weights: dict[str, object]) -> str:
    sparkle_contract_text = SPARKLE_CONTRACT_DATA_PATH.read_text(encoding="utf-8")
    return _replace_block(
        sparkle_contract_text,
        "/- BEGIN AUTO-GENERATED CONTRACT DATA -/",
        "/- END AUTO-GENERATED CONTRACT DATA -/",
        _sparkle_contract_data_block(weights),
    )


def render_model_doc_text(weights: dict[str, object]) -> str:
    model_md_text = _replace_block(
        DEFAULT_MODEL_DOC_TEMPLATE,
        "<!-- BEGIN AUTO-GENERATED BOUNDEDNESS -->",
        "<!-- END AUTO-GENERATED BOUNDEDNESS -->",
        _boundedness_block(weights),
    )
    return _replace_block(
        model_md_text,
        "<!-- BEGIN AUTO-GENERATED WEIGHTS -->",
        "<!-- END AUTO-GENERATED WEIGHTS -->",
        _model_md_block(weights),
    )


def expected_downstream_artifacts(weights: dict[str, object]) -> dict[Path, str]:
    model_doc_text = render_model_doc_text(weights)
    return {
        WEIGHT_ROM_PATH: render_weight_rom_text(weights),
        LEAN_SPEC_PATH: render_lean_spec_text(weights),
        SPARKLE_CONTRACT_DATA_PATH: render_sparkle_contract_data_text(weights),
        CONTRACT_MODEL_MD_PATH: model_doc_text,
    }


def sync_downstream(weights: dict[str, object]) -> None:
    WEIGHT_ROM_PATH.write_text(render_weight_rom_text(weights), encoding="utf-8")
    LEAN_SPEC_PATH.write_text(render_lean_spec_text(weights), encoding="utf-8")
    SPARKLE_CONTRACT_DATA_PATH.write_text(render_sparkle_contract_data_text(weights), encoding="utf-8")
    CONTRACT_MODEL_MD_PATH.write_text(render_model_doc_text(weights), encoding="utf-8")
