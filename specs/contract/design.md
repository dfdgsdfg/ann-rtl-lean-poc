# Contract Design

## 1. Design Goals

The contract step should convert ANN training output into a hardware-ready and proof-ready agreement.

The design should favor:

- One unambiguous downstream target
- Minimal ambiguity about numeric meaning
- Easy traceability back to the training result
- Early detection of mismatches before RTL and proof work start

## 2. Contract Derivation Workflow

A practical workflow is:

1. Produce one or more ANN training results
2. Select the result to use downstream
3. Inspect model topology and parameter shapes
4. Quantize weights and biases
5. Freeze numeric assumptions and exported artifacts
6. Hand the frozen contract to RTL, formalization, simulations, and experiments

This makes the contract step the bridge between ANN training and implementation.

## 3. Freeze CLI Plan

The contract step should be scriptable with one simple command that freezes a selected ANN result into downstream artifacts.

A practical command shape is:

```text
python3 -m contract.src.freeze --run-dir ann/results/runs/relu_teacher_v2-seed20260312-epoch51
```

To validate an existing frozen contract without rewriting:

```text
python3 -m contract.src.freeze --check
```

The main requirement is that downstream domains can consume a frozen contract without manually rewriting constants.

## 4. Expected Contract Outputs

The contract step should produce:

- Confirmed model shape and layer dimensions
- Selected floating-point or high-precision parameters
- Selected quantized weights and biases
- Notes on scaling, rounding, clipping, and overflow assumptions
- Verified safe bounds for intermediate values over the supported input domain
- Exported constants or generated files for downstream use
- A short summary of which training result was chosen and why

## 5. Failure Modes to Catch Early

This domain should catch issues before implementation begins:

- Shape mismatch between ANN and hardware target
- Quantized values outside the intended integer ranges
- Different arithmetic assumptions across Python, RTL, and Lean
- Exported constants that do not match the selected training result
- Multiple candidate results with no clearly frozen choice

## 6. Downstream Use

The frozen contract should be the input to:

- `rtl`, which implements the hardware behavior
- `formalize`, which proves the intended machine behavior
- `simulations`, which checks implementation results
- `experiments`, which compares behavior against a stable baseline

Downstream domains should not reinterpret ANN outputs independently once the contract is frozen.

## 7. Bring-Up Strategy

The safest early milestone is:

1. Train a minimal ANN
2. Freeze one contract from that result
3. Build RTL and Lean models against the frozen contract
4. Add additional training runs later only if they produce a new explicit contract version

This reduces churn because hardware and proof work depend on stable semantics.

## 8. Domain Boundary

The `contract` domain must own all code it needs to validate, freeze, and generate downstream artifacts. It must not import Python modules from the `ann` domain.

The interface between `ann` and `contract` is the file system:

- `ann` writes immutable run artifacts under `ann/results/runs/<run_id>/...`
- `ann/results/selected_run.json` records which immutable run is canonical
- `contract` reads that selected immutable run and produces `contract/result/weights.json` plus downstream generated files

Low-level utilities such as integer range checking may be duplicated across domains. This small duplication is preferable to a code-level coupling that would prevent the two domains from being tested and reasoned about independently.
