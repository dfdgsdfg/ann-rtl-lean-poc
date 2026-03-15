from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from contract.src.artifacts import (
        CONTRACT_WEIGHTS_PATH,
        SELECTED_RUN_PATH,
        json_text,
        read_json,
        relative_to_root,
        require_immutable_run_dir,
        resolve_metadata_path,
        write_text_files,
    )
    from contract.src.downstream_sync import expected_downstream_artifacts
    from contract.src.gen_vectors import expected_vector_artifacts
    from contract.src.schema import build_analysis_payload, validate_analysis_payload, validate_selected_run_metadata
else:
    from .artifacts import (
        CONTRACT_WEIGHTS_PATH,
        SELECTED_RUN_PATH,
        json_text,
        read_json,
        relative_to_root,
        require_immutable_run_dir,
        resolve_metadata_path,
        write_text_files,
    )
    from .downstream_sync import expected_downstream_artifacts
    from .gen_vectors import expected_vector_artifacts
    from .schema import build_analysis_payload, validate_analysis_payload, validate_selected_run_metadata


def resolve_selected_run_dir(run_dir: Path | None = None) -> Path:
    if run_dir is not None:
        resolved, _ = require_immutable_run_dir(resolve_metadata_path(run_dir))
        return resolved

    if SELECTED_RUN_PATH.exists():
        selected_meta = validate_selected_run_metadata(read_json(SELECTED_RUN_PATH))
        candidate_dir, selected_run_id = require_immutable_run_dir(resolve_metadata_path(selected_meta["selected_run"]))
        if selected_meta["selected_run_id"] != selected_run_id:
            raise ValueError(
                "selected run metadata does not match immutable run directory name: "
                f"{selected_meta['selected_run_id']} != {selected_run_id}"
            )
        if not candidate_dir.exists():
            raise FileNotFoundError(
                "selected run metadata points to a missing run directory: "
                f"{SELECTED_RUN_PATH} -> {candidate_dir}"
            )
        return candidate_dir

    raise FileNotFoundError(
        "missing selected ANN run metadata; pass --run-dir or refresh the canonical run selection first"
    )


def _selected_run_metadata_payload(
    selected_dir: Path,
    quantized_path: Path,
    contract_payload: dict[str, object],
) -> dict[str, object]:
    payload: dict[str, object] = {
        "selected_run_id": contract_payload["selected_run_id"],
        "selected_run": relative_to_root(selected_dir),
        "weights_quantized": relative_to_root(quantized_path),
        "contract_weights": relative_to_root(CONTRACT_WEIGHTS_PATH),
    }
    if "selected_epoch" in contract_payload:
        payload["selected_epoch"] = contract_payload["selected_epoch"]
    return payload


def freeze_contract(run_dir: Path | None = None) -> Path:
    selected_dir = resolve_selected_run_dir(run_dir)
    selected_dir, selected_run_id = require_immutable_run_dir(selected_dir)
    quantized_path = selected_dir / "weights_quantized.json"
    if not quantized_path.exists():
        raise FileNotFoundError(f"missing quantized weights at {quantized_path}")

    quantized_payload = read_json(quantized_path)
    analysis_payload = build_analysis_payload(
        quantized_payload,
        selected_run_id=selected_run_id,
        selected_run=relative_to_root(selected_dir),
    )
    selected_meta = _selected_run_metadata_payload(selected_dir, quantized_path, analysis_payload)
    pending_files: dict[Path, tuple[str, str]] = {
        CONTRACT_WEIGHTS_PATH: (json_text(analysis_payload), "utf-8"),
        SELECTED_RUN_PATH: (json_text(selected_meta), "utf-8"),
    }
    pending_files.update(
        {
            generated_path: (text, "utf-8")
            for generated_path, text in expected_downstream_artifacts(analysis_payload).items()
        }
    )
    pending_files.update(
        {
            generated_path: (text, "ascii")
            for generated_path, text in expected_vector_artifacts(analysis_payload).items()
        }
    )
    write_text_files(pending_files)
    validate_canonical_contract_bundle()
    return CONTRACT_WEIGHTS_PATH


def validate_canonical_contract_bundle() -> None:
    contract_payload = validate_analysis_payload(read_json(CONTRACT_WEIGHTS_PATH), label="contract result")
    selected_meta = validate_selected_run_metadata(read_json(SELECTED_RUN_PATH))

    contract_selected_dir, contract_selected_run_id = require_immutable_run_dir(
        resolve_metadata_path(contract_payload["selected_run"])
    )
    if contract_payload["selected_run_id"] != contract_selected_run_id:
        raise ValueError(
            "contract result selected_run_id does not match immutable run directory name: "
            f"{contract_payload['selected_run_id']} != {contract_selected_run_id}"
        )

    expected_selected_run = str(contract_payload["selected_run"])
    if selected_meta["selected_run"] != expected_selected_run:
        raise ValueError(
            "selected run metadata does not match contract result: "
            f"{selected_meta['selected_run']} != {expected_selected_run}"
        )
    if selected_meta["selected_run_id"] != contract_payload["selected_run_id"]:
        raise ValueError(
            "selected run metadata does not match contract selected_run_id: "
            f"{selected_meta['selected_run_id']} != {contract_payload['selected_run_id']}"
        )

    expected_contract_path = relative_to_root(CONTRACT_WEIGHTS_PATH)
    if selected_meta["contract_weights"] != expected_contract_path:
        raise ValueError(
            "selected run metadata does not point to the canonical contract weights: "
            f"{selected_meta['contract_weights']} != {expected_contract_path}"
        )
    if "selected_epoch" in contract_payload:
        expected_selected_epoch = contract_payload["selected_epoch"]
        if selected_meta.get("selected_epoch") != expected_selected_epoch:
            raise ValueError(
                "selected run metadata does not match contract selected epoch: "
                f"{selected_meta.get('selected_epoch')} != {expected_selected_epoch}"
            )

    quantized_path = resolve_metadata_path(selected_meta["weights_quantized"])
    if not quantized_path.exists():
        raise FileNotFoundError(f"missing recorded quantized weights at {quantized_path}")

    selected_dir, selected_run_id = require_immutable_run_dir(resolve_metadata_path(selected_meta["selected_run"]))
    if selected_run_id != selected_meta["selected_run_id"]:
        raise ValueError(
            "selected run metadata does not match immutable run directory name: "
            f"{selected_meta['selected_run_id']} != {selected_run_id}"
        )
    if not selected_dir.exists():
        raise FileNotFoundError(f"missing recorded selected run directory at {selected_dir}")
    if selected_dir != contract_selected_dir:
        raise ValueError(
            "contract result selected_run does not match selected metadata immutable directory: "
            f"{contract_selected_dir} != {selected_dir}"
        )

    expected_quantized_path = selected_dir / "weights_quantized.json"
    if quantized_path.resolve() != expected_quantized_path.resolve():
        raise ValueError(
            "selected run metadata does not point to the selected run quantized weights: "
            f"{quantized_path} != {expected_quantized_path}"
        )

    quantized_payload = build_analysis_payload(
        read_json(quantized_path),
        selected_run_id=selected_meta["selected_run_id"],
        selected_run=selected_meta["selected_run"],
        source=str(contract_payload["source"]),
    )
    if contract_payload != quantized_payload:
        raise ValueError("contract result payload does not match the selected quantized weights")

    for generated_path, expected_text in expected_downstream_artifacts(contract_payload).items():
        if not generated_path.exists():
            raise FileNotFoundError(f"missing generated contract artifact at {generated_path}")
        actual_text = generated_path.read_text(encoding="utf-8")
        if actual_text != expected_text:
            raise ValueError(f"generated contract artifact is out of sync: {generated_path}")

    for generated_path, expected_text in expected_vector_artifacts(contract_payload).items():
        if not generated_path.exists():
            raise FileNotFoundError(f"missing generated contract artifact at {generated_path}")
        actual_text = generated_path.read_text(encoding="ascii")
        if actual_text != expected_text:
            raise ValueError(f"generated contract artifact is out of sync: {generated_path}")


def validate_contract() -> None:
    validate_canonical_contract_bundle()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Freeze or validate the implementation contract")
    parser.add_argument("--run-dir", type=Path, default=None, help="Optional ANN run directory with weights_quantized.json")
    parser.add_argument("--check", action="store_true", help="Validate the current frozen contract without rewriting artifacts")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.check:
        validate_canonical_contract_bundle()
        print("contract validation passed")
        return

    out_path = freeze_contract(args.run_dir)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
