# SMT Design

## 1. Design Goal

The SMT domain exists to add fast, automated, width-aware verification on top of the repository's current baseline:

- frozen contract in `contract/result/`
- hand-written RTL in `rtl/src/`
- Lean formalization in `formalize/src/`
- simulation flow in `simulations/`

The design goal is not to replace any of those layers. It is to add a solver-backed path that is good at:

- bounded counterexample generation
- bitvector-width reasoning
- automated checking of repetitive control properties

## 2. Domain Focus

This domain is intentionally limited to solver-backed verification outside Lean.

It covers:

- RTL property checking
- contract-tied width and overflow analysis
- optional equivalence-style solver checks

It does not cover:

- SMT tactics inside `formalize/`
- external-solver-dependent Lean proof workflows
- any attempt to redefine the canonical proof backbone away from `formalize/`

The SMT-assisted Lean path, if adopted, belongs in `specs/formalize-smt/`.

## 3. Why SMT Fits Here

This repository's control path is a strong fit for SMT because it is:

- finite-state
- bounded-width
- trace-sensitive
- already specified in terms of exact phase ordering and guard behavior

The arithmetic path is also compatible with SMT when encoded as fixed-size bitvectors, especially for overflow and width-safety checks.

What SMT does poorly here is replace the full semantic structure of the Lean development. The Lean layer should continue to own the compositional proof story.

## 4. Recommended Property Stack

The first SMT implementation should focus on properties that are already central in the repository docs and tests.

### 4.1 Controller Properties

For [`rtl/src/controller.sv`](../../rtl/src/controller.sv):

- legal phase ordering
- one-step transition correctness
- `done` / `busy` definitions
- hold-high behavior in `DONE`
- release-to-`IDLE` behavior
- hidden and output guard-cycle transition behavior

### 4.2 Top-Level Integration Properties

For [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv):

- accepted `start` captures the intended transaction structure
- hidden and output loop boundaries do not trigger duplicate work
- no out-of-range counter use is required at the transition steps
- exact-cycle claims are checked only under explicit environment assumptions

### 4.3 Arithmetic Properties

Over the frozen contract:

- hidden and output products fit their intended widths
- accumulator bounds fit the declared width
- sign extension is modeled explicitly
- any direct equivalence encoding uses the same wraparound rules recorded in the contract

## 5. Solver Strategy

The design should not hard-code one universal solver path.

Recommended strategy:

- SymbiYosys or Yosys-SMTBMC for RTL property entry
- Z3, cvc5, or Bitwuzla as backend solvers depending on the query family

Reasonable default split:

- use SymbiYosys plus one broadly available solver first for controller properties
- use a bitvector-strong backend for datapath overflow analysis if that work is added

## 6. Assumption Discipline

The main design rule for this domain is assumption explicitness.

SMT checks can look stronger than they are if the harness quietly bakes in hidden constraints. This repository should therefore record, per property family:

- which module is under test
- what the environment controls
- what is assumed about counters or sampled inputs
- whether the result is bounded bug-finding, k-induction, or exact proof for the encoded model

That rule is especially important for:

- exact `76`-cycle latency claims
- `mlp_core` boundary properties that depend on datapath-owned counters
- any equivalence statement between RTL and a contract encoding

## 7. Artifact Layout Plan

The implementation should eventually have a dedicated SMT artifact tree instead of scattering harnesses across unrelated directories.

Recommended future layout:

```text
smt/
  rtl/
    controller/
    mlp_core/
  contract/
    overflow/
    equivalence/
```

Expected content classes:

- property files
- harness modules
- solver configuration files
- small wrapper scripts or Make targets
- brief README notes per check family

The committed source artifacts matter more than committing raw solver output.

## 8. Relationship To Existing Domains

The intended relationship is:

- `contract` defines the frozen arithmetic facts
- `rtl` defines the canonical implementation
- `formalize` defines the semantic proof structure
- `formalize-smt` can optionally define an SMT-assisted Lean workflow
- `simulations` provides practical regression checks
- `smt` adds automated bounded verification outside Lean

This means the SMT domain is cross-cutting, not linear in the repository pipeline.

The right mental model is:

- simulation asks "does this behave correctly on these concrete traces?"
- SMT asks "can a bounded counterexample or width violation exist under these assumptions?"
- Lean asks "what is the general machine-checked correctness argument?"

The SMT domain should not be used to blur the status of the canonical `formalize` build. If an external solver is needed inside Lean, that dependency belongs to the separate `formalize-smt` path.

## 9. Delivery Plan

A practical implementation order is:

1. Add controller-focused RTL properties first.
2. Add `mlp_core` boundary and handshake properties next.
3. Add arithmetic overflow or equivalence checks tied to the frozen contract.

This order maximizes immediate verification value while keeping the repository's current strengths intact.
