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

Main baseline:
`ann -> contract -> rtl -> formalize -> rtl-synthesis -> simulations -> experiments -> asic`

Optional Lean-generated RTL path:
`ann -> contract -> formalize -> rtl-formalize-synthsis -> simulations -> experiments -> asic`

Cross-cutting verification complement:
`contract -> rtl -> smt`

Optional proof-automation complement:
`formalize -> formalize-smt`
