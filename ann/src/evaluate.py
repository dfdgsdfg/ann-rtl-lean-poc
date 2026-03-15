from __future__ import annotations

import json
from pathlib import Path
from typing import Any

try:
    from .artifacts import SELECTED_RUN_PATH, read_json, resolve_metadata_path
    from .dataset import (
        DEFAULT_DATASET_SEED,
        DEFAULT_INPUT_HIGH,
        DEFAULT_INPUT_LOW,
        DEFAULT_TRAIN_SIZE,
        DEFAULT_VAL_SIZE,
        build_dataset,
    )
    from .quantize import coerce_float_weights_payload, coerce_int_weights_payload
    from .train import evaluate_float, evaluate_quantized
except ImportError:
    from artifacts import SELECTED_RUN_PATH, read_json, resolve_metadata_path
    from dataset import (
        DEFAULT_DATASET_SEED,
        DEFAULT_INPUT_HIGH,
        DEFAULT_INPUT_LOW,
        DEFAULT_TRAIN_SIZE,
        DEFAULT_VAL_SIZE,
        build_dataset,
    )
    from quantize import coerce_float_weights_payload, coerce_int_weights_payload
    from train import evaluate_float, evaluate_quantized

ARTIFACT_PATHS = {
    "quantized": ("weights_quantized.json", "quantized"),
    "selected-float": ("weights_float_selected.json", "float"),
    "best-float": ("weights_float.json", "float"),
}


def _default_run_dir() -> Path:
    if not SELECTED_RUN_PATH.exists():
        raise FileNotFoundError(
            "missing selected ANN run metadata; pass --run-dir/--weights or refresh the canonical contract selection"
        )

    metadata = read_json(SELECTED_RUN_PATH)
    selected_run_id = metadata.get("selected_run_id")
    selected_run = metadata.get("selected_run")
    if not isinstance(selected_run_id, str) or not selected_run_id:
        raise ValueError(f"{SELECTED_RUN_PATH} is missing required field 'selected_run_id'")
    if not isinstance(selected_run, str) or not selected_run:
        raise ValueError(f"{SELECTED_RUN_PATH} is missing required field 'selected_run'")
    return resolve_metadata_path(selected_run)


def resolve_run_artifact(run_dir: Path | None, artifact: str) -> tuple[Path, str]:
    if artifact not in ARTIFACT_PATHS:
        raise ValueError(f"unsupported artifact kind: {artifact}")
    base_dir = run_dir if run_dir is not None else _default_run_dir()
    filename, kind = ARTIFACT_PATHS[artifact]
    artifact_path = Path(base_dir) / filename
    if not artifact_path.exists():
        raise FileNotFoundError(f"missing ANN artifact: {artifact_path}")
    return artifact_path, kind


def _declared_payload_kind(payload: dict[str, Any]) -> str | None:
    source = str(payload.get("source", ""))
    if "quantized" in source or source in {"trained_quantized_selected", "trained_selected_quantized"}:
        return "quantized"
    if "float" in source:
        return "float"
    selection_mode = payload.get("selection_mode")
    if isinstance(selection_mode, str) and selection_mode:
        return "float"
    return None


def _contains_float(value: object) -> bool:
    if isinstance(value, float):
        return True
    if isinstance(value, list):
        return any(_contains_float(item) for item in value)
    return False


def _payload_kind_from_source(payload: dict[str, Any]) -> str:
    declared = _declared_payload_kind(payload)
    if declared is not None:
        return declared

    for field in ("w1", "b1", "w2", "b2"):
        if _contains_float(payload.get(field)):
            return "float"
    return "quantized"


def load_evaluation_payload(
    *,
    run_dir: Path | None = None,
    weights_path: Path | None = None,
    artifact: str = "quantized",
    expected_kind: str | None = None,
) -> tuple[dict[str, object], str, Path]:
    if weights_path is not None:
        payload_path = Path(weights_path)
        if not payload_path.exists():
            raise FileNotFoundError(f"missing weights file: {payload_path}")
        raw_payload = json.loads(payload_path.read_text(encoding="utf-8"))
        declared_kind = _declared_payload_kind(raw_payload)
        if expected_kind is not None and declared_kind is None:
            kind = expected_kind
        else:
            kind = declared_kind or _payload_kind_from_source(raw_payload)
    else:
        payload_path, kind = resolve_run_artifact(run_dir, artifact)
        raw_payload = json.loads(payload_path.read_text(encoding="utf-8"))

    if kind == "float":
        payload = coerce_float_weights_payload(raw_payload, label=f"ANN float weights at {payload_path}")
    else:
        payload = coerce_int_weights_payload(raw_payload, label=f"ANN quantized weights at {payload_path}")
    return payload, kind, payload_path


def evaluate_payload(
    payload: dict[str, object],
    *,
    kind: str,
    seed: int = DEFAULT_DATASET_SEED,
    train_size: int = DEFAULT_TRAIN_SIZE,
    val_size: int = DEFAULT_VAL_SIZE,
    input_low: int = DEFAULT_INPUT_LOW,
    input_high: int = DEFAULT_INPUT_HIGH,
    split: str = "all",
) -> dict[str, object]:
    dataset = build_dataset(
        seed=seed,
        train_size=train_size,
        val_size=val_size,
        input_low=input_low,
        input_high=input_high,
    )

    if split == "train":
        examples = dataset["train"]
    elif split == "val":
        examples = dataset["val"]
    elif split == "all":
        examples = dataset["train"] + dataset["val"]
    else:
        raise ValueError(f"unsupported split: {split}")

    if len(examples) == 0:
        raise ValueError(
            f"evaluate split '{split}' is empty for train_size={train_size}, val_size={val_size}"
        )

    if kind == "float":
        metrics = evaluate_float(examples, payload)
    elif kind == "quantized":
        metrics = evaluate_quantized(examples, payload)
    else:
        raise ValueError(f"unsupported weights kind: {kind}")

    return {
        "dataset_version": dataset["metadata"]["version"],
        "dataset_seed": seed,
        "train_size": train_size,
        "val_size": val_size,
        "input_low": input_low,
        "input_high": input_high,
        "split": split,
        "example_count": len(examples),
        "weights_kind": kind,
        "loss": metrics["loss"],
        "accuracy": metrics["accuracy"],
    }
