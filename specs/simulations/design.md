# Simulation Design

## 1. Design Goals

The simulation flow should be:

- Simple to run repeatedly
- Deterministic for debugging
- Shared across RTL, Python, and generated assets
- Structured so failures are easy to localize

## 2. Reference Flow

Python should act as the golden reference pipeline:

1. Define or train a toy model
2. Quantize weights into signed integer form
3. Export weights and biases for RTL
4. Generate input vectors and expected outputs

This creates one source of truth for constants and reduces manual mismatch risk.

## 3. CLI Flow

After training finishes, testing should be runnable through a small command sequence.

A practical flow is:

```text
python -m ann.cli train --seed 42
python -m ann.cli export --run-dir ann/results/latest
python -m contract.src.gen_vectors
make sim
```

The `train` command with default settings automatically freezes the contract and regenerates downstream artifacts (including `simulations/rtl/test_vectors.mem`). Use `--skip-export` to train without freezing.

The user should not need to manually copy weights or hand-edit vectors after training.

## 4. Testbench Design

The SystemVerilog testbench should:

- Load embedded or generated vectors
- Apply `start`
- Wait until `done`
- Compare `out` against the expected value
- Print enough debug context on failure

Useful failure details include:

- Input vector
- Expected output
- Actual output
- Cycle count to completion

## 5. Regression Strategy

The initial regression plan should include:

- Small directed vectors with known hand-computed outcomes
- Broader generated vectors from the Python toolchain
- Repeated runs using the same exported constants

Once the datapath is stable, the regression suite can expand to random sweeps and corner-case stress tests.

## 6. Asset Flow

The simulation assets should move in one direction:

```text
Python model -> quantized constants -> RTL ROM/test vectors -> simulation results
```

This avoids maintaining duplicate weight definitions by hand.

## 7. Debugging Plan

When a mismatch occurs, the flow should make it easy to answer:

- Was the vector generation wrong?
- Was the ROM export wrong?
- Was the RTL state schedule wrong?
- Was the expected output based on a different arithmetic interpretation?

For that reason, the simulation harness should prefer plain text or machine-readable exported vectors over hidden ad hoc stimuli.
