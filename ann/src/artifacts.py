from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ANN_RESULTS_DIR = ROOT / "ann" / "results"
LATEST_RESULTS_DIR = ANN_RESULTS_DIR / "latest"
SELECTED_RUN_PATH = ANN_RESULTS_DIR / "selected_run.json"
CONTRACT_RESULT_DIR = ROOT / "contract" / "result"
CONTRACT_WEIGHTS_PATH = CONTRACT_RESULT_DIR / "weights.json"


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def relative_to_root(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError as exc:
        raise ValueError(f"path {resolved} is outside repository root {ROOT}") from exc


def display_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def require_repo_path(path: Path) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError as exc:
        raise ValueError(f"path {resolved} is outside repository root {ROOT}") from exc
    return resolved


def resolve_metadata_path(path_value: str | Path) -> Path:
    path = Path(path_value)
    resolved = path.resolve() if path.is_absolute() else (ROOT / path).resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError as exc:
        raise ValueError(f"metadata path {path_value!r} is outside repository root {ROOT}") from exc
    return resolved
