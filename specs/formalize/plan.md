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
- explicit contract-domain hidden and output folds in `FixedPoint.lean`
- an explicit `Int24` output-product stage with typed lifts into `Acc32`
- a typed hidden-cell write path in `Machine.lean`
- a build-clean operational proof story over `step` and `run`
- a project-local temporal layer in `Temporal.lean`
- the current public temporal theorem package and `Correctness.lean` re-exports
- a green `cd formalize && lake build`

The main remaining work is now in artifact-surface cleanup and in deciding whether the stronger boundary-theorem package stays in scope for this milestone.

## 3. Remaining Gaps

### 3.1 Artifact-Surface And Naming Gap

Current issue:

- the docs still blur goal predicates such as `rtlCorrectnessGoal` / `rtlTerminationGoal` with the proved theorem names `rtl_correctness_goal` / `rtl_terminates_goal`
- reviewers still need a single place where the current public theorem export surface is listed without having to infer it from helper lemmas
- the implementation plan should no longer point readers at a fixed-point refactor that has already landed in code

Why this matters:

- acceptance criteria should reference the identifiers that are actually proved and exported
- reviewers need the docs to match the checked-in artifact surface exactly
- stale implementation guidance sends work back into already-completed code

### 3.2 Boundary-Theorem Scope Gap

Current issue:

- the current public temporal surface proves the guard-cycle phase transitions and `biasOutput_registers_result`
- stronger no-duplicate/no-skip/no-out-of-range boundary theorems are not yet part of the exported surface under the names suggested in this plan
- the docs currently risk implying that Phase 5 is fully complete even if those stronger statements remain desired

Why this matters:

- the acceptance contract must say clearly whether the current exported boundary package is sufficient
- otherwise reviewers cannot tell whether missing stronger boundary theorems are a defect or intentionally deferred work
- Phase 5 status should reflect the real theorem surface rather than an older plan snapshot

### 3.3 Reproducibility And Artifact-Surface Gap

Current issue:

- the final docs and verification checklist must consistently use `cd formalize && lake build`, because the Lean project lives under `formalize/`
- the remaining implementation plan should point reviewers at artifact-surface cleanup and any deliberate boundary-proof strengthening as the primary open work

Why this matters:

- reviewers need the docs to describe the real entrypoint and open work
- reproducibility is part of the acceptance contract, not just a convenience note

## 4. Resolution Strategy

Resolve the remaining work in the following order:

1. treat the current bounded storage and fixed-point layers as the landed foundation
2. align the docs and theorem-surface naming with the checked-in code
3. decide whether the stronger boundary theorems remain milestone-critical; if yes, add them as a scoped follow-up
4. finish with artifact-surface and reproducibility cleanup

This order keeps proof churn localized:

- the code already contains the bounded arithmetic refactor, so the next edits should not reopen that implementation surface
- theorem-surface wording and milestone scope should be settled before any optional boundary-proof strengthening
- reproducibility cleanup should happen after the docs reflect the actual exported artifact

## 5. Phase Plan

### Phase 0: Freeze The Remaining Contract Surface

Status:

- completed for the current theorem and file surface

Purpose:

- make the exact remaining deliverables explicit before changing the proof code again

Work items:

- pin the final public theorem names that must appear in `Temporal.lean` and `Correctness.lean`
- decide whether `phase_ordering_ok` remains mandatory as a public theorem or becomes a supporting theorem referenced by the stronger boundary package
- distinguish goal predicates from proof theorems in the reviewer-facing docs

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
- no remaining blocker in the bounded storage layer prevents milestone cleanup

### Phase 2: Refactor The Contract-Domain Fixed-Point Layer

Status:

- completed in the current codebase

Purpose:

- record the contract-domain arithmetic refactor that is now part of the checked-in implementation

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
- no remaining proof refit is planned unless later theorem-surface cleanup uncovers a localized issue

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

- partially completed in the current public theorem package
- guard-cycle transition theorems and `biasOutput_registers_result` are already public
- stronger no-duplicate/no-skip/no-out-of-range formulations remain optional follow-up unless they stay mandatory in the acceptance docs

Purpose:

- close the main remaining spec-to-proof gap in the timing layer

Work items:

- decide whether the stronger boundary obligations below remain milestone-critical or move to explicit follow-up scope
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

- deferred unless Phase 5 strengthening stays in scope and needs stronger reusable invariants

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
- standardize the reproducibility instructions on `cd formalize && lake build`
- align the documented pinned toolchain version with the checked-in `lean-toolchain`
- verify that `Correctness.lean` shows:
  - top-level functional theorem
  - top-level termination theorem
  - explicit hardware-to-math bridge theorem
  - complete temporal theorem exports
- run:
  - `cd formalize && lake build`
  - `rg -n "\\bsorry\\b|\\baxiom\\b" formalize/src`
- update any stale comments or theorem-surface summaries in module headers

Exit criteria:

- the build succeeds on the documented toolchain using the documented entrypoint
- the completion surface visible from `Correctness.lean` matches the docs
- no completion-critical theorem remains private or undocumented

## 6. File Ownership By Remaining Work

- `Spec.lean`
  - no planned milestone-critical edits unless boundary-proof strengthening needs extra helper lemmas
- `FixedPoint.lean`
  - no planned milestone-critical refactor; current code is the landed contract-domain arithmetic layer
- `Machine.lean`
  - no planned milestone-critical edits unless theorem-surface cleanup reveals a small supporting lemma gap
- `Simulation.lean`
  - supporting lemmas only if optional boundary-proof strengthening stays in scope
- `Invariants.lean`
  - stronger reusable invariants only if Phase 5/6 strengthening stays in scope
- `Temporal.lean`
  - already-completed public temporal vocabulary and mandatory theorem set
  - follow-up boundary statement adjustments only if the stronger theorem package remains in scope
- `Correctness.lean`
  - final public theorem export surface
  - final artifact-surface cleanup
- `specs/formalize/*.md`
  - align milestone language with the current codebase and documented entrypoint

## 7. Recommended Execution Order

Use this order unless a proof dependency forces a local swap:

1. Phase 0
2. Phase 7
3. Phase 5
4. Phase 6

Rationale:

- the bounded-type and fixed-point refactors have already landed
- the next required work is reviewer-facing cleanup, not reopening the arithmetic model
- only after the docs are aligned should the project decide whether the stronger boundary package stays in scope

## 8. Immediate Next Steps

1. Align `requirement.md`, `design.md`, and `plan.md` with the current public theorem names and exported artifact surface.
2. Decide whether the stronger Phase 5 boundary theorems remain milestone-critical or move to explicit follow-up scope.
3. If those stronger boundary theorems remain in scope, add and export them from `Temporal.lean` and `Correctness.lean`.
4. Re-run `cd formalize && lake build` and `rg -n "\\bsorry\\b|\\baxiom\\b" formalize/src` after the final doc and theorem-surface cleanup.
