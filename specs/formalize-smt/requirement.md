# Formalize-SMT Requirements

## 1. Purpose

This document defines the requirements for an optional Lean-plus-SMT proof lane that sits beside the canonical vanilla `formalize` development.

In this repository:

- `formalize` is the canonical vanilla Lean proof path
- `formalize-smt` is an optional SMT-backed proof lane with the same public theorem interface

The purpose of `formalize-smt` is not merely to demonstrate that `lean-smt` can solve isolated toy obligations. Its purpose is to reduce real proof burden in this repository while preserving the theorem interface, semantic intent, and reviewability of the existing Lean formalization.

## 2. Scope

The `formalize-smt` domain covers:

- Lean tactics or libraries that call an external SMT solver
- proof reconstruction or witness-checking paths that keep final theorems kernel-checked
- a full optional proof lane that mirrors the public theorem surface of `formalize`
- explicit documentation of the additional solver dependency and trust boundary

It does not cover:

- replacing `specs/formalize/` as the canonical proof baseline
- external SMT checking of RTL outside Lean; that belongs to `specs/smt/`
- silently turning the main repository proof story into an SMT-dependent build

For this repository, "same public theorem interface" means:

- the SMT lane mirrors the same proof-facing module responsibilities as the vanilla lane
- theorem names, theorem statements, and goal definitions are intended to match modulo package / namespace prefix
- shared semantic definitions may still come from `formalize`, but replaced theorem families must be reproved in the SMT lane rather than imported from vanilla proof modules

## 3. Baseline Preservation Requirements

The baseline `formalize` domain must remain independently meaningful and buildable.

Required separation rules:

- the main repository proof claim remains attached to `formalize/`
- `formalize-smt` must stay optional
- shared definitions and proof interfaces from `formalize/` are allowed and preferred
- theorem families that `formalize-smt` claims to provide must not be satisfied by importing the finished vanilla proof modules as an oracle

The preferred architecture is a parallel proof lane:

- reuse shared `Defs/*` and `Interfaces/*` from the baseline where possible
- mirror the public proof surface in `formalize-smt`
- keep proof implementations lane-specific
- preserve the ability to compare the vanilla and SMT-backed lanes at the theorem-interface level

If the baseline does not yet expose the needed boundary cleanly enough, refactoring `formalize/` is a prerequisite to a correct `formalize-smt` implementation rather than optional cleanup.

## 4. Target Proof Surface

`formalize-smt` should target the same proof-facing layers as `formalize`:

- arithmetic helper theorems
- fixed-point bridge theorems
- machine semantics
- invariants
- simulation bridge lemmas
- temporal theorems
- top-level correctness goals

This does not mean every theorem must be solved directly by an SMT tactic. It means the SMT lane must provide the same theorem surface while using SMT where it actually reduces proof effort.

The theorem classes most likely to justify SMT assistance are still the solver-friendly ones:

- bounded multiplication lemmas such as `int8_mul_int8_bounds` and `int16_mul_int8_bounds`
- width-preservation side conditions such as `int16_to_int32_bounds` and `int24_to_int32_bounds`
- wraparound elimination and normalization families such as `wrap16_eq_self_of_bounds`, `wrap32_eq_self_of_bounds`, `wrap32_hiddenPreAt8_*`, and `wrap16_hiddenSpecAt8_*`
- closed-form bounded arithmetic proofs such as `hiddenSpecAt8_*_bounds` and `outputScoreSpec8_bounds`
- finite bridge lemmas such as `w1Int8At_toInt` and `w2Int8At_toInt`

The upper machine / temporal / correctness layers remain part of the target theorem surface, but the design should still keep their statements readable and should not replace explicit structural reasoning with opaque solver scripts where no real benefit exists.

## 5. Value Requirement

The repository should treat `formalize-smt` as meaningful only if it reduces real repository-specific proof burden.

That means:

- replacing low-value repetitive proof labor is good
- preserving theorem readability is required
- proving one or two isolated arithmetic lemmas is not enough to justify the lane on its own

If `formalize-smt` never goes beyond a tiny arithmetic proof-of-concept, the repository should describe it as such rather than presenting it as a meaningful second proof lane.

## 6. Trust and Proof-Checking Requirements

Any theorem claimed through the `formalize-smt` path must still end as a Lean theorem checked by the Lean kernel.

The repository must document:

- the external solver used
- whether proofs are reconstructed, translated, or witness-checked
- whether the external solver is part of the trusted computing base
- what happens when the solver is unavailable
- which theorem families are already mirrored in `formalize-smt`
- which theorem families remain missing or partial, if the checked-in implementation has not yet reached full interface parity

If the chosen tool does not support a strong reconstruction story, that limitation must be called out explicitly.

## 7. Tooling Requirements

If adopted, the initial tooling direction should use:

- Lean 4 tactic integration compatible with the pinned toolchain
- a solver with a credible proof-production or reconstruction story, such as `cvc5`
- clear version pinning or installation instructions

The repository should avoid keeping `formalize-smt` alive as a permanent burden if the proof-engineering gain remains too small to justify the dependency and trust cost.

## 8. Artifact Requirements

The `formalize-smt` domain must record:

- which module families already have SMT-backed counterparts
- which theorem families are shared-definition only versus lane-specific proofs
- the required extra dependencies
- the command needed to run the SMT-backed build
- the fallback baseline path
- the intended proof-engineering benefits relative to the vanilla path

The package README may additionally record:

- current implementation status relative to the target interface
- comparison notes such as reduced proof-script size or reduced manual case splitting
- maintenance costs or trust caveats

## 9. Acceptance Criteria

The `formalize-smt` domain is adequately specified for this repository when:

1. A checked-in requirements document and design document exist under `specs/formalize-smt/`.
2. The repository explicitly identifies `formalize` as the canonical vanilla Lean baseline and `formalize-smt` as an optional secondary lane.
3. The repository defines `formalize-smt` as a full proof lane with the same public theorem interface as `formalize`, not merely as a tiny arithmetic proof slice.
4. The repository specifies that shared semantic definitions and proof interfaces may be reused, but replaced theorem families must not be imported as solved facts from vanilla proof modules.
5. The repository specifies where SMT assistance is expected to add real proof value, especially in arithmetic and fixed-point helper families.
6. The repository specifies the external dependency and trust story clearly.
7. The repository specifies how the SMT-backed lane coexists with the canonical vanilla lane.
