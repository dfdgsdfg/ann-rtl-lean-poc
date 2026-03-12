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
- `simulations`: vectors, testbench, regression flow
- `experiments`: optional comparison and evaluation work
- `asic`: synthesis and physical-design flow

## Process

`ann -> contract -> rtl -> formalize -> simulations -> experiments -> asic`
