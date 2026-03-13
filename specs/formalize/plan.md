# Formalize Implementation Plan

## 1. Goal

Close the remaining gap between the current Lean implementation and the updated formalization contract.

The target end state for this milestone is:

- the repository builds cleanly with zero `sorry` in `formalize/src/`
- hardware-domain values are bounded in their storage types
- controller indices remain `Nat`, but their legal ranges are stated and proved through invariants
- the strong boundary theorem package is proved as public milestone scope
- `Correctness.lean` exposes the full reviewer-facing theorem surface
- the docs and reproducibility instructions match the checked-in artifact

## 2. Accepted Modeling Decisions

This plan adopts the following current project decisions:

- **Value boundedness**: hardware-facing value storage is bounded in Lean types, for example `Input8`, `Hidden16`, `Acc32`, and the explicit `Int24` output-product stage
- **Index discipline**: `hiddenIdx` and `inputIdx` remain `Nat` in the machine model; their admissible ranges are enforced by invariants and phase-specific proof lemmas, not by changing the field types in this milestone
- **Boundary scope**: the stronger boundary package is milestone-critical, not optional follow-up
- **Temporal layer**: the project-local finite-trace layer in `Temporal.lean` remains the proof-facing timing vocabulary
- **Reproducibility entrypoint**: the canonical verification command is `cd formalize && lake build`

## 3. Current Implementation Baseline

The current tree already provides:

- `MathInput`, `Input8`, and `toMathInput`
- bounded wrappers for hidden values, accumulator values, and intermediate products
- explicit contract-domain hidden and output folds in `FixedPoint.lean`
- an explicit `Int24` stage for the output product before accumulation into `Acc32`
- a machine model in which value storage is bounded, while indices are tracked as `Nat`
- a basic index-safety layer via `IndexInvariant`, plus preservation across `step` and `run`
- an operational proof story over `step`, `run`, and `controlRun`
- a project-local temporal layer and the current public temporal theorem package
- a green `cd formalize && lake build`

What is not finished yet is the stronger boundary proof package and the final artifact-surface cleanup around those proofs.

## 4. Current Spec-Implementation Gap

### 4.1 Boundedness Story Gap

The codebase is no longer aiming for "every hardware-facing field is itself a bounded index type".

The current implemented design is:

- value storage is bounded in types
- index ranges are enforced by invariants

The remaining work is therefore not to refactor `hiddenIdx` and `inputIdx` away from `Nat`. The remaining work is to make the invariant story explicit, reusable, and strong enough to discharge the boundary obligations now required by the spec.

### 4.2 Strong Boundary Theorem Gap

The current public theorem surface already covers:

- accepted start reaches `done`
- `busy` during the active window
- `done` implies output validity
- output stability while remaining in `done`
- `done ∧ start` holds the machine in `done`
- `done ∧ ¬start` returns the machine to `idle`
- phase-ordering and boundary-transition facts
- `biasOutput_registers_result`

The missing milestone-critical gap is that the public proof surface does not yet fully state and prove:

- guard cycles perform no MAC work
- boundary steps do not duplicate required work
- boundary steps do not skip required work
- boundary steps do not perform out-of-range reads

### 4.3 Artifact-Surface Gap

The docs and plan must reflect the checked-in artifact exactly:

- goal predicates and proved theorems must be distinguished clearly
- the strong boundary package must be listed as required scope
- the boundedness story must say "bounded values plus invariant-backed indices"
- reviewer-facing docs must point at the actual public theorem surface in `Correctness.lean`

## 5. Resolution Strategy

Resolve the remaining work in the following order:

1. treat the current bounded value-storage model as the landed foundation
2. strengthen the invariant layer so `Nat`-indexed control state is justified everywhere it matters
3. prove and export the missing strong boundary theorems
4. finish with artifact-surface cleanup and reproducibility verification

This order keeps proof churn localized:

- the arithmetic and bounded-value refactor is already landed, so it should not be reopened without a concrete blocker
- the next real technical dependency is stronger invariant support for the boundary proofs
- only after the proof surface is complete should the docs be frozen as final reviewer-facing artifacts

## 6. Phase Plan

### Phase 0: Freeze The Current Contract Interpretation

Status:

- completed

Purpose:

- make the current milestone interpretation explicit before more proofs are added

Work items:

- record that value storage is bounded in types
- record that index ranges are enforced by invariants rather than bounded index field types
- record that the strong boundary package is mandatory for milestone completion

Exit criteria:

- this plan matches the current intended contract surface

### Phase 1: Treat Bounded Value Storage As Landed Foundation

Status:

- completed

Purpose:

- avoid reopening already-landed arithmetic and storage work

Work items:

- preserve `Input8`, `Hidden16`, `Acc32`, and the explicit `Int24` output path as the current foundation
- preserve the current hardware-to-math bridge structure
- avoid new representation churn unless a missing theorem genuinely requires a local helper lemma

Files:

- `formalize/src/TinyMLP/Spec.lean`
- `formalize/src/TinyMLP/FixedPoint.lean`
- `formalize/src/TinyMLP/Machine.lean`

Exit criteria:

- no milestone-critical work remains on bounded value storage itself

### Phase 2: Strengthen The Invariant Story For Nat-Indexed Control State

Status:

- pending

Purpose:

- make the `Nat`-indexed controller model precise enough to support the stronger boundary package

Work items:

- retain `IndexInvariant` as the baseline bound:
  - `hiddenIdx ≤ hiddenCount`
  - `inputIdx ≤ hiddenCount`
- add phase-sensitive lemmas that explain what the index values mean in each relevant phase
- add lemmas that distinguish useful MAC cycles from guard cycles
- add the minimum additional invariants needed to support no-duplicate, no-skip, and no-out-of-range-read boundary proofs
- ensure these lemmas are reusable from `Simulation.lean` and `Temporal.lean`, not only ad hoc simplifications inside one theorem

Files:

- `formalize/src/TinyMLP/Invariants.lean`
- `formalize/src/TinyMLP/Simulation.lean`
- `formalize/src/TinyMLP/Temporal.lean`

Exit criteria:

- every proof that relies on a legal index or boundary condition has an explicit invariant or phase lemma to cite
- the invariant layer is strong enough to support the missing boundary theorems without changing the machine field types

### Phase 3: Prove The Strong Boundary Package

Status:

- pending

Purpose:

- close the main remaining spec-to-proof gap

Work items:

- preserve the current public transition theorems and build on top of them
- add explicit theorems that the hidden and output guard cycles perform no MAC work
- add explicit no-duplicate and no-skip theorems for the final hidden and output boundary steps
- add explicit no-out-of-range-read theorems for the relevant boundary cycles
- connect those theorems to the existing `biasOutput_registers_result` observability result so the full `BIAS_OUTPUT`/`DONE` story is public and reviewable

Recommended theorem families:

- hidden guard-cycle no-work theorem
- output guard-cycle no-work theorem
- boundary no-duplicate/no-skip theorem
- boundary no-out-of-range-read theorem
- any small helper theorems needed to expose the final public statement cleanly

Files:

- `formalize/src/TinyMLP/Temporal.lean`
- `formalize/src/TinyMLP/Simulation.lean`
- `formalize/src/TinyMLP/Invariants.lean`

Exit criteria:

- the strong boundary package required by the spec is proved
- reviewers do not need to infer no-work or no-out-of-range behavior indirectly from weaker transition lemmas

### Phase 4: Finalize The Public Theorem Surface

Status:

- pending

Purpose:

- make the milestone completion surface visible in one place

Work items:

- keep goal predicates and proved theorems clearly separated
- ensure every milestone-critical theorem has a public home in `Temporal.lean` or a public wrapper in `Correctness.lean`
- update theorem-surface comments to match the actual exported artifact
- make sure the final public surface includes the stronger boundary package as named theorems

Files:

- `formalize/src/TinyMLP/Temporal.lean`
- `formalize/src/TinyMLP/Correctness.lean`
- `formalize/src/TinyMLP.lean`

Exit criteria:

- a reviewer can inspect `Correctness.lean` and see the full milestone theorem surface without hunting through helper lemmas

### Phase 5: Final Artifact Cleanup And Verification

Status:

- pending

Purpose:

- ensure the repository is reviewable and reproducible as a completed formal artifact

Work items:

- align `requirement.md`, `design.md`, and `plan.md` with the final theorem surface
- standardize the boundedness language on "bounded value storage plus invariant-backed indices"
- verify the documented toolchain and build entrypoint
- run:
  - `cd formalize && lake build`
  - `rg -n "\\bsorry\\b|\\baxiom\\b" formalize/src`
- update any stale theorem-surface comments or reviewer guidance

Exit criteria:

- the build succeeds on the documented toolchain using the documented entrypoint
- the docs match the checked-in theorem surface
- no completion-critical theorem remains private or undocumented

## 7. File Ownership By Remaining Work

- `Spec.lean`
  - no planned milestone-critical representation refactor
  - only local helper lemmas if a boundary proof needs them
- `FixedPoint.lean`
  - no planned milestone-critical refactor
  - only local helper lemmas if a boundary proof needs them
- `Machine.lean`
  - no planned change to the index field types in this milestone
  - small helper lemmas only if needed to support invariant-backed reasoning
- `Invariants.lean`
  - primary home for the strengthened index and phase-sensitive invariant layer
- `Simulation.lean`
  - operational lemmas that connect the strengthened invariants to boundary behavior
- `Temporal.lean`
  - primary home for the public strong boundary theorem package
- `Correctness.lean`
  - final public reviewer-facing theorem surface
- `specs/formalize/*.md`
  - final artifact-surface and reproducibility alignment

## 8. Recommended Execution Order

Use this order unless a local proof dependency forces a swap:

1. Phase 2
2. Phase 3
3. Phase 4
4. Phase 5

Rationale:

- the bounded-value foundation is already landed
- the next technical dependency is stronger invariant support for the boundary proofs
- doc cleanup should happen after the actual proof surface is settled

## 9. Immediate Next Steps

1. Add the phase-sensitive invariant lemmas needed to talk precisely about hidden and output guard cycles.
2. Add public theorems for no guard-cycle MAC work, no duplicate/skip boundary work, and no out-of-range reads.
3. Re-export the completed boundary package through `Correctness.lean`.
4. Re-run `cd formalize && lake build` and `rg -n "\\bsorry\\b|\\baxiom\\b" formalize/src` after the proof and doc cleanup.
