from __future__ import annotations

from datetime import datetime, timezone
import json
import os
import re
import stat
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ANN_RESULTS_DIR = ROOT / "ann" / "results"
RUNS_RESULTS_DIR = ANN_RESULTS_DIR / "runs"
SELECTED_RUN_PATH = ANN_RESULTS_DIR / "selected_run.json"
CONTRACT_RESULT_DIR = ROOT / "contract" / "result"
CONTRACT_WEIGHTS_PATH = CONTRACT_RESULT_DIR / "weights.json"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")


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
    return RUNS_RESULTS_DIR / build_default_run_id(seed)


def require_immutable_run_dir(path: Path) -> tuple[Path, str]:
    resolved = resolve_metadata_path(path)
    expected_parent = RUNS_RESULTS_DIR.resolve()
    if resolved.parent != expected_parent:
        raise ValueError(
            f"canonical ANN run directories must live under {RUNS_RESULTS_DIR}, got {resolved}"
        )

    run_id = resolved.name
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise ValueError(f"run id {run_id!r} contains unsupported characters")
    return resolved, run_id
