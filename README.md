# Tiny Neural Inference ASIC

## What This Is

This repository is a small end-to-end research project for a tiny neural-network inference chip.

It takes one toy MLP and pushes it through the full stack:

1. train an actual ANN
2. freeze one quantized result as the implementation contract
3. implement the contract in RTL
4. model the same behavior in Lean
5. validate with simulation
6. add SMT-backed control verification
7. synthesize with an open-source ASIC flow

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

6. `smt`
Run solver-backed verification for RTL control properties, frozen-contract overflow bounds, arithmetic equivalence, and the frozen arithmetic-assumption export.

7. `experiments`
Run optional comparisons such as functional sweeps, latency checks, report comparisons, reactive-synthesis studies, or generated-implementation studies.

8. `asic`
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

## Reactive-Synthesis Experiments

Reactive synthesis is separated from the baseline implementation flow.

In this repository it belongs under `experiments`, not under the canonical `rtl/` path.

The intended use is experimental:

- synthesize a controller candidate from a temporal specification
- compare it against `rtl/src/controller.sv`
- keep the arithmetic datapath and frozen contract as the baseline unless an experiment explicitly replaces them

That means:

- reactive synthesis is an experiment track, not the source of truth for the shipped RTL
- experiment summaries should distinguish `artifact_kind`, `assembly_boundary`, `evidence_boundary`, and `evidence_method` instead of collapsing branch status into a single support label
- Lean/Sparkle-generated RTL is a full-core experiment branch validated by the shared `mlp_core` regression bench and downstream QoR flows
- `rtl-formalize-synthesis/` now carries a full-core Lean refinement surface from the pure `rtlTrace` semantics to the Sparkle Signal DSL full-core view; emitted RTL remains downstream-validated rather than proved by Lean alone
- Sparkle-to-Verilog remains a trusted backend boundary and is validated by shared full-core simulation and downstream synthesis comparison, not by Lean proof alone
- hand-written `rtl/` remains the canonical implementation baseline

Relevant docs:

- [experiments/README.md](experiments/README.md)
- [experiments/implementation-branch-comparison.md](experiments/implementation-branch-comparison.md)
- [experiments/rtl-formalize-synthesis/sparkle/README.md](experiments/rtl-formalize-synthesis/sparkle/README.md)
- [experiments/rtl-synthesis/spot/README.md](experiments/rtl-synthesis/spot/README.md)
- [rtl-synthesis/controller/README.md](rtl-synthesis/controller/README.md)
- [specs/rtl-synthesis/requirement.md](specs/rtl-synthesis/requirement.md)
- [specs/rtl-formalize-synthesis/requirement.md](specs/rtl-formalize-synthesis/requirement.md)

## Dependencies

Install Homebrew packages:

```bash
brew bundle
```

Install the npm visualization tool:

```bash
npm install -g netlistsvg
```

The committed Brewfile currently installs most of the baseline local toolchain used by this repository:
`icarus-verilog`, `verilator`, `yosys`, and `z3`.
Install `python3`, `node`, and `elan` separately if your system does not already provide them.

For the SMT flow specifically, `make smt` expects:

- `python3` for the SMT driver scripts
- `yosys` for RTL elaboration
- `yosys-smtbmc` for bounded SMT model checking
- `z3` as the current backend solver

For the vanilla Lean proof path, `make formalize` expects:

- `lake`
- a working `elan` installation so the pinned Lean toolchain can be installed on first build

For the Sparkle full-core generation path, `make rtl-formalize-synthesis-build` expects:

- `git` for the Sparkle prepare step
- `lake` to build the full `TinyMLPSparkle` library, then emit the checked-in Sparkle full-core artifact and stable generated `mlp_core` wrapper

On Homebrew, the `yosys` formula provides both `yosys` and `yosys-smtbmc`.

For the `rtl-synthesis` experiment specifically, `make rtl-synthesis` expects:

- `ltlsynt` from the Spot toolchain
- `syfco` on `PATH` for TLSF loading
- `yosys`, `yosys-smtbmc`, and `z3`

For `make rtl-synthesis-sim`, you also need:

- `iverilog`
- `vvp`
- `verilator`

Other tools used by the project (install separately if needed):

| Tool | Purpose | Install |
|------|---------|---------|
| Python 3 | ANN training, contract freeze, vector generation | `brew install python@3` or system Python |
| elan | Lean 4 toolchain manager (formal verification) | `brew install elan-init` |
| Node.js | Required for netlistsvg | `brew install node` |

## How To Use It

If you only want the practical starting point, begin with the ANN wrapper:

```bash
make train
```

Evaluate the currently selected quantized result:

```bash
make evaluate ARGS="--artifact quantized"
```

Validate that the frozen contract is still consistent:

```bash
python3 -m contract.src.freeze --check
```

Run the vanilla Lean proof baseline:

```bash
make formalize
```

Run the dual-simulator RTL regression:

```bash
make sim
```

Run the full solver-backed SMT flow:

```bash
make smt
```

Run the practical proof-plus-regression bundle:

```bash
make verify
```

Run the controller reactive-synthesis experiment:

```bash
make rtl-synthesis-smoke
make rtl-synthesis
make rtl-synthesis-sim
```

### Typical Human Workflow

Use this when you want to understand or refresh the current repository baseline:

```bash
make train
make evaluate ARGS="--artifact quantized"
make verify
```

If you want to train into a separate run directory first:

```bash
make train ARGS="--out-dir ann/results/tmp/run_001 --skip-export"
make evaluate ARGS="--run-dir ann/results/tmp/run_001 --artifact quantized"
make export ARGS="--run-dir ann/results/tmp/run_001"
```

## What Gets Generated

The main human-facing outputs are:

- `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/training_summary.md`
- `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/metrics.json`
- `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_float.json`
- `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_float_selected.json`
- `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_quantized.json`
- `ann/results/selected_run.json` (canonical immutable selection metadata)
- `contract/result/weights.json`
- `contract/result/model.md`
- `rtl/src/weight_rom.sv`
- `simulations/shared/test_vectors.mem` (packed expected score, class bit, and inputs for the deterministic smoke suite, per-lane arithmetic-boundary sweep, and synthesized score/accumulator stress vectors)

`contract/result/weights.json` is the canonical frozen payload for downstream use. It also records verified safe intermediate-value bounds for all signed `int8` inputs.

## Repository Map

- `ann/`
Training, evaluation, quantization, export, and saved run artifacts.

- `contract/`
The frozen implementation contract and the tooling that regenerates downstream artifacts from it.

- `rtl/`
SystemVerilog source for the tiny inference core.

- `rtl-synthesis/`
Reactive-synthesis source inputs, formal harnesses, and driver scripts for the controller experiment.

- `rtl-formalize-synthesis/`
Lean/Sparkle source for the generated full-core experiment branch, including the direct full-core refinement bridge from `rtlTrace` into the actual Sparkle Signal DSL view.

- `formalize/`
Lean source files for the spec, fixed-point model, machine model, invariants, and correctness statements.

- `smt/`
Solver-backed verification artifacts and frozen-contract assumption exports.

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

- [docs/reactive-systems-beginners-guide.md](docs/reactive-systems-beginners-guide.md)
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
- the ASIC flow is present as source artifacts, but not yet wrapped in the same CLI style as the ANN flow
- generated RTL and reactive-synthesis work are experiment tracks, not the canonical implementation flow

## Current CLI Summary

Available ANN commands:

```bash
make train
make evaluate ARGS="--artifact quantized"
make quantize ARGS="--artifact selected-float"
make export
```

Contract freeze tool:

```bash
make freeze
make freeze-check
make sim-vectors
```

The freeze/vector-generation path now fails early if it cannot synthesize positive, zero, and negative score witnesses from its deterministic candidate pool, and it emits a broader deterministic suite that exercises per-lane `-128/-127/+127` boundaries plus score/accumulator stress cases.

Proof commands:

```bash
make formalize
make verify
```

Simulation commands:

```bash
make sim
make sim-iverilog
make sim-verilator
make rtl-synthesis-sim
make rtl-formalize-synthesis-sim
make rtl-formalize-synthesis-iverilog
make rtl-formalize-synthesis-verilator
```

Experiment commands:

```bash
make experiments
make experiments-artifact-consistency
make experiments-semantic-closure
make experiments-branch-compare
make experiments-qor
make experiments-post-synth
```

The experiment runner writes family summaries and reports under `build/experiments/`.

Visualization (generates SVG schematics in `docs/assets/`):

```bash
make show
```

## Notes

- The repository currently treats the selected trained result as the single source of truth for downstream implementation.
- Do not edit generated contract weights by hand. Re-freeze them from an ANN result instead.
- If you are trying to understand the intended architecture rather than the current code state, read `specs/` first.
