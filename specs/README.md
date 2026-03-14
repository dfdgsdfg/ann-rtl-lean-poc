# Specs

This directory contains the project specifications.

Each domain may contain:

- `requirement.md`: what must be true
- `design.md`: how the domain is intended to work
- `plan.md`: working notes, defaults, or execution planning when needed

## Domains

- `ann`: training, quantization, export
- `contract`: frozen result and downstream handoff
- `rtl`: hardware behavior and microarchitecture
- `formalize`: Lean models and proof targets
- `formalize-smt`: optional SMT-assisted Lean proof workflow
- `smt`: solver-backed verification outside Lean
- `rtl-formalize-synthsis`: Lean Signal-DSL hardware generation via Sparkle
- `rtl-synthesis`: reactive controller synthesis from temporal specifications
- `simulations`: vectors, testbench, regression flow
- `experiments`: optional comparison and evaluation work
- `asic`: synthesis and physical-design flow

## Process

Canonical implementation path:
`ann -> contract -> rtl -> simulations -> experiments -> asic`

Optional controller-synthesis branch:
`ann -> contract -> rtl + rtl-synthesis -> simulations -> experiments -> asic`

Optional Lean-generated RTL branch:
`ann -> contract -> formalize -> rtl-formalize-synthsis -> simulations -> experiments -> asic`

Cross-cutting verification complement:
`contract -> rtl -> smt`

Optional proof-automation complement:
`formalize -> formalize-smt`

The `simulations` and `experiments` specs should state the support level for each RTL branch:

- `rtl/`: full-core baseline
- `rtl-synthesis`: mixed-path support unless a wider generated replacement is declared
- `rtl-formalize-synthsis`: controller-only or other explicitly declared generated scope

They should also prefer a branch-first layout:

- `experiments/` should use branch folders directly
- `simulations/` should keep shared assets separate from branch-local benches
