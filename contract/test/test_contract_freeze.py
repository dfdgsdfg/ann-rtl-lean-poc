from __future__ import annotations

import json
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from contract.src import artifacts as contract_artifacts
from contract.src import downstream_sync, gen_vectors


ROOT = contract_artifacts.ROOT
RUN_DIR = ROOT / "ann" / "results" / "runs" / "relu_teacher_v2-seed20260312-epoch51"
MAKEFILE_TEMPLATE = ROOT / "Makefile"
WEIGHT_ROM_TEMPLATE = ROOT / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv"
LEAN_SPEC_TEMPLATE = ROOT / "formalize" / "src" / "MlpCore" / "Defs" / "SpecCore.lean"
SPARKLE_CONTRACT_TEMPLATE = ROOT / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ContractData.lean"
SIM_TESTBENCH_TEMPLATE = ROOT / "simulations" / "rtl" / "testbench.sv"
CONTRACT_SRC_DIR = ROOT / "contract" / "src"
CONTRACT_RUNNERS_DIR = ROOT / "contract" / "runners"
ROOT_RUNNERS_DIR = ROOT / "runners"
RTL_SV_DIR = ROOT / "rtl" / "results" / "canonical" / "sv"
SCRIPTS_DIR = ROOT / "scripts"
SIM_RUNNERS_DIR = ROOT / "simulations" / "runners"


class FreezeContractTests(unittest.TestCase):
    def setUp(self) -> None:
        build_dir = ROOT / "build"
        build_dir.mkdir(parents=True, exist_ok=True)
        self._tmpdir = tempfile.TemporaryDirectory(dir=build_dir)
        self.temp_root = Path(self._tmpdir.name)

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

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

    def _prepare_repo_root(self, *, include_ann_canonical: bool = False, include_contract_canonical: bool = False) -> Path:
        repo_root = self.temp_root / "repo"
        (repo_root / "ann" / "results" / "runs").mkdir(parents=True, exist_ok=True)
        (repo_root / "formalize" / "src" / "MlpCore" / "Defs").mkdir(parents=True, exist_ok=True)
        (repo_root / "rtl" / "results" / "canonical" / "sv").mkdir(parents=True, exist_ok=True)
        (repo_root / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle").mkdir(parents=True, exist_ok=True)
        (repo_root / "simulations" / "rtl").mkdir(parents=True, exist_ok=True)
        (repo_root / "simulations" / "shared").mkdir(parents=True, exist_ok=True)
        (repo_root / "build" / "sim").mkdir(parents=True, exist_ok=True)

        shutil.copy2(MAKEFILE_TEMPLATE, repo_root / "Makefile")
        shutil.copy2(SIM_TESTBENCH_TEMPLATE, repo_root / "simulations" / "rtl" / "testbench.sv")
        shutil.copy2(WEIGHT_ROM_TEMPLATE, repo_root / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv")
        shutil.copy2(LEAN_SPEC_TEMPLATE, repo_root / "formalize" / "src" / "MlpCore" / "Defs" / "SpecCore.lean")
        shutil.copy2(
            SPARKLE_CONTRACT_TEMPLATE,
            repo_root / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ContractData.lean",
        )
        shutil.copy2(ROOT / "simulations" / "shared" / "test_vectors.mem", repo_root / "simulations" / "shared" / "test_vectors.mem")
        shutil.copy2(
            ROOT / "simulations" / "shared" / "test_vectors_meta.svh",
            repo_root / "simulations" / "shared" / "test_vectors_meta.svh",
        )
        shutil.copytree(CONTRACT_SRC_DIR, repo_root / "contract" / "src", dirs_exist_ok=True)
        shutil.copytree(CONTRACT_RUNNERS_DIR, repo_root / "contract" / "runners", dirs_exist_ok=True)
        shutil.copytree(ROOT_RUNNERS_DIR, repo_root / "runners", dirs_exist_ok=True)
        shutil.copytree(RTL_SV_DIR, repo_root / "rtl" / "results" / "canonical" / "sv", dirs_exist_ok=True)
        shutil.copytree(SCRIPTS_DIR, repo_root / "scripts", dirs_exist_ok=True)
        shutil.copytree(SIM_RUNNERS_DIR, repo_root / "simulations" / "runners", dirs_exist_ok=True)
        shutil.copytree(RUN_DIR, repo_root / "ann" / "results" / "runs" / RUN_DIR.name, dirs_exist_ok=True)

        if include_ann_canonical:
            shutil.copytree(ROOT / "ann" / "results" / "canonical", repo_root / "ann" / "results" / "canonical", dirs_exist_ok=True)
        if include_contract_canonical:
            shutil.copytree(ROOT / "contract" / "results" / "canonical", repo_root / "contract" / "results" / "canonical", dirs_exist_ok=True)
        return repo_root

    def test_freeze_contract_writes_full_artifact_set(self) -> None:
        repo_root = self._prepare_repo_root()

        result = subprocess.run(
            [
                "python3",
                "contract/runners/freeze.py",
                "--run-dir",
                f"ann/results/runs/{RUN_DIR.name}",
            ],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, msg=output)

        ann_manifest_path = repo_root / "ann" / "results" / "canonical" / "manifest.json"
        contract_weights_path = repo_root / "contract" / "results" / "canonical" / "weights.json"
        contract_manifest_path = repo_root / "contract" / "results" / "canonical" / "manifest.json"
        contract_run_weights = repo_root / "contract" / "results" / "runs" / RUN_DIR.name / "weights.json"
        contract_run_manifest = repo_root / "contract" / "results" / "runs" / RUN_DIR.name / "manifest.json"
        contract_model_path = repo_root / "contract" / "results" / "canonical" / "model.md"

        ann_manifest = json.loads(ann_manifest_path.read_text(encoding="utf-8"))
        contract_payload = json.loads(contract_weights_path.read_text(encoding="utf-8"))
        contract_manifest = json.loads(contract_manifest_path.read_text(encoding="utf-8"))

        self.assertEqual(ann_manifest["selected_run_id"], RUN_DIR.name)
        self.assertEqual(ann_manifest["artifact_dir"], "ann/results/canonical")
        self.assertEqual(contract_payload["selected_run_id"], RUN_DIR.name)
        self.assertEqual(contract_payload["selected_run"], "ann/results/canonical")
        self.assertEqual(contract_payload["dataset_snapshot"], "ann/results/canonical/dataset_snapshot.jsonl")
        self.assertEqual(contract_payload["dataset_snapshot_sha256"], ann_manifest["dataset_snapshot_sha256"])
        self.assertEqual(contract_manifest["artifact_dir"], "contract/results/canonical")
        self.assertEqual(contract_manifest["source_ann_manifest"], "ann/results/canonical/manifest.json")
        self.assertEqual(contract_manifest["source_ann_artifact_dir"], "ann/results/canonical")

        for path in (
            ann_manifest_path,
            contract_weights_path,
            contract_manifest_path,
            contract_run_weights,
            contract_run_manifest,
            contract_model_path,
            repo_root / "rtl" / "results" / "canonical" / "sv" / "weight_rom.sv",
            repo_root / "formalize" / "src" / "MlpCore" / "Defs" / "SpecCore.lean",
            repo_root / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ContractData.lean",
            repo_root / "simulations" / "shared" / "test_vectors.mem",
            repo_root / "simulations" / "shared" / "test_vectors_meta.svh",
        ):
            self.assertTrue(path.exists(), msg=f"expected generated artifact: {path}")

    def test_freeze_check_requires_ann_canonical_without_explicit_run(self) -> None:
        repo_root = self._prepare_repo_root()

        result = subprocess.run(
            ["python3", "contract/runners/freeze.py", "--check"],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertNotEqual(result.returncode, 0, msg=output)
        self.assertIn("missing ANN canonical manifest", output)

    def test_freeze_check_fails_when_ann_canonical_dataset_hash_drifts(self) -> None:
        repo_root = self._prepare_repo_root(include_ann_canonical=True, include_contract_canonical=True)
        snapshot_path = repo_root / "ann" / "results" / "canonical" / "dataset_snapshot.jsonl"
        snapshot_path.write_text(snapshot_path.read_text(encoding="utf-8") + "\n", encoding="utf-8")

        result = subprocess.run(
            ["python3", "contract/runners/freeze.py", "--check"],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertNotEqual(result.returncode, 0, msg=output)
        self.assertIn("ANN canonical manifest dataset snapshot hash does not match", output)

    def test_render_sparkle_contract_data_text_includes_expected_signed_literals(self) -> None:
        weights = {
            "w1": [
                [-2, 1, 0, 3],
                [4, -5, 6, -7],
                [8, 9, -10, 11],
                [-12, 13, 14, -15],
                [16, -17, 18, 19],
                [-20, 21, -22, 23],
                [24, -25, 26, -27],
                [28, 29, -30, 31],
            ],
            "b1": [32, -33, 34, -35, 36, -37, 38, -39],
            "w2": [-40, 41, -42, 43, -44, 45, -46, 47],
            "b2": -48,
        }

        rendered = downstream_sync.render_sparkle_contract_data_text(weights)

        self.assertIn("/- BEGIN AUTO-GENERATED CONTRACT DATA -/", rendered)
        self.assertIn("/- END AUTO-GENERATED CONTRACT DATA -/", rendered)
        self.assertIn("Signal.pure (bv8 (-2))", rendered)
        self.assertIn("Signal.pure (bv8 31)", rendered)
        self.assertIn("hidden_idx === Signal.pure (bv4 7) => Signal.pure (bv32 (-39))", rendered)
        self.assertIn("input_idx === Signal.pure (bv4 6) => Signal.pure (bv8 (-46))", rendered)
        self.assertIn("Signal.pure (bv32 (-48))", rendered)

    def test_render_vectors_fails_when_score_class_witnesses_are_missing(self) -> None:
        with self.assertRaisesRegex(ValueError, "unable to synthesize required score-class witnesses for zero"):
            gen_vectors.render_vectors(self._always_positive_weights())

    def test_check_witness_coverage_fails_for_always_positive_weights(self) -> None:
        contract_weights_path = self.temp_root / "contract" / "results" / "canonical" / "weights.json"
        contract_weights_path.parent.mkdir(parents=True, exist_ok=True)
        contract_payload = json.loads((ROOT / "contract" / "results" / "canonical" / "weights.json").read_text(encoding="utf-8"))
        contract_payload.update(self._always_positive_weights())
        contract_payload["selected_run_id"] = RUN_DIR.name
        contract_payload["selected_run"] = "ann/results/canonical"
        contract_payload["dataset_snapshot"] = "ann/results/canonical/dataset_snapshot.jsonl"
        contract_payload["dataset_snapshot_sha256"] = contract_artifacts.file_sha256(ROOT / "ann" / "results" / "canonical" / "dataset_snapshot.jsonl")
        contract_weights_path.write_text(json.dumps(contract_payload), encoding="utf-8")

        with patch.object(gen_vectors, "CONTRACT_WEIGHTS_PATH", contract_weights_path):
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
        target = self.temp_root / "contract" / "results" / "canonical" / "preserved.txt"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("before\n", encoding="utf-8")
        target.chmod(0o754)

        contract_artifacts.write_text_files({target: ("after\n", "utf-8")})

        self.assertEqual(target.read_text(encoding="utf-8"), "after\n")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o754)

    def test_make_sim_iverilog_runs_after_contract_preflight(self) -> None:
        for tool in ("make", "iverilog", "vvp"):
            if shutil.which(tool) is None:
                self.skipTest(f"missing required tool: {tool}")

        repo_root = self._prepare_repo_root()
        freeze_result = subprocess.run(
            [
                "python3",
                "contract/runners/freeze.py",
                "--run-dir",
                f"ann/results/runs/{RUN_DIR.name}",
            ],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        freeze_output = freeze_result.stdout + freeze_result.stderr
        self.assertEqual(freeze_result.returncode, 0, msg=freeze_output)

        result = subprocess.run(
            ["make", "sim-iverilog"],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        output = result.stdout + result.stderr

        self.assertEqual(result.returncode, 0, msg=output)
        self.assertIn("python3 contract/runners/freeze.py --check", output)
        self.assertIn("PASS rtl shared iverilog", output)


if __name__ == "__main__":
    unittest.main()
