# Contract Domain

## What This Is

The `contract` folder is the handoff point between ANN training and the downstream implementation work.

It freezes one selected quantized ANN result into a stable contract that the rest of the repository can consume without reinterpreting weights or arithmetic rules independently.

In practical terms, this domain answers:

- Which ANN run is the current implementation target
- Which exact quantized tensors are frozen
- Which arithmetic and quantization assumptions are part of that freeze
- Which generated files downstream should match the frozen contract

## What Gets Generated

Running the freeze step refreshes these files from the same frozen payload:

- `contract/result/weights.json`
- `contract/result/model.md`
- `rtl/src/weight_rom.sv`
- `formalize/src/TinyMLP/Spec.lean`
- `simulations/rtl/test_vectors.mem`

Related provenance lives in `ann/results/selected_run.json`. That file points to the selected ANN run, its `weights_quantized.json`, and the canonical contract weights file.

The frozen contract also records verified safe bounds for the current weights over all signed `int8` inputs. Those bounds back the range-safety claim in `contract/result/model.md`.

## How To Use It

### 1. Train or choose an ANN result

To create a fresh ANN result:

```bash
python3 ann/src/train.py
```

That training flow also exports a quantized result and refreshes the contract.

If you already have a run directory with `weights_quantized.json`, you can freeze that run directly.

### 2. Freeze the contract

Freeze using the currently recorded run if `ann/results/selected_run.json` exists. If it does not exist, the CLI falls back to `ann/results/latest`.

```bash
python3 -m contract.src.freeze
```

Freeze an explicit run directory:

```bash
python3 -m contract.src.freeze --run-dir ann/results/latest
```

### 3. Validate the current frozen contract

Check that the frozen contract, provenance file, and generated downstream artifacts are all still in sync:

```bash
python3 -m contract.src.freeze --check
```

### 4. Read the outputs

For machine-readable data:

- `contract/result/weights.json`

For human-readable documentation:

- `contract/result/model.md`

For provenance:

- `ann/results/selected_run.json`

## When To Use This Folder

Use the `contract` CLI when you want to:

- promote one ANN result to the implementation baseline
- refresh RTL, Lean, and simulation artifacts from that baseline
- verify that the repo still matches the currently frozen contract

Do not edit `contract/result/weights.json` by hand. Re-freeze from an ANN result instead.

## Specs

The contract requirements and plan live here:

- `../specs/contract/requirement.md`
- `../specs/contract/design.md`
- `../specs/contract/plan.md`
