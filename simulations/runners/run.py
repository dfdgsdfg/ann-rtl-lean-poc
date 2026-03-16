from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from contract.src.freeze import validate_canonical_contract_bundle
from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot


SIM_INCLUDE_DIR = ROOT / "simulations" / "shared"
TOP_LEVEL_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
INTERNAL_TB = ROOT / "simulations" / "rtl" / "testbench_internal.sv"
VECTORS = ROOT / "simulations" / "shared" / "test_vectors.mem"
VECTOR_META = ROOT / "simulations" / "shared" / "test_vectors_meta.svh"

BRANCH_BUILD_ROOTS = {
    "rtl": ROOT / "build" / "rtl",
    "rtl-synthesis": ROOT / "build" / "rtl-synthesis",
    "rtl-formalize-synthesis": ROOT / "build" / "rtl-formalize-synthesis",
}
BRANCH_REPORT_ROOTS = {
    "rtl": ROOT / "reports" / "rtl",
    "rtl-synthesis": ROOT / "reports" / "rtl-synthesis",
    "rtl-formalize-synthesis": ROOT / "reports" / "rtl-formalize-synthesis",
}
BRANCH_SOURCES = {
    "rtl": [
        ROOT / "rtl" / "results" / "canonical" / "sv" / "mac_unit.sv",
        ROOT / "rtl" / "results" / "canonical" / "sv" / "relu_unit.sv",
        ROOT / "rtl" / "results" / "canonical" / "sv" / "controller.sv",
        ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
        ROOT / "rtl" / "results" / "canonical" / "sv" / "mlp_core.sv",
    ],
    "rtl-synthesis": [
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mac_unit.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "relu_unit.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_compat.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_core.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "weight_rom.sv",
        ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv",
    ],
    "rtl-formalize-synthesis": [
        ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv",
        ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv",
    ],
}


def timestamp_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def tool_version(command: list[str], *, fallback: str = "unknown") -> str:
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    except OSError:
        return fallback
    output = (result.stdout + result.stderr).strip()
    return output.splitlines()[0] if output else fallback


def ensure_tools(simulator: str, *, iverilog: str, vvp: str, verilator: str) -> None:
    if simulator in {"iverilog", "all"}:
        for tool in (iverilog, vvp):
            if shutil.which(tool) is None:
                raise SystemExit(f"missing required tool: {tool}")
    if simulator in {"verilator", "all"} and shutil.which(verilator) is None:
        raise SystemExit(f"missing required tool: {verilator}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run shared RTL simulation regressions.")
    parser.add_argument("--branch", choices=sorted(BRANCH_SOURCES), required=True)
    parser.add_argument("--profile", choices=("shared", "internal"), default="shared")
    parser.add_argument("--simulator", choices=("iverilog", "verilator", "all"), default="all")
    parser.add_argument("--iverilog", default=shutil.which("iverilog") or "iverilog")
    parser.add_argument("--vvp", default=shutil.which("vvp") or "vvp")
    parser.add_argument("--verilator", default=shutil.which("verilator") or "verilator")
    parser.add_argument("--build-root", type=Path, default=None)
    parser.add_argument("--report-root", type=Path, default=None)
    parser.add_argument("--run-id", default=None)
    return parser.parse_args(argv)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def run_command(command: list[str], *, cwd: Path) -> tuple[int, str]:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    return result.returncode, result.stdout + result.stderr


def run_iverilog(
    *,
    top_module: str,
    bench: Path,
    sources: list[Path],
    build_dir: Path,
    iverilog: str,
    vvp: str,
) -> dict[str, object]:
    bin_path = build_dir / "iverilog" / f"{top_module}.out"
    bin_path.parent.mkdir(parents=True, exist_ok=True)
    compile_command = [
        iverilog,
        "-g2012",
        f"-I{SIM_INCLUDE_DIR}",
        "-s",
        top_module,
        "-o",
        str(bin_path),
        str(bench),
        *(str(path) for path in sources),
    ]
    code, output = run_command(compile_command, cwd=ROOT)
    write_text(build_dir / "iverilog" / "compile.log", output)
    if code != 0:
        return {
            "name": "iverilog",
            "result": "fail",
            "compile_command": " ".join(compile_command),
            "compile_log": relative(build_dir / "iverilog" / "compile.log"),
            "binary": relative(bin_path),
        }

    run_command_line = [vvp, str(bin_path)]
    code, output = run_command(run_command_line, cwd=ROOT)
    write_text(build_dir / "iverilog" / "run.log", output)
    return {
        "name": "iverilog",
        "result": "pass" if code == 0 else "fail",
        "compile_command": " ".join(compile_command),
        "run_command": " ".join(run_command_line),
        "compile_log": relative(build_dir / "iverilog" / "compile.log"),
        "run_log": relative(build_dir / "iverilog" / "run.log"),
        "binary": relative(bin_path),
    }


def run_verilator(
    *,
    top_module: str,
    bench: Path,
    sources: list[Path],
    build_dir: Path,
    verilator: str,
) -> dict[str, object]:
    mdir = build_dir / "verilator"
    mdir.mkdir(parents=True, exist_ok=True)
    prefix = "Vtestbench_internal" if top_module == "testbench_internal" else "Vtestbench"
    compile_command = [
        verilator,
        "--binary",
        "--timing",
        f"-I{SIM_INCLUDE_DIR}",
        "--Mdir",
        str(mdir),
    ]
    if top_module == "testbench_internal":
        compile_command.extend(["--top-module", top_module, "--prefix", prefix])
    compile_command.extend([str(bench), *(str(path) for path in sources)])
    code, output = run_command(compile_command, cwd=ROOT)
    write_text(build_dir / "verilator" / "compile.log", output)
    binary = mdir / prefix
    if code != 0:
        return {
            "name": "verilator",
            "result": "fail",
            "compile_command": " ".join(compile_command),
            "compile_log": relative(build_dir / "verilator" / "compile.log"),
            "binary": relative(binary),
        }

    run_command_line = [str(binary)]
    code, output = run_command(run_command_line, cwd=ROOT)
    write_text(build_dir / "verilator" / "run.log", output)
    return {
        "name": "verilator",
        "result": "pass" if code == 0 else "fail",
        "compile_command": " ".join(compile_command),
        "run_command": " ".join(run_command_line),
        "compile_log": relative(build_dir / "verilator" / "compile.log"),
        "run_log": relative(build_dir / "verilator" / "run.log"),
        "binary": relative(binary),
    }


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.profile == "internal" and args.branch == "rtl-formalize-synthesis":
        raise SystemExit("internal simulation profile is unsupported for rtl-formalize-synthesis")

    ensure_tools(args.simulator, iverilog=args.iverilog, vvp=args.vvp, verilator=args.verilator)
    validate_canonical_contract_bundle()

    branch_build_root = args.build_root.resolve() if args.build_root is not None else BRANCH_BUILD_ROOTS[args.branch]
    branch_report_root = args.report_root.resolve() if args.report_root is not None else BRANCH_REPORT_ROOTS[args.branch]
    subpath = Path("simulations") / args.profile
    snapshot = prepare_snapshot(
        build_root=branch_build_root,
        report_root=branch_report_root,
        run_id=args.run_id or build_run_id(args.branch, f"sim-{args.profile}"),
        subpath=subpath,
    )
    build_dir = snapshot.build_run_dir
    report_dir = snapshot.report_run_dir

    bench = TOP_LEVEL_TB if args.profile == "shared" else INTERNAL_TB
    top_module = "testbench" if args.profile == "shared" else "testbench_internal"
    results: list[dict[str, object]] = []

    if args.simulator in {"iverilog", "all"}:
        results.append(
            run_iverilog(
                top_module=top_module,
                bench=bench,
                sources=BRANCH_SOURCES[args.branch],
                build_dir=build_dir,
                iverilog=args.iverilog,
                vvp=args.vvp,
            )
        )
    if args.simulator in {"verilator", "all"}:
        results.append(
            run_verilator(
                top_module=top_module,
                bench=bench,
                sources=BRANCH_SOURCES[args.branch],
                build_dir=build_dir,
                verilator=args.verilator,
            )
        )

    generated_at_utc = timestamp_utc()
    overall_result = "pass" if all(item["result"] == "pass" for item in results) else "fail"
    summary = {
        "generated_at_utc": generated_at_utc,
        "branch": args.branch,
        "profile": args.profile,
        "overall_result": overall_result,
        "sources": {
            "rtl": [relative(path) for path in BRANCH_SOURCES[args.branch]],
            "testbench": relative(bench),
            "vectors": [relative(VECTORS), relative(VECTOR_META)],
        },
        "tools": {
            "iverilog": tool_version([args.iverilog, "-V"], fallback=args.iverilog),
            "vvp": args.vvp,
            "verilator": tool_version([args.verilator, "--version"], fallback=args.verilator),
            "driver": f"python3 simulations/runners/run.py --branch {args.branch} --profile {args.profile} --simulator {args.simulator}",
        },
        "results": results,
    }
    report_dir.mkdir(parents=True, exist_ok=True)
    summary_path = report_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    promote_snapshot(
        snapshot,
        source="simulations_runner",
        created_at_utc=generated_at_utc,
        inputs={"branch": args.branch, "profile": args.profile, "simulator": args.simulator},
        commands={"driver": summary["tools"]["driver"]},
        tool_versions={
            "iverilog": summary["tools"]["iverilog"],
            "verilator": summary["tools"]["verilator"],
        },
        artifacts={"build_dir": snapshot.build_run_dir.relative_to(ROOT).as_posix()},
        reports={"summary": summary_path.relative_to(ROOT).as_posix()},
    )

    for item in results:
        print(f"{str(item['result']).upper():4} {args.branch} {args.profile} {item['name']}")
    print(f"wrote {summary_path}")
    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
