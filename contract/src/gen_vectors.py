from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from itertools import product
from pathlib import Path
from typing import Iterable, Sequence

from .artifacts import CONTRACT_WEIGHTS_PATH, ROOT
from .params import HIDDEN_SIZE, INPUT_SIZE
from .quantize_helpers import relu, wrap_signed
from .schema import coerce_weights_payload

TEST_VECTORS_PATH = ROOT / "simulations" / "shared" / "test_vectors.mem"
TEST_VECTORS_META_PATH = ROOT / "simulations" / "shared" / "test_vectors_meta.svh"
VECTOR_HEX_WIDTH = 17

SMOKE_VECTORS = (
    (-8, -3, 2, 1),
    (7, -2, 3, -1),
    (12, 6, -5, -2),
    (-4, 9, -3, 7),
    (0, 0, 0, 0),
    (15, -16, 12, -8),
    (-32, 31, -7, 9),
    (63, -12, 5, -1),
    (-11, -9, 14, 8),
    (20, 2, -18, 3),
    (-64, 5, 33, -17),
    (19, -21, 11, 4),
    (-7, 4, -12, 13),
)
ARITHMETIC_BOUNDARY_VALUES = (-128, -127, 127)
SEARCH_VALUES = (-128, -127, -64, -32, -16, -8, -4, -2, -1, 0, 1, 2, 4, 8, 16, 32, 64, 127)
EXTREME_COMBINATION_VECTORS = (
    (-128, -128, -128, -128),
    (-127, -127, -127, -127),
    (127, 127, 127, 127),
    (-128, 127, -128, 127),
    (127, -128, 127, -128),
    (-128, -128, 127, 127),
    (127, 127, -128, -128),
)
WITNESS_CLASSES = ("positive", "zero", "negative")


@dataclass(frozen=True)
class ScoreTrace:
    score: int
    hidden_pre_activations: tuple[int, ...]
    output_mac_partials: tuple[int, ...]


@dataclass(frozen=True)
class CandidatePoolAnalysis:
    score_witnesses: dict[str, tuple[int, int, int, int]]
    max_score_vector: tuple[int, int, int, int]
    min_score_vector: tuple[int, int, int, int]
    hidden_pre_max_vectors: tuple[tuple[int, int, int, int], ...]
    hidden_pre_min_vectors: tuple[tuple[int, int, int, int], ...]
    output_partial_max_vectors: tuple[tuple[int, int, int, int], ...]
    output_partial_min_vectors: tuple[tuple[int, int, int, int], ...]


def _normalize_input(values: Iterable[int]) -> tuple[int, int, int, int]:
    data = tuple(wrap_signed(v, 8) for v in values)
    if len(data) != INPUT_SIZE:
        raise ValueError(f"expected {INPUT_SIZE} inputs, got {len(data)}")
    return data  # type: ignore[return-value]


def _score(values: Sequence[int], weights: dict[str, object]) -> int:
    return _score_trace(values, weights=weights).score


def _score_trace(values: Sequence[int], weights: dict[str, object]) -> ScoreTrace:
    xs = _normalize_input(values)
    w1 = weights["w1"]
    b1 = weights["b1"]
    hidden: list[int] = []
    hidden_pre_activations: list[int] = []
    for i in range(HIDDEN_SIZE):
        acc = 0
        for j in range(INPUT_SIZE):
            product = wrap_signed(xs[j] * w1[i][j], 16)
            acc = wrap_signed(acc + product, 32)
        acc = wrap_signed(acc + b1[i], 32)
        hidden_pre_activations.append(acc)
        hidden.append(wrap_signed(relu(acc), 16))

    w2 = weights["w2"]
    b2 = weights["b2"]
    acc = 0
    output_mac_partials: list[int] = []
    for i in range(HIDDEN_SIZE):
        product = wrap_signed(hidden[i] * w2[i], 24)
        acc = wrap_signed(acc + product, 32)
        output_mac_partials.append(acc)
    return ScoreTrace(
        score=wrap_signed(acc + b2, 32),
        hidden_pre_activations=tuple(hidden_pre_activations),
        output_mac_partials=tuple(output_mac_partials),
    )


def _pack_vector(values: Sequence[int], score: int) -> int:
    xs = _normalize_input(values)
    expected = int(score > 0)
    word = wrap_signed(score, 32) & 0xFFFFFFFF
    word = (word << 1) | (expected & 0x1)
    for value in xs:
        word = (word << 8) | (value & 0xFF)
    return word


def _score_class(score: int) -> str:
    if score > 0:
        return "positive"
    if score == 0:
        return "zero"
    return "negative"


def _update_extremum(
    current: tuple[int, tuple[int, int, int, int]] | None,
    candidate_value: int,
    candidate_vector: tuple[int, int, int, int],
    *,
    prefer_max: bool,
) -> tuple[int, tuple[int, int, int, int]]:
    if current is None:
        return (candidate_value, candidate_vector)
    current_value, _ = current
    if prefer_max:
        if candidate_value > current_value:
            return (candidate_value, candidate_vector)
    elif candidate_value < current_value:
        return (candidate_value, candidate_vector)
    return current


def _analyze_candidate_pool(weights: dict[str, object]) -> CandidatePoolAnalysis:
    witnesses: dict[str, tuple[int, int, int, int]] = {}
    max_score: tuple[int, tuple[int, int, int, int]] | None = None
    min_score: tuple[int, tuple[int, int, int, int]] | None = None
    hidden_pre_max: list[tuple[int, tuple[int, int, int, int]] | None] = [None] * HIDDEN_SIZE
    hidden_pre_min: list[tuple[int, tuple[int, int, int, int]] | None] = [None] * HIDDEN_SIZE
    output_partial_max: list[tuple[int, tuple[int, int, int, int]] | None] = [None] * HIDDEN_SIZE
    output_partial_min: list[tuple[int, tuple[int, int, int, int]] | None] = [None] * HIDDEN_SIZE

    for candidate in product(SEARCH_VALUES, repeat=INPUT_SIZE):
        vector = _normalize_input(candidate)
        trace = _score_trace(vector, weights=weights)
        score_class = _score_class(trace.score)
        witnesses.setdefault(score_class, vector)
        max_score = _update_extremum(max_score, trace.score, vector, prefer_max=True)
        min_score = _update_extremum(min_score, trace.score, vector, prefer_max=False)

        for idx, value in enumerate(trace.hidden_pre_activations):
            hidden_pre_max[idx] = _update_extremum(hidden_pre_max[idx], value, vector, prefer_max=True)
            hidden_pre_min[idx] = _update_extremum(hidden_pre_min[idx], value, vector, prefer_max=False)
        for idx, value in enumerate(trace.output_mac_partials):
            output_partial_max[idx] = _update_extremum(output_partial_max[idx], value, vector, prefer_max=True)
            output_partial_min[idx] = _update_extremum(output_partial_min[idx], value, vector, prefer_max=False)

    for target_class in WITNESS_CLASSES:
        if target_class not in witnesses:
            raise ValueError(
                "unable to synthesize required score-class witnesses "
                f"for {target_class} from the deterministic candidate pool"
            )

    if max_score is None or min_score is None:
        raise ValueError("deterministic candidate pool produced no vectors")

    return CandidatePoolAnalysis(
        score_witnesses=witnesses,
        max_score_vector=max_score[1],
        min_score_vector=min_score[1],
        hidden_pre_max_vectors=tuple(entry[1] for entry in hidden_pre_max if entry is not None),
        hidden_pre_min_vectors=tuple(entry[1] for entry in hidden_pre_min if entry is not None),
        output_partial_max_vectors=tuple(entry[1] for entry in output_partial_max if entry is not None),
        output_partial_min_vectors=tuple(entry[1] for entry in output_partial_min if entry is not None),
    )


def _build_boundary_vectors() -> tuple[tuple[int, int, int, int], ...]:
    vectors: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)]
    vectors.extend(EXTREME_COMBINATION_VECTORS)
    for lane in range(INPUT_SIZE):
        for value in ARITHMETIC_BOUNDARY_VALUES:
            sample = [0] * INPUT_SIZE
            sample[lane] = value
            vectors.append(tuple(sample))
    return tuple(vectors)


def _append_unique(
    vectors: list[tuple[int, int, int, int]],
    seen: set[tuple[int, int, int, int]],
    vector: Sequence[int],
) -> None:
    normalized = _normalize_input(vector)
    if normalized in seen:
        return
    seen.add(normalized)
    vectors.append(normalized)


def validate_witness_coverage(weights: dict[str, object]) -> None:
    _analyze_candidate_pool(weights)


def _load_contract_weights() -> dict[str, object]:
    if not CONTRACT_WEIGHTS_PATH.exists():
        raise FileNotFoundError(f"missing contract weights file: {CONTRACT_WEIGHTS_PATH}")
    return coerce_weights_payload(
        json.loads(CONTRACT_WEIGHTS_PATH.read_text(encoding="utf-8")),
        label="contract weights",
    )


def _build_scored_vectors(weights: dict[str, object]) -> tuple[tuple[tuple[int, int, int, int], int], ...]:
    analysis = _analyze_candidate_pool(weights)
    ordered_vectors: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()

    for vector in SMOKE_VECTORS:
        _append_unique(ordered_vectors, seen, vector)
    for vector in _build_boundary_vectors():
        _append_unique(ordered_vectors, seen, vector)
    for vector in (
        analysis.max_score_vector,
        analysis.min_score_vector,
        *analysis.hidden_pre_max_vectors,
        *analysis.hidden_pre_min_vectors,
        *analysis.output_partial_max_vectors,
        *analysis.output_partial_min_vectors,
    ):
        _append_unique(ordered_vectors, seen, vector)
    for witness_class in WITNESS_CLASSES:
        _append_unique(ordered_vectors, seen, analysis.score_witnesses[witness_class])
    return tuple((vector, _score(vector, weights=weights)) for vector in ordered_vectors)


def render_vectors(weights: dict[str, object]) -> str:
    lines = []
    for vector, score in _build_scored_vectors(weights):
        lines.append(f"{_pack_vector(vector, score):0{VECTOR_HEX_WIDTH}x}")
    return "\n".join(lines) + "\n"


def render_vector_meta(weights: dict[str, object]) -> str:
    vector_count = len(_build_scored_vectors(weights))
    return (
        "// Generated by contract.src.gen_vectors. Do not edit.\n"
        f"localparam int NUM_VECTORS = {vector_count};\n"
    )


def expected_vector_artifacts(weights: dict[str, object]) -> dict[Path, str]:
    return {
        TEST_VECTORS_PATH: render_vectors(weights),
        TEST_VECTORS_META_PATH: render_vector_meta(weights),
    }


def _write_if_changed(out_path: Path, text: str) -> None:
    if out_path.exists() and out_path.read_text(encoding="ascii") == text:
        return
    out_path.write_text(text, encoding="ascii")


def generate_vectors() -> Path:
    weights = _load_contract_weights()
    for out_path, text in expected_vector_artifacts(weights).items():
        _write_if_changed(out_path, text)
    return TEST_VECTORS_PATH


def check_witness_coverage() -> None:
    weights = _load_contract_weights()
    validate_witness_coverage(weights)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or validate RTL test vectors")
    parser.add_argument(
        "--check-witnesses",
        action="store_true",
        help="Validate that the deterministic candidate pool can synthesize positive/zero/negative score witnesses",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.check_witnesses:
        check_witness_coverage()
        print("witness coverage validation passed")
        return

    out_path = generate_vectors()
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
