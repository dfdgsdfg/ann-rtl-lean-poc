# Contract Requirements

## 1. Purpose

This document defines the requirements for the implementation contract derived from the ANN training result.

The `contract` domain covers:

- Selecting the exact ANN result to use downstream
- Freezing the parameter set and tensor shapes
- Freezing quantization and arithmetic assumptions
- Defining the implementation-facing handoff consumed by RTL, formalization, and simulation
- Owning the contract schema definition and validation logic
- Generating downstream artifacts (RTL ROM, Lean spec, simulation vectors, model documentation)

The `contract` domain reads ANN training results from `ann/results/` as files. It must not depend on ANN Python code at import time. The ANN domain likewise must not import contract Python code. The boundary between the two domains is the file system.

## 2. Contract Scope

The contract must turn ANN training output into one stable implementation target.

The contract must identify and freeze:

- The selected training run, checkpoint, or final model result
- The exact model topology, which must match `4 -> 8 -> 1`
- The complete parameter tensors `W1`, `b1`, `W2`, and `b2`
- The fixed-point or integer interpretation used downstream

The contract must be normative. Downstream domains must treat it as the single source of truth.

## 3. Numeric Contract Requirements

The contract must define the numeric assumptions used by hardware-facing flows.

It must specify:

- Weight representation in signed `int8`
- Input representation assumptions in signed `int8`
- Hidden activation representation in signed `int16`
- Accumulator and bias representation in signed `int32`
- Overflow semantics as signed two's complement wraparound
- Sign extension expectations between arithmetic stages
- Whether the frozen weights keep every intermediate stage within its declared width over the supported input domain

If clipping, scaling, or rounding are used, the contract must define them explicitly.

## 4. Parameter Contract Requirements

The contract must freeze one specific parameter set for downstream use.

It must provide:

- `W1[8][4]`
- `b1[8]`
- `W2[8]`
- `b2`

The contract must also record:

- Which training result produced these values
- Which immutable dataset snapshot was used to produce the selected result
- Why this result was selected
- Which exported files correspond to the frozen contract
- The verified boundedness status and safe intermediate-value bounds for the supported input domain

## 5. Handoff Requirements

The contract domain must produce artifacts that downstream domains can consume directly:

- Selected parameter export
- Quantized parameter export
- Tensor-shape declaration
- Arithmetic interpretation notes
- Optional representative vectors or expected outputs

This handoff must be stable enough for:

- RTL specification and implementation
- Lean formal modeling
- Simulation vector generation and checking
- Experiment comparison baselines

The contract flow must also be invokable through a simple script or CLI command so that one selected ANN result can be frozen without manual editing.

## 6. Reproducibility Requirements

The contract must be reproducible from committed sources and documented commands.

The repository should clearly show:

- Which ANN run produced the selected contract
- Which immutable dataset snapshot and snapshot hash back that selected run
- Which quantization method was applied
- Which exported artifacts implement the frozen contract
- Which downstream domains depend on it

## 7. Code Ownership

The `contract` domain must own all code needed to:

- Validate and coerce quantized weight payloads (schema validation)
- Build the frozen contract payload with arithmetic and quantization metadata
- Freeze a selected ANN run into `contract/results/canonical/weights.json`
- Validate that frozen artifacts are in sync
- Generate downstream artifacts: `rtl/results/canonical/sv/weight_rom.sv`, `formalize/src/TinyMLP/Defs/SpecCore.lean`, `contract/results/canonical/model.md`, `simulations/shared/test_vectors.mem`

Low-level quantization math (rounding, clipping, range checks) used during validation may be duplicated from or shared with the ANN domain, but the contract domain must not import ANN modules.

## 8. Suggested Files

```text
contract/
  results/
    canonical/
      manifest.json
      weights.json
      model.md
    runs/
      <run_id>/
        manifest.json
        weights.json
        model.md
  src/
    schema.py
    freeze.py
    downstream_sync.py
    gen_vectors.py
```

## 9. Acceptance Criteria

The `contract` domain is complete when:

1. One trained ANN result is selected and frozen for downstream work.
2. The exact tensors, shapes, and arithmetic assumptions are documented.
3. Quantized exports are available for RTL, formalization, and simulation.
4. The contract is reproducible from committed scripts or documented commands.
5. The contract domain owns its schema validation and downstream generation code without importing ANN modules.
