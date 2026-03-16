from __future__ import annotations

import json
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import patch

from ann.cli import __main__ as ann_cli
from ann.src import evaluate as ann_evaluate
from ann.src import train as ann_train


ROOT = Path(__file__).resolve().parents[2]
CANONICAL_DIR = ROOT / "ann" / "results" / "canonical"
SELECTED_QUANTIZED = CANONICAL_DIR / "weights_quantized.json"


def _integral_float_weights_payload() -> dict[str, object]:
    return {
        "schema_version": 1,
        "input_size": 4,
        "hidden_size": 8,
        "w1": [[0.0, 0.0, 0.0, 0.0] for _ in range(8)],
        "b1": [0.0] * 8,
        "w2": [0.0] * 8,
        "b2": 0.0,
    }


class AnnCliRegressionTests(unittest.TestCase):
    def test_train_rejects_zero_sized_split(self) -> None:
        with self.assertRaisesRegex(ValueError, "non-empty train and val splits"):
            ann_train.train(Namespace(train_size=0, val_size=1))

    def test_evaluate_payload_rejects_empty_selected_split(self) -> None:
        payload, kind, _ = ann_evaluate.load_evaluation_payload(run_dir=SELECTED_QUANTIZED.parent, artifact="quantized")
        with self.assertRaisesRegex(ValueError, "split 'train' is empty"):
            ann_evaluate.evaluate_payload(payload, kind=kind, train_size=0, val_size=1, split="train")

    def test_evaluate_payload_allows_zero_unused_split(self) -> None:
        payload, kind, _ = ann_evaluate.load_evaluation_payload(run_dir=SELECTED_QUANTIZED.parent, artifact="quantized")
        result = ann_evaluate.evaluate_payload(payload, kind=kind, train_size=0, val_size=1, split="all")
        self.assertEqual(result["weights_kind"], "quantized")
        self.assertEqual(result["example_count"], 1)

    def test_default_run_dir_requires_selected_run_metadata(self) -> None:
        missing_path = ROOT / "build" / "missing-ann-canonical-manifest.json"
        with patch.object(ann_evaluate, "CANONICAL_MANIFEST_PATH", missing_path):
            with self.assertRaisesRegex(FileNotFoundError, "missing ANN canonical manifest"):
                ann_evaluate.resolve_run_artifact(None, "quantized")

    def test_evaluation_helpers_reject_empty_lists(self) -> None:
        with self.assertRaisesRegex(ValueError, "requires at least one example"):
            ann_train.evaluate_float([], {"w1": [[0.0] * 4 for _ in range(8)], "b1": [0.0] * 8, "w2": [0.0] * 8, "b2": 0.0})
        with self.assertRaisesRegex(ValueError, "requires at least one example"):
            ann_train.evaluate_quantized([], {"w1": [[0] * 4 for _ in range(8)], "b1": [0] * 8, "w2": [0] * 8, "b2": 0})

    def test_explicit_integral_float_payload_is_detected_as_float(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            weights_path = Path(tmpdir) / "weights_float.json"
            weights_path.write_text(json.dumps(_integral_float_weights_payload()), encoding="utf-8")

            payload, kind, payload_path = ann_evaluate.load_evaluation_payload(weights_path=weights_path)

        self.assertEqual(kind, "float")
        self.assertEqual(payload_path, weights_path)
        self.assertEqual(payload["b2"], 0.0)

    def test_quantize_accepts_explicit_integral_float_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            weights_path = Path(tmpdir) / "weights_float.json"
            out_path = Path(tmpdir) / "weights_quantized.json"
            weights_path.write_text(json.dumps(_integral_float_weights_payload()), encoding="utf-8")

            rc = ann_cli.cmd_quantize(
                Namespace(
                    run_dir=None,
                    weights=weights_path,
                    artifact="selected-float",
                    out=out_path,
                    json=False,
                )
            )

            self.assertEqual(rc, 0)
            quantized = json.loads(out_path.read_text(encoding="utf-8"))

        self.assertEqual(quantized["w1"], [[0, 0, 0, 0] for _ in range(8)])
        self.assertEqual(quantized["b1"], [0] * 8)
        self.assertEqual(quantized["w2"], [0] * 8)
        self.assertEqual(quantized["b2"], 0)


if __name__ == "__main__":
    unittest.main()
