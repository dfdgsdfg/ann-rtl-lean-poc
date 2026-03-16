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

The repository already exposes the arithmetic and shared fixed-point executable layer cleanly enough for a selective overlay. The upper machine and temporal stack remain vanilla unless the repository deliberately adds a similarly clean exposure boundary there.

## 3. Separation Strategy

There are three plausible implementation patterns.

### 3.1 Full Fork

Duplicate the full `formalize` development and maintain an SMT-assisted copy.

This is the least attractive option here because it maximizes drift and maintenance cost.

### 3.2 Oracle Wrapper

Import the finished vanilla proofs and use them as solved facts while claiming an SMT-assisted path.

This is also a poor fit for this repository. It weakens the comparison story and makes the SMT-assisted lane hard to interpret, because the baseline proof is doing the real work.

### 3.3 Selective Overlay

Reuse the existing `formalize` definitions and proof interfaces, but reprove only the targeted theorem families with SMT assistance.

This is viable only if:

- imports are well controlled
- the extra dependency is explicit
- the baseline build story remains understandable
- the targeted lemmas do not import the finished vanilla proof modules as an oracle

For this repository, the selective overlay is the right design. The vanilla `formalize` path is already mature, so definitions should be shared, but replaced proof families should still be reproved inside the SMT-assisted lane.

## 4. Overlay Import Rule

The overlay rule should be explicit:

- `formalize-smt` may import baseline definition modules
- `formalize-smt` may import shared proof interfaces
- `formalize-smt` should not import the vanilla proof module for any theorem family it claims to replace
- `formalize-smt` may still depend on vanilla proofs for unrelated areas that it is not trying to reprove, provided that boundary is documented

This gives the repository a clean trust and comparison story:

- shared semantics come from one place
- SMT-assisted proofs are real proofs of the targeted obligations
- untouched theorem families do not need to be duplicated gratuitously

## 5. Exposure Prerequisite

The repository exposes the overlay boundary for the arithmetic and shared fixed-point layer as:

- `Defs`
- `Interfaces`
- `ProofsVanilla`

Concretely:

- `Defs/SpecCore.lean` exposes shared semantic definitions and frozen constants
- `Interfaces/ArithmeticProofProvider.lean` exposes the proof-provider interface used by shared fixed-point executable defs
- `Defs/FixedPointCore.lean` exposes provider-parameterized fixed-point executable definitions
- `ProofsVanilla/SpecArithmetic.lean` and `ProofsVanilla/FixedPoint.lean` keep the baseline proofs and the baseline provider value

This is enough to support an SMT-assisted overlay on the arithmetic and shared fixed-point layer without importing the finished vanilla proofs it wants to replace. The upper machine and temporal stack still require a similarly clean exposure boundary if they are ever targeted.

## 6. Good Target Families

The best `formalize-smt` targets in this repository are arithmetic and shared fixed-point helper lemmas whose proof labor is repetitive, solver-friendly, and lower-value than the theorem statement itself.

Good target families include:

- bounded multiplication lemmas such as `int8_mul_int8_bounds` and `int16_mul_int8_bounds`
- width-preservation lemmas such as `int16_to_int32_bounds` and `int24_to_int32_bounds`
- wraparound elimination lemmas such as `wrap16_eq_self_of_bounds`, `wrap32_eq_self_of_bounds`, and the derived families `wrap32_hiddenPreAt8_*` and `wrap16_hiddenSpecAt8_*`
- closed-form bounded arithmetic lemmas such as `hiddenSpecAt8_*_bounds` and `outputScoreSpec8_bounds`
- finite case-split bridge lemmas such as `w1Int8At_toInt` and `w2Int8At_toInt` when handled through a proof-producing or reconstruction-backed decision procedure rather than an opaque oracle

Poor targets include:

- trace or control invariants in `Temporal.lean`
- delicate machine-step proofs whose value comes from explicit structural reasoning
- large semantic bridge theorems whose value is mainly in their readable statement structure rather than in repetitive local arithmetic proof work

These target families sit squarely inside the existing arithmetic/shared fixed-point exposure boundary and do not require turning the repository into a separate external-solver verification lane.

## 7. Dependency Strategy

The SMT-assisted path should use a narrow dependency story.

Recommended direction:

- one Lean integration layer
- one preferred solver
- explicit version pinning

If `lean-smt` is used, the design should record:

- that it is a tactic layer rather than a standalone solver
- which backend solver it depends on
- which theorem families justify the extra dependency

## 8. Trust Strategy

The core requirement is that final theorems remain Lean theorems.

The design should therefore prefer:

- proof reconstruction
- explicit witness checking
- or another workflow where the solver result is not accepted blindly

The repository should say plainly if a given tactic has a weaker trust story than the vanilla path.

The repository should also say plainly whether a theorem family is:

- reproved in the SMT-assisted lane
- inherited unchanged from the vanilla baseline
- or intentionally left on the vanilla path

## 9. Repository Relationship

The intended relationship among the proof and solver domains is:

- `formalize`: canonical theorem statements and baseline proofs
- `formalize-smt`: optional Lean proof acceleration
- `smt`: external solver verification outside Lean

This keeps three different kinds of value separate:

- semantic proof backbone
- proof authoring convenience
- bounded solver-backed verification

## 10. Overlay Workflow

The repository should adopt SMT assistance through a stable overlay workflow:

1. Keep `formalize` as the baseline proof path.
2. Reuse the existing exposure split: shared definitions in `Defs/*`, proof interfaces in `Interfaces/*`, and baseline proofs in `ProofsVanilla/*`.
3. Reuse the exposed baseline definitions and theorem statements for each targeted theorem family.
4. Reprove the targeted family in the SMT-assisted lane without importing the finished vanilla proof of that same family.
5. Keep the resulting theorem surface readable, kernel-checked, and comparable against the vanilla path.

This keeps the solver integration focused on proof authoring convenience rather than on redefining the repository's semantic proof backbone.

## 11. Repository Layout and Coexistence

The SMT-assisted overlay should use a separate sibling package:

- `formalize/` remains the canonical vanilla package
- `formalize-smt/` is a second Lake package that depends on `../formalize`
- both packages share the same Lean toolchain pin so the overlay is reproducible

The package layout should be:

- `formalize-smt/lean-toolchain`
- `formalize-smt/lakefile.lean`
- `formalize-smt/src/TinyMLPSmt.lean`
- `formalize-smt/src/TinyMLPSmt/Arithmetic.lean`

The dependency stack should be narrow and explicit:

- `lean-smt` as the tactic layer
- its transitive `lean-cvc5` dependency for solver interaction
- a pinned upstream commit rather than a floating branch in the committed package manifest

Representative migrated theorem families may include:

- `ArithmeticProofProvider` obligations such as the bounded multiplication lemmas
- width-preservation and wraparound helper families in `ProofsVanilla/SpecArithmetic.lean`
- closed-form bound proofs such as `hiddenSpecAt8_*_bounds` and `outputScoreSpec8_bounds`
- finite case-split bridge lemmas such as `w1Int8At_toInt` and `w2Int8At_toInt`

When the overlay targets a theorem family consumed by provider-parameterized executable definitions, it may define alternate provider values and small smoke theorems that instantiate those definitions with the SMT-backed provider.

Coexistence between the vanilla and SMT lanes should be explicit:

- neither lane should export a global `ArithmeticProofProvider` instance
- provider selection should happen through local bindings in the files that elaborate provider-parameterized definitions
- importing both lanes together should leave instance synthesis unresolved until a file chooses the intended lane explicitly

The overlay should not migrate:

- machine, invariant, simulation, temporal, or correctness theorems whose primary value is explicit structural reasoning
- controller proofs or other theorem families whose natural verification target is emitted RTL rather than Lean proof obligations

That boundary keeps the comparison clean and preserves the repository-wide split between semantic proof, proof automation, and external solver-backed verification.
