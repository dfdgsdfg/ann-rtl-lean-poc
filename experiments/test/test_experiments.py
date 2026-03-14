from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


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
