# Formalize-SMT Requirements

## 1. Purpose

This document defines the requirements for an optional SMT-assisted Lean proof workflow layered on top of the mature baseline `formalize` domain.

In this repository:

- `formalize` is the canonical vanilla Lean proof path
- `formalize-smt` is an optional acceleration layer for selected proof obligations

The purpose of `formalize-smt` is to improve proof ergonomics for bounded arithmetic and similar automation-friendly obligations without changing the repository's core correctness story.

## 2. Scope

The `formalize-smt` domain covers:

- Lean tactics or libraries that call an external SMT solver
- proof reconstruction or witness-checking paths that keep final theorems kernel-checked
- selective automation and reproving of helper lemmas in `formalize/src/`
- explicit documentation of the additional solver dependency and trust boundary

It does not cover:

- replacing `specs/formalize/` as the canonical proof baseline
- external SMT checking of RTL outside Lean; that belongs to `specs/smt/`
- broad theorem proving strategy changes unrelated to SMT-assisted automation

This domain also assumes a prerequisite on the baseline Lean structure:

- `formalize/` must expose shared definitions and proof interfaces cleanly enough for an overlay proof lane to import them without importing the finished vanilla proofs of the same theorem families
- in the current repository, that prerequisite is satisfied first for the arithmetic and shared fixed-point executable layer via `Defs/*`, `Interfaces/ArithmeticProofProvider.lean`, and `ProofsVanilla/*`

## 3. Baseline Preservation Requirements

The baseline `formalize` domain must remain independently meaningful and buildable.

Required separation rules:

- the main repository proof claim remains attached to `formalize/`
- `formalize-smt` must not redefine the project so that an external solver becomes mandatory for understanding the core proof story
- shared definitions from `formalize/` are allowed and preferred
- baseline proof reuse is allowed only for theorem families that `formalize-smt` is not trying to replace

The preferred architecture is a selective overlay:

- import definitions, structures, constants, and proof interfaces from the baseline `formalize` path
- reprove the targeted theorem families inside `formalize-smt`
- avoid treating the baseline proof modules as an oracle for the very lemmas the SMT-assisted path claims to establish

In particular, if `formalize-smt` claims to provide an SMT-assisted proof of a lemma family, it must not satisfy that claim merely by importing the finished vanilla proof of the same lemmas and wrapping it.

If the baseline does not yet expose that interface boundary, then refactoring `formalize/` is a prerequisite task for `formalize-smt`, not optional cleanup.

If the project adopts an SMT tactic in the existing Lean files rather than forking files, the repository must document whether:

- the tactic is optional and guarded by imports or configuration
- the baseline can still be built without the external solver
- or the SMT-assisted path has become the only maintained proof path

The preferred design is to keep the canonical baseline clear and stable even if the SMT-assisted path becomes useful in practice.

## 4. Allowed Automation Scope

The `formalize-smt` domain should target theorem classes that are solver-friendly and structurally repetitive.

Good targets include:

- bounded multiplication lemmas
- sign-sensitive arithmetic case splits
- width-preservation side conditions
- repetitive arithmetic normalization subgoals

Poor targets include:

- main control proofs in `Temporal.lean`
- high-level theorem statements whose value is in their human-readable structure
- large opaque tactic scripts that make the proof harder to audit than the vanilla version

## 5. Trust and Proof-Checking Requirements

Any theorem claimed through the `formalize-smt` path must still end as a Lean theorem checked by the Lean kernel.

The repository must document:

- the external solver used
- whether proofs are reconstructed, translated, or witness-checked
- whether the external solver is part of the trusted computing base
- what happens when the solver is unavailable
- which targeted theorem families are reproved in `formalize-smt`
- which untargeted theorem families are still inherited from the vanilla baseline, if any

If the chosen tool does not support a strong reconstruction story, that limitation must be called out explicitly.

## 6. Tooling Requirements

If adopted, the initial tooling direction should use:

- Lean 4 tactic integration compatible with the pinned toolchain
- a solver with a credible proof-production or reconstruction story, such as `cvc5`
- clear version pinning or installation instructions

The repository should avoid making `formalize-smt` depend on a fragile or poorly documented tool stack if the marginal proof-engineering gain is small.

## 7. Artifact Requirements

The `formalize-smt` domain must record:

- which Lean files or theorem families use SMT assistance
- whether each such family is definition-sharing only or proof-sharing with the baseline
- the required extra dependencies
- the command needed to run the SMT-assisted build
- any fallback or non-SMT baseline path
- the intended benefits relative to the vanilla path

This domain may also record comparison notes such as:

- reduced proof-script size
- reduced manual case splitting
- new maintenance burden

## 8. Acceptance Criteria

The `formalize-smt` domain is complete for its first milestone when:

1. A checked-in requirements document and design document exist under `specs/formalize-smt/`.
2. The repository explicitly identifies `formalize` as the canonical vanilla Lean baseline and `formalize-smt` as optional or secondary.
3. The repository specifies which theorem classes are appropriate SMT-assistance targets.
4. The baseline `formalize` domain exposes shared definitions and proof interfaces cleanly enough that `formalize-smt` can be an overlay instead of a fork or oracle wrapper. For the first milestone, this requirement is scoped to the arithmetic and shared fixed-point executable layer.
5. The repository specifies the overlay boundary clearly: shared definitions are allowed, but replaced theorem families are reproved rather than imported as solved facts from vanilla proof modules.
6. The repository specifies the external dependency and trust story clearly.
7. The repository specifies how the SMT-assisted path coexists with, or is compared against, the vanilla path.
