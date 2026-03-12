# Formalize Implementation Plan

## 1. Goal

Close the remaining gaps between the updated formalization requirement and the current Lean implementation.

The target end state is:

- the repository still builds cleanly with zero `sorry` in `formalize/src/`
- the hardware input domain remains explicit in Lean types
- hardware-facing storage and contract-domain arithmetic are genuinely bounded in their types, not only wrapped on some writes
- the fixed-point layer is a real contract-domain implementation model, not a thin wrapper around the mathematical spec
- the output datapath explicitly models the `int16 × int8 → int24 → int32` contract
- the full mandatory temporal theorem set is public, named, and re-exported from `Correctness.lean`
- the stronger guard-cycle and boundary obligations are stated and proved
- the exported theorem surface matches the requirement and design documents without hidden or private completion-critical lemmas
- the reproducibility instructions match the actual repository entrypoint and pinned toolchain

## 2. Current Implementation Baseline

The current tree already has:

- `MathInput` and `Input8`
- `toMathInput`
- bounded wrappers for `Hidden16` and `Acc32`
- a build-clean operational proof story over `step` and `run`
- a project-local temporal layer in `Temporal.lean`
- the current public temporal theorem package and `Correctness.lean` re-exports
- a green `lake build` from `formalize/`

The main remaining work is no longer in the machine state or temporal theorem surface.
It is in the contract-domain arithmetic layer and the final artifact cleanup around it.

## 3. Remaining Gaps

### 3.1 Fixed-Point Contract Model Gap

Current issue:

- `hiddenFixedAt` is still defined by wrapping `hiddenSpecAt8`
- `hiddenFixed` is still `Hidden16.ofHidden (hiddenSpec8 input)`
- `outputScoreFixed` is still `Acc32.ofInt (outputScoreSpecFromHidden16 ...)`
- the current fixed-point bridge theorem simplifies mainly because the fixed-point layer is built from the spec layer directly

Why this matters:

- the requirement demands a distinct fixed-point implementation model
- the repository should check agreement between two layers, not repackage one layer as the other
- the current proof story would hide bugs in the intended contract-domain arithmetic layer

### 3.2 Width-Fidelity And Typed-Arithmetic Gap

Current issue:

- `mul16x8To24` currently returns `Acc32` instead of an explicit `Int24`-bounded result
- the output MAC path jumps directly from hidden activation and weight to the accumulator
- `Hidden16` already stores bounded cells, but the machine still writes activations through `Int` round-trips
- some hardware-adjacent helper definitions over `Input8` or `Hidden16` still expose unrestricted `Int` as the primary interface

Why this matters:

- the requirement calls out the `int16 × int8 → int24` stage explicitly
- typed boundaries are what make the hardware-contract layer reviewable
- the fixed-point layer should stay inside bounded representations until the explicit interpretation step

### 3.3 Reproducibility And Artifact-Surface Gap

Current issue:

- the requirement says `lake build` should work from the repository root, but the current Lean project still lives under `formalize/`
- the requirement text still mentions Lean `v4.28.0`, while the checked-in `formalize/lean-toolchain` is newer
- the remaining implementation plan should point reviewers at the fixed-point refactor as the primary open milestone

Why this matters:

- reviewers need the docs to describe the real entrypoint and open work
- reproducibility is part of the acceptance contract, not just a convenience note

## 4. Resolution Strategy

Resolve the remaining work in the following order:

1. keep the current bounded storage layer as the foundation
2. replace the fixed-point spec shortcuts with explicit bounded folds and an explicit `Int24` output-product stage
3. propagate the remaining typed-helper cleanup through the machine and simulation proofs
4. finish with artifact-surface and reproducibility cleanup

This order keeps proof churn localized:

- the machine and temporal layers already build over bounded state, so the next change should target the contract-domain arithmetic directly
- the fixed-point refactor should land before any final cleanup of theorem-surface wording
- reproducibility cleanup should happen after the code surface is stable enough that the docs stop moving

## 5. Phase Plan

### Phase 0: Freeze The Remaining Contract Surface

Status:

- completed for the current theorem and file surface

Purpose:

- make the exact remaining deliverables explicit before changing the proof code again

Work items:

- pin the final public theorem names that must appear in `Temporal.lean` and `Correctness.lean`
- decide whether `phase_ordering_ok` remains mandatory as a public theorem or becomes a supporting theorem referenced by the stronger boundary package
- decide whether the fixed-point layer will expose bounded wrapper results directly or expose them through explicit `toInt` observation functions

Exit criteria:

- the final required theorem names are written down and agreed by the docs
- every remaining proof obligation has a home file

### Phase 1: Make Hardware-Domain Types Strictly Bounded

Status:

- completed for machine storage and the primary bounded wrappers

Purpose:

- remove the remaining hardware-facing `Int` leakage from the type layer

Work items:

- replace `Hidden16` raw `Int` fields with true bounded signed storage
- replace raw accumulator storage with a true bounded signed 32-bit representation
- add explicit observation and conversion helpers such as:
  - `Hidden16.toIntAt`
  - `Acc32.toInt`
  - constructor functions that define wrap semantics once
- keep unrestricted `Int` only in:
  - `MathInput`
  - `mlpSpec`
  - bridge lemmas that interpret bounded values mathematically

Files:

- `formalize/src/TinyMLP/Spec.lean`
- `formalize/src/TinyMLP/FixedPoint.lean`
- `formalize/src/TinyMLP/Machine.lean`

Exit criteria:

- hardware-facing machine storage is bounded in its type definitions, not only by helper functions
- no hardware-facing state field is a naked unrestricted `Int`
- residual helper-surface `Int` leakage is tracked separately in Phase 2

### Phase 2: Refactor The Contract-Domain Fixed-Point Layer

Status:

- pending
- this is now the primary remaining implementation task

Purpose:

- make `FixedPoint.lean` a real contract-domain model instead of an almost-math model over `Int`

Work items:

- define typed views of the embedded constants, for example bounded input weights, output weights, and bias terms
- keep `mul8x8To16` as the hidden-product primitive over hardware-domain operands
- change `mul16x8To24` to return an explicit `Int24`-bounded result
- add explicit lifts from `Int16` and `Int24` products into the `Acc32` accumulator domain
- define hidden pre-activation and output-score computations as explicit bounded folds, not by wrapping `hiddenSpec8` or `outputScoreSpec8`
- add a typed hidden-cell setter so the machine can write `relu16` results without `Int` round-trips
- separate:
  - the contract-domain computation
  - the mathematical interpretation of that computation
- restate the bridge theorem in a form that is explicit about interpretation, for example:
  - exact equality after interpretation if bounds rule out truncation
  - exact wrapped equivalence if truncation is part of the contract model

Files:

- `formalize/src/TinyMLP/FixedPoint.lean`
- `formalize/src/TinyMLP/Spec.lean`
- `formalize/src/TinyMLP/Machine.lean`

Exit criteria:

- `hiddenFixedAt`, `hiddenFixed`, and `outputScoreFixed` are visibly defined through contract-domain arithmetic
- the output path has an explicit `Int24` stage before accumulation into `Acc32`
- the machine no longer writes hidden activations by converting bounded values to `Int` and immediately re-wrapping them
- the hardware-to-math bridge theorem states the relationship explicitly rather than collapsing the two layers by accident

### Phase 3: Refit Operational Proofs To The Strictly Bounded Model

Status:

- completed for the current bounded-state model
- small follow-up proof edits may still be needed after Phase 2 changes

Purpose:

- carry the type refactor through the machine and symbolic simulation proofs

Work items:

- update `step` and `run` proofs to use strict bounded storage
- keep the control projection proof structure intact where possible
- replace proofs that rely on raw `Int` extensionality with proofs over bounded constructor or observation lemmas
- preserve the existing end-state theorems:
  - `rtl_terminates`
  - `rtl_correct`

Files:

- `formalize/src/TinyMLP/Machine.lean`
- `formalize/src/TinyMLP/Simulation.lean`
- `formalize/src/TinyMLP/Invariants.lean`

Exit criteria:

- end-state correctness and termination still build over the stricter storage model
- the control projection and symbolic simulation lemmas still compose cleanly

### Phase 4: Complete The Public Temporal Theorem Surface

Status:

- completed

Purpose:

- expose the actual mandatory timing contract as top-level theorems

Work items:

- promote `timedStep_done_hold` to a public theorem with the spec-facing name `done_hold_while_start_high`
- promote `timedStep_done_restart` to a public theorem with the spec-facing name `done_to_idle_when_start_low`
- decide whether `phase_ordering_ok` should remain public; if yes, make it non-private and export it
- update the theorem list comment in `Temporal.lean` to match the real public surface
- re-export the full temporal theorem set from `Correctness.lean`

Files:

- `formalize/src/TinyMLP/Temporal.lean`
- `formalize/src/TinyMLP/Correctness.lean`
- `formalize/src/TinyMLP.lean`

Exit criteria:

- every mandatory theorem from the requirement appears as a public theorem
- `Correctness.lean` clearly shows milestone completion without readers having to inspect helper lemmas

### Phase 5: Prove Guard-Cycle And Boundary Obligations

Status:

- completed for the current public theorem package
- follow-up strengthening may still be needed if the fixed-point refactor changes theorem statements

Purpose:

- close the main remaining spec-to-proof gap in the timing layer

Work items:

- add explicit hidden-guard-cycle theorems:
  - after the fourth hidden MAC, `inputIdx = 4`
  - the next cycle is a guard cycle in `MAC_HIDDEN`
  - that guard cycle performs no MAC work
  - the successor phase is `BIAS_HIDDEN`
- add explicit output-guard-cycle theorems:
  - after the eighth output MAC, `inputIdx = 8`
  - the next cycle is a guard cycle in `MAC_OUTPUT`
  - that guard cycle performs no MAC work
  - the successor phase is `BIAS_OUTPUT`
- prove the no-duplicate and no-skip obligations for the last hidden and output iterations
- prove the critical no-out-of-range-read obligations at the boundary cycles
- prove that `BIAS_OUTPUT` writes the final result register and that `DONE` is the first externally valid-completion cycle

Recommended theorem names:

- `hiddenGuard_before_biasHidden`
- `outputGuard_before_biasOutput`
- `boundary_no_duplicate_or_skip_work`
- `boundary_no_out_of_range_reads`
- `biasOutput_registers_result`

Files:

- `formalize/src/TinyMLP/Temporal.lean`
- `formalize/src/TinyMLP/Simulation.lean`
- `formalize/src/TinyMLP/Invariants.lean`

Exit criteria:

- the guard-cycle semantics are proved explicitly, not only inferred from control transitions
- the boundary theorems rule out the specific stale-value and off-by-one failure modes named in the spec

### Phase 6: Strengthen Invariants To Support The Boundary Proofs

Status:

- deferred unless the fixed-point refactor exposes a proof gap that needs stronger reusable invariants

Purpose:

- move from simple index bounds to the stronger per-phase reasoning the updated spec expects

Work items:

- retain `IndexInvariant`
- add phase-sensitive invariants for:
  - partial hidden MAC sums
  - partial output MAC sums
  - which hidden slots are already committed
  - which hidden slots are not yet semantically relevant
  - output stability in `DONE`
- use these invariants to support the no-duplicate, no-skip, and no-stale-value theorems

Files:

- `formalize/src/TinyMLP/Invariants.lean`
- `formalize/src/TinyMLP/Simulation.lean`
- `formalize/src/TinyMLP/Temporal.lean`

Exit criteria:

- the stronger boundary theorems are backed by reusable invariants, not only ad hoc symbolic reductions

### Phase 7: Final Artifact Cleanup And Verification

Status:

- pending

Purpose:

- ensure the repository is reviewable and reproducible as a completed formal artifact

Work items:

- align theorem names in code with `requirement.md` and `design.md`
- make sure `TinyMLP.lean` imports all required modules
- decide whether to make the repository root itself a Lean entrypoint or to narrow the reproducibility instructions to `cd formalize && lake build`
- align the documented pinned toolchain version with the checked-in `lean-toolchain`
- verify that `Correctness.lean` shows:
  - top-level functional theorem
  - top-level termination theorem
  - explicit hardware-to-math bridge theorem
  - complete temporal theorem exports
- run:
  - `lake build`
  - `rg -n "\\bsorry\\b|\\baxiom\\b" formalize/src`
- update any stale comments or theorem-surface summaries in module headers

Exit criteria:

- the build succeeds on the documented toolchain using the documented entrypoint
- the completion surface visible from `Correctness.lean` matches the docs
- no completion-critical theorem remains private or undocumented

## 6. File Ownership By Remaining Work

- `Spec.lean`
  - bounded wrapper definitions
  - mathematical interpretation helpers
  - width and bridge lemmas
  - typed hidden-cell update helpers
- `FixedPoint.lean`
  - contract-domain arithmetic
  - explicit hidden and output folds
  - `Int24` output-product stage
  - explicit hardware-to-math bridge theorem
- `Machine.lean`
  - bounded machine storage updates that consume the typed fixed-point helpers directly
- `Simulation.lean`
  - symbolic execution and bridge lemmas updated for the true fixed-point layer
- `Invariants.lean`
  - stronger reusable invariants only if Phase 2 follow-up requires them
- `Temporal.lean`
  - already-completed public temporal vocabulary and mandatory theorem set
  - follow-up boundary statement adjustments only if the fixed-point refactor forces them
- `Correctness.lean`
  - final public theorem export surface
  - final artifact-surface cleanup

## 7. Recommended Execution Order

Use this order unless a proof dependency forces a local swap:

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 5
6. Phase 4
7. Phase 7

Rationale:

- bounded-type cleanup has already landed in the state layer
- the fixed-point refactor is now the only remaining implementation change large enough to perturb proofs
- public theorem export work is already complete for the current theorem package
- reproducibility cleanup should happen after the code surface stops moving

## 8. Immediate Next Steps

1. Replace the current fixed-point shortcuts with explicit bounded hidden-layer and output-layer folds in `FixedPoint.lean`.
2. Introduce the explicit `Int24` output-product stage and typed lifts into `Acc32`.
3. Add the typed hidden-cell write path and remove the remaining machine-side `Int` round-trip for hidden activations.
4. Refit any simulation lemmas that depended on the old shortcut definitions.
5. After the fixed-point layer is stable, clean up the reproducibility docs and verify the final artifact surface again.
