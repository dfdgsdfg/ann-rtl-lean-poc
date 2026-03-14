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
CONTRACT_RESULT_DIR = ROOT / "contract" / "result"
CONTRACT_SRC_DIR = ROOT / "contract" / "src"
RTL_SRC_DIR = ROOT / "rtl" / "src"
SIM_RTL_DIR = ROOT / "simulations" / "rtl"
SIM_SHARED_DIR = ROOT / "simulations" / "shared"
RTL_SYNTHESIS_CONTROLLER_DIR = ROOT / "rtl-synthesis" / "controller"
RTL_SYNTHESIS_EXPERIMENT_DIR = ROOT / "experiments" / "rtl-synthesis" / "spot"
RTL_SYNTHESIS_SPEC_DIR = ROOT / "specs" / "rtl-synthesis"
EXPERIMENT_TRACK_NOTE = ROOT / "experiments" / "generated-rtl-vs-rtl.md"


FAKE_AIGER = """\
aag 17 17 0 9 0
2
4
6
8
10
12
14
16
18
20
22
24
26
28
30
32
34
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
i7 hidden_mac_pos_b0
i8 hidden_mac_pos_b1
i9 hidden_mac_pos_b2
i10 hidden_neuron_ord_b0
i11 hidden_neuron_ord_b1
i12 hidden_neuron_ord_b2
i13 output_mac_pos_b0
i14 output_mac_pos_b1
i15 output_mac_pos_b2
i16 output_mac_pos_b3
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
  input  logic hidden_mac_pos_b0,
  input  logic hidden_mac_pos_b1,
  input  logic hidden_mac_pos_b2,
  input  logic hidden_neuron_ord_b0,
  input  logic hidden_neuron_ord_b1,
  input  logic hidden_neuron_ord_b2,
  input  logic output_mac_pos_b0,
  input  logic output_mac_pos_b1,
  input  logic output_mac_pos_b2,
  input  logic output_mac_pos_b3,
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

RESET_RELEASE_ACCEPT_TB = """\
`timescale 1ns/1ps

module reset_release_accept_tb;
  logic clk;
  logic rst_n;
  logic start;
  logic [3:0] hidden_idx;
  logic [3:0] input_idx;

  logic [3:0] baseline_state;
  logic       baseline_load_input;
  logic       baseline_clear_acc;
  logic       baseline_do_mac_hidden;
  logic       baseline_do_bias_hidden;
  logic       baseline_do_act_hidden;
  logic       baseline_advance_hidden;
  logic       baseline_do_mac_output;
  logic       baseline_do_bias_output;
  logic       baseline_done;
  logic       baseline_busy;

  logic [3:0] generated_state;
  logic       generated_load_input;
  logic       generated_clear_acc;
  logic       generated_do_mac_hidden;
  logic       generated_do_bias_hidden;
  logic       generated_do_act_hidden;
  logic       generated_advance_hidden;
  logic       generated_do_mac_output;
  logic       generated_do_bias_output;
  logic       generated_done;
  logic       generated_busy;

  controller baseline_controller (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(baseline_state),
    .load_input(baseline_load_input),
    .clear_acc(baseline_clear_acc),
    .do_mac_hidden(baseline_do_mac_hidden),
    .do_bias_hidden(baseline_do_bias_hidden),
    .do_act_hidden(baseline_do_act_hidden),
    .advance_hidden(baseline_advance_hidden),
    .do_mac_output(baseline_do_mac_output),
    .do_bias_output(baseline_do_bias_output),
    .done(baseline_done),
    .busy(baseline_busy)
  );

  controller_spot_compat generated_controller (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .hidden_idx(hidden_idx),
    .input_idx(input_idx),
    .state(generated_state),
    .load_input(generated_load_input),
    .clear_acc(generated_clear_acc),
    .do_mac_hidden(generated_do_mac_hidden),
    .do_bias_hidden(generated_do_bias_hidden),
    .do_act_hidden(generated_do_act_hidden),
    .advance_hidden(generated_advance_hidden),
    .do_mac_output(generated_do_mac_output),
    .do_bias_output(generated_do_bias_output),
    .done(generated_done),
    .busy(generated_busy)
  );

  always #5 clk = ~clk;

  task automatic check_equal(input string label);
    begin
      if (baseline_state !== generated_state ||
          baseline_load_input !== generated_load_input ||
          baseline_clear_acc !== generated_clear_acc ||
          baseline_do_mac_hidden !== generated_do_mac_hidden ||
          baseline_do_bias_hidden !== generated_do_bias_hidden ||
          baseline_do_act_hidden !== generated_do_act_hidden ||
          baseline_advance_hidden !== generated_advance_hidden ||
          baseline_do_mac_output !== generated_do_mac_output ||
          baseline_do_bias_output !== generated_do_bias_output ||
          baseline_done !== generated_done ||
          baseline_busy !== generated_busy) begin
        $display(
          "FAIL %s state=%0d/%0d load=%0d/%0d clear=%0d/%0d mac_h=%0d/%0d bias_h=%0d/%0d act_h=%0d/%0d next_h=%0d/%0d mac_o=%0d/%0d bias_o=%0d/%0d done=%0d/%0d busy=%0d/%0d",
          label,
          baseline_state, generated_state,
          baseline_load_input, generated_load_input,
          baseline_clear_acc, generated_clear_acc,
          baseline_do_mac_hidden, generated_do_mac_hidden,
          baseline_do_bias_hidden, generated_do_bias_hidden,
          baseline_do_act_hidden, generated_do_act_hidden,
          baseline_advance_hidden, generated_advance_hidden,
          baseline_do_mac_output, generated_do_mac_output,
          baseline_do_bias_output, generated_do_bias_output,
          baseline_done, generated_done,
          baseline_busy, generated_busy
        );
        $finish_and_return(1);
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    hidden_idx = 4'd0;
    input_idx = 4'd0;

    repeat (2) @(negedge clk);
    start = 1'b1;
    rst_n = 1'b1;
    @(negedge clk);
    check_equal("accept_on_reset_release");

    start = 1'b0;
    @(negedge clk);
    check_equal("load_input_to_mac_hidden");

    $display("PASS reset release accept");
    $finish;
  end
endmodule
"""


def _write_executable(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class RtlSynthesisFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name) / "rtl-synthesis-repo"
        self.temp_root.mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, self.temp_root / "Makefile")
        shutil.copytree(CONTRACT_RESULT_DIR, self.temp_root / "contract" / "result", dirs_exist_ok=True)
        shutil.copytree(CONTRACT_SRC_DIR, self.temp_root / "contract" / "src", dirs_exist_ok=True)
        shutil.copytree(RTL_SRC_DIR, self.temp_root / "rtl" / "src", dirs_exist_ok=True)
        shutil.copytree(SIM_RTL_DIR, self.temp_root / "simulations" / "rtl", dirs_exist_ok=True)
        shutil.copytree(SIM_SHARED_DIR, self.temp_root / "simulations" / "shared", dirs_exist_ok=True)
        shutil.copytree(RTL_SYNTHESIS_CONTROLLER_DIR, self.temp_root / "rtl-synthesis" / "controller", dirs_exist_ok=True)
        shutil.copytree(
            RTL_SYNTHESIS_EXPERIMENT_DIR,
            self.temp_root / "experiments" / "rtl-synthesis" / "spot",
            dirs_exist_ok=True,
        )
        shutil.copytree(RTL_SYNTHESIS_SPEC_DIR, self.temp_root / "specs" / "rtl-synthesis", dirs_exist_ok=True)
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
            f"RTL_SYNTHESIS_LTLSYNT={self.tools_dir / 'ltlsynt'}",
            f"RTL_SYNTHESIS_SYFCO={self.tools_dir / 'syfco'}",
            f"RTL_SYNTHESIS_YOSYS={self.tools_dir / 'yosys'}",
            f"RTL_SYNTHESIS_SMTBMC={self.tools_dir / 'yosys-smtbmc'}",
            f"RTL_SYNTHESIS_Z3={self.tools_dir / 'z3'}",
        ]

    def test_controller_tlsf_records_exact_schedule_v1_assumptions(self) -> None:
        tlsf_path = ROOT / "rtl-synthesis" / "controller" / "controller.tlsf"
        tlsf_text = tlsf_path.read_text(encoding="utf-8")

        for signal in (
            "hidden_mac_pos_b0",
            "hidden_mac_pos_b1",
            "hidden_mac_pos_b2",
            "hidden_neuron_ord_b0",
            "hidden_neuron_ord_b1",
            "hidden_neuron_ord_b2",
            "output_mac_pos_b0",
            "output_mac_pos_b1",
            "output_mac_pos_b2",
            "output_mac_pos_b3",
        ):
            self.assertIn(f"    {signal};", tlsf_text)

        for snippet in (
            'DESCRIPTION: "Controller-only phase contract for rtl/src/controller.sv with exact_schedule_v1 assumptions"',
            "G(!reset && phase_mac_hidden -> (",
            "G(!reset && phase_mac_output -> (",
            "G(!reset && phase_next_hidden -> (",
            "G(!reset && phase_load_input -> X (",
            "G(!reset && phase_mac_hidden &&",
            "G(!reset && phase_bias_hidden -> X (",
            "G(!reset && phase_act_hidden -> X (",
            "G(!reset && phase_next_hidden && last_hidden -> X (",
            "G(!reset && phase_bias_output -> X (",
            "G(!reset && phase_done && start -> X (",
            "G(!reset && phase_done && !start -> X (",
            "G(!reset && phase_idle && !start -> X (",
        ):
            self.assertIn(snippet, tlsf_text)

    def test_wrapper_source_records_direct_reset_boundary(self) -> None:
        wrapper_path = ROOT / "experiments" / "rtl-synthesis" / "spot" / "controller_spot_compat.sv"
        wrapper_text = wrapper_path.read_text(encoding="utf-8")

        for snippet in (
            "logic core_reset;",
            "assign core_reset = !rst_n;",
            "if (!rst_n) begin",
        ):
            self.assertIn(snippet, wrapper_text)

    def test_formal_harness_records_sampled_interface_checks(self) -> None:
        harness_path = ROOT / "rtl-synthesis" / "controller" / "formal" / "formal_controller_spot_equivalence.sv"
        harness_text = harness_path.read_text(encoding="utf-8")

        for snippet in (
            "logic history_valid;",
            "logic [3:0] prev_baseline_state;",
            "logic sampled_rst_n;",
            "always @(negedge clk) begin",
            "assume (rst_n == sampled_rst_n);",
            "assert (generated_state == baseline_state);",
            "assume (input_idx <= INPUT_NEURONS_4B);",
            "assume (input_idx <= HIDDEN_NEURONS_4B);",
            "if (history_valid && prev_rst_n && prev_baseline_state == DONE && !prev_start) begin",
            "if (prev_input_idx < INPUT_NEURONS_4B) begin",
            "assume (input_idx == prev_input_idx + 4'd1);",
            "if (prev_hidden_idx == LAST_HIDDEN_IDX) begin",
        ):
            self.assertIn(snippet, harness_text)

    def test_wrapper_matches_baseline_when_start_is_high_on_reset_release(self) -> None:
        for tool in ("iverilog", "vvp"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        generated_dir.mkdir(parents=True, exist_ok=True)
        fake_core_path = generated_dir / "controller_spot_core.sv"
        fake_core_path.write_text(textwrap.dedent(FAKE_CONTROLLER_CORE), encoding="utf-8")

        tb_path = self.temp_root / "build" / "reset_release_accept_tb.sv"
        tb_path.write_text(textwrap.dedent(RESET_RELEASE_ACCEPT_TB), encoding="utf-8")
        out_path = self.temp_root / "build" / "reset_release_accept_tb.out"

        compile_result = subprocess.run(
            [
                "iverilog",
                "-g2012",
                "-o",
                str(out_path),
                str(tb_path),
                str(self.temp_root / "rtl" / "src" / "controller.sv"),
                str(self.temp_root / "experiments" / "rtl-synthesis" / "spot" / "controller_spot_compat.sv"),
                str(fake_core_path),
            ],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        compile_output = compile_result.stdout + compile_result.stderr
        self.assertEqual(compile_result.returncode, 0, msg=compile_output)

        run_result = subprocess.run(
            ["vvp", str(out_path)],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        run_output = run_result.stdout + run_result.stderr
        self.assertEqual(run_result.returncode, 0, msg=run_output)
        self.assertIn("PASS reset release accept", run_output)

    def test_make_rtl_synthesis_generates_summary_and_artifacts_with_fake_tools(self) -> None:
        result = subprocess.run(
            ["make", "rtl-synthesis", *self._tool_args()],
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

        summary_path = self.temp_root / "build" / "rtl-synthesis" / "spot" / "rtl_synthesis_summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        self.assertEqual(summary["overall_result"], "pass")
        self.assertEqual(summary["assumption_profile"], "exact_schedule_v1")
        self.assertEqual(
            summary["claim_scope"],
            "bounded (12-cycle) sampled controller-interface equivalence under exact_schedule_v1 assumptions",
        )

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        self.assertTrue((generated_dir / "controller_spot_core.sv").exists())
        self.assertTrue((generated_dir / "controller.sv").exists())
        self.assertTrue((generated_dir / "controller_spot.aag").exists())

    def test_make_rtl_synthesis_sim_runs_with_fake_tools(self) -> None:
        for tool in ("make", "iverilog", "vvp", "verilator"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        result = subprocess.run(
            ["make", "rtl-synthesis-sim", *self._tool_args()],
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
