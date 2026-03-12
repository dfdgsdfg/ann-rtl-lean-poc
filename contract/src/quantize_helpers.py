from __future__ import annotations

from typing import Iterable


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
