from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot

CONTRACT_PATH = ROOT / "contract" / "results" / "canonical" / "weights.json"
DEFAULT_BUILD_ROOT = ROOT / "build" / "smt"
DEFAULT_REPORT_ROOT = ROOT / "reports" / "smt"
DEFAULT_OUTPUT = DEFAULT_REPORT_ROOT / "canonical" / "contract" / "assumptions.json"


def build_summary() -> dict[str, object]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_contract": str(CONTRACT_PATH.relative_to(ROOT)),
        "schema_version": contract["schema_version"],
        "selected_run_id": contract["selected_run_id"],
        "selected_run": contract["selected_run"],
        "selected_epoch": contract["selected_epoch"],
        "source": contract["source"],
        "network_shape": {
            "input_size": contract["input_size"],
            "hidden_size": contract["hidden_size"],
            "output_size": 1,
        },
        "arithmetic": contract["arithmetic"],
        "quantization": contract["quantization"],
        "boundedness": contract["boundedness"],
        "usage": {
            "current_scope": "The committed SMT checks export the frozen arithmetic assumptions and use them for contract-side overflow and arithmetic-equivalence proofs.",
            "datapath_rule": "Any contract-side SMT encoding must use fixed-size bitvectors whose widths and overflow semantics match the frozen contract.",
            "overflow_rule": contract["arithmetic"]["overflow"],
            "sign_extension_rule": contract["arithmetic"]["sign_extension"],
            "boundedness_scope": contract["boundedness"]["scope"],
            "overflow_entrypoint": "python3 smt/contract/overflow/check_bounds.py",
            "equivalence_entrypoint": "python3 smt/contract/equivalence/check_equivalence.py",
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export frozen contract assumptions for SMT flows.")
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="Runtime build root for SMT assumptions snapshots.",
    )
    parser.add_argument(
        "--report-root",
        type=Path,
        default=DEFAULT_REPORT_ROOT,
        help="Runtime report root for SMT assumptions snapshots.",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="Optional run id for runtime artifact provenance mode.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Explicit JSON path for the exported assumption summary. Overrides provenance mode.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = build_summary()
    snapshot = None
    if args.output is None:
        snapshot = prepare_snapshot(
            build_root=args.build_root.resolve(),
            report_root=args.report_root.resolve(),
            run_id=args.run_id or build_run_id("smt", "contract-assumptions"),
            subpath="contract",
        )
        args.output = snapshot.report_run_dir / "assumptions.json"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if snapshot is not None:
        promote_snapshot(
            snapshot,
            source="smt_contract_assumptions",
            created_at_utc=str(summary["generated_at_utc"]),
            inputs={"contract": str(CONTRACT_PATH.relative_to(ROOT))},
            commands={"driver": "python3 smt/contract/export_assumptions.py"},
            tool_versions={},
            artifacts={},
            reports={"assumptions": str(args.output.resolve().relative_to(ROOT))},
        )

    print(f"wrote {args.output}")
    print(
        "arithmetic widths:"
        f" in={summary['arithmetic']['input_bits']}"
        f" hidden_product={summary['arithmetic']['hidden_product_bits']}"
        f" output_product={summary['arithmetic']['output_product_bits']}"
        f" acc={summary['arithmetic']['accumulator_bits']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
