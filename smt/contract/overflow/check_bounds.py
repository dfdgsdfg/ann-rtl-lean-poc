from __future__ import annotations

import argparse
import sys
from pathlib import Path


if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from common import (  # type: ignore[import-not-found]
        ROOT,
        CheckSpec,
        build_batch_smt,
        build_single_check_smt,
        build_network_model,
        build_reproduction_command,
        bvadd_chain,
        load_contract,
        neq_or,
        or_chain,
        repo_relative,
        run_z3_query,
        sign_extend,
        signed_bv_literal,
        timestamp_utc,
        write_json,
        z3_version,
    )
    from runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot  # type: ignore[import-not-found]
else:
    from ..common import (
        ROOT,
        CheckSpec,
        build_batch_smt,
        build_single_check_smt,
        build_network_model,
        build_reproduction_command,
        bvadd_chain,
        load_contract,
        neq_or,
        or_chain,
        repo_relative,
        run_z3_query,
        sign_extend,
        signed_bv_literal,
        timestamp_utc,
        write_json,
        z3_version,
    )
    from runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot


DEFAULT_BUILD_ROOT = ROOT / "build" / "smt"
DEFAULT_REPORT_ROOT = ROOT / "reports" / "smt"
DEFAULT_SUMMARY = DEFAULT_REPORT_ROOT / "canonical" / "contract" / "overflow" / "summary.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prove frozen width/overflow/sign-extension properties for contract/results/canonical/weights.json."
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="Runtime build root for SMT overflow artifacts.",
    )
    parser.add_argument(
        "--report-root",
        type=Path,
        default=DEFAULT_REPORT_ROOT,
        help="Runtime report root for SMT overflow summaries.",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="Optional run id for runtime artifact provenance mode.",
    )
    parser.add_argument(
        "--contract",
        type=Path,
        default=ROOT / "contract" / "results" / "canonical" / "weights.json",
        help="Frozen contract JSON to analyze.",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=None,
        help="JSON path for the proof summary. Overrides provenance mode.",
    )
    parser.add_argument(
        "--z3",
        default="z3",
        help="Path to the z3 CLI binary.",
    )
    parser.add_argument(
        "--dump-smt",
        type=Path,
        help="Optional path for the generated SMT-LIB batch query.",
    )
    return parser.parse_args()


def build_checks(contract_path: Path) -> tuple[list[CheckSpec], tuple[str, ...], str]:
    contract = load_contract(contract_path)
    model = build_network_model(contract)

    hidden_product_bits = int(contract.arithmetic["hidden_product_bits"])
    hidden_activation_bits = int(contract.arithmetic["hidden_activation_bits"])
    output_product_bits = int(contract.arithmetic["output_product_bits"])
    rtl_hidden_product_bits = model.rtl_hidden_product_bits
    accumulator_bits = int(contract.arithmetic["accumulator_bits"])
    wide_bits = max(64, accumulator_bits * 2)

    hidden_product_bound = contract.boundedness["hidden_product"]
    hidden_preact_bound = contract.boundedness["hidden_pre_activation"]
    hidden_activation_bound = contract.boundedness["hidden_activation"]
    output_product_bound = contract.boundedness["output_product"]
    output_acc_bound = contract.boundedness["output_accumulator"]

    base_lines = list(model.lines)

    hidden_wide_names: list[str] = []
    for hidden_index, product_names in enumerate(model.contract_hidden_products):
        wide_name = f"contract_hidden_preact_{hidden_index}_wide"
        wide_terms = [
            sign_extend(product_name, hidden_product_bits, wide_bits)
            for product_name in product_names
        ]
        wide_terms.append(sign_extend(signed_bv_literal(contract.b1[hidden_index], accumulator_bits), accumulator_bits, wide_bits))
        base_lines.append(
            f"(define-fun {wide_name} () (_ BitVec {wide_bits}) {bvadd_chain(wide_terms)})"
        )
        hidden_wide_names.append(wide_name)

    output_wide_name = "contract_output_score_wide"
    output_wide_terms = [
        sign_extend(product_name, output_product_bits, wide_bits)
        for product_name in model.contract_output_products
    ]
    output_wide_terms.append(sign_extend(signed_bv_literal(contract.b2, accumulator_bits), accumulator_bits, wide_bits))
    base_lines.append(
        f"(define-fun {output_wide_name} () (_ BitVec {wide_bits}) {bvadd_chain(output_wide_terms)})"
    )

    checks = [
        CheckSpec(
            name="hidden_products_fit_int16",
            description="Every hidden-layer product remains inside the frozen signed int16 bound.",
            assertion=or_chain(
                [
                    (
                        f"(or (bvslt {product_name} {signed_bv_literal(hidden_product_bound['min_bound'], hidden_product_bits)}) "
                        f"(bvsgt {product_name} {signed_bv_literal(hidden_product_bound['max_bound'], hidden_product_bits)}))"
                    )
                    for product_row in model.contract_hidden_products
                    for product_name in product_row
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "bits": hidden_product_bits,
                "min_bound": hidden_product_bound["min_bound"],
                "max_bound": hidden_product_bound["max_bound"],
                "view": "contract hidden products (signed int8 x int8 -> int16)",
            },
        ),
        CheckSpec(
            name="hidden_pre_activations_fit_int32",
            description="Every hidden pre-activation stays within the frozen signed int32 bound.",
            assertion=or_chain(
                [
                    (
                        f"(or (bvslt {preact_name} {signed_bv_literal(hidden_preact_bound['min_bound'], accumulator_bits)}) "
                        f"(bvsgt {preact_name} {signed_bv_literal(hidden_preact_bound['max_bound'], accumulator_bits)}))"
                    )
                    for preact_name in model.contract_hidden_preacts
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "bits": accumulator_bits,
                "min_bound": hidden_preact_bound["min_bound"],
                "max_bound": hidden_preact_bound["max_bound"],
                "view": "contract hidden accumulators after bias",
            },
        ),
        CheckSpec(
            name="hidden_activations_fit_int16",
            description="Every hidden activation stays within the frozen signed int16 post-ReLU bound.",
            assertion=or_chain(
                [
                    (
                        f"(or (bvslt {activation_name} {signed_bv_literal(hidden_activation_bound['min_bound'], hidden_activation_bits)}) "
                        f"(bvsgt {activation_name} {signed_bv_literal(hidden_activation_bound['max_bound'], hidden_activation_bits)}))"
                    )
                    for activation_name in model.contract_hidden_acts
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "bits": hidden_activation_bits,
                "min_bound": hidden_activation_bound["min_bound"],
                "max_bound": hidden_activation_bound["max_bound"],
                "view": "contract hidden activations after signed-saturating ReLU16",
            },
        ),
        CheckSpec(
            name="output_products_fit_int24",
            description="Every output-layer product remains inside the frozen signed int24 bound.",
            assertion=or_chain(
                [
                    (
                        f"(or (bvslt {product_name} {signed_bv_literal(output_product_bound['min_bound'], output_product_bits)}) "
                        f"(bvsgt {product_name} {signed_bv_literal(output_product_bound['max_bound'], output_product_bits)}))"
                    )
                    for product_name in model.contract_output_products
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "bits": output_product_bits,
                "min_bound": output_product_bound["min_bound"],
                "max_bound": output_product_bound["max_bound"],
                "view": "contract output products (signed int16 x int8 -> int24)",
            },
        ),
        CheckSpec(
            name="output_accumulator_fits_int32",
            description="The final output accumulator stays within the frozen signed int32 bound.",
            assertion=(
                f"(or (bvslt {model.contract_output_score} {signed_bv_literal(output_acc_bound['min_bound'], accumulator_bits)}) "
                f"(bvsgt {model.contract_output_score} {signed_bv_literal(output_acc_bound['max_bound'], accumulator_bits)}))"
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "bits": accumulator_bits,
                "min_bound": output_acc_bound["min_bound"],
                "max_bound": output_acc_bound["max_bound"],
                "view": "contract output accumulator after bias",
            },
        ),
        CheckSpec(
            name="hidden_product_sign_extension_matches_rtl",
            description="The contract hidden products and RTL hidden MAC contributions agree after sign extension to the accumulator width.",
            assertion=neq_or(
                [
                    (
                        sign_extend(contract_product_name, hidden_product_bits, accumulator_bits),
                        sign_extend(rtl_product_name, rtl_hidden_product_bits, accumulator_bits),
                    )
                    for contract_row, rtl_row in zip(model.contract_hidden_products, model.rtl_hidden_products)
                    for contract_product_name, rtl_product_name in zip(contract_row, rtl_row)
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "accumulator_bits": accumulator_bits,
                "contract_product_bits": hidden_product_bits,
                "rtl_product_bits": rtl_hidden_product_bits,
                "sign_extension": contract.arithmetic["sign_extension"],
                "rtl_hidden_product_rationale": "The RTL-style hidden product widens after the input lane is sign-extended to 16 bits before multiply.",
            },
        ),
        CheckSpec(
            name="hidden_accumulators_match_wide_sum",
            description="The 32-bit hidden accumulators match the exact wider signed sums, so the chosen wraparound model is explicit but inactive here.",
            assertion=neq_or(
                [
                    (
                        sign_extend(preact_name, accumulator_bits, wide_bits),
                        wide_name,
                    )
                    for preact_name, wide_name in zip(model.contract_hidden_preacts, hidden_wide_names)
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "overflow_rule": contract.arithmetic["overflow"],
                "accumulator_bits": accumulator_bits,
                "wide_bits": wide_bits,
            },
        ),
        CheckSpec(
            name="output_accumulator_matches_wide_sum",
            description="The 32-bit final score matches the exact wider signed sum, so the chosen wraparound model is explicit but inactive here.",
            assertion=neq_or(
                [
                    (
                        sign_extend(model.contract_output_score, accumulator_bits, wide_bits),
                        output_wide_name,
                    )
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "overflow_rule": contract.arithmetic["overflow"],
                "accumulator_bits": accumulator_bits,
                "wide_bits": wide_bits,
            },
        ),
    ]

    return checks, tuple(base_lines), build_batch_smt(base_lines, checks)


def main() -> int:
    args = parse_args()
    snapshot = None
    if args.summary is None:
        snapshot = prepare_snapshot(
            build_root=args.build_root.resolve(),
            report_root=args.report_root.resolve(),
            run_id=args.run_id or build_run_id("smt", "contract-overflow"),
            subpath=Path("contract") / "overflow",
        )
        args.summary = snapshot.report_run_dir / "summary.json"
        if args.dump_smt is None:
            args.dump_smt = snapshot.build_run_dir / "query.smt2"

    contract = load_contract(args.contract)
    model = build_network_model(contract)
    checks, base_lines, smt_text = build_checks(args.contract)

    if args.dump_smt is not None:
        args.dump_smt.parent.mkdir(parents=True, exist_ok=True)
        args.dump_smt.write_text(smt_text, encoding="utf-8")

    solver_version = z3_version(args.z3)
    result_rows: list[dict[str, object]] = []
    overall_result = "pass"
    for check in checks:
        solver_result = run_z3_query(args.z3, build_single_check_smt(base_lines, check))
        if solver_result == "unsat":
            check_result = "pass"
        elif solver_result == "sat":
            check_result = "fail"
            overall_result = "fail"
        else:
            check_result = "unknown"
            overall_result = "error"

        result_rows.append(
            {
                "name": check.name,
                "description": check.description,
                "result": check_result,
                "solver_result": solver_result,
                "assumptions": check.assumptions,
            }
        )
        print(f"{check.name}: {check_result} ({solver_result})")

    generated_at_utc = timestamp_utc()
    summary = {
        "generated_at_utc": generated_at_utc,
        "summary_kind": "contract_overflow",
        "overall_result": overall_result,
        "source_contract": repo_relative(contract.path),
        "network_shape": {
            "input_size": contract.input_size,
            "hidden_size": contract.hidden_size,
            "output_size": 1,
        },
        "encoding": {
            "logic": "QF_BV",
            "overflow_rule": contract.arithmetic["overflow"],
            "sign_extension_rule": contract.arithmetic["sign_extension"],
            "contract_hidden_product_bits": contract.arithmetic["hidden_product_bits"],
            "rtl_hidden_product_bits": model.rtl_hidden_product_bits,
            "rtl_hidden_product_model": "sign-extend hidden inputs to 16 bits before multiply, matching mlp_core/mac_unit",
            "contract_output_product_bits": contract.arithmetic["output_product_bits"],
            "accumulator_bits": contract.arithmetic["accumulator_bits"],
            "wide_sum_bits": max(64, int(contract.arithmetic["accumulator_bits"]) * 2),
        },
        "tool": {
            "solver": "z3",
            "binary": args.z3,
            "version": solver_version,
        },
        "reproduction": {
            "script": repo_relative(Path(__file__).resolve()),
            "command": build_reproduction_command(
                script_path=Path(__file__).resolve(),
                summary_path=args.summary.resolve(),
                z3_binary=args.z3,
                contract_path=contract.path.resolve(),
                dump_smt_path=args.dump_smt.resolve() if args.dump_smt is not None else None,
            ),
        },
        "assumptions": {
            "scope": contract.boundedness["scope"],
            "boundedness_status": contract.boundedness["status"],
            "frozen_contract": repo_relative(contract.path),
            "quantization_clipping": contract.quantization["clipping"],
        },
        "results": result_rows,
    }

    write_json(args.summary, summary)
    if snapshot is not None:
        promote_snapshot(
            snapshot,
            source="smt_contract_overflow",
            created_at_utc=generated_at_utc,
            inputs={"contract": repo_relative(contract.path)},
            commands={"driver": summary["reproduction"]["command"]},
            tool_versions={"z3": solver_version},
            artifacts={"query": repo_relative(args.dump_smt)} if args.dump_smt is not None else {},
            reports={"summary": repo_relative(args.summary)},
        )
    print(f"wrote {args.summary}")
    if args.dump_smt is not None:
        print(f"wrote {args.dump_smt}")

    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
