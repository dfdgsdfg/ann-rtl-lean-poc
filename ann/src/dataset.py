from __future__ import annotations

from dataclasses import dataclass
import json
import random
from pathlib import Path

try:
    from .model import infer, score
    from .teacher import TEACHER_SOURCE, TEACHER_VERSION, teacher_payload
except ImportError:
    from model import infer, score
    from teacher import TEACHER_SOURCE, TEACHER_VERSION, teacher_payload

DATASET_VERSION = TEACHER_VERSION
DEFAULT_DATASET_SEED = 20260312
DEFAULT_INPUT_LOW = -16
DEFAULT_INPUT_HIGH = 15
DEFAULT_TRAIN_SIZE = 512
DEFAULT_VAL_SIZE = 128


@dataclass(frozen=True)
class Example:
    inputs: tuple[int, int, int, int]
    label: int
    teacher_score: int
    split: str

    def to_json(self) -> str:
        return json.dumps(
            {
                "inputs": list(self.inputs),
                "label": self.label,
                "teacher_score": self.teacher_score,
                "split": self.split,
            },
            sort_keys=True,
        )


def _generate_split(
    rng: random.Random,
    count: int,
    split: str,
    input_low: int,
    input_high: int,
    global_seen: set[tuple[int, int, int, int]],
) -> list[Example]:
    if count < 0:
        raise ValueError(f"{split} split size must be non-negative, got {count}")
    if count == 0:
        return []

    teacher = teacher_payload()
    target_zero = count // 2
    target_one = count - target_zero
    buckets: dict[int, list[Example]] = {0: [], 1: []}
    seen: set[tuple[int, int, int, int]] = set()
    attempts = 0
    max_attempts = max(1000, count * 200)

    while len(buckets[0]) < target_zero or len(buckets[1]) < target_one:
        attempts += 1
        if attempts > max_attempts:
            raise ValueError(
                f"unable to build {split} split with balanced labels after {max_attempts} attempts; "
                f"requested={count} collected_zero={len(buckets[0])} collected_one={len(buckets[1])}"
            )
        candidate = tuple(rng.randint(input_low, input_high) for _ in range(4))
        if candidate in seen or candidate in global_seen:
            continue
        label = infer(candidate, weights=teacher)
        target = target_zero if label == 0 else target_one
        if len(buckets[label]) >= target:
            continue
        seen.add(candidate)
        global_seen.add(candidate)
        buckets[label].append(
            Example(
                inputs=candidate,
                label=label,
                teacher_score=score(candidate, weights=teacher),
                split=split,
            )
        )

    examples = buckets[0] + buckets[1]
    rng.shuffle(examples)
    return examples


def build_dataset(
    seed: int = DEFAULT_DATASET_SEED,
    train_size: int = DEFAULT_TRAIN_SIZE,
    val_size: int = DEFAULT_VAL_SIZE,
    input_low: int = DEFAULT_INPUT_LOW,
    input_high: int = DEFAULT_INPUT_HIGH,
) -> dict[str, object]:
    if input_low > input_high:
        raise ValueError(f"input_low must be <= input_high, got {input_low} > {input_high}")
    if train_size < 0 or val_size < 0:
        raise ValueError("train_size and val_size must be non-negative")

    range_size = input_high - input_low + 1
    max_unique_inputs = range_size**4
    if train_size + val_size > max_unique_inputs:
        raise ValueError(
            "requested dataset is larger than the available unique input space: "
            f"{train_size + val_size} > {max_unique_inputs}"
        )

    rng = random.Random(seed)
    global_seen: set[tuple[int, int, int, int]] = set()
    train_examples = _generate_split(rng, train_size, "train", input_low, input_high, global_seen)
    val_examples = _generate_split(rng, val_size, "val", input_low, input_high, global_seen)
    return {
        "metadata": {
            "version": DATASET_VERSION,
            "seed": seed,
            "train_size": train_size,
            "val_size": val_size,
            "input_low": input_low,
            "input_high": input_high,
            "teacher_source": TEACHER_SOURCE,
            "label_balance": "balanced_per_split",
        },
        "train": train_examples,
        "val": val_examples,
    }


def write_snapshot(path: Path, examples: list[Example]) -> None:
    path.write_text("\n".join(example.to_json() for example in examples) + "\n", encoding="utf-8")
