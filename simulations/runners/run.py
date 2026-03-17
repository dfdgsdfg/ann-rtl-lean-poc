from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

if __package__ in (None, ""):
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from contract.src.freeze import validate_canonical_contract_bundle
from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot


SIM_INCLUDE_DIR = ROOT / "simulations" / "shared"
TOP_LEVEL_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
INTERNAL_TB = ROOT / "simulations" / "rtl" / "testbench_internal.sv"
VECTORS = ROOT / "simulations" / "shared" / "test_vectors.mem"
VECTOR_META = ROOT / "simulations" / "shared" / "test_vectors_meta.svh"
COUNTER_PATTERN = re.compile(r"^(vectors|passes|failures|output|latency|handshake|coverage|boundary):\s*(\d+)\s*$")
TOP_LEVEL_BENCH_KIND = "shared_full_core_top_level_bench"
INTERNAL_OBSERVABILITY_BENCH_KIND = "internal_observability_bench"

BRANCH_BLUEPRINTS = {
    "rtl": ROOT / "rtl" / "results" / "canonical" / "blueprint" / "mlp_core.svg",
    "rtl-synthesis": ROOT / "rtl-synthesis" / "results" / "canonical" / "blueprint" / "mlp_core.svg",
    "rtl-formalize-synthesis": ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "blueprint" / "mlp_core.svg",
}
BRANCH_EXPORT_TREES = {
    "rtl": ROOT / "rtl" / "results" / "canonical" / "sv",
    "rtl-synthesis": ROOT / "rtl-synthesis" / "results" / "canonical" / "sv",
    "rtl-formalize-synthesis": ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv",
}
BRANCH_SCOPES = {
    "rtl": {
        "generation_scope": "handwritten_full_core_rtl",
        "integration_scope": "full_core_mlp_core",
        "validation_scopes": {
            "shared": "shared_full_core_mlp_core_regression",
            "internal": "internal_observability_regression",
        },
    },
    "rtl-synthesis": {
        "generation_scope": "generated_controller_rtl",
        "integration_scope": "mixed_path_mlp_core",
        "validation_scopes": {
            "shared": "shared_full_core_mlp_core_regression",
            "internal": "mixed_path_internal_observability_regression",
        },
    },
    "rtl-formalize-synthesis": {
        "generation_scope": "generated_full_core_rtl",
        "integration_scope": "full_core_mlp_core",
        "validation_scopes": {
            "shared": "shared_full_core_mlp_core_regression",
        },
    },
}

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
SPARKLE_VERIFICATION_MANIFEST = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "verification_manifest.json"


def timestamp_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def relative(path: Path) -> str:
    candidate = path if path.is_absolute() else ROOT / path
    try:
        return candidate.relative_to(ROOT).as_posix()
    except ValueError:
        return str(candidate)


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


def load_sparkle_proof_lane() -> dict[str, object] | None:
    if not SPARKLE_VERIFICATION_MANIFEST.exists():
        return None
    try:
        payload = json.loads(SPARKLE_VERIFICATION_MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    proof_lane = payload.get("proof_lane")
    return proof_lane if isinstance(proof_lane, dict) else None


def first_relevant_line(text: str) -> str | None:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return None


def parse_regression_output(output: str) -> dict[str, object]:
    counts: dict[str, int] = {}
    failure_summary: str | None = None

    for line in output.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        match = COUNTER_PATTERN.match(stripped)
        if match is not None:
            counts[match.group(1)] = int(match.group(2))
            continue
        if failure_summary is None and stripped.startswith("FAIL "):
            failure_summary = stripped

    regression: dict[str, object] = {}
    if "vectors" in counts:
        regression["vectors"] = counts.pop("vectors")
    if "passes" in counts:
        regression["passes"] = counts.pop("passes")
    if "failures" in counts:
        regression["failures"] = counts.pop("failures")
    if counts:
        regression["error_counts"] = counts
    if failure_summary is not None:
        regression["failure_summary"] = failure_summary
    return regression


def bench_kind_for_profile(profile: str) -> str:
    return TOP_LEVEL_BENCH_KIND if profile == "shared" else INTERNAL_OBSERVABILITY_BENCH_KIND


def ensure_branch_surface(branch: str) -> None:
    missing: list[str] = []
    export_tree = BRANCH_EXPORT_TREES[branch]
    if not export_tree.is_dir():
        missing.append(relative(export_tree))

    for path in BRANCH_SOURCES[branch]:
        if not path.exists():
            missing.append(relative(path))

    blueprint = BRANCH_BLUEPRINTS[branch]
    if not blueprint.is_file():
        missing.append(relative(blueprint))

    if missing:
        raise SystemExit(
            "missing required branch-local simulation surface for "
            f"{branch}: {', '.join(missing)}"
        )


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
        result = {
            "name": "iverilog",
            "result": "fail",
            "compile_command": " ".join(compile_command),
            "compile_log": relative(build_dir / "iverilog" / "compile.log"),
            "binary": relative(bin_path),
        }
        failure_summary = first_relevant_line(output)
        if failure_summary is not None:
            result["failure_summary"] = failure_summary
        return result

    run_command_line = [vvp, str(bin_path)]
    code, output = run_command(run_command_line, cwd=ROOT)
    write_text(build_dir / "iverilog" / "run.log", output)
    regression = parse_regression_output(output)
    result = {
        "name": "iverilog",
        "result": "pass" if code == 0 else "fail",
        "compile_command": " ".join(compile_command),
        "run_command": " ".join(run_command_line),
        "compile_log": relative(build_dir / "iverilog" / "compile.log"),
        "run_log": relative(build_dir / "iverilog" / "run.log"),
        "binary": relative(bin_path),
    }
    if regression:
        result["regression"] = regression
    if code != 0:
        failure_summary = None
        if regression:
            parsed_failure = regression.get("failure_summary")
            if isinstance(parsed_failure, str) and parsed_failure:
                failure_summary = parsed_failure
        if failure_summary is None:
            failure_summary = first_relevant_line(output)
        if failure_summary is not None:
            result["failure_summary"] = failure_summary
    return result


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
        result = {
            "name": "verilator",
            "result": "fail",
            "compile_command": " ".join(compile_command),
            "compile_log": relative(build_dir / "verilator" / "compile.log"),
            "binary": relative(binary),
        }
        failure_summary = first_relevant_line(output)
        if failure_summary is not None:
            result["failure_summary"] = failure_summary
        return result

    run_command_line = [str(binary)]
    code, output = run_command(run_command_line, cwd=ROOT)
    write_text(build_dir / "verilator" / "run.log", output)
    regression = parse_regression_output(output)
    result = {
        "name": "verilator",
        "result": "pass" if code == 0 else "fail",
        "compile_command": " ".join(compile_command),
        "run_command": " ".join(run_command_line),
        "compile_log": relative(build_dir / "verilator" / "compile.log"),
        "run_log": relative(build_dir / "verilator" / "run.log"),
        "binary": relative(binary),
    }
    if regression:
        result["regression"] = regression
    if code != 0:
        failure_summary = None
        if regression:
            parsed_failure = regression.get("failure_summary")
            if isinstance(parsed_failure, str) and parsed_failure:
                failure_summary = parsed_failure
        if failure_summary is None:
            failure_summary = first_relevant_line(output)
        if failure_summary is not None:
            result["failure_summary"] = failure_summary
    return result


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.profile == "internal" and args.branch == "rtl-formalize-synthesis":
        raise SystemExit("internal simulation profile is unsupported for rtl-formalize-synthesis")

    ensure_tools(args.simulator, iverilog=args.iverilog, vvp=args.vvp, verilator=args.verilator)
    validate_canonical_contract_bundle()
    ensure_branch_surface(args.branch)

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
    branch_scope = BRANCH_SCOPES[args.branch]
    summary = {
        "generated_at_utc": generated_at_utc,
        "branch": args.branch,
        "profile": args.profile,
        "overall_result": overall_result,
        "generation_scope": branch_scope["generation_scope"],
        "integration_scope": branch_scope["integration_scope"],
        "validation_scope": branch_scope["validation_scopes"][args.profile],
        "bench_kind": bench_kind_for_profile(args.profile),
        "bench_shared_with_baseline": True,
        "export_tree": relative(BRANCH_EXPORT_TREES[args.branch]),
        "bench_path": relative(bench),
        "sources": {
            "rtl": [relative(path) for path in BRANCH_SOURCES[args.branch]],
            "blueprint": relative(BRANCH_BLUEPRINTS[args.branch]),
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
    if args.branch == "rtl-formalize-synthesis":
        proof_lane = load_sparkle_proof_lane()
        if proof_lane is not None:
            summary["proof_lane"] = proof_lane
            summary["sources"]["verification_manifest"] = relative(SPARKLE_VERIFICATION_MANIFEST)
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
