from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from simulations.runners import run as simulation_run


ROOT = Path(__file__).resolve().parents[2]


class SimulationRunnerTests(unittest.TestCase):
    def load_summary(self, report_root: Path, profile: str) -> dict[str, object]:
        path = report_root / "canonical" / "simulations" / profile / "summary.json"
        return json.loads(path.read_text(encoding="utf-8"))

    def test_parse_regression_output_extracts_counts_and_first_failure(self) -> None:
        output = "\n".join(
            [
                "FAIL idx=2 latency=80: busy deasserted during active computation",
                "---",
                "vectors:    4",
                "passes:     3",
                "failures:   1",
                "output:     0",
                "latency:    1",
                "handshake:  0",
                "coverage:   0",
                "FAIL total_errors=1",
            ]
        )

        regression = simulation_run.parse_regression_output(output)

        self.assertEqual(regression["vectors"], 4)
        self.assertEqual(regression["passes"], 3)
        self.assertEqual(regression["failures"], 1)
        self.assertEqual(
            regression["error_counts"],
            {"output": 0, "latency": 1, "handshake": 0, "coverage": 0},
        )
        self.assertEqual(
            regression["failure_summary"],
            "FAIL idx=2 latency=80: busy deasserted during active computation",
        )

    def test_run_iverilog_compile_failure_reports_failure_summary(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_dir = Path(tmpdir)
            with patch.object(simulation_run, "run_command", return_value=(1, "syntax error\nat line 12\n")):
                result = simulation_run.run_iverilog(
                    top_module="testbench",
                    bench=simulation_run.TOP_LEVEL_TB,
                    sources=[simulation_run.BRANCH_SOURCES["rtl"][0]],
                    build_dir=build_dir,
                    iverilog="iverilog",
                    vvp="vvp",
                )

        self.assertEqual(result["result"], "fail")
        self.assertEqual(result["failure_summary"], "syntax error")
        self.assertNotIn("regression", result)

    def test_run_verilator_runtime_failure_keeps_regression_counts_and_failure_summary(self) -> None:
        runtime_output = "\n".join(
            [
                "FAIL idx=7 inputs=ff00: expected latency=76 got=75",
                "---",
                "vectors:    8",
                "passes:     7",
                "failures:   1",
                "output:     0",
                "latency:    1",
                "handshake:  0",
                "coverage:   0",
                "FAIL total_errors=1",
            ]
        )

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            build_dir = Path(tmpdir)
            with patch.object(
                simulation_run,
                "run_command",
                side_effect=[
                    (0, "compile ok\n"),
                    (1, runtime_output),
                ],
            ):
                result = simulation_run.run_verilator(
                    top_module="testbench",
                    bench=simulation_run.TOP_LEVEL_TB,
                    sources=[simulation_run.BRANCH_SOURCES["rtl"][0]],
                    build_dir=build_dir,
                    verilator="verilator",
                )

        self.assertEqual(result["result"], "fail")
        self.assertEqual(result["failure_summary"], "FAIL idx=7 inputs=ff00: expected latency=76 got=75")
        self.assertEqual(
            result["regression"],
            {
                "vectors": 8,
                "passes": 7,
                "failures": 1,
                "error_counts": {
                    "output": 0,
                    "latency": 1,
                    "handshake": 0,
                    "coverage": 0,
                },
                "failure_summary": "FAIL idx=7 inputs=ff00: expected latency=76 got=75",
            },
        )

    def test_main_writes_summary_with_branch_metadata_and_branch_local_sources(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            tmp_root = Path(tmpdir)
            build_root = tmp_root / "build-root"
            report_root = tmp_root / "report-root"
            with (
                patch.object(simulation_run, "ensure_tools"),
                patch.object(simulation_run, "validate_canonical_contract_bundle"),
                patch.object(simulation_run, "tool_version", side_effect=lambda *_args, **_kwargs: "tool 1.0"),
                patch.object(
                    simulation_run,
                    "run_iverilog",
                    return_value={
                        "name": "iverilog",
                        "result": "pass",
                        "regression": {"vectors": 10, "passes": 10, "failures": 0},
                    },
                ),
                patch.object(
                    simulation_run,
                    "run_verilator",
                    return_value={
                        "name": "verilator",
                        "result": "pass",
                        "regression": {"vectors": 10, "passes": 10, "failures": 0},
                    },
                ),
                patch.object(simulation_run, "timestamp_utc", return_value="2026-03-16T00:00:00+00:00"),
            ):
                exit_code = simulation_run.main(
                    [
                        "--branch",
                        "rtl-synthesis",
                        "--profile",
                        "shared",
                        "--simulator",
                        "all",
                        "--build-root",
                        str(build_root),
                        "--report-root",
                        str(report_root),
                        "--run-id",
                        "unit-shared",
                    ]
                )
                summary = self.load_summary(report_root, "shared")

        self.assertEqual(exit_code, 0)
        self.assertEqual(summary["overall_result"], "pass")
        self.assertEqual(summary["branch"], "rtl-synthesis")
        self.assertEqual(summary["generation_scope"], "generated_controller_rtl")
        self.assertEqual(summary["integration_scope"], "mixed_path_mlp_core")
        self.assertEqual(summary["validation_scope"], "shared_full_core_mlp_core_regression")
        self.assertEqual(summary["bench_kind"], simulation_run.TOP_LEVEL_BENCH_KIND)
        self.assertEqual(summary["bench_path"], "simulations/rtl/testbench.sv")
        self.assertTrue(summary["bench_shared_with_baseline"])
        self.assertEqual(summary["export_tree"], "rtl-synthesis/results/canonical/sv")
        self.assertEqual(summary["sources"]["blueprint"], "rtl-synthesis/results/canonical/blueprint/mlp_core.svg")
        self.assertTrue(all(path.startswith("rtl-synthesis/results/canonical/sv/") for path in summary["sources"]["rtl"]))
        self.assertEqual(summary["results"][0]["regression"]["vectors"], 10)
        self.assertEqual(summary["tools"]["driver"], "python3 simulations/runners/run.py --branch rtl-synthesis --profile shared --simulator all")

    def test_main_internal_profile_uses_internal_scope_metadata(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            tmp_root = Path(tmpdir)
            build_root = tmp_root / "build-root"
            report_root = tmp_root / "report-root"
            with (
                patch.object(simulation_run, "ensure_tools"),
                patch.object(simulation_run, "validate_canonical_contract_bundle"),
                patch.object(simulation_run, "tool_version", side_effect=lambda *_args, **_kwargs: "tool 1.0"),
                patch.object(
                    simulation_run,
                    "run_iverilog",
                    return_value={"name": "iverilog", "result": "pass", "regression": {"vectors": 3, "passes": 3, "failures": 0}},
                ),
                patch.object(simulation_run, "timestamp_utc", return_value="2026-03-16T00:00:00+00:00"),
            ):
                exit_code = simulation_run.main(
                    [
                        "--branch",
                        "rtl-synthesis",
                        "--profile",
                        "internal",
                        "--simulator",
                        "iverilog",
                        "--build-root",
                        str(build_root),
                        "--report-root",
                        str(report_root),
                        "--run-id",
                        "unit-internal",
                    ]
                )
                summary = self.load_summary(report_root, "internal")

        self.assertEqual(exit_code, 0)
        self.assertEqual(summary["validation_scope"], "mixed_path_internal_observability_regression")
        self.assertEqual(summary["bench_kind"], simulation_run.INTERNAL_OBSERVABILITY_BENCH_KIND)
        self.assertEqual(summary["bench_path"], "simulations/rtl/testbench_internal.sv")
        self.assertEqual(summary["sources"]["testbench"], "simulations/rtl/testbench_internal.sv")

    def test_ensure_branch_surface_requires_mlp_core_blueprint(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            temp_root = Path(tmpdir)
            export_tree = temp_root / "sv"
            export_tree.mkdir(parents=True)
            source = export_tree / "mlp_core.sv"
            source.write_text("module mlp_core; endmodule\n", encoding="utf-8")
            blueprint = temp_root / "blueprint" / "mlp_core.svg"
            with (
                patch.dict(simulation_run.BRANCH_EXPORT_TREES, {"rtl": export_tree}, clear=False),
                patch.dict(simulation_run.BRANCH_SOURCES, {"rtl": [source]}, clear=False),
                patch.dict(simulation_run.BRANCH_BLUEPRINTS, {"rtl": blueprint}, clear=False),
            ):
                with self.assertRaises(SystemExit) as context:
                    simulation_run.ensure_branch_surface("rtl")

        self.assertIn("missing required branch-local simulation surface for rtl", str(context.exception))
        self.assertIn("mlp_core.svg", str(context.exception))

    def test_main_rejects_internal_profile_for_formalize_synthesis(self) -> None:
        with self.assertRaises(SystemExit) as context:
            simulation_run.main(["--branch", "rtl-formalize-synthesis", "--profile", "internal"])

        self.assertEqual(
            str(context.exception),
            "internal simulation profile is unsupported for rtl-formalize-synthesis",
        )


if __name__ == "__main__":
    unittest.main()
