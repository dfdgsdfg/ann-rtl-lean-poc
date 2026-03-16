from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot

DEFAULT_BUILD_ROOT = ROOT / "build" / "smt"
DEFAULT_REPORT_ROOT = ROOT / "reports" / "smt"
DEFAULT_SUMMARIES = {
    "rtl": ROOT / "reports" / "smt" / "canonical" / "rtl" / "rtl" / "summary.json",
    "rtl-synthesis": ROOT / "reports" / "smt" / "canonical" / "rtl" / "rtl-synthesis" / "summary.json",
    "rtl-formalize-synthesis": ROOT / "reports" / "smt" / "canonical" / "rtl" / "rtl-formalize-synthesis" / "summary.json",
}

BASELINE_RTL_SOURCES = [
    ROOT / "rtl" / "results" / "canonical" / "sv" / "controller.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mlp_core.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
]
RTL_SYNTHESIS_RTL_SOURCES = [
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_compat.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_core.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "weight_rom.sv",
]
SPARKLE_RTL_SOURCES = [
    ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv",
    ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv",
]

COMMON_SPEC_SOURCES = [
    "specs/smt/requirement.md",
    "specs/smt/design.md",
]
BRANCH_SPEC_SOURCES = {
    "rtl": [],
    "rtl-synthesis": [
        "specs/rtl-synthesis/requirement.md",
        "specs/rtl-synthesis/design.md",
    ],
    "rtl-formalize-synthesis": [
        "specs/rtl-formalize-synthesis/requirement.md",
        "specs/rtl-formalize-synthesis/design.md",
    ],
}


@dataclass(frozen=True)
class FormalJob:
    name: str
    family: str
    description: str
    top: str
    harness: Path
    depth: int
    assumptions: list[str]
    properties: list[str]
    rtl_sources: list[Path]


@dataclass
class FormalResult:
    name: str
    family: str
    description: str
    top: str
    assumptions: list[str]
    properties: list[str]
    depth: int
    result: str
    yosys_log: str
    smtbmc_log: str
    artifacts: dict[str, str]
    commands: dict[str, str]


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def tool_exists(tool: str) -> bool:
    return Path(tool).exists() or shutil.which(tool) is not None


def first_output_line(proc: subprocess.CompletedProcess[str]) -> str:
    text = (proc.stdout + proc.stderr).strip()
    return text.splitlines()[0].strip() if text else "unknown"


def tool_version(command: list[str], fallback: str = "unknown") -> str:
    proc = subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )
    return first_output_line(proc) or fallback


def mlp_core_jobs(rtl_sources: list[Path], *, description_prefix: str) -> list[FormalJob]:
    rtl_dir = ROOT / "smt" / "rtl"
    return [
        FormalJob(
            name="mlp_core_boundary_behavior",
            family="boundary_behavior",
            description=f"{description_prefix} mlp_core boundary proofs for hidden/output guard cycles and no-duplicate/no-skip transitions.",
            top="formal_mlp_core_boundaries",
            harness=rtl_dir / "mlp_core" / "formal_mlp_core_boundaries.sv",
            depth=82,
            assumptions=[
                "Reset is asserted for the initial step, then released permanently.",
                "start is high on the single accept cycle immediately after reset release.",
                "start is low for the remainder of the bounded transaction window.",
                "The proof follows one bounded mlp_core transaction through DONE and release.",
            ],
            properties=[
                "hidden MAC boundary takes exactly one guard cycle at input_idx == 4 with no duplicate MAC work",
                "last hidden neuron handoff enters MAC_OUTPUT at hidden_idx == 0 and input_idx == 0",
                "output MAC boundary takes exactly one guard cycle at input_idx == 8 with no duplicate MAC work",
                "BIAS_OUTPUT applies the output bias once and enters DONE with the documented completion indices",
            ],
            rtl_sources=rtl_sources,
        ),
        FormalJob(
            name="mlp_core_range_safety",
            family="range_safety",
            description=f"{description_prefix} mlp_core range-safety proofs around MAC enables, selector validity, and boundary guard reads.",
            top="formal_mlp_core_range_safety",
            harness=rtl_dir / "mlp_core" / "formal_mlp_core_range_safety.sv",
            depth=82,
            assumptions=[
                "Reset is asserted for the initial step, then released permanently.",
                "start is high on the single accept cycle immediately after reset release.",
                "start is low for the remainder of the bounded transaction window.",
                "The proof is bounded to one transaction so hidden and output boundaries are both exercised.",
            ],
            properties=[
                "do_mac_hidden implies input_idx < 4 and hits real input/weight selector cases",
                "do_mac_output implies input_idx < 8 and hits real hidden/weight selector cases",
                "hidden guard cycle at input_idx == 4 misses the hidden selector/ROM cases and drives mac_a to zero",
                "output guard cycle at input_idx == 8 misses the output selector/ROM cases and drives mac_a to zero",
                "MAC_OUTPUT operates with hidden_idx == 0 throughout the output phase",
            ],
            rtl_sources=rtl_sources,
        ),
        FormalJob(
            name="mlp_core_transaction_capture",
            family="transaction_capture",
            description=f"{description_prefix} proof that an accepted start captures in0..in3 into the transaction state and keeps them stable.",
            top="formal_mlp_core_transaction_capture",
            harness=rtl_dir / "mlp_core" / "formal_mlp_core_transaction_capture.sv",
            depth=82,
            assumptions=[
                "Reset is asserted for the initial step, then released permanently.",
                "start is high on the single accept cycle immediately after reset release.",
                "start is low for the remainder of the bounded transaction window.",
                "The environment may change in0..in3 after acceptance, so stability must come from the captured input_regs.",
            ],
            properties=[
                "LOAD_INPUT is reached after the accepted start and asserts the top-level load pulse",
                "LOAD_INPUT samples in0..in3 into input_regs on the transaction boundary",
                "The captured input_regs remain stable for the rest of the bounded transaction",
                "The load step clears acc_reg, resets the visible indices, and clears out_bit",
            ],
            rtl_sources=rtl_sources,
        ),
        FormalJob(
            name="mlp_core_bounded_latency",
            family="bounded_latency",
            description=f"{description_prefix} exact-latency proof for the single-transaction mlp_core trace.",
            top="formal_mlp_core_latency",
            harness=rtl_dir / "mlp_core" / "formal_mlp_core_latency.sv",
            depth=82,
            assumptions=[
                "Initial visible state is IDLE with hidden_idx = 0 and input_idx = 0 because reset is asserted.",
                "start is sampled high only on the accept cycle immediately after reset release.",
                "start stays low afterward so DONE can release back to IDLE.",
                "No reset is applied during the bounded transaction window after acceptance.",
            ],
            properties=[
                "the accepted transaction is not done early",
                "busy stays high throughout the active window",
                "done becomes visible exactly 76 cycles after the accept cycle",
                "the design returns to IDLE one cycle after DONE when start is low",
            ],
            rtl_sources=rtl_sources,
        ),
    ]


def formal_jobs(branch: str) -> list[FormalJob]:
    rtl_dir = ROOT / "smt" / "rtl"
    if branch == "rtl-synthesis":
        return mlp_core_jobs(
            RTL_SYNTHESIS_RTL_SOURCES,
            description_prefix="RTL-synthesis mixed-path",
        )

    if branch == "rtl-formalize-synthesis":
        return [
            FormalJob(
                name="sparkle_wrapper_equivalence",
                family="wrapper_equivalence",
                description="Sparkle raw packed module and stable wrapper equivalence over reset adaptation, packed bus recovery, and FORMAL aliases.",
                top="formal_sparkle_wrapper_equivalence",
                harness=rtl_dir / "mlp_core" / "formal_sparkle_wrapper_equivalence.sv",
                depth=2,
                assumptions=[],
                properties=[
                    "wrapper-visible behavior matches a direct raw-module instantiation under the documented rst_n to rst adaptation",
                    "done, busy, and out_bit are exact projections of the raw packed bus",
                    "all FORMAL aliases are exact projections of the documented packed fields",
                ],
                rtl_sources=SPARKLE_RTL_SOURCES,
            ),
            *mlp_core_jobs(
                SPARKLE_RTL_SOURCES,
                description_prefix="Sparkle-wrapper-backed",
            ),
        ]

    return [
        FormalJob(
            name="controller_interface",
            family="controller_interface",
            description="RTL-backed controller transition and output-definition checks over controller.sv.",
            top="formal_controller_interface",
            harness=rtl_dir / "controller" / "formal_controller_interface.sv",
            depth=12,
            assumptions=[
                "The controller starts from reset with state forced to IDLE.",
                "start, hidden_idx, and input_idx remain unconstrained after reset release.",
                "Proof source of truth is rtl/results/canonical/sv/controller.sv, not a duplicated Python transition model.",
            ],
            properties=[
                "accepted start leaves IDLE for LOAD_INPUT on the next cycle",
                "done matches state == DONE",
                "busy matches state != IDLE && state != DONE",
                "load_input, clear_acc, MAC, bias, and advance outputs match the RTL state encoding",
                "DONE self-holds while start remains high and releases to IDLE when start is low",
            ],
            rtl_sources=[ROOT / "rtl" / "results" / "canonical" / "sv" / "controller.sv"],
        ),
        *mlp_core_jobs(
            BASELINE_RTL_SOURCES,
            description_prefix="RTL-backed",
        ),
    ]


def branch_rtl_sources(branch: str) -> list[Path]:
    if branch == "rtl-synthesis":
        return RTL_SYNTHESIS_RTL_SOURCES
    if branch == "rtl-formalize-synthesis":
        return SPARKLE_RTL_SOURCES
    return BASELINE_RTL_SOURCES


def build_yosys_script(job: FormalJob, smt2_path: Path) -> str:
    verilog_sources = " ".join(relative(path) for path in job.rtl_sources + [job.harness])
    return "\n".join(
        [
            f"read_verilog -DFORMAL -sv -formal {verilog_sources}",
            f"prep -top {job.top}",
            "async2sync",
            "dffunmap",
            f"write_smt2 -wires {relative(smt2_path)}",
        ]
    ) + "\n"


def run_job(
    job: FormalJob,
    yosys_bin: str,
    smtbmc_bin: str,
    solver_bin: str,
    *,
    build_dir: Path,
) -> FormalResult:
    job_dir = build_dir / job.name
    job_dir.mkdir(parents=True, exist_ok=True)

    yosys_script = job_dir / "run.ys"
    smt2_path = job_dir / f"{job.top}.smt2"
    yosys_log = job_dir / "yosys.log"
    smtbmc_log = job_dir / "yosys_smtbmc.log"

    yosys_script.write_text(build_yosys_script(job, smt2_path), encoding="utf-8")

    solver_name = Path(solver_bin).name
    yosys_proc = subprocess.run(
        [yosys_bin, "-q", "-s", str(yosys_script)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    yosys_output = (yosys_proc.stdout + yosys_proc.stderr).strip()
    yosys_log.write_text(yosys_output + ("\n" if yosys_output else ""), encoding="utf-8")

    smtbmc_output = ""
    if yosys_proc.returncode == 0:
        smtbmc_proc = subprocess.run(
            [
                smtbmc_bin,
                "-s",
                solver_name,
                "--presat",
                "-t",
                str(job.depth),
                str(smt2_path),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        smtbmc_output = (smtbmc_proc.stdout + smtbmc_proc.stderr).strip()
        smtbmc_log.write_text(smtbmc_output + ("\n" if smtbmc_output else ""), encoding="utf-8")
        if "Status: PASSED" in smtbmc_output and smtbmc_proc.returncode == 0:
            result = "pass"
        elif "Status: FAILED" in smtbmc_output or smtbmc_proc.returncode != 0:
            result = "fail"
        else:
            result = "error"
    else:
        smtbmc_log.write_text("yosys step failed; SMTBMC was not run\n", encoding="utf-8")
        result = "error"

    return FormalResult(
        name=job.name,
        family=job.family,
        description=job.description,
        top=job.top,
        assumptions=job.assumptions,
        properties=job.properties,
        depth=job.depth,
        result=result,
        yosys_log=relative(yosys_log),
        smtbmc_log=relative(smtbmc_log),
        artifacts={
            "harness": relative(job.harness),
            "yosys_script": relative(yosys_script),
            "smt2": relative(smt2_path),
        },
        commands={
            "yosys": f"{yosys_bin} -q -s {relative(yosys_script)}",
            "yosys_smtbmc": f"{smtbmc_bin} -s {Path(solver_bin).name} --presat -t {job.depth} {relative(smt2_path)}",
        },
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run RTL-backed SMT control checks with Yosys and yosys-smtbmc.")
    parser.add_argument(
        "--branch",
        choices=sorted(DEFAULT_SUMMARIES),
        default="rtl",
        help="Which RTL branch/source set to validate.",
    )
    parser.add_argument(
        "--yosys",
        default=shutil.which("yosys") or "yosys",
        help="Path to the yosys binary.",
    )
    parser.add_argument(
        "--smtbmc",
        default=shutil.which("yosys-smtbmc") or "yosys-smtbmc",
        help="Path to the yosys-smtbmc binary.",
    )
    parser.add_argument(
        "--solver",
        default=shutil.which("z3") or "z3",
        help="Path to the backend SMT solver binary.",
    )
    parser.add_argument(
        "--z3",
        dest="solver_alias",
        default=None,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="Runtime build root for SMT job artifacts.",
    )
    parser.add_argument(
        "--report-root",
        type=Path,
        default=DEFAULT_REPORT_ROOT,
        help="Runtime report root for SMT summaries.",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="Optional run id for runtime artifact provenance mode.",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=None,
        help="JSON path for the pass/fail summary.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.solver_alias:
        args.solver = args.solver_alias
    explicit_output_mode = args.summary is not None
    snapshot = None
    if explicit_output_mode:
        args.summary = args.summary or DEFAULT_SUMMARIES[args.branch]
        formal_build_dir = (args.build_root.resolve() / "canonical" / "rtl" / args.branch / "jobs")
    else:
        snapshot = prepare_snapshot(
            build_root=args.build_root.resolve(),
            report_root=args.report_root.resolve(),
            run_id=args.run_id or build_run_id("smt", f"rtl-{args.branch}"),
            subpath=Path("rtl") / args.branch,
        )
        args.summary = snapshot.report_run_dir / "summary.json"
        formal_build_dir = snapshot.build_run_dir / "jobs"

    for tool in (args.yosys, args.smtbmc, args.solver):
        if not tool_exists(tool):
            raise SystemExit(f"missing required tool: {tool}")

    formal_build_dir.mkdir(parents=True, exist_ok=True)
    jobs = formal_jobs(args.branch)
    results = [
        run_job(job, args.yosys, args.smtbmc, args.solver, build_dir=formal_build_dir)
        for job in jobs
    ]
    overall_result = "pass" if all(item.result == "pass" for item in results) else "fail"

    yosys_version = tool_version([args.yosys, "-V"])
    solver_version = tool_version([args.solver, "-version"])
    smtbmc_version = tool_version([args.smtbmc, "-h"], fallback=f"bundled with {yosys_version}")

    generated_at_utc = datetime.now(timezone.utc).isoformat(timespec="seconds")
    summary = {
        "generated_at_utc": generated_at_utc,
        "branch": args.branch,
        "overall_result": overall_result,
        "tool": {
            "driver": "python3 smt/runners/rtl.py",
            "yosys": str(args.yosys),
            "yosys_version": yosys_version,
            "yosys_smtbmc": str(args.smtbmc),
            "yosys_smtbmc_version": smtbmc_version,
            "solver": str(args.solver),
            "solver_version": solver_version,
            "command": (
                f"python3 smt/runners/rtl.py --branch {args.branch} --yosys {args.yosys} "
                f"--smtbmc {args.smtbmc} --solver {args.solver} --summary {args.summary}"
            ),
        },
        "sources": {
            "rtl": [relative(path) for path in branch_rtl_sources(args.branch)],
            "specs": [*COMMON_SPEC_SOURCES, *BRANCH_SPEC_SOURCES[args.branch]],
            "harnesses": [relative(job.harness) for job in jobs],
        },
        "results": [asdict(item) for item in results],
    }

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if snapshot is not None:
        promote_snapshot(
            snapshot,
            source="smt_rtl_family",
            created_at_utc=generated_at_utc,
            inputs={"branch": args.branch},
            commands={"driver": summary["tool"]["command"]},
            tool_versions={
                "yosys": yosys_version,
                "yosys_smtbmc": smtbmc_version,
                "solver": solver_version,
            },
            artifacts={
                "jobs_dir": relative(formal_build_dir),
                "rtl_sources": summary["sources"]["rtl"],
            },
            reports={"summary": relative(args.summary)},
        )

    for item in results:
        print(f"{item.result.upper():4} {args.branch} {item.family} {item.name}")
    print(f"wrote {args.summary}")
    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
