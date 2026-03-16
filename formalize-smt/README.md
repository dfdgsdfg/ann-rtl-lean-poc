# Formalize-SMT

This package implements the optional SMT-backed Lean proof lane described in [`specs/formalize-smt/design.md`](../specs/formalize-smt/design.md).

Baseline relationship:

- `formalize/` is the canonical solver-free Lean proof path
- `formalize-smt/` is an optional SMT-backed lane intended to mirror the same public theorem interface

Target scope:

- provide an SMT-backed proof lane with the same public theorem surface as `formalize`
- reuse shared semantic definitions and proof interfaces from `../formalize` where practical
- use `lean-smt` where it reduces real repository-specific proof burden rather than only demonstrating the library

Current checked-in status:

- the implementation is still partial relative to that target lane
- today it reproves the `ArithmeticProofProvider` theorem family and exposes an alternate provider value for the shared fixed-point executable layer
- the upper machine / simulation / temporal / correctness theorem surface has not yet reached interface parity

Current non-goals:

- replacing the vanilla `formalize/` package as the canonical baseline
- making SMT tooling a prerequisite for understanding the repository's baseline proof story
- presenting the current partial implementation as if the full target lane were already complete

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

- `formalize-smt` is specified as a full optional proof lane, not merely as a tiny arithmetic proof slice
- shared semantic modules may be imported from `MlpCore.*`, but replaced proof families should not be imported from `ProofsVanilla/*` as solved facts
- the current checked-in implementation still reflects only the first provider-level slice of that wider target

## Command

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

Example of explicit lane selection outside the SMT lane package:

```lean
import MlpCore.ProofsVanilla.SpecArithmetic
import MlpCoreSmt

open MlpCore

section VanillaLane
local instance : ArithmeticProofProvider := vanillaArithmeticProofProvider
example (lhs rhs : Int8) : (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl
end VanillaLane

section SmtLane
local instance : ArithmeticProofProvider := smtArithmeticProofProvider
example (lhs rhs : Int8) : (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl
end SmtLane
```
