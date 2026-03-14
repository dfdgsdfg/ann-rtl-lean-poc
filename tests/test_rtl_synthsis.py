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


ROOT = Path(__file__).resolve().parents[1]

MAKEFILE_TEMPLATE = ROOT / "Makefile"
CONTRACT_RESULT_DIR = ROOT / "contract" / "result"
CONTRACT_SRC_DIR = ROOT / "contract" / "src"
RTL_SRC_DIR = ROOT / "rtl" / "src"
SIM_RTL_DIR = ROOT / "simulations" / "rtl"
SYNTHESIS_CONTROLLER_DIR = ROOT / "synthesis" / "controller"
RTL_SYNTHSIS_EXPERIMENT_DIR = ROOT / "experiments" / "generated-rtl" / "rtl-synthsis" / "spot"
RTL_SYNTHSIS_SPEC_DIR = ROOT / "specs" / "rtl-synthsis"
EXPERIMENT_TRACK_NOTE = ROOT / "experiments" / "generated-rtl-vs-rtl.md"


FAKE_AIGER = """\
aag 1 7 1 9 0
2
4
6
8
10
12
14
16 0
0
0
0
0
0
0
0
0
0
i0 start
i1 reset
i2 hidden_mac_active
i3 hidden_mac_guard
i4 last_hidden
i5 output_mac_active
i6 output_mac_guard
o0 phase_idle
o1 phase_load_input
o2 phase_mac_hidden
o3 phase_bias_hidden
o4 phase_act_hidden
o5 phase_next_hidden
o6 phase_mac_output
o7 phase_bias_output
o8 phase_done
c
fake ltlsynt output
"""


FAKE_CONTROLLER_CORE = """\
module controller_spot_core (
  input  logic clk,
  input  logic start,
  input  logic reset,
  input  logic hidden_mac_active,
  input  logic hidden_mac_guard,
  input  logic last_hidden,
  input  logic output_mac_active,
  input  logic output_mac_guard,
  output logic phase_idle,
  output logic phase_load_input,
  output logic phase_mac_hidden,
  output logic phase_bias_hidden,
  output logic phase_act_hidden,
  output logic phase_next_hidden,
  output logic phase_mac_output,
  output logic phase_bias_output,
  output logic phase_done
);
  localparam logic [3:0] IDLE = 4'd0;
  localparam logic [3:0] LOAD_INPUT = 4'd1;
  localparam logic [3:0] MAC_HIDDEN = 4'd2;
  localparam logic [3:0] BIAS_HIDDEN = 4'd3;
  localparam logic [3:0] ACT_HIDDEN = 4'd4;
  localparam logic [3:0] NEXT_HIDDEN = 4'd5;
  localparam logic [3:0] MAC_OUTPUT = 4'd6;
  localparam logic [3:0] BIAS_OUTPUT = 4'd7;
  localparam logic [3:0] DONE = 4'd8;

  logic [3:0] state;
  logic [3:0] next_state;

  always_comb begin
    unique case (state)
      IDLE:        next_state = start ? LOAD_INPUT : IDLE;
      LOAD_INPUT:  next_state = MAC_HIDDEN;
      MAC_HIDDEN:  next_state = hidden_mac_guard ? BIAS_HIDDEN : MAC_HIDDEN;
      BIAS_HIDDEN: next_state = ACT_HIDDEN;
      ACT_HIDDEN:  next_state = NEXT_HIDDEN;
      NEXT_HIDDEN: next_state = last_hidden ? MAC_OUTPUT : MAC_HIDDEN;
      MAC_OUTPUT:  next_state = output_mac_guard ? BIAS_OUTPUT : MAC_OUTPUT;
      BIAS_OUTPUT: next_state = DONE;
      DONE:        next_state = start ? DONE : IDLE;
      default:     next_state = IDLE;
    endcase

    if (reset) begin
      next_state = IDLE;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    phase_idle = (state == IDLE);
    phase_load_input = (state == LOAD_INPUT);
    phase_mac_hidden = (state == MAC_HIDDEN);
    phase_bias_hidden = (state == BIAS_HIDDEN);
    phase_act_hidden = (state == ACT_HIDDEN);
    phase_next_hidden = (state == NEXT_HIDDEN);
    phase_mac_output = (state == MAC_OUTPUT);
    phase_bias_output = (state == BIAS_OUTPUT);
    phase_done = (state == DONE);
  end
endmodule
"""


def _write_executable(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class RtlSynthsisFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name) / "rtl-synthsis-repo"
        self.temp_root.mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, self.temp_root / "Makefile")
        shutil.copytree(CONTRACT_RESULT_DIR, self.temp_root / "contract" / "result", dirs_exist_ok=True)
        shutil.copytree(CONTRACT_SRC_DIR, self.temp_root / "contract" / "src", dirs_exist_ok=True)
        shutil.copytree(RTL_SRC_DIR, self.temp_root / "rtl" / "src", dirs_exist_ok=True)
        shutil.copytree(SIM_RTL_DIR, self.temp_root / "simulations" / "rtl", dirs_exist_ok=True)
        shutil.copytree(SYNTHESIS_CONTROLLER_DIR, self.temp_root / "synthesis" / "controller", dirs_exist_ok=True)
        shutil.copytree(
            RTL_SYNTHSIS_EXPERIMENT_DIR,
            self.temp_root / "experiments" / "generated-rtl" / "rtl-synthsis" / "spot",
            dirs_exist_ok=True,
        )
        shutil.copytree(RTL_SYNTHSIS_SPEC_DIR, self.temp_root / "specs" / "rtl-synthsis", dirs_exist_ok=True)
        (self.temp_root / "experiments").mkdir(parents=True, exist_ok=True)
        shutil.copy2(EXPERIMENT_TRACK_NOTE, self.temp_root / "experiments" / "generated-rtl-vs-rtl.md")

        self.tools_dir = self.temp_root / "fake-tools"
        self.tools_dir.mkdir(parents=True, exist_ok=True)
        self._write_fake_tools()

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def _write_fake_tools(self) -> None:
        _write_executable(
            self.tools_dir / "ltlsynt",
            f"""#!/usr/bin/env python3
import sys

if "--version" in sys.argv:
    print("ltlsynt fake 1.0")
    raise SystemExit(0)

if "--realizability" in sys.argv:
    print("REALIZABLE")
    raise SystemExit(0)

sys.stdout.write({FAKE_AIGER!r})
""",
        )
        _write_executable(
            self.tools_dir / "syfco",
            """#!/usr/bin/env python3
import sys

if "--version" in sys.argv:
    print("syfco fake 1.0")
else:
    print("syfco fake")
""",
        )
        _write_executable(
            self.tools_dir / "yosys",
            f"""#!/usr/bin/env python3
import pathlib
import re
import sys

if "-V" in sys.argv:
    print("Yosys fake 0.1")
    raise SystemExit(0)

script = pathlib.Path(sys.argv[sys.argv.index("-s") + 1])
text = script.read_text(encoding="utf-8")
cwd = pathlib.Path.cwd()

verilog_match = re.search(r"write_verilog -sv -noattr (\\S+)", text)
if verilog_match:
    out_path = cwd / verilog_match.group(1)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text({FAKE_CONTROLLER_CORE!r}, encoding="utf-8")

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

if "-h" in sys.argv:
    print("yosys-smtbmc fake help")
    raise SystemExit(0)

print("Status: PASSED")
""",
        )
        _write_executable(
            self.tools_dir / "z3",
            """#!/usr/bin/env python3
import sys

if "-version" in sys.argv or "--version" in sys.argv:
    print("Z3 fake 0.1")
else:
    print("Z3 fake")
""",
        )

    def _make_env(self) -> dict[str, str]:
        env = dict(**os.environ)
        env["PATH"] = f"{self.tools_dir}{os.pathsep}{env.get('PATH', '')}"
        return env

    def _tool_args(self) -> list[str]:
        return [
            f"RTL_SYNTHSIS_LTLSYNT={self.tools_dir / 'ltlsynt'}",
            f"RTL_SYNTHSIS_SYFCO={self.tools_dir / 'syfco'}",
            f"RTL_SYNTHSIS_YOSYS={self.tools_dir / 'yosys'}",
            f"RTL_SYNTHSIS_SMTBMC={self.tools_dir / 'yosys-smtbmc'}",
            f"RTL_SYNTHSIS_Z3={self.tools_dir / 'z3'}",
        ]

    def test_make_rtl_synthsis_generates_summary_and_artifacts_with_fake_tools(self) -> None:
        result = subprocess.run(
            ["make", "rtl-synthsis", *self._tool_args()],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            env=self._make_env(),
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("PASS realisability", output)
        self.assertIn("PASS aiger_generation", output)
        self.assertIn("PASS controller_equivalence", output)

        summary_path = self.temp_root / "build" / "rtl-synthsis" / "spot" / "rtl_synthsis_summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        self.assertEqual(summary["overall_result"], "pass")
        self.assertEqual(summary["claim_scope"], "controller-only equivalence through the raw controller module boundary")

        generated_dir = self.temp_root / "build" / "rtl-synthsis" / "spot" / "generated"
        self.assertTrue((generated_dir / "controller_spot_core.sv").exists())
        self.assertTrue((generated_dir / "controller.sv").exists())
        self.assertTrue((generated_dir / "controller_spot.aag").exists())

    def test_make_rtl_synthsis_sim_runs_with_fake_tools(self) -> None:
        for tool in ("make", "iverilog", "vvp", "verilator"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        result = subprocess.run(
            ["make", "rtl-synthsis-sim", *self._tool_args()],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            env=self._make_env(),
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("PASS all vectors", output)


if __name__ == "__main__":
    unittest.main()
