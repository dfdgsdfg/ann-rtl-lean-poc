from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from ann.src.artifacts import read_json, write_json
from ann.src.evaluate import (
    DEFAULT_DATASET_SEED,
    DEFAULT_INPUT_HIGH,
    DEFAULT_INPUT_LOW,
    DEFAULT_TRAIN_SIZE,
    DEFAULT_VAL_SIZE,
    evaluate_payload,
    load_evaluation_payload,
)
from ann.src.quantize import quantize_float_weights_payload
from ann.src.train import add_train_arguments, train
from contract.src.freeze import freeze_contract


def _default_quantized_output_path(source_path: Path) -> Path:
    if source_path.name == "weights_float_selected.json":
        return source_path.with_name("weights_quantized.rederived.json")
    if source_path.name == "weights_float.json":
        return source_path.with_name("weights_quantized_from_best_float.json")
    return source_path.with_name(f"{source_path.stem}.quantized.json")


def _print_json(payload: dict[str, object]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def _same_quantized_values(left: dict[str, object], right: dict[str, object]) -> bool:
    fields = ("w1", "b1", "w2", "b2", "training_seed", "dataset_version", "selected_epoch")
    return all(left.get(field) == right.get(field) for field in fields)


def cmd_train(args: argparse.Namespace) -> int:
    run_dir = train(args)
    print(f"wrote training artifacts to {run_dir}")
    if not args.skip_export:
        out_path = freeze_contract(run_dir)
        print(f"wrote {out_path}")
    return 0


def cmd_evaluate(args: argparse.Namespace) -> int:
    payload, kind, payload_path = load_evaluation_payload(
        run_dir=args.run_dir,
        weights_path=args.weights,
        artifact=args.artifact,
    )
    result = evaluate_payload(
        payload,
        kind=kind,
        seed=args.seed,
        train_size=args.train_size,
        val_size=args.val_size,
        input_low=args.input_low,
        input_high=args.input_high,
        split=args.split,
    )
    result["weights_path"] = str(payload_path)
    result["artifact"] = args.artifact if args.weights is None else "explicit-weights"
    if args.json:
        _print_json(result)
    else:
        print(f"weights: {payload_path}")
        print(f"kind: {result['weights_kind']}")
        print(f"split: {result['split']} ({result['example_count']} examples)")
        print(f"accuracy: {result['accuracy']:.4f}")
        print(f"loss: {result['loss']:.6f}")
    return 0


def cmd_quantize(args: argparse.Namespace) -> int:
    try:
        payload, kind, source_path = load_evaluation_payload(
            run_dir=args.run_dir,
            weights_path=args.weights,
            artifact=args.artifact,
            expected_kind="float",
        )
    except (TypeError, ValueError) as exc:
        if args.weights is not None:
            raise ValueError(
                "quantize expects a float-weight artifact; use --artifact best-float or --artifact selected-float"
            ) from exc
        raise
    if kind != "float":
        raise ValueError("quantize expects a float-weight artifact; use --artifact best-float or --artifact selected-float")

    quantized = quantize_float_weights_payload(payload)
    out_path = args.out if args.out is not None else _default_quantized_output_path(source_path)
    write_json(out_path, quantized)

    result: dict[str, object] = {
        "input_weights": str(source_path),
        "output_weights": str(out_path),
    }
    selected_quantized_path = source_path.with_name("weights_quantized.json")
    if source_path.name == "weights_float_selected.json" and selected_quantized_path.exists():
        result["matches_selected_quantized"] = _same_quantized_values(read_json(selected_quantized_path), quantized)

    if args.json:
        _print_json(result)
    else:
        print(f"wrote {out_path}")
        if "matches_selected_quantized" in result:
            print(f"matches selected quantized: {result['matches_selected_quantized']}")
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    out_path = freeze_contract(args.run_dir)
    print(f"wrote {out_path}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ANN domain CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    train_parser = subparsers.add_parser("train", help="Train the ANN and optionally refresh downstream artifacts")
    add_train_arguments(train_parser)
    train_parser.add_argument(
        "--skip-export",
        action="store_true",
        help="Do not refresh results/canonical or downstream generated artifacts after training",
    )
    train_parser.set_defaults(func=cmd_train)

    eval_parser = subparsers.add_parser("evaluate", help="Evaluate a float or quantized ANN artifact on the default dataset")
    eval_source = eval_parser.add_mutually_exclusive_group()
    eval_source.add_argument("--run-dir", type=Path, default=None, help="Run directory containing ANN artifacts")
    eval_source.add_argument("--weights", type=Path, default=None, help="Explicit weights JSON to evaluate")
    eval_parser.add_argument(
        "--artifact",
        choices=("quantized", "selected-float", "best-float"),
        default="quantized",
        help="Artifact to load when --run-dir is used or omitted",
    )
    eval_parser.add_argument("--seed", type=int, default=DEFAULT_DATASET_SEED)
    eval_parser.add_argument("--train-size", type=int, default=DEFAULT_TRAIN_SIZE)
    eval_parser.add_argument("--val-size", type=int, default=DEFAULT_VAL_SIZE)
    eval_parser.add_argument("--input-low", type=int, default=DEFAULT_INPUT_LOW)
    eval_parser.add_argument("--input-high", type=int, default=DEFAULT_INPUT_HIGH)
    eval_parser.add_argument("--split", choices=("train", "val", "all"), default="all")
    eval_parser.add_argument("--json", action="store_true", help="Print machine-readable JSON metrics")
    eval_parser.set_defaults(func=cmd_evaluate)

    quantize_parser = subparsers.add_parser("quantize", help="Quantize a float ANN artifact into an integer weights JSON")
    quantize_source = quantize_parser.add_mutually_exclusive_group()
    quantize_source.add_argument("--run-dir", type=Path, default=None, help="Run directory containing float artifacts")
    quantize_source.add_argument("--weights", type=Path, default=None, help="Explicit float weights JSON to quantize")
    quantize_parser.add_argument(
        "--artifact",
        choices=("selected-float", "best-float"),
        default="selected-float",
        help="Float artifact to use when --run-dir is used or omitted",
    )
    quantize_parser.add_argument("--out", type=Path, default=None, help="Output JSON path for the quantized weights")
    quantize_parser.add_argument("--json", action="store_true", help="Print machine-readable command output")
    quantize_parser.set_defaults(func=cmd_quantize)

    export_parser = subparsers.add_parser(
        "export",
        help="Promote an ANN run into ann/results/canonical, refresh contract/results/canonical, and regenerate downstream artifacts",
    )
    export_parser.add_argument("--run-dir", type=Path, default=None, help="Run directory containing weights_quantized.json")
    export_parser.set_defaults(func=cmd_export)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
