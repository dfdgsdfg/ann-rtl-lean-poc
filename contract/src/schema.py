from __future__ import annotations

from typing import Any

from .boundedness import build_boundedness_payload
from .params import HIDDEN_SIZE, INPUT_SIZE
from .quantize_helpers import assert_signed_range

SCHEMA_VERSION = 1
ANALYSIS_SOURCES = {"trained_selected_quantized"}


def _require_mapping(payload: dict[str, Any], label: str) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise TypeError(f"{label} must be a JSON object")
    return payload


def _coerce_string(value: object, field: str, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{label} field '{field}' must be a non-empty string")
    return value


def _coerce_mapping(value: object, field: str, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} field '{field}' must be a JSON object")
    return value


def _coerce_int(value: object, field: str, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{label} field '{field}' must be an integer")
    return value


def _coerce_vector(value: object, field: str, label: str, expected_length: int) -> list[int]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list")
    if len(value) != expected_length:
        raise ValueError(f"{label} field '{field}' must have length {expected_length}")
    return [_coerce_int(item, f"{field}[{index}]", label) for index, item in enumerate(value)]


def _coerce_matrix(
    value: object,
    field: str,
    label: str,
    expected_rows: int,
    expected_cols: int,
) -> list[list[int]]:
    if not isinstance(value, list):
        raise ValueError(f"{label} field '{field}' must be a list of rows")
    if len(value) != expected_rows:
        raise ValueError(f"{label} field '{field}' must have {expected_rows} rows")

    rows: list[list[int]] = []
    for row_index, row in enumerate(value):
        rows.append(_coerce_vector(row, f"{field}[{row_index}]", label, expected_cols))
    return rows


def coerce_weights_payload(payload: dict[str, Any], *, label: str) -> dict[str, object]:
    raw = _require_mapping(payload, label)

    schema_version = int(raw.get("schema_version", SCHEMA_VERSION))
    if schema_version != SCHEMA_VERSION:
        raise ValueError(f"{label} field 'schema_version' must be {SCHEMA_VERSION}")

    source = str(raw.get("source", "unknown"))
    input_size = int(raw.get("input_size", INPUT_SIZE))
    hidden_size = int(raw.get("hidden_size", HIDDEN_SIZE))
    if input_size != INPUT_SIZE:
        raise ValueError(f"{label} field 'input_size' must be {INPUT_SIZE}")
    if hidden_size != HIDDEN_SIZE:
        raise ValueError(f"{label} field 'hidden_size' must be {HIDDEN_SIZE}")

    w1 = _coerce_matrix(raw.get("w1"), "w1", label, HIDDEN_SIZE, INPUT_SIZE)
    b1 = _coerce_vector(raw.get("b1"), "b1", label, HIDDEN_SIZE)
    w2 = _coerce_vector(raw.get("w2"), "w2", label, HIDDEN_SIZE)
    b2 = _coerce_int(raw.get("b2"), "b2", label)

    assert_signed_range((value for row in w1 for value in row), 8, f"{label} W1")
    assert_signed_range(w2, 8, f"{label} W2")
    assert_signed_range(b1, 32, f"{label} b1")
    assert_signed_range([b2], 32, f"{label} b2")

    normalized: dict[str, object] = {
        "schema_version": schema_version,
        "source": source,
        "input_size": input_size,
        "hidden_size": hidden_size,
        "w1": w1,
        "b1": b1,
        "w2": w2,
        "b2": b2,
    }

    if "dataset_version" in raw:
        normalized["dataset_version"] = _coerce_string(raw["dataset_version"], "dataset_version", label)
    if "training_seed" in raw:
        normalized["training_seed"] = _coerce_int(raw["training_seed"], "training_seed", label)
    if "selected_run" in raw:
        normalized["selected_run"] = _coerce_string(raw["selected_run"], "selected_run", label)
    if "selected_epoch" in raw:
        normalized["selected_epoch"] = _coerce_int(raw["selected_epoch"], "selected_epoch", label)

    return normalized


def validate_quantized_source_payload(payload: dict[str, Any], *, label: str) -> dict[str, object]:
    normalized = coerce_weights_payload(payload, label=label)
    if "dataset_version" not in normalized:
        raise ValueError(f"{label} field 'dataset_version' is required")
    if "training_seed" not in normalized:
        raise ValueError(f"{label} field 'training_seed' is required")
    return normalized


def validate_analysis_payload(payload: dict[str, Any], *, label: str) -> dict[str, object]:
    raw = _require_mapping(payload, label)
    normalized = validate_quantized_source_payload(raw, label=label)
    if "selected_run" not in normalized:
        raise ValueError(f"{label} field 'selected_run' is required")
    if str(normalized["source"]) not in ANALYSIS_SOURCES:
        allowed = ", ".join(sorted(ANALYSIS_SOURCES))
        raise ValueError(f"{label} field 'source' must be one of: {allowed}")
    normalized["quantization"] = _validate_quantization_contract(raw.get("quantization"), label=label)
    normalized["arithmetic"] = _validate_arithmetic_contract(raw.get("arithmetic"), label=label)
    normalized["boundedness"] = _validate_boundedness_contract(raw.get("boundedness"), label=label)
    return normalized


def build_analysis_payload(
    quantized_payload: dict[str, Any],
    *,
    selected_run: str,
    source: str = "trained_selected_quantized",
) -> dict[str, object]:
    quantized = validate_quantized_source_payload(quantized_payload, label="selected quantized weights")
    arithmetic_contract = {
        "input_bits": 8,
        "hidden_activation_bits": 16,
        "hidden_product_bits": 16,
        "output_weight_bits": 8,
        "output_product_bits": 24,
        "accumulator_bits": 32,
        "bias_bits": 32,
        "overflow": "two_complement_wraparound",
        "sign_extension": "required_between_product_and_accumulator_stages",
    }
    return validate_analysis_payload(
        {
            "schema_version": SCHEMA_VERSION,
            "source": source,
            "selected_run": selected_run,
            "input_size": quantized["input_size"],
            "hidden_size": quantized["hidden_size"],
            "dataset_version": quantized["dataset_version"],
            "training_seed": quantized["training_seed"],
            "w1": quantized["w1"],
            "b1": quantized["b1"],
            "w2": quantized["w2"],
            "b2": quantized["b2"],
            "quantization": {
                "rounding": "half_away_from_zero",
                "clipping": "signed_saturating",
                "weight_bits": 8,
                "bias_bits": 32,
            },
            "arithmetic": arithmetic_contract,
            "boundedness": build_boundedness_payload(
                quantized,
                input_bits=arithmetic_contract["input_bits"],
                hidden_product_bits=arithmetic_contract["hidden_product_bits"],
                hidden_activation_bits=arithmetic_contract["hidden_activation_bits"],
                output_product_bits=arithmetic_contract["output_product_bits"],
                accumulator_bits=arithmetic_contract["accumulator_bits"],
            ),
        },
        label="frozen analysis contract",
    )


def validate_selected_run_metadata(payload: dict[str, Any], *, label: str = "selected run metadata") -> dict[str, str]:
    raw = _require_mapping(payload, label)
    contract_weights = raw.get("contract_weights")
    if contract_weights is None:
        contract_weights = raw.get("analysis_weights")
    return {
        "selected_run": _coerce_string(raw.get("selected_run"), "selected_run", label),
        "weights_quantized": _coerce_string(raw.get("weights_quantized"), "weights_quantized", label),
        "contract_weights": _coerce_string(contract_weights, "contract_weights", label),
    }


def _validate_quantization_contract(value: object, *, label: str) -> dict[str, object]:
    raw = _coerce_mapping(value, "quantization", label)
    normalized = {
        "rounding": _coerce_string(raw.get("rounding"), "quantization.rounding", label),
        "clipping": _coerce_string(raw.get("clipping"), "quantization.clipping", label),
        "weight_bits": _coerce_int(raw.get("weight_bits"), "quantization.weight_bits", label),
        "bias_bits": _coerce_int(raw.get("bias_bits"), "quantization.bias_bits", label),
    }
    expected = {
        "rounding": "half_away_from_zero",
        "clipping": "signed_saturating",
        "weight_bits": 8,
        "bias_bits": 32,
    }
    for key, expected_value in expected.items():
        if normalized[key] != expected_value:
            raise ValueError(f"{label} field 'quantization.{key}' must be {expected_value!r}")
    return normalized


def _validate_arithmetic_contract(value: object, *, label: str) -> dict[str, object]:
    raw = _coerce_mapping(value, "arithmetic", label)
    normalized = {
        "input_bits": _coerce_int(raw.get("input_bits"), "arithmetic.input_bits", label),
        "hidden_activation_bits": _coerce_int(raw.get("hidden_activation_bits"), "arithmetic.hidden_activation_bits", label),
        "hidden_product_bits": _coerce_int(raw.get("hidden_product_bits"), "arithmetic.hidden_product_bits", label),
        "output_weight_bits": _coerce_int(raw.get("output_weight_bits"), "arithmetic.output_weight_bits", label),
        "output_product_bits": _coerce_int(raw.get("output_product_bits"), "arithmetic.output_product_bits", label),
        "accumulator_bits": _coerce_int(raw.get("accumulator_bits"), "arithmetic.accumulator_bits", label),
        "bias_bits": _coerce_int(raw.get("bias_bits"), "arithmetic.bias_bits", label),
        "overflow": _coerce_string(raw.get("overflow"), "arithmetic.overflow", label),
        "sign_extension": _coerce_string(raw.get("sign_extension"), "arithmetic.sign_extension", label),
    }
    expected = {
        "input_bits": 8,
        "hidden_activation_bits": 16,
        "hidden_product_bits": 16,
        "output_weight_bits": 8,
        "output_product_bits": 24,
        "accumulator_bits": 32,
        "bias_bits": 32,
        "overflow": "two_complement_wraparound",
        "sign_extension": "required_between_product_and_accumulator_stages",
    }
    for key, expected_value in expected.items():
        if normalized[key] != expected_value:
            raise ValueError(f"{label} field 'arithmetic.{key}' must be {expected_value!r}")
    return normalized


def _validate_boundedness_contract(value: object, *, label: str) -> dict[str, object]:
    raw = _coerce_mapping(value, "boundedness", label)
    normalized = {
        "scope": _coerce_string(raw.get("scope"), "boundedness.scope", label),
        "status": _coerce_string(raw.get("status"), "boundedness.status", label),
        "input_range": _validate_input_range(raw.get("input_range"), label=label),
        "hidden_product": _validate_stage_bounds(raw.get("hidden_product"), "hidden_product", 16, label=label),
        "hidden_pre_activation": _validate_stage_bounds(raw.get("hidden_pre_activation"), "hidden_pre_activation", 32, label=label),
        "hidden_activation": _validate_stage_bounds(raw.get("hidden_activation"), "hidden_activation", 16, label=label),
        "output_product": _validate_stage_bounds(raw.get("output_product"), "output_product", 24, label=label),
        "output_accumulator": _validate_stage_bounds(raw.get("output_accumulator"), "output_accumulator", 32, label=label),
    }
    if normalized["scope"] != "all_signed_int8_inputs":
        raise ValueError(f"{label} field 'boundedness.scope' must be 'all_signed_int8_inputs'")
    if normalized["status"] != "verified":
        raise ValueError(f"{label} field 'boundedness.status' must be 'verified'")
    return normalized


def _validate_input_range(value: object, *, label: str) -> dict[str, int]:
    raw = _coerce_mapping(value, "boundedness.input_range", label)
    normalized = {
        "min": _coerce_int(raw.get("min"), "boundedness.input_range.min", label),
        "max": _coerce_int(raw.get("max"), "boundedness.input_range.max", label),
    }
    if normalized["min"] != -128 or normalized["max"] != 127:
        raise ValueError(f"{label} field 'boundedness.input_range' must be the signed int8 range [-128, 127]")
    return normalized


def _validate_stage_bounds(value: object, field: str, expected_bits: int, *, label: str) -> dict[str, int]:
    raw = _coerce_mapping(value, f"boundedness.{field}", label)
    normalized = {
        "bits": _coerce_int(raw.get("bits"), f"boundedness.{field}.bits", label),
        "min_bound": _coerce_int(raw.get("min_bound"), f"boundedness.{field}.min_bound", label),
        "max_bound": _coerce_int(raw.get("max_bound"), f"boundedness.{field}.max_bound", label),
    }
    if normalized["bits"] != expected_bits:
        raise ValueError(f"{label} field 'boundedness.{field}.bits' must be {expected_bits}")
    if normalized["min_bound"] > normalized["max_bound"]:
        raise ValueError(f"{label} field 'boundedness.{field}.min_bound' must be <= max_bound")

    min_value = -(1 << (expected_bits - 1))
    max_value = (1 << (expected_bits - 1)) - 1
    if normalized["min_bound"] < min_value or normalized["max_bound"] > max_value:
        raise ValueError(
            f"{label} field 'boundedness.{field}' must fit signed {expected_bits}-bit range "
            f"[{min_value}, {max_value}]"
        )
    return normalized
