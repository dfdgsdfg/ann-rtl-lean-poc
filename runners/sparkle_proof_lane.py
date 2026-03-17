from __future__ import annotations

import os
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORMALIZE_SMT_DIR = ROOT / "formalize-smt"
SPARKLE_PROOF_CONFIG = ROOT / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ProofConfig.lean"
SUPPORTED_PROOF_LANES = {"vanilla", "smt"}
PROOF_LANE_PATTERN = re.compile(r'^def selectedProofLane : String := "([^"]+)"$', re.MULTILINE)


def load_selected_sparkle_proof_lane(root: Path = ROOT) -> str:
    config_path = root / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ProofConfig.lean"
    match = PROOF_LANE_PATTERN.search(config_path.read_text(encoding="utf-8"))
    if match is None:
        raise RuntimeError(f"could not determine selected Sparkle proof lane from {config_path}")
    proof_lane = match.group(1)
    if proof_lane not in SUPPORTED_PROOF_LANES:
        raise RuntimeError(f"unsupported Sparkle proof lane: {proof_lane}")
    return proof_lane


def _formalize_smt_lean_paths(root: Path = ROOT) -> list[Path]:
    formalize_smt_dir = root / "formalize-smt"
    paths = [formalize_smt_dir / ".lake" / "build" / "lib" / "lean"]
    packages_dir = formalize_smt_dir / ".lake" / "packages"
    if packages_dir.exists():
        for package_dir in sorted(packages_dir.iterdir()):
            lib_path = package_dir / ".lake" / "build" / "lib" / "lean"
            if lib_path.exists():
                paths.append(lib_path)
    return paths


def _sparkle_overlay_root(root: Path = ROOT) -> Path:
    return root / "rtl-formalize-synthesis" / ".lake" / "build" / "lib" / "lean"


def materialize_formalize_smt_overlay(root: Path = ROOT) -> None:
    ensure_formalize_smt_ready(root)
    overlay_root = _sparkle_overlay_root(root)
    overlay_root.mkdir(parents=True, exist_ok=True)
    for source_root in _formalize_smt_lean_paths(root):
        for source in source_root.iterdir():
            target = overlay_root / source.name
            if target.exists() or target.is_symlink():
                if target.is_symlink() and target.resolve() == source.resolve():
                    continue
                raise RuntimeError(f"cannot overlay SMT Lean artifact onto existing path: {target}")
            target.symlink_to(source, target_is_directory=source.is_dir())


def ensure_formalize_smt_ready(root: Path = ROOT) -> None:
    missing = [path for path in _formalize_smt_lean_paths(root) if not path.exists()]
    if missing:
        joined = ", ".join(str(path) for path in missing)
        raise RuntimeError(
            "formalize-smt build artifacts are missing; run `cd formalize-smt && lake build` first "
            f"(missing: {joined})"
        )


def build_sparkle_proof_lane_env(
    *,
    root: Path = ROOT,
    proof_lane: str | None = None,
    base_env: dict[str, str] | None = None,
) -> dict[str, str]:
    selected_lane = proof_lane or load_selected_sparkle_proof_lane(root)
    env = dict(os.environ if base_env is None else base_env)
    if selected_lane != "smt":
        return env

    materialize_formalize_smt_overlay(root)
    return env
