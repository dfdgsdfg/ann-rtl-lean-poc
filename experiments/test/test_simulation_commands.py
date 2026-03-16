from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOP_LEVEL_TB = ROOT / "simulations" / "rtl" / "testbench.sv"
INTERNAL_TB = ROOT / "simulations" / "rtl" / "testbench_internal.sv"
SPARKLE_VENDOR_GIT = ROOT / "rtl-formalize-synthesis" / "vendor" / "Sparkle" / ".git"
SPARKLE_RAW = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv"
SPARKLE_WRAPPER = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "sv" / "mlp_core.sv"
SPARKLE_VERIFICATION_MANIFEST = ROOT / "rtl-formalize-synthesis" / "results" / "canonical" / "verification_manifest.json"
SPARKLE_WRAPPER_GENERATOR = ROOT / "rtl-formalize-synthesis" / "scripts" / "generate_wrapper.py"


def run_make_dry_run(target: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["make", "-Bn", target],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class SimulationCommandTests(unittest.TestCase):
    def test_formalize_target_builds_vanilla_lean_package(self) -> None:
        result = run_make_dry_run("formalize")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("command -v lake", output)
        self.assertIn("cd formalize && lake build", output)

    def test_verify_target_includes_formalize_sim_and_smt(self) -> None:
        result = run_make_dry_run("verify")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("cd formalize && lake build", output)
        self.assertIn("python3 contract/runners/freeze.py --check", output)
        self.assertIn("python3 simulations/runners/run.py --branch rtl --profile shared --simulator all", output)
        self.assertIn("python3 smt/runners/all.py", output)

    def test_top_level_sim_targets_run_contract_preflight(self) -> None:
        for target in ("sim", "rtl-formalize-synthesis-sim", "rtl-synthesis-sim"):
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn("python3 contract/runners/freeze.py --check", output)

    def test_internal_sim_targets_exist_for_baseline_and_rtl_synthesis(self) -> None:
        expectations = {
            "sim-internal": "python3 simulations/runners/run.py --branch rtl --profile internal --simulator all",
            "rtl-synthesis-sim-internal": "python3 simulations/runners/run.py --branch rtl-synthesis --profile internal --simulator all",
        }
        for target, expected in expectations.items():
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn(expected, output)
                self.assertIn("python3 contract/runners/freeze.py --check", output)

    def test_sparkle_emit_target_regenerates_raw_and_wrapper_artifacts(self) -> None:
        result = run_make_dry_run("rtl-formalize-synthesis-emit")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 rtl-formalize-synthesis/runners/emit.py --emit", output)

    def test_sparkle_emit_target_executes_without_dirtying_tracked_artifacts(self) -> None:
        if shutil.which("lake") is None:
            self.skipTest("missing required tool: lake")
        if shutil.which("git") is None:
            self.skipTest("missing required tool: git")
        if not SPARKLE_VENDOR_GIT.exists():
            self.skipTest("missing prepared Sparkle vendor checkout")

        emit = subprocess.run(
            ["make", "rtl-formalize-synthesis-emit"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        emit_output = emit.stdout + emit.stderr
        self.assertEqual(emit.returncode, 0, msg=emit_output)

        wrapper_check = subprocess.run(
            [
                "python3",
                str(SPARKLE_WRAPPER_GENERATOR),
                "--raw",
                str(SPARKLE_RAW),
                "--wrapper",
                str(SPARKLE_WRAPPER),
                "--subset-manifest",
                str(SPARKLE_VERIFICATION_MANIFEST),
                "--check",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        wrapper_check_output = wrapper_check.stdout + wrapper_check.stderr
        self.assertEqual(wrapper_check.returncode, 0, msg=wrapper_check_output)

        diff = subprocess.run(
            [
                "git",
                "diff",
                "--exit-code",
                "--",
                str(SPARKLE_RAW.relative_to(ROOT)),
                str(SPARKLE_WRAPPER.relative_to(ROOT)),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        diff_output = diff.stdout + diff.stderr
        self.assertEqual(diff.returncode, 0, msg=diff_output)

    def test_sparkle_branch_aggregate_target_runs_both_simulators(self) -> None:
        result = run_make_dry_run("rtl-formalize-synthesis-sim")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 contract/runners/freeze.py --check", output)
        self.assertIn("python3 simulations/runners/run.py --branch rtl-formalize-synthesis --profile shared --simulator all", output)
        self.assertNotIn("--profile internal", output)

    def test_sparkle_branch_leaf_targets_exist(self) -> None:
        for target, simulator in (
            ("rtl-formalize-synthesis-iverilog", "iverilog"),
            ("rtl-formalize-synthesis-verilator", "verilator"),
        ):
            with self.subTest(target=target):
                result = run_make_dry_run(target)
                output = result.stdout + result.stderr

                self.assertEqual(result.returncode, 0, msg=output)
                self.assertIn("python3 simulations/runners/run.py --branch rtl-formalize-synthesis --profile shared", output)
                self.assertIn(f"--simulator {simulator}", output)

    def test_sparkle_blueprint_target_builds_wrapper_and_raw_views(self) -> None:
        result = run_make_dry_run("rtl-formalize-synthesis-blueprint")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 rtl-formalize-synthesis/runners/blueprint.py", output)

    def test_baseline_blueprint_target_exists(self) -> None:
        result = run_make_dry_run("rtl-blueprint")
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 rtl/runners/blueprint.py", output)

    def test_canonical_top_level_blueprints_exist_for_all_rtl_branches(self) -> None:
        for branch in ("rtl", "rtl-synthesis", "rtl-formalize-synthesis"):
            with self.subTest(branch=branch):
                path = ROOT / branch / "results" / "canonical" / "blueprint" / "blueprint.svg"
                self.assertTrue(path.exists(), msg=str(path))
                self.assertGreater(path.stat().st_size, 0)

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
