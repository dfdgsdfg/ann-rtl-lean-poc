# Contract Implementation Plan

## Goal

Turn the `contract` domain into a concrete, reproducible freeze step that selects one quantized ANN result and exposes it as the single implementation contract for RTL, formalization, simulation, and experiments.

## Scope

- The contract is derived from ANN export artifacts rather than authored independently.
- The canonical frozen contract artifact is `contract/result/weights.json`.
- Provenance for the frozen contract is recorded in `ann/results/selected_run.json`.
- The contract domain owns: schema validation (`schema.py`), freeze logic (`freeze.py`), downstream artifact generation (`downstream_sync.py`, `gen_vectors.py`).
- The contract domain reads ANN training outputs as files. It does not import ANN Python modules.
- The public contract fields are:
  - `schema_version`
  - `source`
  - `selected_run`
  - `input_size`
  - `hidden_size`
  - `dataset_version`
  - `training_seed`
  - `w1`
  - `b1`
  - `w2`
  - `b2`
  - `quantization`
  - `arithmetic`
  - `boundedness`
- Downstream generated views of the contract are:
  - `contract/result/weights.json`
  - `contract/result/model.md`
  - `rtl/src/weight_rom.sv`
  - `formalize/src/TinyMLP/Spec.lean`
  - `simulations/rtl/test_vectors.mem`

## Execution Plan

1. Produce a candidate ANN result with a quantized export, either by running `python3 -m ann.cli train` or by choosing an existing run directory that contains `weights_quantized.json`.
2. Read the quantized weights file from the selected ANN run directory.
3. Validate tensor shapes, integer ranges, and metadata using contract-owned schema logic.
4. Build the frozen payload with arithmetic and quantization contract metadata.
5. Verify that the frozen weights keep every intermediate stage within its declared signed width for all signed `int8` inputs, and record the resulting safe bounds in `boundedness`.
6. Write `contract/result/weights.json` via `python3 -m contract.src.freeze` using the default selected run or `--run-dir` for an explicit run.
7. Record the selected run and artifact provenance in `ann/results/selected_run.json`.
8. Regenerate all downstream generated artifacts from the frozen payload.
9. Self-validate that all frozen and generated artifacts are in sync.
10. Treat the regenerated outputs as the only downstream views of the frozen contract. No downstream domain should re-quantize or reinterpret ANN parameters independently.

## Default Policy

- The default selected run is `ann/results/latest`.
- The frozen topology is `4 -> 8 -> 1`.
- Run selection follows the ANN domain policy:
  1. Higher quantized validation accuracy
  2. Lower quantized validation loss
  3. Smaller quantized `L1` magnitude
- The frozen arithmetic meaning is:
  - inputs and weights are signed `int8`
  - hidden activations are signed `int16`
  - hidden MAC products are `int8 * int8 -> int16`, accumulated in `int32`
  - output MAC products are `int16 * int8 -> int24`, accumulated in `int32`
  - biases are signed `int32`
  - overflow uses signed two's complement wraparound

## Validation Checklist

- `weights_quantized.json` exists for the selected run.
- Tensor shapes match `W1[8][4]`, `b1[8]`, `W2[8]`, and `b2`.
- Exported integer values fit the expected signed ranges for their stored widths.
- `contract/result/weights.json` contains the full frozen metadata and tensor payload.
- `contract/result/weights.json` records verified safe bounds for hidden products, hidden pre-activations, hidden activations, output products, and the output accumulator over all signed `int8` inputs.
- `ann/results/selected_run.json` points to the same selected run, quantized artifact, and canonical contract weights used for the freeze step.
- `contract/result/weights.json`, `contract/result/model.md`, `rtl/src/weight_rom.sv`, `formalize/src/TinyMLP/Spec.lean`, and `simulations/rtl/test_vectors.mem` are refreshed from the same frozen payload.
- `python3 -m contract.src.freeze --check` passes without rewriting artifacts.

## Suggested Files

```text
contract/
  src/
    schema.py            # contract schema definition and validation
    freeze.py            # freeze_contract, validate_contract
    downstream_sync.py   # weight_rom.sv, Spec.lean, model.md generation
    gen_vectors.py       # test_vectors.mem generation
  result/
    weights.json         # canonical frozen contract
    model.md             # human-readable contract documentation
```

## Acceptance

The `contract` domain is ready for downstream work when:

1. One quantized ANN result is explicitly frozen.
2. The frozen contract can be traced back to a selected ANN run.
3. All downstream generated artifacts are synchronized from the frozen payload.
4. Reproducing the contract requires only committed scripts and documented commands.
5. All contract logic lives in `contract/src/` without importing ANN Python modules.
