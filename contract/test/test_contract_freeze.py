from __future__ import annotations

import json
import shutil
import stat
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

from contract.src import artifacts as contract_artifacts
from contract.src import downstream_sync, freeze, gen_vectors


ROOT = contract_artifacts.ROOT
RUN_DIR = ROOT / "ann" / "results" / "latest"
MAKEFILE_TEMPLATE = ROOT / "Makefile"
WEIGHT_ROM_TEMPLATE = ROOT / "rtl" / "src" / "weight_rom.sv"
LEAN_SPEC_TEMPLATE = ROOT / "formalize" / "src" / "TinyMLP" / "Defs" / "SpecCore.lean"
SPARKLE_CONTRACT_TEMPLATE = ROOT / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle" / "ContractData.lean"
CONTRACT_WEIGHTS_TEMPLATE = ROOT / "contract" / "result" / "weights.json"
SIM_TESTBENCH_TEMPLATE = ROOT / "simulations" / "rtl" / "testbench.sv"
CONTRACT_SRC_DIR = ROOT / "contract" / "src"
RTL_SRC_DIR = ROOT / "rtl" / "src"


class FreezeContractTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name)

        self.contract_weights_path = self.temp_root / "contract" / "result" / "weights.json"
        self.selected_run_path = self.temp_root / "ann" / "results" / "selected_run.json"
        self.weight_rom_path = self.temp_root / "rtl" / "src" / "weight_rom.sv"
        self.lean_spec_path = self.temp_root / "formalize" / "src" / "TinyMLP" / "Defs" / "SpecCore.lean"
        self.sparkle_contract_path = self.temp_root / "rtl-formalize-synthesis" / "src" / "TinyMLPSparkle" / "ContractData.lean"
        self.model_doc_path = self.temp_root / "contract" / "result" / "model.md"
        self.vectors_path = self.temp_root / "simulations" / "shared" / "test_vectors.mem"
        self.vector_meta_path = self.temp_root / "simulations" / "shared" / "test_vectors_meta.svh"

        self.weight_rom_path.parent.mkdir(parents=True, exist_ok=True)
        self.weight_rom_path.write_text(WEIGHT_ROM_TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

        self.lean_spec_path.parent.mkdir(parents=True, exist_ok=True)
        self.lean_spec_path.write_text(LEAN_SPEC_TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

        self.sparkle_contract_path.parent.mkdir(parents=True, exist_ok=True)
        self.sparkle_contract_path.write_text(SPARKLE_CONTRACT_TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def _patched_output_paths(self) -> ExitStack:
        stack = ExitStack()
        stack.enter_context(patch.object(freeze, "CONTRACT_WEIGHTS_PATH", self.contract_weights_path))
        stack.enter_context(patch.object(freeze, "SELECTED_RUN_PATH", self.selected_run_path))
        stack.enter_context(patch.object(downstream_sync, "WEIGHT_ROM_PATH", self.weight_rom_path))
        stack.enter_context(patch.object(downstream_sync, "LEAN_SPEC_PATH", self.lean_spec_path))
        stack.enter_context(patch.object(downstream_sync, "SPARKLE_CONTRACT_DATA_PATH", self.sparkle_contract_path))
        stack.enter_context(patch.object(downstream_sync, "CONTRACT_MODEL_MD_PATH", self.model_doc_path))
        stack.enter_context(patch.object(gen_vectors, "TEST_VECTORS_PATH", self.vectors_path))
        stack.enter_context(patch.object(gen_vectors, "TEST_VECTORS_META_PATH", self.vector_meta_path))
        return stack

    def _always_positive_weights(self) -> dict[str, object]:
        return {
            "schema_version": 1,
            "source": "trained_selected_quantized",
            "input_size": 4,
            "hidden_size": 8,
            "dataset_version": "test",
            "training_seed": 0,
            "w1": [[0, 0, 0, 0] for _ in range(8)],
            "b1": [0] * 8,
            "w2": [0] * 8,
            "b2": 1,
        }

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
            self.sparkle_contract_path: self.sparkle_contract_path.read_text(encoding="utf-8"),
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

        weight_rom_text = self.weight_rom_path.read_text(encoding="utf-8")
        self.assertIn("assign formal_hidden_weight_case_hit = (hidden_idx < 4'd8) && (input_idx < 4'd4);", weight_rom_text)
        self.assertIn("assign formal_output_weight_case_hit = (input_idx < 4'd8);", weight_rom_text)

        for path in (
            self.contract_weights_path,
            self.selected_run_path,
            self.weight_rom_path,
            self.lean_spec_path,
            self.sparkle_contract_path,
            self.model_doc_path,
            self.vectors_path,
            self.vector_meta_path,
        ):
            self.assertTrue(path.exists(), msg=f"expected generated artifact: {path}")

    def test_resolve_selected_run_dir_requires_existing_selected_metadata_target(self) -> None:
        self.selected_run_path.parent.mkdir(parents=True, exist_ok=True)
        missing_run = self.temp_root / "ann" / "results" / "missing-run"
        self.selected_run_path.write_text(
            json.dumps(
                {
                    "selected_run": contract_artifacts.relative_to_root(missing_run),
                    "weights_quantized": contract_artifacts.relative_to_root(missing_run / "weights_quantized.json"),
                    "contract_weights": contract_artifacts.relative_to_root(self.contract_weights_path),
                }
            ),
            encoding="utf-8",
        )

        with self._patched_output_paths():
            with patch.object(freeze, "LATEST_RESULTS_DIR", RUN_DIR):
                with self.assertRaisesRegex(FileNotFoundError, "selected run metadata points to a missing run directory"):
                    freeze.freeze_contract()

        self.assertFalse(self.contract_weights_path.exists(), msg="freeze should fail before writing artifacts")

    def test_resolve_selected_run_dir_falls_back_to_latest_when_metadata_missing(self) -> None:
        with self._patched_output_paths():
            with patch.object(freeze, "LATEST_RESULTS_DIR", RUN_DIR):
                resolved = freeze.resolve_selected_run_dir()

        self.assertEqual(resolved, RUN_DIR)

    def test_render_vectors_fails_when_score_class_witnesses_are_missing(self) -> None:
        with self.assertRaisesRegex(ValueError, "unable to synthesize required score-class witnesses for zero"):
            gen_vectors.render_vectors(self._always_positive_weights())

    def test_check_witness_coverage_fails_for_always_positive_weights(self) -> None:
        self.contract_weights_path.parent.mkdir(parents=True, exist_ok=True)
        self.contract_weights_path.write_text(json.dumps(self._always_positive_weights()), encoding="utf-8")

        with patch.object(gen_vectors, "CONTRACT_WEIGHTS_PATH", self.contract_weights_path):
            with self.assertRaisesRegex(ValueError, "unable to synthesize required score-class witnesses for zero"):
                gen_vectors.check_witness_coverage()

    def test_generated_vector_suite_covers_boundary_values_and_stress_vectors(self) -> None:
        weights = gen_vectors._load_contract_weights()
        scored_vectors = gen_vectors._build_scored_vectors(weights)
        suite_vectors = {vector for vector, _ in scored_vectors}
        analysis = gen_vectors._analyze_candidate_pool(weights)

        self.assertGreaterEqual(len(scored_vectors), 32)

        for lane in range(4):
            for boundary_value in gen_vectors.ARITHMETIC_BOUNDARY_VALUES:
                expected = [0] * 4
                expected[lane] = boundary_value
                self.assertIn(tuple(expected), suite_vectors)

        for vector in gen_vectors.EXTREME_COMBINATION_VECTORS:
            self.assertIn(vector, suite_vectors)

        for vector in (
            analysis.max_score_vector,
            analysis.min_score_vector,
            *analysis.hidden_pre_max_vectors,
            *analysis.hidden_pre_min_vectors,
            *analysis.output_partial_max_vectors,
            *analysis.output_partial_min_vectors,
            *(analysis.score_witnesses[score_class] for score_class in gen_vectors.WITNESS_CLASSES),
        ):
            self.assertIn(vector, suite_vectors)

    def test_write_text_files_preserves_existing_file_mode(self) -> None:
        target = self.temp_root / "contract" / "result" / "preserved.txt"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("before\n", encoding="utf-8")
        target.chmod(0o754)

        contract_artifacts.write_text_files({target: ("after\n", "utf-8")})

        self.assertEqual(target.read_text(encoding="utf-8"), "after\n")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o754)

    def test_make_sim_iverilog_bootstraps_missing_vectors_from_existing_stamp(self) -> None:
        for tool in ("make", "iverilog", "vvp"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        repo_root = self.temp_root / "sim-repo"
        (repo_root / "contract" / "result").mkdir(parents=True, exist_ok=True)
        (repo_root / "simulations" / "rtl").mkdir(parents=True, exist_ok=True)
        (repo_root / "simulations" / "shared").mkdir(parents=True, exist_ok=True)
        (repo_root / "build" / "sim").mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, repo_root / "Makefile")
        shutil.copy2(CONTRACT_WEIGHTS_TEMPLATE, repo_root / "contract" / "result" / "weights.json")
        shutil.copy2(SIM_TESTBENCH_TEMPLATE, repo_root / "simulations" / "rtl" / "testbench.sv")
        shutil.copytree(CONTRACT_SRC_DIR, repo_root / "contract" / "src", dirs_exist_ok=True)
        shutil.copytree(RTL_SRC_DIR, repo_root / "rtl" / "src", dirs_exist_ok=True)

        stamp_path = repo_root / "build" / "sim" / "vectors.stamp"
        stamp_path.write_text("stale stamp\n", encoding="utf-8")
        vectors_path = repo_root / "simulations" / "shared" / "test_vectors.mem"
        vector_meta_path = repo_root / "simulations" / "shared" / "test_vectors_meta.svh"
        self.assertFalse(vectors_path.exists())
        self.assertFalse(vector_meta_path.exists())

        result = subprocess.run(
            ["make", "sim-iverilog"],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 -m contract.src.gen_vectors", output)
        self.assertIn("PASS all vectors", output)
        self.assertTrue(vectors_path.exists(), msg="expected test_vectors.mem to be regenerated")
        self.assertTrue(vector_meta_path.exists(), msg="expected test_vectors_meta.svh to be regenerated")


if __name__ == "__main__":
    unittest.main()
