from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from runners.sparkle_proof_lane import build_sparkle_proof_lane_env, load_selected_sparkle_proof_lane


DOMAIN_ROOT = ROOT / "rtl-formalize-synthesis"
FORMALIZE_SMT_ROOT = ROOT / "formalize-smt"
PREPARE_SCRIPT = DOMAIN_ROOT / "scripts" / "prepare_sparkle.sh"
CONFIGURE_PROOF_LANE_SCRIPT = DOMAIN_ROOT / "scripts" / "configure_proof_lane.py"
RAW_ARTIFACT = DOMAIN_ROOT / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv"
WRAPPER_ARTIFACT = DOMAIN_ROOT / "results" / "canonical" / "sv" / "mlp_core.sv"
VERIFICATION_MANIFEST = DOMAIN_ROOT / "results" / "canonical" / "verification_manifest.json"
REFRESH_SCRIPT = DOMAIN_ROOT / "scripts" / "refresh_verification_manifest.py"
WRAPPER_SCRIPT = DOMAIN_ROOT / "scripts" / "generate_wrapper.py"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Emit rtl-formalize-synthesis canonical artifacts.")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--emit", action="store_true")
    parser.add_argument("--proof-lane", choices=("vanilla", "smt"))
    parser.add_argument("--lake", default=shutil.which("lake") or "lake")
    parser.add_argument("--git", default=shutil.which("git") or "git")
    return parser.parse_args(argv)


def run(command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    result = subprocess.run(command, cwd=cwd or ROOT, env=env, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    mode_prepare_only = args.prepare_only
    mode_build_only = args.build_only
    mode_emit = args.emit or (not mode_prepare_only and not mode_build_only)

    if shutil.which(args.git) is None:
        raise SystemExit(f"missing required tool: {args.git}")
    if args.proof_lane is not None:
        run(["python3", str(CONFIGURE_PROOF_LANE_SCRIPT), "--proof-lane", args.proof_lane])
    selected_proof_lane = args.proof_lane or load_selected_sparkle_proof_lane(ROOT)
    if selected_proof_lane == "smt":
        run([args.lake, "build"], cwd=FORMALIZE_SMT_ROOT)
    proof_lane_env = build_sparkle_proof_lane_env(root=ROOT, proof_lane=selected_proof_lane)
    run([str(PREPARE_SCRIPT)])

    if mode_prepare_only:
        return 0
    if shutil.which(args.lake) is None:
        raise SystemExit(f"missing required tool: {args.lake}")
    if mode_build_only:
        run([args.lake, "build", "MlpCoreSparkle"], cwd=DOMAIN_ROOT, env=proof_lane_env)
        return 0

    run([args.lake, "build", "MlpCoreSparkle", "MlpCoreSparkle.Emit"], cwd=DOMAIN_ROOT, env=proof_lane_env)
    run(["python3", str(REFRESH_SCRIPT), "--manifest", str(VERIFICATION_MANIFEST)], env=proof_lane_env)
    run(
        [
            "python3",
            str(WRAPPER_SCRIPT),
            "--raw",
            str(RAW_ARTIFACT),
            "--wrapper",
            str(WRAPPER_ARTIFACT),
            "--subset-manifest",
            str(VERIFICATION_MANIFEST),
        ]
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
