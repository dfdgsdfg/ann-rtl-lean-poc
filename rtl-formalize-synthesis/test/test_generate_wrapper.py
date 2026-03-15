from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "rtl-formalize-synthesis" / "scripts" / "generate_wrapper.py"
VALID_RAW_MODULE = """\
module TinyMLP_sparkleMlpCorePacked (
  input logic _gen_start,
  input logic [7:0] _gen_in0,
  input logic [7:0] _gen_in1,
  input logic [7:0] _gen_in2,
  input logic [7:0] _gen_in3,
  input logic clk,
  input logic rst,
  output logic [298:0] out
);
  assign out = 299'd0;
endmodule
"""


def run_generator(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class GenerateWrapperTests(unittest.TestCase):
    def test_rejects_raw_module_missing_expected_ports(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            raw_path = Path(tmpdir) / "sparkle_mlp_core.sv"
            wrapper_path = Path(tmpdir) / "sparkle_mlp_core_wrapper.sv"
            raw_path.write_text(
                "module TinyMLP_sparkleMlpCorePacked (\n"
                "  input logic clk,\n"
                "  output logic [298:0] out\n"
                ");\n"
                "  assign out = 299'd0;\n"
                "endmodule\n",
                encoding="utf-8",
            )

            result = run_generator("--raw", str(raw_path), "--wrapper", str(wrapper_path))

            self.assertNotEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertIn("raw module interface validation failed", result.stderr)
            self.assertIn("missing ports", result.stderr)

    def test_check_mode_rejects_wrapper_mismatch(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmpdir:
            raw_path = Path(tmpdir) / "sparkle_mlp_core.sv"
            wrapper_path = Path(tmpdir) / "sparkle_mlp_core_wrapper.sv"
            raw_path.write_text(VALID_RAW_MODULE, encoding="utf-8")

            generate = run_generator("--raw", str(raw_path), "--wrapper", str(wrapper_path))
            self.assertEqual(generate.returncode, 0, msg=generate.stdout + generate.stderr)

            wrapper_path.write_text("module mlp_core; endmodule\n", encoding="utf-8")
            check = run_generator("--raw", str(raw_path), "--wrapper", str(wrapper_path), "--check")

            self.assertNotEqual(check.returncode, 0, msg=check.stdout + check.stderr)
            self.assertIn("wrapper check failed", check.stderr)


if __name__ == "__main__":
    unittest.main()
