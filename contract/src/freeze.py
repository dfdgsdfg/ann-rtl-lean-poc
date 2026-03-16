from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from contract.src.artifacts import (
        ANN_CANONICAL_DIR,
        ANN_CANONICAL_MANIFEST_PATH,
        CONTRACT_CANONICAL_DIR,
        CONTRACT_CANONICAL_MANIFEST_PATH,
        CONTRACT_RUNS_DIR,
        CONTRACT_WEIGHTS_PATH,
        ann_artifact_paths,
        contract_artifact_paths,
        file_sha256,
        json_text,
        read_json,
        relative_to_root,
        require_immutable_run_dir,
        resolve_metadata_path,
        validate_ann_manifest,
        validate_contract_manifest,
        write_text_files,
    )
    from contract.src.downstream_sync import expected_downstream_artifacts, render_model_doc_text
    from contract.src.gen_vectors import expected_vector_artifacts
    from contract.src.schema import build_analysis_payload, validate_analysis_payload
else:
    from .artifacts import (
        ANN_CANONICAL_DIR,
        ANN_CANONICAL_MANIFEST_PATH,
        CONTRACT_CANONICAL_DIR,
        CONTRACT_CANONICAL_MANIFEST_PATH,
        CONTRACT_RUNS_DIR,
        CONTRACT_WEIGHTS_PATH,
        ann_artifact_paths,
        contract_artifact_paths,
        file_sha256,
        json_text,
        read_json,
        relative_to_root,
        require_immutable_run_dir,
        resolve_metadata_path,
        validate_ann_manifest,
        validate_contract_manifest,
        write_text_files,
    )
    from .downstream_sync import expected_downstream_artifacts, render_model_doc_text
    from .gen_vectors import expected_vector_artifacts
    from .schema import build_analysis_payload, validate_analysis_payload


def _require_ann_artifacts(base_dir: Path) -> dict[str, Path]:
    paths = ann_artifact_paths(base_dir)
    for label, path in paths.items():
        if not path.exists():
            raise FileNotFoundError(f"missing ANN artifact {label} at {path}")
    return paths


def _build_ann_manifest(
    *,
    run_id: str,
    artifact_dir: Path,
    quantized_payload: dict[str, object],
    dataset_snapshot_sha256: str,
    origin_run_path: Path | None = None,
) -> dict[str, object]:
    paths = ann_artifact_paths(artifact_dir)
    manifest: dict[str, object] = {
        "schema_version": 1,
        "source": "ann_results_snapshot",
        "selected_run_id": run_id,
        "artifact_dir": relative_to_root(artifact_dir),
        "weights_quantized": relative_to_root(paths["weights_quantized"]),
        "weights_float_selected": relative_to_root(paths["weights_float_selected"]),
        "weights_float": relative_to_root(paths["weights_float"]),
        "metrics": relative_to_root(paths["metrics"]),
        "training_summary": relative_to_root(paths["training_summary"]),
        "dataset_snapshot": relative_to_root(paths["dataset_snapshot"]),
        "dataset_snapshot_sha256": dataset_snapshot_sha256,
        "dataset_version": quantized_payload["dataset_version"],
        "training_seed": quantized_payload["training_seed"],
        "selected_epoch": quantized_payload["selected_epoch"],
    }
    if origin_run_path is not None:
        manifest["origin_run_id"] = origin_run_path.name
        manifest["origin_run_path"] = relative_to_root(origin_run_path)
    return validate_ann_manifest(manifest)


def _build_contract_manifest(
    *,
    artifact_dir: Path,
    contract_payload: dict[str, object],
    ann_manifest: dict[str, object],
    origin_run_path: Path | None = None,
) -> dict[str, object]:
    paths = contract_artifact_paths(artifact_dir)
    manifest: dict[str, object] = {
        "schema_version": 1,
        "source": "contract_results_snapshot",
        "selected_run_id": contract_payload["selected_run_id"],
        "artifact_dir": relative_to_root(artifact_dir),
        "weights": relative_to_root(paths["weights"]),
        "model_md": relative_to_root(paths["model_md"]),
        "source_ann_manifest": relative_to_root(ANN_CANONICAL_MANIFEST_PATH),
        "source_ann_artifact_dir": ann_manifest["artifact_dir"],
        "source_ann_weights": ann_manifest["weights_quantized"],
        "dataset_snapshot": contract_payload["dataset_snapshot"],
        "dataset_snapshot_sha256": contract_payload["dataset_snapshot_sha256"],
    }
    if "selected_epoch" in contract_payload:
        manifest["selected_epoch"] = contract_payload["selected_epoch"]
    if origin_run_path is not None:
        manifest["origin_run_path"] = relative_to_root(origin_run_path)
    return validate_contract_manifest(manifest)


def _rewrite_training_summary_for_canonical(source_dir: Path) -> str:
    text = (source_dir / "training_summary.md").read_text(encoding="utf-8")
    return text.replace(relative_to_root(source_dir), relative_to_root(ANN_CANONICAL_DIR))


def _canonical_ann_pending_files(run_dir: Path) -> tuple[dict[str, object], dict[str, object], dict[Path, tuple[str, str]]]:
    source_dir, run_id = require_immutable_run_dir(resolve_metadata_path(run_dir))
    if not source_dir.exists():
        raise FileNotFoundError(f"missing ANN run directory at {source_dir}")
    source_paths = _require_ann_artifacts(source_dir)
    quantized_payload = read_json(source_paths["weights_quantized"])
    dataset_snapshot_sha256 = file_sha256(source_paths["dataset_snapshot"])
    manifest = _build_ann_manifest(
        run_id=run_id,
        artifact_dir=ANN_CANONICAL_DIR,
        quantized_payload=quantized_payload,
        dataset_snapshot_sha256=dataset_snapshot_sha256,
        origin_run_path=source_dir,
    )

    target_paths = ann_artifact_paths(ANN_CANONICAL_DIR)
    pending: dict[Path, tuple[str, str]] = {
        target_paths["weights_quantized"]: (source_paths["weights_quantized"].read_text(encoding="utf-8"), "utf-8"),
        target_paths["weights_float_selected"]: (source_paths["weights_float_selected"].read_text(encoding="utf-8"), "utf-8"),
        target_paths["weights_float"]: (source_paths["weights_float"].read_text(encoding="utf-8"), "utf-8"),
        target_paths["metrics"]: (source_paths["metrics"].read_text(encoding="utf-8"), "utf-8"),
        target_paths["training_summary"]: (_rewrite_training_summary_for_canonical(source_dir), "utf-8"),
        target_paths["dataset_snapshot"]: (source_paths["dataset_snapshot"].read_text(encoding="utf-8"), "utf-8"),
        ANN_CANONICAL_MANIFEST_PATH: (json_text(manifest), "utf-8"),
    }
    return manifest, quantized_payload, pending


def _load_ann_canonical_manifest() -> tuple[dict[str, object], dict[str, Path]]:
    if not ANN_CANONICAL_MANIFEST_PATH.exists():
        raise FileNotFoundError(
            "missing ANN canonical manifest; pass --run-dir or refresh ann/results/canonical first"
        )

    manifest = validate_ann_manifest(read_json(ANN_CANONICAL_MANIFEST_PATH), label="ANN canonical manifest")
    artifact_dir = resolve_metadata_path(manifest["artifact_dir"])
    if artifact_dir.resolve() != ANN_CANONICAL_DIR.resolve():
        raise ValueError(
            "ANN canonical manifest does not point to ann/results/canonical: "
            f"{artifact_dir} != {ANN_CANONICAL_DIR}"
        )
    paths = _require_ann_artifacts(artifact_dir)

    expected_paths = ann_artifact_paths(ANN_CANONICAL_DIR)
    for key, expected_path in expected_paths.items():
        if resolve_metadata_path(manifest[key]).resolve() != expected_path.resolve():
            raise ValueError(
                f"ANN canonical manifest field '{key}' does not point to the canonical artifact: "
                f"{manifest[key]} != {relative_to_root(expected_path)}"
            )

    dataset_snapshot_sha256 = file_sha256(paths["dataset_snapshot"])
    if dataset_snapshot_sha256 != manifest["dataset_snapshot_sha256"]:
        raise ValueError(
            "ANN canonical manifest dataset snapshot hash does not match the canonical snapshot: "
            f"{manifest['dataset_snapshot_sha256']} != {dataset_snapshot_sha256}"
        )

    quantized_payload = read_json(paths["weights_quantized"])
    if quantized_payload["training_seed"] != manifest["training_seed"]:
        raise ValueError(
            "ANN canonical manifest training_seed does not match canonical weights_quantized.json: "
            f"{manifest['training_seed']} != {quantized_payload['training_seed']}"
        )
    if quantized_payload["dataset_version"] != manifest["dataset_version"]:
        raise ValueError(
            "ANN canonical manifest dataset_version does not match canonical weights_quantized.json: "
            f"{manifest['dataset_version']} != {quantized_payload['dataset_version']}"
        )
    if quantized_payload["selected_epoch"] != manifest["selected_epoch"]:
        raise ValueError(
            "ANN canonical manifest selected_epoch does not match canonical weights_quantized.json: "
            f"{manifest['selected_epoch']} != {quantized_payload['selected_epoch']}"
        )
    return manifest, paths


def freeze_contract(run_dir: Path | None = None) -> Path:
    ann_manifest_updates: dict[Path, tuple[str, str]] = {}
    origin_run_path: Path | None = None
    quantized_payload: dict[str, object]
    if run_dir is not None:
        origin_run_path = resolve_metadata_path(run_dir)
        ann_manifest, quantized_payload, ann_manifest_updates = _canonical_ann_pending_files(origin_run_path)
    else:
        ann_manifest, _ = _load_ann_canonical_manifest()
        quantized_payload = read_json(resolve_metadata_path(ann_manifest["weights_quantized"]))
    analysis_payload = build_analysis_payload(
        quantized_payload,
        selected_run_id=str(ann_manifest["selected_run_id"]),
        selected_run=str(ann_manifest["artifact_dir"]),
        dataset_snapshot=str(ann_manifest["dataset_snapshot"]),
        dataset_snapshot_sha256=str(ann_manifest["dataset_snapshot_sha256"]),
    )

    contract_run_dir = CONTRACT_RUNS_DIR / str(ann_manifest["selected_run_id"])
    run_paths = contract_artifact_paths(contract_run_dir)
    canonical_paths = contract_artifact_paths(CONTRACT_CANONICAL_DIR)
    run_manifest = _build_contract_manifest(
        artifact_dir=contract_run_dir,
        contract_payload=analysis_payload,
        ann_manifest=ann_manifest,
        origin_run_path=origin_run_path if run_dir is not None else None,
    )
    canonical_manifest = _build_contract_manifest(
        artifact_dir=CONTRACT_CANONICAL_DIR,
        contract_payload=analysis_payload,
        ann_manifest=ann_manifest,
        origin_run_path=origin_run_path if run_dir is not None else None,
    )
    model_doc_text = render_model_doc_text(analysis_payload)

    pending_files = dict(ann_manifest_updates)
    pending_files.update(
        {
            run_paths["weights"]: (json_text(analysis_payload), "utf-8"),
            run_paths["model_md"]: (model_doc_text, "utf-8"),
            run_paths["manifest"]: (json_text(run_manifest), "utf-8"),
            canonical_paths["weights"]: (json_text(analysis_payload), "utf-8"),
            canonical_paths["model_md"]: (model_doc_text, "utf-8"),
            canonical_paths["manifest"]: (json_text(canonical_manifest), "utf-8"),
        }
    )
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
    ann_manifest, ann_paths = _load_ann_canonical_manifest()
    contract_payload = validate_analysis_payload(read_json(CONTRACT_WEIGHTS_PATH), label="contract canonical weights")
    contract_manifest = validate_contract_manifest(
        read_json(CONTRACT_CANONICAL_MANIFEST_PATH),
        label="contract canonical manifest",
    )

    if resolve_metadata_path(contract_manifest["artifact_dir"]).resolve() != CONTRACT_CANONICAL_DIR.resolve():
        raise ValueError(
            "contract canonical manifest does not point to contract/results/canonical: "
            f"{contract_manifest['artifact_dir']} != {relative_to_root(CONTRACT_CANONICAL_DIR)}"
        )

    expected_contract_paths = contract_artifact_paths(CONTRACT_CANONICAL_DIR)
    for key in ("weights", "model_md"):
        expected_path = expected_contract_paths[key]
        if resolve_metadata_path(contract_manifest[key]).resolve() != expected_path.resolve():
            raise ValueError(
                f"contract canonical manifest field '{key}' does not point to the canonical artifact: "
                f"{contract_manifest[key]} != {relative_to_root(expected_path)}"
            )

    if contract_manifest["selected_run_id"] != contract_payload["selected_run_id"]:
        raise ValueError(
            "contract canonical manifest selected_run_id does not match contract weights: "
            f"{contract_manifest['selected_run_id']} != {contract_payload['selected_run_id']}"
        )
    if contract_manifest["source_ann_manifest"] != relative_to_root(ANN_CANONICAL_MANIFEST_PATH):
        raise ValueError(
            "contract canonical manifest does not point to the ANN canonical manifest: "
            f"{contract_manifest['source_ann_manifest']} != {relative_to_root(ANN_CANONICAL_MANIFEST_PATH)}"
        )
    if contract_manifest["source_ann_artifact_dir"] != ann_manifest["artifact_dir"]:
        raise ValueError(
            "contract canonical manifest does not match the ANN canonical artifact dir: "
            f"{contract_manifest['source_ann_artifact_dir']} != {ann_manifest['artifact_dir']}"
        )
    if contract_manifest["source_ann_weights"] != ann_manifest["weights_quantized"]:
        raise ValueError(
            "contract canonical manifest does not match the ANN canonical quantized weights path: "
            f"{contract_manifest['source_ann_weights']} != {ann_manifest['weights_quantized']}"
        )
    if contract_manifest["dataset_snapshot"] != ann_manifest["dataset_snapshot"]:
        raise ValueError(
            "contract canonical manifest does not match the ANN canonical dataset snapshot: "
            f"{contract_manifest['dataset_snapshot']} != {ann_manifest['dataset_snapshot']}"
        )
    if contract_manifest["dataset_snapshot_sha256"] != ann_manifest["dataset_snapshot_sha256"]:
        raise ValueError(
            "contract canonical manifest does not match the ANN canonical dataset snapshot hash: "
            f"{contract_manifest['dataset_snapshot_sha256']} != {ann_manifest['dataset_snapshot_sha256']}"
        )

    if contract_payload["selected_run_id"] != ann_manifest["selected_run_id"]:
        raise ValueError(
            "contract canonical weights selected_run_id does not match the ANN canonical run id: "
            f"{contract_payload['selected_run_id']} != {ann_manifest['selected_run_id']}"
        )
    if contract_payload["selected_run"] != ann_manifest["artifact_dir"]:
        raise ValueError(
            "contract canonical weights selected_run does not match the ANN canonical artifact dir: "
            f"{contract_payload['selected_run']} != {ann_manifest['artifact_dir']}"
        )
    if contract_payload["dataset_snapshot"] != ann_manifest["dataset_snapshot"]:
        raise ValueError(
            "contract canonical weights dataset_snapshot does not match the ANN canonical snapshot: "
            f"{contract_payload['dataset_snapshot']} != {ann_manifest['dataset_snapshot']}"
        )
    if contract_payload["dataset_snapshot_sha256"] != ann_manifest["dataset_snapshot_sha256"]:
        raise ValueError(
            "contract canonical weights dataset snapshot hash does not match the ANN canonical snapshot hash: "
            f"{contract_payload['dataset_snapshot_sha256']} != {ann_manifest['dataset_snapshot_sha256']}"
        )

    rebuilt_payload = build_analysis_payload(
        read_json(ann_paths["weights_quantized"]),
        selected_run_id=str(ann_manifest["selected_run_id"]),
        selected_run=str(ann_manifest["artifact_dir"]),
        dataset_snapshot=str(ann_manifest["dataset_snapshot"]),
        dataset_snapshot_sha256=str(ann_manifest["dataset_snapshot_sha256"]),
        source=str(contract_payload["source"]),
    )
    if rebuilt_payload != contract_payload:
        raise ValueError("contract canonical weights do not match the ANN canonical quantized weights")

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
    parser.add_argument(
        "--run-dir",
        type=Path,
        default=None,
        help="Optional ANN run directory under ann/results/runs/<run_id> to promote into canonical results",
    )
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
