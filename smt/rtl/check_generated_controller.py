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
GENERATED_CONTROLLER_RTL = ROOT / "experiments" / "generated-rtl" / "sparkle" / "sparkle_controller.sv"
GENERATED_CONTROLLER_WRAPPER = ROOT / "experiments" / "generated-rtl" / "sparkle" / "sparkle_controller_wrapper.sv"


@dataclass(frozen=True)
class FormalJob:
    name: str
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


def formal_job() -> FormalJob:
    return FormalJob(
        name="generated_controller_equivalence",
        description="Equivalence between the hand-written controller and the Sparkle-generated controller wrapper.",
        top="formal_generated_controller_equivalence",
        harness=ROOT / "smt" / "rtl" / "controller" / "formal_generated_controller_equivalence.sv",
        depth=12,
        assumptions=[
            "Reset is held low for the first two cycles and then released permanently.",
            "start, hidden_idx, and input_idx remain unconstrained after reset release.",
            "The Sparkle wrapper maps active-low rst_n to the generated module's active-high rst input.",
        ],
        properties=[
            "4-bit state encoding matches the baseline controller on every checked cycle",
            "all control outputs match the baseline controller on every checked cycle",
            "busy and done agree exactly with the baseline controller semantics",
        ],
        rtl_sources=[
            ROOT / "rtl" / "src" / "controller.sv",
            GENERATED_CONTROLLER_RTL,
            GENERATED_CONTROLLER_WRAPPER,
        ],
    )


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
            f"missing generated RTL artifact: {relative(GENERATED_CONTROLLER_RTL)}; run `make rtl-formalize-synthsis-emit` first"
        )

    FORMAL_BUILD_DIR.mkdir(parents=True, exist_ok=True)
    job = formal_job()
    result = run_job(job, args.yosys, args.smtbmc, args.solver)

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "source_generated_rtl": relative(GENERATED_CONTROLLER_RTL),
        "source_wrapper": relative(GENERATED_CONTROLLER_WRAPPER),
        "tool_versions": {
            "yosys": tool_version([args.yosys, "-V"]),
            "yosys_smtbmc": tool_version([args.smtbmc, "--version"]),
            "solver": tool_version([args.solver, "--version"]),
        },
        "result": asdict(result),
    }
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    status = result.result.upper()
    print(f"{status} {result.name}")
    print(f"wrote {args.summary}")
    return 0 if result.result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
