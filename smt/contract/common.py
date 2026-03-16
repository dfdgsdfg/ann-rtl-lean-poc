from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONTRACT_PATH = ROOT / "contract" / "results" / "canonical" / "weights.json"

EXPECTED_OVERFLOW_RULE = "two_complement_wraparound"
EXPECTED_SIGN_EXTENSION_RULE = "required_between_product_and_accumulator_stages"
EXPECTED_CLIPPING_RULE = "signed_saturating"


@dataclass(frozen=True)
class FrozenContract:
    path: Path
    raw: dict[str, Any]
    input_size: int
    hidden_size: int
    w1: tuple[tuple[int, ...], ...]
    b1: tuple[int, ...]
    w2: tuple[int, ...]
    b2: int
    arithmetic: dict[str, Any]
    quantization: dict[str, Any]
    boundedness: dict[str, Any]


@dataclass(frozen=True)
class NetworkModel:
    lines: tuple[str, ...]
    input_symbols: tuple[str, ...]
    hidden_input_symbols: tuple[str, ...]
    hidden_input_rtl_symbols: tuple[str, ...]
    rtl_hidden_product_bits: int
    contract_hidden_products: tuple[tuple[str, ...], ...]
    rtl_hidden_products: tuple[tuple[str, ...], ...]
    contract_hidden_preacts: tuple[str, ...]
    rtl_hidden_preacts: tuple[str, ...]
    contract_hidden_acts: tuple[str, ...]
    rtl_hidden_acts: tuple[str, ...]
    contract_output_products: tuple[str, ...]
    rtl_output_products: tuple[str, ...]
    contract_output_score: str
    rtl_output_score: str
    contract_out_bit: str
    rtl_out_bit: str


@dataclass(frozen=True)
class CheckSpec:
    name: str
    description: str
    assertion: str
    assumptions: dict[str, object]


def load_contract(path: Path = DEFAULT_CONTRACT_PATH) -> FrozenContract:
    raw = json.loads(path.read_text(encoding="utf-8"))
    input_size = int(raw["input_size"])
    hidden_size = int(raw["hidden_size"])

    w1 = tuple(tuple(int(value) for value in row) for row in raw["w1"])
    b1 = tuple(int(value) for value in raw["b1"])
    w2 = tuple(int(value) for value in raw["w2"])
    b2 = int(raw["b2"])

    if len(w1) != hidden_size:
        raise ValueError(f"w1 row count {len(w1)} does not match hidden_size {hidden_size}")
    if any(len(row) != input_size for row in w1):
        raise ValueError("w1 columns do not match input_size")
    if len(b1) != hidden_size:
        raise ValueError(f"b1 length {len(b1)} does not match hidden_size {hidden_size}")
    if len(w2) != hidden_size:
        raise ValueError(f"w2 length {len(w2)} does not match hidden_size {hidden_size}")

    arithmetic = dict(raw["arithmetic"])
    quantization = dict(raw["quantization"])
    boundedness = dict(raw["boundedness"])

    if arithmetic["overflow"] != EXPECTED_OVERFLOW_RULE:
        raise ValueError(f"unsupported overflow rule: {arithmetic['overflow']}")
    if arithmetic["sign_extension"] != EXPECTED_SIGN_EXTENSION_RULE:
        raise ValueError(f"unsupported sign extension rule: {arithmetic['sign_extension']}")
    if quantization["clipping"] != EXPECTED_CLIPPING_RULE:
        raise ValueError(f"unsupported clipping rule: {quantization['clipping']}")

    return FrozenContract(
        path=path,
        raw=raw,
        input_size=input_size,
        hidden_size=hidden_size,
        w1=w1,
        b1=b1,
        w2=w2,
        b2=b2,
        arithmetic=arithmetic,
        quantization=quantization,
        boundedness=boundedness,
    )


def repo_relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def timestamp_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def signed_bv_literal(value: int, width: int) -> str:
    return f"(_ bv{value % (1 << width)} {width})"


def sign_extend(expr: str, from_width: int, to_width: int) -> str:
    if to_width < from_width:
        raise ValueError(f"cannot sign-extend {from_width} bits down to {to_width}")
    extend_by = to_width - from_width
    if extend_by == 0:
        return expr
    return f"((_ sign_extend {extend_by}) {expr})"


def extract_low(expr: str, width: int) -> str:
    return f"((_ extract {width - 1} 0) {expr})"


def signed_max(width: int) -> int:
    return (1 << (width - 1)) - 1


def bvadd_chain(expressions: Sequence[str]) -> str:
    if not expressions:
        raise ValueError("expected at least one expression for bvadd")
    result = expressions[0]
    for expression in expressions[1:]:
        result = f"(bvadd {result} {expression})"
    return result


def or_chain(expressions: Sequence[str]) -> str:
    if not expressions:
        return "false"
    if len(expressions) == 1:
        return expressions[0]
    return f"(or {' '.join(expressions)})"


def and_chain(expressions: Sequence[str]) -> str:
    if not expressions:
        return "true"
    if len(expressions) == 1:
        return expressions[0]
    return f"(and {' '.join(expressions)})"


def neq_or(expressions: Sequence[tuple[str, str]]) -> str:
    clauses = [f"(distinct {lhs} {rhs})" for lhs, rhs in expressions]
    return or_chain(clauses)


def build_network_model(contract: FrozenContract) -> NetworkModel:
    input_bits = int(contract.arithmetic["input_bits"])
    hidden_act_bits = int(contract.arithmetic["hidden_activation_bits"])
    hidden_product_bits = int(contract.arithmetic["hidden_product_bits"])
    output_product_bits = int(contract.arithmetic["output_product_bits"])
    output_weight_bits = int(contract.arithmetic["output_weight_bits"])
    acc_bits = int(contract.arithmetic["accumulator_bits"])
    rtl_hidden_product_bits = hidden_act_bits + output_weight_bits

    if rtl_hidden_product_bits != output_product_bits:
        raise ValueError(
            "RTL-style hidden product width mismatch: "
            f"hidden_activation_bits + output_weight_bits = {rtl_hidden_product_bits}, "
            f"expected output_product_bits = {output_product_bits}"
        )

    lines: list[str] = ["(set-logic QF_BV)"]
    input_symbols = tuple(f"in{index}" for index in range(contract.input_size))
    for symbol in input_symbols:
        lines.append(f"(declare-fun {symbol} () (_ BitVec {input_bits}))")

    hidden_input_symbols = tuple(f"contract_input_{index}_16" for index in range(contract.input_size))
    hidden_input_rtl_symbols = tuple(f"rtl_input_{index}_16" for index in range(contract.input_size))

    for index, symbol in enumerate(hidden_input_symbols):
        lines.append(
            f"(define-fun {symbol} () (_ BitVec {hidden_act_bits})"
            f" {sign_extend(input_symbols[index], input_bits, hidden_act_bits)})"
        )
    for index, symbol in enumerate(hidden_input_rtl_symbols):
        lines.append(
            f"(define-fun {symbol} () (_ BitVec {hidden_act_bits})"
            f" {sign_extend(input_symbols[index], input_bits, hidden_act_bits)})"
        )

    lines.append(
        f"(define-fun contract_relu16 ((x (_ BitVec {acc_bits}))) (_ BitVec {hidden_act_bits}) "
        f"(ite (bvslt x {signed_bv_literal(0, acc_bits)}) {signed_bv_literal(0, hidden_act_bits)} "
        f"(ite (bvsgt x {signed_bv_literal(signed_max(hidden_act_bits), acc_bits)}) "
        f"{signed_bv_literal(signed_max(hidden_act_bits), hidden_act_bits)} "
        f"{extract_low('x', hidden_act_bits)})))"
    )
    lines.append(
        f"(define-fun rtl_relu16 ((x (_ BitVec {acc_bits}))) (_ BitVec {hidden_act_bits}) "
        f"(ite (bvslt x {signed_bv_literal(0, acc_bits)}) {signed_bv_literal(0, hidden_act_bits)} "
        f"{extract_low('x', hidden_act_bits)}))"
    )

    contract_hidden_products: list[list[str]] = []
    rtl_hidden_products: list[list[str]] = []
    contract_hidden_preacts: list[str] = []
    rtl_hidden_preacts: list[str] = []
    contract_hidden_acts: list[str] = []
    rtl_hidden_acts: list[str] = []

    for hidden_index, row in enumerate(contract.w1):
        contract_product_names: list[str] = []
        rtl_product_names: list[str] = []
        for input_index, weight in enumerate(row):
            contract_product_name = f"contract_hidden_prod_{hidden_index}_{input_index}"
            rtl_product_name = f"rtl_hidden_prod_{hidden_index}_{input_index}"
            contract_input_symbol = hidden_input_symbols[input_index]
            rtl_input_symbol = hidden_input_rtl_symbols[input_index]

            lines.append(
                f"(define-fun {contract_product_name} () (_ BitVec {hidden_product_bits}) "
                f"(bvmul {contract_input_symbol} {signed_bv_literal(weight, hidden_product_bits)}))"
            )
            # The frozen contract models hidden products as int8 x int8 -> int16.
            # The RTL-style view mirrors mlp_core/mac_unit: inputs are sign-extended
            # to 16 bits before multiply, so the hidden contribution is represented
            # as a 24-bit product before it is sign-extended into the accumulator.
            lines.append(
                f"(define-fun {rtl_product_name} () (_ BitVec {rtl_hidden_product_bits}) "
                f"(bvmul {sign_extend(rtl_input_symbol, hidden_act_bits, rtl_hidden_product_bits)} "
                f"{signed_bv_literal(weight, rtl_hidden_product_bits)}))"
            )

            contract_product_names.append(contract_product_name)
            rtl_product_names.append(rtl_product_name)

        contract_hidden_products.append(contract_product_names)
        rtl_hidden_products.append(rtl_product_names)

        contract_preact_name = f"contract_hidden_preact_{hidden_index}"
        rtl_preact_name = f"rtl_hidden_preact_{hidden_index}"
        contract_act_name = f"contract_hidden_act_{hidden_index}"
        rtl_act_name = f"rtl_hidden_act_{hidden_index}"

        contract_preact_terms = [
            sign_extend(product_name, hidden_product_bits, acc_bits)
            for product_name in contract_product_names
        ]
        contract_preact_terms.append(signed_bv_literal(contract.b1[hidden_index], acc_bits))
        rtl_preact_terms = [
            sign_extend(product_name, rtl_hidden_product_bits, acc_bits)
            for product_name in rtl_product_names
        ]
        rtl_preact_terms.append(signed_bv_literal(contract.b1[hidden_index], acc_bits))

        lines.append(
            f"(define-fun {contract_preact_name} () (_ BitVec {acc_bits}) {bvadd_chain(contract_preact_terms)})"
        )
        lines.append(
            f"(define-fun {rtl_preact_name} () (_ BitVec {acc_bits}) {bvadd_chain(rtl_preact_terms)})"
        )
        lines.append(
            f"(define-fun {contract_act_name} () (_ BitVec {hidden_act_bits}) "
            f"(contract_relu16 {contract_preact_name}))"
        )
        lines.append(
            f"(define-fun {rtl_act_name} () (_ BitVec {hidden_act_bits}) (rtl_relu16 {rtl_preact_name}))"
        )

        contract_hidden_preacts.append(contract_preact_name)
        rtl_hidden_preacts.append(rtl_preact_name)
        contract_hidden_acts.append(contract_act_name)
        rtl_hidden_acts.append(rtl_act_name)

    contract_output_products: list[str] = []
    rtl_output_products: list[str] = []
    for hidden_index, weight in enumerate(contract.w2):
        contract_product_name = f"contract_output_prod_{hidden_index}"
        rtl_product_name = f"rtl_output_prod_{hidden_index}"

        lines.append(
            f"(define-fun {contract_product_name} () (_ BitVec {output_product_bits}) "
            f"(bvmul {sign_extend(contract_hidden_acts[hidden_index], hidden_act_bits, output_product_bits)} "
            f"{signed_bv_literal(weight, output_product_bits)}))"
        )
        lines.append(
            f"(define-fun {rtl_product_name} () (_ BitVec {output_product_bits}) "
            f"(bvmul {sign_extend(rtl_hidden_acts[hidden_index], hidden_act_bits, output_product_bits)} "
            f"{signed_bv_literal(weight, output_product_bits)}))"
        )

        contract_output_products.append(contract_product_name)
        rtl_output_products.append(rtl_product_name)

    contract_output_score = "contract_output_score"
    rtl_output_score = "rtl_output_score"
    contract_score_terms = [
        sign_extend(product_name, output_product_bits, acc_bits)
        for product_name in contract_output_products
    ]
    contract_score_terms.append(signed_bv_literal(contract.b2, acc_bits))
    rtl_score_terms = [
        sign_extend(product_name, output_product_bits, acc_bits)
        for product_name in rtl_output_products
    ]
    rtl_score_terms.append(signed_bv_literal(contract.b2, acc_bits))

    lines.append(
        f"(define-fun {contract_output_score} () (_ BitVec {acc_bits}) {bvadd_chain(contract_score_terms)})"
    )
    lines.append(f"(define-fun {rtl_output_score} () (_ BitVec {acc_bits}) {bvadd_chain(rtl_score_terms)})")
    lines.append(
        f"(define-fun contract_out_bit () Bool (bvsgt {contract_output_score} {signed_bv_literal(0, acc_bits)}))"
    )
    lines.append(f"(define-fun rtl_out_bit () Bool (bvsgt {rtl_output_score} {signed_bv_literal(0, acc_bits)}))")

    return NetworkModel(
        lines=tuple(lines),
        input_symbols=input_symbols,
        hidden_input_symbols=hidden_input_symbols,
        hidden_input_rtl_symbols=hidden_input_rtl_symbols,
        rtl_hidden_product_bits=rtl_hidden_product_bits,
        contract_hidden_products=tuple(tuple(row) for row in contract_hidden_products),
        rtl_hidden_products=tuple(tuple(row) for row in rtl_hidden_products),
        contract_hidden_preacts=tuple(contract_hidden_preacts),
        rtl_hidden_preacts=tuple(rtl_hidden_preacts),
        contract_hidden_acts=tuple(contract_hidden_acts),
        rtl_hidden_acts=tuple(rtl_hidden_acts),
        contract_output_products=tuple(contract_output_products),
        rtl_output_products=tuple(rtl_output_products),
        contract_output_score=contract_output_score,
        rtl_output_score=rtl_output_score,
        contract_out_bit="contract_out_bit",
        rtl_out_bit="rtl_out_bit",
    )


def build_batch_smt(base_lines: Sequence[str], checks: Sequence[CheckSpec]) -> str:
    lines = list(base_lines)
    for check in checks:
        lines.append(f"; {check.name}")
        lines.append("(push 1)")
        lines.append(f"(assert {check.assertion})")
        lines.append("(check-sat)")
        lines.append("(pop 1)")
    lines.append("(exit)")
    return "\n".join(lines) + "\n"


def build_single_check_smt(base_lines: Sequence[str], check: CheckSpec) -> str:
    lines = list(base_lines)
    lines.append(f"; {check.name}")
    lines.append(f"(assert {check.assertion})")
    lines.append("(check-sat)")
    lines.append("(exit)")
    return "\n".join(lines) + "\n"


def z3_version(z3_binary: str) -> str:
    result = subprocess.run(
        [z3_binary, "--version"],
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"failed to query {z3_binary} version:\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


def run_z3_batch(z3_binary: str, smt_text: str, expected_results: int) -> list[str]:
    result = subprocess.run(
        [z3_binary, "-in"],
        input=smt_text,
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"{z3_binary} failed:\n{result.stdout}{result.stderr}")

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip() and line.strip() != "success"]
    if len(lines) != expected_results:
        raise RuntimeError(
            f"expected {expected_results} check-sat results from {z3_binary}, got {len(lines)}:\n{result.stdout}"
        )
    invalid = [line for line in lines if line not in {"sat", "unsat", "unknown"}]
    if invalid:
        raise RuntimeError(f"unexpected {z3_binary} output lines: {invalid}")
    return lines


def run_z3_query(z3_binary: str, smt_text: str) -> str:
    result = subprocess.run(
        [z3_binary, "-in"],
        input=smt_text,
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"{z3_binary} failed:\n{result.stdout}{result.stderr}")
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip() and line.strip() != "success"]
    if len(lines) != 1:
        raise RuntimeError(f"expected one check-sat result from {z3_binary}, got {lines}")
    solver_result = lines[0]
    if solver_result not in {"sat", "unsat", "unknown"}:
        raise RuntimeError(f"unexpected {z3_binary} output line: {solver_result}")
    return solver_result


def build_reproduction_command(
    *,
    script_path: Path,
    summary_path: Path,
    z3_binary: str,
    contract_path: Path,
    dump_smt_path: Path | None = None,
) -> str:
    parts = [
        "python3",
        repo_relative(script_path),
        "--z3",
        z3_binary,
        "--contract",
        repo_relative(contract_path),
        "--summary",
        repo_relative(summary_path),
    ]
    if dump_smt_path is not None:
        parts.extend(["--dump-smt", repo_relative(dump_smt_path)])
    return " ".join(parts)


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
