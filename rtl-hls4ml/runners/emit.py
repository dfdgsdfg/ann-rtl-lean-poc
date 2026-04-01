#!/usr/bin/env python3
"""Runner for the rtl-hls4ml branch: generate wrapper RTL from frozen contract."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

CANONICAL_SV_DIR = ROOT / "rtl-hls4ml" / "results" / "canonical" / "sv"
WRAPPER_GENERATOR = ROOT / "rtl-hls4ml" / "scripts" / "generate_wrapper.py"


def _load_wrapper_main():
    spec = importlib.util.spec_from_file_location("generate_wrapper", WRAPPER_GENERATOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or check rtl-hls4ml canonical artifacts.")
    parser.add_argument("--emit", action="store_true", help="Generate canonical SV files from frozen contract.")
    parser.add_argument("--check", action="store_true", help="Validate canonical SV files match frozen contract.")
    parser.add_argument("--build-root", type=Path, default=ROOT / "build" / "rtl-hls4ml")
    parser.add_argument("--report-root", type=Path, default=ROOT / "reports" / "rtl-hls4ml")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    wrapper_main = _load_wrapper_main()

    if args.check:
        return wrapper_main(["--check"])

    if args.emit:
        code = wrapper_main([])
        if code != 0:
            return code

        manifest = {
            "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "source": "rtl-hls4ml/scripts/generate_wrapper.py",
            "contract": "contract/results/canonical/weights.json",
            "branch": "rtl-hls4ml",
            "artifact_kind": "hls4ml_generated_full_core_rtl",
        }
        manifest_path = CANONICAL_SV_DIR / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {manifest_path}")
        return 0

    print("specify --emit or --check", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
