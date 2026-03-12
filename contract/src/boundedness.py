from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


def _signed_limits(bits: int) -> tuple[int, int]:
    return -(1 << (bits - 1)), (1 << (bits - 1)) - 1


@dataclass(frozen=True)
class Interval:
    min_bound: int
    max_bound: int

    def add(self, other: "Interval") -> "Interval":
        return Interval(
            min_bound=self.min_bound + other.min_bound,
            max_bound=self.max_bound + other.max_bound,
        )

    def multiply_by_constant(self, value: int) -> "Interval":
        left = self.min_bound * value
        right = self.max_bound * value
        return Interval(min(left, right), max(left, right))

    def relu(self) -> "Interval":
        return Interval(max(0, self.min_bound), max(0, self.max_bound))

    def to_payload(self, *, bits: int) -> dict[str, int]:
        return {
            "bits": bits,
            "min_bound": self.min_bound,
            "max_bound": self.max_bound,
        }


def _merge_intervals(intervals: Iterable[Interval]) -> Interval:
    iterator = iter(intervals)
    first = next(iterator)
    min_bound = first.min_bound
    max_bound = first.max_bound
    for interval in iterator:
        min_bound = min(min_bound, interval.min_bound)
        max_bound = max(max_bound, interval.max_bound)
    return Interval(min_bound=min_bound, max_bound=max_bound)


def _assert_interval_fits_signed(interval: Interval, bits: int, label: str) -> None:
    min_value, max_value = _signed_limits(bits)
    if interval.min_bound < min_value or interval.max_bound > max_value:
        raise ValueError(
            f"{label} bounds [{interval.min_bound}, {interval.max_bound}] exceed signed {bits}-bit range "
            f"[{min_value}, {max_value}]"
        )


def build_boundedness_payload(
    weights: dict[str, object],
    *,
    input_bits: int,
    hidden_product_bits: int,
    hidden_activation_bits: int,
    output_product_bits: int,
    accumulator_bits: int,
) -> dict[str, object]:
    input_min, input_max = _signed_limits(input_bits)
    input_interval = Interval(min_bound=input_min, max_bound=input_max)

    hidden_product_intervals: list[Interval] = []
    hidden_pre_intervals: list[Interval] = []
    hidden_activation_intervals: list[Interval] = []
    for row, bias in zip(weights["w1"], weights["b1"]):
        row_products = [input_interval.multiply_by_constant(weight) for weight in row]
        hidden_product_intervals.extend(row_products)

        hidden_pre = Interval(min_bound=bias, max_bound=bias)
        for product in row_products:
            hidden_pre = hidden_pre.add(product)
        _assert_interval_fits_signed(hidden_pre, accumulator_bits, "hidden pre-activation")
        hidden_pre_intervals.append(hidden_pre)

        hidden_activation = hidden_pre.relu()
        _assert_interval_fits_signed(hidden_activation, hidden_activation_bits, "hidden activation")
        hidden_activation_intervals.append(hidden_activation)

    hidden_product_bounds = _merge_intervals(hidden_product_intervals)
    _assert_interval_fits_signed(hidden_product_bounds, hidden_product_bits, "hidden product")
    hidden_pre_bounds = _merge_intervals(hidden_pre_intervals)
    hidden_activation_bounds = _merge_intervals(hidden_activation_intervals)

    output_product_intervals: list[Interval] = []
    for hidden_activation, weight in zip(hidden_activation_intervals, weights["w2"]):
        output_product = hidden_activation.multiply_by_constant(weight)
        _assert_interval_fits_signed(output_product, output_product_bits, "output product")
        output_product_intervals.append(output_product)

    output_product_bounds = _merge_intervals(output_product_intervals)
    output_accumulator = Interval(min_bound=weights["b2"], max_bound=weights["b2"])
    for output_product in output_product_intervals:
        output_accumulator = output_accumulator.add(output_product)
    _assert_interval_fits_signed(output_accumulator, accumulator_bits, "output accumulator")

    return {
        "scope": "all_signed_int8_inputs",
        "status": "verified",
        "input_range": {
            "min": input_min,
            "max": input_max,
        },
        "hidden_product": hidden_product_bounds.to_payload(bits=hidden_product_bits),
        "hidden_pre_activation": hidden_pre_bounds.to_payload(bits=accumulator_bits),
        "hidden_activation": hidden_activation_bounds.to_payload(bits=hidden_activation_bits),
        "output_product": output_product_bounds.to_payload(bits=output_product_bits),
        "output_accumulator": output_accumulator.to_payload(bits=accumulator_bits),
    }
