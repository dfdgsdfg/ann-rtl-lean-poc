# Contract Domain

## What This Is

The `contract` folder is the handoff point between ANN training and the downstream implementation work.

It freezes one canonical ANN snapshot into a stable contract that the rest of the repository can consume without reinterpreting weights or arithmetic rules independently.

In practical terms, this domain answers:

- Which ANN result is the current implementation target
- Which exact quantized tensors are frozen
- Which arithmetic and quantization assumptions are part of that freeze
- Which generated files downstream should match the frozen contract

## What Gets Generated

Running the freeze step refreshes these files and metadata from the same frozen payload:

- `contract/results/canonical/manifest.json`
- `contract/results/canonical/weights.json`
- `contract/results/canonical/model.md`
- `rtl/results/canonical/sv/weight_rom.sv`
- `formalize/src/TinyMLP/Defs/SpecCore.lean`
- `simulations/shared/test_vectors.mem`
- `simulations/shared/test_vectors_meta.svh`

The freeze step may also write a local historical snapshot under `contract/results/runs/<run_id>/`, but the checked-in implementation baseline is always `contract/results/canonical/`.

`ann/results/canonical/manifest.json` records the canonical ANN artifact set and its dataset snapshot SHA-256.

`contract/results/canonical/weights.json` mirrors that canonical ANN provenance. `python3 -m contract.src.freeze --check` proves that the frozen contract still matches `ann/results/canonical/` and that the downstream generated artifacts are in sync.

The frozen contract also records verified safe bounds for the current weights over all signed `int8` inputs. Those bounds back the range-safety claim in `contract/results/canonical/model.md`.

## How To Use It

### 1. Train or choose an ANN result

To create a fresh ANN result and refresh canonical snapshots:

```bash
make train
```

If you run the lower-level training module directly:

```bash
python3 ann/src/train.py
```

it only writes ANN artifacts under `ann/results/` and does not refresh `ann/results/canonical/`, `contract/results/canonical/`, or the downstream generated files. Run `python3 -m contract.src.freeze --run-dir ...` afterward if you use that lower-level entrypoint.

### 2. Freeze the contract

Freeze from the current canonical ANN snapshot:

```bash
python3 -m contract.src.freeze
```

Freeze an explicit local ANN run and promote it into canonical ANN and contract snapshots:

```bash
python3 -m contract.src.freeze --run-dir ann/results/runs/relu_teacher_v2-seed20260312-epoch51
```

### 3. Validate the current frozen contract

Check that the canonical contract, canonical ANN snapshot, and generated downstream artifacts are all still in sync:

```bash
python3 -m contract.src.freeze --check
```

### 4. Regenerate only the simulation vectors

If the contract is already frozen and you only need to refresh `simulations/shared/test_vectors.mem` and `simulations/shared/test_vectors_meta.svh`:

```bash
python3 -m contract.src.gen_vectors
```

Run the separate strict witness check for positive/zero/negative score-class coverage:

```bash
python3 -m contract.src.gen_vectors --check-witnesses
```

### 5. Read the outputs

For machine-readable data:

- `contract/results/canonical/weights.json`

For human-readable documentation:

- `contract/results/canonical/model.md`

For provenance:

- `ann/results/canonical/manifest.json`
- `contract/results/canonical/manifest.json`

## When To Use This Folder

Use the `contract` CLI when you want to:

- promote one ANN run to the implementation baseline
- refresh RTL, Lean, simulation, and provenance artifacts from that baseline
- verify that the repo still matches the currently frozen canonical contract

Do not edit `contract/results/canonical/weights.json` by hand. Re-freeze from an ANN result instead.

## Specs

The contract requirements and design live here:

- `../specs/contract/requirement.md`
- `../specs/contract/design.md`
