from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SUMMARY = ROOT / "build" / "smt" / "generated_controller_summary.json"
FORMAL_BUILD_DIR = ROOT / "build" / "smt" / "generated_controller"
GENERATED_CONTROLLER_RTL = ROOT / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller.sv"
GENERATED_CONTROLLER_WRAPPER = ROOT / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller_wrapper.sv"


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
    defines: list[str]


@dataclass
class FormalResult:
    name: str
    family: str
    description: str
    top: str
    depth: int
    assumptions: list[str]
    properties: list[str]
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
    proc = subprocess.run(command, text=True, capture_output=True, check=False)
    return first_output_line(proc) or fallback


def formal_jobs() -> list[FormalJob]:
    common_sources = [
        ROOT / "rtl" / "src" / "controller.sv",
        GENERATED_CONTROLLER_RTL,
        GENERATED_CONTROLLER_WRAPPER,
    ]
    equivalence_harness = ROOT / "smt" / "rtl" / "controller" / "formal_generated_controller_equivalence.sv"
    illegal_state_harness = ROOT / "smt" / "rtl" / "controller" / "formal_generated_controller_illegal_state.sv"
    common_assumptions = [
        "Reset is held low for the first two cycles and then released permanently.",
        "start, hidden_idx, and input_idx remain unconstrained after reset release.",
        "The Sparkle wrapper maps active-low rst_n to the generated module's active-high rst input.",
    ]
    common_properties = [
        "4-bit state encoding matches the baseline controller on every checked cycle",
        "all control outputs match the baseline controller on every checked cycle",
        "busy and done agree exactly with the baseline controller semantics",
    ]
    return [
        FormalJob(
            name="generated_controller_equivalence_default",
            family="parameter_equivalence",
            description="Bounded equivalence between the hand-written controller and the Sparkle wrapper for INPUT_NEURONS=4, HIDDEN_NEURONS=8.",
            top="formal_generated_controller_equivalence",
            harness=equivalence_harness,
            depth=12,
            assumptions=common_assumptions,
            properties=common_properties,
            rtl_sources=common_sources,
            defines=["INPUT_NEURONS_VALUE=4", "HIDDEN_NEURONS_VALUE=8"],
        ),
        FormalJob(
            name="generated_controller_equivalence_3x5",
            family="parameter_equivalence",
            description="Bounded equivalence between the hand-written controller and the Sparkle wrapper for INPUT_NEURONS=3, HIDDEN_NEURONS=5.",
            top="formal_generated_controller_equivalence",
            harness=equivalence_harness,
            depth=12,
            assumptions=common_assumptions,
            properties=common_properties,
            rtl_sources=common_sources,
            defines=["INPUT_NEURONS_VALUE=3", "HIDDEN_NEURONS_VALUE=5"],
        ),
        FormalJob(
            name="generated_controller_equivalence_1x1",
            family="parameter_equivalence",
            description="Bounded equivalence between the hand-written controller and the Sparkle wrapper for INPUT_NEURONS=1, HIDDEN_NEURONS=1.",
            top="formal_generated_controller_equivalence",
            harness=equivalence_harness,
            depth=12,
            assumptions=common_assumptions,
            properties=common_properties,
            rtl_sources=common_sources,
            defines=["INPUT_NEURONS_VALUE=1", "HIDDEN_NEURONS_VALUE=1"],
        ),
        FormalJob(
            name="generated_controller_illegal_state_recovery",
            family="illegal_state_recovery",
            description="Parity with the baseline controller when both designs begin from the same invalid 4-bit state encoding.",
            top="formal_generated_controller_illegal_state",
            harness=illegal_state_harness,
            depth=2,
            assumptions=[
                "rst_n is released from the initial step so the controller state is unconstrained before the first clock edge.",
                "Both controllers are constrained to the same invalid state encoding in the first checked cycle.",
                "start, hidden_idx, and input_idx remain unconstrained while invalid-state outputs and one-cycle recovery are checked.",
            ],
            properties=[
                "invalid-state outputs match the baseline busy/done/control semantics in the seeded cycle",
                "the generated wrapper recovers to IDLE in one cycle exactly like the baseline controller",
            ],
            rtl_sources=common_sources,
            defines=["INPUT_NEURONS_VALUE=4", "HIDDEN_NEURONS_VALUE=8"],
        ),
    ]


def build_yosys_script(job: FormalJob, smt2_path: Path) -> str:
    verilog_sources = " ".join(relative(path) for path in job.rtl_sources + [job.harness])
    define_flags = " ".join(f"-D{item}" for item in ["FORMAL", *job.defines])
    return "\n".join(
        [
            f"read_verilog {define_flags} -sv -formal {verilog_sources}",
            f"prep -top {job.top}",
            "async2sync",
            "dffunmap",
            f"write_smt2 -wires {relative(smt2_path)}",
        ]
    ) + "\n"


def run_job(job: FormalJob, yosys_bin: str, smtbmc_bin: str, solver_bin: str) -> FormalResult:
    job_dir = FORMAL_BUILD_DIR / job.name
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
            [smtbmc_bin, "-s", solver_name, "--presat", "-t", str(job.depth), str(smt2_path)],
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
        depth=job.depth,
        assumptions=job.assumptions,
        properties=job.properties,
        result=result,
        yosys_log=relative(yosys_log),
        smtbmc_log=relative(smtbmc_log),
        artifacts={"smt2": relative(smt2_path)},
        commands={
            "yosys": f"{yosys_bin} -q -s {relative(yosys_script)}",
            "yosys_smtbmc": f"{smtbmc_bin} -s {solver_name} --presat -t {job.depth} {relative(smt2_path)}",
        },
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run RTL-backed formal equivalence checks for the generated Sparkle controller."
    )
    parser.add_argument("--yosys", default="yosys")
    parser.add_argument("--smtbmc", default="yosys-smtbmc")
    parser.add_argument("--solver", default="z3")
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    args = parser.parse_args()

    for tool in (args.yosys, args.smtbmc, args.solver):
        if not tool_exists(tool):
            parser.error(f"missing required tool: {tool}")

    if not GENERATED_CONTROLLER_RTL.exists():
        parser.error(
            f"missing generated RTL artifact: {relative(GENERATED_CONTROLLER_RTL)}; run `make rtl-formalize-synthesis-emit` first"
        )

    FORMAL_BUILD_DIR.mkdir(parents=True, exist_ok=True)
    jobs = formal_jobs()
    results = [run_job(job, args.yosys, args.smtbmc, args.solver) for job in jobs]
    overall_result = "pass" if all(item.result == "pass" for item in results) else "fail"

    yosys_version = tool_version([args.yosys, "-V"])
    solver_version = tool_version([args.solver, "--version"])
    smtbmc_version = tool_version([args.smtbmc, "--version"], fallback=f"bundled with {yosys_version}")
    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "overall_result": overall_result,
        "claim_scope": "bounded equivalence through the parameterized sparkle_controller_wrapper boundary",
        "tool": {
            "driver": "python3 smt/rtl/check_generated_controller.py",
            "yosys": str(args.yosys),
            "yosys_version": yosys_version,
            "yosys_smtbmc": str(args.smtbmc),
            "yosys_smtbmc_version": smtbmc_version,
            "solver": str(args.solver),
            "solver_version": solver_version,
            "command": (
                f"python3 smt/rtl/check_generated_controller.py --yosys {args.yosys} "
                f"--smtbmc {args.smtbmc} --solver {args.solver} --summary {args.summary}"
            ),
        },
        "sources": {
            "rtl": [
                relative(ROOT / "rtl" / "src" / "controller.sv"),
                relative(GENERATED_CONTROLLER_RTL),
                relative(GENERATED_CONTROLLER_WRAPPER),
            ],
            "harnesses": sorted({relative(job.harness) for job in jobs}),
        },
        "results": [asdict(result) for result in results],
    }
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for result in results:
        print(f"{result.result.upper():4} {result.family} {result.name}")
    print(f"wrote {args.summary}")
    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
