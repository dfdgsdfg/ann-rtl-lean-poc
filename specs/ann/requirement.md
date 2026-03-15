# ANN Requirements

## 1. Purpose

This document defines the requirements for creating the artificial neural network used by the Tiny Neural Inference ASIC.

The `ann` domain covers:

- Model definition
- Actual model training
- Training results and evaluation artifacts
- Quantization
- Dataset and reproducibility inputs

The `ann` domain does not own downstream artifact generation or contract freezing. Those responsibilities belong to the `contract` domain. The boundary between the two domains is the file system: `ann` writes training results to `ann/results/`, and `contract` reads them.

Application or CLI layers may orchestrate `ann` and `contract` commands together for user convenience. This does not change domain ownership: the boundary above still applies to domain implementation code.

## 2. Model Requirements

The ANN must match the hardware-targeted MLP shape:

- Input dimension: `4`
- Hidden dimension: `8`
- Output dimension: `1`
- Hidden activation: `ReLU`
- Final decision rule: `y > 0`

The ANN creation flow must produce parameters compatible with the hardware inference specification.

## 3. Training Requirements

The project must include an actual ANN training flow, not only handcrafted parameters.

The training flow must:

- Train a toy ANN from a defined dataset or generated dataset
- Produce a final trained parameter set for the target `4 -> 8 -> 1` MLP
- Be reproducible through committed scripts and documented commands
- Record enough information to regenerate the same or equivalent result

The parameter generation flow must produce trained values for:

- First-layer weights `W1[8][4]`
- First-layer biases `b1[8]`
- Second-layer weights `W2[8]`
- Output bias `b2`

The training flow must also record:

- Dataset source or generation method
- Training seed or determinism strategy
- Hyperparameters used for training
- Final training metrics

The ANN domain must expose a simple CLI or equivalent scriptable entry points for:

- Training
- Evaluating a trained result
- Quantizing the selected result
- Exporting the selected result for downstream use

## 4. Training Result Requirements

The ANN domain must produce concrete training results that downstream domains can consume.

Required result artifacts include:

- Final floating-point or high-precision trained parameters
- Quantized parameter set used by hardware-facing flows
- Evaluation metrics for the trained model
- A machine-readable export of weights and biases
- A short human-readable summary of the selected result

Recommended result details include:

- Training accuracy or loss
- Validation accuracy or loss if a validation split exists
- Confusion summary or classification summary for the toy task
- Notes on why the chosen checkpoint or final epoch was selected

## 5. Quantization Requirements

The ANN flow must convert parameters into signed integer values compatible with the hardware datapath.

Quantization requirements:

- Weights must be representable as `int8`
- Inputs assumed by generated test vectors must be representable as `int8`
- Biases must be exportable in a form compatible with `int32`
- The quantization method must be documented

If scaling factors are used during training or export, the flow must document how they are applied and how they map to RTL and reference inference.

## 6. Export Requirements

The ANN domain must export its training results in a format that the `contract` domain can consume.

Required exports:

- Quantized weights JSON (`weights_quantized.json`)
- Float weights JSON for the best float checkpoint and the quantized-selected shadow
- Training metrics JSON
- Human-readable training summary
- Dataset snapshot

These exports live in `ann/results/` and are the ANN domain's output boundary. The `contract` domain is responsible for reading these files, freezing them into a canonical contract, and generating downstream artifacts for RTL, Lean, and simulation.

## 7. Reproducibility Requirements

The ANN flow must be reproducible from committed code and documented commands.

At minimum, the repository should be able to answer:

- How were the weights produced?
- Which dataset or fixed inputs were used?
- Which quantization scheme was applied?
- Which exported files correspond to the current hardware build?

The repository should also be able to show:

- Which training run produced the selected result
- Which metrics justified using that result for downstream work
- Which CLI command sequence reproduces the selected result

## 8. Suggested Files

Suggested ANN-related files:

```text
ann/
  cli/
    __main__.py
  src/
    train.py
    evaluate.py
    quantize.py
    model.py
    dataset.py
    teacher.py
    params.py
    artifacts.py
  results/
    latest/
      training_summary.md
      metrics.json
      weights_float.json
      weights_float_selected.json
      weights_quantized.json
      dataset_snapshot.jsonl
```

Equivalent file names are acceptable if the same responsibilities are covered.

## 9. Acceptance Criteria

The `ann` domain is complete when:

1. The project can actually train a valid MLP parameter set for the target shape.
2. The training run produces recorded metrics and saved result artifacts.
3. The trained parameters can be quantized into hardware-compatible values.
4. The exported results are consumable by the `contract` domain for downstream freezing.
5. The generation path is reproducible from committed scripts or documented commands.

## 10. Repository Defaults

The current repository implementation fixes the following default choices:

- Dataset seed: `20260312`
- Input range: signed integers in `[-16, 15]`
- Dataset labeling: fixed ReLU teacher network
- Optimizer: mini-batch Adam
- Batch size: `64`
- Epoch budget: `300`
- Early stopping patience: `20`
- Quantization: round-half-away-from-zero followed by signed clipping
- Default training output directory: auto-created immutable `ann/results/runs/<run_id>/`
