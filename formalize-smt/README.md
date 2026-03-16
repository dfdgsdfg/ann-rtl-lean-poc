# Formalize-SMT

This package implements the optional SMT-backed Lean proof lane described in [`specs/formalize-smt/design.md`](../specs/formalize-smt/design.md).

Baseline relationship:

- `formalize/` is the canonical solver-free Lean proof path
- `formalize-smt/` is an optional SMT-backed alternative that mirrors the same public theorem surface under the `MlpCoreSmt` namespace

Current checked-in scope:

- `MlpCoreSmt` mirrors the proof-facing responsibilities of `MlpCore`
- the SMT lane reuses shared semantic definitions and proof interfaces from `../formalize`
- arithmetic-side proof burden is reduced with `lean-smt`, while upper simulation / temporal / correctness layers remain readable Lean proofs built on the SMT-backed lower surface

Non-goals:

- replacing the vanilla `formalize/` package as the canonical repository baseline
- making SMT tooling a prerequisite for the repository's baseline proof story
- folding the external `smt/` domain into this Lean-side package

## Dependencies

This package depends on:

- the local `../formalize` package for shared definitions and proof interfaces
- [`lean-smt`](https://github.com/ufmg-smite/lean-smt)
- the transitive `lean-cvc5` plugin used by `lean-smt`

Operational requirements:

- first build may download the pinned cvc5 release archive into `.lake/packages/cvc5`
- `clang` is required for the `lean-cvc5` FFI build
- `tar` is required on macOS/Windows and `unzip` is required on Linux to unpack the cvc5 archive
- offline or minimal environments can fail even before theorem checking if the cvc5 archive is missing or the native toolchain is incomplete

Trust boundary:

- the SMT solver is used only through the optional SMT-backed package
- final theorems are still checked by the Lean kernel
- the current upstream `lean-smt` dependency emits a `warning: declaration uses 'sorry'` message in `Smt.Reconstruct.BitVec.Bitblast`, so this SMT-backed lane currently has a weaker trust story than the vanilla `formalize/` baseline
- if SMT tooling is unavailable, `formalize-smt/` fails to build, but `formalize/` remains buildable on its own

Lane relationship:

- the mirrored public theorem surface is exposed through `MlpCoreSmt.Proofs.SpecArithmetic`, `MlpCoreSmt.Proofs.FixedPoint`, `MlpCoreSmt.Proofs.Invariants`, `MlpCoreSmt.Proofs.Simulation`, `MlpCoreSmt.Proofs.Temporal`, and `MlpCoreSmt.Proofs.Correctness`
- shared semantic modules may be imported from `MlpCore.*`, but SMT-lane proofs must not be satisfied by importing `MlpCore.Proofs.*` as solved facts
- `MlpCoreSmt.Arithmetic` remains a compatibility shim for the older arithmetic-only entrypoint

## Commands

```bash
make formalize-smt
```

```bash
cd formalize-smt
lake script run doctor
```

```bash
cd formalize-smt
lake build
```

Example of lane swapping by imports:

```lean
import MlpCore

open MlpCore

example (input : Input8) :
    @mlpFixed vanillaArithmeticProofProvider input = mlpSpec (toMathInput input) := by
  exact MlpCore.fixedPoint_matchesSpec input
```

```lean
import MlpCoreSmt

open MlpCore

example (input : Input8) :
    @mlpFixed MlpCoreSmt.smtArithmeticProofProvider input = mlpSpec (toMathInput input) := by
  exact MlpCoreSmt.fixedPoint_matchesSpec input
```
