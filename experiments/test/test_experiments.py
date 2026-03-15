from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from experiments import run as experiments_run


ROOT = Path(__file__).resolve().parents[2]
LEGACY_SCOPE_FIELDS = ("generation_scope", "integration_scope", "validation_scope", "validation_method")
VALID_SPARKLE_RAW_MODULE = """\
module TinyMLP_sparkleMlpCorePacked (
  input logic _gen_start,
  input logic [7:0] _gen_in0,
  input logic [7:0] _gen_in1,
  input logic [7:0] _gen_in2,
  input logic [7:0] _gen_in3,
  input logic clk,
  input logic rst,
  output logic [298:0] out
);
  assign out = 299'd0;
endmodule
"""


def run_experiments(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", "experiments/run.py", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class ExperimentFlowTests(unittest.TestCase):
    def write_valid_sparkle_artifacts(self, raw_path: Path, wrapper_path: Path) -> None:
        raw_path.write_text(VALID_SPARKLE_RAW_MODULE, encoding="utf-8")
        result = subprocess.run(
            [
                "python3",
                str(experiments_run.SPARKLE_WRAPPER_GENERATOR),
                "--raw",
                str(raw_path),
                "--wrapper",
                str(wrapper_path),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)

    def make_args(self) -> SimpleNamespace:
        return SimpleNamespace(
            iverilog="__missing_iverilog__",
            vvp="__missing_vvp__",
            verilator="__missing_verilator__",
            yosys="__missing_yosys__",
            smtbmc="__missing_smtbmc__",
            z3="__missing_z3__",
            lake="__missing_lake__",
            ltlsynt="__missing_ltlsynt__",
            syfco="__missing_syfco__",
            openlane_flow="__missing_openlane_flow__",
        )

    def make_available_args(self) -> SimpleNamespace:
        return SimpleNamespace(
            iverilog=shutil.which("iverilog") or "iverilog",
            vvp=shutil.which("vvp") or "vvp",
            verilator=shutil.which("verilator") or "verilator",
            yosys=shutil.which("yosys") or "yosys",
            smtbmc=shutil.which("yosys-smtbmc") or "yosys-smtbmc",
            z3=shutil.which("z3") or "z3",
            lake=shutil.which("lake") or "lake",
            ltlsynt=experiments_run.preferred_tool_path(experiments_run.VENDORED_LTLSYNT, "ltlsynt"),
            syfco=experiments_run.preferred_tool_path(experiments_run.VENDORED_SYFCO, "syfco"),
            openlane_flow=experiments_run.preferred_tool_path(experiments_run.VENDORED_OPENLANE_FLOW, "flow.tcl"),
        )

    def make_sparkle_manifest(self, source_paths: list[Path]) -> experiments_run.BranchManifest:
        return experiments_run.BranchManifest(
            branch="rtl-formalize-synthesis",
            artifact_kind="generated_full_core_rtl",
            assembly_boundary="full_core_mlp_core",
            evidence_boundary=experiments_run.TOP_LEVEL_BENCH_KIND,
            evidence_method="dual_simulator_regression",
            claim_scope="shared mlp_core top-level comparison between baseline RTL and Sparkle-generated full-core RTL",
            source_paths=source_paths,
            artifacts={
                "generated_wrapper": source_paths[0],
                "generated_core": source_paths[1],
            },
            provenance={
                "source_kind": "generated_full_core_wrapper_flow",
                "generated_core": experiments_run.relative(source_paths[1]),
                "wrapper": experiments_run.relative(source_paths[0]),
                "wrapper_generator": experiments_run.relative(experiments_run.SPARKLE_WRAPPER_GENERATOR),
                "emit_command": "make rtl-formalize-synthesis-emit",
            },
            simulation_profile=experiments_run.make_simulation_profile(
                bench_kind=experiments_run.TOP_LEVEL_BENCH_KIND,
                required_simulators=["iverilog", "verilator"],
            ),
        )

    def make_rtl_synthesis_manifest(
        self,
        *,
        summary_path: Path | None = None,
        source_paths: list[Path] | None = None,
        source_kind: str = "fresh_flow",
        result: str = "pass",
        reason: str | None = None,
    ) -> experiments_run.BranchManifest:
        provenance: dict[str, object] = {
            "source_kind": source_kind,
            "result": result,
            "command": "python3 rtl-synthesis/controller/run_flow.py ...",
            "usable_source_set": bool(source_paths),
        }
        if summary_path is not None:
            provenance["summary"] = experiments_run.relative(summary_path)
        if reason is not None:
            provenance["reason"] = reason

        return experiments_run.BranchManifest(
            branch="rtl-synthesis",
            artifact_kind="generated_controller_rtl",
            assembly_boundary="mixed_path_mlp_core",
            evidence_boundary=experiments_run.TOP_LEVEL_BENCH_KIND,
            evidence_method="closed_loop_formal_plus_controller_formal_plus_dual_simulator_regression",
            claim_scope="bounded mixed-path mlp_core equivalence with controller-scoped secondary proof",
            source_paths=source_paths or [],
            artifacts={"summary": summary_path} if summary_path is not None else {},
            provenance=provenance,
            simulation_profile=experiments_run.make_simulation_profile(
                bench_kind=experiments_run.TOP_LEVEL_BENCH_KIND,
                required_simulators=["iverilog", "verilator"],
            ),
        )

    def assert_no_legacy_scope_fields(self, payload: dict[str, object]) -> None:
        for field in LEGACY_SCOPE_FIELDS:
            self.assertNotIn(field, payload)

    def assert_boundary_metadata(
        self,
        payload: dict[str, object],
        *,
        artifact_kind: str,
        assembly_boundary: str,
        evidence_boundary: str,
        evidence_method: str,
    ) -> None:
        self.assert_no_legacy_scope_fields(payload)
        self.assertEqual(payload["artifact_kind"], artifact_kind)
        self.assertEqual(payload["assembly_boundary"], assembly_boundary)
        self.assertEqual(payload["evidence_boundary"], evidence_boundary)
        self.assertEqual(payload["evidence_method"], evidence_method)

    def assert_simulation_profile(
        self,
        payload: dict[str, object],
        *,
        bench_kind: str,
        required_simulators: list[str],
    ) -> None:
        profile = payload["simulation_profile"]
        self.assertEqual(profile["bench_kind"], bench_kind)
        self.assertEqual(profile["bench_path"], "simulations/rtl/testbench.sv")
        self.assertEqual(
            profile["vector_artifacts"],
            [
                "simulations/shared/test_vectors.mem",
                "simulations/shared/test_vectors_meta.svh",
            ],
        )
        self.assertEqual(profile["required_simulators"], required_simulators)

    def test_preferred_tool_path_prefers_vendored_checkout(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            vendored = Path(tmpdir) / "flow.tcl"
            vendored.write_text("#!/usr/bin/env tclsh\n", encoding="utf-8")
            self.assertEqual(
                experiments_run.preferred_tool_path(vendored, "__missing_flow__"),
                str(vendored),
            )

    def test_preferred_tool_path_falls_back_to_command_name_when_vendor_missing(self) -> None:
        missing_vendor = ROOT / "build" / "missing-vendor-flow.tcl"
        self.assertEqual(
            experiments_run.preferred_tool_path(missing_vendor, "__missing_flow__"),
            "__missing_flow__",
        )

    def test_artifact_consistency_family_writes_pass_summary(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            result = run_experiments("--family", "artifact-consistency", "--build-root", str(build_root))
            output = result.stdout + result.stderr

            self.assertEqual(result.returncode, 0, msg=output)
            summary = json.loads((build_root / "artifact-consistency" / "summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["overall_result"], "pass")
            self.assert_boundary_metadata(
                summary,
                artifact_kind="frozen_contract_bundle",
                assembly_boundary="contract_downstream_bundle",
                evidence_boundary="checked_in_downstream_artifacts",
                evidence_method="frozen_contract_consistency_check",
            )
            self.assertEqual(
                [item["name"] for item in summary["results"]],
                ["freeze_check", "sparkle_generated_core_freshness"],
            )
            self.assertTrue(all(item["result"] == "pass" for item in summary["results"]))

    def test_semantic_closure_family_exports_lean_bridge(self) -> None:
        for tool in ("lake", "z3"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            result = run_experiments("--family", "semantic-closure", "--build-root", str(build_root))
            output = result.stdout + result.stderr

            self.assertEqual(result.returncode, 0, msg=output)
            summary = json.loads((build_root / "semantic-closure" / "summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["overall_result"], "pass")
            self.assert_boundary_metadata(
                summary,
                artifact_kind="lean_contract_rtl_bridge",
                assembly_boundary="lean_fixed_point_bridge",
                evidence_boundary="bridge_export_and_solver_checks",
                evidence_method="bridge_export_plus_solver_backed_checks",
            )
            self.assertEqual(
                [item["name"] for item in summary["results"]],
                [
                    "lean_semantic_bridge_export",
                    "lean_bridge_consistency",
                    "frozen_bounds_check",
                    "rtl_datapath_equivalence",
                ],
            )
            bridge_payload = json.loads((build_root / "semantic-closure" / "lean_fixed_point_bridge.json").read_text(encoding="utf-8"))
            self.assertEqual(bridge_payload["topology"]["input_size"], 4)
            self.assertEqual(bridge_payload["schedule"]["total_cycles"], 76)

    def test_branch_compare_family_records_branch_results(self) -> None:
        for tool in ("iverilog", "vvp", "verilator", "yosys", "yosys-smtbmc", "z3"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            result = run_experiments("--family", "branch-compare", "--build-root", str(build_root))
            output = result.stdout + result.stderr

            self.assertEqual(result.returncode, 0, msg=output)
            summary = json.loads((build_root / "branch-compare" / "summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["overall_result"], "pass")
            branch_results = {item["branch"]: item["overall_result"] for item in summary["branches"]}
            self.assertEqual(branch_results["rtl"], "pass")
            self.assertEqual(branch_results["rtl-formalize-synthesis"], "pass")
            self.assertIn(branch_results["rtl-synthesis"], {"pass", "skip"})
            rtl_synthesis_branch = next(item for item in summary["branches"] if item["branch"] == "rtl-synthesis")
            self.assert_boundary_metadata(
                rtl_synthesis_branch,
                artifact_kind="generated_controller_rtl",
                assembly_boundary="mixed_path_mlp_core",
                evidence_boundary=experiments_run.TOP_LEVEL_BENCH_KIND,
                evidence_method="closed_loop_formal_plus_controller_formal_plus_dual_simulator_regression",
            )
            sparkle_branch = next(item for item in summary["branches"] if item["branch"] == "rtl-formalize-synthesis")
            self.assert_boundary_metadata(
                sparkle_branch,
                artifact_kind="generated_full_core_rtl",
                assembly_boundary="full_core_mlp_core",
                evidence_boundary=experiments_run.TOP_LEVEL_BENCH_KIND,
                evidence_method="dual_simulator_regression",
            )
            self.assert_simulation_profile(
                sparkle_branch,
                bench_kind=experiments_run.TOP_LEVEL_BENCH_KIND,
                required_simulators=["iverilog", "verilator"],
            )
            self.assertEqual(
                sparkle_branch["simulation_profile"]["simulator_results"],
                {"iverilog": "pass", "verilator": "pass"},
            )
            self.assertEqual(
                sparkle_branch["manifest"]["artifacts"]["generated_wrapper"],
                "experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core_wrapper.sv",
            )
            self.assertEqual(
                sparkle_branch["manifest"]["artifacts"]["generated_core"],
                "experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core.sv",
            )
            self.assert_boundary_metadata(
                sparkle_branch["manifest"],
                artifact_kind="generated_full_core_rtl",
                assembly_boundary="full_core_mlp_core",
                evidence_boundary=experiments_run.TOP_LEVEL_BENCH_KIND,
                evidence_method="dual_simulator_regression",
            )
            self.assert_simulation_profile(
                sparkle_branch["manifest"],
                bench_kind=experiments_run.TOP_LEVEL_BENCH_KIND,
                required_simulators=["iverilog", "verilator"],
            )
            self.assertNotIn("controller_alias", sparkle_branch["manifest"]["artifacts"])
            rtl_branch = next(item for item in summary["branches"] if item["branch"] == "rtl")
            self.assertEqual(rtl_branch["secondary_result"], "pass")

    def test_branch_compare_family_fails_when_fresh_flow_formal_step_fails(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            flow_root = build_root / "fake-flow"
            flow_root.mkdir(parents=True, exist_ok=True)
            summary_path = flow_root / "rtl_synthesis_summary.json"
            summary_path.write_text(
                json.dumps(
                    {
                        "claim_scope": "primary mixed-path proof",
                        "results": [
                            {"name": "realisability", "result": "pass", "command": "ltlsynt", "log": "", "artifacts": {}, "details": {}},
                            {"name": "aiger_generation", "result": "pass", "command": "ltlsynt --aiger", "log": "", "artifacts": {}, "details": {}},
                            {"name": "yosys_translation", "result": "pass", "command": "yosys", "log": "", "artifacts": {}, "details": {}},
                            {
                                "name": "controller_interface_equivalence",
                                "result": "pass",
                                "command": "yosys && yosys-smtbmc",
                                "log": "",
                                "artifacts": {},
                                "details": {},
                            },
                            {
                                "name": "closed_loop_mlp_core_equivalence",
                                "result": "fail",
                                "command": "yosys && yosys-smtbmc",
                                "log": "",
                                "artifacts": {},
                                "details": {},
                            },
                        ],
                    },
                    indent=2,
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            manifest = self.make_rtl_synthesis_manifest(
                summary_path=summary_path,
                source_paths=[ROOT / "rtl" / "src" / "controller.sv"],
                result="fail",
            )
            simulation = {
                "overall_result": "pass",
                "steps": [
                    experiments_run.make_step(
                        name="iverilog_sim",
                        result="pass",
                        command="iverilog ...",
                        log_path=build_root / "iverilog.log",
                    ),
                    experiments_run.make_step(
                        name="verilator_sim",
                        result="pass",
                        command="verilator ...",
                        log_path=build_root / "verilator.log",
                    ),
                ],
            }

            with (
                patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl-synthesis": manifest}),
                patch.object(experiments_run, "run_branch_simulation", return_value=simulation),
            ):
                summary = experiments_run.run_branch_compare_family(self.make_args(), build_root)

            self.assertEqual(summary["overall_result"], "fail")
            branch = summary["branches"][0]
            self.assertEqual(branch["branch"], "rtl-synthesis")
            self.assertEqual(branch["simulation_result"], "pass")
            self.assertEqual(branch["overall_result"], "fail")
            self.assertEqual(branch["evidence_result"], "fail")
            self.assertIn("controller_interface_equivalence", [step["name"] for step in branch["steps"]])
            self.assertIn("closed_loop_mlp_core_equivalence", [step["name"] for step in branch["steps"]])

    def test_prepare_rtl_synthesis_branch_skips_without_fresh_flow_toolchain(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            branch_root = Path(tmpdir) / "rtl-synthesis"
            manifest = experiments_run.prepare_rtl_synthesis_branch(branch_root, self.make_args())

            self.assertEqual(manifest.provenance["source_kind"], "fresh_flow_unavailable")
            self.assertEqual(manifest.provenance["result"], "skip")
            self.assertEqual(manifest.provenance["reason"], "required fresh-flow toolchain is unavailable")
            self.assertNotIn("aiger_snapshot", manifest.provenance)
            self.assertEqual(manifest.source_paths, [])

            with patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl-synthesis": manifest}):
                summary = experiments_run.run_branch_compare_family(self.make_args(), Path(tmpdir))

            self.assertEqual(summary["overall_result"], "skip")
            branch = summary["branches"][0]
            self.assertEqual(branch["overall_result"], "skip")
            self.assertEqual(branch["simulation_result"], "skip")
            self.assertEqual(branch["steps"][0]["name"], "rtl_synthesis_fresh_flow")
            self.assertEqual(branch["steps"][0]["result"], "skip")

    def test_prepare_rtl_synthesis_branch_drops_stale_outputs_after_failed_rerun(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            branch_root = Path(tmpdir) / "rtl-synthesis"
            generated_dir = branch_root / "generated"
            logs_dir = branch_root / "logs"
            generated_dir.mkdir(parents=True, exist_ok=True)
            logs_dir.mkdir(parents=True, exist_ok=True)
            stale_summary = branch_root / "rtl_synthesis_summary.json"
            stale_core = generated_dir / "controller_spot_core.sv"
            stale_alias = generated_dir / "controller.sv"
            stale_summary.write_text("{}\n", encoding="utf-8")
            stale_core.write_text("module controller_spot_core (input clk); endmodule\n", encoding="utf-8")
            stale_alias.write_text("module controller; endmodule\n", encoding="utf-8")

            with (
                patch.object(experiments_run, "missing_rtl_synthesis_tools", return_value=[]),
                patch.object(experiments_run, "run_checked_command", return_value=("fail", "")),
            ):
                manifest = experiments_run.prepare_rtl_synthesis_branch(branch_root, self.make_args())

            self.assertEqual(manifest.source_paths, [])
            self.assertFalse(stale_summary.exists())
            self.assertFalse(stale_core.exists())
            self.assertFalse(stale_alias.exists())
            self.assertFalse(manifest.provenance["usable_source_set"])
            self.assertEqual(
                manifest.provenance["reason"],
                "rtl-synthesis fresh flow did not write a summary",
            )

    def test_branch_compare_family_uses_baseline_sim_only_evidence_when_control_formal_skips(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            manifest = experiments_run.prepare_baseline_branch(build_root / "branches" / "rtl")
            simulation = {
                "overall_result": "pass",
                "steps": [
                    experiments_run.make_step(
                        name="iverilog_sim",
                        result="pass",
                        command="iverilog ...",
                        log_path=build_root / "iverilog.log",
                    ),
                    experiments_run.make_step(
                        name="verilator_sim",
                        result="pass",
                        command="verilator ...",
                        log_path=build_root / "verilator.log",
                    ),
                ],
            }

            with (
                patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl": manifest}),
                patch.object(experiments_run, "run_branch_simulation", return_value=simulation),
            ):
                summary = experiments_run.run_branch_compare_family(self.make_args(), build_root)

            branch = summary["branches"][0]
            self.assertEqual(branch["branch"], "rtl")
            self.assertEqual(branch["overall_result"], "pass")
            self.assertEqual(branch["evidence_method"], "dual_simulator_regression")

    def test_branch_compare_family_ignores_secondary_internal_failures_for_branch_result(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            manifest = experiments_run.prepare_baseline_branch(build_root / "branches" / "rtl")
            simulation = {
                "simulation_result": "pass",
                "secondary_result": "fail",
                "steps": [
                    experiments_run.make_step(
                        name="contract_validation",
                        result="pass",
                        command="python3 -m contract.src.freeze --check",
                        log_path=build_root / "contract_validation.log",
                        details={"gating": True},
                    ),
                    experiments_run.make_step(
                        name="iverilog_sim",
                        result="pass",
                        command="iverilog ...",
                        log_path=build_root / "iverilog.log",
                        details={"gating": True},
                    ),
                    experiments_run.make_step(
                        name="verilator_sim",
                        result="pass",
                        command="verilator ...",
                        log_path=build_root / "verilator.log",
                        details={"gating": True},
                    ),
                    experiments_run.make_step(
                        name="iverilog_internal_observability",
                        result="fail",
                        command="iverilog internal ...",
                        log_path=build_root / "internal_iverilog.log",
                        details={"gating": False},
                    ),
                ],
            }

            with (
                patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl": manifest}),
                patch.object(experiments_run, "run_branch_simulation", return_value=simulation),
            ):
                summary = experiments_run.run_branch_compare_family(self.make_args(), build_root)

            branch = summary["branches"][0]
            self.assertEqual(branch["overall_result"], "pass")
            self.assertEqual(branch["simulation_result"], "pass")
            self.assertEqual(branch["secondary_result"], "fail")

    def test_qor_family_records_branch_metrics(self) -> None:
        if shutil.which("yosys") is None:
            self.skipTest("missing required tool: yosys")

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            result = run_experiments("--family", "qor", "--build-root", str(build_root))
            output = result.stdout + result.stderr

            self.assertEqual(result.returncode, 0, msg=output)
            summary = json.loads((build_root / "qor" / "summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["overall_result"], "pass")
            results = {item["branch"]: item for item in summary["results"]}
            self.assertEqual(results["rtl"]["result"], "pass")
            self.assertEqual(results["rtl"]["metrics_basis"], experiments_run.QOR_METRICS_BASIS)
            self.assertEqual(results["rtl-formalize-synthesis"]["result"], "pass")
            self.assertEqual(results["rtl-formalize-synthesis"]["metrics_basis"], experiments_run.QOR_METRICS_BASIS)
            self.assertIsInstance(results["rtl"]["metrics"]["cell_count"], int)
            self.assertIsInstance(results["rtl-formalize-synthesis"]["metrics"]["cell_count"], int)
            self.assertGreater(results["rtl"]["metrics"]["cell_count"], 0)
            self.assertGreater(results["rtl-formalize-synthesis"]["metrics"]["cell_count"], 0)
            self.assert_boundary_metadata(
                results["rtl-synthesis"],
                artifact_kind="generated_controller_rtl",
                assembly_boundary="mixed_path_mlp_core",
                evidence_boundary="yosys_mlp_core_characterization",
                evidence_method="qor_characterization",
            )
            self.assert_boundary_metadata(
                results["rtl-formalize-synthesis"],
                artifact_kind="generated_full_core_rtl",
                assembly_boundary="full_core_mlp_core",
                evidence_boundary="yosys_mlp_core_characterization",
                evidence_method="qor_characterization",
            )
            self.assertNotIn("simulation_profile", results["rtl-formalize-synthesis"])
            self.assertIn(results["rtl-synthesis"]["result"], {"pass", "skip"})

    def test_qor_family_drops_stale_metrics_after_failed_rerun(self) -> None:
        if shutil.which("yosys") is None:
            self.skipTest("missing required tool: yosys")
        false_tool = shutil.which("false")
        if false_tool is None:
            self.skipTest("missing required tool: false")

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            good_args = self.make_available_args()
            manifests = experiments_run.prepare_branch_manifests(good_args, build_root)

            with patch.object(experiments_run, "prepare_branch_manifests", return_value=manifests):
                initial_summary = experiments_run.run_qor_family(good_args, build_root)
                self.assertEqual(initial_summary["overall_result"], "pass")

                bad_args = self.make_available_args()
                bad_args.yosys = false_tool
                failed_summary = experiments_run.run_qor_family(bad_args, build_root)

            self.assertEqual(failed_summary["overall_result"], "fail")
            failed_results = {item["branch"]: item for item in failed_summary["results"]}
            for branch_name in ("rtl", "rtl-formalize-synthesis"):
                with self.subTest(branch=branch_name):
                    self.assertEqual(failed_results[branch_name]["result"], "fail")
                    self.assertEqual(failed_results[branch_name]["metrics"], experiments_run.empty_qor_metrics())
                    self.assertEqual(failed_results[branch_name]["artifacts"]["json"], "")
                    self.assertEqual(failed_results[branch_name]["artifacts"]["netlist"], "")

    def test_qor_family_fails_early_when_contract_preflight_fails(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            fail_step = experiments_run.make_step(
                name="contract_validation",
                result="fail",
                command="python3 -m contract.src.freeze --check",
                log_path=build_root / "contract_validation.log",
                details={"reason": "broken canonical contract", "gating": True},
            )

            with (
                patch.object(experiments_run, "run_contract_preflight_step", return_value=fail_step),
                patch.object(experiments_run, "prepare_branch_manifests") as prepare_manifests,
            ):
                summary = experiments_run.run_qor_family(self.make_args(), build_root)

            prepare_manifests.assert_not_called()
            self.assertEqual(summary["overall_result"], "fail")
            self.assertEqual([item["name"] for item in summary["results"]], ["contract_validation"])
            self.assertEqual(summary["results"][0]["evidence_boundary"], "canonical_contract_validation")
            self.assertEqual(summary["results"][0]["result"], "fail")

    def test_stale_sparkle_generated_core_fails_experiment_families(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            stale_root = build_root / "stale-sparkle"
            stale_root.mkdir(parents=True, exist_ok=True)
            wrapper_path = stale_root / "sparkle_mlp_core_wrapper.sv"
            core_path = stale_root / "sparkle_mlp_core.sv"
            source_path = stale_root / "ContractData.lean"
            self.write_valid_sparkle_artifacts(core_path, wrapper_path)
            source_path.write_text("-- newer source\n", encoding="utf-8")
            os.utime(wrapper_path, (10, 10))
            os.utime(core_path, (10, 10))
            os.utime(source_path, (20, 20))

            manifest = self.make_sparkle_manifest([wrapper_path, core_path])
            args = self.make_args()
            empty_metrics = experiments_run.empty_qor_metrics()

            with (
                patch.object(experiments_run, "SPARKLE_FULL_CORE_WRAPPER", wrapper_path),
                patch.object(experiments_run, "SPARKLE_FULL_CORE_RTL", core_path),
                patch.object(experiments_run, "sparkle_generated_full_core_sources", return_value=[source_path]),
                patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl-formalize-synthesis": manifest}),
            ):
                artifact_summary = experiments_run.run_artifact_consistency_family(args, build_root)
                self.assertEqual(artifact_summary["overall_result"], "fail")
                self.assertEqual(artifact_summary["results"][1]["name"], "sparkle_generated_core_freshness")
                self.assertEqual(artifact_summary["results"][1]["result"], "fail")

                branch_summary = experiments_run.run_branch_compare_family(args, build_root)
                self.assertEqual(branch_summary["overall_result"], "fail")
                sparkle_branch = branch_summary["branches"][0]
                self.assertEqual(sparkle_branch["overall_result"], "fail")
                self.assertEqual([step["name"] for step in sparkle_branch["steps"]], ["sparkle_generated_core_freshness"])

                qor_summary = experiments_run.run_qor_family(args, build_root)
                self.assertEqual(qor_summary["overall_result"], "fail")
                sparkle_qor = qor_summary["results"][0]
                self.assertEqual(sparkle_qor["result"], "fail")
                self.assertEqual(sparkle_qor["metrics"], empty_metrics)
                self.assertEqual(sparkle_qor["metrics_basis"], experiments_run.QOR_METRICS_BASIS)
                self.assertIn("older than the newest Sparkle source input", sparkle_qor["details"]["reason"])

                post_synth_summary = experiments_run.run_post_synth_family(args, build_root)
                self.assertEqual(post_synth_summary["overall_result"], "fail")
                sparkle_post_synth = post_synth_summary["results"][0]
                self.assertEqual(sparkle_post_synth["result"], "fail")
                self.assertEqual([step["name"] for step in sparkle_post_synth["steps"]], ["sparkle_generated_core_freshness"])

    def test_stale_sparkle_wrapper_fails_freshness_check(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            stale_root = Path(tmpdir)
            wrapper_path = stale_root / "sparkle_mlp_core_wrapper.sv"
            core_path = stale_root / "sparkle_mlp_core.sv"
            source_path = stale_root / "ContractData.lean"
            self.write_valid_sparkle_artifacts(core_path, wrapper_path)
            source_path.write_text("-- stale check source\n", encoding="utf-8")
            os.utime(source_path, (10, 10))
            os.utime(core_path, (20, 20))
            os.utime(wrapper_path, (20, 20))

            with (
                patch.object(experiments_run, "SPARKLE_FULL_CORE_WRAPPER", wrapper_path),
                patch.object(experiments_run, "SPARKLE_FULL_CORE_RTL", core_path),
                patch.object(experiments_run, "sparkle_generated_full_core_sources", return_value=[source_path]),
            ):
                step = experiments_run.make_sparkle_generated_core_freshness_step(stale_root / "freshness.log")

            self.assertEqual(step["result"], "fail")
            self.assertIn("stable wrapper is older", step["details"]["reason"])
            self.assertEqual(
                step["details"]["newest_wrapper_input"],
                experiments_run.relative(experiments_run.SPARKLE_WRAPPER_GENERATOR),
            )

    def test_missing_sparkle_dependency_fails_freshness_check(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            stale_root = Path(tmpdir)
            wrapper_path = stale_root / "sparkle_mlp_core_wrapper.sv"
            core_path = stale_root / "sparkle_mlp_core.sv"
            source_path = stale_root / "ContractData.lean"
            missing_dependency = stale_root / "lake-manifest.json"
            self.write_valid_sparkle_artifacts(core_path, wrapper_path)
            source_path.write_text("-- freshness check source\n", encoding="utf-8")

            with (
                patch.object(experiments_run, "SPARKLE_FULL_CORE_WRAPPER", wrapper_path),
                patch.object(experiments_run, "SPARKLE_FULL_CORE_RTL", core_path),
                patch.object(experiments_run, "sparkle_generated_full_core_sources", return_value=[source_path, missing_dependency]),
            ):
                step = experiments_run.make_sparkle_generated_core_freshness_step(stale_root / "freshness.log")

            self.assertEqual(step["result"], "fail")
            self.assertEqual(step["details"]["reason"], "missing Sparkle generated branch artifact or source dependency")
            self.assertIn(experiments_run.relative(missing_dependency), step["details"]["missing_paths"])

    def test_malformed_sparkle_generated_core_fails_freshness_check(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            stale_root = Path(tmpdir)
            wrapper_path = stale_root / "sparkle_mlp_core_wrapper.sv"
            core_path = stale_root / "sparkle_mlp_core.sv"
            source_path = stale_root / "ContractData.lean"
            core_path.write_text("module TinyMLP_sparkleMlpCorePacked (input logic clk);\nendmodule\n", encoding="utf-8")
            wrapper_path.write_text("module mlp_core; endmodule\n", encoding="utf-8")
            source_path.write_text("-- freshness check source\n", encoding="utf-8")

            with (
                patch.object(experiments_run, "SPARKLE_FULL_CORE_WRAPPER", wrapper_path),
                patch.object(experiments_run, "SPARKLE_FULL_CORE_RTL", core_path),
                patch.object(experiments_run, "sparkle_generated_full_core_sources", return_value=[source_path]),
            ):
                step = experiments_run.make_sparkle_generated_core_freshness_step(stale_root / "freshness.log")

            self.assertEqual(step["result"], "fail")
            self.assertEqual(step["details"]["validation_failure_kind"], "malformed_raw_rtl")
            self.assertIn("raw-module validation", step["details"]["reason"])

    def test_mismatched_sparkle_wrapper_fails_freshness_check(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            stale_root = Path(tmpdir)
            wrapper_path = stale_root / "sparkle_mlp_core_wrapper.sv"
            core_path = stale_root / "sparkle_mlp_core.sv"
            source_path = stale_root / "ContractData.lean"
            self.write_valid_sparkle_artifacts(core_path, wrapper_path)
            wrapper_path.write_text("module mlp_core; endmodule\n", encoding="utf-8")
            source_path.write_text("-- freshness check source\n", encoding="utf-8")

            with (
                patch.object(experiments_run, "SPARKLE_FULL_CORE_WRAPPER", wrapper_path),
                patch.object(experiments_run, "SPARKLE_FULL_CORE_RTL", core_path),
                patch.object(experiments_run, "sparkle_generated_full_core_sources", return_value=[source_path]),
            ):
                step = experiments_run.make_sparkle_generated_core_freshness_step(stale_root / "freshness.log")

            self.assertEqual(step["result"], "fail")
            self.assertEqual(step["details"]["validation_failure_kind"], "wrapper_mismatch")
            self.assertIn("stable wrapper does not match", step["details"]["reason"])

    def test_sparkle_generated_full_core_sources_include_emit_dependencies(self) -> None:
        source_paths = {experiments_run.relative(path) for path in experiments_run.sparkle_generated_full_core_sources()}

        self.assertIn("rtl-formalize-synthesis/patches/sparkle-local.patch", source_paths)
        self.assertIn("rtl-formalize-synthesis/lean-toolchain", source_paths)
        self.assertIn("rtl-formalize-synthesis/lake-manifest.json", source_paths)

    def test_post_synth_family_skips_when_openlane_flow_missing(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            result = run_experiments(
                "--family",
                "post-synth",
                "--build-root",
                str(build_root),
                "--openlane-flow",
                "__missing_openlane_flow__",
            )
            output = result.stdout + result.stderr

            self.assertEqual(result.returncode, 0, msg=output)
            summary = json.loads((build_root / "post-synth" / "summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["overall_result"], "skip")
            self.assertTrue(all(item["result"] == "skip" for item in summary["results"]))
            self.assert_boundary_metadata(
                summary["results"][0],
                artifact_kind="baseline_full_core_rtl",
                assembly_boundary="full_core_mlp_core",
                evidence_boundary="openlane_post_synth_flow",
                evidence_method="post_synthesis_validation",
            )
            self.assert_simulation_profile(
                summary["results"][0],
                bench_kind=experiments_run.GATE_LEVEL_BENCH_KIND,
                required_simulators=["iverilog"],
            )

    def test_post_synth_family_skips_unavailable_branch_source_set_without_openlane_config(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            pass_step = experiments_run.make_step(
                name="contract_validation",
                result="pass",
                command="python3 -m contract.src.freeze --check",
                log_path=build_root / "contract_validation.log",
                details={"gating": True},
            )
            manifest = self.make_rtl_synthesis_manifest(
                source_paths=[],
                source_kind="fresh_flow_unavailable",
                result="skip",
                reason="required fresh-flow toolchain is unavailable",
            )

            with (
                patch.object(experiments_run, "run_contract_preflight_step", return_value=pass_step),
                patch.object(experiments_run, "prepare_branch_manifests", return_value={"rtl-synthesis": manifest}),
            ):
                summary = experiments_run.run_post_synth_family(self.make_args(), build_root)

            self.assertEqual(summary["overall_result"], "skip")
            branch = summary["results"][0]
            self.assertEqual(branch["branch"], "rtl-synthesis")
            self.assertEqual(branch["result"], "skip")
            self.assertEqual([step["name"] for step in branch["steps"]], ["branch_source_set"])
            self.assertEqual(branch["steps"][0]["result"], "skip")
            self.assertNotIn("openlane_config", branch["artifacts"])
            self.assertFalse((build_root / "post-synth" / "rtl-synthesis" / "openlane_design" / "config.json").exists())

    def test_post_synth_family_fails_early_when_contract_preflight_fails(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_root = Path(tmpdir)
            fail_step = experiments_run.make_step(
                name="contract_validation",
                result="fail",
                command="python3 -m contract.src.freeze --check",
                log_path=build_root / "contract_validation.log",
                details={"reason": "broken canonical contract", "gating": True},
            )

            with (
                patch.object(experiments_run, "run_contract_preflight_step", return_value=fail_step),
                patch.object(experiments_run, "prepare_branch_manifests") as prepare_manifests,
            ):
                summary = experiments_run.run_post_synth_family(self.make_args(), build_root)

            prepare_manifests.assert_not_called()
            self.assertEqual(summary["overall_result"], "fail")
            self.assertEqual([item["name"] for item in summary["results"]], ["contract_validation"])
            self.assertEqual(summary["results"][0]["evidence_boundary"], "canonical_contract_validation")
            self.assertEqual(summary["results"][0]["result"], "fail")


if __name__ == "__main__":
    unittest.main()
