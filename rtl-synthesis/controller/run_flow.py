from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot

DOMAIN_ROOT = ROOT / "rtl-synthesis" / "controller"
DEFAULT_BUILD_ROOT = ROOT / "build" / "rtl-synthesis"
DEFAULT_REPORT_ROOT = ROOT / "reports" / "rtl-synthesis"
DEFAULT_BUILD_DIR = DEFAULT_BUILD_ROOT / "canonical" / "flow" / "spot"
DEFAULT_SUMMARY = DEFAULT_REPORT_ROOT / "canonical" / "flow" / "spot" / "summary.json"
VENDOR_DIR = ROOT / "vendor"
VENDORED_LTLSYNT = VENDOR_DIR / "spot-install" / "bin" / "ltlsynt"
VENDORED_SYFCO = VENDOR_DIR / "syfco-install" / "bin" / "syfco"

TLSF_SOURCE = DOMAIN_ROOT / "controller.tlsf"
FORMAL_INTERFACE_HARNESS = DOMAIN_ROOT / "formal" / "formal_controller_spot_equivalence.sv"
FORMAL_CLOSED_LOOP_HARNESS = DOMAIN_ROOT / "formal" / "formal_closed_loop_mlp_core_equivalence.sv"
BASELINE_CONTROLLER = ROOT / "rtl" / "results" / "canonical" / "sv" / "controller.sv"
BASELINE_MLP_CORE = ROOT / "rtl" / "results" / "canonical" / "sv" / "mlp_core.sv"
SHARED_DATAPATH_SOURCES = [
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
]
COMPAT_WRAPPER = ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_compat.sv"

SPEC_SOURCES = [
    "specs/rtl-synthesis/requirement.md",
    "specs/rtl-synthesis/design.md",
    "experiments/implementation-branch-comparison.md",
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

PRIMARY_EQUIVALENCE_DEPTH = 82
SECONDARY_EQUIVALENCE_DEPTH = 80
PRIMARY_CLAIM_SCOPE = (
    f"bounded ({PRIMARY_EQUIVALENCE_DEPTH}-cycle) closed-loop mlp_core mixed-path equivalence "
    "over a post-reset accepted transaction window, with the hand-written datapath and "
    "shared external inputs driving both baseline and synthesized-controller assemblies"
)
SECONDARY_CLAIM_SCOPE = (
    f"bounded ({SECONDARY_EQUIVALENCE_DEPTH}-cycle) sampled controller-interface equivalence "
    "through MAC_OUTPUT, BIAS_OUTPUT, DONE, and DONE hold/release under "
    "exact_schedule_v1 assumptions"
)


@dataclass(frozen=True)
class LoweredTlsf:
    inputs: list[str]
    outputs: list[str]
    preset: list[str]
    require: list[str]
    assertions: list[str]
    guarantees: list[str]
    formula: str


def preferred_tool_path(vendored_path: Path, executable_name: str) -> str:
    if vendored_path.exists():
        return str(vendored_path)
    return shutil.which(executable_name) or executable_name


@dataclass
class CommandArtifact:
    name: str
    result: str
    command: str
    log: str
    artifacts: dict[str, str]
    details: dict[str, object]


def rooted_path(path: Path) -> Path:
    return path if path.is_absolute() else (ROOT / path).resolve()


def relative(path: Path) -> str:
    resolved = rooted_path(path)
    try:
        return str(resolved.relative_to(ROOT))
    except ValueError:
        return str(resolved)


def tool_exists(tool: str) -> bool:
    return Path(tool).exists() or shutil.which(tool) is not None


def resolve_executable(tool: str) -> Path | None:
    tool_path = Path(tool)
    if tool_path.exists():
        return tool_path.resolve()
    resolved = shutil.which(tool)
    if resolved is None:
        return None
    return Path(resolved).resolve()


def first_output_line(proc: subprocess.CompletedProcess[str]) -> str:
    text = (proc.stdout + proc.stderr).strip()
    return text.splitlines()[0].strip() if text else "unknown"


def tool_version(commands: list[list[str]], fallback: str = "unknown") -> str:
    for command in commands:
        try:
            proc = subprocess.run(
                command,
                text=True,
                capture_output=True,
                check=False,
            )
        except OSError:
            continue
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


def prepend_path(env: dict[str, str], path: Path) -> dict[str, str]:
    updated = env.copy()
    current = updated.get("PATH", "")
    updated["PATH"] = os.pathsep.join([str(path)] + ([current] if current else []))
    return updated


def write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding=encoding)


def write_executable_shim(path: Path, command: list[str]) -> None:
    quoted = " ".join(shlex.quote(part) for part in command)
    write_text(path, f"#!/bin/sh\nexec {quoted} \"$@\"\n")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


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


def extract_braced_block(text: str, label: str) -> str:
    match = re.search(rf"\b{re.escape(label)}\s*\{{", text)
    if match is None:
        raise ValueError(f"missing TLSF section: {label}")
    idx = match.end()
    depth = 1
    start = idx
    while idx < len(text):
        char = text[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:idx]
        idx += 1
    raise ValueError(f"unterminated TLSF section: {label}")


def split_tlsf_entries(text: str) -> list[str]:
    return [entry.strip() for entry in text.split(";") if entry.strip()]


def conjunct(formulas: list[str]) -> str:
    if not formulas:
        return "true"
    if len(formulas) == 1:
        return f"({formulas[0]})"
    return "(" + " && ".join(f"({formula})" for formula in formulas) + ")"


def normalize_formula_whitespace(formula: str) -> str:
    return re.sub(r"\s+", " ", formula).strip()


def lower_tlsf_spec(path: Path) -> LoweredTlsf:
    text = path.read_text(encoding="utf-8")
    main_body = extract_braced_block(text, "MAIN")
    inputs = split_tlsf_entries(extract_braced_block(main_body, "INPUTS"))
    outputs = split_tlsf_entries(extract_braced_block(main_body, "OUTPUTS"))
    preset = split_tlsf_entries(extract_braced_block(main_body, "PRESET"))
    require = split_tlsf_entries(extract_braced_block(main_body, "REQUIRE"))
    assertions = split_tlsf_entries(extract_braced_block(main_body, "ASSERT"))
    guarantees = split_tlsf_entries(extract_braced_block(main_body, "GUARANTEE"))
    formula = f"({conjunct(require)}) -> ({conjunct([*preset, *assertions, *guarantees])})"
    return LoweredTlsf(
        inputs=inputs,
        outputs=outputs,
        preset=preset,
        require=require,
        assertions=assertions,
        guarantees=guarantees,
        formula=formula,
    )


def ltlsynt_problem_args(*, syfco: str, lowered_formula_path: Path, lowered_tlsf: LoweredTlsf) -> tuple[list[str], str]:
    if tool_exists(syfco):
        return ["--tlsf", str(TLSF_SOURCE)], "native_tlsf_via_syfco"
    return [
        "--file",
        str(lowered_formula_path),
        "--ins",
        ",".join(lowered_tlsf.inputs),
        "--outs",
        ",".join(lowered_tlsf.outputs),
    ], "local_tlsf_lowering"


def prepare_solver_env(
    *,
    solver_name: str,
    solver_bin: str,
    launcher_dir: Path,
    env: dict[str, str],
) -> tuple[dict[str, str], str | None]:
    resolved_solver = resolve_executable(solver_bin)
    if resolved_solver is None or resolved_solver.name == solver_name:
        return env, None

    launcher_path = launcher_dir / solver_name
    write_executable_shim(launcher_path, [str(resolved_solver)])
    return prepend_path(env, launcher_dir), relative(launcher_path)


def write_alias_module(path: Path, module_name: str, compat_module_name: str) -> None:
    write_text(
        path,
        f"""module {module_name} #(
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
  {compat_module_name} #(
    .INPUT_NEURONS(INPUT_NEURONS),
    .HIDDEN_NEURONS(HIDDEN_NEURONS)
  ) u_{compat_module_name} (
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


def replace_once(text: str, pattern: str, replacement: str, description: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"failed to rewrite {description}")
    return updated


def write_baseline_controller_copy(path: Path) -> None:
    text = BASELINE_CONTROLLER.read_text(encoding="utf-8")
    text = replace_once(text, r"^module\s+controller\b", "module baseline_controller", "baseline controller module name")
    write_text(path, text)


def write_mlp_core_copy(path: Path, module_name: str, controller_module_name: str) -> None:
    text = BASELINE_MLP_CORE.read_text(encoding="utf-8")
    text = replace_once(text, r"^module\s+mlp_core\b", f"module {module_name}", f"{module_name} module name")
    text = replace_once(
        text,
        r"(^\s*)controller(\s+u_controller\s*\()",
        rf"\1{controller_module_name}\2",
        f"{module_name} controller instance",
    )
    write_text(path, text)


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


def build_controller_interface_script(generated_core: Path, smt2_path: Path) -> str:
    verilog_sources = [
        BASELINE_CONTROLLER,
        COMPAT_WRAPPER,
        generated_core,
        FORMAL_INTERFACE_HARNESS,
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


def build_closed_loop_script(
    generated_core: Path,
    baseline_controller_copy: Path,
    generated_controller_copy: Path,
    baseline_mlp_core_copy: Path,
    generated_mlp_core_copy: Path,
    smt2_path: Path,
) -> str:
    verilog_sources = [
        *SHARED_DATAPATH_SOURCES,
        baseline_controller_copy,
        COMPAT_WRAPPER,
        generated_core,
        generated_controller_copy,
        baseline_mlp_core_copy,
        generated_mlp_core_copy,
        FORMAL_CLOSED_LOOP_HARNESS,
    ]
    joined = " ".join(relative(path) for path in verilog_sources)
    return "\n".join(
        [
            f"read_verilog -sv -formal {joined}",
            "prep -top formal_closed_loop_mlp_core_equivalence",
            "async2sync",
            "dffunmap",
            f"write_smt2 -wires {relative(smt2_path)}",
        ]
    ) + "\n"


def run_equivalence_job(
    *,
    name: str,
    script_path: Path,
    script_text: str,
    yosys_log: Path,
    smtbmc_log: Path,
    smt2_path: Path,
    depth: int,
    yosys_bin: str,
    smtbmc_bin: str,
    solver_name: str,
    env: dict[str, str],
) -> tuple[str, str, str, dict[str, object]]:
    write_text(script_path, script_text)
    yosys_proc = run_command([yosys_bin, "-q", "-s", str(script_path)], env=env)
    yosys_output = (yosys_proc.stdout + yosys_proc.stderr).strip()
    write_text(yosys_log, yosys_output + ("\n" if yosys_output else ""))
    if yosys_proc.returncode != 0:
        write_text(smtbmc_log, "")
        return (
            "error",
            relative(yosys_log),
            relative(smtbmc_log),
            {"reason": f"yosys exited with code {yosys_proc.returncode}"},
        )

    smtbmc_proc = run_command(
        [
            smtbmc_bin,
            "-s",
            solver_name,
            "--presat",
            "-t",
            str(depth),
            str(smt2_path),
        ],
        env=env,
    )
    smtbmc_output = (smtbmc_proc.stdout + smtbmc_proc.stderr).strip()
    write_text(smtbmc_log, smtbmc_output + ("\n" if smtbmc_output else ""))
    if "Status: PASSED" in smtbmc_output and smtbmc_proc.returncode == 0:
        return "pass", relative(yosys_log), relative(smtbmc_log), {}
    if "Status: FAILED" in smtbmc_output:
        return (
            "fail",
            relative(yosys_log),
            relative(smtbmc_log),
            {"reason": "smt proof reported FAILED"},
        )
    if smtbmc_proc.returncode != 0:
        return (
            "error",
            relative(yosys_log),
            relative(smtbmc_log),
            {"reason": f"yosys-smtbmc exited with code {smtbmc_proc.returncode}"},
        )
    return (
        "error",
        relative(yosys_log),
        relative(smtbmc_log),
        {"reason": f"{name} did not report PASSED or FAILED"},
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the rtl-synthesis Spot/ltlsynt flow.")
    parser.add_argument(
        "--ltlsynt",
        default=preferred_tool_path(VENDORED_LTLSYNT, "ltlsynt"),
        help="Path to the ltlsynt binary.",
    )
    parser.add_argument(
        "--syfco",
        default=preferred_tool_path(VENDORED_SYFCO, "syfco"),
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
        "--solver-name",
        default="z3",
        help="Solver kind passed to yosys-smtbmc -s (for example: z3 or cvc5).",
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="Runtime build root for run snapshots and canonical artifacts.",
    )
    parser.add_argument(
        "--report-root",
        type=Path,
        default=DEFAULT_REPORT_ROOT,
        help="Runtime report root for run snapshots and canonical summaries.",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="Optional run id for runtime artifact provenance mode.",
    )
    parser.add_argument(
        "--build-dir",
        type=Path,
        default=None,
        help="Explicit build directory for generated artifacts. Overrides --build-root provenance mode.",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=None,
        help="Explicit JSON path for the synthesis summary. Overrides --report-root provenance mode.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    explicit_output_mode = args.build_dir is not None or args.summary is not None
    snapshot = None
    if explicit_output_mode:
        build_dir = rooted_path(args.build_dir or DEFAULT_BUILD_DIR)
        summary_path = rooted_path(args.summary or DEFAULT_SUMMARY)
    else:
        snapshot = prepare_snapshot(
            build_root=rooted_path(args.build_root),
            report_root=rooted_path(args.report_root),
            run_id=args.run_id or build_run_id("rtl-synthesis", "spot"),
            subpath="flow/spot",
        )
        build_dir = snapshot.build_run_dir
        summary_path = snapshot.report_run_dir / "summary.json"
    generated_dir = build_dir / "generated"
    logs_dir = build_dir / "logs"
    generated_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)
    lowered_formula_path = generated_dir / "controller_spec.ltl"
    lowered_partition_path = generated_dir / "controller_partition.json"
    lowered_tlsf = lower_tlsf_spec(TLSF_SOURCE)
    write_text(lowered_formula_path, normalize_formula_whitespace(lowered_tlsf.formula) + "\n")
    write_text(
        lowered_partition_path,
        json.dumps(
            {
                "inputs": lowered_tlsf.inputs,
                "outputs": lowered_tlsf.outputs,
                "preset": lowered_tlsf.preset,
                "require": lowered_tlsf.require,
                "assert": lowered_tlsf.assertions,
                "guarantee": lowered_tlsf.guarantees,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
    )

    env_tools = [args.ltlsynt, args.yosys, args.smtbmc, args.solver]
    if tool_exists(args.syfco):
        env_tools.insert(1, args.syfco)
    shared_env = tool_env(*env_tools)
    shared_env, solver_launcher = prepare_solver_env(
        solver_name=args.solver_name,
        solver_bin=args.solver,
        launcher_dir=generated_dir / "tool-shims",
        env=shared_env,
    )

    realisability_log = logs_dir / "ltlsynt_realisability.log"
    generate_log = logs_dir / "ltlsynt_generate.log"
    translate_script = generated_dir / "translate_controller_spot_core.ys"
    translate_log = logs_dir / "yosys_translate.log"
    controller_equivalence_script = generated_dir / "formal_controller_spot_equivalence.ys"
    controller_equivalence_yosys_log = logs_dir / "yosys_controller_equivalence.log"
    controller_equivalence_smtbmc_log = logs_dir / "yosys_smtbmc_controller_equivalence.log"
    closed_loop_equivalence_script = generated_dir / "formal_closed_loop_mlp_core_equivalence.ys"
    closed_loop_equivalence_yosys_log = logs_dir / "yosys_closed_loop_equivalence.log"
    closed_loop_equivalence_smtbmc_log = logs_dir / "yosys_smtbmc_closed_loop_equivalence.log"

    aiger_path = generated_dir / "controller_spot.aag"
    aiger_map_path = generated_dir / "controller_spot.map"
    generated_core_path = generated_dir / "controller_spot_core.sv"
    controller_alias_path = generated_dir / "controller.sv"
    generated_controller_copy = generated_dir / "generated_controller.sv"
    baseline_controller_copy = generated_dir / "baseline_controller.sv"
    baseline_mlp_core_copy = generated_dir / "baseline_mlp_core.sv"
    generated_mlp_core_copy = generated_dir / "generated_mlp_core.sv"
    controller_equivalence_smt2 = generated_dir / "formal_controller_spot_equivalence.smt2"
    closed_loop_equivalence_smt2 = generated_dir / "formal_closed_loop_mlp_core_equivalence.smt2"

    realisability = "unknown"
    realisability_result = "skip"
    realisability_details: dict[str, object] = {}
    synthesis_result = "skip"
    synthesis_details: dict[str, object] = {}
    translation_result = "skip"
    translation_details: dict[str, object] = {}
    controller_equivalence_result = "skip"
    controller_equivalence_details: dict[str, object] = {}
    closed_loop_equivalence_result = "skip"
    closed_loop_equivalence_details: dict[str, object] = {}
    problem_args, input_lowering = ltlsynt_problem_args(
        syfco=args.syfco,
        lowered_formula_path=lowered_formula_path,
        lowered_tlsf=lowered_tlsf,
    )

    tool_failures = [
        tool
        for tool in (args.ltlsynt, args.yosys, args.smtbmc, args.solver)
        if not tool_exists(tool)
    ]

    if tool_failures:
        missing = ", ".join(tool_failures)
        realisability_result = "error"
        realisability_details = {"reason": f"missing required tool(s): {missing}"}
        synthesis_details = {"reason": "realisability step did not pass"}
        translation_details = {"reason": "aiger generation step did not pass"}
        controller_equivalence_details = {"reason": "yosys translation step did not pass"}
        closed_loop_equivalence_details = {"reason": "yosys translation step did not pass"}
        write_text(realisability_log, f"missing required tool(s): {missing}\n")
        write_text(generate_log, "")
        write_text(translate_log, "")
        write_text(controller_equivalence_yosys_log, "")
        write_text(controller_equivalence_smtbmc_log, "")
        write_text(closed_loop_equivalence_yosys_log, "")
        write_text(closed_loop_equivalence_smtbmc_log, "")
    else:
        realisability_proc = run_command(
            [args.ltlsynt, *problem_args, "--realizability"],
            env=shared_env,
        )
        realisability_output = (realisability_proc.stdout + realisability_proc.stderr).strip()
        write_text(realisability_log, realisability_output + ("\n" if realisability_output else ""))
        if realisability_proc.returncode != 0:
            realisability_result = "error"
            realisability_details = {"reason": f"ltlsynt exited with code {realisability_proc.returncode}"}
        else:
            try:
                realisability = parse_realisability(realisability_output)
            except ValueError as exc:
                realisability_result = "error"
                realisability_details = {"reason": str(exc)}
            else:
                if realisability == "REALIZABLE":
                    realisability_result = "pass"
                else:
                    realisability_result = "fail"
                    realisability_details = {"reported_status": realisability}

        if realisability_result == "pass":
            generate_proc = run_command(
                [args.ltlsynt, *problem_args, "--aiger", "--verify", "--hide-status"],
                env=shared_env,
            )
            generate_output = (generate_proc.stdout or "") + (generate_proc.stderr or "")
            write_text(generate_log, generate_output + ("\n" if generate_output and not generate_output.endswith("\n") else ""))
            if generate_proc.returncode != 0:
                synthesis_result = "fail"
                synthesis_details = {"reason": f"ltlsynt exited with code {generate_proc.returncode}"}
            else:
                try:
                    aiger_payload = extract_aiger_payload(generate_proc.stdout)
                except ValueError as exc:
                    synthesis_result = "error"
                    synthesis_details = {"reason": str(exc)}
                else:
                    write_text(aiger_path, aiger_payload)
                    symbol_lines = extract_symbol_lines(aiger_payload) or declared_symbol_lines()
                    write_text(aiger_map_path, "\n".join(symbol_lines) + "\n")
                    synthesis_result = "pass"

            if synthesis_result == "pass":
                write_text(translate_script, build_translate_script(aiger_path, aiger_map_path, generated_core_path))
                translate_proc = run_command([args.yosys, "-q", "-s", str(translate_script)], env=shared_env)
                translate_output = (translate_proc.stdout + translate_proc.stderr).strip()
                write_text(translate_log, translate_output + ("\n" if translate_output else ""))
                if translate_proc.returncode == 0 and generated_core_path.exists():
                    translation_result = "pass"
                    write_alias_module(controller_alias_path, "controller", "controller_spot_compat")
                    write_alias_module(generated_controller_copy, "generated_controller", "controller_spot_compat")
                    write_baseline_controller_copy(baseline_controller_copy)
                    write_mlp_core_copy(baseline_mlp_core_copy, "baseline_mlp_core", "baseline_controller")
                    write_mlp_core_copy(generated_mlp_core_copy, "generated_mlp_core", "generated_controller")

                    (
                        controller_equivalence_result,
                        _,
                        _,
                        controller_equivalence_details,
                    ) = run_equivalence_job(
                        name="controller_interface_equivalence",
                        script_path=controller_equivalence_script,
                        script_text=build_controller_interface_script(generated_core_path, controller_equivalence_smt2),
                        yosys_log=controller_equivalence_yosys_log,
                        smtbmc_log=controller_equivalence_smtbmc_log,
                        smt2_path=controller_equivalence_smt2,
                        depth=SECONDARY_EQUIVALENCE_DEPTH,
                        yosys_bin=args.yosys,
                        smtbmc_bin=args.smtbmc,
                        solver_name=args.solver_name,
                        env=shared_env,
                    )
                    (
                        closed_loop_equivalence_result,
                        _,
                        _,
                        closed_loop_equivalence_details,
                    ) = run_equivalence_job(
                        name="closed_loop_mlp_core_equivalence",
                        script_path=closed_loop_equivalence_script,
                        script_text=build_closed_loop_script(
                            generated_core_path,
                            baseline_controller_copy,
                            generated_controller_copy,
                            baseline_mlp_core_copy,
                            generated_mlp_core_copy,
                            closed_loop_equivalence_smt2,
                        ),
                        yosys_log=closed_loop_equivalence_yosys_log,
                        smtbmc_log=closed_loop_equivalence_smtbmc_log,
                        smt2_path=closed_loop_equivalence_smt2,
                        depth=PRIMARY_EQUIVALENCE_DEPTH,
                        yosys_bin=args.yosys,
                        smtbmc_bin=args.smtbmc,
                        solver_name=args.solver_name,
                        env=shared_env,
                    )
                else:
                    translation_result = "fail"
                    if translate_proc.returncode != 0:
                        translation_details = {"reason": f"yosys exited with code {translate_proc.returncode}"}
                    else:
                        translation_details = {"reason": "translated controller core was not written"}
                    controller_equivalence_details = {"reason": "yosys translation step did not pass"}
                    closed_loop_equivalence_details = {"reason": "yosys translation step did not pass"}
            else:
                write_text(translate_log, "")
                translation_details = {"reason": "aiger generation step did not pass"}
                controller_equivalence_details = {"reason": "yosys translation step did not pass"}
                closed_loop_equivalence_details = {"reason": "yosys translation step did not pass"}
        else:
            write_text(generate_log, "")
            write_text(translate_log, "")
            synthesis_details = {"reason": "realisability step did not pass"}
            translation_details = {"reason": "aiger generation step did not pass"}
            controller_equivalence_details = {"reason": "yosys translation step did not pass"}
            closed_loop_equivalence_details = {"reason": "yosys translation step did not pass"}

        if controller_equivalence_result == "skip":
            write_text(controller_equivalence_yosys_log, "")
            write_text(controller_equivalence_smtbmc_log, "")
        if closed_loop_equivalence_result == "skip":
            write_text(closed_loop_equivalence_yosys_log, "")
            write_text(closed_loop_equivalence_smtbmc_log, "")

    overall_result = "pass"
    for result in (
        realisability_result,
        synthesis_result,
        translation_result,
        controller_equivalence_result,
        closed_loop_equivalence_result,
    ):
        if result != "pass":
            overall_result = "fail"
            break

    failure_reason = None
    for details in (
        realisability_details,
        synthesis_details,
        translation_details,
        controller_equivalence_details,
        closed_loop_equivalence_details,
    ):
        reason = details.get("reason")
        if isinstance(reason, str) and reason:
            failure_reason = reason
            break

    ltlsynt_version = tool_version([[args.ltlsynt, "--version"], [args.ltlsynt, "-h"]])
    syfco_version = (
        tool_version([[args.syfco, "--version"], [args.syfco, "-h"]])
        if tool_exists(args.syfco)
        else "not used (local tlsf lowering)"
    )
    yosys_version = tool_version([[args.yosys, "-V"]])
    smtbmc_version = tool_version([[args.smtbmc, "-h"]], fallback=f"bundled with {yosys_version}")
    solver_version = tool_version([[args.solver, "-version"], [args.solver, "--version"]])

    results = [
        CommandArtifact(
            name="realisability",
            result=realisability_result,
            command=" ".join(
                [args.ltlsynt, *problem_args, "--realizability"]
            ),
            log=relative(realisability_log),
            artifacts={},
            details=realisability_details,
        ),
        CommandArtifact(
            name="aiger_generation",
            result=synthesis_result,
            command=" ".join(
                [args.ltlsynt, *problem_args, "--aiger", "--verify", "--hide-status"]
            ),
            log=relative(generate_log),
            artifacts={
                "aiger": relative(aiger_path),
                "aiger_map": relative(aiger_map_path),
            },
            details=synthesis_details,
        ),
        CommandArtifact(
            name="yosys_translation",
            result=translation_result,
            command=f"{args.yosys} -q -s {relative(translate_script)}",
            log=relative(translate_log),
            artifacts={
                "generated_core": relative(generated_core_path),
                "controller_alias": relative(controller_alias_path),
                "generated_controller_copy": relative(generated_controller_copy),
                "baseline_controller_copy": relative(baseline_controller_copy),
                "baseline_mlp_core_copy": relative(baseline_mlp_core_copy),
                "generated_mlp_core_copy": relative(generated_mlp_core_copy),
                **({"solver_launcher": solver_launcher} if solver_launcher is not None else {}),
            },
            details=translation_details,
        ),
        CommandArtifact(
            name="controller_interface_equivalence",
            result=controller_equivalence_result,
            command=(
                f"{args.yosys} -q -s {relative(controller_equivalence_script)} && "
                f"{args.smtbmc} -s {args.solver_name} --presat -t {SECONDARY_EQUIVALENCE_DEPTH} "
                f"{relative(controller_equivalence_smt2)}"
            ),
            log=relative(controller_equivalence_smtbmc_log),
            artifacts={
                "yosys_log": relative(controller_equivalence_yosys_log),
                "smt2": relative(controller_equivalence_smt2),
                "harness": relative(FORMAL_INTERFACE_HARNESS),
            },
            details=controller_equivalence_details,
        ),
        CommandArtifact(
            name="closed_loop_mlp_core_equivalence",
            result=closed_loop_equivalence_result,
            command=(
                f"{args.yosys} -q -s {relative(closed_loop_equivalence_script)} && "
                f"{args.smtbmc} -s {args.solver_name} --presat -t {PRIMARY_EQUIVALENCE_DEPTH} "
                f"{relative(closed_loop_equivalence_smt2)}"
            ),
            log=relative(closed_loop_equivalence_smtbmc_log),
            artifacts={
                "yosys_log": relative(closed_loop_equivalence_yosys_log),
                "smt2": relative(closed_loop_equivalence_smt2),
                "harness": relative(FORMAL_CLOSED_LOOP_HARNESS),
            },
            details=closed_loop_equivalence_details,
        ),
    ]

    generated_at_utc = datetime.now(timezone.utc).isoformat(timespec="seconds")
    summary = {
        "generated_at_utc": generated_at_utc,
        "overall_result": overall_result,
        "assumption_profile": "exact_schedule_v1",
        "primary_claim_scope": PRIMARY_CLAIM_SCOPE,
        "secondary_claim_scope": SECONDARY_CLAIM_SCOPE,
        "claim_scope": PRIMARY_CLAIM_SCOPE,
        **({"failure_reason": failure_reason} if failure_reason is not None else {}),
        "input_lowering": {
            "kind": input_lowering,
            "formula": relative(lowered_formula_path),
            "partition": relative(lowered_partition_path),
            "syfco": str(args.syfco),
            "syfco_used": input_lowering == "native_tlsf_via_syfco",
        },
        "tool": {
            "driver": "python3 rtl-synthesis/runners/spot_flow.py",
            "ltlsynt": str(args.ltlsynt),
            "ltlsynt_version": ltlsynt_version,
            "syfco": str(args.syfco),
            "syfco_version": syfco_version,
            "yosys": str(args.yosys),
            "yosys_version": yosys_version,
            "yosys_smtbmc": str(args.smtbmc),
            "yosys_smtbmc_version": smtbmc_version,
            "solver": str(args.solver),
            "solver_name": args.solver_name,
            "solver_version": solver_version,
            "command": (
                f"python3 rtl-synthesis/runners/spot_flow.py --ltlsynt {args.ltlsynt} --syfco {args.syfco} "
                f"--yosys {args.yosys} --smtbmc {args.smtbmc} --solver {args.solver} --solver-name {args.solver_name} "
                f"--build-dir {relative(build_dir)} --summary {relative(summary_path)}"
            ),
        },
        "sources": {
            "tlsf": relative(TLSF_SOURCE),
            "lowered_formula": relative(lowered_formula_path),
            "lowered_partition": relative(lowered_partition_path),
            "baseline_controller": relative(BASELINE_CONTROLLER),
            "baseline_mlp_core": relative(BASELINE_MLP_CORE),
            "compat_wrapper": relative(COMPAT_WRAPPER),
            "formal_controller_interface_harness": relative(FORMAL_INTERFACE_HARNESS),
            "formal_closed_loop_harness": relative(FORMAL_CLOSED_LOOP_HARNESS),
            "specs": SPEC_SOURCES,
        },
        "results": [asdict(item) for item in results],
    }

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if snapshot is not None:
        promote_snapshot(
            snapshot,
            source="rtl_synthesis_spot_flow",
            created_at_utc=generated_at_utc,
            inputs={
                "tlsf": relative(TLSF_SOURCE),
                "solver_name": args.solver_name,
                "input_lowering": input_lowering,
            },
            commands={"driver": summary["tool"]["command"]},
            tool_versions={
                "ltlsynt": ltlsynt_version,
                "syfco": syfco_version,
                "yosys": yosys_version,
                "yosys_smtbmc": smtbmc_version,
                "solver": solver_version,
            },
            artifacts={
                "build_dir": relative(build_dir),
                "generated_dir": relative(generated_dir),
                "logs_dir": relative(logs_dir),
            },
            reports={"summary": relative(summary_path)},
        )

    for item in results:
        print(f"{item.result.upper():4} {item.name}")
    print(f"wrote {summary_path}")
    return 0 if overall_result == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
