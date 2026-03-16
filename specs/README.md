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
- `rtl-formalize-synthesis`: Lean Signal-DSL hardware generation via Sparkle
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
`ann -> contract -> formalize -> rtl-formalize-synthesis -> simulations -> experiments -> asic`

Cross-cutting verification complement:
`contract -> rtl -> smt`

Optional proof-automation complement:
`formalize -> formalize-smt`

The `simulations` and `experiments` specs should state the generation, integration, and validation scopes for each RTL branch. Branch-facing reports may spell those same boundaries through `artifact_kind`, `assembly_boundary`, `evidence_boundary`, and `evidence_method`, but they should not hide the underlying scope split:

- `rtl/`: full-core generation, full-core integration, and full-core validation at `mlp_core`
- `rtl-synthesis`: controller generation with mixed-path `mlp_core` integration unless a wider generated replacement is declared; however, its branch-local export surface must still materialize a full comparable `mlp_core` tree
- `rtl-formalize-synthesis`: full-core generation with full-core `mlp_core` integration and validation, or another explicitly declared generated scope

They should also prefer a branch-first layout:

- `experiments/` should use branch folders directly
- `simulations/` should keep shared assets separate from branch-local benches
- branch-local comparable RTL exports should align on `rtl/results/canonical/sv/`, `rtl-synthesis/results/canonical/sv/`, and `rtl-formalize-synthesis/results/canonical/sv/`
- branch-local blueprint exports should align on `rtl/results/canonical/blueprint/`, `rtl-synthesis/results/canonical/blueprint/`, and `rtl-formalize-synthesis/results/canonical/blueprint/`

The specs should distinguish between domain source trees and comparable export trees:

- `rtl/results/canonical/sv/` is both the baseline source-of-truth RTL tree and the comparable export tree
- `rtl-synthesis/controller/` and `rtl-formalize-synthesis/src/` remain domain-internal source locations
- `*/sv/` is the normalized branch-local comparable RTL surface consumed by branch comparison and downstream validation
- `*/blueprint/` is the normalized branch-local schematic surface, with at least `mlp_core.svg` required for each branch
- if a generated branch reuses unchanged baseline artifacts, the branch-local `sv/` and `blueprint/` trees should expose that reuse explicitly through symlinks or override files

## RTL Branch Styles

The repository intentionally does not force the three RTL branches into one internal decomposition style. The common comparison contract is the branch-local `mlp_core` surface; deeper internal review artifacts may differ by branch.

| Branch | Internal style | Stable comparable surface | Main pros | Main cons | Repository position |
| --- | --- | --- | --- | --- | --- |
| `rtl` | layered full-core RTL | explicit `controller/mac/relu/weight_rom/mlp_core` modules | inspectable, direct per-module review, good baseline for reuse | verbose manual coordination across module boundaries | accepted; baseline clarity and debuggability matter more than minimizing module count |
| `rtl-synthesis` | adapter-based mixed path | generated controller core plus compatibility wrapper plus reused baseline datapath | generation scope stays narrow, mixed-path proof target is explicit, existing datapath benches remain usable | internal layers are not uniformly 3-way comparable, adapter logic becomes a semantic bridge | accepted; the branch is judged primarily at the mixed-path `mlp_core` boundary, not by per-layer symmetry |
| `rtl-formalize-synthesis` | monolithic raw full-core plus stable wrapper | raw emitted full-core module plus stable `mlp_core` adapter | proof/emission target aligns with full-core semantics, fewer human-imposed internal boundaries | per-layer comparison is weak, wrapper packing/reset contract must be documented and checked, localized debug is harder | accepted; this branch optimizes for full-core semantic alignment rather than for per-layer structural parity |

The specs should therefore not require a uniform 3-way per-layer comparison across all RTL branches. The mandatory common comparison surface is:

- `*/results/canonical/sv/mlp_core.sv`
- `*/results/canonical/blueprint/mlp_core.svg`

Additional internal comparison views such as `controller.svg`, `controller_spot_core.svg`, or `sparkle_mlp_core.svg` are branch-specific review artifacts, not a requirement that every branch expose the same internal layers.
