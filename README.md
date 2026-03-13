# Tiny Neural Inference ASIC

## What This Is

This repository is a small end-to-end research project for a tiny neural-network inference chip.

It takes one toy MLP and pushes it through the full stack:

1. train an actual ANN
2. freeze one quantized result as the implementation contract
3. implement the contract in RTL
4. model the same behavior in Lean
5. validate with simulation
6. synthesize with an open-source ASIC flow

The model is intentionally small enough to inspect by hand:

- input width: `4`
- hidden width: `8`
- output width: `1`
- hidden activation: `ReLU`
- output: binary classification

## Goal

The goal is not benchmark performance. The goal is to make the whole path understandable and checkable:

- an ANN that is actually trained
- a frozen quantized contract that downstream code agrees on
- a small sequential-MAC RTL design
- a Lean formalization of the intended behavior
- simulation and ASIC artifacts tied back to the same frozen result

## Project Process

The repository is organized around this process:

1. `ann`
Train the toy model, evaluate it, quantize it, and save the results.

2. `contract`
Choose one trained result and freeze the exact tensors and arithmetic assumptions that the rest of the repository must use.

3. `rtl`
Implement the frozen contract in SystemVerilog.

4. `formalize`
Define the mathematical, fixed-point, and machine models in Lean and prove the intended relationships.

5. `simulations`
Generate vectors and compare RTL behavior against the frozen contract.

6. `experiments`
Run optional comparisons such as functional sweeps, latency checks, or report comparisons.

7. `asic`
Run synthesis and, later, physical-design steps.

## Why RTL Is Hard

The arithmetic in this project is small. The harder part is the sequential RTL behavior.

This RTL is a reactive system:

- it observes control inputs over time
- it updates internal state on clock edges
- it produces outputs based on input history and FSM state, not only current inputs

That means verification is not only about “does the final value match the math?”

It is also about:

- cycle-accurate FSM behavior
- `start` / `busy` / `done` / output timing
- hidden-to-output phase transitions
- final-iteration and off-by-one boundaries
- output validity and stability after completion

That is why temporal reasoning matters here. End-state correctness is necessary, but not sufficient. We also need bounded progress, phase ordering, and stable-result properties over execution traces.

In this repository, that is the role of the `formalize` domain: connect mathematical correctness to reactive RTL behavior with machine and temporal proofs.

## How To Use It

If you only want the practical starting point, begin with the ANN wrapper:

```bash
./scripts/ann.sh --help
```

Train the model and refresh the default downstream artifacts:

```bash
./scripts/ann.sh train
```

Evaluate the currently selected quantized result:

```bash
./scripts/ann.sh evaluate --artifact quantized
```

Validate that the frozen contract is still consistent:

```bash
python3 -m contract.src.freeze --check
```

Run the dual-simulator RTL regression:

```bash
make sim
```

### Typical Human Workflow

Use this when you want to understand or refresh the current repository baseline:

```bash
./scripts/ann.sh train
./scripts/ann.sh evaluate --artifact quantized
python3 -m contract.src.freeze --check
make sim
```

If you want to train into a separate run directory first:

```bash
./scripts/ann.sh train --out-dir ann/results/tmp/run_001 --skip-export
./scripts/ann.sh evaluate --run-dir ann/results/tmp/run_001 --artifact quantized
./scripts/ann.sh export --run-dir ann/results/tmp/run_001
```

## What Gets Generated

The main human-facing outputs are:

- `ann/results/latest/training_summary.md`
- `ann/results/latest/metrics.json`
- `ann/results/latest/weights_float.json`
- `ann/results/latest/weights_float_selected.json`
- `ann/results/latest/weights_quantized.json`
- `contract/result/weights.json`
- `contract/result/model.md`
- `rtl/src/weight_rom.sv`
- `simulations/rtl/test_vectors.mem` (packed expected score, class bit, and inputs)

`contract/result/weights.json` is the canonical frozen payload for downstream use. It also records verified safe intermediate-value bounds for all signed `int8` inputs.

## Repository Map

- `ann/`
Training, evaluation, quantization, export, and saved run artifacts.

- `contract/`
The frozen implementation contract and the tooling that regenerates downstream artifacts from it.

- `rtl/`
SystemVerilog source for the tiny inference core.

- `formalize/`
Lean source files for the spec, fixed-point model, machine model, invariants, and correctness statements.

- `simulations/`
RTL testbench and generated test vectors.

- `experiments/`
Optional evaluation and comparison work.

- `asic/`
ASIC synthesis and flow scripts.

- `specs/`
Human-facing requirements and design documents for each domain.

## Where To Read First

If you want the human documentation first, start here:

- [docs/reactive-state-systems-beginners-guide.md](docs/reactive-state-systems-beginners-guide.md)
- [specs/README.md](specs/README.md)
- [specs/ann/requirement.md](specs/ann/requirement.md)
- [specs/contract/requirement.md](specs/contract/requirement.md)
- [specs/rtl/requirement.md](specs/rtl/requirement.md)
- [specs/formalize/requirement.md](specs/formalize/requirement.md)

If you want the current implemented training and freeze flow:

- [ann/README.md](ann/README.md)
- [contract/readme.md](contract/readme.md)

## Current Status

What is already in place:

- ANN training, evaluation, quantization, and export CLI exist
- frozen contract artifacts exist
- RTL sources exist
- simulation sources exist
- Lean sources exist

What is still in progress:

- the repository is not yet a one-command end-to-end flow across every domain
- Lean package wiring still needs cleanup before `lake build` succeeds from the repository root
- the ASIC flow is present as source artifacts, but not yet wrapped in the same CLI style as the ANN flow

## Current CLI Summary

Available ANN commands:

```bash
python3 -m ann.cli train
python3 -m ann.cli evaluate
python3 -m ann.cli quantize
python3 -m ann.cli export
```

Wrapper form:

```bash
./scripts/ann.sh train
./scripts/ann.sh evaluate --artifact quantized
./scripts/ann.sh quantize --artifact selected-float
./scripts/ann.sh export
```

Contract freeze tool:

```bash
python3 -m contract.src.freeze
python3 -m contract.src.freeze --check
python3 -m contract.src.gen_vectors
```

Simulation commands:

```bash
make sim
make sim-iverilog
make sim-verilator
```

## Notes

- The repository currently treats the selected trained result as the single source of truth for downstream implementation.
- Do not edit generated contract weights by hand. Re-freeze them from an ANN result instead.
- If you are trying to understand the intended architecture rather than the current code state, read `specs/` first.
