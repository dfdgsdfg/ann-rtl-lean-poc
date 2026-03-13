# Formalize-SMT Design

## 1. Design Goal

The design goal of `formalize-smt` is to create a separate Lean-plus-SMT workflow without destabilizing the mature `formalize` baseline.

The key architectural decision is:

- `formalize/` stays canonical
- `formalize-smt/` is an optional proof-automation lane

This separation is worth keeping explicit because the two lanes optimize for different things:

- vanilla Lean optimizes for minimal external dependencies and straightforward reviewability
- SMT-assisted Lean optimizes for automation on solver-friendly proof obligations

## 2. Workflow Model

The intended workflow is layered rather than competitive.

Recommended mental model:

1. Write or preserve the main theorem structure in vanilla Lean.
2. Identify repetitive helper lemmas that are solver-friendly.
3. Add SMT assistance only where it removes low-value proof labor.
4. Keep the resulting theorem surface readable and kernel-checked.

The design should avoid turning the project into a solver-script repository wrapped in Lean syntax.

## 3. Separation Strategy

There are three plausible implementation patterns.

### 3.1 Full Fork

Duplicate the full `formalize` development and maintain an SMT-assisted copy.

This is the least attractive option here because it maximizes drift and maintenance cost.

### 3.2 Oracle Wrapper

Import the finished vanilla proofs and use them as solved facts while claiming an SMT-assisted path.

This is also a poor fit for this repository. It weakens the comparison story and makes the SMT-assisted lane hard to interpret, because the baseline proof is doing the real work.

### 3.3 Selective Overlay

Reuse the existing `formalize` definitions and theorem statements, but reprove only the targeted theorem families with SMT assistance.

This is viable only if:

- imports are well controlled
- the extra dependency is explicit
- the baseline build story remains understandable
- the targeted lemmas do not import the finished vanilla proof modules as an oracle

For this repository, the selective overlay is the right design. The vanilla `formalize` path is already mature, so definitions should be shared, but replaced proof families should still be reproved inside the SMT-assisted lane.

## 4. Overlay Import Rule

The overlay rule should be explicit:

- `formalize-smt` may import baseline definition modules
- `formalize-smt` may import theorem statements or shared helper interfaces
- `formalize-smt` should not import the vanilla proof module for any theorem family it claims to replace
- `formalize-smt` may still depend on vanilla proofs for unrelated areas that it is not trying to reprove, provided that boundary is documented

This gives the repository a clean trust and comparison story:

- shared semantics come from one place
- SMT-assisted proofs are real proofs of the targeted obligations
- untouched theorem families do not need to be duplicated gratuitously

## 5. Good Initial Targets

The first candidate targets should be arithmetic helper lemmas in the existing formalization, not the controller proofs.

Good starting points include:

- bounded multiplication lemmas in `Spec.lean`
- arithmetic side conditions that currently need repeated sign-case splitting
- width-fit obligations produced by fixed-point helper definitions

Bad first targets:

- trace or control invariants in `Temporal.lean`
- delicate machine-step proofs whose value comes from explicit structural reasoning

## 6. Dependency Strategy

The SMT-assisted path should use a narrow dependency story.

Recommended direction:

- one Lean integration layer
- one preferred solver
- explicit version pinning

If `lean-smt` is used, the design should record:

- that it is a tactic layer rather than a standalone solver
- which backend solver it depends on
- which theorem families justify the extra dependency

## 7. Trust Strategy

The core requirement is that final theorems remain Lean theorems.

The design should therefore prefer:

- proof reconstruction
- explicit witness checking
- or another workflow where the solver result is not accepted blindly

The repository should say plainly if a given tactic has a weaker trust story than the vanilla path.

The repository should also say plainly whether a theorem family is:

- reproved in the SMT-assisted lane
- inherited unchanged from the vanilla baseline
- or still pending migration

## 8. Repository Relationship

The intended relationship among the proof and solver domains is:

- `formalize`: canonical theorem statements and baseline proofs
- `formalize-smt`: optional Lean proof acceleration
- `smt`: external solver verification outside Lean

This keeps three different kinds of value separate:

- semantic proof backbone
- proof authoring convenience
- bounded solver-backed verification

## 9. Delivery Plan

A practical implementation order is:

1. Keep the current `formalize` path unchanged as the baseline.
2. Identify one or two arithmetic lemma families where SMT assistance would remove obvious manual proof boilerplate.
3. Share the baseline definitions and theorem statements needed for those lemmas.
4. Reprove those lemmas in the SMT-assisted lane without importing the finished vanilla proof of the same family.
5. Compare the result against the vanilla path for readability, maintenance burden, and dependency cost.
6. Expand only if the gain is clear.

This avoids paying solver-integration complexity before the repository has a concrete proof-maintenance problem worth solving.
