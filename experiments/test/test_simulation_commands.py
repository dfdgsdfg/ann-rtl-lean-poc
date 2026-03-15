from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOP_LEVEL_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
INTERNAL_TB = ROOT / "simulations" / "rtl" / "testbench_internal.sv"


def run_make_dry_run(target: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["make", "-Bn", target],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class SimulationCommandTests(unittest.TestCase):
    def test_top_level_sim_targets_run_contract_preflight(self) -> None:
        for target in ("sim", "rtl-formalize-synthesis-sim", "rtl-synthesis-sim"):
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn("python3 -m contract.src.freeze --check", output)

    def test_internal_sim_targets_exist_for_baseline_and_rtl_synthesis(self) -> None:
        expectations = {
            "sim-internal": "vvp build/sim-internal/iverilog/testbench_internal.out",
            "rtl-synthesis-sim-internal": "vvp build/rtl-synthesis/spot/sim-internal/iverilog/testbench_internal.out",
        }
        for target, expected in expectations.items():
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn(expected, output)
                self.assertIn("python3 -m contract.src.freeze --check", output)
                self.assertIn("testbench_internal", output)

    def test_sparkle_emit_target_regenerates_raw_and_wrapper_artifacts(self) -> None:
        result = run_make_dry_run("rtl-formalize-synthesis-emit")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("rtl-formalize-synthesis/scripts/prepare_sparkle.sh", output)
        self.assertIn("build/rtl-formalize-synthesis/sparkle_prepare.stamp", output)
        self.assertIn("lake env lean src/TinyMLPSparkle/Emit.lean", output)
        self.assertIn("python3 rtl-formalize-synthesis/scripts/generate_wrapper.py", output)
        self.assertIn("sparkle_mlp_core_wrapper.sv", output)

    def test_sparkle_branch_aggregate_target_runs_both_simulators(self) -> None:
        result = run_make_dry_run("rtl-formalize-synthesis-sim")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 -m contract.src.freeze --check", output)
        self.assertIn("vvp build/rtl-formalize-synthesis/iverilog/testbench.out", output)
        self.assertIn("verilator --binary --timing", output)
        self.assertIn("build/rtl-formalize-synthesis/verilator", output)
        self.assertIn("build/rtl-formalize-synthesis/verilator/Vtestbench", output)
        self.assertNotIn("testbench_internal", output)

    def test_sparkle_branch_leaf_targets_exist(self) -> None:
        for target, expected in (
            ("rtl-formalize-synthesis-iverilog", "iverilog -g2012"),
            ("rtl-formalize-synthesis-verilator", "verilator --binary --timing"),
        ):
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn(expected, output)

    def test_top_level_bench_does_not_reference_internal_dut_state(self) -> None:
        top_level_bench = TOP_LEVEL_TB.read_text(encoding="utf-8")
        forbidden_tokens = (
            "dut.state",
            "dut.acc_reg",
            "dut.hidden_idx",
            "dut.input_regs",
            "dut.output_acc",
        )

        for token in forbidden_tokens:
            with self.subTest(token=token):
                self.assertNotIn(token, top_level_bench)

    def test_internal_bench_preserves_internal_observability_checks(self) -> None:
        internal_bench = INTERNAL_TB.read_text(encoding="utf-8")

        self.assertIn("module testbench_internal;", internal_bench)
        self.assertIn("dut.state", internal_bench)


if __name__ == "__main__":
    unittest.main()
