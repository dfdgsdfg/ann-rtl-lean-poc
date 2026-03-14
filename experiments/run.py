from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[1]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from contract.src.artifacts import read_json  # type: ignore[import-not-found]
    from contract.src.downstream_sync import expected_downstream_artifacts  # type: ignore[import-not-found]
    from contract.src.freeze import SELECTED_RUN_PATH, validate_contract  # type: ignore[import-not-found]
    from contract.src.gen_vectors import (  # type: ignore[import-not-found]
        TEST_VECTORS_META_PATH,
        TEST_VECTORS_PATH,
        expected_vector_artifacts,
    )
    from experiments.common import (  # type: ignore[import-not-found]
        ROOT as REPO_ROOT,
        combine_results,
        command_text,
        ensure_dir,
        relative,
        run_command,
        timestamp_utc,
        tool_exists,
        tool_version,
        write_json,
        write_text,
    )
else:
    from contract.src.artifacts import read_json
    from contract.src.downstream_sync import expected_downstream_artifacts
    from contract.src.freeze import SELECTED_RUN_PATH, validate_contract
    from contract.src.gen_vectors import TEST_VECTORS_META_PATH, TEST_VECTORS_PATH, expected_vector_artifacts
    from experiments.common import (
        ROOT as REPO_ROOT,
        combine_results,
        command_text,
        ensure_dir,
        relative,
        run_command,
        timestamp_utc,
        tool_exists,
        tool_version,
        write_json,
        write_text,
    )
    ROOT = REPO_ROOT


assert ROOT == REPO_ROOT

SIM_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
SIM_INCLUDE_DIR = ROOT / "simulations" / "shared"
BASELINE_RTL = [
    ROOT / "rtl" / "src" / "mac_unit.sv",
    ROOT / "rtl" / "src" / "relu_unit.sv",
    ROOT / "rtl" / "src" / "controller.sv",
    ROOT / "rtl" / "src" / "weight_rom.sv",
    ROOT / "rtl" / "src" / "mlp_core.sv",
]
BASELINE_RTL_NO_CONTROLLER = [
    ROOT / "rtl" / "src" / "mac_unit.sv",
    ROOT / "rtl" / "src" / "relu_unit.sv",
    ROOT / "rtl" / "src" / "weight_rom.sv",
    ROOT / "rtl" / "src" / "mlp_core.sv",
]
SPOT_COMPAT_WRAPPER = ROOT / "experiments" / "rtl-synthesis" / "spot" / "controller_spot_compat.sv"
SPOT_FORMAL_HARNESS = ROOT / "rtl-synthesis" / "controller" / "formal" / "formal_controller_spot_equivalence.sv"
SPOT_AIGER_SNAPSHOT = ROOT / "rel-build" / "generated" / "controller_spot.aag"
SPOT_AIGER_MAP = ROOT / "rel-build" / "generated" / "controller_spot.map"
SPARKLE_FULL_CORE_RTL = ROOT / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_mlp_core.sv"
SPARKLE_FULL_CORE_WRAPPER = ROOT / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_mlp_core_wrapper.sv"
SEMANTIC_BRIDGE_SCRIPT = ROOT / "formalize" / "scripts" / "ExportSemanticBridge.lean"
OPENLANE_TEMPLATE = ROOT / "asic" / "openlane" / "config.json"
OPENLANE_FLOORPLAN = ROOT / "asic" / "openlane" / "floorplan.tcl"
VENDOR_DIR = ROOT / "vendor"
VENDORED_LTLSYNT = VENDOR_DIR / "spot-install" / "bin" / "ltlsynt"
VENDORED_SYFCO = VENDOR_DIR / "syfco-install" / "bin" / "syfco"
VENDORED_OPENLANE_FLOW = VENDOR_DIR / "OpenLane" / "flow.tcl"
SPOT_CLAIM_SCOPE = (
    "bounded (82-cycle) closed-loop mlp_core mixed-path equivalence over a post-reset "
    "accepted transaction window, with the hand-written datapath and shared external "
    "inputs driving both baseline and synthesized-controller assemblies"
)


@dataclass(frozen=True)
class BranchManifest:
    branch: str
    generation_scope: str
    integration_scope: str
    validation_scope: str
    validation_method: str
    claim_scope: str
    source_paths: list[Path]
    artifacts: dict[str, Path]
    provenance: dict[str, object]

    def summary(self) -> dict[str, object]:
        return {
            "branch": self.branch,
            "generation_scope": self.generation_scope,
            "integration_scope": self.integration_scope,
            "validation_scope": self.validation_scope,
            "validation_method": self.validation_method,
            "claim_scope": self.claim_scope,
            "source_files": [relative(path) for path in self.source_paths],
            "artifacts": {name: relative(path) for name, path in self.artifacts.items()},
            "provenance": self.provenance,
        }


def preferred_tool_path(vendored_path: Path, executable_name: str) -> str:
    if vendored_path.exists():
        return str(vendored_path)
    return shutil.which(executable_name) or executable_name


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run repository experiment families.")
    parser.add_argument(
        "--family",
        default="all",
        choices=["all", "artifact-consistency", "semantic-closure", "branch-compare", "qor", "post-synth"],
        help="Experiment family to run.",
    )
    parser.add_argument("--build-root", type=Path, default=ROOT / "build" / "experiments")
    parser.add_argument("--iverilog", default=shutil.which("iverilog") or "iverilog")
    parser.add_argument("--vvp", default=shutil.which("vvp") or "vvp")
    parser.add_argument("--verilator", default=shutil.which("verilator") or "verilator")
    parser.add_argument("--yosys", default=shutil.which("yosys") or "yosys")
    parser.add_argument("--smtbmc", default=shutil.which("yosys-smtbmc") or "yosys-smtbmc")
    parser.add_argument("--z3", default=shutil.which("z3") or "z3")
    parser.add_argument("--lake", default=shutil.which("lake") or "lake")
    parser.add_argument("--ltlsynt", default=preferred_tool_path(VENDORED_LTLSYNT, "ltlsynt"))
    parser.add_argument("--syfco", default=preferred_tool_path(VENDORED_SYFCO, "syfco"))
    parser.add_argument("--openlane-flow", default=preferred_tool_path(VENDORED_OPENLANE_FLOW, "flow.tcl"))
    return parser.parse_args()


def write_command_log(log_path: Path, proc_output: str) -> None:
    write_text(log_path, proc_output if proc_output.endswith("\n") else proc_output + "\n")


def make_step(
    *,
    name: str,
    result: str,
    command: str,
    log_path: Path | None,
    artifacts: dict[str, Path] | None = None,
    details: dict[str, object] | None = None,
) -> dict[str, object]:
    return {
        "name": name,
        "result": result,
        "command": command,
        "log": relative(log_path) if log_path is not None else "",
        "artifacts": {key: relative(path) for key, path in (artifacts or {}).items()},
        "details": details or {},
    }


def write_family_outputs(family_root: Path, summary: dict[str, object], report: str) -> None:
    write_json(family_root / "summary.json", summary)
    write_text(family_root / "report.md", report)


def render_family_report(summary: dict[str, object]) -> str:
    lines = [
        f"# {summary['family'].title()}",
        "",
        f"- overall result: `{summary['overall_result']}`",
        f"- generated at: `{summary['generated_at_utc']}`",
        "",
    ]
    if "claim_scope" in summary:
        lines.append(f"- claim scope: {summary['claim_scope']}")
        lines.append("")
    if "branches" in summary:
        lines.append("## Branches")
        lines.append("")
        for branch in summary["branches"]:
            lines.append(f"### {branch['branch']}")
            lines.append("")
            lines.append(f"- result: `{branch['overall_result']}`")
            lines.append(f"- generation scope: `{branch['generation_scope']}`")
            lines.append(f"- integration scope: `{branch['integration_scope']}`")
            lines.append(f"- validation scope: `{branch['validation_scope']}`")
            lines.append(f"- validation method: `{branch['validation_method']}`")
            for step in branch.get("steps", []):
                lines.append(f"- {step['name']}: `{step['result']}`")
            lines.append("")
    if "results" in summary:
        lines.append("## Results")
        lines.append("")
        for item in summary["results"]:
            label = item.get("name") or item.get("branch") or "result"
            result = item.get("result", item.get("overall_result", "unknown"))
            if "generation_scope" in item:
                lines.append(f"### {label}")
                lines.append("")
                lines.append(f"- result: `{result}`")
                lines.append(f"- generation scope: `{item['generation_scope']}`")
                lines.append(f"- integration scope: `{item['integration_scope']}`")
                lines.append(f"- validation scope: `{item['validation_scope']}`")
                lines.append(f"- validation method: `{item['validation_method']}`")
                if "claim_scope" in item:
                    lines.append(f"- claim scope: {item['claim_scope']}")
                lines.append("")
            else:
                lines.append(f"- {label}: `{result}`")
        if not summary["results"] or "generation_scope" not in summary["results"][0]:
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_root_report(summary: dict[str, object]) -> str:
    lines = [
        "# Experiments",
        "",
        f"- overall result: `{summary['overall_result']}`",
        f"- generated at: `{summary['generated_at_utc']}`",
        "",
        "## Families",
        "",
    ]
    for family in summary["families"]:
        lines.append(f"- `{family['family']}`: `{family['overall_result']}`")
        lines.append(f"  summary: `{family['summary_path']}`")
    lines.append("")
    return "\n".join(lines)


def run_checked_command(command: list[str], *, cwd: Path, log_path: Path) -> tuple[str, str]:
    proc = run_command(command, cwd=cwd)
    output = (proc.stdout or "") + (proc.stderr or "")
    write_command_log(log_path, output or "(no output)\n")
    result = "pass" if proc.returncode == 0 else "fail"
    return result, output


def write_controller_alias_module(path: Path, compat_module_name: str) -> None:
    write_text(
        path,
        f"""module controller #(
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
  ) u_controller_impl (
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


def build_spot_translate_script(aiger_path: Path, map_path: Path, output_path: Path) -> str:
    return "\n".join(
        [
            f"read_aiger -module_name controller_spot_core -clk_name clk -map {relative(map_path)} {relative(aiger_path)}",
            "hierarchy -check -top controller_spot_core",
            "opt",
            "clean",
            f"write_verilog -sv -noattr {relative(output_path)}",
        ]
    ) + "\n"


def build_spot_equivalence_script(generated_core: Path, smt2_path: Path) -> str:
    joined = " ".join(
        relative(path)
        for path in [
            ROOT / "rtl" / "src" / "controller.sv",
            SPOT_COMPAT_WRAPPER,
            generated_core,
            SPOT_FORMAL_HARNESS,
        ]
    )
    return "\n".join(
        [
            f"read_verilog -sv -formal {joined}",
            "prep -top formal_controller_spot_equivalence",
            "async2sync",
            "dffunmap",
            f"write_smt2 -wires {relative(smt2_path)}",
        ]
    ) + "\n"


def spot_core_usable(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    return "module controller_spot_core" in text and "input clk;" in text


def prepare_baseline_branch(branch_root: Path) -> BranchManifest:
    manifest = BranchManifest(
        branch="rtl",
        generation_scope="full-core",
        integration_scope="full-core mlp_core",
        validation_scope="full-core mlp_core",
        validation_method="shared full-core simulation",
        claim_scope="committed hand-written baseline RTL",
        source_paths=list(BASELINE_RTL),
        artifacts={},
        provenance={"source_kind": "committed_rtl"},
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_rtl_synthesis_branch(branch_root: Path, args: argparse.Namespace) -> BranchManifest:
    ensure_dir(branch_root)
    generated_dir = branch_root / "generated"
    logs_dir = branch_root / "logs"
    ensure_dir(generated_dir)
    ensure_dir(logs_dir)
    summary_path = branch_root / "rtl_synthesis_summary.json"

    alias_path = generated_dir / "controller.sv"
    generated_core = generated_dir / "controller_spot_core.sv"
    provenance: dict[str, object]

    if all(tool_exists(tool) for tool in (args.ltlsynt, args.syfco, args.yosys, args.smtbmc, args.z3)):
        command = [
            "python3",
            str(ROOT / "rtl-synthesis" / "controller" / "run_flow.py"),
            "--ltlsynt",
            args.ltlsynt,
            "--syfco",
            args.syfco,
            "--yosys",
            args.yosys,
            "--smtbmc",
            args.smtbmc,
            "--solver",
            args.z3,
            "--build-dir",
            str(branch_root),
            "--summary",
            str(summary_path),
        ]
        log_path = logs_dir / "run_flow.log"
        result, output = run_checked_command(command, cwd=ROOT, log_path=log_path)
        if result == "pass" and spot_core_usable(generated_core):
            provenance = {
                "source_kind": "fresh_flow",
                "summary": relative(summary_path),
                "result": "pass",
                "claim_scope": SPOT_CLAIM_SCOPE,
            }
        else:
            provenance = {
                "source_kind": "fresh_flow_unavailable",
                "summary": relative(summary_path) if summary_path.exists() else "",
                "result": "skip",
                "reason": "generated controller core is unavailable or incompatible in the current environment",
            }
    else:
        if not tool_exists(args.yosys):
            raise RuntimeError("rtl-synthesis fallback requires yosys")
        if not SPOT_AIGER_SNAPSHOT.exists() or not SPOT_AIGER_MAP.exists():
            raise RuntimeError("rtl-synthesis fallback snapshot is missing")

        translate_script = generated_dir / "translate_snapshot.ys"
        translate_log = logs_dir / "translate_snapshot.log"
        write_text(translate_script, build_spot_translate_script(SPOT_AIGER_SNAPSHOT, SPOT_AIGER_MAP, generated_core))
        translate_proc = run_command([args.yosys, "-q", "-s", str(translate_script)], cwd=ROOT)
        translate_output = (translate_proc.stdout or "") + (translate_proc.stderr or "")
        write_command_log(translate_log, translate_output or "(no output)\n")
        if translate_proc.returncode != 0:
            raise RuntimeError(f"rtl-synthesis snapshot translation failed; see {relative(translate_log)}")

        provenance = {
            "source_kind": "committed_aiger_snapshot",
            "aiger_snapshot": relative(SPOT_AIGER_SNAPSHOT),
            "aiger_map": relative(SPOT_AIGER_MAP),
            "translation_log": relative(translate_log),
            "claim_scope": SPOT_CLAIM_SCOPE,
        }

        if tool_exists(args.smtbmc) and tool_exists(args.z3):
            equivalence_script = generated_dir / "formal_controller_spot_equivalence.ys"
            equivalence_smt2 = generated_dir / "formal_controller_spot_equivalence.smt2"
            equivalence_yosys_log = logs_dir / "equivalence_yosys.log"
            equivalence_smtbmc_log = logs_dir / "equivalence_smtbmc.log"
            write_text(equivalence_script, build_spot_equivalence_script(generated_core, equivalence_smt2))

            yosys_proc = run_command([args.yosys, "-q", "-s", str(equivalence_script)], cwd=ROOT)
            yosys_output = (yosys_proc.stdout or "") + (yosys_proc.stderr or "")
            write_command_log(equivalence_yosys_log, yosys_output or "(no output)\n")
            equivalence_result = "error"
            if yosys_proc.returncode == 0:
                solver_name = Path(args.z3).name
                smtbmc_proc = run_command(
                    [args.smtbmc, "-s", solver_name, "--presat", "-t", "80", str(equivalence_smt2)],
                    cwd=ROOT,
                )
                smtbmc_output = (smtbmc_proc.stdout or "") + (smtbmc_proc.stderr or "")
                write_command_log(equivalence_smtbmc_log, smtbmc_output or "(no output)\n")
                if "Status: PASSED" in smtbmc_output and smtbmc_proc.returncode == 0:
                    equivalence_result = "pass"
                elif "Status: FAILED" in smtbmc_output or smtbmc_proc.returncode != 0:
                    equivalence_result = "fail"
            provenance["formal_equivalence"] = {
                "result": equivalence_result,
                "yosys_log": relative(equivalence_yosys_log),
                "smtbmc_log": relative(equivalence_smtbmc_log),
                "smt2": relative(equivalence_smt2),
            }

    usable = spot_core_usable(generated_core)
    if usable and not alias_path.exists():
        write_controller_alias_module(alias_path, "controller_spot_compat")

    manifest = BranchManifest(
        branch="rtl-synthesis",
        generation_scope="controller",
        integration_scope="mixed-path mlp_core",
        validation_scope="mixed-path mlp_core",
        validation_method="bounded controller-formal parity plus shared full-core simulation",
        claim_scope=SPOT_CLAIM_SCOPE if usable else "rtl-synthesis branch skipped because no usable generated controller core is available",
        source_paths=[alias_path, SPOT_COMPAT_WRAPPER, generated_core, *BASELINE_RTL_NO_CONTROLLER] if usable else [],
        artifacts={
            **({"controller_alias": alias_path} if alias_path.exists() else {}),
            **({"generated_core": generated_core} if generated_core.exists() else {}),
            "compat_wrapper": SPOT_COMPAT_WRAPPER,
        },
        provenance={**provenance, "usable_source_set": usable},
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_sparkle_branch(branch_root: Path) -> BranchManifest:
    ensure_dir(branch_root)
    if not SPARKLE_FULL_CORE_RTL.exists():
        raise RuntimeError("missing committed Sparkle full-core generated artifact")
    if not SPARKLE_FULL_CORE_WRAPPER.exists():
        raise RuntimeError("missing committed Sparkle full-core wrapper artifact")

    manifest = BranchManifest(
        branch="rtl-formalize-synthesis",
        generation_scope="full-core",
        integration_scope="full-core mlp_core",
        validation_scope="full-core mlp_core",
        validation_method="shared full-core simulation",
        claim_scope="shared mlp_core full-core comparison between baseline RTL and Sparkle-generated full-core RTL",
        source_paths=[SPARKLE_FULL_CORE_WRAPPER, SPARKLE_FULL_CORE_RTL],
        artifacts={
            "generated_wrapper": SPARKLE_FULL_CORE_WRAPPER,
            "generated_core": SPARKLE_FULL_CORE_RTL,
        },
        provenance={
            "source_kind": "checked_in_generated_full_core",
            "generated_core": relative(SPARKLE_FULL_CORE_RTL),
            "wrapper": relative(SPARKLE_FULL_CORE_WRAPPER),
        },
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_branch_manifests(args: argparse.Namespace, build_root: Path) -> dict[str, BranchManifest]:
    branch_root = build_root / "branches"
    ensure_dir(branch_root)
    manifests = {
        "rtl": prepare_baseline_branch(branch_root / "rtl"),
        "rtl-synthesis": prepare_rtl_synthesis_branch(branch_root / "rtl-synthesis", args),
        "rtl-formalize-synthesis": prepare_sparkle_branch(branch_root / "rtl-formalize-synthesis"),
    }
    return manifests


def check_contract_without_mutation() -> None:
    validate_contract()
    if not TEST_VECTORS_PATH.exists() or not TEST_VECTORS_META_PATH.exists():
        raise FileNotFoundError("expected checked-in vector artifacts are missing")


def run_artifact_consistency_family(args: argparse.Namespace, build_root: Path) -> dict[str, object]:
    family_root = build_root / "artifact-consistency"
    ensure_dir(family_root)
    logs_dir = family_root / "logs"
    ensure_dir(logs_dir)

    freeze_check_log = logs_dir / "freeze_check.log"
    freeze_check_command = ["python3", "-m", "contract.src.freeze", "--check"]
    freeze_check_proc = run_command(freeze_check_command, cwd=ROOT)
    freeze_check_output = (freeze_check_proc.stdout or "") + (freeze_check_proc.stderr or "")
    write_command_log(freeze_check_log, freeze_check_output or "(no output)\n")
    freeze_check_result = "pass" if freeze_check_proc.returncode == 0 else "fail"

    contract_payload = read_json(ROOT / "contract" / "result" / "weights.json")
    downstream = expected_downstream_artifacts(contract_payload)
    vectors = expected_vector_artifacts(contract_payload)

    results = [
        make_step(
            name="freeze_check",
            result=freeze_check_result,
            command=command_text(freeze_check_command),
            log_path=freeze_check_log,
            artifacts={},
            details={
                "checked_artifacts": [relative(path) for path in [*downstream.keys(), *vectors.keys()]],
                "selected_run_metadata": relative(SELECTED_RUN_PATH),
            },
        )
    ]
    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "artifact-consistency",
        "overall_result": combine_results([item["result"] for item in results]),
        "claim_scope": "checked-in frozen contract and downstream artifacts remain synchronized without rewriting tracked files",
        "tool_versions": {
            "python3": tool_version([["python3", "--version"]]),
        },
        "results": results,
        "sources": {
            "contract": "contract/result/weights.json",
            "selected_run": relative(SELECTED_RUN_PATH),
        },
    }
    write_family_outputs(family_root, summary, render_family_report(summary))
    return summary


def compare_semantic_bridge(bridge_path: Path) -> tuple[str, dict[str, object]]:
    bridge = read_json(bridge_path)
    contract = read_json(ROOT / "contract" / "result" / "weights.json")
    mismatches: list[str] = []

    topology = bridge["topology"]
    arithmetic = bridge["arithmetic"]
    weights = bridge["weights"]

    if topology["input_size"] != contract["input_size"]:
        mismatches.append("input_size")
    if topology["hidden_size"] != contract["hidden_size"]:
        mismatches.append("hidden_size")
    if weights["w1"] != contract["w1"]:
        mismatches.append("w1")
    if weights["b1"] != contract["b1"]:
        mismatches.append("b1")
    if weights["w2"] != contract["w2"]:
        mismatches.append("w2")
    if weights["b2"] != contract["b2"]:
        mismatches.append("b2")

    for field in (
        "input_bits",
        "hidden_product_bits",
        "hidden_activation_bits",
        "output_weight_bits",
        "output_product_bits",
        "accumulator_bits",
        "overflow",
        "sign_extension",
    ):
        if arithmetic[field] != contract["arithmetic"][field]:
            mismatches.append(f"arithmetic.{field}")

    if bridge["schedule"]["total_cycles"] != 76:
        mismatches.append("schedule.total_cycles")

    return ("pass" if not mismatches else "fail"), {"mismatches": mismatches}


def run_semantic_closure_family(args: argparse.Namespace, build_root: Path) -> dict[str, object]:
    family_root = build_root / "semantic-closure"
    ensure_dir(family_root)
    logs_dir = family_root / "logs"
    ensure_dir(logs_dir)

    results: list[dict[str, object]] = []
    bridge_path = family_root / "lean_fixed_point_bridge.json"

    export_log = logs_dir / "lean_export.log"
    build_command = [args.lake, "build"]
    export_command = [args.lake, "env", "lean", "--run", str(SEMANTIC_BRIDGE_SCRIPT), str(bridge_path)]
    if tool_exists(args.lake):
        build_proc = run_command(build_command, cwd=ROOT / "formalize")
        build_output = (build_proc.stdout or "") + (build_proc.stderr or "")
        log_chunks = [f"$ {command_text(build_command)}\n{build_output or '(no output)\\n'}"]
        if build_proc.returncode == 0:
            export_proc = run_command(export_command, cwd=ROOT / "formalize")
            export_output = (export_proc.stdout or "") + (export_proc.stderr or "")
            log_chunks.append(f"$ {command_text(export_command)}\n{export_output or '(no output)\\n'}")
            export_result = "pass" if export_proc.returncode == 0 and bridge_path.exists() else "fail"
        else:
            log_chunks.append(f"$ {command_text(export_command)}\n(skipped because lake build failed)\n")
            export_result = "fail"
        write_command_log(export_log, "\n".join(log_chunks))
    else:
        write_command_log(export_log, "missing required tool: lake\n")
        export_result = "fail"
    results.append(
        make_step(
            name="lean_semantic_bridge_export",
            result=export_result,
            command=f"{command_text(build_command)} && {command_text(export_command)}",
            log_path=export_log,
            artifacts={"semantic_bridge": bridge_path} if bridge_path.exists() else {},
        )
    )

    bridge_check_log = logs_dir / "bridge_consistency.log"
    if export_result == "pass":
        bridge_result, bridge_details = compare_semantic_bridge(bridge_path)
        write_text(bridge_check_log, json.dumps(bridge_details, indent=2, sort_keys=True) + "\n")
    else:
        bridge_result = "skip"
        bridge_details = {"reason": "semantic bridge export failed"}
        write_text(bridge_check_log, json.dumps(bridge_details, indent=2, sort_keys=True) + "\n")
    results.append(
        make_step(
            name="lean_bridge_consistency",
            result=bridge_result,
            command="internal semantic bridge vs frozen contract comparison",
            log_path=bridge_check_log,
            artifacts={"semantic_bridge": bridge_path} if bridge_path.exists() else {},
            details=bridge_details,
        )
    )

    overflow_summary = family_root / "contract_overflow_summary.json"
    overflow_log = logs_dir / "contract_overflow.log"
    overflow_command = [
        "python3",
        str(ROOT / "smt" / "contract" / "overflow" / "check_bounds.py"),
        "--z3",
        args.z3,
        "--summary",
        str(overflow_summary),
    ]
    if tool_exists(args.z3):
        overflow_proc = run_command(overflow_command, cwd=ROOT)
        overflow_output = (overflow_proc.stdout or "") + (overflow_proc.stderr or "")
        write_command_log(overflow_log, overflow_output or "(no output)\n")
        overflow_result = "pass" if overflow_proc.returncode == 0 else "fail"
    else:
        write_command_log(overflow_log, "missing required tool: z3\n")
        overflow_result = "fail"
    results.append(
        make_step(
            name="frozen_bounds_check",
            result=overflow_result,
            command=command_text(overflow_command),
            log_path=overflow_log,
            artifacts={"summary": overflow_summary} if overflow_summary.exists() else {},
        )
    )

    equivalence_summary = family_root / "contract_equivalence_summary.json"
    equivalence_log = logs_dir / "contract_equivalence.log"
    equivalence_command = [
        "python3",
        str(ROOT / "smt" / "contract" / "equivalence" / "check_equivalence.py"),
        "--z3",
        args.z3,
        "--summary",
        str(equivalence_summary),
    ]
    if tool_exists(args.z3):
        equivalence_proc = run_command(equivalence_command, cwd=ROOT)
        equivalence_output = (equivalence_proc.stdout or "") + (equivalence_proc.stderr or "")
        write_command_log(equivalence_log, equivalence_output or "(no output)\n")
        equivalence_result = "pass" if equivalence_proc.returncode == 0 else "fail"
    else:
        write_command_log(equivalence_log, "missing required tool: z3\n")
        equivalence_result = "fail"
    results.append(
        make_step(
            name="rtl_datapath_equivalence",
            result=equivalence_result,
            command=command_text(equivalence_command),
            log_path=equivalence_log,
            artifacts={"summary": equivalence_summary} if equivalence_summary.exists() else {},
        )
    )

    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "semantic-closure",
        "overall_result": combine_results([item["result"] for item in results]),
        "claim_scope": "Lean fixed-point semantics are exported as a machine-readable artifact, aligned with the frozen contract, and connected to RTL-style datapath equivalence through solver-backed checks",
        "tool_versions": {
            "python3": tool_version([["python3", "--version"]]),
            "lake": tool_version([[args.lake, "--version"]], cwd=ROOT / "formalize") if tool_exists(args.lake) else "missing",
            "z3": tool_version([[args.z3, "--version"]]) if tool_exists(args.z3) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_root, summary, render_family_report(summary))
    return summary


def run_iverilog_suite(args: argparse.Namespace, sources: list[Path], out_root: Path) -> dict[str, object]:
    ensure_dir(out_root)
    compile_log = out_root / "iverilog_compile.log"
    run_log = out_root / "iverilog_run.log"
    binary = out_root / "testbench.out"
    compile_command = [
        args.iverilog,
        "-g2012",
        f"-I{SIM_INCLUDE_DIR}",
        "-s",
        "testbench",
        "-o",
        str(binary),
        str(SIM_TB),
        *[str(path) for path in sources],
    ]
    if not tool_exists(args.iverilog) or not tool_exists(args.vvp):
        missing = args.iverilog if not tool_exists(args.iverilog) else args.vvp
        write_command_log(compile_log, f"missing required tool: {missing}\n")
        return make_step(
            name="iverilog_sim",
            result="skip",
            command=command_text(compile_command),
            log_path=compile_log,
            details={"reason": f"missing required tool: {missing}"},
        )

    compile_proc = run_command(compile_command, cwd=ROOT)
    compile_output = (compile_proc.stdout or "") + (compile_proc.stderr or "")
    write_command_log(compile_log, compile_output or "(no output)\n")
    if compile_proc.returncode != 0:
        return make_step(
            name="iverilog_sim",
            result="fail",
            command=command_text(compile_command),
            log_path=compile_log,
            artifacts={"binary": binary},
        )

    run_command_args = [args.vvp, str(binary)]
    run_proc = run_command(run_command_args, cwd=ROOT)
    run_output = (run_proc.stdout or "") + (run_proc.stderr or "")
    write_command_log(run_log, run_output or "(no output)\n")
    return make_step(
        name="iverilog_sim",
        result="pass" if run_proc.returncode == 0 else "fail",
        command=command_text(run_command_args),
        log_path=run_log,
        artifacts={"binary": binary},
    )


def run_verilator_suite(args: argparse.Namespace, sources: list[Path], out_root: Path) -> dict[str, object]:
    ensure_dir(out_root)
    compile_log = out_root / "verilator_compile.log"
    run_log = out_root / "verilator_run.log"
    mdir = out_root / "obj_dir"
    binary = mdir / "Vtestbench"
    compile_command = [
        args.verilator,
        "--binary",
        "--timing",
        f"-I{SIM_INCLUDE_DIR}",
        "--Mdir",
        str(mdir),
        str(SIM_TB),
        *[str(path) for path in sources],
    ]
    if not tool_exists(args.verilator):
        write_command_log(compile_log, f"missing required tool: {args.verilator}\n")
        return make_step(
            name="verilator_sim",
            result="skip",
            command=command_text(compile_command),
            log_path=compile_log,
            details={"reason": f"missing required tool: {args.verilator}"},
        )

    compile_proc = run_command(compile_command, cwd=ROOT)
    compile_output = (compile_proc.stdout or "") + (compile_proc.stderr or "")
    write_command_log(compile_log, compile_output or "(no output)\n")
    if compile_proc.returncode != 0:
        return make_step(
            name="verilator_sim",
            result="fail",
            command=command_text(compile_command),
            log_path=compile_log,
            artifacts={"binary": binary},
        )

    run_command_args = [str(binary)]
    run_proc = run_command(run_command_args, cwd=ROOT)
    run_output = (run_proc.stdout or "") + (run_proc.stderr or "")
    write_command_log(run_log, run_output or "(no output)\n")
    return make_step(
        name="verilator_sim",
        result="pass" if run_proc.returncode == 0 else "fail",
        command=command_text(run_command_args),
        log_path=run_log,
        artifacts={"binary": binary},
    )


def run_branch_simulation(args: argparse.Namespace, manifest: BranchManifest, out_root: Path) -> dict[str, object]:
    if not manifest.source_paths:
        skip_log = out_root / "skip.log"
        ensure_dir(skip_log.parent)
        write_command_log(skip_log, "branch source set is unavailable in the current environment\n")
        step = make_step(
            name="full_core_simulation",
            result="skip",
            command="branch simulation",
            log_path=skip_log,
            details={"reason": "branch source set unavailable"},
        )
        return {"overall_result": "skip", "steps": [step]}

    check_contract_without_mutation()
    steps = [
        run_iverilog_suite(args, manifest.source_paths, out_root / "iverilog"),
        run_verilator_suite(args, manifest.source_paths, out_root / "verilator"),
    ]
    return {
        "overall_result": combine_results([step["result"] for step in steps]),
        "steps": steps,
    }


def run_branch_compare_family(args: argparse.Namespace, build_root: Path) -> dict[str, object]:
    family_root = build_root / "branch-compare"
    ensure_dir(family_root)
    manifests = prepare_branch_manifests(args, build_root)
    branches: list[dict[str, object]] = []

    baseline_formal_summary = family_root / "rtl_control_summary.json"
    baseline_formal_log = family_root / "logs" / "rtl_control.log"
    ensure_dir(baseline_formal_log.parent)
    baseline_formal_result = "skip"
    if all(tool_exists(tool) for tool in (args.yosys, args.smtbmc, args.z3)):
        command = [
            "python3",
            str(ROOT / "smt" / "rtl" / "check_control.py"),
            "--yosys",
            args.yosys,
            "--smtbmc",
            args.smtbmc,
            "--solver",
            args.z3,
            "--summary",
            str(baseline_formal_summary),
        ]
        proc = run_command(command, cwd=ROOT)
        output = (proc.stdout or "") + (proc.stderr or "")
        write_command_log(baseline_formal_log, output or "(no output)\n")
        baseline_formal_result = "pass" if proc.returncode == 0 else "fail"
    else:
        write_command_log(baseline_formal_log, "missing yosys/yosys-smtbmc/z3; skipped baseline control proof\n")

    for branch_name, manifest in manifests.items():
        branch_root = family_root / branch_name
        simulation = run_branch_simulation(args, manifest, branch_root / "sim")
        steps = list(simulation["steps"])

        if branch_name == "rtl":
            steps.append(
                make_step(
                    name="rtl_control_formal",
                    result=baseline_formal_result,
                    command="python3 smt/rtl/check_control.py ...",
                    log_path=baseline_formal_log,
                    artifacts={"summary": baseline_formal_summary} if baseline_formal_summary.exists() else {},
                )
            )
            validation_scope = "full-core mlp_core"
            validation_method = "bounded control formal plus shared full-core simulation"
        else:
            formal_provenance = manifest.provenance.get("formal_equivalence")
            if isinstance(formal_provenance, dict):
                steps.append(
                    {
                        "name": "spot_controller_formal",
                        "result": formal_provenance.get("result", "skip"),
                        "command": "fallback committed AIGER equivalence check",
                        "log": formal_provenance.get("smtbmc_log", ""),
                        "artifacts": {
                            key: value
                            for key, value in {
                                "yosys_log": formal_provenance.get("yosys_log", ""),
                                "smt2": formal_provenance.get("smt2", ""),
                            }.items()
                            if value
                        },
                        "details": {},
                    }
                )
            validation_scope = manifest.validation_scope
            validation_method = manifest.validation_method

        branch_result = {
            "branch": branch_name,
            "generation_scope": manifest.generation_scope,
            "integration_scope": manifest.integration_scope,
            "validation_scope": validation_scope,
            "validation_method": validation_method,
            "claim_scope": manifest.claim_scope,
            "overall_result": simulation["overall_result"],
            "evidence_result": combine_results([step["result"] for step in steps]),
            "manifest": manifest.summary(),
            "steps": steps,
        }
        branches.append(branch_result)

    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "branch-compare",
        "overall_result": combine_results([branch["overall_result"] for branch in branches]),
        "tool_versions": {
            "iverilog": tool_version([[args.iverilog, "-V"]]) if tool_exists(args.iverilog) else "missing",
            "verilator": tool_version([[args.verilator, "--version"]]) if tool_exists(args.verilator) else "missing",
            "yosys": tool_version([[args.yosys, "-V"]]) if tool_exists(args.yosys) else "missing",
            "yosys_smtbmc": tool_version([[args.smtbmc, "--version"]]) if tool_exists(args.smtbmc) else "missing",
            "z3": tool_version([[args.z3, "--version"]]) if tool_exists(args.z3) else "missing",
        },
        "branches": branches,
    }
    write_family_outputs(family_root, summary, render_family_report(summary))
    return summary


def build_yosys_qor_script(
    sources: list[Path],
    netlist_path: Path,
    json_path: Path,
    liberty_path: Path | None,
) -> str:
    lines = [
        "read_verilog -sv " + " ".join(relative(path) for path in sources),
        "hierarchy -check -top mlp_core",
        "proc",
        "opt",
        "fsm",
        "opt",
        "memory",
        "opt",
    ]
    if liberty_path is not None:
        lines.extend(
            [
                "synth -top mlp_core",
                f"dfflibmap -liberty {liberty_path}",
                f"abc -liberty {liberty_path}",
                f"stat -liberty {liberty_path}",
            ]
        )
    else:
        lines.extend(["synth -top mlp_core", "stat"])
    lines.extend(
        [
            "check",
            f"write_json {relative(json_path)}",
            f"write_verilog -noattr {relative(netlist_path)}",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_qor_metrics(log_text: str) -> dict[str, object]:
    module_match = re.search(r"=== mlp_core ===\n(.*?)(?=\n=== |\Z)", log_text, re.DOTALL)
    cells = None
    cell_breakdown: dict[str, int] = {}
    if module_match:
        module_text = module_match.group(1)
        total_match = re.search(r"\n\s+(\d+)\s+cells\b", module_text)
        if total_match:
            cells = int(total_match.group(1))
        for count, cell_name in re.findall(r"\n\s+(\d+)\s+(\$_[A-Z0-9_]+)\b", module_text):
            cell_breakdown[cell_name] = int(count)

    area_match = re.search(r"Chip area for module '\\mlp_core':\s*([0-9.eE+-]+)", log_text)
    delay_match = re.search(r"(?:Delay|Critical path)\D+([0-9.eE+-]+)", log_text)
    return {
        "cell_count": cells,
        "cell_breakdown": cell_breakdown,
        "chip_area": float(area_match.group(1)) if area_match else None,
        "timing_estimate": float(delay_match.group(1)) if delay_match else None,
    }


def run_qor_family(args: argparse.Namespace, build_root: Path) -> dict[str, object]:
    family_root = build_root / "qor"
    ensure_dir(family_root)
    manifests = prepare_branch_manifests(args, build_root)
    liberty_env = os.environ.get("SKY130_FD_SC_HD_LIBERTY")
    liberty_path = Path(liberty_env).resolve() if liberty_env else None
    if liberty_path is not None and not liberty_path.exists():
        liberty_path = None

    results: list[dict[str, object]] = []
    for branch_name, manifest in manifests.items():
        branch_root = family_root / branch_name
        ensure_dir(branch_root)
        script_path = branch_root / "qor.ys"
        log_path = branch_root / "yosys.log"
        json_path = branch_root / "mlp_core.json"
        netlist_path = branch_root / "mlp_core.netlist.v"
        if not manifest.source_paths:
            write_command_log(log_path, "branch source set is unavailable in the current environment\n")
            results.append(
                {
                    "branch": branch_name,
                    "generation_scope": manifest.generation_scope,
                    "integration_scope": manifest.integration_scope,
                    "validation_scope": "full-core mlp_core",
                    "validation_method": "qor characterization",
                    "claim_scope": manifest.claim_scope,
                    "result": "skip",
                    "command": "",
                    "log": relative(log_path),
                    "artifacts": {
                        "manifest": relative((build_root / "branches" / branch_name / "manifest.json")),
                    },
                    "metrics": {"cell_count": None, "cell_breakdown": {}, "chip_area": None, "timing_estimate": None},
                    "liberty": relative(liberty_path) if liberty_path is not None else "",
                }
            )
            continue

        write_text(script_path, build_yosys_qor_script(manifest.source_paths, netlist_path, json_path, liberty_path))

        command = [args.yosys, "-s", str(script_path)]
        if not tool_exists(args.yosys):
            write_command_log(log_path, f"missing required tool: {args.yosys}\n")
            result = "fail"
            metrics = {"cell_count": None, "cell_breakdown": {}, "chip_area": None, "timing_estimate": None}
        else:
            proc = run_command(command, cwd=ROOT)
            output = (proc.stdout or "") + (proc.stderr or "")
            write_command_log(log_path, output or "(no output)\n")
            result = "pass" if proc.returncode == 0 else "fail"
            metrics = parse_qor_metrics(output)

        results.append(
            {
                "branch": branch_name,
                "generation_scope": manifest.generation_scope,
                "integration_scope": manifest.integration_scope,
                "validation_scope": "full-core mlp_core",
                "validation_method": "qor characterization",
                "claim_scope": "same-top mlp_core Yosys characterization across baseline RTL, Sparkle full-core RTL, and generated-controller mixed-path RTL",
                "result": result,
                "command": command_text(command),
                "log": relative(log_path),
                "artifacts": {
                    "netlist": relative(netlist_path) if netlist_path.exists() else "",
                    "json": relative(json_path) if json_path.exists() else "",
                    "manifest": relative((build_root / "branches" / branch_name / "manifest.json")),
                },
                "metrics": metrics,
                "liberty": relative(liberty_path) if liberty_path is not None else "",
            }
        )

    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "qor",
        "overall_result": combine_results([item["result"] for item in results]),
        "claim_scope": "branch-tagged QoR data over the same full-core mlp_core top across baseline, Sparkle full-core, and mixed-path generated-controller branches",
        "tool_versions": {
            "yosys": tool_version([[args.yosys, "-V"]]) if tool_exists(args.yosys) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_root, summary, render_family_report(summary))
    return summary


def load_openlane_template() -> dict[str, object]:
    return json.loads(OPENLANE_TEMPLATE.read_text(encoding="utf-8"))


def create_openlane_design_config(branch_root: Path, manifest: BranchManifest) -> Path:
    design_dir = branch_root / "openlane_design"
    ensure_dir(design_dir)
    config_path = design_dir / "config.json"
    floorplan_path = design_dir / "floorplan.tcl"

    config = load_openlane_template()
    config["VERILOG_FILES"] = [str(path.resolve()) for path in manifest.source_paths]
    write_json(config_path, config)
    write_text(floorplan_path, OPENLANE_FLOORPLAN.read_text(encoding="utf-8"))
    return config_path


def discover_openlane_netlist(design_root: Path) -> Path | None:
    for path in design_root.rglob("*.v"):
        if "synthesis" in path.parts and "results" in path.parts:
            return path
    return None


def expand_gls_library_models() -> list[str]:
    model_path = os.environ.get("SKY130_FD_SC_HD_VERILOG", "")
    if not model_path:
        return []
    path = Path(model_path)
    if path.is_file():
        return [str(path)]
    if path.is_dir():
        return [str(candidate) for candidate in sorted(path.glob("*.v"))]
    return []


def run_gate_level_sim(
    args: argparse.Namespace,
    netlist_path: Path,
    out_root: Path,
) -> dict[str, object]:
    compile_log = out_root / "gls_compile.log"
    run_log = out_root / "gls_run.log"
    binary = out_root / "gls.out"
    library_models = expand_gls_library_models()
    if not library_models:
        write_command_log(compile_log, "missing SKY130_FD_SC_HD_VERILOG models for gate-level simulation\n")
        return make_step(
            name="gate_level_sim",
            result="skip",
            command="iverilog gate-level simulation",
            log_path=compile_log,
            details={"reason": "missing SKY130_FD_SC_HD_VERILOG"},
        )

    compile_command = [
        args.iverilog,
        "-g2012",
        f"-I{SIM_INCLUDE_DIR}",
        "-s",
        "testbench",
        "-o",
        str(binary),
        str(SIM_TB),
        str(netlist_path),
        *library_models,
    ]
    compile_proc = run_command(compile_command, cwd=ROOT)
    compile_output = (compile_proc.stdout or "") + (compile_proc.stderr or "")
    write_command_log(compile_log, compile_output or "(no output)\n")
    if compile_proc.returncode != 0:
        return make_step(
            name="gate_level_sim",
            result="fail",
            command=command_text(compile_command),
            log_path=compile_log,
            artifacts={"netlist": netlist_path},
        )

    run_command_args = [args.vvp, str(binary)]
    run_proc = run_command(run_command_args, cwd=ROOT)
    run_output = (run_proc.stdout or "") + (run_proc.stderr or "")
    write_command_log(run_log, run_output or "(no output)\n")
    return make_step(
        name="gate_level_sim",
        result="pass" if run_proc.returncode == 0 else "fail",
        command=command_text(run_command_args),
        log_path=run_log,
        artifacts={"binary": binary, "netlist": netlist_path},
    )


def run_post_synth_family(args: argparse.Namespace, build_root: Path) -> dict[str, object]:
    family_root = build_root / "post-synth"
    ensure_dir(family_root)
    manifests = prepare_branch_manifests(args, build_root)
    results: list[dict[str, object]] = []

    openlane_available = tool_exists(args.openlane_flow)
    pdk_root = os.environ.get("PDK_ROOT", "")

    for branch_name, manifest in manifests.items():
        branch_root = family_root / branch_name
        ensure_dir(branch_root)
        config_path = create_openlane_design_config(branch_root, manifest)
        branch_result: dict[str, object] = {
            "branch": branch_name,
            "generation_scope": manifest.generation_scope,
            "integration_scope": manifest.integration_scope,
            "validation_scope": "full-core mlp_core",
            "validation_method": "post-synthesis validation",
            "claim_scope": "OpenLane-oriented post-synthesis setup plus gate-level replay when flow artifacts and library models are available",
            "result": "skip",
            "artifacts": {"openlane_config": relative(config_path)},
            "steps": [],
        }

        if not openlane_available:
            skip_log = branch_root / "openlane.log"
            write_command_log(skip_log, f"missing required tool: {args.openlane_flow}\n")
            branch_result["steps"].append(
                make_step(
                    name="openlane_flow",
                    result="skip",
                    command=args.openlane_flow,
                    log_path=skip_log,
                    artifacts={"openlane_config": config_path},
                    details={"reason": "missing flow.tcl/openlane flow entrypoint"},
                )
            )
            results.append(branch_result)
            continue

        if not pdk_root:
            skip_log = branch_root / "openlane.log"
            write_command_log(skip_log, "missing required environment variable: PDK_ROOT\n")
            branch_result["steps"].append(
                make_step(
                    name="openlane_flow",
                    result="skip",
                    command=args.openlane_flow,
                    log_path=skip_log,
                    artifacts={"openlane_config": config_path},
                    details={"reason": "missing PDK_ROOT"},
                )
            )
            results.append(branch_result)
            continue

        run_log = branch_root / "openlane.log"
        command = [args.openlane_flow, "-design", str(config_path.parent), "-tag", f"experiments_{branch_name}", "-overwrite"]
        proc = run_command(command, cwd=ROOT)
        output = (proc.stdout or "") + (proc.stderr or "")
        write_command_log(run_log, output or "(no output)\n")
        flow_result = "pass" if proc.returncode == 0 else "fail"
        branch_result["steps"].append(
            make_step(
                name="openlane_flow",
                result=flow_result,
                command=command_text(command),
                log_path=run_log,
                artifacts={"openlane_config": config_path},
            )
        )

        if flow_result == "pass":
            netlist_path = discover_openlane_netlist(config_path.parent)
            if netlist_path is not None:
                branch_result["artifacts"]["post_synth_netlist"] = relative(netlist_path)
                branch_result["steps"].append(run_gate_level_sim(args, netlist_path, branch_root / "gls"))
            else:
                missing_log = branch_root / "gls" / "gate_level_sim.log"
                ensure_dir(missing_log.parent)
                write_command_log(missing_log, "no synthesized netlist found in OpenLane run outputs\n")
                branch_result["steps"].append(
                    make_step(
                        name="gate_level_sim",
                        result="skip",
                        command="iverilog gate-level simulation",
                        log_path=missing_log,
                        details={"reason": "no synthesized netlist found"},
                    )
                )

        branch_result["result"] = combine_results([step["result"] for step in branch_result["steps"]])
        results.append(branch_result)

    overall_result = combine_results([item["result"] for item in results])
    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "post-synth",
        "overall_result": overall_result,
        "tool_versions": {
            "openlane_flow": tool_version([[args.openlane_flow, "--version"]]) if tool_exists(args.openlane_flow) else "missing",
            "iverilog": tool_version([[args.iverilog, "-V"]]) if tool_exists(args.iverilog) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_root, summary, render_family_report(summary))
    return summary


def run_selected_families(args: argparse.Namespace) -> list[dict[str, object]]:
    build_root = args.build_root.resolve()
    ensure_dir(build_root)
    families: list[dict[str, object]] = []

    dispatch = {
        "artifact-consistency": run_artifact_consistency_family,
        "semantic-closure": run_semantic_closure_family,
        "branch-compare": run_branch_compare_family,
        "qor": run_qor_family,
        "post-synth": run_post_synth_family,
    }

    if args.family == "all":
        selected = ["artifact-consistency", "semantic-closure", "branch-compare", "qor", "post-synth"]
    else:
        selected = [args.family]

    for family_name in selected:
        families.append(dispatch[family_name](args, build_root))
    return families


def main() -> int:
    args = parse_args()
    families = run_selected_families(args)
    build_root = args.build_root.resolve()
    family_rows = [
        {
            "family": family["family"],
            "overall_result": family["overall_result"],
            "summary_path": relative(build_root / family["family"] / "summary.json"),
        }
        for family in families
    ]
    if args.family == "all":
        summary = {
            "generated_at_utc": timestamp_utc(),
            "overall_result": combine_results([family["overall_result"] for family in families]),
            "families": family_rows,
        }
        write_json(build_root / "summary.json", summary)
        write_text(build_root / "report.md", render_root_report(summary))
        print(f"wrote {build_root / 'summary.json'}")
        return 0 if summary["overall_result"] not in {"fail", "error"} else 1

    family = families[0]
    print(f"wrote {build_root / family['family'] / 'summary.json'}")
    return 0 if family["overall_result"] not in {"fail", "error"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
