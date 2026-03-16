from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from contract.src.artifacts import ROOT, json_text, write_text_files


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def relative(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def timestamp_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    write_text_files({path: (text, encoding)})


def write_json(path: Path, payload: dict[str, Any]) -> None:
    write_text(path, json_text(payload), encoding="utf-8")


def tool_exists(tool: str) -> bool:
    return Path(tool).exists() or shutil.which(tool) is not None


def command_text(command: list[str]) -> str:
    return shlex.join(command)


def run_command(
    command: list[str],
    *,
    cwd: Path = ROOT,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env is not None:
        merged_env.update(env)
    return subprocess.run(
        command,
        cwd=cwd,
        env=merged_env,
        text=True,
        capture_output=True,
        check=False,
    )


def first_output_line(proc: subprocess.CompletedProcess[str]) -> str:
    text = (proc.stdout + proc.stderr).strip()
    return text.splitlines()[0].strip() if text else "unknown"


def tool_version(commands: list[list[str]], fallback: str = "unknown", *, cwd: Path = ROOT) -> str:
    for command in commands:
        proc = run_command(command, cwd=cwd)
        if proc.returncode == 0 and (proc.stdout or proc.stderr):
            return first_output_line(proc)
    return fallback


def combine_results(results: list[str]) -> str:
    if any(result == "error" for result in results):
        return "error"
    if any(result == "fail" for result in results):
        return "fail"
    if results and all(result == "skip" for result in results):
        return "skip"
    return "pass"
