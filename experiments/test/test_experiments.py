from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from experiments import run as experiments_run


ROOT = Path(__file__).resolve().parents[2]


def run_experiments(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", "experiments/run.py", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class ExperimentFlowTests(unittest.TestCase):
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
            self.assertEqual(summary["results"][0]["name"], "freeze_check")

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
            self.assertEqual(rtl_synthesis_branch["generation_scope"], "controller")
            self.assertEqual(rtl_synthesis_branch["integration_scope"], "mixed-path mlp_core")
            self.assertEqual(rtl_synthesis_branch["validation_scope"], "mixed-path mlp_core")
            sparkle_branch = next(item for item in summary["branches"] if item["branch"] == "rtl-formalize-synthesis")
            self.assertEqual(sparkle_branch["generation_scope"], "full-core")
            self.assertEqual(sparkle_branch["integration_scope"], "full-core mlp_core")
            self.assertEqual(sparkle_branch["validation_scope"], "full-core mlp_core")
            self.assertEqual(sparkle_branch["validation_method"], "shared full-core simulation")
            self.assertEqual(
                sparkle_branch["manifest"]["artifacts"]["generated_wrapper"],
                "experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core_wrapper.sv",
            )
            self.assertEqual(
                sparkle_branch["manifest"]["artifacts"]["generated_core"],
                "experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core.sv",
            )
            self.assertNotIn("controller_alias", sparkle_branch["manifest"]["artifacts"])

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
            self.assertEqual(results["rtl"]["metrics"]["cell_count"], 1343)
            self.assertEqual(results["rtl-formalize-synthesis"]["result"], "pass")
            self.assertEqual(results["rtl-synthesis"]["generation_scope"], "controller")
            self.assertEqual(results["rtl-synthesis"]["integration_scope"], "mixed-path mlp_core")
            self.assertEqual(results["rtl-synthesis"]["validation_scope"], "full-core mlp_core")
            self.assertEqual(results["rtl-formalize-synthesis"]["generation_scope"], "full-core")
            self.assertEqual(results["rtl-formalize-synthesis"]["integration_scope"], "full-core mlp_core")
            self.assertEqual(results["rtl-formalize-synthesis"]["validation_scope"], "full-core mlp_core")
            self.assertEqual(results["rtl-formalize-synthesis"]["validation_method"], "qor characterization")
            self.assertIn(results["rtl-synthesis"]["result"], {"pass", "skip"})

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


if __name__ == "__main__":
    unittest.main()
