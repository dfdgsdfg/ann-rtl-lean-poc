from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FORMALIZE_SMT_SRC = ROOT / "formalize-smt" / "src" / "MlpCoreSmt"


def run_formalize_smt_lean(input_text: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["lake", "env", "lean", "--stdin"],
        cwd=ROOT / "formalize-smt",
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )


class FormalizeSmtSurfaceTests(unittest.TestCase):
    def test_mirrored_surface_is_available_from_root_import(self) -> None:
        if shutil.which("lake") is None:
            self.skipTest("missing required tool: lake")

        result = run_formalize_smt_lean(
            """\
import MlpCoreSmt
open MlpCore

#check MlpCoreSmt.int8_mul_int8_bounds
#check MlpCoreSmt.hiddenSpecAt8_0_bounds
#check MlpCoreSmt.w1Int8At_toInt
#check MlpCoreSmt.hiddenFixed_eq_hiddenSpec
#check MlpCoreSmt.initialState_indexInvariant
#check MlpCoreSmt.rtl_correct
#check MlpCoreSmt.acceptedStart_eventually_done
#check MlpCoreSmt.phase_ordering_ok
#check MlpCoreSmt.fixedPoint_matchesSpec
#check MlpCoreSmt.rtl_correctness_goal

example (lhs rhs : Int8) : Int16Bounds (lhs.toInt * rhs.toInt) :=
  MlpCoreSmt.int8_mul_int8_bounds lhs rhs

example (input : Input8) :
    @mlpFixed MlpCoreSmt.smtArithmeticProofProvider input = mlpSpec (toMathInput input) :=
  MlpCoreSmt.fixedPoint_matchesSpec input

example (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) idleState) :
    doneOf (@rtlTrace MlpCoreSmt.smtArithmeticProofProvider samples totalCycles) :=
  MlpCoreSmt.temporal_acceptedStart_eventually_done samples haccept
"""
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, msg=output)

    def test_smt_lane_does_not_import_vanilla_proof_modules(self) -> None:
        offending: list[str] = []
        for path in sorted(FORMALIZE_SMT_SRC.glob("*.lean")):
            text = path.read_text(encoding="utf-8")
            if "MlpCore.Proofs." in text:
                offending.append(str(path.relative_to(ROOT)))

        self.assertEqual(offending, [], msg="\n".join(offending))


if __name__ == "__main__":
    unittest.main()
