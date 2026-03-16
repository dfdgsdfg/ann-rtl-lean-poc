from __future__ import annotations

import json
import re
import shutil
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = 1
RUN_PART_PATTERN = re.compile(r"[^A-Za-z0-9._-]+")


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def relative_to_root(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def _sanitize_part(value: str) -> str:
    sanitized = RUN_PART_PATTERN.sub("-", value.strip()).strip("-")
    return sanitized or "run"


def build_run_id(*parts: str) -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    suffix = "-".join(_sanitize_part(part) for part in parts if part)
    return f"{timestamp}-{suffix}" if suffix else timestamp


def _json_text(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def write_json(path: Path, payload: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    path.write_text(_json_text(payload), encoding="utf-8")


def replace_tree(src: Path, dst: Path) -> None:
    ensure_dir(dst.parent)
    with tempfile.TemporaryDirectory(dir=dst.parent, prefix=f".{dst.name}.") as tmpdir:
        temp_dst = Path(tmpdir) / dst.name
        shutil.copytree(src, temp_dst, symlinks=True)
        if dst.exists():
            shutil.rmtree(dst)
        temp_dst.replace(dst)


@dataclass(frozen=True)
class RuntimeSnapshot:
    run_id: str
    build_root: Path
    report_root: Path
    build_run_dir: Path
    build_canonical_dir: Path
    report_run_dir: Path
    report_canonical_dir: Path


def prepare_snapshot(
    *,
    build_root: Path,
    report_root: Path,
    run_id: str,
    subpath: str | Path = ".",
) -> RuntimeSnapshot:
    subdir = Path(subpath)
    build_run_dir = build_root / "runs" / run_id / subdir
    build_canonical_dir = build_root / "canonical" / subdir
    report_run_dir = report_root / "runs" / run_id / subdir
    report_canonical_dir = report_root / "canonical" / subdir
    for path in (build_run_dir, build_canonical_dir.parent, report_run_dir, report_canonical_dir.parent):
        ensure_dir(path)
    return RuntimeSnapshot(
        run_id=run_id,
        build_root=build_root,
        report_root=report_root,
        build_run_dir=build_run_dir,
        build_canonical_dir=build_canonical_dir,
        report_run_dir=report_run_dir,
        report_canonical_dir=report_canonical_dir,
    )


def build_manifest(
    *,
    snapshot_dir: Path,
    run_id: str,
    source: str,
    artifact_dir: Path,
    report_dir: Path,
    created_at_utc: str,
    inputs: dict[str, object] | None = None,
    commands: dict[str, object] | None = None,
    tool_versions: dict[str, object] | None = None,
    artifacts: dict[str, object] | None = None,
    reports: dict[str, object] | None = None,
    origin_run_id: str | None = None,
) -> dict[str, object]:
    manifest: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "source": source,
        "run_id": run_id,
        "artifact_dir": relative_to_root(artifact_dir),
        "report_dir": relative_to_root(report_dir),
        "created_at_utc": created_at_utc,
        "inputs": inputs or {},
        "commands": commands or {},
        "tool_versions": tool_versions or {},
        "artifacts": artifacts or {},
        "reports": reports or {},
    }
    if origin_run_id is not None:
        manifest["origin_run_id"] = origin_run_id
    write_json(snapshot_dir / "manifest.json", manifest)
    return manifest


def promote_snapshot(
    snapshot: RuntimeSnapshot,
    *,
    source: str,
    created_at_utc: str,
    inputs: dict[str, object] | None = None,
    commands: dict[str, object] | None = None,
    tool_versions: dict[str, object] | None = None,
    artifacts: dict[str, object] | None = None,
    reports: dict[str, object] | None = None,
) -> tuple[dict[str, object], dict[str, object]]:
    run_build_manifest = build_manifest(
        snapshot_dir=snapshot.build_run_dir,
        run_id=snapshot.run_id,
        source=source,
        artifact_dir=snapshot.build_run_dir,
        report_dir=snapshot.report_run_dir,
        created_at_utc=created_at_utc,
        inputs=inputs,
        commands=commands,
        tool_versions=tool_versions,
        artifacts=artifacts,
        reports=reports,
    )
    run_report_manifest = build_manifest(
        snapshot_dir=snapshot.report_run_dir,
        run_id=snapshot.run_id,
        source=source,
        artifact_dir=snapshot.build_run_dir,
        report_dir=snapshot.report_run_dir,
        created_at_utc=created_at_utc,
        inputs=inputs,
        commands=commands,
        tool_versions=tool_versions,
        artifacts=artifacts,
        reports=reports,
    )

    replace_tree(snapshot.build_run_dir, snapshot.build_canonical_dir)
    replace_tree(snapshot.report_run_dir, snapshot.report_canonical_dir)

    build_manifest(
        snapshot_dir=snapshot.build_canonical_dir,
        run_id=snapshot.run_id,
        source=source,
        artifact_dir=snapshot.build_canonical_dir,
        report_dir=snapshot.report_canonical_dir,
        created_at_utc=created_at_utc,
        inputs=inputs,
        commands=commands,
        tool_versions=tool_versions,
        artifacts=artifacts,
        reports=reports,
        origin_run_id=snapshot.run_id,
    )
    build_manifest(
        snapshot_dir=snapshot.report_canonical_dir,
        run_id=snapshot.run_id,
        source=source,
        artifact_dir=snapshot.build_canonical_dir,
        report_dir=snapshot.report_canonical_dir,
        created_at_utc=created_at_utc,
        inputs=inputs,
        commands=commands,
        tool_versions=tool_versions,
        artifacts=artifacts,
        reports=reports,
        origin_run_id=snapshot.run_id,
    )
    return run_build_manifest, run_report_manifest
