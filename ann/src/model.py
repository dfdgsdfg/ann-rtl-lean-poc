from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable, Sequence

try:
    from .params import HIDDEN_SIZE, INPUT_SIZE
    from .quantize import coerce_int_weights_payload, relu, wrap_signed
except ImportError:
    from params import HIDDEN_SIZE, INPUT_SIZE
    from quantize import coerce_int_weights_payload, relu, wrap_signed


def _coerce_weights(payload: dict[str, object]) -> dict[str, object]:
    return coerce_int_weights_payload(payload, label="weights payload")


def load_weights(path: str | Path) -> dict[str, object]:
    weights_path = Path(path)
    if not weights_path.exists():
        raise FileNotFoundError(f"missing weights file: {weights_path}")
    return _coerce_weights(json.loads(weights_path.read_text(encoding="utf-8")))


def normalize_input(values: Iterable[int]) -> tuple[int, int, int, int]:
    data = tuple(wrap_signed(v, 8) for v in values)
    if len(data) != INPUT_SIZE:
        raise ValueError(f"expected {INPUT_SIZE} inputs, got {len(data)}")
    return data  # type: ignore[return-value]


def hidden_layer(values: Sequence[int], weights: dict[str, object]) -> list[int]:
    xs = normalize_input(values)
    w1 = weights["w1"]
    b1 = weights["b1"]
    hidden: list[int] = []
    for i in range(HIDDEN_SIZE):
        acc = 0
        for j in range(INPUT_SIZE):
            product = wrap_signed(xs[j] * w1[i][j], 16)
            acc = wrap_signed(acc + product, 32)
        acc = wrap_signed(acc + b1[i], 32)
        hidden.append(wrap_signed(relu(acc), 16))
    return hidden


def score(values: Sequence[int], weights: dict[str, object]) -> int:
    hidden = hidden_layer(values, weights=weights)
    w2 = weights["w2"]
    b2 = weights["b2"]
    acc = 0
    for i in range(HIDDEN_SIZE):
        product = wrap_signed(hidden[i] * w2[i], 24)
        acc = wrap_signed(acc + product, 32)
    return wrap_signed(acc + b2, 32)


def infer(values: Sequence[int], weights: dict[str, object]) -> int:
    return int(score(values, weights=weights) > 0)


def pack_vector(values: Sequence[int], expected: int) -> int:
    xs = normalize_input(values)
    word = expected & 0x1
    for value in xs:
        word = (word << 8) | (value & 0xFF)
    return word
