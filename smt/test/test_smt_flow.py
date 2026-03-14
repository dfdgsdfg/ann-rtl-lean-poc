from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class SmtFlowTests(unittest.TestCase):
    def test_contract_assumption_export_matches_frozen_contract(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
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

            self.assertEqual(exported["source_contract"], "contract/result/weights.json")
            self.assertEqual(exported["arithmetic"]["input_bits"], 8)
            self.assertEqual(exported["arithmetic"]["output_product_bits"], 24)
            self.assertEqual(exported["boundedness"]["status"], "verified")

    def test_make_smt_runs_all_smt_checks(self) -> None:
        for tool in ("make", "z3", "yosys", "yosys-smtbmc"):
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
        self.assertIn("controller_interface", output)
        self.assertIn("hidden_products_fit_int16", output)
        self.assertIn("out_bit_equivalent", output)

        rtl_summary = json.loads((ROOT / "build" / "smt" / "rtl_control_summary.json").read_text(encoding="utf-8"))
        contract_summary = json.loads((ROOT / "build" / "smt" / "contract_assumptions.json").read_text(encoding="utf-8"))
        overflow_summary = json.loads((ROOT / "build" / "smt" / "contract_overflow_summary.json").read_text(encoding="utf-8"))
        equivalence_summary = json.loads((ROOT / "build" / "smt" / "contract_equivalence_summary.json").read_text(encoding="utf-8"))

        self.assertEqual(rtl_summary["overall_result"], "pass")
        self.assertEqual(contract_summary["arithmetic"]["accumulator_bits"], 32)
        self.assertEqual(overflow_summary["overall_result"], "pass")
        self.assertEqual(equivalence_summary["overall_result"], "pass")
        self.assertEqual(
            {result["family"] for result in rtl_summary["results"]},
            {"controller_interface", "boundary_behavior", "range_safety", "transaction_capture", "bounded_latency"},
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
