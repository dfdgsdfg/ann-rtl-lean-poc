from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEST_TMP_ROOT = ROOT / "build" / "tests" / "tmp"


class SmtFlowTests(unittest.TestCase):
    def test_contract_assumption_export_matches_frozen_contract(self) -> None:
        TEST_TMP_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=TEST_TMP_ROOT) as tmpdir:
            output_path = Path(tmpdir) / "contract_assumptions.json"
            result = subprocess.run(
                [
                    "python3",
                    "smt/contract/export_assumptions.py",
                    "--output",
                    str(output_path),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            exported = json.loads(output_path.read_text(encoding="utf-8"))

            self.assertEqual(exported["source_contract"], "contract/results/canonical/weights.json")
            self.assertEqual(exported["selected_run_id"], "relu_teacher_v2-seed20260312-epoch51")
            self.assertEqual(exported["arithmetic"]["input_bits"], 8)
            self.assertEqual(exported["arithmetic"]["output_product_bits"], 24)
            self.assertEqual(exported["boundedness"]["status"], "verified")

    def test_make_smt_runs_all_smt_checks(self) -> None:
        for tool in ("make", "lake", "z3", "yosys", "yosys-smtbmc"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        result = subprocess.run(
            ["make", "smt"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("rtl controller_interface controller_interface", output)
        self.assertIn("rtl-formalize-synthesis boundary_behavior mlp_core_boundary_behavior", output)
        self.assertIn("hidden_products_fit_int16", output)
        self.assertIn("out_bit_equivalent", output)

        rtl_summary = json.loads((ROOT / "reports" / "smt" / "canonical" / "rtl" / "rtl" / "summary.json").read_text(encoding="utf-8"))
        sparkle_summary = json.loads((ROOT / "reports" / "smt" / "canonical" / "rtl" / "rtl-formalize-synthesis" / "summary.json").read_text(encoding="utf-8"))
        contract_summary = json.loads((ROOT / "reports" / "smt" / "canonical" / "contract" / "assumptions.json").read_text(encoding="utf-8"))
        overflow_summary = json.loads((ROOT / "reports" / "smt" / "canonical" / "contract" / "overflow" / "summary.json").read_text(encoding="utf-8"))
        equivalence_summary = json.loads((ROOT / "reports" / "smt" / "canonical" / "contract" / "equivalence" / "summary.json").read_text(encoding="utf-8"))

        self.assertEqual(rtl_summary["branch"], "rtl")
        self.assertEqual(rtl_summary["overall_result"], "pass")
        self.assertEqual(sparkle_summary["branch"], "rtl-formalize-synthesis")
        self.assertEqual(sparkle_summary["overall_result"], "pass")
        self.assertEqual(contract_summary["arithmetic"]["accumulator_bits"], 32)
        self.assertEqual(overflow_summary["overall_result"], "pass")
        self.assertEqual(equivalence_summary["overall_result"], "pass")
        self.assertEqual(
            {result["family"] for result in rtl_summary["results"]},
            {"controller_interface", "boundary_behavior", "range_safety", "transaction_capture", "bounded_latency"},
        )
        self.assertEqual(
            {result["family"] for result in sparkle_summary["results"]},
            {"wrapper_equivalence", "boundary_behavior", "range_safety", "transaction_capture", "bounded_latency"},
        )
        self.assertEqual(
            sparkle_summary["sources"]["rtl"],
            [
                "rtl-formalize-synthesis/results/canonical/sv/mlp_core.sv",
                "rtl-formalize-synthesis/results/canonical/sv/sparkle_mlp_core.sv",
            ],
        )
        self.assertEqual(overflow_summary["encoding"]["contract_hidden_product_bits"], 16)
        self.assertEqual(overflow_summary["encoding"]["rtl_hidden_product_bits"], 24)
        self.assertIn("sign-extend hidden inputs to 16 bits", overflow_summary["encoding"]["rtl_hidden_product_model"])
        self.assertEqual(equivalence_summary["encoding"]["contract_hidden_product_bits"], 16)
        self.assertEqual(equivalence_summary["encoding"]["rtl_hidden_product_bits"], 24)
        self.assertIn("sign-extend hidden inputs to 16 bits", equivalence_summary["encoding"]["rtl_hidden_product_model"])
        self.assertGreaterEqual(len(overflow_summary["results"]), 8)
        self.assertGreaterEqual(len(equivalence_summary["results"]), 6)


if __name__ == "__main__":
    unittest.main()
