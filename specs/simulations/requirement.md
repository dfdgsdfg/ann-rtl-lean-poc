# Simulation Requirements

## 1. Purpose

This document defines the requirements for validating the Tiny Neural Inference ASIC through simulation.

The `simulations` domain covers:

- RTL testbench behavior
- Python reference-model comparison
- Test-vector generation
- Regression and pass or fail criteria
- Declared simulation support boundaries for `rtl/`, `rtl-synthesis`, and `rtl-formalize-synthesis`

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
- `rtl-synthesis`: mixed-path simulation support that preserves the baseline datapath contract and vector format while replacing the controller implementation, but exposes that compared assembly through a branch-local `rtl-synthesis/sv/` tree
- `rtl-formalize-synthesis`: full-core simulation support against the shared `mlp_core` bench once the emitted Sparkle wrapper preserves that top-level boundary

Each simulation entry point, summary, or experiment note must state:

- which branch is under test
- the generation scope, integration scope, and validation scope
- whether the bench is shared with the baseline or branch-local
- which normalized branch-local export tree supplied the RTL under test

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

Any controller-scoped branch-local benches that still exist elsewhere in the repository must also include:

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
  rtl-formalize-synthesis/
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
- `rtl-formalize-synthesis` should reuse the shared full-core bench when it preserves the `mlp_core` boundary
- branch comparison and downstream simulation inputs should resolve through `rtl/sv/`, `rtl-synthesis/sv/`, and `rtl-formalize-synthesis/sv/`
- if a generated branch reuses baseline RTL, that reuse must appear inside the branch-local `sv/` tree via symlink or override rather than through hidden direct bench references to `rtl/src/`
- each branch should expose at least `blueprint/mlp_core.svg` as the normalized top-level schematic artifact paired with the compared RTL tree

## 7. Acceptance Criteria

The `simulations` domain is complete when:

1. The testbench can run inference end to end without manual intervention.
2. RTL outputs are automatically checked against Python-generated expectations.
3. Directed tests pass.
4. Generated regression vectors pass or produce actionable mismatch logs.
5. The simulation support boundary is explicit for `rtl/`, `rtl-synthesis`, and `rtl-formalize-synthesis`.
6. Any branch that is not yet full-core end-to-end support is clearly labeled with its generation, integration, and validation scopes rather than described as baseline-equivalent simulation support.
7. The compared RTL for each branch is discoverable through its branch-local `sv/` export tree.
8. Each branch exposes at least `blueprint/mlp_core.svg` as the normalized top-level schematic artifact.
