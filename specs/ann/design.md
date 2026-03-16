# ANN Design

## 1. Design Goals

The ANN creation flow should be:

- Small and deterministic
- Easy to rerun
- Closely aligned with the hardware model
- Structured to export one consistent set of parameters
- Capable of producing an actual trained result, not only a placeholder parameter set

## 2. Model Creation Strategy

The ANN should use the same topology as the hardware target:

- `4 -> 8 -> 1`
- `ReLU` hidden activation
- Binary classification output

The primary path must be an actual training flow that produces a real parameter set and recorded results.

## 3. Training Flow

If training is used, a practical sequence is:

1. Define or generate a toy dataset
2. Train the floating-point reference MLP
3. Extract weights and biases
4. Quantize them into hardware-compatible integer values
5. Export the results for downstream domains

The training flow should remain simple enough that export stability matters more than benchmark quality, but it still needs to produce a real trained result with recorded metrics.

## 4. Training Result Design

Each training run should generate artifacts that make the result inspectable and reusable:

- Final or best-checkpoint weights
- Float-shadow weights for the selected quantized checkpoint
- Metrics summary
- Quantized export derived from the selected weights
- Short markdown summary of the chosen run

A practical result flow is:

```text
dataset
  -> train model
  -> evaluate model
  -> select final result
  -> quantize selected parameters
  -> export downstream artifacts
```

The selected result should be the single source of truth for the later `contract`, `rtl`, `formalize`, and `simulations` domains.

## 5. CLI Plan

The ANN flow should be operable through a simple CLI so that a finished training run can be tested and exported without manual file editing.

A practical command shape is:

```text
python3 -m ann.cli train --out-dir ann/results/runs/run_001 --skip-export
python3 -m ann.cli evaluate --run-dir ann/results/runs/run_001 --artifact quantized
python3 -m ann.cli quantize --run-dir ann/results/runs/run_001 --artifact selected-float
python3 -m ann.cli export --run-dir ann/results/runs/run_001
```

The exact filenames and subcommands can vary. What matters is that one short command path can:

- Train
- Evaluate
- Quantize
- Export

without manual copying of weights between steps.

## 6. Quantization Design

The quantization path should map trained parameters into:

- `int8` weights
- `int32` compatible biases

The design should explicitly document:

- Scaling assumptions
- Rounding policy
- Clipping policy if used
- How exported values are interpreted by the Python reference and RTL

This is important because quantization mismatch is one of the easiest ways to create silent divergence between the ANN and hardware flows.

## 7. Export Design

The ANN flow should separate local run history from the checked-in canonical snapshot.

- local immutable runs live under `ann/results/runs/<run_id>/`
- the checked-in baseline lives under `ann/results/canonical/`

The `contract` domain is responsible for reading the canonical ANN snapshot, freezing it into a canonical contract, and generating downstream artifacts for RTL, Lean, and simulation.

The ANN domain's export boundary is the file system:

```text
dataset
  -> train model
  -> quantize
  -> write results to ann/results/runs/<run_id>/
  -> optionally promote to ann/results/canonical/
  -> (contract domain reads and freezes)
```

The ANN domain must not import code from the `contract` domain. The `ann/cli` layer may invoke contract operations as an orchestration convenience, but the core ANN modules must remain independent.

## 8. Result Selection Strategy

The ANN flow should define how one result is chosen for downstream use.

Selection should consider:

- Stable convergence
- Sufficient task accuracy for the toy problem
- Quantization compatibility
- Simplicity of downstream explanation and debugging

The chosen result should be documented in a short summary so later domains know exactly which exported constants they depend on.

## 9. Bring-Up Strategy

The most reliable development order is:

1. Start with a minimal dataset and actual training flow
2. Produce one trained result and metrics summary
3. Quantize the selected result
4. Validate reference inference and RTL behavior
5. Regenerate constants and rerun simulation and synthesis

## 10. Open ANN Decisions

These choices should be fixed early:

- Dataset choice or generation method
- Exact quantization scheme and scaling
- Export format for ROM constants
- Which metrics determine the selected training result
- Whether Lean consumes generated constants directly or redefines them manually
