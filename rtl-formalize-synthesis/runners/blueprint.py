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
SV_DIR = DOMAIN_ROOT / "results" / "canonical" / "sv"
BLUEPRINT_DIR = DOMAIN_ROOT / "results" / "canonical" / "blueprint"
BUILD_DIR = ROOT / "build" / "rtl-formalize-synthesis" / "canonical" / "schematics"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate rtl-formalize-synthesis blueprint SVGs.")
    parser.add_argument("--yosys", default=shutil.which("yosys") or "yosys")
    parser.add_argument("--netlistsvg", default=shutil.which("netlistsvg") or "netlistsvg")
    return parser.parse_args(argv)


def run(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    for tool in (args.yosys, args.netlistsvg):
        if shutil.which(tool) is None:
            raise SystemExit(f"missing required tool: {tool}")

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    BLUEPRINT_DIR.mkdir(parents=True, exist_ok=True)

    wrapper_json = BUILD_DIR / "mlp_core.json"
    raw_json = BUILD_DIR / "sparkle_mlp_core.json"
    wrapper_svg = BLUEPRINT_DIR / "mlp_core.svg"
    raw_svg = BLUEPRINT_DIR / "sparkle_mlp_core.svg"

    run(
        [
            args.yosys,
            "-q",
            "-p",
            f"read_verilog -sv {SV_DIR / 'mlp_core.sv'} {SV_DIR / 'sparkle_mlp_core.sv'}; "
            f"hierarchy -check -top mlp_core; proc; opt; write_json {wrapper_json}",
        ]
    )
    run([args.netlistsvg, str(wrapper_json), "-o", str(wrapper_svg)])
    run(
        [
            args.yosys,
            "-q",
            "-p",
            f"read_verilog -sv {SV_DIR / 'sparkle_mlp_core.sv'}; "
            f"hierarchy -check -top TinyMLP_sparkleMlpCorePacked; proc; opt; write_json {raw_json}",
        ]
    )
    run([args.netlistsvg, str(raw_json), "-o", str(raw_svg)])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
