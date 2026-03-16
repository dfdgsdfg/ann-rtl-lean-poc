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


DOMAIN_ROOT = ROOT / "rtl-formalize-synthesis"
PREPARE_SCRIPT = DOMAIN_ROOT / "scripts" / "prepare_sparkle.sh"
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
    parser.add_argument("--lake", default=shutil.which("lake") or "lake")
    parser.add_argument("--git", default=shutil.which("git") or "git")
    return parser.parse_args(argv)


def run(command: list[str], *, cwd: Path | None = None) -> None:
    result = subprocess.run(command, cwd=cwd or ROOT, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    mode_prepare_only = args.prepare_only
    mode_build_only = args.build_only
    mode_emit = args.emit or (not mode_prepare_only and not mode_build_only)

    if shutil.which(args.git) is None:
        raise SystemExit(f"missing required tool: {args.git}")
    run([str(PREPARE_SCRIPT)])

    if mode_prepare_only:
        return 0
    if shutil.which(args.lake) is None:
        raise SystemExit(f"missing required tool: {args.lake}")
    if mode_build_only:
        run([args.lake, "build", "MlpCoreSparkle"], cwd=DOMAIN_ROOT)
        return 0

    run([args.lake, "build", "MlpCoreSparkle", "MlpCoreSparkle.Emit"], cwd=DOMAIN_ROOT)
    run(["python3", str(REFRESH_SCRIPT), "--manifest", str(VERIFICATION_MANIFEST)])
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
