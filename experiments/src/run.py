from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from contract.src.artifacts import ANN_CANONICAL_MANIFEST_PATH, read_json  # type: ignore[import-not-found]
    from contract.src.downstream_sync import expected_downstream_artifacts  # type: ignore[import-not-found]
    from contract.src.freeze import validate_contract  # type: ignore[import-not-found]
    from contract.src.gen_vectors import (  # type: ignore[import-not-found]
        TEST_VECTORS_META_PATH,
        TEST_VECTORS_PATH,
        expected_vector_artifacts,
    )
    from experiments.src.common import (  # type: ignore[import-not-found]
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
    from runners.sparkle_proof_lane import (  # type: ignore[import-not-found]
        build_sparkle_proof_lane_env,
        load_selected_sparkle_proof_lane,
    )
    from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot  # type: ignore[import-not-found]
else:
    from contract.src.artifacts import ANN_CANONICAL_MANIFEST_PATH, read_json
    from contract.src.downstream_sync import expected_downstream_artifacts
    from contract.src.freeze import validate_contract
    from contract.src.gen_vectors import TEST_VECTORS_META_PATH, TEST_VECTORS_PATH, expected_vector_artifacts
    from experiments.src.common import (
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
    from runners.sparkle_proof_lane import build_sparkle_proof_lane_env, load_selected_sparkle_proof_lane
    from runners.runtime_artifacts import build_run_id, prepare_snapshot, promote_snapshot
    ROOT = REPO_ROOT


assert ROOT == REPO_ROOT

SIM_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
SIM_INTERNAL_TB = ROOT / "simulations" / "rtl" / "testbench_internal.sv"
SIM_INCLUDE_DIR = ROOT / "simulations" / "shared"
BASELINE_RTL = [
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "controller.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mlp_core.sv",
]
BASELINE_RTL_NO_CONTROLLER = [
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
    ROOT / "rtl" / "results" / "canonical" / "sv" / "mlp_core.sv",
]
SPOT_COMPAT_WRAPPER = ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_compat.sv"
SPARKLE_PROJECT_DIR = ROOT / "rtl-formalize-synthesis"
FORMALIZE_SMT_ROOT = ROOT / "formalize-smt"
SPARKLE_LAKEFILE = SPARKLE_PROJECT_DIR / "lakefile.lean"
SPARKLE_PREPARE_SCRIPT = SPARKLE_PROJECT_DIR / "scripts" / "prepare_sparkle.sh"
SPARKLE_PROOF_CONFIG = SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "ProofConfig.lean"
SPARKLE_PROOF_LANE_CONFIG_SCRIPT = SPARKLE_PROJECT_DIR / "scripts" / "configure_proof_lane.py"
SPARKLE_WRAPPER_GENERATOR = SPARKLE_PROJECT_DIR / "scripts" / "generate_wrapper.py"
SPARKLE_BACKEND_METADATA_EXPORT = SPARKLE_PROJECT_DIR / "scripts" / "export_backend_metadata.lean"
SPARKLE_VERIFICATION_REFRESH = SPARKLE_PROJECT_DIR / "scripts" / "refresh_verification_manifest.py"
SPARKLE_PATCH_PATH = SPARKLE_PROJECT_DIR / "patches" / "sparkle-local.patch"
SPARKLE_LEAN_TOOLCHAIN = SPARKLE_PROJECT_DIR / "lean-toolchain"
SPARKLE_LAKE_MANIFEST = SPARKLE_PROJECT_DIR / "lake-manifest.json"
SPARKLE_FULL_CORE_RTL = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv"
SPARKLE_FULL_CORE_WRAPPER = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv"
SPARKLE_VERIFICATION_MANIFEST = (
    ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "verification_manifest.json"
)
SEMANTIC_BRIDGE_SCRIPT = ROOT / "formalize" / "scripts" / "ExportSemanticBridge.lean"
OPENLANE_TEMPLATE = ROOT / "asic" / "openlane" / "config.json"
OPENLANE_FLOORPLAN = ROOT / "asic" / "openlane" / "floorplan.tcl"
VENDOR_DIR = ROOT / "vendor"
VENDORED_LTLSYNT = VENDOR_DIR / "spot-install" / "bin" / "ltlsynt"
VENDORED_SYFCO = VENDOR_DIR / "syfco-install" / "bin" / "syfco"
VENDORED_OPENLANE_FLOW = VENDOR_DIR / "OpenLane" / "flow.tcl"
SOFT_GATE_EXPERIMENT = "soft-gate experiment"
SPOT_CLAIM_SCOPE = (
    "bounded (82-cycle) closed-loop mlp_core mixed-path equivalence over a post-reset "
    "accepted transaction window, with the hand-written datapath and shared external "
    "inputs driving both baseline and synthesized-controller assemblies"
)
QOR_METRICS_BASIS = "full_core_aggregate"
TOP_LEVEL_BENCH_KIND = "shared_full_core_top_level_bench"
INTERNAL_OBSERVABILITY_BENCH_KIND = "internal_observability_bench"
GATE_LEVEL_BENCH_KIND = "shared_full_core_gate_level_bench"
RTL_SYNTHESIS_FLOW_STEP_ORDER = (
    "realisability",
    "aiger_generation",
    "yosys_translation",
    "controller_interface_equivalence",
    "closed_loop_mlp_core_equivalence",
)
SPARKLE_FEATURE_SLICE_CONSTRUCTS = [
    "Signal.loop",
    "Signal.pure",
    "hw_cond",
    "BitVec.append",
    "BitVec.extractLsb'",
    "BitVec.ult",
    "declare_signal_state",
]
BASELINE_BLUEPRINT = ROOT / "rtl" / "results" / "canonical" / "blueprint" / "mlp_core.svg"
RTL_SYNTHESIS_CANONICAL_RTL = [
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mac_unit.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "relu_unit.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_compat.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_core.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "weight_rom.sv",
    ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv",
]
RTL_SYNTHESIS_BLUEPRINT = ROOT / "rtl-synthesis" / "results" / "canonical" / "blueprint" / "mlp_core.svg"
SPARKLE_BLUEPRINT = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "blueprint" / "mlp_core.svg"


@dataclass(frozen=True)
class BranchManifest:
    branch: str
    artifact_kind: str
    assembly_boundary: str
    evidence_boundary: str
    evidence_method: str
    experiment_status: str
    claim_scope: str
    source_paths: list[Path]
    artifacts: dict[str, Path]
    provenance: dict[str, object]
    simulation_profile: dict[str, object] | None = None

    def summary(self) -> dict[str, object]:
        summary = {
            "branch": self.branch,
            "artifact_kind": self.artifact_kind,
            "assembly_boundary": self.assembly_boundary,
            "evidence_boundary": self.evidence_boundary,
            "evidence_method": self.evidence_method,
            "experiment_status": self.experiment_status,
            "claim_scope": self.claim_scope,
            "source_files": [relative(path) for path in self.source_paths],
            "artifacts": {name: relative(path) for name, path in self.artifacts.items()},
            "provenance": self.provenance,
        }
        if self.simulation_profile is not None:
            summary["simulation_profile"] = self.simulation_profile
        return summary


def preferred_tool_path(vendored_path: Path, executable_name: str) -> str:
    if vendored_path.exists():
        return str(vendored_path)
    return shutil.which(executable_name) or executable_name


BOUNDARY_METADATA_LABELS = (
    ("artifact_kind", "artifact kind"),
    ("assembly_boundary", "assembly boundary"),
    ("evidence_boundary", "evidence boundary"),
    ("evidence_method", "evidence method"),
)


def make_simulation_profile(
    *,
    bench_kind: str,
    required_simulators: list[str],
    bench_path: Path = SIM_TB,
    vector_artifacts: list[Path] | None = None,
) -> dict[str, object]:
    return {
        "bench_kind": bench_kind,
        "bench_path": relative(bench_path),
        "vector_artifacts": [relative(path) for path in (vector_artifacts or [TEST_VECTORS_PATH, TEST_VECTORS_META_PATH])],
        "required_simulators": required_simulators,
    }


def has_boundary_metadata(payload: dict[str, object]) -> bool:
    return (
        any(key in payload for key, _ in BOUNDARY_METADATA_LABELS)
        or "experiment_status" in payload
        or "claim_scope" in payload
        or "simulation_profile" in payload
    )


def append_boundary_metadata(lines: list[str], payload: dict[str, object]) -> None:
    for key, label in BOUNDARY_METADATA_LABELS:
        value = payload.get(key)
        if isinstance(value, str) and value:
            lines.append(f"- {label}: `{value}`")
    experiment_status = payload.get("experiment_status")
    if isinstance(experiment_status, str) and experiment_status:
        lines.append(f"- experiment status: `{experiment_status}`")
    if "claim_scope" in payload:
        lines.append(f"- claim scope: {payload['claim_scope']}")

    simulation_profile = payload.get("simulation_profile")
    if not isinstance(simulation_profile, dict):
        return

    bench_kind = simulation_profile.get("bench_kind")
    if isinstance(bench_kind, str) and bench_kind:
        lines.append(f"- simulation bench kind: `{bench_kind}`")

    bench_path = simulation_profile.get("bench_path")
    if isinstance(bench_path, str) and bench_path:
        lines.append(f"- simulation bench path: `{bench_path}`")

    vector_artifacts = simulation_profile.get("vector_artifacts")
    if isinstance(vector_artifacts, list) and vector_artifacts:
        lines.append(f"- simulation vector artifacts: `{', '.join(str(path) for path in vector_artifacts)}`")

    required_simulators = simulation_profile.get("required_simulators")
    if isinstance(required_simulators, list) and required_simulators:
        lines.append(f"- required simulators: `{', '.join(str(tool) for tool in required_simulators)}`")

    simulator_results = simulation_profile.get("simulator_results")
    if isinstance(simulator_results, dict) and simulator_results:
        rendered = ", ".join(f"{name}={result}" for name, result in sorted(simulator_results.items()))
        lines.append(f"- simulator results: `{rendered}`")


def with_simulator_results(
    simulation_profile: dict[str, object] | None,
    steps: list[dict[str, object]],
) -> dict[str, object] | None:
    if simulation_profile is None:
        return None

    step_to_simulator = {
        "iverilog_sim": "iverilog",
        "verilator_sim": "verilator",
        "gate_level_sim": "iverilog",
    }
    simulator_results = {
        simulator: step["result"]
        for step in steps
        if (simulator := step_to_simulator.get(str(step.get("name", "")))) is not None
    }
    if not simulator_results:
        return simulation_profile

    enriched = dict(simulation_profile)
    enriched["simulator_results"] = simulator_results
    return enriched


def simulator_step_details(*, bench_kind: str, bench_path: Path, gating: bool) -> dict[str, object]:
    return {
        "bench_kind": bench_kind,
        "bench_path": relative(bench_path),
        "gating": gating,
    }


def step_is_gating(step: dict[str, object]) -> bool:
    details = step.get("details")
    if not isinstance(details, dict):
        return True
    return details.get("gating", True) is not False


def normalize_branch_result(result: str) -> str:
    if result == "error":
        return "fail"
    return result


def combine_branch_results(results: list[str]) -> str:
    return combine_results([normalize_branch_result(result) for result in results])


def rtl_synthesis_flow_command(args: argparse.Namespace, branch_root: Path, summary_path: Path) -> list[str]:
    return [
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


def missing_rtl_synthesis_tools(args: argparse.Namespace) -> list[str]:
    return [
        label
        for label, tool in (
            ("ltlsynt", args.ltlsynt),
            ("yosys", args.yosys),
            ("yosys-smtbmc", args.smtbmc),
            ("z3", args.z3),
        )
        if not tool_exists(tool)
    ]


def resolve_repo_path(path_value: object) -> Path | None:
    if not isinstance(path_value, str) or not path_value:
        return None
    path = Path(path_value)
    return path if path.is_absolute() else ROOT / path


def load_rtl_synthesis_flow_summary(summary_path: Path) -> tuple[dict[str, object] | None, str | None]:
    if not summary_path.exists():
        return None, "rtl-synthesis fresh flow did not write a summary"
    try:
        payload = read_json(summary_path)
    except Exception as exc:  # pragma: no cover - defensive parse guard
        return None, f"rtl-synthesis fresh flow summary could not be parsed: {exc}"
    if not isinstance(payload, dict):
        return None, "rtl-synthesis fresh flow summary was not a JSON object"
    return payload, None


def normalize_recorded_step(payload: dict[str, object]) -> dict[str, object]:
    artifacts_value = payload.get("artifacts", {})
    details_value = payload.get("details", {})
    artifacts = {str(key): str(value) for key, value in artifacts_value.items()} if isinstance(artifacts_value, dict) else {}
    details = {str(key): value for key, value in details_value.items()} if isinstance(details_value, dict) else {}
    return {
        "name": str(payload.get("name", "unknown")),
        "result": str(payload.get("result", "fail")),
        "command": str(payload.get("command", "")),
        "log": str(payload.get("log", "")),
        "artifacts": artifacts,
        "details": details,
    }


def rtl_synthesis_flow_steps_from_summary(summary: dict[str, object]) -> list[dict[str, object]]:
    results_value = summary.get("results")
    if not isinstance(results_value, list):
        return [
            {
                "name": "rtl_synthesis_flow_summary",
                "result": "fail",
                "command": "",
                "log": "",
                "artifacts": {},
                "details": {"reason": "rtl-synthesis fresh flow summary is missing its results list"},
            }
        ]

    by_name = {
        item.get("name"): item
        for item in results_value
        if isinstance(item, dict) and isinstance(item.get("name"), str)
    }
    steps: list[dict[str, object]] = []
    missing_steps: list[str] = []
    for name in RTL_SYNTHESIS_FLOW_STEP_ORDER:
        payload = by_name.get(name)
        if not isinstance(payload, dict):
            missing_steps.append(name)
            continue
        steps.append(normalize_recorded_step(payload))

    if missing_steps:
        steps.append(
            {
                "name": "rtl_synthesis_flow_summary",
                "result": "fail",
                "command": "",
                "log": "",
                "artifacts": {},
                "details": {"reason": f"rtl-synthesis fresh flow summary is missing required steps: {', '.join(missing_steps)}"},
            }
        )
    return steps


def rtl_synthesis_flow_steps_from_manifest(manifest: BranchManifest) -> list[dict[str, object]]:
    source_kind = manifest.provenance.get("source_kind")
    command = str(manifest.provenance.get("command", "python3 rtl-synthesis/runners/spot_flow.py ..."))
    if source_kind == "fresh_flow_unavailable":
        return [
            {
                "name": "rtl_synthesis_fresh_flow",
                "result": "skip",
                "command": command,
                "log": "",
                "artifacts": {},
                "details": {"reason": manifest.provenance.get("reason", "required fresh-flow toolchain is unavailable")},
            }
        ]

    summary_path = resolve_repo_path(manifest.provenance.get("summary"))
    if summary_path is not None:
        summary, error = load_rtl_synthesis_flow_summary(summary_path)
        if summary is not None:
            return rtl_synthesis_flow_steps_from_summary(summary)
        log_path = resolve_repo_path(manifest.provenance.get("run_flow_log"))
        return [
            {
                "name": "rtl_synthesis_fresh_flow",
                "result": "fail",
                "command": command,
                "log": relative(log_path) if log_path is not None else "",
                "artifacts": {"summary": relative(summary_path)},
                "details": {"reason": error or "rtl-synthesis fresh flow summary was unavailable"},
            }
        ]

    log_path = resolve_repo_path(manifest.provenance.get("run_flow_log"))
    return [
        {
            "name": "rtl_synthesis_fresh_flow",
            "result": "fail",
            "command": command,
            "log": relative(log_path) if log_path is not None else "",
            "artifacts": {},
            "details": {"reason": manifest.provenance.get("reason", "rtl-synthesis fresh flow did not record proof results")},
        }
    ]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run repository experiment families.")
    parser.add_argument(
        "--family",
        default="all",
        choices=["all", "artifact-consistency", "semantic-closure", "branch-compare", "qor", "post-synth"],
        help="Experiment family to run.",
    )
    parser.add_argument("--build-root", type=Path, default=ROOT / "build" / "experiments")
    parser.add_argument("--report-root", type=Path, default=ROOT / "reports" / "experiments")
    parser.add_argument("--run-id", default=None)
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
    return parser.parse_args(argv)


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


def write_family_outputs(report_root: Path, summary: dict[str, object], report: str) -> None:
    write_json(report_root / "summary.json", summary)
    write_text(report_root / "report.md", report)


def render_family_report(summary: dict[str, object]) -> str:
    lines = [
        f"# {summary['family'].title()}",
        "",
        f"- overall result: `{summary['overall_result']}`",
        f"- generated at: `{summary['generated_at_utc']}`",
        "",
    ]
    if has_boundary_metadata(summary):
        append_boundary_metadata(lines, summary)
        lines.append("")
    if "branches" in summary:
        lines.append("## Branches")
        lines.append("")
        for branch in summary["branches"]:
            lines.append(f"### {branch['branch']}")
            lines.append("")
            lines.append(f"- result: `{branch['overall_result']}`")
            if "simulation_result" in branch:
                lines.append(f"- simulation result: `{branch['simulation_result']}`")
            if "evidence_result" in branch and branch["evidence_result"] != branch["overall_result"]:
                lines.append(f"- evidence result: `{branch['evidence_result']}`")
            if "secondary_result" in branch:
                lines.append(f"- secondary result: `{branch['secondary_result']}`")
            append_boundary_metadata(lines, branch)
            for step in branch.get("steps", []):
                lines.append(f"- {step['name']}: `{step['result']}`")
            lines.append("")
    if "results" in summary:
        lines.append("## Results")
        lines.append("")
        for item in summary["results"]:
            label = item.get("name") or item.get("branch") or "result"
            result = item.get("result", item.get("overall_result", "unknown"))
            if has_boundary_metadata(item):
                lines.append(f"### {label}")
                lines.append("")
                lines.append(f"- result: `{result}`")
                append_boundary_metadata(lines, item)
                lines.append("")
            else:
                lines.append(f"- {label}: `{result}`")
        if not summary["results"] or not has_boundary_metadata(summary["results"][0]):
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


def empty_qor_metrics() -> dict[str, object]:
    return {"cell_count": None, "cell_breakdown": {}, "chip_area": None, "timing_estimate": None}


def make_contract_validation_result(
    step: dict[str, object],
    *,
    claim_scope: str,
    evidence_boundary: str,
    evidence_method: str,
) -> dict[str, object]:
    return {
        "name": str(step["name"]),
        "result": str(step["result"]),
        "artifact_kind": "frozen_contract_bundle",
        "assembly_boundary": "contract_downstream_bundle",
        "evidence_boundary": evidence_boundary,
        "evidence_method": evidence_method,
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "claim_scope": claim_scope,
        "command": step["command"],
        "log": step["log"],
        "artifacts": step["artifacts"],
        "details": step["details"],
    }


def format_mtime_utc(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(timespec="seconds")


def sparkle_generated_full_core_emit_sources() -> list[Path]:
    return [
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "Emit.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "Types.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "ControllerSignal.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "ContractData.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "DatapathSignal.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "MlpCoreSignal.lean",
        SPARKLE_PATCH_PATH,
        SPARKLE_LEAN_TOOLCHAIN,
        SPARKLE_LAKE_MANIFEST,
        SPARKLE_LAKEFILE,
        SPARKLE_PREPARE_SCRIPT,
    ]


def sparkle_generated_full_core_proof_sources() -> list[Path]:
    return [
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle.lean",
        SPARKLE_PROOF_CONFIG,
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "Refinement.lean",
        SPARKLE_PROJECT_DIR / "src" / "MlpCoreSparkle" / "BackendSemantics.lean",
        SPARKLE_PROOF_LANE_CONFIG_SCRIPT,
        SPARKLE_BACKEND_METADATA_EXPORT,
        SPARKLE_VERIFICATION_REFRESH,
    ]


def sparkle_generated_full_core_wrapper_inputs() -> list[Path]:
    return [
        SPARKLE_FULL_CORE_RTL,
        SPARKLE_WRAPPER_GENERATOR,
    ]


def load_sparkle_verification_manifest() -> dict[str, object]:
    payload = read_json(SPARKLE_VERIFICATION_MANIFEST)
    if not isinstance(payload, dict):
        raise ValueError("verification manifest must be a JSON object")
    return payload


def sparkle_proof_lane_from_manifest_payload(payload: dict[str, object]) -> dict[str, str]:
    proof_lane = payload.get("proof_lane")
    if not isinstance(proof_lane, dict):
        raise ValueError("verification manifest is missing proof_lane metadata")

    normalized: dict[str, str] = {}
    for key in ("name", "lean_namespace", "package", "arithmetic_provider", "trust_profile", "trust_note"):
        value = proof_lane.get(key)
        if not isinstance(value, str) or not value:
            raise ValueError(f"verification manifest proof_lane.{key} must be a non-empty string")
        normalized[key] = value

    selected_config = proof_lane.get("selected_config")
    if isinstance(selected_config, str) and selected_config:
        normalized["selected_config"] = selected_config
    return normalized


def maybe_load_sparkle_proof_lane() -> dict[str, str] | None:
    try:
        return sparkle_proof_lane_from_manifest_payload(load_sparkle_verification_manifest())
    except Exception:
        return None


def current_sparkle_proof_lane(export_payload: dict[str, object]) -> dict[str, str]:
    current: dict[str, str] = {}
    for key, export_key in (
        ("name", "proof_lane"),
        ("lean_namespace", "proof_namespace"),
        ("package", "proof_package"),
        ("arithmetic_provider", "arithmetic_provider"),
        ("trust_profile", "trust_profile"),
        ("trust_note", "trust_note"),
    ):
        value = export_payload.get(export_key)
        if not isinstance(value, str) or not value:
            raise RuntimeError(f"backend metadata export did not provide a valid {export_key}")
        current[key] = value
    current["selected_config"] = relative(SPARKLE_PROOF_CONFIG)
    return current


def export_current_sparkle_backend_metadata() -> tuple[dict[str, object], str]:
    command = [
        "lake",
        "env",
        "lean",
        "--run",
        str(SPARKLE_BACKEND_METADATA_EXPORT),
    ]
    proc = run_command(
        command,
        cwd=SPARKLE_PROJECT_DIR,
        env=build_sparkle_proof_lane_env(root=ROOT),
    )
    output = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if proc.returncode != 0:
        raise RuntimeError(output or "backend metadata export failed")
    try:
        payload = json.loads(output)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"backend metadata export did not return valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("backend metadata export must return a JSON object")
    return payload, command_text(command)


def current_sparkle_backend_fingerprints(export_payload: dict[str, object]) -> dict[str, str]:
    design_repr = str(export_payload.get("design_repr", ""))
    verilog_text = str(export_payload.get("verilog_text", ""))
    return {
        "decl_name": str(export_payload.get("decl_name", "")),
        "typed_backend_ir": str(export_payload.get("typed_backend_ir", "")),
        "top_module": str(export_payload.get("top_module", "")),
        "module_count": str(export_payload.get("module_count", "")),
        "elaborated_design_fingerprint": sha256_text(design_repr),
        "backend_ast_fingerprint": sha256_text(design_repr),
        "verilog_render_fingerprint": sha256_text(verilog_text),
        "raw_artifact_fingerprint": sha256_file(SPARKLE_FULL_CORE_RTL),
        "local_patch_id": sha256_file(SPARKLE_PATCH_PATH),
    }


def git_head_revision(repo_dir: Path) -> str:
    if not (repo_dir / ".git").exists():
        return "unknown"
    proc = run_command(["git", "-C", str(repo_dir), "rev-parse", "HEAD"], cwd=ROOT)
    if proc.returncode != 0:
        return "unknown"
    return ((proc.stdout or "") + (proc.stderr or "")).strip().splitlines()[0].strip() or "unknown"


def check_sparkle_feature_slice(manifest_payload: dict[str, object]) -> tuple[list[str], dict[str, list[str]]]:
    feature_slice = manifest_payload.get("sparkle_feature_slice")
    if not isinstance(feature_slice, dict):
        return (["missing sparkle_feature_slice object"], {})
    declared_constructs = feature_slice.get("constructs")
    if declared_constructs != SPARKLE_FEATURE_SLICE_CONSTRUCTS:
        return (
            [
                "sparkle_feature_slice.constructs does not match the repository-declared feature slice"
            ],
            {},
        )

    emit_sources = sparkle_generated_full_core_emit_sources()
    hit_map: dict[str, list[str]] = {}
    missing_constructs: list[str] = []
    for token in SPARKLE_FEATURE_SLICE_CONSTRUCTS:
        hits: list[str] = []
        for path in emit_sources:
            if not path.exists():
                continue
            if token in path.read_text(encoding="utf-8"):
                hits.append(relative(path))
        if not hits:
            missing_constructs.append(token)
        hit_map[token] = hits
    if missing_constructs:
        return (
            [f"declared feature-slice token not found in current emit sources: {token}" for token in missing_constructs],
            hit_map,
        )
    return ([], hit_map)


def classify_sparkle_validation_failure(output: str) -> tuple[str, str]:
    if "wrapper check failed" in output:
        return (
            "wrapper_mismatch",
            "checked-in Sparkle stable wrapper does not match the raw Sparkle RTL plus wrapper generator; "
            "regenerate with `make rtl-formalize-synthesis-emit`",
        )
    if "emitted subset validation failed" in output:
        return (
            "emitted_subset_mismatch",
            "checked-in Sparkle generated core no longer matches the declared emitted subset verification "
            "manifest; regenerate with `make rtl-formalize-synthesis-emit` or update "
            "`rtl-formalize-synthesis/results/canonical/verification_manifest.json`",
        )
    if "verification manifest validation failed" in output:
        return (
            "invalid_verification_manifest",
            "checked-in Sparkle emitted-subset verification manifest is invalid; fix "
            "`rtl-formalize-synthesis/results/canonical/verification_manifest.json`",
        )
    if any(
        token in output
        for token in (
            "raw module interface validation failed",
            "could not find raw module declaration",
            "could not parse raw module ports",
        )
    ):
        return (
            "malformed_raw_rtl",
            "checked-in Sparkle generated core failed raw-module validation; regenerate with "
            "`make rtl-formalize-synthesis-emit`",
        )
    return (
        "structural_validation_failed",
        "checked-in Sparkle generated artifacts failed structural validation; regenerate with "
        "`make rtl-formalize-synthesis-emit`",
    )


def remove_if_exists(path: Path) -> None:
    if path.exists():
        path.unlink()


def sha256_text(text: str) -> str:
    return f"sha256:{hashlib.sha256(text.encode('utf-8')).hexdigest()}"


def sha256_file(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def make_sparkle_generated_core_freshness_step(log_path: Path) -> dict[str, object]:
    ensure_dir(log_path.parent)
    emit_source_paths = sparkle_generated_full_core_emit_sources()
    wrapper_input_paths = sparkle_generated_full_core_wrapper_inputs()
    tracked_paths = list(
        dict.fromkeys(
            [
                SPARKLE_FULL_CORE_RTL,
                SPARKLE_FULL_CORE_WRAPPER,
                SPARKLE_VERIFICATION_MANIFEST,
                *emit_source_paths,
                *wrapper_input_paths,
            ]
        )
    )
    missing_paths = [
        path
        for path in tracked_paths
        if not path.exists()
    ]
    details: dict[str, object] = {
        "generated_core": relative(SPARKLE_FULL_CORE_RTL),
        "wrapper": relative(SPARKLE_FULL_CORE_WRAPPER),
        "wrapper_generator": relative(SPARKLE_WRAPPER_GENERATOR),
        "verification_manifest": relative(SPARKLE_VERIFICATION_MANIFEST),
        "source_count": len(emit_source_paths),
    }
    artifacts: dict[str, Path] = {}
    log_lines = [
        "Sparkle full-core generated RTL freshness check",
        "",
        f"generated core: {relative(SPARKLE_FULL_CORE_RTL)}",
        f"wrapper: {relative(SPARKLE_FULL_CORE_WRAPPER)}",
        f"wrapper generator: {relative(SPARKLE_WRAPPER_GENERATOR)}",
    ]

    if SPARKLE_FULL_CORE_RTL.exists():
        details["generated_core_mtime_utc"] = format_mtime_utc(SPARKLE_FULL_CORE_RTL)
        artifacts["generated_core"] = SPARKLE_FULL_CORE_RTL
        log_lines.append(f"generated core mtime (utc): {details['generated_core_mtime_utc']}")
    if SPARKLE_FULL_CORE_WRAPPER.exists():
        details["wrapper_mtime_utc"] = format_mtime_utc(SPARKLE_FULL_CORE_WRAPPER)
        artifacts["generated_wrapper"] = SPARKLE_FULL_CORE_WRAPPER
        log_lines.append(f"wrapper mtime (utc): {details['wrapper_mtime_utc']}")
    if SPARKLE_WRAPPER_GENERATOR.exists():
        details["wrapper_generator_mtime_utc"] = format_mtime_utc(SPARKLE_WRAPPER_GENERATOR)
        artifacts["wrapper_generator"] = SPARKLE_WRAPPER_GENERATOR
        log_lines.append(f"wrapper generator mtime (utc): {details['wrapper_generator_mtime_utc']}")
    if SPARKLE_VERIFICATION_MANIFEST.exists():
        details["verification_manifest_mtime_utc"] = format_mtime_utc(SPARKLE_VERIFICATION_MANIFEST)
        artifacts["verification_manifest"] = SPARKLE_VERIFICATION_MANIFEST
        log_lines.append(f"verification manifest mtime (utc): {details['verification_manifest_mtime_utc']}")

    if missing_paths:
        details["reason"] = "missing Sparkle generated branch artifact or source dependency"
        details["missing_paths"] = [relative(path) for path in missing_paths]
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
                "missing paths:",
                *[f"- {path}" for path in details["missing_paths"]],
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_generated_core_freshness",
            result="fail",
            command="internal Sparkle generated RTL freshness check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    if not emit_source_paths:
        details["reason"] = "no Sparkle source dependencies were discovered for freshness checking"
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_generated_core_freshness",
            result="fail",
            command="internal Sparkle generated RTL freshness check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    if not wrapper_input_paths:
        details["reason"] = "no Sparkle wrapper inputs were discovered for freshness checking"
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_generated_core_freshness",
            result="fail",
            command="internal Sparkle generated RTL freshness check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    newest_source = max(emit_source_paths, key=lambda path: path.stat().st_mtime)
    wrapper_trigger = max(wrapper_input_paths, key=lambda path: path.stat().st_mtime)
    details["newest_source"] = relative(newest_source)
    details["newest_source_mtime_utc"] = format_mtime_utc(newest_source)
    artifacts["newest_source"] = newest_source
    log_lines.append(f"newest source: {details['newest_source']}")
    log_lines.append(f"newest source mtime (utc): {details['newest_source_mtime_utc']}")
    details["newest_wrapper_input"] = relative(wrapper_trigger)
    details["newest_wrapper_input_mtime_utc"] = format_mtime_utc(wrapper_trigger)
    log_lines.append(f"newest wrapper input: {details['newest_wrapper_input']}")
    log_lines.append(f"newest wrapper input mtime (utc): {details['newest_wrapper_input_mtime_utc']}")

    validation_command = [
        "python3",
        str(SPARKLE_WRAPPER_GENERATOR),
        "--raw",
        str(SPARKLE_FULL_CORE_RTL),
        "--wrapper",
        str(SPARKLE_FULL_CORE_WRAPPER),
        "--subset-manifest",
        str(SPARKLE_VERIFICATION_MANIFEST),
        "--check",
    ]
    details["validation_command"] = command_text(validation_command)
    validation_proc = run_command(validation_command, cwd=ROOT)
    validation_output = ((validation_proc.stdout or "") + (validation_proc.stderr or "")).strip()
    log_lines.extend(
        [
            "",
            f"$ {details['validation_command']}",
            validation_output or "(no output)",
        ]
    )
    if validation_proc.returncode != 0:
        failure_kind, failure_reason = classify_sparkle_validation_failure(validation_output)
        details["reason"] = failure_reason
        details["validation_failure_kind"] = failure_kind
        details["validation_output"] = validation_output
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_generated_core_freshness",
            result="fail",
            command="internal Sparkle generated RTL freshness check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    if SPARKLE_FULL_CORE_RTL.stat().st_mtime < newest_source.stat().st_mtime:
        details["reason"] = (
            "checked-in Sparkle generated core is older than the newest Sparkle emit-source input; "
            "regenerate with `make rtl-formalize-synthesis-emit`"
        )
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
            ]
        )
        result = "fail"
    else:
        if SPARKLE_FULL_CORE_WRAPPER.stat().st_mtime < wrapper_trigger.stat().st_mtime:
            details["wrapper_timestamp_note"] = (
                "checked-in Sparkle stable wrapper is older than the latest wrapper-validation input, "
                "but structural validation passed"
            )
            log_lines.append(f"note: {details['wrapper_timestamp_note']}")
        log_lines.append("result: pass")
        result = "pass"

    write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
    return make_step(
        name="sparkle_generated_core_freshness",
        result=result,
        command="internal Sparkle generated RTL freshness check",
        log_path=log_path,
        artifacts=artifacts,
        details=details,
    )


def make_sparkle_backend_proof_status_step(log_path: Path) -> dict[str, object]:
    ensure_dir(log_path.parent)
    proof_source_paths = sparkle_generated_full_core_proof_sources()
    tracked_paths = list(
        dict.fromkeys(
            [
                SPARKLE_FULL_CORE_RTL,
                SPARKLE_VERIFICATION_MANIFEST,
                SPARKLE_BACKEND_METADATA_EXPORT,
                SPARKLE_VERIFICATION_REFRESH,
                *proof_source_paths,
            ]
        )
    )
    missing_paths = [path for path in tracked_paths if not path.exists()]
    details: dict[str, object] = {
        "generated_core": relative(SPARKLE_FULL_CORE_RTL),
        "verification_manifest": relative(SPARKLE_VERIFICATION_MANIFEST),
        "proof_source_count": len(proof_source_paths),
        "gating": True,
    }
    artifacts: dict[str, Path] = {}
    log_lines = [
        "Sparkle backend proof-status check",
        "",
        f"generated core: {relative(SPARKLE_FULL_CORE_RTL)}",
        f"verification manifest: {relative(SPARKLE_VERIFICATION_MANIFEST)}",
    ]

    if SPARKLE_FULL_CORE_RTL.exists():
        details["generated_core_mtime_utc"] = format_mtime_utc(SPARKLE_FULL_CORE_RTL)
        artifacts["generated_core"] = SPARKLE_FULL_CORE_RTL
        log_lines.append(f"generated core mtime (utc): {details['generated_core_mtime_utc']}")
    if SPARKLE_VERIFICATION_MANIFEST.exists():
        details["verification_manifest_mtime_utc"] = format_mtime_utc(SPARKLE_VERIFICATION_MANIFEST)
        artifacts["verification_manifest"] = SPARKLE_VERIFICATION_MANIFEST
        log_lines.append(f"verification manifest mtime (utc): {details['verification_manifest_mtime_utc']}")

    if missing_paths:
        details["reason"] = "missing Sparkle proof-source, manifest, or generated-core dependency"
        details["missing_paths"] = [relative(path) for path in missing_paths]
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
                "missing paths:",
                *[f"- {path}" for path in details["missing_paths"]],
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    if not proof_source_paths:
        details["reason"] = "no Sparkle proof-source dependencies were discovered for proof-status checking"
        log_lines.extend(
            [
                "result: fail",
                f"reason: {details['reason']}",
            ]
        )
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    newest_proof_source = max(proof_source_paths, key=lambda path: path.stat().st_mtime)
    details["newest_proof_source"] = relative(newest_proof_source)
    details["newest_proof_source_mtime_utc"] = format_mtime_utc(newest_proof_source)
    artifacts["newest_proof_source"] = newest_proof_source
    log_lines.append(f"newest proof source: {details['newest_proof_source']}")
    log_lines.append(f"newest proof source mtime (utc): {details['newest_proof_source_mtime_utc']}")

    selected_proof_lane = load_selected_sparkle_proof_lane(ROOT)
    details["selected_proof_lane_from_config"] = selected_proof_lane
    if selected_proof_lane == "smt":
        smt_build_command = ["lake", "build"]
        details["formalize_smt_build_command"] = command_text(smt_build_command)
        smt_build_proc = run_command(smt_build_command, cwd=FORMALIZE_SMT_ROOT)
        smt_build_output = ((smt_build_proc.stdout or "") + (smt_build_proc.stderr or "")).strip()
        log_lines.extend(
            [
                "",
                f"$ {details['formalize_smt_build_command']}  # cwd=formalize-smt",
                smt_build_output or "(no output)",
            ]
        )
        if smt_build_proc.returncode != 0:
            details["reason"] = "formalize-smt failed to build for the selected Sparkle proof lane"
            details["formalize_smt_build_output"] = smt_build_output
            log_lines.extend(["result: fail", f"reason: {details['reason']}"])
            write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
            return make_step(
                name="sparkle_backend_proof_status",
                result="fail",
                command="internal Sparkle backend proof-status check",
                log_path=log_path,
                artifacts=artifacts,
                details=details,
            )

    build_command = ["lake", "build", "MlpCoreSparkle.BackendSemantics"]
    details["proof_build_command"] = command_text(build_command)
    build_proc = run_command(
        build_command,
        cwd=SPARKLE_PROJECT_DIR,
        env=build_sparkle_proof_lane_env(root=ROOT, proof_lane=selected_proof_lane),
    )
    build_output = ((build_proc.stdout or "") + (build_proc.stderr or "")).strip()
    log_lines.extend(
        [
            "",
            f"$ {details['proof_build_command']}",
            build_output or "(no output)",
        ]
    )
    if build_proc.returncode != 0:
        details["reason"] = "Lean backend proof module failed to build"
        details["proof_build_output"] = build_output
        log_lines.extend(["result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    try:
        manifest_payload = load_sparkle_verification_manifest()
    except Exception as exc:
        details["reason"] = f"failed to load verification manifest: {exc}"
        log_lines.extend(["result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    try:
        manifest_proof_lane = sparkle_proof_lane_from_manifest_payload(manifest_payload)
    except Exception as exc:
        details["reason"] = f"failed to load verification manifest proof lane: {exc}"
        log_lines.extend(["result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    details["manifest_schema_version"] = manifest_payload.get("schema_version")
    details["manifest_proof_lane"] = manifest_proof_lane
    if details["manifest_schema_version"] != 2:
        details["reason"] = "verification manifest does not use schema_version 2"
        log_lines.extend(["result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    try:
        export_payload, export_command = export_current_sparkle_backend_metadata()
    except Exception as exc:
        details["reason"] = f"failed to export current Sparkle backend metadata: {exc}"
        log_lines.extend(["result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    details["backend_metadata_command"] = export_command
    current_metadata = current_sparkle_backend_fingerprints(export_payload)
    current_metadata["vendor_revision"] = git_head_revision(SPARKLE_PROJECT_DIR / "vendor" / "Sparkle")
    details["current_backend_metadata"] = current_metadata
    current_proof_lane = current_sparkle_proof_lane(export_payload)
    details["current_proof_lane"] = current_proof_lane
    log_lines.append(
        f"manifest proof lane: {manifest_proof_lane['name']} ({manifest_proof_lane['package']}, "
        f"{manifest_proof_lane['arithmetic_provider']})"
    )
    log_lines.append(
        f"current proof lane: {current_proof_lane['name']} ({current_proof_lane['package']}, "
        f"{current_proof_lane['arithmetic_provider']})"
    )

    proof_endpoint = manifest_payload.get("proof_endpoint")
    exact_emit_path = manifest_payload.get("exact_emit_path")
    mismatches: list[str] = []
    if not isinstance(proof_endpoint, dict):
        mismatches.append("missing proof_endpoint object")
    else:
        if proof_endpoint.get("kind") != "packed_signal_payload":
            mismatches.append("proof_endpoint.kind does not equal packed_signal_payload")
        if proof_endpoint.get("typed_backend_ir") != "Sparkle.IR.AST.Design":
            mismatches.append("proof_endpoint.typed_backend_ir does not equal Sparkle.IR.AST.Design")
        if proof_endpoint.get("lean_theorem") != "MlpCore.Sparkle.sparkleMlpCoreBackendPayload_refines_rtlTrace":
            mismatches.append("proof_endpoint.lean_theorem does not match the expected theorem")
        if proof_endpoint.get("decl_name") != current_metadata["decl_name"]:
            mismatches.append("proof_endpoint.decl_name does not match the current emit declaration")

    for key, current_value in current_proof_lane.items():
        if manifest_proof_lane.get(key) != current_value:
            mismatches.append(f"proof_lane.{key} does not match the current selected proof lane")

    if not isinstance(exact_emit_path, dict):
        mismatches.append("missing exact_emit_path object")
    else:
        expected_emit_paths = [relative(path) for path in sparkle_generated_full_core_emit_sources()]
        declared_subset = manifest_payload.get("declared_emitted_subset")
        if isinstance(declared_subset, dict) and set(declared_subset.get("emit_source_paths", [])) != set(expected_emit_paths):
            mismatches.append("declared_emitted_subset.emit_source_paths does not match the current emit source set")
        comparisons = {
            "decl_name": current_metadata["decl_name"],
            "vendor_revision": current_metadata["vendor_revision"],
            "local_patch_id": current_metadata["local_patch_id"],
            "top_module": str(export_payload.get("top_module", "")),
            "module_count": int(export_payload.get("module_count", 0)),
            "elaborated_design_fingerprint": current_metadata["elaborated_design_fingerprint"],
            "backend_ast_fingerprint": current_metadata["backend_ast_fingerprint"],
            "verilog_render_fingerprint": current_metadata["verilog_render_fingerprint"],
            "raw_artifact_fingerprint": current_metadata["raw_artifact_fingerprint"],
        }
        for key, current_value in comparisons.items():
            if exact_emit_path.get(key) != current_value:
                mismatches.append(f"exact_emit_path.{key} does not match the current exact emit path")

    feature_slice_problems, feature_slice_hits = check_sparkle_feature_slice(manifest_payload)
    details["feature_slice_hits"] = feature_slice_hits
    mismatches.extend(feature_slice_problems)

    if mismatches:
        details["reason"] = "Sparkle backend proof metadata drifted from the exact current emit path"
        details["mismatches"] = mismatches
        log_lines.extend(["", "mismatches:", *[f"- {problem}" for problem in mismatches], "result: fail", f"reason: {details['reason']}"])
        write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
        return make_step(
            name="sparkle_backend_proof_status",
            result="fail",
            command="internal Sparkle backend proof-status check",
            log_path=log_path,
            artifacts=artifacts,
            details=details,
        )

    log_lines.append("result: pass")
    write_text(log_path, "\n".join(log_lines).rstrip() + "\n")
    return make_step(
        name="sparkle_backend_proof_status",
        result="pass",
        command="internal Sparkle backend proof-status check",
        log_path=log_path,
        artifacts=artifacts,
        details=details,
    )


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


def spot_core_usable(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    return "module controller_spot_core" in text and "input clk;" in text


def prepare_baseline_branch(branch_root: Path) -> BranchManifest:
    manifest = BranchManifest(
        branch="rtl",
        artifact_kind="baseline_full_core_rtl",
        assembly_boundary="full_core_mlp_core",
        evidence_boundary=TOP_LEVEL_BENCH_KIND,
        evidence_method="dual_simulator_regression",
        experiment_status=SOFT_GATE_EXPERIMENT,
        claim_scope="committed hand-written baseline RTL",
        source_paths=list(BASELINE_RTL),
        artifacts={"blueprint_mlp_core": BASELINE_BLUEPRINT},
        provenance={"source_kind": "committed_rtl"},
        simulation_profile=make_simulation_profile(
            bench_kind=TOP_LEVEL_BENCH_KIND,
            required_simulators=["iverilog", "verilator"],
        ),
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_rtl_synthesis_branch(
    branch_root: Path,
    args: argparse.Namespace,
    report_root: Path | None = None,
) -> BranchManifest:
    ensure_dir(branch_root)
    report_root = branch_root if report_root is None else report_root
    ensure_dir(report_root)
    generated_dir = branch_root / "generated"
    logs_dir = branch_root / "logs"
    ensure_dir(generated_dir)
    ensure_dir(logs_dir)
    summary_path = report_root / "rtl_synthesis_summary.json"

    alias_path = generated_dir / "controller.sv"
    generated_core = generated_dir / "controller_spot_core.sv"
    command = rtl_synthesis_flow_command(args, branch_root, summary_path)
    log_path = logs_dir / "run_flow.log"
    summary: dict[str, object] | None = None
    summary_error: str | None = None
    claim_scope = SPOT_CLAIM_SCOPE
    missing_tools = missing_rtl_synthesis_tools(args)
    missing_canonical_sources = [path for path in RTL_SYNTHESIS_CANONICAL_RTL if not path.exists()]

    if missing_tools:
        write_command_log(log_path, f"missing required fresh-flow tools: {', '.join(missing_tools)}\n")
        provenance = {
            "source_kind": "fresh_flow_unavailable",
            "result": "skip",
            "reason": "required fresh-flow toolchain is unavailable",
            "missing_tools": missing_tools,
            "command": command_text(command),
            "run_flow_log": relative(log_path),
        }
    else:
        for stale_artifact in (summary_path, alias_path, generated_core):
            remove_if_exists(stale_artifact)
        result, _ = run_checked_command(command, cwd=ROOT, log_path=log_path)
        summary, summary_error = load_rtl_synthesis_flow_summary(summary_path)
        if summary is not None:
            summary_claim_scope = summary.get("claim_scope")
            if isinstance(summary_claim_scope, str) and summary_claim_scope:
                claim_scope = summary_claim_scope
        provenance = {
            "source_kind": "fresh_flow",
            "result": result,
            "summary": relative(summary_path) if summary_path.exists() else "",
            "command": command_text(command),
            "run_flow_log": relative(log_path),
        }
        if summary_error is not None:
            provenance["reason"] = summary_error
        elif result != "pass":
            provenance["reason"] = "rtl-synthesis fresh flow reported one or more failing required steps"

    usable = (
        not missing_tools
        and summary is not None
        and summary_error is None
        and spot_core_usable(generated_core)
        and not missing_canonical_sources
    )
    if usable and not alias_path.exists():
        write_controller_alias_module(alias_path, "controller_spot_compat")
    elif not usable and summary is None and summary_error is not None and "reason" not in provenance:
        provenance["reason"] = summary_error
    if missing_canonical_sources:
        provenance["missing_canonical_sources"] = [relative(path) for path in missing_canonical_sources]
        if "reason" not in provenance:
            provenance["reason"] = "rtl-synthesis canonical export tree is missing one or more comparable sv files"

    manifest = BranchManifest(
        branch="rtl-synthesis",
        artifact_kind="generated_controller_rtl",
        assembly_boundary="mixed_path_mlp_core",
        evidence_boundary=TOP_LEVEL_BENCH_KIND,
        evidence_method="closed_loop_formal_plus_controller_formal_plus_dual_simulator_regression",
        experiment_status=SOFT_GATE_EXPERIMENT,
        claim_scope=(
            claim_scope
            if usable
            else (
                "rtl-synthesis branch skipped because the required fresh-flow toolchain is unavailable"
                if provenance.get("source_kind") == "fresh_flow_unavailable"
                else "rtl-synthesis branch failed because the fresh flow did not produce a usable generated controller core"
            )
        ),
        source_paths=list(RTL_SYNTHESIS_CANONICAL_RTL) if usable else [],
        artifacts={
            "controller_alias": ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller.sv",
            "generated_core": ROOT / "rtl-synthesis" / "results" / "canonical" / "sv" / "controller_spot_core.sv",
            **({"summary": summary_path} if summary_path.exists() else {}),
            "compat_wrapper": SPOT_COMPAT_WRAPPER,
            "blueprint_mlp_core": RTL_SYNTHESIS_BLUEPRINT,
        },
        provenance={**provenance, "usable_source_set": usable},
        simulation_profile=make_simulation_profile(
            bench_kind=TOP_LEVEL_BENCH_KIND,
            required_simulators=["iverilog", "verilator"],
        ),
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_sparkle_branch(branch_root: Path) -> BranchManifest:
    ensure_dir(branch_root)
    proof_lane = maybe_load_sparkle_proof_lane()
    manifest = BranchManifest(
        branch="rtl-formalize-synthesis",
        artifact_kind="generated_full_core_rtl",
        assembly_boundary="full_core_mlp_core",
        evidence_boundary=TOP_LEVEL_BENCH_KIND,
        evidence_method="dual_simulator_regression",
        experiment_status=SOFT_GATE_EXPERIMENT,
        claim_scope="shared mlp_core top-level comparison between baseline RTL and Sparkle-generated full-core RTL",
        source_paths=[SPARKLE_FULL_CORE_WRAPPER, SPARKLE_FULL_CORE_RTL],
        artifacts={
            "generated_wrapper": SPARKLE_FULL_CORE_WRAPPER,
            "generated_core": SPARKLE_FULL_CORE_RTL,
            "blueprint_mlp_core": SPARKLE_BLUEPRINT,
        },
        provenance={
            "source_kind": "generated_full_core_wrapper_flow",
            "generated_core": relative(SPARKLE_FULL_CORE_RTL),
            "wrapper": relative(SPARKLE_FULL_CORE_WRAPPER),
            "wrapper_generator": relative(SPARKLE_WRAPPER_GENERATOR),
            "emit_command": "make rtl-formalize-synthesis-emit",
            "proof_lane": proof_lane["name"] if proof_lane is not None else "unknown",
            "proof_namespace": proof_lane["lean_namespace"] if proof_lane is not None else "unknown",
            "arithmetic_provider": proof_lane["arithmetic_provider"] if proof_lane is not None else "unknown",
            "verification_manifest": relative(SPARKLE_VERIFICATION_MANIFEST),
            "generated_core_exists": SPARKLE_FULL_CORE_RTL.exists(),
            "wrapper_exists": SPARKLE_FULL_CORE_WRAPPER.exists(),
        },
        simulation_profile=make_simulation_profile(
            bench_kind=TOP_LEVEL_BENCH_KIND,
            required_simulators=["iverilog", "verilator"],
        ),
    )
    write_json(branch_root / "manifest.json", manifest.summary())
    return manifest


def prepare_branch_manifests(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, BranchManifest]:
    branch_root = build_root / "branches"
    branch_report_root = branch_root if report_root is None else report_root / "branches"
    ensure_dir(branch_root)
    ensure_dir(branch_report_root)
    manifests = {
        "rtl": prepare_baseline_branch(branch_root / "rtl"),
        "rtl-synthesis": prepare_rtl_synthesis_branch(branch_root / "rtl-synthesis", args, branch_report_root / "rtl-synthesis"),
        "rtl-formalize-synthesis": prepare_sparkle_branch(branch_root / "rtl-formalize-synthesis"),
    }
    return manifests


def check_contract_without_mutation() -> None:
    validate_contract()


def run_contract_preflight_step(log_path: Path) -> dict[str, object]:
    command = ["python3", "contract/runners/freeze.py", "--check"]
    try:
        check_contract_without_mutation()
    except Exception as exc:
        write_command_log(log_path, f"{type(exc).__name__}: {exc}\n")
        return make_step(
            name="contract_validation",
            result="fail",
            command=command_text(command),
            log_path=log_path,
            details={"reason": str(exc), "gating": True},
        )

    write_command_log(log_path, "contract validation passed\n")
    return make_step(
        name="contract_validation",
        result="pass",
        command=command_text(command),
        log_path=log_path,
        details={"gating": True},
    )


def run_artifact_consistency_family(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, object]:
    family_root = build_root / "artifact-consistency"
    family_report_root = family_root if report_root is None else report_root / "artifact-consistency"
    ensure_dir(family_root)
    logs_dir = family_root / "logs"
    ensure_dir(logs_dir)

    freeze_check_log = logs_dir / "freeze_check.log"
    freeze_check_command = ["python3", "contract/runners/freeze.py", "--check"]
    freeze_check_proc = run_command(freeze_check_command, cwd=ROOT)
    freeze_check_output = (freeze_check_proc.stdout or "") + (freeze_check_proc.stderr or "")
    write_command_log(freeze_check_log, freeze_check_output or "(no output)\n")
    freeze_check_result = "pass" if freeze_check_proc.returncode == 0 else "fail"

    contract_payload = read_json(ROOT / "contract" / "results" / "canonical" / "weights.json")
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
                "ann_canonical_manifest": relative(ANN_CANONICAL_MANIFEST_PATH),
            },
        )
    ]
    results.append(make_sparkle_generated_core_freshness_step(logs_dir / "sparkle_generated_core_freshness.log"))
    results.append(make_sparkle_backend_proof_status_step(logs_dir / "sparkle_backend_proof_status.log"))
    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "artifact-consistency",
        "overall_result": combine_results([item["result"] for item in results]),
        "artifact_kind": "frozen_contract_bundle",
        "assembly_boundary": "contract_downstream_bundle",
        "evidence_boundary": "checked_in_downstream_artifacts",
        "evidence_method": "frozen_contract_consistency_check",
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "claim_scope": (
            "checked-in frozen contract and downstream artifacts remain synchronized without rewriting tracked "
            "files, the checked-in Sparkle full-core RTL and wrapper remain aligned with the declared emitted "
            "subset verification manifest and emit inputs, and the exact current Sparkle emit path still matches "
            "the checked-in backend proof metadata and feature-slice declaration"
        ),
        "tool_versions": {
            "python3": tool_version([["python3", "--version"]]),
        },
        "results": results,
        "sources": {
            "contract": "contract/results/canonical/weights.json",
            "ann_canonical": relative(ANN_CANONICAL_MANIFEST_PATH),
        },
    }
    write_family_outputs(family_report_root, summary, render_family_report(summary))
    return summary


def compare_semantic_bridge(bridge_path: Path) -> tuple[str, dict[str, object]]:
    bridge = read_json(bridge_path)
    contract = read_json(ROOT / "contract" / "results" / "canonical" / "weights.json")
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


def run_semantic_closure_family(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, object]:
    family_root = build_root / "semantic-closure"
    family_report_root = family_root if report_root is None else report_root / "semantic-closure"
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

    overflow_summary = family_report_root / "contract_overflow_summary.json"
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

    equivalence_summary = family_report_root / "contract_equivalence_summary.json"
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
        "artifact_kind": "lean_contract_rtl_bridge",
        "assembly_boundary": "lean_fixed_point_bridge",
        "evidence_boundary": "bridge_export_and_solver_checks",
        "evidence_method": "bridge_export_plus_solver_backed_checks",
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "claim_scope": "Lean fixed-point semantics are exported as a machine-readable artifact, aligned with the frozen contract, and connected to RTL-style datapath equivalence through solver-backed checks",
        "tool_versions": {
            "python3": tool_version([["python3", "--version"]]),
            "lake": tool_version([[args.lake, "--version"]], cwd=ROOT / "formalize") if tool_exists(args.lake) else "missing",
            "z3": tool_version([[args.z3, "--version"]]) if tool_exists(args.z3) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_report_root, summary, render_family_report(summary))
    return summary


def run_iverilog_suite(
    args: argparse.Namespace,
    sources: list[Path],
    out_root: Path,
    *,
    bench_path: Path = SIM_TB,
    top_module: str = "testbench",
    step_name: str = "iverilog_sim",
    details: dict[str, object] | None = None,
) -> dict[str, object]:
    ensure_dir(out_root)
    compile_log = out_root / "iverilog_compile.log"
    run_log = out_root / "iverilog_run.log"
    binary = out_root / f"{top_module}.out"
    compile_command = [
        args.iverilog,
        "-g2012",
        f"-I{SIM_INCLUDE_DIR}",
        "-s",
        top_module,
        "-o",
        str(binary),
        str(bench_path),
        *[str(path) for path in sources],
    ]
    if not tool_exists(args.iverilog) or not tool_exists(args.vvp):
        missing = args.iverilog if not tool_exists(args.iverilog) else args.vvp
        write_command_log(compile_log, f"missing required tool: {missing}\n")
        return make_step(
            name=step_name,
            result="skip",
            command=command_text(compile_command),
            log_path=compile_log,
            details={**(details or {}), "reason": f"missing required tool: {missing}"},
        )

    compile_proc = run_command(compile_command, cwd=ROOT)
    compile_output = (compile_proc.stdout or "") + (compile_proc.stderr or "")
    write_command_log(compile_log, compile_output or "(no output)\n")
    if compile_proc.returncode != 0:
        return make_step(
            name=step_name,
            result="fail",
            command=command_text(compile_command),
            log_path=compile_log,
            artifacts={"binary": binary},
            details=details,
        )

    run_command_args = [args.vvp, str(binary)]
    run_proc = run_command(run_command_args, cwd=ROOT)
    run_output = (run_proc.stdout or "") + (run_proc.stderr or "")
    write_command_log(run_log, run_output or "(no output)\n")
    return make_step(
        name=step_name,
        result="pass" if run_proc.returncode == 0 else "fail",
        command=command_text(run_command_args),
        log_path=run_log,
        artifacts={"binary": binary},
        details=details,
    )


def run_verilator_suite(
    args: argparse.Namespace,
    sources: list[Path],
    out_root: Path,
    *,
    bench_path: Path = SIM_TB,
    top_module: str = "testbench",
    step_name: str = "verilator_sim",
    details: dict[str, object] | None = None,
) -> dict[str, object]:
    ensure_dir(out_root)
    compile_log = out_root / "verilator_compile.log"
    run_log = out_root / "verilator_run.log"
    mdir = out_root / "obj_dir"
    prefix = f"V{top_module}"
    binary = mdir / prefix
    compile_command = [
        args.verilator,
        "--binary",
        "--timing",
        f"-I{SIM_INCLUDE_DIR}",
        "--top-module",
        top_module,
        "--prefix",
        prefix,
        "--Mdir",
        str(mdir),
        str(bench_path),
        *[str(path) for path in sources],
    ]
    if not tool_exists(args.verilator):
        write_command_log(compile_log, f"missing required tool: {args.verilator}\n")
        return make_step(
            name=step_name,
            result="skip",
            command=command_text(compile_command),
            log_path=compile_log,
            details={**(details or {}), "reason": f"missing required tool: {args.verilator}"},
        )

    compile_proc = run_command(compile_command, cwd=ROOT)
    compile_output = (compile_proc.stdout or "") + (compile_proc.stderr or "")
    write_command_log(compile_log, compile_output or "(no output)\n")
    if compile_proc.returncode != 0:
        return make_step(
            name=step_name,
            result="fail",
            command=command_text(compile_command),
            log_path=compile_log,
            artifacts={"binary": binary},
            details=details,
        )

    run_command_args = [str(binary)]
    run_proc = run_command(run_command_args, cwd=ROOT)
    run_output = (run_proc.stdout or "") + (run_proc.stderr or "")
    write_command_log(run_log, run_output or "(no output)\n")
    return make_step(
        name=step_name,
        result="pass" if run_proc.returncode == 0 else "fail",
        command=command_text(run_command_args),
        log_path=run_log,
        artifacts={"binary": binary},
        details=details,
    )


def run_branch_simulation(args: argparse.Namespace, manifest: BranchManifest, out_root: Path) -> dict[str, object]:
    if not manifest.source_paths:
        skip_log = out_root / "skip.log"
        ensure_dir(skip_log.parent)
        write_command_log(skip_log, "branch source set is unavailable in the current environment\n")
        step = make_step(
            name="top_level_simulation",
            result="skip",
            command="branch simulation",
            log_path=skip_log,
            details={"reason": "branch source set unavailable", "gating": True},
        )
        return {
            "simulation_result": "skip",
            "gating_result": "skip",
            "secondary_result": "skip",
            "steps": [step],
        }

    preflight_step = run_contract_preflight_step(out_root / "contract_validation.log")
    if preflight_step["result"] != "pass":
        return {
            "simulation_result": "fail",
            "gating_result": "fail",
            "secondary_result": "skip",
            "steps": [preflight_step],
        }

    primary_steps = [
        run_iverilog_suite(
            args,
            manifest.source_paths,
            out_root / "iverilog",
            bench_path=SIM_TB,
            top_module="testbench",
            step_name="iverilog_sim",
            details=simulator_step_details(bench_kind=TOP_LEVEL_BENCH_KIND, bench_path=SIM_TB, gating=True),
        ),
        run_verilator_suite(
            args,
            manifest.source_paths,
            out_root / "verilator",
            bench_path=SIM_TB,
            top_module="testbench",
            step_name="verilator_sim",
            details=simulator_step_details(bench_kind=TOP_LEVEL_BENCH_KIND, bench_path=SIM_TB, gating=True),
        ),
    ]

    secondary_steps: list[dict[str, object]] = []
    if manifest.branch in {"rtl", "rtl-synthesis"}:
        internal_details = simulator_step_details(
            bench_kind=INTERNAL_OBSERVABILITY_BENCH_KIND,
            bench_path=SIM_INTERNAL_TB,
            gating=False,
        )
        secondary_steps = [
            run_iverilog_suite(
                args,
                manifest.source_paths,
                out_root / "internal-iverilog",
                bench_path=SIM_INTERNAL_TB,
                top_module="testbench_internal",
                step_name="iverilog_internal_observability",
                details=internal_details,
            ),
            run_verilator_suite(
                args,
                manifest.source_paths,
                out_root / "internal-verilator",
                bench_path=SIM_INTERNAL_TB,
                top_module="testbench_internal",
                step_name="verilator_internal_observability",
                details=internal_details,
            ),
        ]

    gating_steps = [preflight_step, *primary_steps]
    return {
        "simulation_result": combine_results([step["result"] for step in primary_steps]),
        "gating_result": combine_results([step["result"] for step in gating_steps]),
        "secondary_result": combine_results([step["result"] for step in secondary_steps]) if secondary_steps else "skip",
        "steps": [*gating_steps, *secondary_steps],
    }


def run_branch_compare_family(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, object]:
    family_root = build_root / "branch-compare"
    family_report_root = family_root if report_root is None else report_root / "branch-compare"
    ensure_dir(family_root)
    manifests = prepare_branch_manifests(args, build_root, report_root)
    branches: list[dict[str, object]] = []

    baseline_formal_summary = family_report_root / "rtl_control_summary.json"
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
        steps: list[dict[str, object]] = []
        if branch_name == "rtl-formalize-synthesis":
            freshness_step = make_sparkle_generated_core_freshness_step(branch_root / "sparkle_generated_core_freshness.log")
            steps.append(freshness_step)
            proof_step = make_sparkle_backend_proof_status_step(branch_root / "sparkle_backend_proof_status.log")
            steps.append(proof_step)
            if freshness_step["result"] != "pass" or proof_step["result"] != "pass":
                branch_result = {
                    "branch": branch_name,
                    "artifact_kind": manifest.artifact_kind,
                    "assembly_boundary": manifest.assembly_boundary,
                    "evidence_boundary": manifest.evidence_boundary,
                    "evidence_method": manifest.evidence_method,
                    "experiment_status": manifest.experiment_status,
                    "claim_scope": manifest.claim_scope,
                    "simulation_profile": manifest.simulation_profile,
                    "simulation_result": "skip",
                    "overall_result": "fail",
                    "evidence_result": "fail",
                    "manifest": manifest.summary(),
                    "steps": steps,
                }
                branches.append(branch_result)
                continue

        if branch_name == "rtl-synthesis":
            steps.extend(rtl_synthesis_flow_steps_from_manifest(manifest))

        simulation = run_branch_simulation(args, manifest, branch_root / "sim")
        simulation_steps = simulation["steps"]
        steps.extend(simulation_steps)

        if branch_name == "rtl":
            steps.append(
                make_step(
                    name="rtl_control_formal",
                    result=baseline_formal_result,
                    command="python3 smt/runners/rtl.py --branch rtl ...",
                    log_path=baseline_formal_log,
                    artifacts={"summary": baseline_formal_summary} if baseline_formal_summary.exists() else {},
                )
            )
            evidence_boundary = manifest.evidence_boundary
            evidence_method = (
                "dual_simulator_regression_plus_control_formal"
                if baseline_formal_result != "skip"
                else manifest.evidence_method
            )
        else:
            evidence_boundary = manifest.evidence_boundary
            evidence_method = manifest.evidence_method

        gating_results = [str(step["result"]) for step in steps if step_is_gating(step)]
        branch_overall_result = combine_branch_results(gating_results)
        branch_result = {
            "branch": branch_name,
            "artifact_kind": manifest.artifact_kind,
            "assembly_boundary": manifest.assembly_boundary,
            "evidence_boundary": evidence_boundary,
            "evidence_method": evidence_method,
            "experiment_status": manifest.experiment_status,
            "claim_scope": manifest.claim_scope,
            "simulation_profile": with_simulator_results(manifest.simulation_profile, steps),
            "simulation_result": simulation.get("simulation_result", simulation.get("overall_result", "fail")),
            "overall_result": branch_overall_result,
            "evidence_result": branch_overall_result,
            "manifest": manifest.summary(),
            "steps": steps,
        }
        secondary_result = simulation.get("secondary_result", "skip")
        if secondary_result != "skip":
            branch_result["secondary_result"] = secondary_result
        branches.append(branch_result)

    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "branch-compare",
        "overall_result": combine_branch_results([str(branch["overall_result"]) for branch in branches]),
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "tool_versions": {
            "iverilog": tool_version([[args.iverilog, "-V"]]) if tool_exists(args.iverilog) else "missing",
            "verilator": tool_version([[args.verilator, "--version"]]) if tool_exists(args.verilator) else "missing",
            "yosys": tool_version([[args.yosys, "-V"]]) if tool_exists(args.yosys) else "missing",
            "yosys_smtbmc": tool_version([[args.smtbmc, "--version"]]) if tool_exists(args.smtbmc) else "missing",
            "z3": tool_version([[args.z3, "--version"]]) if tool_exists(args.z3) else "missing",
        },
        "branches": branches,
    }
    write_family_outputs(family_report_root, summary, render_family_report(summary))
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
                "flatten",
                "opt",
                f"dfflibmap -liberty {liberty_path}",
                f"abc -liberty {liberty_path}",
                "opt",
                f"stat -liberty {liberty_path}",
            ]
        )
    else:
        lines.extend(["synth -top mlp_core", "flatten", "opt", "stat"])
    lines.extend(
        [
            "check",
            f"write_json {relative(json_path)}",
            f"write_verilog -noattr {relative(netlist_path)}",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_qor_metrics(log_text: str, json_path: Path) -> dict[str, object]:
    cells = None
    cell_breakdown: dict[str, int] = {}
    if json_path.exists():
        payload = read_json(json_path)
        modules = payload.get("modules")
        if isinstance(modules, dict):
            module = modules.get("mlp_core")
            if isinstance(module, dict):
                module_cells = module.get("cells")
                if isinstance(module_cells, dict):
                    cells = len(module_cells)
                    for cell in module_cells.values():
                        if isinstance(cell, dict):
                            cell_type = cell.get("type")
                            if isinstance(cell_type, str):
                                cell_breakdown[cell_type] = cell_breakdown.get(cell_type, 0) + 1
    elif (module_match := re.search(r"=== mlp_core ===\n(.*?)(?=\n=== |\Z)", log_text, re.DOTALL)) is not None:
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


def run_qor_family(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, object]:
    family_root = build_root / "qor"
    family_report_root = family_root if report_root is None else report_root / "qor"
    ensure_dir(family_root)
    liberty_env = os.environ.get("SKY130_FD_SC_HD_LIBERTY")
    liberty_path = Path(liberty_env).resolve() if liberty_env else None
    if liberty_path is not None and not liberty_path.exists():
        liberty_path = None

    contract_validation = run_contract_preflight_step(family_root / "logs" / "contract_validation.log")
    if contract_validation["result"] != "pass":
        summary = {
            "generated_at_utc": timestamp_utc(),
            "family": "qor",
            "overall_result": "fail",
            "experiment_status": SOFT_GATE_EXPERIMENT,
            "claim_scope": (
                "branch-tagged flattened full-core mlp_core QoR data across baseline RTL, Sparkle full-core RTL, "
                "and mixed-path generated-controller branches"
            ),
            "tool_versions": {
                "yosys": tool_version([[args.yosys, "-V"]]) if tool_exists(args.yosys) else "missing",
            },
            "results": [
                make_contract_validation_result(
                    contract_validation,
                    claim_scope="canonical frozen contract bundle is coherent before QoR characterization runs",
                    evidence_boundary="canonical_contract_validation",
                    evidence_method="frozen_contract_consistency_check",
                )
            ],
        }
        write_family_outputs(family_report_root, summary, render_family_report(summary))
        return summary

    manifests = prepare_branch_manifests(args, build_root, report_root)

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
                    "artifact_kind": manifest.artifact_kind,
                    "assembly_boundary": manifest.assembly_boundary,
                    "evidence_boundary": "yosys_mlp_core_characterization",
                    "evidence_method": "qor_characterization",
                    "experiment_status": manifest.experiment_status,
                    "claim_scope": manifest.claim_scope,
                    "result": "skip",
                    "command": "",
                    "log": relative(log_path),
                    "artifacts": {
                        "manifest": relative((build_root / "branches" / branch_name / "manifest.json")),
                    },
                    "manifest": manifest.summary(),
                    "metrics": empty_qor_metrics(),
                    "metrics_basis": QOR_METRICS_BASIS,
                    "liberty": relative(liberty_path) if liberty_path is not None else "",
                }
            )
            continue

        if branch_name == "rtl-formalize-synthesis":
            freshness_step = make_sparkle_generated_core_freshness_step(branch_root / "sparkle_generated_core_freshness.log")
            proof_step = make_sparkle_backend_proof_status_step(branch_root / "sparkle_backend_proof_status.log")
            if freshness_step["result"] != "pass" or proof_step["result"] != "pass":
                failing_step = freshness_step if freshness_step["result"] != "pass" else proof_step
                results.append(
                    {
                        "branch": branch_name,
                        "artifact_kind": manifest.artifact_kind,
                        "assembly_boundary": manifest.assembly_boundary,
                        "evidence_boundary": "yosys_mlp_core_characterization",
                        "evidence_method": "qor_characterization",
                        "experiment_status": manifest.experiment_status,
                        "claim_scope": (
                            "flattened full-core mlp_core Yosys characterization across baseline RTL, Sparkle "
                            "full-core RTL, and generated-controller mixed-path RTL"
                        ),
                        "result": "fail",
                        "command": failing_step["command"],
                        "log": failing_step["log"],
                        "artifacts": {
                            "manifest": relative((build_root / "branches" / branch_name / "manifest.json")),
                        },
                        "manifest": manifest.summary(),
                        "metrics": empty_qor_metrics(),
                        "metrics_basis": QOR_METRICS_BASIS,
                        "liberty": relative(liberty_path) if liberty_path is not None else "",
                        "details": failing_step["details"],
                    }
                )
                continue

        for stale_artifact in (json_path, netlist_path):
            if stale_artifact.exists():
                stale_artifact.unlink()

        write_text(script_path, build_yosys_qor_script(manifest.source_paths, netlist_path, json_path, liberty_path))

        command = [args.yosys, "-s", str(script_path)]
        if not tool_exists(args.yosys):
            write_command_log(log_path, f"missing required tool: {args.yosys}\n")
            result = "fail"
            metrics = empty_qor_metrics()
        else:
            proc = run_command(command, cwd=ROOT)
            output = (proc.stdout or "") + (proc.stderr or "")
            write_command_log(log_path, output or "(no output)\n")
            result = "pass" if proc.returncode == 0 else "fail"
            metrics = parse_qor_metrics(output, json_path) if result == "pass" else empty_qor_metrics()

        results.append(
            {
                "branch": branch_name,
                "artifact_kind": manifest.artifact_kind,
                "assembly_boundary": manifest.assembly_boundary,
                "evidence_boundary": "yosys_mlp_core_characterization",
                "evidence_method": "qor_characterization",
                "experiment_status": manifest.experiment_status,
                "claim_scope": (
                    "flattened full-core mlp_core Yosys characterization across baseline RTL, Sparkle full-core RTL, "
                    "and generated-controller mixed-path RTL"
                ),
                "result": result,
                "command": command_text(command),
                "log": relative(log_path),
                "artifacts": {
                    "netlist": relative(netlist_path) if result == "pass" and netlist_path.exists() else "",
                    "json": relative(json_path) if result == "pass" and json_path.exists() else "",
                    "manifest": relative((build_root / "branches" / branch_name / "manifest.json")),
                },
                "manifest": manifest.summary(),
                "metrics": metrics,
                "metrics_basis": QOR_METRICS_BASIS,
                "liberty": relative(liberty_path) if liberty_path is not None else "",
            }
        )

    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "qor",
        "overall_result": combine_results([item["result"] for item in results]),
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "claim_scope": (
            "branch-tagged flattened full-core mlp_core QoR data across baseline RTL, Sparkle full-core RTL, and "
            "mixed-path generated-controller branches"
        ),
        "tool_versions": {
            "yosys": tool_version([[args.yosys, "-V"]]) if tool_exists(args.yosys) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_report_root, summary, render_family_report(summary))
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


def run_post_synth_family(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path | None = None,
) -> dict[str, object]:
    family_root = build_root / "post-synth"
    family_report_root = family_root if report_root is None else report_root / "post-synth"
    ensure_dir(family_root)
    results: list[dict[str, object]] = []

    openlane_available = tool_exists(args.openlane_flow)
    pdk_root = os.environ.get("PDK_ROOT", "")

    contract_validation = run_contract_preflight_step(family_root / "logs" / "contract_validation.log")
    if contract_validation["result"] != "pass":
        summary = {
            "generated_at_utc": timestamp_utc(),
            "family": "post-synth",
            "overall_result": "fail",
            "experiment_status": SOFT_GATE_EXPERIMENT,
            "tool_versions": {
                "openlane_flow": tool_version([[args.openlane_flow, "--version"]]) if tool_exists(args.openlane_flow) else "missing",
                "iverilog": tool_version([[args.iverilog, "-V"]]) if tool_exists(args.iverilog) else "missing",
            },
            "results": [
                make_contract_validation_result(
                    contract_validation,
                    claim_scope="canonical frozen contract bundle is coherent before post-synthesis setup runs",
                    evidence_boundary="canonical_contract_validation",
                    evidence_method="frozen_contract_consistency_check",
                )
            ],
        }
        write_family_outputs(family_report_root, summary, render_family_report(summary))
        return summary

    manifests = prepare_branch_manifests(args, build_root, report_root)

    for branch_name, manifest in manifests.items():
        branch_root = family_root / branch_name
        ensure_dir(branch_root)
        branch_result: dict[str, object] = {
            "branch": branch_name,
            "artifact_kind": manifest.artifact_kind,
            "assembly_boundary": manifest.assembly_boundary,
            "evidence_boundary": "openlane_post_synth_flow",
            "evidence_method": "post_synthesis_validation",
            "experiment_status": manifest.experiment_status,
            "claim_scope": "OpenLane-oriented post-synthesis setup plus gate-level replay when flow artifacts and library models are available",
            "simulation_profile": make_simulation_profile(
                bench_kind=GATE_LEVEL_BENCH_KIND,
                required_simulators=["iverilog"],
            ),
            "result": "skip",
            "artifacts": {"manifest": relative((build_root / "branches" / branch_name / "manifest.json"))},
            "manifest": manifest.summary(),
            "steps": [],
        }

        if branch_name == "rtl-formalize-synthesis":
            freshness_step = make_sparkle_generated_core_freshness_step(branch_root / "sparkle_generated_core_freshness.log")
            branch_result["steps"].append(freshness_step)
            proof_step = make_sparkle_backend_proof_status_step(branch_root / "sparkle_backend_proof_status.log")
            branch_result["steps"].append(proof_step)
            if freshness_step["result"] != "pass" or proof_step["result"] != "pass":
                branch_result["result"] = "fail"
                results.append(branch_result)
                continue

        if not manifest.source_paths:
            skip_log = branch_root / "source_set_unavailable.log"
            reason = str(manifest.provenance.get("reason", "branch source set unavailable"))
            write_command_log(skip_log, reason + "\n")
            branch_result["steps"].append(
                make_step(
                    name="branch_source_set",
                    result="skip",
                    command="post-synth branch preparation",
                    log_path=skip_log,
                    details={"reason": reason},
                )
            )
            branch_result["result"] = "skip"
            results.append(branch_result)
            continue

        config_path = create_openlane_design_config(branch_root, manifest)
        branch_result["artifacts"]["openlane_config"] = relative(config_path)

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
        simulation_profile = branch_result.get("simulation_profile")
        steps = branch_result["steps"]
        branch_result["simulation_profile"] = with_simulator_results(
            simulation_profile if isinstance(simulation_profile, dict) else None,
            steps if isinstance(steps, list) else [],
        )
        results.append(branch_result)

    overall_result = combine_results([item["result"] for item in results])
    summary = {
        "generated_at_utc": timestamp_utc(),
        "family": "post-synth",
        "overall_result": overall_result,
        "experiment_status": SOFT_GATE_EXPERIMENT,
        "tool_versions": {
            "openlane_flow": tool_version([[args.openlane_flow, "--version"]]) if tool_exists(args.openlane_flow) else "missing",
            "iverilog": tool_version([[args.iverilog, "-V"]]) if tool_exists(args.iverilog) else "missing",
        },
        "results": results,
    }
    write_family_outputs(family_report_root, summary, render_family_report(summary))
    return summary


def run_selected_families(
    args: argparse.Namespace,
    build_root: Path,
    report_root: Path,
) -> list[dict[str, object]]:
    ensure_dir(build_root)
    ensure_dir(report_root)
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
        families.append(dispatch[family_name](args, build_root, report_root))
    return families


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    snapshot = prepare_snapshot(
        build_root=args.build_root.resolve(),
        report_root=args.report_root.resolve(),
        run_id=args.run_id or build_run_id("experiments", args.family),
        subpath=".",
    )
    build_root = snapshot.build_run_dir
    report_root = snapshot.report_run_dir
    families = run_selected_families(args, build_root, report_root)
    family_rows = [
        {
            "family": family["family"],
            "overall_result": family["overall_result"],
            "summary_path": relative(report_root / family["family"] / "summary.json"),
        }
        for family in families
    ]
    if args.family == "all":
        generated_at_utc = timestamp_utc()
        summary = {
            "generated_at_utc": generated_at_utc,
            "overall_result": combine_results([family["overall_result"] for family in families]),
            "families": family_rows,
        }
        write_json(report_root / "summary.json", summary)
        write_text(report_root / "report.md", render_root_report(summary))
        promote_snapshot(
            snapshot,
            source="experiments_family_suite",
            created_at_utc=generated_at_utc,
            inputs={"family": args.family},
            commands={"driver": f"python3 experiments/runners/run.py --family {args.family}"},
            tool_versions={},
            artifacts={"build_root": relative(build_root)},
            reports={"summary": relative(report_root / "summary.json")},
        )
        print(f"wrote {report_root / 'summary.json'}")
        return 0 if summary["overall_result"] not in {"fail", "error"} else 1

    family = families[0]
    promote_snapshot(
        snapshot,
        source="experiments_family_suite",
        created_at_utc=str(family["generated_at_utc"]),
        inputs={"family": args.family},
        commands={"driver": f"python3 experiments/runners/run.py --family {args.family}"},
        tool_versions={},
        artifacts={"build_root": relative(build_root)},
        reports={"summary": relative(report_root / family["family"] / "summary.json")},
    )
    print(f"wrote {report_root / family['family'] / 'summary.json'}")
    return 0 if family["overall_result"] not in {"fail", "error"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
