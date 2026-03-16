from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))


SV_DIR = ROOT / "rtl-synthesis" / "results" / "canonical" / "sv"
BLUEPRINT_DIR = ROOT / "rtl-synthesis" / "results" / "canonical" / "blueprint"
BUILD_DIR = ROOT / "build" / "rtl-synthesis" / "canonical" / "schematics"
BASELINE_BLUEPRINT_DIR = ROOT / "rtl" / "results" / "canonical" / "blueprint"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate rtl-synthesis blueprint SVGs.")
    parser.add_argument("--yosys", default=shutil.which("yosys") or "yosys")
    parser.add_argument("--netlistsvg", default=shutil.which("netlistsvg") or "netlistsvg")
    return parser.parse_args(argv)


def run(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def ensure_symlink(name: str) -> None:
    BLUEPRINT_DIR.mkdir(parents=True, exist_ok=True)
    link_path = BLUEPRINT_DIR / name
    target = os.path.relpath(BASELINE_BLUEPRINT_DIR / name, BLUEPRINT_DIR)
    if link_path.is_symlink() or link_path.exists():
        link_path.unlink()
    link_path.symlink_to(target)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    for tool in (args.yosys, args.netlistsvg):
        if shutil.which(tool) is None:
            raise SystemExit(f"missing required tool: {tool}")

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    BLUEPRINT_DIR.mkdir(parents=True, exist_ok=True)
    for name in ("mac_unit.svg", "relu_unit.svg", "weight_rom.svg"):
        ensure_symlink(name)

    mlp_json = BUILD_DIR / "mlp_core.json"
    controller_json = BUILD_DIR / "controller.json"
    core_json = BUILD_DIR / "controller_spot_core.json"
    run(
        [
            args.yosys,
            "-q",
            "-p",
            "read_verilog -sv "
            f"{SV_DIR / 'mac_unit.sv'} {SV_DIR / 'relu_unit.sv'} {SV_DIR / 'controller.sv'} "
            f"{SV_DIR / 'controller_spot_compat.sv'} {SV_DIR / 'controller_spot_core.sv'} "
            f"{SV_DIR / 'weight_rom.sv'} {SV_DIR / 'mlp_core.sv'}; "
            f"hierarchy -check -top mlp_core; proc; opt; write_json {mlp_json}",
        ]
    )
    run([args.netlistsvg, str(mlp_json), "-o", str(BLUEPRINT_DIR / "mlp_core.svg")])
    run(
        [
            args.yosys,
            "-q",
            "-p",
            f"read_verilog -sv {SV_DIR / 'controller.sv'} {SV_DIR / 'controller_spot_compat.sv'} {SV_DIR / 'controller_spot_core.sv'}; "
            f"hierarchy -check -top controller; proc; opt; write_json {controller_json}",
        ]
    )
    run([args.netlistsvg, str(controller_json), "-o", str(BLUEPRINT_DIR / "controller.svg")])
    run(
        [
            args.yosys,
            "-q",
            "-p",
            f"read_verilog -sv {SV_DIR / 'controller_spot_core.sv'}; hierarchy -check -top controller_spot_core; proc; opt; write_json {core_json}",
        ]
    )
    run([args.netlistsvg, str(core_json), "-o", str(BLUEPRINT_DIR / "controller_spot_core.svg")])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
