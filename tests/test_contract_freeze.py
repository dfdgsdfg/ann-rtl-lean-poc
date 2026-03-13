from __future__ import annotations

import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

from contract.src import artifacts as contract_artifacts
from contract.src import downstream_sync, freeze, gen_vectors


ROOT = contract_artifacts.ROOT
RUN_DIR = ROOT / "ann" / "results" / "latest"
WEIGHT_ROM_TEMPLATE = ROOT / "rtl" / "src" / "weight_rom.sv"
LEAN_SPEC_TEMPLATE = ROOT / "formalize" / "src" / "TinyMLP" / "Spec.lean"


class FreezeContractTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name)

        self.contract_weights_path = self.temp_root / "contract" / "result" / "weights.json"
        self.selected_run_path = self.temp_root / "ann" / "results" / "selected_run.json"
        self.weight_rom_path = self.temp_root / "rtl" / "src" / "weight_rom.sv"
        self.lean_spec_path = self.temp_root / "formalize" / "src" / "TinyMLP" / "Spec.lean"
        self.model_doc_path = self.temp_root / "contract" / "result" / "model.md"
        self.vectors_path = self.temp_root / "simulations" / "rtl" / "test_vectors.mem"
        self.vector_meta_path = self.temp_root / "simulations" / "rtl" / "test_vectors_meta.svh"

        self.weight_rom_path.parent.mkdir(parents=True, exist_ok=True)
        self.weight_rom_path.write_text(WEIGHT_ROM_TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

        self.lean_spec_path.parent.mkdir(parents=True, exist_ok=True)
        self.lean_spec_path.write_text(LEAN_SPEC_TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def _patched_output_paths(self) -> ExitStack:
        stack = ExitStack()
        stack.enter_context(patch.object(freeze, "CONTRACT_WEIGHTS_PATH", self.contract_weights_path))
        stack.enter_context(patch.object(freeze, "SELECTED_RUN_PATH", self.selected_run_path))
        stack.enter_context(patch.object(downstream_sync, "WEIGHT_ROM_PATH", self.weight_rom_path))
        stack.enter_context(patch.object(downstream_sync, "LEAN_SPEC_PATH", self.lean_spec_path))
        stack.enter_context(patch.object(downstream_sync, "CONTRACT_MODEL_MD_PATH", self.model_doc_path))
        stack.enter_context(patch.object(gen_vectors, "TEST_VECTORS_PATH", self.vectors_path))
        stack.enter_context(patch.object(gen_vectors, "TEST_VECTORS_META_PATH", self.vector_meta_path))
        return stack

    def test_freeze_contract_does_not_write_partial_artifacts_when_vector_generation_fails(self) -> None:
        self.contract_weights_path.parent.mkdir(parents=True, exist_ok=True)
        self.contract_weights_path.write_text('{"sentinel": "contract"}\n', encoding="utf-8")
        self.selected_run_path.parent.mkdir(parents=True, exist_ok=True)
        self.selected_run_path.write_text('{"sentinel": "selected"}\n', encoding="utf-8")
        self.model_doc_path.parent.mkdir(parents=True, exist_ok=True)
        self.model_doc_path.write_text("sentinel model\n", encoding="utf-8")
        self.vectors_path.parent.mkdir(parents=True, exist_ok=True)
        self.vectors_path.write_text("sentinel vectors\n", encoding="ascii")
        self.vector_meta_path.write_text("sentinel meta\n", encoding="ascii")

        baseline = {
            self.contract_weights_path: self.contract_weights_path.read_text(encoding="utf-8"),
            self.selected_run_path: self.selected_run_path.read_text(encoding="utf-8"),
            self.weight_rom_path: self.weight_rom_path.read_text(encoding="utf-8"),
            self.lean_spec_path: self.lean_spec_path.read_text(encoding="utf-8"),
            self.model_doc_path: self.model_doc_path.read_text(encoding="utf-8"),
            self.vectors_path: self.vectors_path.read_text(encoding="ascii"),
            self.vector_meta_path: self.vector_meta_path.read_text(encoding="ascii"),
        }

        with self._patched_output_paths():
            with patch.object(freeze, "expected_vector_artifacts", side_effect=ValueError("vector generation failed")):
                with self.assertRaisesRegex(ValueError, "vector generation failed"):
                    freeze.freeze_contract(RUN_DIR)

        for path, expected_text in baseline.items():
            encoding = "ascii" if path.suffix in {".mem", ".svh"} else "utf-8"
            self.assertEqual(path.read_text(encoding=encoding), expected_text)

    def test_freeze_contract_writes_full_artifact_set(self) -> None:
        with self._patched_output_paths():
            out_path = freeze.freeze_contract(RUN_DIR)
            self.assertEqual(out_path, self.contract_weights_path)
            freeze.validate_contract()

        for path in (
            self.contract_weights_path,
            self.selected_run_path,
            self.weight_rom_path,
            self.lean_spec_path,
            self.model_doc_path,
            self.vectors_path,
            self.vector_meta_path,
        ):
            self.assertTrue(path.exists(), msg=f"expected generated artifact: {path}")


if __name__ == "__main__":
    unittest.main()
