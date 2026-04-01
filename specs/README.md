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
- `formalize-smt`: optional SMT-backed Lean proof lane
- `smt`: solver-backed verification outside Lean
- `rtl-formalize-synthesis`: Lean Signal-DSL hardware generation via Sparkle
- `rtl-synthesis`: reactive controller synthesis from temporal specifications
- `rtl-hls4ml`: hls4ml-based RTL generation for comparison
- `simulations`: shared executable validation for branch-local RTL exports
- `experiments`: comparison, characterization, and reporting over validated branches
- `asic`: synthesis and physical-design flow

## Process

Canonical implementation path:
`ann -> contract -> rtl -> simulations + smt -> asic`

Optional controller-synthesis branch:
`ann -> contract -> rtl + rtl-synthesis -> simulations + smt -> asic`

Optional Lean-generated RTL branch:
`ann -> contract -> formalize -> rtl-formalize-synthesis -> simulations + smt -> asic`

Optional hls4ml-generated RTL branch:
`ann -> contract -> rtl-hls4ml -> simulations -> asic`

Cross-branch comparison and characterization complement:
`rtl branches -> experiments`

Optional parallel Lean-SMT proof lane:
`formalize -> formalize-smt`

## RTL Verification Ladder

The RTL branches use one shared verification ladder with branch-specific extension packs:

1. `contract-preflight`
2. branch-local canonical surface existence
3. shared executable validation owned by `simulations`
4. shared top-level SMT family owned by `smt`
5. branch-specific required validation owned by each RTL branch
6. common experiments owned by `experiments`
7. branch-specific experiments owned by `experiments`

The first four steps are the repository-wide common required core. Step five is required per branch. Steps six and seven are experiment/reporting layers; they may record `pass`, `fail`, or `skip`, but they do not redefine the normative branch-support boundary unless a branch spec explicitly imports them as required.

Step four applies to every supported RTL branch, not only to the baseline. The shared top-level SMT family must be instantiated against each branch-local canonical `mlp_core` surface:

- `rtl/results/canonical/sv/mlp_core.sv`
- `rtl-synthesis/results/canonical/sv/mlp_core.sv`
- `rtl-formalize-synthesis/results/canonical/sv/mlp_core.sv`
- `rtl-hls4ml/results/canonical/sv/mlp_core.sv`

## Verification Status Vocabulary

The specs should use one status vocabulary:

- `common required`: repository-wide required verification shared by all supported RTL branches
- `branch-specific required`: additional required validation owned by one branch
- `soft-gate experiment`: reportable experiment that may fail or skip without redefining normative branch support on its own
- `advisory/optional experiment`: non-gating characterization or exploratory work

## RTL Branch Scopes

The `simulations`, `smt`, and `experiments` specs should state the generation, integration, and validation scopes for each RTL branch. Branch-facing reports may spell those same boundaries through `artifact_kind`, `assembly_boundary`, `evidence_boundary`, and `evidence_method`, but they should not hide the underlying scope split:

- `rtl/`: full-core generation, full-core integration, and full-core validation at `mlp_core`
- `rtl-synthesis`: controller generation with mixed-path `mlp_core` integration unless a wider generated replacement is declared; however, its branch-local export surface must still materialize a full comparable `mlp_core` tree
- `rtl-formalize-synthesis`: full-core generation with full-core `mlp_core` integration and validation, or another explicitly declared generated scope
- `rtl-hls4ml`: full-core generation with full-core `mlp_core` integration and validation, validation-backed only (no formal proofs)

They should also prefer a branch-first layout:

- `experiments/` should use branch folders directly
- `simulations/` should keep shared assets separate from branch-local benches
- `smt/` should distinguish shared top-level families from branch-owned required formal add-ons
- branch-local comparable RTL exports should align on `rtl/results/canonical/sv/`, `rtl-synthesis/results/canonical/sv/`, `rtl-formalize-synthesis/results/canonical/sv/`, and `rtl-hls4ml/results/canonical/sv/`
- branch-local blueprint exports should align on `rtl/results/canonical/blueprint/`, `rtl-synthesis/results/canonical/blueprint/`, `rtl-formalize-synthesis/results/canonical/blueprint/`, and `rtl-hls4ml/results/canonical/blueprint/`

The specs should distinguish between domain source trees and comparable export trees:

- `rtl/results/canonical/sv/` is both the baseline source-of-truth RTL tree and the comparable export tree
- `rtl-synthesis/controller/` and `rtl-formalize-synthesis/src/` remain domain-internal source locations
- `*/sv/` is the normalized branch-local comparable RTL surface consumed by branch comparison and downstream validation
- `*/blueprint/` is the normalized branch-local schematic surface, with `mlp_core.svg` as the required stable comparable boundary and `blueprint.svg` as the required flattened whole-circuit overview artifact for each branch
- if a generated branch reuses unchanged baseline artifacts, the branch-local `sv/` and `blueprint/` trees should expose that reuse explicitly through symlinks or override files

## RTL Branch Styles

The repository intentionally does not force the four RTL branches into one internal decomposition style. The common comparison contract is the branch-local `mlp_core` surface; deeper internal review artifacts may differ by branch.

| Branch | Internal style | Stable comparable surface | Main pros | Main cons | Repository position |
| --- | --- | --- | --- | --- | --- |
| `rtl` | layered full-core RTL | explicit `controller/mac/relu/weight_rom/mlp_core` modules | inspectable, direct per-module review, good baseline for reuse | verbose manual coordination across module boundaries | accepted; baseline clarity and debuggability matter more than minimizing module count |
| `rtl-synthesis` | adapter-based mixed path | generated controller core plus compatibility wrapper plus reused baseline datapath | generation scope stays narrow, mixed-path proof target is explicit, existing datapath benches remain usable | internal layers are not uniformly comparable, adapter logic becomes a semantic bridge | accepted; the branch is judged primarily at the mixed-path `mlp_core` boundary, not by per-layer symmetry |
| `rtl-formalize-synthesis` | monolithic raw full-core plus stable wrapper | raw emitted full-core module plus stable `mlp_core` adapter | proof/emission target aligns with full-core semantics, fewer human-imposed internal boundaries | per-layer comparison is weak, wrapper packing/reset contract must be documented and checked, localized debug is harder | accepted; this branch optimizes for full-core semantic alignment rather than for per-layer structural parity |
| `rtl-hls4ml` | layered full-core RTL generated from contract | explicit `controller/mac/relu/weight_rom/mlp_core` modules matching baseline decomposition | direct comparison with baseline, familiar module structure, no wrapper complexity | no formal proof story, validation-backed only | accepted; this branch provides an hls4ml comparison point with the simplest trust model |

The specs should therefore not require a uniform per-layer comparison across all RTL branches. The mandatory common comparison surface is:

- `*/results/canonical/sv/mlp_core.sv`
- `*/results/canonical/blueprint/mlp_core.svg`

Additional internal comparison views such as `controller.svg`, `controller_spot_core.svg`, or `sparkle_mlp_core.svg` are branch-specific review artifacts, not a requirement that every branch expose the same internal layers. Separately, `*/results/canonical/blueprint/blueprint.svg` is the normalized flattened whole-circuit review view used for simple side-by-side visual comparison.
