from __future__ import annotations

from typing import Any, Iterable, Sequence

try:
    from .params import HIDDEN_SIZE, INPUT_SIZE
except ImportError:
    from params import HIDDEN_SIZE, INPUT_SIZE


def round_half_away_from_zero(value: float) -> int:
    if value >= 0:
        return int(value + 0.5)
    return int(value - 0.5)


def clip_signed(value: int, bits: int) -> int:
    min_value = -(1 << (bits - 1))
    max_value = (1 << (bits - 1)) - 1
    return max(min(value, max_value), min_value)


def quantize_scalar(value: float, bits: int) -> int:
    return clip_signed(round_half_away_from_zero(value), bits)


def quantize_vector(values: Sequence[float], bits: int) -> list[int]:
    return [quantize_scalar(value, bits) for value in values]


def quantize_matrix(rows: Sequence[Sequence[float]], bits: int) -> list[list[int]]:
    return [quantize_vector(row, bits) for row in rows]


def assert_signed_range(values: Iterable[int], bits: int, label: str) -> None:
    min_value = -(1 << (bits - 1))
    max_value = (1 << (bits - 1)) - 1
    for value in values:
        if not (min_value <= value <= max_value):
            raise ValueError(f"{label} value {value} is out of range for signed {bits}-bit")


def wrap_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    if value & sign_bit:
        return value - (1 << bits)
    return value


def relu(value: int) -> int:
    return value if value > 0 else 0


def _coerce_number(value: object, field: str, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{label} field '{field}' must be numeric")
    return float(value)


def _coerce_numeric_vector(value: object, field: str, label: str, expected_length: int) -> list[float]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list")
    if len(value) != expected_length:
        raise ValueError(f"{label} field '{field}' must have length {expected_length}")
    return [_coerce_number(item, f"{field}[{index}]", label) for index, item in enumerate(value)]


def _coerce_numeric_matrix(
    value: object,
    field: str,
    label: str,
    expected_rows: int,
    expected_cols: int,
) -> list[list[float]]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list of rows")
    if len(value) != expected_rows:
        raise ValueError(f"{label} field '{field}' must have {expected_rows} rows")
    rows: list[list[float]] = []
    for row_index, row in enumerate(value):
        rows.append(_coerce_numeric_vector(row, f"{field}[{row_index}]", label, expected_cols))
    return rows


def coerce_float_weights_payload(payload: dict[str, Any], *, label: str) -> dict[str, object]:
    if not isinstance(payload, dict):
        raise TypeError(f"{label} must be a JSON object")

    schema_version = payload.get("schema_version", 1)
    if schema_version != 1:
        raise ValueError(f"{label} field 'schema_version' must be 1")

    input_size = payload.get("input_size", INPUT_SIZE)
    hidden_size = payload.get("hidden_size", HIDDEN_SIZE)
    if input_size != INPUT_SIZE:
        raise ValueError(f"{label} field 'input_size' must be {INPUT_SIZE}")
    if hidden_size != HIDDEN_SIZE:
        raise ValueError(f"{label} field 'hidden_size' must be {HIDDEN_SIZE}")

    normalized: dict[str, object] = {
        "schema_version": 1,
        "source": str(payload.get("source", "trained_float_unknown")),
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "w1": _coerce_numeric_matrix(payload.get("w1"), "w1", label, HIDDEN_SIZE, INPUT_SIZE),
        "b1": _coerce_numeric_vector(payload.get("b1"), "b1", label, HIDDEN_SIZE),
        "w2": _coerce_numeric_vector(payload.get("w2"), "w2", label, HIDDEN_SIZE),
        "b2": _coerce_number(payload.get("b2"), "b2", label),
    }

    if "training_seed" in payload:
        training_seed = payload["training_seed"]
        if isinstance(training_seed, bool) or not isinstance(training_seed, int):
            raise ValueError(f"{label} field 'training_seed' must be an integer")
        normalized["training_seed"] = training_seed
    if "dataset_version" in payload:
        dataset_version = payload["dataset_version"]
        if not isinstance(dataset_version, str) or not dataset_version:
            raise ValueError(f"{label} field 'dataset_version' must be a non-empty string")
        normalized["dataset_version"] = dataset_version
    if "selected_epoch" in payload:
        selected_epoch = payload["selected_epoch"]
        if isinstance(selected_epoch, bool) or not isinstance(selected_epoch, int):
            raise ValueError(f"{label} field 'selected_epoch' must be an integer")
        normalized["selected_epoch"] = selected_epoch
    if "selection_mode" in payload:
        selection_mode = payload["selection_mode"]
        if not isinstance(selection_mode, str) or not selection_mode:
            raise ValueError(f"{label} field 'selection_mode' must be a non-empty string")
        normalized["selection_mode"] = selection_mode

    return normalized


def _coerce_int(value: object, field: str, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{label} field '{field}' must be an integer")
    return value


def _coerce_int_vector(value: object, field: str, label: str, expected_length: int) -> list[int]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list")
    if len(value) != expected_length:
        raise ValueError(f"{label} field '{field}' must have length {expected_length}")
    return [_coerce_int(item, f"{field}[{index}]", label) for index, item in enumerate(value)]


def _coerce_int_matrix(
    value: object, field: str, label: str, expected_rows: int, expected_cols: int,
) -> list[list[int]]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list of rows")
    if len(value) != expected_rows:
        raise ValueError(f"{label} field '{field}' must have {expected_rows} rows")
    return [_coerce_int_vector(row, f"{field}[{i}]", label, expected_cols) for i, row in enumerate(value)]


def coerce_int_weights_payload(payload: dict[str, Any], *, label: str) -> dict[str, object]:
    if not isinstance(payload, dict):
        raise TypeError(f"{label} must be a JSON object")

    input_size = int(payload.get("input_size", INPUT_SIZE))
    hidden_size = int(payload.get("hidden_size", HIDDEN_SIZE))
    if input_size != INPUT_SIZE:
        raise ValueError(f"{label} field 'input_size' must be {INPUT_SIZE}")
    if hidden_size != HIDDEN_SIZE:
        raise ValueError(f"{label} field 'hidden_size' must be {HIDDEN_SIZE}")

    w1 = _coerce_int_matrix(payload.get("w1"), "w1", label, HIDDEN_SIZE, INPUT_SIZE)
    b1 = _coerce_int_vector(payload.get("b1"), "b1", label, HIDDEN_SIZE)
    w2 = _coerce_int_vector(payload.get("w2"), "w2", label, HIDDEN_SIZE)
    b2 = _coerce_int(payload.get("b2"), "b2", label)

    assert_signed_range((v for row in w1 for v in row), 8, f"{label} W1")
    assert_signed_range(w2, 8, f"{label} W2")
    assert_signed_range(b1, 32, f"{label} b1")
    assert_signed_range([b2], 32, f"{label} b2")

    return {
        "schema_version": int(payload.get("schema_version", 1)),
        "source": str(payload.get("source", "unknown")),
        "input_size": input_size,
        "hidden_size": hidden_size,
        "w1": w1,
        "b1": b1,
        "w2": w2,
        "b2": b2,
    }


def quantize_float_weights_payload(
    payload: dict[str, Any],
    *,
    source: str = "trained_quantized_from_float",
) -> dict[str, object]:
    float_weights = coerce_float_weights_payload(payload, label="float weights payload")
    quantized: dict[str, object] = {
        "schema_version": 1,
        "source": source,
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "w1": quantize_matrix(float_weights["w1"], bits=8),
        "b1": quantize_vector(float_weights["b1"], bits=32),
        "w2": quantize_vector(float_weights["w2"], bits=8),
        "b2": quantize_scalar(float_weights["b2"], bits=32),
    }

    for field in ("training_seed", "dataset_version", "selected_epoch"):
        if field in float_weights:
            quantized[field] = float_weights[field]

    return quantized
