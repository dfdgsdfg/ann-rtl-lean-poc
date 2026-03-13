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
make train
make freeze-check
make sim
```

The `train` command with default settings automatically freezes the contract and regenerates downstream artifacts (including `simulations/rtl/test_vectors.mem`). Use `--skip-export` to train without freezing.

`make sim` is the canonical regression entry point. It runs the same SystemVerilog bench through both `Icarus Verilog` and `Verilator`, and the regression fails if either simulator fails.

The user should not need to manually copy weights or hand-edit vectors after training.

Vector generation should synthesize dedicated positive, zero, and negative score witnesses during freeze. If the deterministic candidate pool cannot provide one of those classes, freeze should fail before the simulator runs.

## 4. Testbench Design

The SystemVerilog testbench should:

- Load embedded or generated vectors
- Apply `start`
- Wait until `done`
- Sample DUT-visible state and control on `negedge clk` after the `posedge` update has settled
- Compare `out` against the expected value on the `done` cycle
- Enforce the exact `76`-cycle latency as a failing condition
- Check the documented `DONE` hold and release semantics
- Print enough debug context on failure

Useful failure details include:

- Input vector
- Expected score
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

The generated vector file should remain plain text, but it should carry enough information for the bench to distinguish positive, zero, and negative expected scores instead of only the final class bit.

## 7. Debugging Plan

When a mismatch occurs, the flow should make it easy to answer:

- Was the vector generation wrong?
- Was the ROM export wrong?
- Was the RTL state schedule wrong?
- Was the expected output based on a different arithmetic interpretation?

For that reason, the simulation harness should prefer plain text or machine-readable exported vectors over hidden ad hoc stimuli.
