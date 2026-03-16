# Formalize-SMT Design

## 1. Design Goal

The design goal of `formalize-smt` is to provide a full optional Lean-plus-SMT proof lane without destabilizing the mature `formalize` baseline.

The key architectural decision is:

- `formalize/` stays canonical
- `formalize-smt/` is a second proof lane with the same public theorem interface

This separation remains worth keeping explicit because the two lanes optimize for different things:

- vanilla Lean optimizes for minimal external dependencies and straightforward reviewability
- Lean-plus-SMT optimizes for reducing repetitive proof labor while preserving theorem statements

## 2. Lane Model

`formalize-smt` is not just a small helper slice in the design target. It is a parallel proof lane.

That means:

- the semantic backbone remains shared where practical
- the proof implementations are lane-specific
- the public theorem surface is intended to match the vanilla lane
- the SMT lane is still optional and explicitly weaker in trust unless the underlying tooling story improves

The design should still avoid turning the repository into a solver-script repository wrapped in Lean syntax. The goal is interface parity with better automation, not opaque proof scripts.

## 3. Shared vs Lane-Specific Surface

The design should keep three categories separate.

Shared baseline surface:

- `MlpCore.Defs.*`
- `MlpCore.Interfaces.*`
- frozen constants and executable definitions whose semantics should not fork

Lane-specific proof surface:

- arithmetic proof implementations
- fixed-point proof implementations
- machine / invariant / simulation / temporal / correctness theorem implementations

Forbidden proof sharing:

- `formalize-smt` must not satisfy mirrored theorem families by importing the finished `ProofsVanilla/*` modules or other vanilla proof modules as oracles

This keeps the comparison honest: one semantic surface, two proof lanes.

## 4. Interface Parity Rule

The design target is interface parity with the vanilla lane.

For this repository, that means:

- `MlpCoreSmt` mirrors the proof-facing module responsibilities of `MlpCore`
- public theorem names, theorem statements, and goal definitions are intended to match modulo package / namespace prefix
- consumers should be able to swap the proof lane by changing imports rather than by rewriting theorem statements

This parity requirement matters more than whether every internal helper theorem is named the same way. The public theorem contract is the compatibility target.

## 5. Repository Relationship

The intended relationship among the proof and solver domains is:

- `formalize`: canonical theorem statements and baseline proofs
- `formalize-smt`: optional SMT-backed Lean proof lane with matching interface
- `smt`: external solver verification outside Lean

This keeps three different kinds of value separate:

- semantic proof backbone
- proof-lane comparison inside Lean
- bounded solver-backed verification over RTL or SMT-LIB artifacts

## 6. Layout Direction

The SMT-backed lane should use a separate sibling package:

- `formalize/` remains the canonical vanilla package
- `formalize-smt/` is a second Lake package that depends on `../formalize`
- both packages share the same Lean toolchain pin so the comparison is reproducible

The layout should support full proof-lane mirroring:

- `formalize-smt/lean-toolchain`
- `formalize-smt/lakefile.lean`
- `formalize-smt/src/MlpCoreSmt.lean`
- `formalize-smt/src/MlpCoreSmt/*` for the mirrored proof-facing modules

Shared semantic modules may still be imported from `MlpCore.*` rather than duplicated, provided the theorem families themselves are proved in the SMT lane.

## 7. Proof Strategy

A sensible proof-lane strategy is:

1. Reuse shared semantic definitions and theorem statements where available.
2. Introduce SMT-backed proofs first where proof burden is most repetitive and solver-friendly.
3. Build upward until the SMT lane exposes the same public theorem surface as the vanilla lane.
4. Keep theorem statements readable and structurally recognizable even when proof scripts change substantially.
5. Make current implementation status explicit whenever the checked-in SMT lane still lags behind the design target.

The point is not to replace all reasoning with SMT. The point is to preserve interface parity while using SMT in the parts where it materially improves proof maintenance.

## 8. High-Value Theorem Families

The theorem families most likely to justify SMT assistance in this repository are:

- bounded multiplication lemmas such as `int8_mul_int8_bounds` and `int16_mul_int8_bounds`
- width-preservation lemmas such as `int16_to_int32_bounds` and `int24_to_int32_bounds`
- wraparound elimination lemmas such as `wrap16_eq_self_of_bounds`, `wrap32_eq_self_of_bounds`, `wrap32_hiddenPreAt8_*`, and `wrap16_hiddenSpecAt8_*`
- closed-form bounded arithmetic lemmas such as `hiddenSpecAt8_*_bounds` and `outputScoreSpec8_bounds`
- finite case-split bridge lemmas such as `w1Int8At_toInt` and `w2Int8At_toInt`

These families are where `lean-smt` can deliver actual proof value instead of acting as a smoke test for the library.

The upper machine / temporal / correctness layers still belong to the lane target, but the design expectation there is interface parity plus readable proof structure, not aggressive solver use for its own sake.

## 9. Trust Strategy

The core requirement is that final theorems remain Lean theorems.

The design should therefore prefer:

- proof reconstruction
- explicit witness checking
- or another workflow where the solver result is not accepted blindly

The repository should say plainly if a given tactic has a weaker trust story than the vanilla path.

The repository should also say plainly whether a theorem family is:

- already mirrored in the SMT lane
- intentionally still vanilla-only in the checked-in implementation
- or pending migration to achieve interface parity

## 10. Coexistence Rules

Coexistence between the vanilla and SMT lanes should remain explicit:

- neither lane should silently redefine the canonical repository proof claim
- shared semantic modules should stay semantically identical across lanes
- lane choice should happen through imports, not hidden global-instance selection
- documentation should distinguish the design target of the SMT lane from the narrower currently checked-in implementation when the two diverge

The repository should not describe `formalize-smt` as a full proof lane and a tiny arithmetic proof slice at the same time. One clear story is required, and the design target for this repository is the full optional SMT-backed lane with interface parity.
