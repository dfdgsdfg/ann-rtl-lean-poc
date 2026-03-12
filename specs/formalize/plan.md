# Formalize Implementation Plan

## 1. Goal

Close the remaining gaps between the updated formalization spec and the current Lean implementation.

The target end state is:

- the repository still builds cleanly with zero `sorry` in `formalize/src/`
- the hardware input domain remains explicit in Lean types
- hardware-facing storage and contract-domain arithmetic are genuinely bounded in their types, not only wrapped on some writes
- the full mandatory temporal theorem set is public, named, and re-exported from `Correctness.lean`
- the stronger guard-cycle and boundary obligations are stated and proved
- the exported theorem surface matches the requirement and design documents without hidden or private completion-critical lemmas

## 2. Current Implementation Baseline

The current tree already has:

- `MathInput` and `Input8`
- `toMathInput`
- a build-clean operational proof story over `step` and `run`
- a project-local temporal layer in `Temporal.lean`
- width-aware wrap functions and machine storage updates
- a green `lake build`

However, the implementation is still short of the updated spec in three important ways:

1. The hardware-facing bounded types are not yet strict enough.
2. The mandatory temporal theorem surface is incomplete at the public artifact level.
3. The guard-cycle and boundary proof obligations are not yet packaged as explicit theorems.

## 3. Gap Inventory

### 3.1 Type-Level Boundedness Gap

Current issue:

- `Hidden16` stores eight raw `Int` fields
- `Acc32` stores a raw `Int`
- `FixedPoint.lean` still defines contract-domain arithmetic helpers as plain `Int -> Int -> Int`

Why this matters:

- the spec now says unrestricted `Int` belongs only to the mathematical layer
- wrap-on-write is weaker than type-level boundedness
- reviewers cannot tell from the type signatures alone which values are hardware-domain and which are idealized math-domain

### 3.2 Fixed-Point Contract Model Gap

Current issue:

- `mlpFixed` is over `Input8`, but the intermediate arithmetic layer is still mostly plain `Int`
- the current bridge theorem is effectively equality through the current network bounds, not an explicitly typed hardware-domain arithmetic story

Why this matters:

- the spec now treats contract-domain arithmetic as a first-class formal layer
- the fixed-point model should not look like a thin alias of the mathematical model

### 3.3 Temporal Artifact-Surface Gap

Current issue:

- `Temporal.lean` currently advertises only seven public theorems
- `timedStep_done_hold` and `timedStep_done_restart` exist, but they are not part of the public theorem surface
- `phase_ordering_ok` is private
- `Correctness.lean` does not re-export the full mandatory theorem set from the updated spec

Why this matters:

- the requirement says the repository must clearly show which temporal theorems are mandatory and where they live
- completion-critical timing properties should not be hidden in helper lemmas

### 3.4 Boundary-Obligation Gap

Current issue:

- the implementation proves some phase transitions
- it does not yet expose a spec-tight theorem package for:
  - hidden guard cycle does no MAC work
  - output guard cycle does no MAC work
  - no duplicate or skipped work across boundary transitions
  - no out-of-range reads at the critical guard and exit boundaries
  - `BIAS_OUTPUT` as the register-update cycle
  - `DONE` as the first externally valid-completion cycle

Why this matters:

- the current spec is no longer satisfied by end-state correctness plus a few transition lemmas
- these are the main off-by-one and stale-data bug classes the formalization is supposed to rule out

## 4. Resolution Strategy

Resolve the remaining work in phases that minimize proof churn:

1. tighten the bounded hardware-domain types first
2. move the fixed-point layer onto those types
3. prove the stronger invariants and guard or boundary obligations
4. promote the completed temporal theorem set into the public artifact surface
5. finish with theorem-surface cleanup and verification

This order keeps the proof refactor localized:

- type and arithmetic changes happen before theorem naming is frozen
- temporal theorem export changes happen after the theorem set is complete
- final verification happens only after both arithmetic and timing surfaces are stable

## 5. Phase Plan

### Phase 0: Freeze The Remaining Contract Surface

Purpose:

- make the exact remaining deliverables explicit before changing the proof code again

Work items:

- pin the final public theorem names that must appear in `Temporal.lean` and `Correctness.lean`
- decide whether `phase_ordering_ok` remains mandatory as a public theorem or becomes a supporting theorem referenced by the stronger boundary package
- decide whether the fixed-point layer will expose bounded wrapper results directly or expose them through explicit `toInt` observation functions

Recommended public theorem set:

- `acceptedStart_eventually_done`
- `busy_during_active_window`
- `done_implies_outputValid`
- `output_stable_while_done`
- `done_hold_while_start_high`
- `done_to_idle_when_start_low`
- `phase_ordering_ok`
- `hiddenGuard_before_biasHidden`
- `lastHiddenNeuron_to_macOutput`
- `outputGuard_before_biasOutput`
- `biasOutput_registers_result`

Exit criteria:

- the final required theorem names are written down and agreed by the docs
- every remaining proof obligation has a home file

### Phase 1: Make Hardware-Domain Types Strictly Bounded

Status:

- pending

Purpose:

- remove the remaining hardware-facing `Int` leakage from the type layer

Work items:

- replace `Hidden16` raw `Int` fields with true bounded signed storage, for example `Int16` or a thin wrapper over `BitVec 16`
- replace `Acc32.toInt : Int` as stored state with a true bounded signed 32-bit representation
- add explicit observation and conversion helpers such as:
  - `Hidden16.toIntAt`
  - `Acc32.toInt`
  - constructor functions that define the wrap semantics once
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

### Phase 2: Refactor The Contract-Domain Fixed-Point Layer

Status:

- pending

Purpose:

- make `FixedPoint.lean` a real contract-domain model instead of an almost-math model over `Int`

Work items:

- define contract-domain arithmetic operators over the bounded wrapper types
- make the hidden-layer fixed-point result use bounded hidden storage directly
- make the output-accumulation path use bounded accumulator semantics directly
- separate:
  - the contract-domain computation
  - the mathematical interpretation of that computation
- restate the bridge theorem in a form that is explicit about interpretation, for example:
  - exact equality after interpretation if bounds rule out truncation
  - exact wrapped equivalence if truncation is part of the contract model

Files:

- `formalize/src/TinyMLP/FixedPoint.lean`
- `formalize/src/TinyMLP/Spec.lean`

Exit criteria:

- `mlpFixed` is visibly defined through contract-domain arithmetic
- the hardware-to-math bridge theorem states the relationship explicitly rather than collapsing the two layers by accident

### Phase 3: Refit Operational Proofs To The Strictly Bounded Model

Status:

- pending

Purpose:

- carry the type refactor through the machine and symbolic simulation proofs

Work items:

- update `step` and `run` proofs to use the strict bounded storage
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
- follow-up strengthening may still be needed if the stricter bounded-type refactor changes theorem statements

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

Purpose:

- ensure the repository is reviewable and reproducible as a completed formal artifact

Work items:

- align theorem names in code with `requirement.md` and `design.md`
- make sure `TinyMLP.lean` imports all required modules
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

- the build succeeds on the pinned toolchain
- the completion surface visible from `Correctness.lean` matches the docs
- no completion-critical theorem remains private or undocumented

## 6. File Ownership By Remaining Work

- `Spec.lean`
  - strict bounded wrapper definitions
  - mathematical interpretation helpers
  - width and bridge lemmas
- `FixedPoint.lean`
  - contract-domain arithmetic
  - bounded hidden and accumulator usage
  - explicit hardware-to-math bridge theorem
- `Machine.lean`
  - bounded machine storage
  - operational semantics over strict wrappers
- `Simulation.lean`
  - symbolic execution and bridge lemmas updated for the strict wrappers
  - boundary-support lemmas
- `Invariants.lean`
  - stronger per-phase invariants beyond simple index bounds
- `Temporal.lean`
  - public temporal vocabulary
  - mandatory theorem set
  - guard-cycle and exact boundary theorems
- `Correctness.lean`
  - final public theorem export surface

## 7. Recommended Execution Order

Use this order unless a proof dependency forces a local swap:

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 6
6. Phase 5
7. Phase 4
8. Phase 7

Rationale:

- bounded-type cleanup should happen before proving more timing properties on unstable storage definitions
- stronger invariants should exist before the final boundary package is finished
- public theorem export cleanup should happen after the theorem set itself is complete

## 8. Immediate Next Steps

1. Turn `Hidden16` and `Acc32` into truly bounded hardware-domain storage types.
2. Refactor `FixedPoint.lean` so contract-domain arithmetic is visibly bounded and no longer mostly plain `Int`.
3. Promote `done_hold_while_start_high`, `done_to_idle_when_start_low`, and `phase_ordering_ok` into the public theorem surface as required.
4. Add the explicit guard-cycle and `BIAS_OUTPUT` validity theorems.
5. Re-export the full mandatory theorem set from `Correctness.lean`.
