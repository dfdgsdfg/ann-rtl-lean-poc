from __future__ import annotations

import argparse
from copy import deepcopy
from math import exp, log1p, sqrt
import random
from pathlib import Path

try:
    from .artifacts import default_run_dir, display_path, ensure_dir, write_json
    from .dataset import (
        DEFAULT_DATASET_SEED,
        DEFAULT_TRAIN_SIZE,
        DEFAULT_VAL_SIZE,
        build_dataset,
        write_snapshot,
    )
    from .model import infer, score
    from .params import HIDDEN_SIZE, INPUT_SIZE
    from .quantize import assert_signed_range, quantize_matrix, quantize_vector, relu, wrap_signed
except ImportError:
    from artifacts import default_run_dir, display_path, ensure_dir, write_json
    from dataset import (
        DEFAULT_DATASET_SEED,
        DEFAULT_TRAIN_SIZE,
        DEFAULT_VAL_SIZE,
        build_dataset,
        write_snapshot,
    )
    from model import infer, score
    from params import HIDDEN_SIZE, INPUT_SIZE
    from quantize import assert_signed_range, quantize_matrix, quantize_vector, relu, wrap_signed
DEFAULT_EPOCHS = 300
DEFAULT_LEARNING_RATE = 1e-2
DEFAULT_PATIENCE = 20
DEFAULT_BATCH_SIZE = 64
DEFAULT_INIT_NOISE = 1.5
DEFAULT_REGULARIZATION = 1e-4


def add_train_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--seed", type=int, default=DEFAULT_DATASET_SEED)
    parser.add_argument("--train-size", type=int, default=DEFAULT_TRAIN_SIZE)
    parser.add_argument("--val-size", type=int, default=DEFAULT_VAL_SIZE)
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--learning-rate", type=float, default=DEFAULT_LEARNING_RATE)
    parser.add_argument("--patience", type=int, default=DEFAULT_PATIENCE)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--init-noise", type=float, default=DEFAULT_INIT_NOISE)
    parser.add_argument("--regularization", type=float, default=DEFAULT_REGULARIZATION)
    parser.add_argument("--out-dir", type=Path, default=None, help="Output directory for this training run")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the toy ANN and export the selected result")
    add_train_arguments(parser)
    return parser.parse_args(argv)


def sigmoid(logit: float) -> float:
    if logit >= 0:
        z = exp(-logit)
        return 1.0 / (1.0 + z)
    z = exp(logit)
    return z / (1.0 + z)


def bce_with_logits(logit: float, label: int) -> float:
    if logit >= 0:
        return (1 - label) * logit + log1p(exp(-logit))
    return -label * logit + log1p(exp(logit))


def clone_params(params: dict[str, object]) -> dict[str, object]:
    return {
        "w1": [list(row) for row in params["w1"]],
        "b1": list(params["b1"]),
        "w2": list(params["w2"]),
        "b2": params["b2"],
    }


def init_float_params(seed: int, noise_scale: float) -> dict[str, object]:
    rng = random.Random(seed + 17)
    params = zero_state()
    for i in range(HIDDEN_SIZE):
        for j in range(INPUT_SIZE):
            params["w1"][i][j] = rng.uniform(-noise_scale, noise_scale)
        params["b1"][i] = rng.uniform(-noise_scale, noise_scale)
        params["w2"][i] = rng.uniform(-noise_scale, noise_scale)
    params["b2"] = rng.uniform(-noise_scale, noise_scale)
    return params


def zero_grads() -> dict[str, object]:
    return {
        "w1": [[0.0 for _ in range(INPUT_SIZE)] for _ in range(HIDDEN_SIZE)],
        "b1": [0.0 for _ in range(HIDDEN_SIZE)],
        "w2": [0.0 for _ in range(HIDDEN_SIZE)],
        "b2": 0.0,
    }


def zero_state() -> dict[str, object]:
    return {
        "w1": [[0.0 for _ in range(INPUT_SIZE)] for _ in range(HIDDEN_SIZE)],
        "b1": [0.0 for _ in range(HIDDEN_SIZE)],
        "w2": [0.0 for _ in range(HIDDEN_SIZE)],
        "b2": 0.0,
    }


def require_examples(examples: list[object], *, context: str) -> None:
    if len(examples) == 0:
        raise ValueError(f"{context} requires at least one example")


def forward_float(inputs: tuple[int, int, int, int], params: dict[str, object]) -> tuple[list[float], list[float], float]:
    pre_hidden: list[float] = []
    hidden: list[float] = []
    for i in range(HIDDEN_SIZE):
        acc = params["b1"][i]
        for j in range(INPUT_SIZE):
            acc += params["w1"][i][j] * inputs[j]
        pre_hidden.append(acc)
        hidden.append(acc if acc > 0 else 0.0)

    logit = params["b2"]
    for i in range(HIDDEN_SIZE):
        logit += params["w2"][i] * hidden[i]
    return pre_hidden, hidden, logit


def forward_qat(inputs: tuple[int, int, int, int], params: dict[str, object]) -> tuple[dict[str, object], list[int], list[int], int]:
    quantized = quantized_from_float(params)
    pre_hidden: list[int] = []
    hidden: list[int] = []
    for i in range(HIDDEN_SIZE):
        acc = 0
        for j in range(INPUT_SIZE):
            product = wrap_signed(inputs[j] * quantized["w1"][i][j], 16)
            acc = wrap_signed(acc + product, 32)
        acc = wrap_signed(acc + quantized["b1"][i], 32)
        pre_hidden.append(acc)
        hidden.append(wrap_signed(relu(acc), 16))

    acc = 0
    for i in range(HIDDEN_SIZE):
        product = wrap_signed(hidden[i] * quantized["w2"][i], 24)
        acc = wrap_signed(acc + product, 32)
    logit = wrap_signed(acc + quantized["b2"], 32)
    return quantized, pre_hidden, hidden, logit


def quantized_from_float(params: dict[str, object]) -> dict[str, object]:
    quantized = {
        "w1": quantize_matrix(params["w1"], bits=8),
        "b1": quantize_vector(params["b1"], bits=32),
        "w2": quantize_vector(params["w2"], bits=8),
        "b2": quantize_vector([params["b2"]], bits=32)[0],
    }
    assert_signed_range((value for row in quantized["w1"] for value in row), 8, "W1")
    assert_signed_range(quantized["w2"], 8, "W2")
    assert_signed_range(quantized["b1"], 32, "b1")
    assert_signed_range([quantized["b2"]], 32, "b2")
    return quantized


def evaluate_float(examples: list[object], params: dict[str, object]) -> dict[str, float]:
    require_examples(examples, context="float evaluation")
    total_loss = 0.0
    correct = 0
    for example in examples:
        _, _, logit = forward_float(example.inputs, params)
        total_loss += bce_with_logits(logit, example.label)
        prediction = 1 if logit > 0 else 0
        if prediction == example.label:
            correct += 1
    return {
        "loss": total_loss / len(examples),
        "accuracy": correct / len(examples),
    }


def evaluate_quantized(examples: list[object], quantized: dict[str, object]) -> dict[str, float]:
    require_examples(examples, context="quantized evaluation")
    total_loss = 0.0
    correct = 0
    for example in examples:
        logit = score(example.inputs, weights=quantized)
        total_loss += bce_with_logits(float(logit), example.label)
        prediction = infer(example.inputs, weights=quantized)
        if prediction == example.label:
            correct += 1
    return {
        "loss": total_loss / len(examples),
        "accuracy": correct / len(examples),
    }


def quantized_l1(quantized: dict[str, object]) -> int:
    magnitude = abs(quantized["b2"])
    for i in range(HIDDEN_SIZE):
        magnitude += abs(quantized["b1"][i]) + abs(quantized["w2"][i])
        for j in range(INPUT_SIZE):
            magnitude += abs(quantized["w1"][i][j])
    return magnitude


def is_better_candidate(
    current_metrics: dict[str, float],
    current_quantized: dict[str, object],
    best_metrics: dict[str, float] | None,
    best_quantized: dict[str, object] | None,
) -> bool:
    if best_metrics is None or best_quantized is None:
        return True

    if current_metrics["val_quant_accuracy"] != best_metrics["val_quant_accuracy"]:
        return current_metrics["val_quant_accuracy"] > best_metrics["val_quant_accuracy"]

    if current_metrics["val_quant_loss"] != best_metrics["val_quant_loss"]:
        return current_metrics["val_quant_loss"] < best_metrics["val_quant_loss"]

    return quantized_l1(current_quantized) < quantized_l1(best_quantized)


def batch_indices(sample_count: int, batch_size: int) -> list[tuple[int, int]]:
    if batch_size <= 0:
        raise ValueError("batch_size must be positive")
    return [
        (start, min(start + batch_size, sample_count))
        for start in range(0, sample_count, batch_size)
    ]


def write_markdown_summary(path: Path, summary: dict[str, object]) -> None:
    lines = [
        "# Training Summary",
        "",
        f"- dataset version: `{summary['dataset_version']}`",
        f"- dataset seed: `{summary['dataset_seed']}`",
        f"- train / val size: `{summary['train_size']}` / `{summary['val_size']}`",
        f"- epochs run: `{summary['epochs_ran']}`",
        f"- selected epoch: `{summary['selected_epoch']}`",
        f"- selected source: `{summary['selected_source']}`",
        f"- selected float shadow: `{summary['selected_float_shadow_source']}`",
        f"- best float source: `{summary['best_float_source']}`",
        f"- val quant accuracy: `{summary['val_quant_accuracy']:.4f}`",
        f"- val quant loss: `{summary['val_quant_loss']:.6f}`",
        f"- selected shadow float accuracy: `{summary['selected_shadow_float_accuracy']:.4f}`",
        f"- best float accuracy: `{summary['best_float_accuracy']:.4f}`",
        f"- quantized L1: `{summary['quantized_l1']}`",
        "",
        "The selected checkpoint is chosen from quantized validation metrics first,",
        "with quantized `L1` magnitude used as the final tie-breaker.",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def train(args: argparse.Namespace) -> Path:
    if args.train_size <= 0 or args.val_size <= 0:
        raise ValueError(
            "train requires non-empty train and val splits; "
            f"got train_size={args.train_size}, val_size={args.val_size}"
        )

    run_dir = args.out_dir if args.out_dir is not None else default_run_dir(args.seed)
    if args.out_dir is None and run_dir.exists():
        raise FileExistsError(f"default immutable run directory already exists: {run_dir}")
    ensure_dir(run_dir)

    dataset = build_dataset(
        seed=args.seed,
        train_size=args.train_size,
        val_size=args.val_size,
    )
    train_examples = dataset["train"]
    val_examples = dataset["val"]
    all_examples = train_examples + val_examples

    write_snapshot(run_dir / "dataset_snapshot.jsonl", all_examples)

    params = init_float_params(args.seed, args.init_noise)
    best_quantized: dict[str, object] | None = None
    best_metrics: dict[str, float] | None = None
    best_epoch = 0
    best_float_shadow_params = deepcopy(params)
    best_float_shadow_metrics: dict[str, float] | None = None
    best_float_epoch = 0
    best_float_params = deepcopy(params)
    patience_counter = 0
    history: list[dict[str, float]] = []

    m_state = zero_state()
    v_state = zero_state()
    beta1 = 0.9
    beta2 = 0.999
    epsilon = 1e-8
    update_step = 0
    batches = batch_indices(len(train_examples), args.batch_size)
    shuffle_rng = random.Random(args.seed + 101)

    for epoch in range(args.epochs + 1):
        float_train = evaluate_float(train_examples, params)
        float_val = evaluate_float(val_examples, params)
        quantized = quantized_from_float(params)
        quant_train = evaluate_quantized(train_examples, quantized)
        quant_val = evaluate_quantized(val_examples, quantized)

        metrics = {
            "epoch": float(epoch),
            "train_float_loss": float_train["loss"],
            "train_float_accuracy": float_train["accuracy"],
            "val_float_loss": float_val["loss"],
            "val_float_accuracy": float_val["accuracy"],
            "train_quant_loss": quant_train["loss"],
            "train_quant_accuracy": quant_train["accuracy"],
            "val_quant_loss": quant_val["loss"],
            "val_quant_accuracy": quant_val["accuracy"],
        }
        history.append(metrics)

        if best_float_shadow_metrics is None:
            best_float_shadow_metrics = metrics
            best_float_epoch = epoch
            best_float_params = deepcopy(params)
        else:
            if metrics["val_float_accuracy"] != best_float_shadow_metrics["val_float_accuracy"]:
                is_better_float = metrics["val_float_accuracy"] > best_float_shadow_metrics["val_float_accuracy"]
            else:
                is_better_float = metrics["val_float_loss"] < best_float_shadow_metrics["val_float_loss"]
            if is_better_float:
                best_float_shadow_metrics = metrics
                best_float_epoch = epoch
                best_float_params = deepcopy(params)

        if is_better_candidate(metrics, quantized, best_metrics, best_quantized):
            best_quantized = deepcopy(quantized)
            best_metrics = metrics
            best_epoch = epoch
            best_float_shadow_params = deepcopy(params)
            patience_counter = 0
        else:
            patience_counter += 1

        if epoch == args.epochs or patience_counter >= args.patience:
            break

        shuffled_examples = list(train_examples)
        shuffle_rng.shuffle(shuffled_examples)

        for start, stop in batches:
            grads = zero_grads()
            batch_examples = shuffled_examples[start:stop]

            for example in batch_examples:
                quantized, pre_hidden, hidden, logit = forward_qat(example.inputs, params)
                dlogit = sigmoid(float(logit)) - example.label

                grads["b2"] += dlogit
                for i in range(HIDDEN_SIZE):
                    grads["w2"][i] += dlogit * hidden[i]

                for i in range(HIDDEN_SIZE):
                    da = dlogit * quantized["w2"][i]
                    if pre_hidden[i] <= 0:
                        da = 0.0
                    grads["b1"][i] += da
                    for j in range(INPUT_SIZE):
                        grads["w1"][i][j] += da * example.inputs[j]

            normalizer = float(len(batch_examples))
            update_step += 1
            for i in range(HIDDEN_SIZE):
                for j in range(INPUT_SIZE):
                    grads["w1"][i][j] = grads["w1"][i][j] / normalizer + args.regularization * params["w1"][i][j]
                    m_state["w1"][i][j] = beta1 * m_state["w1"][i][j] + (1.0 - beta1) * grads["w1"][i][j]
                    v_state["w1"][i][j] = beta2 * v_state["w1"][i][j] + (1.0 - beta2) * grads["w1"][i][j] ** 2
                    m_hat = m_state["w1"][i][j] / (1.0 - beta1**update_step)
                    v_hat = v_state["w1"][i][j] / (1.0 - beta2**update_step)
                    params["w1"][i][j] -= args.learning_rate * m_hat / (sqrt(v_hat) + epsilon)

                grads["b1"][i] = grads["b1"][i] / normalizer + args.regularization * params["b1"][i]
                m_state["b1"][i] = beta1 * m_state["b1"][i] + (1.0 - beta1) * grads["b1"][i]
                v_state["b1"][i] = beta2 * v_state["b1"][i] + (1.0 - beta2) * grads["b1"][i] ** 2
                m_hat_b1 = m_state["b1"][i] / (1.0 - beta1**update_step)
                v_hat_b1 = v_state["b1"][i] / (1.0 - beta2**update_step)
                params["b1"][i] -= args.learning_rate * m_hat_b1 / (sqrt(v_hat_b1) + epsilon)

                grads["w2"][i] = grads["w2"][i] / normalizer + args.regularization * params["w2"][i]
                m_state["w2"][i] = beta1 * m_state["w2"][i] + (1.0 - beta1) * grads["w2"][i]
                v_state["w2"][i] = beta2 * v_state["w2"][i] + (1.0 - beta2) * grads["w2"][i] ** 2
                m_hat_w2 = m_state["w2"][i] / (1.0 - beta1**update_step)
                v_hat_w2 = v_state["w2"][i] / (1.0 - beta2**update_step)
                params["w2"][i] -= args.learning_rate * m_hat_w2 / (sqrt(v_hat_w2) + epsilon)

            grads["b2"] = grads["b2"] / normalizer + args.regularization * params["b2"]
            m_state["b2"] = beta1 * m_state["b2"] + (1.0 - beta1) * grads["b2"]
            v_state["b2"] = beta2 * v_state["b2"] + (1.0 - beta2) * grads["b2"] ** 2
            m_hat_b2 = m_state["b2"] / (1.0 - beta1**update_step)
            v_hat_b2 = v_state["b2"] / (1.0 - beta2**update_step)
            params["b2"] -= args.learning_rate * m_hat_b2 / (sqrt(v_hat_b2) + epsilon)

    assert best_quantized is not None
    assert best_metrics is not None
    assert best_float_shadow_metrics is not None

    weights_float_payload = {
        "schema_version": 1,
        "source": "trained_float_best",
        "selection_mode": "float_validation",
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "training_seed": args.seed,
        "dataset_version": dataset["metadata"]["version"],
        "selected_epoch": best_float_epoch,
        "w1": [list(row) for row in best_float_params["w1"]],
        "b1": list(best_float_params["b1"]),
        "w2": list(best_float_params["w2"]),
        "b2": best_float_params["b2"],
    }
    write_json(run_dir / "weights_float.json", weights_float_payload)

    weights_float_selected_payload = {
        "schema_version": 1,
        "source": "trained_float_selected_shadow",
        "selection_mode": "quantized_validation_shadow",
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "training_seed": args.seed,
        "dataset_version": dataset["metadata"]["version"],
        "selected_epoch": best_epoch,
        "w1": [list(row) for row in best_float_shadow_params["w1"]],
        "b1": list(best_float_shadow_params["b1"]),
        "w2": list(best_float_shadow_params["w2"]),
        "b2": best_float_shadow_params["b2"],
    }
    write_json(run_dir / "weights_float_selected.json", weights_float_selected_payload)

    weights_quantized_payload = {
        "schema_version": 1,
        "source": "trained_quantized_selected",
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "training_seed": args.seed,
        "dataset_version": dataset["metadata"]["version"],
        "selected_epoch": best_epoch,
        "w1": best_quantized["w1"],
        "b1": best_quantized["b1"],
        "w2": best_quantized["w2"],
        "b2": best_quantized["b2"],
    }
    write_json(run_dir / "weights_quantized.json", weights_quantized_payload)

    metrics_payload = {
        "schema_version": 1,
        "dataset": dataset["metadata"],
        "training": {
            "seed": args.seed,
            "epochs_requested": args.epochs,
            "epochs_ran": int(history[-1]["epoch"]),
            "batch_size": args.batch_size,
            "learning_rate": args.learning_rate,
            "patience": args.patience,
            "init_noise": args.init_noise,
            "regularization": args.regularization,
            "optimizer": "adam_minibatch_qat_ste",
            "initialization": "random_uniform",
        },
        "selected": {
            "epoch": best_epoch,
            "quantized_l1": quantized_l1(best_quantized),
            "shadow_train_float_accuracy": best_metrics["train_float_accuracy"],
            "shadow_val_float_accuracy": best_metrics["val_float_accuracy"],
            "train_quant_accuracy": best_metrics["train_quant_accuracy"],
            "val_quant_accuracy": best_metrics["val_quant_accuracy"],
            "shadow_train_float_loss": best_metrics["train_float_loss"],
            "shadow_val_float_loss": best_metrics["val_float_loss"],
            "train_quant_loss": best_metrics["train_quant_loss"],
            "val_quant_loss": best_metrics["val_quant_loss"],
        },
        "best_float": {
            "epoch": best_float_epoch,
            "train_accuracy": best_float_shadow_metrics["train_float_accuracy"],
            "val_accuracy": best_float_shadow_metrics["val_float_accuracy"],
            "train_loss": best_float_shadow_metrics["train_float_loss"],
            "val_loss": best_float_shadow_metrics["val_float_loss"],
        },
        "history": history,
    }
    write_json(run_dir / "metrics.json", metrics_payload)

    write_markdown_summary(
        run_dir / "training_summary.md",
        {
            "dataset_version": dataset["metadata"]["version"],
            "dataset_seed": args.seed,
            "train_size": args.train_size,
            "val_size": args.val_size,
            "epochs_ran": int(history[-1]["epoch"]),
            "selected_epoch": best_epoch,
            "selected_source": display_path(run_dir / "weights_quantized.json"),
            "selected_float_shadow_source": display_path(run_dir / "weights_float_selected.json"),
            "best_float_source": display_path(run_dir / "weights_float.json"),
            "val_quant_accuracy": best_metrics["val_quant_accuracy"],
            "val_quant_loss": best_metrics["val_quant_loss"],
            "selected_shadow_float_accuracy": best_metrics["val_float_accuracy"],
            "best_float_accuracy": best_float_shadow_metrics["val_float_accuracy"],
            "quantized_l1": quantized_l1(best_quantized),
        },
    )

    return run_dir


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    run_dir = train(args)
    print(f"wrote training artifacts to {run_dir}")


if __name__ == "__main__":
    main()
