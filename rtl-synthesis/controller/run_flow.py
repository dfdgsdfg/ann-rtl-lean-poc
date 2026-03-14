from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DOMAIN_ROOT = ROOT / "rtl-synthesis" / "controller"
DEFAULT_BUILD_DIR = ROOT / "build" / "rtl-synthesis" / "spot"
DEFAULT_SUMMARY = DEFAULT_BUILD_DIR / "rtl_synthesis_summary.json"

TLSF_SOURCE = DOMAIN_ROOT / "controller.tlsf"
FORMAL_HARNESS = DOMAIN_ROOT / "formal" / "formal_controller_spot_equivalence.sv"
BASELINE_CONTROLLER = ROOT / "rtl" / "src" / "controller.sv"
COMPAT_WRAPPER = ROOT / "experiments" / "generated-rtl" / "rtl-synthesis" / "spot" / "controller_spot_compat.sv"

SPEC_SOURCES = [
    "specs/rtl-synthesis/requirement.md",
    "specs/rtl-synthesis/design.md",
    "experiments/generated-rtl-vs-rtl.md",
]

ABSTRACT_INPUTS = [
    "start",
    "reset",
    "hidden_mac_active",
    "hidden_mac_guard",
    "last_hidden",
    "output_mac_active",
    "output_mac_guard",
    "hidden_mac_pos_b0",
    "hidden_mac_pos_b1",
    "hidden_mac_pos_b2",
    "hidden_neuron_ord_b0",
    "hidden_neuron_ord_b1",
    "hidden_neuron_ord_b2",
    "output_mac_pos_b0",
    "output_mac_pos_b1",
    "output_mac_pos_b2",
    "output_mac_pos_b3",
]

PHASE_OUTPUTS = [
    "phase_idle",
    "phase_load_input",
    "phase_mac_hidden",
    "phase_bias_hidden",
    "phase_act_hidden",
    "phase_next_hidden",
    "phase_mac_output",
    "phase_bias_output",
    "phase_done",
]

EQUIVALENCE_DEPTH = 12
CLAIM_SCOPE = (
    f"bounded ({EQUIVALENCE_DEPTH}-cycle) raw controller-interface equivalence "
    "under exact_schedule_v1 assumptions"
)


@dataclass
class CommandArtifact:
    name: str
    result: str
    command: str
    log: str
    artifacts: dict[str, str]


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def tool_exists(tool: str) -> bool:
    return Path(tool).exists() or shutil.which(tool) is not None


def first_output_line(proc: subprocess.CompletedProcess[str]) -> str:
    text = (proc.stdout + proc.stderr).strip()
    return text.splitlines()[0].strip() if text else "unknown"


def tool_version(commands: list[list[str]], fallback: str = "unknown") -> str:
    for command in commands:
      proc = subprocess.run(
          command,
          text=True,
          capture_output=True,
          check=False,
      )
      if proc.returncode == 0 and (proc.stdout or proc.stderr):
          return first_output_line(proc)
    return fallback


def tool_env(*tools: str) -> dict[str, str]:
    env = os.environ.copy()
    prepend: list[str] = []
    for tool in tools:
        tool_path = Path(tool)
        if tool_path.exists():
            prepend.append(str(tool_path.parent))

    if prepend:
        current = env.get("PATH", "")
        env["PATH"] = os.pathsep.join(prepend + ([current] if current else []))
    return env


def write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding=encoding)


def run_command(command: list[str], *, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def parse_realisability(text: str) -> str:
    match = re.search(r"\b(REALIZABLE|UNREALIZABLE)\b", text)
    if not match:
        raise ValueError("ltlsynt did not report REALIZABLE or UNREALIZABLE")
    return match.group(1)


def extract_aiger_payload(text: str) -> str:
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if line.startswith("aag ") or line.startswith("aig "):
            payload = "\n".join(lines[idx:]).strip()
            if payload:
                return payload + "\n"
    raise ValueError("ltlsynt did not emit an AIGER payload")


def extract_symbol_lines(aiger_text: str) -> list[str]:
    symbol_lines: list[str] = []
    for line in aiger_text.splitlines():
        if re.match(r"^[iol]\d+\s+\S", line):
            symbol_lines.append(line)
    return symbol_lines


def declared_symbol_lines() -> list[str]:
    lines = [f"i{idx} {name}" for idx, name in enumerate(ABSTRACT_INPUTS)]
    lines.extend(f"o{idx} {name}" for idx, name in enumerate(PHASE_OUTPUTS))
    return lines


def write_alias_module(path: Path) -> None:
    write_text(
        path,
        """module controller #(
  parameter int INPUT_NEURONS = 4,
  parameter int HIDDEN_NEURONS = 8
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start,
  input  logic [3:0] hidden_idx,
  input  logic [3:0] input_idx,
  output logic [3:0] state,
  output logic       load_input,
  output logic       clear_acc,
  output logic       do_mac_hidden,
  output logic       do_bias_hidden,
  output logic       do_act_hidden,
  output logic       advance_hidden,
  output logic       do_mac_output,
  output logic       do_bias_output,
  output logic       done,
  output logic       busy
);
  controller_spot_compat #(
    .INPUT_NEURONS(INPUT_NEURONS),
    .HIDDEN_NEURONS(HIDDEN_NEURONS)
  ) u_controller_spot_compat (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(state),
    .load_input(load_input),
    .clear_acc(clear_acc),
    .do_mac_hidden(do_mac_hidden),
    .do_bias_hidden(do_bias_hidden),
    .do_act_hidden(do_act_hidden),
    .advance_hidden(advance_hidden),
    .do_mac_output(do_mac_output),
    .do_bias_output(do_bias_output),
    .done(done),
    .busy(busy)
  );
endmodule
""",
    )


def build_translate_script(aiger_path: Path, map_path: Path, output_path: Path) -> str:
    return "\n".join(
        [
            f"read_aiger -module_name controller_spot_core -clk_name clk -map {relative(map_path)} {relative(aiger_path)}",
            "hierarchy -check -top controller_spot_core",
            "opt",
            "clean",
            f"write_verilog -sv -noattr {relative(output_path)}",
        ]
    ) + "\n"


def build_equivalence_script(generated_core: Path, smt2_path: Path) -> str:
    verilog_sources = [
        BASELINE_CONTROLLER,
        COMPAT_WRAPPER,
        generated_core,
        FORMAL_HARNESS,
    ]
    joined = " ".join(relative(path) for path in verilog_sources)
    return "\n".join(
        [
            f"read_verilog -sv -formal {joined}",
            "prep -top formal_controller_spot_equivalence",
            "async2sync",
            "dffunmap",
            f"write_smt2 -wires {relative(smt2_path)}",
        ]
    ) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the rtl-synthesis Spot/ltlsynt flow.")
    parser.add_argument(
        "--ltlsynt",
        default=shutil.which("ltlsynt") or "ltlsynt",
        help="Path to the ltlsynt binary.",
    )
    parser.add_argument(
        "--syfco",
        default=shutil.which("syfco") or "syfco",
        help="Path to the syfco binary used by ltlsynt --tlsf.",
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
        "--build-dir",
        type=Path,
        default=DEFAULT_BUILD_DIR,
        help="Build directory for generated artifacts.",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=DEFAULT_SUMMARY,
        help="JSON path for the synthesis summary.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    for tool in (args.ltlsynt, args.syfco, args.yosys, args.smtbmc, args.solver):
        if not tool_exists(tool):
            raise SystemExit(f"missing required tool: {tool}")

    build_dir = args.build_dir
    generated_dir = build_dir / "generated"
    logs_dir = build_dir / "logs"
    generated_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)

    shared_env = tool_env(args.ltlsynt, args.syfco, args.yosys, args.smtbmc, args.solver)

    realisability_log = logs_dir / "ltlsynt_realisability.log"
    generate_log = logs_dir / "ltlsynt_generate.log"
    translate_script = generated_dir / "translate_controller_spot_core.ys"
    translate_log = logs_dir / "yosys_translate.log"
    equivalence_script = generated_dir / "formal_controller_spot_equivalence.ys"
    equivalence_yosys_log = logs_dir / "yosys_equivalence.log"
    equivalence_smtbmc_log = logs_dir / "yosys_smtbmc_equivalence.log"

    aiger_path = generated_dir / "controller_spot.aag"
    aiger_map_path = generated_dir / "controller_spot.map"
    generated_core_path = generated_dir / "controller_spot_core.sv"
    alias_path = generated_dir / "controller.sv"
    equivalence_smt2 = generated_dir / "formal_controller_spot_equivalence.smt2"

    realisability_proc = run_command(
        [args.ltlsynt, "--tlsf", str(TLSF_SOURCE), "--realizability"],
        env=shared_env,
    )
    realisability_output = (realisability_proc.stdout + realisability_proc.stderr).strip()
    write_text(realisability_log, realisability_output + ("\n" if realisability_output else ""))
    realisability = parse_realisability(realisability_output)

    synthesis_result = "fail"
    translation_result = "skip"
    equivalence_result = "skip"

    if realisability_proc.returncode == 0 and realisability == "REALIZABLE":
        generate_proc = run_command(
            [args.ltlsynt, "--tlsf", str(TLSF_SOURCE), "--aiger", "--verify", "--hide-status"],
            env=shared_env,
        )
        generate_output = (generate_proc.stdout or "") + (generate_proc.stderr or "")
        write_text(generate_log, generate_output + ("\n" if generate_output and not generate_output.endswith("\n") else ""))
        if generate_proc.returncode != 0:
            synthesis_result = "fail"
        else:
            aiger_payload = extract_aiger_payload(generate_proc.stdout)
            write_text(aiger_path, aiger_payload)
            symbol_lines = extract_symbol_lines(aiger_payload) or declared_symbol_lines()
            write_text(aiger_map_path, "\n".join(symbol_lines) + "\n")
            synthesis_result = "pass"

            write_text(translate_script, build_translate_script(aiger_path, aiger_map_path, generated_core_path))
            translate_proc = run_command([args.yosys, "-q", "-s", str(translate_script)], env=shared_env)
            translate_output = (translate_proc.stdout + translate_proc.stderr).strip()
            write_text(translate_log, translate_output + ("\n" if translate_output else ""))
            if translate_proc.returncode == 0 and generated_core_path.exists():
                translation_result = "pass"
                write_alias_module(alias_path)

                write_text(equivalence_script, build_equivalence_script(generated_core_path, equivalence_smt2))
                eq_yosys_proc = run_command([args.yosys, "-q", "-s", str(equivalence_script)], env=shared_env)
                eq_yosys_output = (eq_yosys_proc.stdout + eq_yosys_proc.stderr).strip()
                write_text(equivalence_yosys_log, eq_yosys_output + ("\n" if eq_yosys_output else ""))
                if eq_yosys_proc.returncode == 0:
                    solver_name = Path(args.solver).name
                    eq_smtbmc_proc = run_command(
                        [
                            args.smtbmc,
                            "-s",
                            solver_name,
                            "--presat",
                            "-t",
                            str(EQUIVALENCE_DEPTH),
                            str(equivalence_smt2),
                        ],
                        env=shared_env,
                    )
                    eq_smtbmc_output = (eq_smtbmc_proc.stdout + eq_smtbmc_proc.stderr).strip()
                    write_text(equivalence_smtbmc_log, eq_smtbmc_output + ("\n" if eq_smtbmc_output else ""))
                    if "Status: PASSED" in eq_smtbmc_output and eq_smtbmc_proc.returncode == 0:
                        equivalence_result = "pass"
                    elif "Status: FAILED" in eq_smtbmc_output or eq_smtbmc_proc.returncode != 0:
                        equivalence_result = "fail"
                    else:
                        equivalence_result = "error"
                else:
                    equivalence_result = "error"
            else:
                translation_result = "fail"

    overall_result = "pass" if synthesis_result == "pass" and translation_result == "pass" and equivalence_result == "pass" else "fail"

    ltlsynt_version = tool_version([[args.ltlsynt, "--version"], [args.ltlsynt, "-h"]])
    syfco_version = tool_version([[args.syfco, "--version"], [args.syfco, "-h"]])
    yosys_version = tool_version([[args.yosys, "-V"]])
    smtbmc_version = tool_version([[args.smtbmc, "-h"]], fallback=f"bundled with {yosys_version}")
    solver_version = tool_version([[args.solver, "-version"], [args.solver, "--version"]])

    results = [
        CommandArtifact(
            name="realisability",
            result="pass" if realisability == "REALIZABLE" and realisability_proc.returncode == 0 else "fail",
            command=f"{args.ltlsynt} --tlsf {TLSF_SOURCE} --realizability",
            log=relative(realisability_log),
            artifacts={},
        ),
        CommandArtifact(
            name="aiger_generation",
            result=synthesis_result,
            command=f"{args.ltlsynt} --tlsf {TLSF_SOURCE} --aiger --verify --hide-status",
            log=relative(generate_log),
            artifacts={
                "aiger": relative(aiger_path),
                "aiger_map": relative(aiger_map_path),
            },
        ),
        CommandArtifact(
            name="yosys_translation",
            result=translation_result,
            command=f"{args.yosys} -q -s {relative(translate_script)}",
            log=relative(translate_log),
            artifacts={
                "generated_core": relative(generated_core_path),
                "controller_alias": relative(alias_path),
            },
        ),
        CommandArtifact(
            name="controller_equivalence",
            result=equivalence_result,
            command=(
                f"{args.yosys} -q -s {relative(equivalence_script)} && "
                f"{args.smtbmc} -s {Path(args.solver).name} --presat -t {EQUIVALENCE_DEPTH} {relative(equivalence_smt2)}"
            ),
            log=relative(equivalence_smtbmc_log),
            artifacts={
                "yosys_log": relative(equivalence_yosys_log),
                "smt2": relative(equivalence_smt2),
                "harness": relative(FORMAL_HARNESS),
            },
        ),
    ]

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "overall_result": overall_result,
        "assumption_profile": "exact_schedule_v1",
        "tool": {
            "driver": "python3 rtl-synthesis/controller/run_flow.py",
            "ltlsynt": str(args.ltlsynt),
            "ltlsynt_version": ltlsynt_version,
            "syfco": str(args.syfco),
            "syfco_version": syfco_version,
            "yosys": str(args.yosys),
            "yosys_version": yosys_version,
            "yosys_smtbmc": str(args.smtbmc),
            "yosys_smtbmc_version": smtbmc_version,
            "solver": str(args.solver),
            "solver_version": solver_version,
            "command": (
                f"python3 rtl-synthesis/controller/run_flow.py --ltlsynt {args.ltlsynt} --syfco {args.syfco} "
                f"--yosys {args.yosys} --smtbmc {args.smtbmc} --solver {args.solver} --summary {args.summary}"
            ),
        },
        "claim_scope": CLAIM_SCOPE,
        "sources": {
            "tlsf": relative(TLSF_SOURCE),
            "baseline_controller": relative(BASELINE_CONTROLLER),
            "compat_wrapper": relative(COMPAT_WRAPPER),
            "formal_harness": relative(FORMAL_HARNESS),
            "specs": SPEC_SOURCES,
        },
        "results": [asdict(item) for item in results],
    }

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for item in results:
        print(f"{item.result.upper():4} {item.name}")
    print(f"wrote {args.summary}")
    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
