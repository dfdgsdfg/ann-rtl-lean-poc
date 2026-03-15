from __future__ import annotations

import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MAKEFILE_TEMPLATE = ROOT / "Makefile"
ANN_RESULTS_DIR = ROOT / "ann" / "results"
SELECTED_RUN_TEMPLATE = ANN_RESULTS_DIR / "selected_run.json"
ANN_SELECTED_RUN_DIR = ANN_RESULTS_DIR / "runs" / "relu_teacher_v2-seed20260312-epoch51"
CONTRACT_RESULT_DIR = ROOT / "contract" / "result"
CONTRACT_SRC_DIR = ROOT / "contract" / "src"
LEAN_SPEC_TEMPLATE = ROOT / "formalize" / "src" / "TinyMLP" / "Defs" / "SpecCore.lean"
RTL_SRC_DIR = ROOT / "rtl" / "src"
SIM_RTL_DIR = ROOT / "simulations" / "rtl"
SIM_SHARED_DIR = ROOT / "simulations" / "shared"
SPARKLE_CONTRACT_TEMPLATE = ROOT / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle" / "ContractData.lean"
RTL_SYNTHESIS_CONTROLLER_DIR = ROOT / "rtl-synthesis" / "controller"
RTL_SYNTHESIS_EXPERIMENT_DIR = ROOT / "experiments" / "rtl-synthesis" / "spot"
RTL_SYNTHESIS_SPEC_DIR = ROOT / "specs" / "rtl-synthesis"
EXPERIMENT_TRACK_NOTE = ROOT / "experiments" / "implementation-branch-comparison.md"
RUN_FLOW_PATH = RTL_SYNTHESIS_CONTROLLER_DIR / "run_flow.py"
RUN_FLOW_SPEC = importlib.util.spec_from_file_location("rtl_synthesis_run_flow", RUN_FLOW_PATH)
assert RUN_FLOW_SPEC is not None and RUN_FLOW_SPEC.loader is not None
RUN_FLOW = importlib.util.module_from_spec(RUN_FLOW_SPEC)
sys.modules[RUN_FLOW_SPEC.name] = RUN_FLOW
RUN_FLOW_SPEC.loader.exec_module(RUN_FLOW)


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

SHORT_ASYNC_RESET_PULSE_TB = """\
`timescale 1ns/1ps

module short_async_reset_pulse_tb;
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

    input_idx = 4'd1;
    @(negedge clk);
    check_equal("mac_hidden_progress");

    #1;
    rst_n = 1'b0;
    #1;
    check_equal("during_short_async_reset_pulse");

    #1;
    rst_n = 1'b1;
    #1;
    check_equal("after_short_async_reset_release_before_posedge");

    @(negedge clk);
    check_equal("after_short_async_reset_release");

    $display("PASS short async reset pulse");
    $finish;
  end
endmodule
"""


def _write_executable(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class ToolPathResolutionTests(unittest.TestCase):
    def test_preferred_tool_path_prefers_vendored_binary(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            vendored = Path(tmpdir) / "ltlsynt"
            vendored.write_text("#!/bin/sh\n", encoding="utf-8")
            self.assertEqual(RUN_FLOW.preferred_tool_path(vendored, "__missing_ltlsynt__"), str(vendored))

    def test_preferred_tool_path_falls_back_to_command_name_when_vendor_missing(self) -> None:
        missing_vendor = ROOT / "build" / "missing-vendored-ltlsynt"
        self.assertEqual(
            RUN_FLOW.preferred_tool_path(missing_vendor, "__missing_ltlsynt__"),
            "__missing_ltlsynt__",
        )


class RtlSynthesisFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name) / "rtl-synthesis-repo"
        self.temp_root.mkdir(parents=True, exist_ok=True)
        (self.temp_root / "ann" / "results" / "runs").mkdir(parents=True, exist_ok=True)
        (self.temp_root / "formalize" / "src" / "TinyMLP" / "Defs").mkdir(parents=True, exist_ok=True)
        (self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle").mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, self.temp_root / "Makefile")
        shutil.copy2(SELECTED_RUN_TEMPLATE, self.temp_root / "ann" / "results" / "selected_run.json")
        shutil.copytree(
            ANN_SELECTED_RUN_DIR,
            self.temp_root / "ann" / "results" / "runs" / ANN_SELECTED_RUN_DIR.name,
            dirs_exist_ok=True,
        )
        shutil.copytree(CONTRACT_RESULT_DIR, self.temp_root / "contract" / "result", dirs_exist_ok=True)
        shutil.copytree(CONTRACT_SRC_DIR, self.temp_root / "contract" / "src", dirs_exist_ok=True)
        shutil.copy2(LEAN_SPEC_TEMPLATE, self.temp_root / "formalize" / "src" / "TinyMLP" / "Defs" / "SpecCore.lean")
        shutil.copytree(RTL_SRC_DIR, self.temp_root / "rtl" / "src", dirs_exist_ok=True)
        shutil.copytree(SIM_RTL_DIR, self.temp_root / "simulations" / "rtl", dirs_exist_ok=True)
        shutil.copytree(SIM_SHARED_DIR, self.temp_root / "simulations" / "shared", dirs_exist_ok=True)
        shutil.copy2(
            SPARKLE_CONTRACT_TEMPLATE,
            self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle" / "ContractData.lean",
        )
        shutil.copytree(RTL_SYNTHESIS_CONTROLLER_DIR, self.temp_root / "rtl-synthesis" / "controller", dirs_exist_ok=True)
        shutil.copytree(
            RTL_SYNTHESIS_EXPERIMENT_DIR,
            self.temp_root / "experiments" / "rtl-synthesis" / "spot",
            dirs_exist_ok=True,
        )
        shutil.copytree(RTL_SYNTHESIS_SPEC_DIR, self.temp_root / "specs" / "rtl-synthesis", dirs_exist_ok=True)
        (self.temp_root / "experiments").mkdir(parents=True, exist_ok=True)
        shutil.copy2(EXPERIMENT_TRACK_NOTE, self.temp_root / "experiments" / "implementation-branch-comparison.md")

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

    def _write_closed_loop_formal_sources(self, generated_dir: Path) -> tuple[Path, Path, Path, Path]:
        baseline_controller_copy = generated_dir / "baseline_controller.sv"
        generated_controller_copy = generated_dir / "generated_controller.sv"
        baseline_mlp_core_copy = generated_dir / "baseline_mlp_core.sv"
        generated_mlp_core_copy = generated_dir / "generated_mlp_core.sv"

        baseline_controller_text = (self.temp_root / "rtl" / "src" / "controller.sv").read_text(encoding="utf-8")
        baseline_controller_copy.write_text(
            baseline_controller_text.replace("module controller #(", "module baseline_controller #(", 1),
            encoding="utf-8",
        )

        generated_controller_copy.write_text(
            textwrap.dedent(
                """\
                module generated_controller #(
                  parameter int INPUT_NEURONS = 4,
                  parameter int HIDDEN_NEURONS = 8
                ) (
                  input  logic       clk,
                  input  logic       rst_n,
                  input  logic       start,
                  input  logic [3:0] hidden_idx,
                  input  logic [3:0] input_idx,
                  output logic [3:0] state,
                  output logic       load_input,
                  output logic       clear_acc,
                  output logic       do_mac_hidden,
                  output logic       do_bias_hidden,
                  output logic       do_act_hidden,
                  output logic       advance_hidden,
                  output logic       do_mac_output,
                  output logic       do_bias_output,
                  output logic       done,
                  output logic       busy
                );
                  controller_spot_compat #(
                    .INPUT_NEURONS(INPUT_NEURONS),
                    .HIDDEN_NEURONS(HIDDEN_NEURONS)
                  ) u_controller_spot_compat (
                    .clk(clk),
                    .rst_n(rst_n),
                    .start(start),
                    .hidden_idx(hidden_idx),
                    .input_idx(input_idx),
                    .state(state),
                    .load_input(load_input),
                    .clear_acc(clear_acc),
                    .do_mac_hidden(do_mac_hidden),
                    .do_bias_hidden(do_bias_hidden),
                    .do_act_hidden(do_act_hidden),
                    .advance_hidden(advance_hidden),
                    .do_mac_output(do_mac_output),
                    .do_bias_output(do_bias_output),
                    .done(done),
                    .busy(busy)
                  );
                endmodule
                """
            ),
            encoding="utf-8",
        )

        mlp_core_text = (self.temp_root / "rtl" / "src" / "mlp_core.sv").read_text(encoding="utf-8")
        baseline_mlp_core_copy.write_text(
            mlp_core_text
            .replace("module mlp_core (", "module baseline_mlp_core (", 1)
            .replace("  controller u_controller (", "  baseline_controller u_controller (", 1),
            encoding="utf-8",
        )
        generated_mlp_core_copy.write_text(
            mlp_core_text
            .replace("module mlp_core (", "module generated_mlp_core (", 1)
            .replace("  controller u_controller (", "  generated_controller u_controller (", 1),
            encoding="utf-8",
        )
        return (
            baseline_controller_copy,
            generated_controller_copy,
            baseline_mlp_core_copy,
            generated_mlp_core_copy,
        )

    def _run_smt2_smoke(self, script_path: Path, smt2_path: Path, depth: int) -> None:
        yosys_result = subprocess.run(
            ["yosys", "-q", "-s", str(script_path)],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        yosys_output = yosys_result.stdout + yosys_result.stderr
        self.assertEqual(yosys_result.returncode, 0, msg=yosys_output)

        smtbmc_result = subprocess.run(
            ["yosys-smtbmc", "-s", "z3", "--presat", "-t", str(depth), str(smt2_path)],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        smtbmc_output = smtbmc_result.stdout + smtbmc_result.stderr
        self.assertEqual(smtbmc_result.returncode, 0, msg=smtbmc_output)
        self.assertIn("Status: PASSED", smtbmc_output)
        self.assertNotIn("PREUNSAT", smtbmc_output)

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
            "logic core_reset_pending = 1'b0;",
            "logic reset_consumed = 1'b0;",
            "assign core_reset = !rst_n || (core_reset_pending && !reset_consumed);",
            "reset_consumed <= 1'b1;",
            "if (core_reset) begin",
        ):
            self.assertIn(snippet, wrapper_text)

    def test_formal_controller_interface_harness_records_sampled_interface_checks(self) -> None:
        harness_path = ROOT / "rtl-synthesis" / "controller" / "formal" / "formal_controller_spot_equivalence.sv"
        harness_text = harness_path.read_text(encoding="utf-8")

        for snippet in (
            "logic history_valid;",
            "logic [3:0] sampled_baseline_state;",
            "logic [3:0] prev_sampled_baseline_state;",
            "logic sampled_rst_n;",
            "always @(negedge clk) begin",
            "sampled_baseline_state <= baseline_state;",
            "always @(posedge clk) begin",
            "assume (rst_n == sampled_rst_n);",
            "if (!prev_sampled_rst_n && sampled_rst_n) begin",
            "unique case (prev_sampled_baseline_state)",
            "assert (generated_state == baseline_state);",
            "assume (sampled_input_idx <= INPUT_NEURONS_4B);",
            "assume (sampled_input_idx <= HIDDEN_NEURONS_4B);",
            "if (history_valid && prev_sampled_rst_n && prev_sampled_baseline_state == DONE && !prev_sampled_start) begin",
            "if (prev_sampled_input_idx < INPUT_NEURONS_4B) begin",
            "assume (sampled_input_idx == prev_sampled_input_idx + 4'd1);",
            "if (prev_sampled_hidden_idx == LAST_HIDDEN_IDX) begin",
        ):
            self.assertIn(snippet, harness_text)

    def test_formal_closed_loop_harness_records_full_core_equivalence_checks(self) -> None:
        harness_path = ROOT / "rtl-synthesis" / "controller" / "formal" / "formal_closed_loop_mlp_core_equivalence.sv"
        harness_text = harness_path.read_text(encoding="utf-8")

        for snippet in (
            "baseline_mlp_core baseline_dut",
            "generated_mlp_core generated_dut",
            "assume (rst_n == (step >= 7'd2));",
            "assume (start);",
            "assert (generated_done == baseline_done);",
            "assert (generated_busy == baseline_busy);",
            "assert (generated_out_bit == baseline_out_bit);",
            "assert (generated_formal_state == baseline_formal_state);",
            "assert (generated_formal_input_reg0 == baseline_formal_input_reg0);",
            "assert (generated_formal_acc_reg == baseline_formal_acc_reg);",
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

    def test_wrapper_matches_baseline_across_short_async_reset_pulse(self) -> None:
        for tool in ("iverilog", "vvp"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        generated_dir.mkdir(parents=True, exist_ok=True)
        fake_core_path = generated_dir / "controller_spot_core.sv"
        fake_core_path.write_text(textwrap.dedent(FAKE_CONTROLLER_CORE), encoding="utf-8")

        tb_path = self.temp_root / "build" / "short_async_reset_pulse_tb.sv"
        tb_path.write_text(textwrap.dedent(SHORT_ASYNC_RESET_PULSE_TB), encoding="utf-8")
        out_path = self.temp_root / "build" / "short_async_reset_pulse_tb.out"

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
        self.assertIn("PASS short async reset pulse", run_output)

    def test_formal_controller_interface_harness_passes_real_yosys_smoke(self) -> None:
        for tool in ("yosys", "yosys-smtbmc", "z3"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        generated_dir.mkdir(parents=True, exist_ok=True)
        fake_core_path = generated_dir / "controller_spot_core.sv"
        fake_core_path.write_text(textwrap.dedent(FAKE_CONTROLLER_CORE), encoding="utf-8")

        smt2_path = generated_dir / "formal_controller_spot_equivalence_smoke.smt2"
        script_path = generated_dir / "formal_controller_spot_equivalence_smoke.ys"
        script_path.write_text(
            textwrap.dedent(
                f"""\
                read_verilog -sv -formal rtl/src/controller.sv experiments/rtl-synthesis/spot/controller_spot_compat.sv {fake_core_path} rtl-synthesis/controller/formal/formal_controller_spot_equivalence.sv
                prep -top formal_controller_spot_equivalence
                async2sync
                dffunmap
                write_smt2 -wires {smt2_path}
                """
            ),
            encoding="utf-8",
        )

        self._run_smt2_smoke(script_path, smt2_path, 80)

    def test_formal_closed_loop_harness_passes_real_yosys_smoke(self) -> None:
        for tool in ("yosys", "yosys-smtbmc", "z3"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        generated_dir.mkdir(parents=True, exist_ok=True)
        fake_core_path = generated_dir / "controller_spot_core.sv"
        fake_core_path.write_text(textwrap.dedent(FAKE_CONTROLLER_CORE), encoding="utf-8")
        (
            baseline_controller_copy,
            generated_controller_copy,
            baseline_mlp_core_copy,
            generated_mlp_core_copy,
        ) = self._write_closed_loop_formal_sources(generated_dir)

        smt2_path = generated_dir / "formal_closed_loop_mlp_core_equivalence_smoke.smt2"
        script_path = generated_dir / "formal_closed_loop_mlp_core_equivalence_smoke.ys"
        script_path.write_text(
            textwrap.dedent(
                f"""\
                read_verilog -DFORMAL -sv -formal rtl/src/mac_unit.sv rtl/src/relu_unit.sv rtl/src/weight_rom.sv {baseline_controller_copy} experiments/rtl-synthesis/spot/controller_spot_compat.sv {fake_core_path} {generated_controller_copy} {baseline_mlp_core_copy} {generated_mlp_core_copy} rtl-synthesis/controller/formal/formal_closed_loop_mlp_core_equivalence.sv
                prep -top formal_closed_loop_mlp_core_equivalence
                async2sync
                dffunmap
                write_smt2 -wires {smt2_path}
                """
            ),
            encoding="utf-8",
        )

        self._run_smt2_smoke(script_path, smt2_path, 82)

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
        self.assertIn("PASS controller_interface_equivalence", output)
        self.assertIn("PASS closed_loop_mlp_core_equivalence", output)

        summary_path = self.temp_root / "build" / "rtl-synthesis" / "spot" / "rtl_synthesis_summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        self.assertEqual(summary["overall_result"], "pass")
        self.assertEqual(summary["assumption_profile"], "exact_schedule_v1")
        self.assertEqual(
            summary["primary_claim_scope"],
            "bounded (82-cycle) closed-loop mlp_core mixed-path equivalence over a post-reset accepted transaction window, with the hand-written datapath and shared external inputs driving both baseline and synthesized-controller assemblies",
        )
        self.assertEqual(
            summary["secondary_claim_scope"],
            "bounded (80-cycle) sampled controller-interface equivalence through MAC_OUTPUT, BIAS_OUTPUT, DONE, and DONE hold/release under exact_schedule_v1 assumptions",
        )
        self.assertEqual(summary["claim_scope"], summary["primary_claim_scope"])
        self.assertEqual(
            [item["name"] for item in summary["results"]],
            [
                "realisability",
                "aiger_generation",
                "yosys_translation",
                "controller_interface_equivalence",
                "closed_loop_mlp_core_equivalence",
            ],
        )

        generated_dir = self.temp_root / "build" / "rtl-synthesis" / "spot" / "generated"
        self.assertTrue((generated_dir / "controller_spot_core.sv").exists())
        self.assertTrue((generated_dir / "controller.sv").exists())
        self.assertTrue((generated_dir / "generated_controller.sv").exists())
        self.assertTrue((generated_dir / "baseline_controller.sv").exists())
        self.assertTrue((generated_dir / "baseline_mlp_core.sv").exists())
        self.assertTrue((generated_dir / "generated_mlp_core.sv").exists())
        self.assertTrue((generated_dir / "controller_spot.aag").exists())

    def test_run_flow_accepts_relative_build_dir_with_fake_tools(self) -> None:
        result = subprocess.run(
            [
                "python3",
                "rtl-synthesis/controller/run_flow.py",
                "--ltlsynt",
                str(self.tools_dir / "ltlsynt"),
                "--syfco",
                str(self.tools_dir / "syfco"),
                "--yosys",
                str(self.tools_dir / "yosys"),
                "--smtbmc",
                str(self.tools_dir / "yosys-smtbmc"),
                "--solver",
                str(self.tools_dir / "z3"),
                "--build-dir",
                "rel-build",
                "--summary",
                "rel-build/out.json",
            ],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            env=self._make_env(),
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertTrue((self.temp_root / "rel-build" / "out.json").exists(), msg=output)
        self.assertTrue((self.temp_root / "rel-build" / "generated" / "controller_spot_core.sv").exists(), msg=output)
        self.assertTrue((self.temp_root / "rel-build" / "generated" / "controller_spot.aag").exists(), msg=output)

    def test_make_n_rtl_synthesis_sim_resolves_summary_backed_generated_artifacts(self) -> None:
        result = subprocess.run(
            ["make", "-n", "rtl-synthesis-sim"],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 rtl-synthesis/controller/run_flow.py", output)
        self.assertIn("iverilog -g2012", output)
        self.assertIn("verilator --binary --timing", output)

    def test_make_rtl_synthesis_rebuilds_when_primary_proof_inputs_change(self) -> None:
        summary_path = self.temp_root / "build" / "rtl-synthesis" / "spot" / "rtl_synthesis_summary.json"
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text("{}\n", encoding="utf-8")
        tracked_dependencies = [
            path
            for path in self.temp_root.rglob("*")
            if path.is_file() and path != summary_path
        ]

        def prepare_up_to_date_summary() -> None:
            for path in tracked_dependencies:
                os.utime(path, (1000, 1000))
            os.utime(summary_path, (2000, 2000))

        prepare_up_to_date_summary()
        result = subprocess.run(
            ["make", "-n", "rtl-synthesis"],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, msg=output)
        self.assertNotIn("python3 rtl-synthesis/controller/run_flow.py", output)

        for dependency in (
            self.temp_root / "rtl" / "src" / "mlp_core.sv",
            self.temp_root / "rtl-synthesis" / "controller" / "formal" / "formal_closed_loop_mlp_core_equivalence.sv",
        ):
            prepare_up_to_date_summary()
            os.utime(dependency, (3000, 3000))
            result = subprocess.run(
                ["make", "-n", "rtl-synthesis"],
                cwd=self.temp_root,
                text=True,
                capture_output=True,
                check=False,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, msg=output)
            self.assertIn("python3 rtl-synthesis/controller/run_flow.py", output)

    def test_make_n_rtl_synthesis_smoke_runs_python_regression_file(self) -> None:
        result = subprocess.run(
            ["make", "-n", "rtl-synthesis-smoke"],
            cwd=self.temp_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 rtl-synthesis/test/test_rtl_synthesis.py", output)

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
