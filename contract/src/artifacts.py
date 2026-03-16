from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
import re
import stat
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ANN_RESULTS_DIR = ROOT / "ann" / "results"
ANN_RUNS_RESULTS_DIR = ANN_RESULTS_DIR / "runs"
ANN_CANONICAL_DIR = ANN_RESULTS_DIR / "canonical"
ANN_CANONICAL_MANIFEST_PATH = ANN_CANONICAL_DIR / "manifest.json"
CONTRACT_RESULTS_DIR = ROOT / "contract" / "results"
CONTRACT_RUNS_DIR = CONTRACT_RESULTS_DIR / "runs"
CONTRACT_CANONICAL_DIR = CONTRACT_RESULTS_DIR / "canonical"
CONTRACT_CANONICAL_MANIFEST_PATH = CONTRACT_CANONICAL_DIR / "manifest.json"
CONTRACT_WEIGHTS_PATH = CONTRACT_CANONICAL_DIR / "weights.json"
CONTRACT_MODEL_MD_PATH = CONTRACT_CANONICAL_DIR / "model.md"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")
ANN_SCHEMA_VERSION = 1
CONTRACT_SCHEMA_VERSION = 1


def ann_artifact_paths(base_dir: Path) -> dict[str, Path]:
    return {
        "weights_quantized": base_dir / "weights_quantized.json",
        "weights_float_selected": base_dir / "weights_float_selected.json",
        "weights_float": base_dir / "weights_float.json",
        "metrics": base_dir / "metrics.json",
        "training_summary": base_dir / "training_summary.md",
        "dataset_snapshot": base_dir / "dataset_snapshot.jsonl",
    }


def contract_artifact_paths(base_dir: Path) -> dict[str, Path]:
    return {
        "weights": base_dir / "weights.json",
        "model_md": base_dir / "model.md",
        "manifest": base_dir / "manifest.json",
    }


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def json_text(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def _target_mode(path: Path) -> int:
    if path.exists():
        return stat.S_IMODE(path.stat().st_mode)
    return 0o644


def write_text_files(files: dict[Path, tuple[str, str]]) -> None:
    pending: list[tuple[Path, Path]] = []
    try:
        for path, (text, encoding) in files.items():
            ensure_dir(path.parent)
            if path.exists() and path.read_text(encoding=encoding) == text:
                continue
            fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
            tmp_path = Path(tmp_name)
            try:
                with os.fdopen(fd, "w", encoding=encoding) as handle:
                    handle.write(text)
            except Exception:
                tmp_path.unlink(missing_ok=True)
                raise
            tmp_path.chmod(_target_mode(path))
            pending.append((tmp_path, path))

        for tmp_path, path in pending:
            tmp_path.replace(path)
    finally:
        for tmp_path, _ in pending:
            tmp_path.unlink(missing_ok=True)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    write_text_files({path: (json_text(payload), "utf-8")})


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative_to_root(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError as exc:
        raise ValueError(f"path {resolved} is outside repository root {ROOT}") from exc


def resolve_metadata_path(path_value: str | Path) -> Path:
    path = Path(path_value)
    resolved = path.resolve() if path.is_absolute() else (ROOT / path).resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError as exc:
        raise ValueError(f"metadata path {path_value!r} is outside repository root {ROOT}") from exc
    return resolved


def build_default_run_id(seed: int) -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{timestamp}-seed{seed}"


def default_run_dir(seed: int) -> Path:
    return ANN_RUNS_RESULTS_DIR / build_default_run_id(seed)


def require_immutable_run_dir(path: Path) -> tuple[Path, str]:
    resolved = resolve_metadata_path(path)
    expected_parent = ANN_RUNS_RESULTS_DIR.resolve()
    if resolved.parent != expected_parent:
        raise ValueError(
            f"canonical ANN run directories must live under {ANN_RUNS_RESULTS_DIR}, got {resolved}"
        )

    run_id = resolved.name
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise ValueError(f"run id {run_id!r} contains unsupported characters")
    return resolved, run_id


def _coerce_string(value: object, field: str, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{label} field '{field}' must be a non-empty string")
    return value


def _coerce_int(value: object, field: str, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{label} field '{field}' must be an integer")
    return value


def validate_ann_manifest(payload: dict[str, Any], *, label: str = "ANN results manifest") -> dict[str, object]:
    if not isinstance(payload, dict):
        raise TypeError(f"{label} must be a JSON object")

    normalized: dict[str, object] = {
        "schema_version": _coerce_int(payload.get("schema_version"), "schema_version", label),
        "source": _coerce_string(payload.get("source"), "source", label),
        "selected_run_id": _coerce_string(payload.get("selected_run_id"), "selected_run_id", label),
        "artifact_dir": _coerce_string(payload.get("artifact_dir"), "artifact_dir", label),
        "weights_quantized": _coerce_string(payload.get("weights_quantized"), "weights_quantized", label),
        "weights_float_selected": _coerce_string(payload.get("weights_float_selected"), "weights_float_selected", label),
        "weights_float": _coerce_string(payload.get("weights_float"), "weights_float", label),
        "metrics": _coerce_string(payload.get("metrics"), "metrics", label),
        "training_summary": _coerce_string(payload.get("training_summary"), "training_summary", label),
        "dataset_snapshot": _coerce_string(payload.get("dataset_snapshot"), "dataset_snapshot", label),
        "dataset_snapshot_sha256": _coerce_string(payload.get("dataset_snapshot_sha256"), "dataset_snapshot_sha256", label),
        "dataset_version": _coerce_string(payload.get("dataset_version"), "dataset_version", label),
        "training_seed": _coerce_int(payload.get("training_seed"), "training_seed", label),
        "selected_epoch": _coerce_int(payload.get("selected_epoch"), "selected_epoch", label),
    }
    if int(normalized["schema_version"]) != ANN_SCHEMA_VERSION:
        raise ValueError(f"{label} field 'schema_version' must be {ANN_SCHEMA_VERSION}")
    if "origin_run_path" in payload:
        normalized["origin_run_path"] = _coerce_string(payload.get("origin_run_path"), "origin_run_path", label)
    if "origin_run_id" in payload:
        normalized["origin_run_id"] = _coerce_string(payload.get("origin_run_id"), "origin_run_id", label)
    return normalized


def validate_contract_manifest(payload: dict[str, Any], *, label: str = "contract results manifest") -> dict[str, object]:
    if not isinstance(payload, dict):
        raise TypeError(f"{label} must be a JSON object")

    normalized: dict[str, object] = {
        "schema_version": _coerce_int(payload.get("schema_version"), "schema_version", label),
        "source": _coerce_string(payload.get("source"), "source", label),
        "selected_run_id": _coerce_string(payload.get("selected_run_id"), "selected_run_id", label),
        "artifact_dir": _coerce_string(payload.get("artifact_dir"), "artifact_dir", label),
        "weights": _coerce_string(payload.get("weights"), "weights", label),
        "model_md": _coerce_string(payload.get("model_md"), "model_md", label),
        "source_ann_manifest": _coerce_string(payload.get("source_ann_manifest"), "source_ann_manifest", label),
        "source_ann_artifact_dir": _coerce_string(payload.get("source_ann_artifact_dir"), "source_ann_artifact_dir", label),
        "source_ann_weights": _coerce_string(payload.get("source_ann_weights"), "source_ann_weights", label),
        "dataset_snapshot": _coerce_string(payload.get("dataset_snapshot"), "dataset_snapshot", label),
        "dataset_snapshot_sha256": _coerce_string(payload.get("dataset_snapshot_sha256"), "dataset_snapshot_sha256", label),
    }
    if int(normalized["schema_version"]) != CONTRACT_SCHEMA_VERSION:
        raise ValueError(f"{label} field 'schema_version' must be {CONTRACT_SCHEMA_VERSION}")
    if "selected_epoch" in payload:
        normalized["selected_epoch"] = _coerce_int(payload.get("selected_epoch"), "selected_epoch", label)
    if "origin_run_path" in payload:
        normalized["origin_run_path"] = _coerce_string(payload.get("origin_run_path"), "origin_run_path", label)
    return normalized
