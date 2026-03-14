from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MAKEFILE_TEMPLATE = ROOT / "Makefile"
RTL_CONTROLLER = ROOT / "rtl" / "src" / "controller.sv"
GENERATED_CONTROLLER_WRAPPER = ROOT / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller_wrapper.sv"
GENERATED_CONTROLLER_TB = ROOT / "simulations" / "rtl-formalize-synthesis" / "generated_controller_testbench.sv"
CHECK_SCRIPT = ROOT / "smt" / "rtl" / "check_generated_controller.py"
FORMAL_CONTROLLER_DIR = ROOT / "smt" / "rtl" / "controller"

FAKE_GENERATED_CONTROLLER = """\
module TinyMLP_sparkleControllerPacked (
  input  logic       _gen_start,
  input  logic [3:0] _gen_hidden_idx,
  input  logic [3:0] _gen_input_idx,
  input  logic [3:0] _gen_inputNeurons4b,
  input  logic [3:0] _gen_hiddenNeurons4b,
  input  logic [3:0] _gen_lastHiddenIdx,
  input  logic       clk,
  input  logic       rst,
  output logic [13:0] out
);
  assign out = 14'd0;
endmodule
"""


def _write_executable(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class GeneratedControllerFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name) / "generated-controller-repo"
        self.temp_root.mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, self.temp_root / "Makefile")
        (self.temp_root / "rtl" / "src").mkdir(parents=True, exist_ok=True)
        shutil.copy2(RTL_CONTROLLER, self.temp_root / "rtl" / "src" / "controller.sv")
        (self.temp_root / "experiments" / "rtl-formalize-synthesis" / "sparkle").mkdir(parents=True, exist_ok=True)
        shutil.copy2(
            GENERATED_CONTROLLER_WRAPPER,
            self.temp_root / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller_wrapper.sv",
        )
        (self.temp_root / "simulations" / "rtl-formalize-synthesis").mkdir(parents=True, exist_ok=True)
        shutil.copy2(
            GENERATED_CONTROLLER_TB,
            self.temp_root / "simulations" / "rtl-formalize-synthesis" / "generated_controller_testbench.sv",
        )
        (self.temp_root / "smt" / "rtl").mkdir(parents=True, exist_ok=True)
        shutil.copy2(CHECK_SCRIPT, self.temp_root / "smt" / "rtl" / "check_generated_controller.py")
        shutil.copytree(
            FORMAL_CONTROLLER_DIR,
            self.temp_root / "smt" / "rtl" / "controller",
            dirs_exist_ok=True,
        )
        (self.temp_root / "rtl-formalize-synthesis").mkdir(parents=True, exist_ok=True)
        (self.temp_root / "rtl-formalize-synthesis" / "lakefile.lean").write_text(
            "-- fake lakefile\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "lake-manifest.json").write_text(
            "{}\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "lean-toolchain").write_text(
            "leanprover/lean4:nightly\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLP").mkdir(parents=True, exist_ok=True)
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLP.lean").write_text(
            "import TinyMLP.Types\\nimport TinyMLP.ControllerSignal\\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLP" / "Types.lean").write_text(
            "-- fake types module\\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLP" / "ControllerSignal.lean").write_text(
            "-- fake controller module\\n",
            encoding="utf-8",
        )
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLP" / "Emit.lean").write_text(
            "-- fake emit entrypoint\n",
            encoding="utf-8",
        )

        self.tools_dir = self.temp_root / "fake-tools"
        self.tools_dir.mkdir(parents=True, exist_ok=True)
        self._write_fake_tools()

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def _write_fake_tools(self) -> None:
        _write_executable(
            self.tools_dir / "lake",
            f"""#!/usr/bin/env python3
import pathlib
import sys

cwd = pathlib.Path.cwd()
pkg_src = cwd / "src"
root_module = pkg_src / "TinyMLP.lean"
emit_module = pkg_src / "TinyMLP" / "Emit.lean"
artifact = cwd.parent / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller.sv"

if not root_module.exists():
    raise SystemExit("missing src/TinyMLP.lean")
if not emit_module.exists():
    raise SystemExit("missing src/TinyMLP/Emit.lean")

if len(sys.argv) >= 2 and sys.argv[1] == "build":
    root_text = root_module.read_text(encoding="utf-8")
    if "import TinyMLP.Emit" in root_text:
        raise SystemExit("build should not import TinyMLP.Emit")
    raise SystemExit(0)

if len(sys.argv) >= 4 and sys.argv[1] == "env" and sys.argv[2] == "lean":
    if pathlib.Path(sys.argv[3]) != pathlib.Path("src/TinyMLP/Emit.lean"):
        raise SystemExit(f"unexpected emit entrypoint: {{sys.argv[3]}}")
    artifact.parent.mkdir(parents=True, exist_ok=True)
    artifact.write_text({FAKE_GENERATED_CONTROLLER!r}, encoding="utf-8")
    raise SystemExit(0)

raise SystemExit(f"unexpected lake invocation: {{sys.argv}}")
""",
        )
        _write_executable(
            self.tools_dir / "yosys",
            """#!/usr/bin/env python3
import pathlib
import re
import sys

if "-V" in sys.argv:
    print("Yosys fake 0.1")
    raise SystemExit(0)

script = pathlib.Path(sys.argv[sys.argv.index("-s") + 1])
text = script.read_text(encoding="utf-8")
cwd = pathlib.Path.cwd()

smt2_match = re.search(r"write_smt2 -wires (\\S+)", text)
if smt2_match:
    out_path = cwd / smt2_match.group(1)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("; fake smt2\\n", encoding="utf-8")
""",
        )
        _write_executable(
            self.tools_dir / "yosys-smtbmc",
            """#!/usr/bin/env python3
import sys

if "--version" in sys.argv:
    print("yosys-smtbmc fake 0.1")
    raise SystemExit(0)

print("Status: PASSED")
""",
        )
        _write_executable(
            self.tools_dir / "z3",
            """#!/usr/bin/env python3
import sys

if "--version" in sys.argv or "-version" in sys.argv:
    print("Z3 fake 0.1")
else:
    print("Z3 fake")
""",
        )

    def _make_env(self) -> dict[str, str]:
        env = dict(**os.environ)
        env["PATH"] = f"{self.tools_dir}{os.pathsep}{env.get('PATH', '')}"
        return env

    def test_make_rtl_formalize_build_does_not_emit_artifact(self) -> None:
        artifact_path = self.temp_root / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller.sv"
        self.assertFalse(artifact_path.exists())

        result = subprocess.run(
            ["make", "rtl-formalize-synthesis-build"],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            env=self._make_env(),
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertFalse(artifact_path.exists(), msg=output)

    def test_make_n_sim_generated_controller_resolves_emitted_artifact_target(self) -> None:
        result = subprocess.run(
            ["make", "-n", "sim-generated-controller"],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("cd rtl-formalize-synthesis && lake build", output)
        self.assertIn("cd rtl-formalize-synthesis && lake env lean src/TinyMLP/Emit.lean", output)
        self.assertIn("iverilog -g2012 -s generated_controller_testbench", output)

    def test_make_smt_generated_controller_writes_multi_job_summary(self) -> None:
        result = subprocess.run(
            [
                "make",
                "smt-generated-controller",
                f"SMT_YOSYS={self.tools_dir / 'yosys'}",
                f"SMT_SMTBMC={self.tools_dir / 'yosys-smtbmc'}",
                f"SMT_Z3={self.tools_dir / 'z3'}",
            ],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            env=self._make_env(),
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("PASS parameter_equivalence generated_controller_equivalence_default", output)
        self.assertIn("PASS parameter_equivalence generated_controller_equivalence_3x5", output)
        self.assertIn("PASS parameter_equivalence generated_controller_equivalence_1x1", output)
        self.assertIn("PASS illegal_state_recovery generated_controller_illegal_state_recovery", output)

        summary_path = self.temp_root / "build" / "smt" / "generated_controller_summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))

        self.assertEqual(summary["overall_result"], "pass")
        self.assertEqual(
            summary["claim_scope"],
            "bounded equivalence through the parameterized sparkle_controller_wrapper boundary",
        )
        self.assertEqual(len(summary["results"]), 4)
        self.assertEqual(
            {result["family"] for result in summary["results"]},
            {"parameter_equivalence", "illegal_state_recovery"},
        )
        self.assertTrue(
            (self.temp_root / "experiments" / "rtl-formalize-synthesis" / "sparkle" / "sparkle_controller.sv").exists()
        )


if __name__ == "__main__":
    unittest.main()
