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
        and_chain,
        build_batch_smt,
        build_single_check_smt,
        build_network_model,
        build_reproduction_command,
        load_contract,
        neq_or,
        repo_relative,
        run_z3_query,
        sign_extend,
        timestamp_utc,
        write_json,
        z3_version,
    )
    from runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot  # type: ignore[import-not-found]
else:
    from ..common import (
        ROOT,
        CheckSpec,
        and_chain,
        build_batch_smt,
        build_single_check_smt,
        build_network_model,
        build_reproduction_command,
        load_contract,
        neq_or,
        repo_relative,
        run_z3_query,
        sign_extend,
        timestamp_utc,
        write_json,
        z3_version,
    )
    from runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot


DEFAULT_BUILD_ROOT = ROOT / "build" / "smt"
DEFAULT_REPORT_ROOT = ROOT / "reports" / "smt"
DEFAULT_SUMMARY = DEFAULT_REPORT_ROOT / "canonical" / "contract" / "equivalence" / "summary.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prove arithmetic equivalence between the frozen contract view and the RTL-style bitvector view."
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="Runtime build root for SMT equivalence artifacts.",
    )
    parser.add_argument(
        "--report-root",
        type=Path,
        default=DEFAULT_REPORT_ROOT,
        help="Runtime report root for SMT equivalence summaries.",
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
    rtl_hidden_product_bits = model.rtl_hidden_product_bits
    output_product_bits = int(contract.arithmetic["output_product_bits"])
    accumulator_bits = int(contract.arithmetic["accumulator_bits"])

    hidden_contribution_equalities = [
        (
            sign_extend(contract_product, hidden_product_bits, accumulator_bits),
            sign_extend(rtl_product, rtl_hidden_product_bits, accumulator_bits),
        )
        for contract_row, rtl_row in zip(model.contract_hidden_products, model.rtl_hidden_products)
        for contract_product, rtl_product in zip(contract_row, rtl_row)
    ]
    hidden_contribution_assumptions = [f"(= {lhs} {rhs})" for lhs, rhs in hidden_contribution_equalities]
    hidden_preactivation_assumptions = [
        f"(= {contract_preact} {rtl_preact})"
        for contract_preact, rtl_preact in zip(model.contract_hidden_preacts, model.rtl_hidden_preacts)
    ]
    hidden_activation_equalities = [
        f"(= {contract_act} {rtl_act})"
        for contract_act, rtl_act in zip(model.contract_hidden_acts, model.rtl_hidden_acts)
    ]
    output_product_equalities = [
        f"(= {contract_product} {rtl_product})"
        for contract_product, rtl_product in zip(model.contract_output_products, model.rtl_output_products)
    ]

    checks = [
        CheckSpec(
            name="hidden_mac_contributions_equivalent",
            description="The contract hidden MAC contributions and RTL-style hidden MAC contributions agree after sign extension to the accumulator width.",
            assertion=neq_or(
                hidden_contribution_equalities
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "contract_view": "signed int8 x int8 -> int16 hidden products, then sign-extend into int32",
                "rtl_view": "sign-extend inputs to 16 bits, multiply in 24 bits, then sign-extend into int32",
                "accumulator_bits": accumulator_bits,
                "contract_product_bits": hidden_product_bits,
                "rtl_product_bits": rtl_hidden_product_bits,
                "rtl_hidden_product_rationale": "The RTL-style hidden product widens after the input lane is sign-extended to 16 bits before multiply.",
            },
        ),
        CheckSpec(
            name="hidden_pre_activations_equivalent",
            description="The contract hidden pre-activations and RTL-style hidden pre-activations agree once the hidden MAC contributions are matched.",
            assertion=and_chain(
                [
                    *hidden_contribution_assumptions,
                    neq_or(list(zip(model.contract_hidden_preacts, model.rtl_hidden_preacts))),
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "requires": "hidden_mac_contributions_equivalent",
            },
        ),
        CheckSpec(
            name="hidden_activations_equivalent",
            description="The contract hidden activations and RTL-style hidden activations agree once the hidden pre-activations are matched.",
            assertion=and_chain(
                [
                    *hidden_preactivation_assumptions,
                    neq_or(list(zip(model.contract_hidden_acts, model.rtl_hidden_acts))),
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "contract_relu": "signed-saturating ReLU16 derived from the frozen quantization rule",
                "rtl_relu": "non-negative low-16-bit RTL relu_unit behavior",
                "requires": "hidden_pre_activations_equivalent",
            },
        ),
        CheckSpec(
            name="output_products_equivalent",
            description="The output-layer products agree once the hidden activations are matched.",
            assertion=and_chain(
                [
                    *hidden_activation_equalities,
                    neq_or(list(zip(model.contract_output_products, model.rtl_output_products))),
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "output_product_bits": contract.arithmetic["output_product_bits"],
                "requires": "hidden_activations_equivalent",
            },
        ),
        CheckSpec(
            name="output_score_equivalent",
            description="The final frozen score agrees between the contract view and the RTL-style view once the output-layer products are matched.",
            assertion=and_chain(
                [
                    *output_product_equalities,
                    f"(distinct {model.contract_output_score} {model.rtl_output_score})",
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "output_product_bits": contract.arithmetic["output_product_bits"],
                "accumulator_bits": contract.arithmetic["accumulator_bits"],
                "requires": "output_products_equivalent",
            },
        ),
        CheckSpec(
            name="out_bit_equivalent",
            description="The final thresholded output bit is a functional consequence of the shared score threshold rule once the score equivalence is matched.",
            assertion=and_chain(
                [
                    f"(= {model.contract_output_score} {model.rtl_output_score})",
                    f"(distinct {model.contract_out_bit} {model.rtl_out_bit})",
                ]
            ),
            assumptions={
                "scope": contract.boundedness["scope"],
                "decision_rule": "out_bit = (score > 0)",
                "requires": "output_score_equivalent",
            },
        ),
    ]

    return checks, tuple(model.lines), build_batch_smt(model.lines, checks)


def main() -> int:
    args = parse_args()
    snapshot = None
    if args.summary is None:
        snapshot = prepare_snapshot(
            build_root=args.build_root.resolve(),
            report_root=args.report_root.resolve(),
            run_id=args.run_id or build_run_id("smt", "contract-equivalence"),
            subpath=Path("contract") / "equivalence",
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
        "summary_kind": "contract_equivalence",
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
            "contract_view": "frozen fixed-point contract derived directly from weights.json",
            "rtl_style_view": "mac_unit/relu_unit width-accurate bitvector encoding",
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
            "quantization_clipping": contract.quantization["clipping"],
            "frozen_contract": repo_relative(contract.path),
        },
        "results": result_rows,
    }

    write_json(args.summary, summary)
    if snapshot is not None:
        promote_snapshot(
            snapshot,
            source="smt_contract_equivalence",
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
