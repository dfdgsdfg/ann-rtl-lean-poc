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


def render_svg(
    *,
    yosys: str,
    netlistsvg: str,
    sources: list[Path],
    top: str,
    json_path: Path,
    svg_path: Path,
    flatten: bool = False,
) -> None:
    script = [
        "read_verilog -sv " + " ".join(str(path) for path in sources),
        f"hierarchy -check -top {top}",
        "proc",
    ]
    if flatten:
        script.append("flatten")
    script.extend(("opt", f"write_json {json_path}"))
    run([yosys, "-q", "-p", "; ".join(script)])
    run([netlistsvg, str(json_path), "-o", str(svg_path)])


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

    top_sources = [
        SV_DIR / "mac_unit.sv",
        SV_DIR / "relu_unit.sv",
        SV_DIR / "controller.sv",
        SV_DIR / "controller_spot_compat.sv",
        SV_DIR / "controller_spot_core.sv",
        SV_DIR / "weight_rom.sv",
        SV_DIR / "mlp_core.sv",
    ]
    render_svg(
        yosys=args.yosys,
        netlistsvg=args.netlistsvg,
        sources=top_sources,
        top="mlp_core",
        json_path=BUILD_DIR / "mlp_core.json",
        svg_path=BLUEPRINT_DIR / "mlp_core.svg",
    )
    render_svg(
        yosys=args.yosys,
        netlistsvg=args.netlistsvg,
        sources=top_sources,
        top="mlp_core",
        json_path=BUILD_DIR / "blueprint.json",
        svg_path=BLUEPRINT_DIR / "blueprint.svg",
        flatten=True,
    )
    render_svg(
        yosys=args.yosys,
        netlistsvg=args.netlistsvg,
        sources=[
            SV_DIR / "controller.sv",
            SV_DIR / "controller_spot_compat.sv",
            SV_DIR / "controller_spot_core.sv",
        ],
        top="controller",
        json_path=BUILD_DIR / "controller.json",
        svg_path=BLUEPRINT_DIR / "controller.svg",
    )
    render_svg(
        yosys=args.yosys,
        netlistsvg=args.netlistsvg,
        sources=[SV_DIR / "controller_spot_core.sv"],
        top="controller_spot_core",
        json_path=BUILD_DIR / "controller_spot_core.json",
        svg_path=BLUEPRINT_DIR / "controller_spot_core.svg",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
