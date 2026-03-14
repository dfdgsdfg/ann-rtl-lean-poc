# Simulation Requirements

## 1. Purpose

This document defines the requirements for validating the Tiny Neural Inference ASIC through simulation.

The `simulations` domain covers:

- RTL testbench behavior
- Python reference-model comparison
- Test-vector generation
- Regression and pass or fail criteria
- Declared simulation support boundaries for `rtl/`, `rtl-synthesis`, and `rtl-formalize-synthsis`

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

The shipped regression entry point for any full-core or mixed-path branch should run the same bench under both `Icarus Verilog` and `Verilator`.

Module-based testbench assertions over DUT state or control must sample post-update values, not immediate `posedge` values before nonblocking register updates settle.

## 3. Implementation Branch Support

The simulation domain must define support for these RTL implementation branches:

- `rtl/`: canonical full-core simulation support against the shared vector-driven `mlp_core` bench
- `rtl-synthesis`: mixed-path simulation support that preserves the baseline datapath and vector format while replacing the controller implementation
- `rtl-formalize-synthsis`: at minimum, controller-only simulation support against the `rtl/src/controller.sv` boundary; any claim of primitive-path or full-core support must be declared separately and validated with the matching bench

Each simulation entry point, summary, or experiment note must state:

- which branch is under test
- whether the scope is full-core, mixed-path, or controller-only
- whether the bench is shared with the baseline or branch-local

## 4. Reference Model Requirements

Simulation outputs must be compared against a Python reference model using the same weights, biases, and input vectors.

The Python side must support:

- Defining or training a toy model
- Quantizing weights and biases into signed integers
- Exporting constants for RTL consumption
- Generating expected scores and expected outputs for test vectors
- Running a reference check for a selected trained result

Generated simulation vectors must preserve enough expected data to distinguish positive, zero, and negative output-score cases, not only the final classification bit.

Freeze and vector generation must fail early if the current frozen weights cannot produce at least one positive, zero, and negative score witness from the deterministic candidate pool used by the repository.

## 5. Test Coverage Requirements

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

Controller-only branch-local benches must also include:

- reset behavior at the declared wrapper boundary
- phase-ordering agreement against the baseline controller
- `start` / `busy` / `done` behavior at the declared support boundary

## 6. Required Files

Suggested simulation-related files:

```text
simulations/
  shared/
    test_vectors.mem
    test_vectors_meta.svh
  rtl/
    testbench.sv
  rtl-synthesis/
    ...
  rtl-formalize-synthsis/
    ...

ann/
  src/
    model.py          # inference reference model

contract/
  src/
    gen_vectors.py    # test vector generation from contract weights
```

Equivalent file names are acceptable if responsibilities remain the same.

If branch-local simulation support exists, the directory structure must make the support boundary visible:

- shared vector assets must not be duplicated per branch unless the vector format itself differs
- `rtl/` must keep a baseline full-core bench
- `rtl-synthesis` may reuse the baseline bench when it preserves the `mlp_core` boundary
- `rtl-formalize-synthsis` may use a branch-local controller bench while it remains controller-only

## 7. Acceptance Criteria

The `simulations` domain is complete when:

1. The testbench can run inference end to end without manual intervention.
2. RTL outputs are automatically checked against Python-generated expectations.
3. Directed tests pass.
4. Generated regression vectors pass or produce actionable mismatch logs.
5. The simulation support boundary is explicit for `rtl/`, `rtl-synthesis`, and `rtl-formalize-synthsis`.
6. Any branch that is not yet full-core support is clearly labeled as mixed-path or controller-only rather than described as baseline-equivalent simulation support.
