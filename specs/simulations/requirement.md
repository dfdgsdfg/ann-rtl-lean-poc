# Simulation Requirements

## 1. Purpose

This document defines the requirements for validating the Tiny Neural Inference ASIC through simulation.

The `simulations` domain covers:

- RTL testbench behavior
- Python reference-model comparison
- Test-vector generation
- Regression and pass or fail criteria

## 2. Testbench Requirements

The RTL testbench must provide:

- Input stimulus generation
- Inference execution
- Output capture
- Automatic output verification

The testbench must be able to:

- Drive the `start` handshake
- Wait for completion through `done`
- Record mismatches with enough context to reproduce them

The simulation domain must provide a simple CLI or script entry point so that a finished training result can be tested end to end without manual stimulus editing.

The shipped regression entry point should run the same bench under both `Icarus Verilog` and `Verilator`.

## 3. Reference Model Requirements

Simulation outputs must be compared against a Python reference model using the same weights, biases, and input vectors.

The Python side must support:

- Defining or training a toy model
- Quantizing weights and biases into signed integers
- Exporting constants for RTL consumption
- Generating expected scores and expected outputs for test vectors
- Running a reference check for a selected trained result

Generated simulation vectors must preserve enough expected data to distinguish positive, zero, and negative output-score cases, not only the final classification bit.

## 4. Test Coverage Requirements

The simulation flow must include:

- Directed tests for hand-checkable cases
- Generated or randomized vectors for broader coverage
- Explicit checks for positive, zero, and negative output-score cases
- Explicit checks for phase-boundary and last-iteration conditions in the controller

The regression flow must clearly report:

- Number of vectors run
- Number of passes and failures
- First failing vector or a failure summary

Boundary-focused regression cases must include:

- the final input MAC step for a hidden neuron
- the final hidden neuron transition into output accumulation
- the final output MAC step before result finalization
- output stability while `done` remains asserted

## 5. Required Files

Suggested simulation-related files:

```text
simulations/
  rtl/
    testbench.sv
    test_vectors.mem

ann/
  src/
    model.py          # inference reference model

contract/
  src/
    gen_vectors.py    # test vector generation from contract weights
```

Equivalent file names are acceptable if responsibilities remain the same.

## 6. Acceptance Criteria

The `simulations` domain is complete when:

1. The testbench can run inference end to end without manual intervention.
2. RTL outputs are automatically checked against Python-generated expectations.
3. Directed tests pass.
4. Generated regression vectors pass or produce actionable mismatch logs.
