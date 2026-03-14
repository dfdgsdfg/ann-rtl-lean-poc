# Simulation Design

## 1. Design Goals

The simulation flow should be:

- Simple to run repeatedly
- Deterministic for debugging
- Shared across RTL, Python, and generated assets
- Structured so failures are easy to localize
- Explicit about which RTL implementation branch a bench supports

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

The `train` command with default settings automatically freezes the contract and regenerates downstream artifacts (including `simulations/shared/test_vectors.mem`). Use `--skip-export` to train without freezing.

`make sim` is the canonical regression entry point. It runs the same SystemVerilog bench through both `Icarus Verilog` and `Verilator`, and the regression fails if either simulator fails.

Branch-specific simulation entry points should remain separate from the canonical baseline command:

- `make sim`: full-core regression for the hand-written `rtl/` implementation
- `make rtl-synthesis-sim`: mixed-path regression that swaps in the synthesized controller while keeping the hand-written datapath and shared vectors
- `make rtl-formalize-synthesis-sim`: shared full-core regression for the Sparkle-generated `rtl-formalize-synthesis` wrapper at the `mlp_core` boundary

The simulation layer must say plainly what the branch generates, how it is integrated, and where it is validated:

- full-core generation and full-core `mlp_core` validation
- controller generation with mixed-path `mlp_core` validation against the baseline datapath
- controller-scoped trace/equivalence validation when a branch-local comparison bench is used

The user should not need to manually copy weights or hand-edit vectors after training.

Vector generation should synthesize dedicated positive, zero, and negative score witnesses during freeze. If the deterministic candidate pool cannot provide one of those classes, freeze should fail before the simulator runs.

## 4. Supported RTL Branches

The simulation design supports three RTL implementation tracks with different current scopes:

- `rtl/`: the canonical full-core implementation and the source of the shared vector-driven regression bench
- `rtl-synthesis`: a controller-generated flow that is simulated as a mixed path by reusing the baseline datapath and replacing the controller module boundary
- `rtl-formalize-synthesis`: a Sparkle-generated full-core path that is simulated at the shared `mlp_core` boundary

This split is intentional as long as the scope is declared in commands, summaries, and experiment notes.

## 5. Testbench Design

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

Two bench styles are expected:

- Shared full-core bench: used by `rtl/` and by any mixed-path branch that preserves the `mlp_core` boundary and vector format
- Branch-local controller bench: used when a generated implementation only claims controller equivalence or handshake/phase parity

When a branch-local bench is used, the scope statement must explain why the shared full-core bench is not yet the right support boundary.

## 6. Regression Strategy

The initial regression plan should include:

- Small directed vectors with known hand-computed outcomes
- Broader generated vectors from the Python toolchain
- Repeated runs using the same exported constants

Once the datapath is stable, the regression suite can expand to random sweeps and corner-case stress tests.

For multi-branch support, each regression result should also record:

- implementation branch: `rtl/`, `rtl-synthesis`, or `rtl-formalize-synthesis`
- generation scope, integration scope, and validation scope
- bench identity: shared vector bench or branch-local comparison bench
- contract/vector provenance shared across the compared branches

## 7. Asset Flow

The simulation assets should move in one direction:

```text
Python model -> quantized constants -> RTL ROM/test vectors -> simulation results
```

This avoids maintaining duplicate weight definitions by hand.

The generated vector file should remain plain text, but it should carry enough information for the bench to distinguish positive, zero, and negative expected scores instead of only the final class bit.

The frozen contract and generated vectors are the common semantic anchor for `rtl/`, `rtl-synthesis`, and `rtl-formalize-synthesis`.

## 8. Recommended Layout

The simulation directory should separate shared assets from branch-local benches.

Recommended structure:

```text
simulations/
  shared/
    test_vectors.mem
    test_vectors_meta.svh
  rtl/
    testbench.sv
  rtl-synthesis/
    ...
```

Layout rules:

- shared vectors and include files should live in one common location
- the baseline full-core bench should stay distinct from controller-scoped comparison benches
- `rtl-synthesis` should reuse the shared full-core bench when it is only swapping the controller boundary
- `rtl-formalize-synthesis` should reuse the shared full-core bench when it preserves the `mlp_core` boundary
- branch-local simulation files should be named so their scope is obvious from the path alone

## 9. Debugging Plan

When a mismatch occurs, the flow should make it easy to answer:

- Was the vector generation wrong?
- Was the ROM export wrong?
- Was the RTL state schedule wrong?
- Was the expected output based on a different arithmetic interpretation?
- Was the failure in the baseline branch, a mixed-path replacement, or a controller-scoped branch-local bench?

For that reason, the simulation harness should prefer plain text or machine-readable exported vectors over hidden ad hoc stimuli.
