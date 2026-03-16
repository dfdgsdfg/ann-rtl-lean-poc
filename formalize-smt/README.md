# Formalize-SMT

This package implements the optional SMT-assisted Lean overlay described in [`specs/formalize-smt/design.md`](../specs/formalize-smt/design.md).

Baseline relationship:

- `formalize/` is the canonical solver-free Lean proof path
- `formalize-smt/` is an optional overlay for selected arithmetic proof obligations

Current scope:

- reprove the `ArithmeticProofProvider` theorem family with `lean-smt`
- expose an alternate provider value for the shared fixed-point executable layer
- require explicit local provider binding when selecting the SMT or vanilla arithmetic lane

Current non-goals:

- replacing the vanilla `formalize/` package
- migrating machine, temporal, or top-level correctness theorems
- making SMT tooling a prerequisite for understanding the repository's baseline proof story

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

- the SMT solver is used only through the overlay package
- final theorems are still checked by the Lean kernel
- the current upstream `lean-smt` dependency emits a `warning: declaration uses 'sorry'` message in `Smt.Reconstruct.BitVec.Bitblast`, so this overlay currently has a weaker trust story than the vanilla `formalize/` baseline
- if SMT tooling is unavailable, `formalize-smt/` fails to build, but `formalize/` remains buildable on its own

Lane selection:

- neither the vanilla nor SMT arithmetic provider is exported as a global instance
- each file that elaborates provider-parameterized fixed-point definitions must bind its intended provider locally
- importing both proof lanes at once should not silently select either lane by import order
- the overlay source tree does not import `TinyMLP.ProofsVanilla.SpecArithmetic`; side-by-side vanilla/SMT comparisons belong in consumer code or documentation snippets, not in `formalize-smt/src/`

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

Example of explicit lane selection outside the overlay package:

```lean
import TinyMLP.ProofsVanilla.SpecArithmetic
import TinyMLPSmt

open TinyMLP

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
