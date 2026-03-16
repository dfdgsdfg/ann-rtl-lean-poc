# Compare RTL Implementations

This note compares the repository's three canonical RTL branches at the branch-local canonical surface:

- `rtl/results/canonical/`
- `rtl-synthesis/results/canonical/`
- `rtl-formalize-synthesis/results/canonical/`

The comparison contract is intentionally centered on the comparable `mlp_core` boundary. The repository does **not** require a forced 3-way symmetry for every internal layer.

## Comparison Baseline

All three branches are compared against the same frozen upstream semantic anchor:

- `contract/results/canonical/weights.json`
- the canonical vector set used by shared simulation
- the shared top-level `mlp_core` executable boundary

The common comparable surfaces are:

- `*/results/canonical/sv/mlp_core.sv`
- `*/results/canonical/blueprint/mlp_core.svg`

Everything deeper than `mlp_core` is branch-specific review evidence.

For simple whole-circuit visual comparison, each branch also exposes:

- `*/results/canonical/blueprint/blueprint.svg`

Unlike `mlp_core.svg`, this is a flattened top-level overview artifact, not the stable comparable semantic boundary.

## Implementation Summary

| Branch | Implementation style | Artifact kind | Assembly boundary | Comparable stable surface | Internal review surface |
| --- | --- | --- | --- | --- | --- |
| `rtl` | layered handwritten RTL | `baseline_full_core_rtl` | `full_core_mlp_core` | `rtl/results/canonical/sv/mlp_core.sv` | explicit `controller`, `mac_unit`, `relu_unit`, `weight_rom` modules |
| `rtl-synthesis` | generated controller plus reused datapath | `generated_controller_rtl` | `mixed_path_mlp_core` | `rtl-synthesis/results/canonical/sv/mlp_core.sv` | stable controller wrapper plus raw synthesized controller core |
| `rtl-formalize-synthesis` | monolithic generated full-core plus stable wrapper | `generated_full_core_rtl` | `full_core_mlp_core` | `rtl-formalize-synthesis/results/canonical/sv/mlp_core.sv` | wrapper-level `mlp_core` plus raw `sparkle_mlp_core` implementation |

## Structural Difference In Practice

The three branches preserve different review boundaries, not just different source origins.

- `rtl` keeps the baseline layer split visible. `controller`, `mac_unit`, `relu_unit`, and `weight_rom` remain direct review and debug units.
- `rtl-synthesis` changes the controller story without changing the datapath story. Its central question is whether a generated controller can be reinserted into the baseline shell without changing closed-loop `mlp_core` behavior.
- `rtl-formalize-synthesis` changes the implementation shape most aggressively. The raw generated artifact is a monolithic full-core module, and the stable downstream `mlp_core` is recovered through a wrapper.

That asymmetry changes how failures should be read:

- a mismatch in `rtl-synthesis` usually points to controller synthesis, controller adaptation, or controller reintegration
- a mismatch in `rtl-formalize-synthesis` is more likely to be about generation scope, wrapper packing/reset adaptation, or proof-to-emission boundary drift than about a preserved per-layer bug

## What Is Actually Comparable

### Shared 3-way comparable boundary

The repository's common 3-way comparison is:

- branch-local canonical `mlp_core` RTL
- branch-local canonical `mlp_core` blueprint
- shared simulation at the `mlp_core` top-level contract
- shared top-level SMT property family at the `mlp_core` boundary

This is the point where the three branches are deliberately aligned.

### Branch-specific internal comparison

Internal structure differs on purpose:

- `rtl` is layered and exposes `controller`, `mac_unit`, `relu_unit`, and `weight_rom`
- `rtl-synthesis` keeps the datapath layered, but replaces the controller with a generated core behind an adapter
- `rtl-formalize-synthesis` does not preserve the same layer split; it exports a monolithic generated core plus a stable wrapper

That means:

- `rtl` vs `rtl-synthesis` can support controller-level secondary comparison
- `rtl-formalize-synthesis` is primarily compared at full-core `mlp_core`, not at a forced per-layer boundary

## Validation And Test Coverage

### Shared required coverage

Every supported RTL branch is expected to pass the same common core:

1. `contract-preflight`
2. branch-local canonical surface existence
3. shared `mlp_core` dual-simulator regression
4. shared top-level SMT family at the branch-local `mlp_core` surface

This shared core is what makes the three branches meaningfully comparable.

### Branch-specific required coverage

| Branch | Required additional validation | Why it exists |
| --- | --- | --- |
| `rtl` | internal observability bench; `controller_interface` SMT | baseline layered implementation should remain directly inspectable and controller-visible |
| `rtl-synthesis` | fresh synthesis flow; adapter validation; controller-only equivalence; mixed-path closed-loop equivalence | the branch only generates the controller, so correctness must be checked both at the controller boundary and after reintegration into `mlp_core` |
| `rtl-formalize-synthesis` | Lean emit; wrapper regeneration/freshness; wrapper structural validation; raw-core review artifact | the branch exports a generated full-core monolith plus a stable wrapper, so wrapper correctness and emitted-artifact freshness are part of the branch contract |

### Branch-comparison evidence

`experiments` sits above the common required core and records comparison evidence:

- `branch-compare` summarizes maintained branch evidence
- `qor` records branch-local Yosys characterization
- `post-synth` records downstream synthesis evidence
- `artifact-consistency` is the Sparkle branch's branch-specific structural validation path

These results are important for reporting, but they do not replace the shared common verification core.

## Observed Results From The 2026-03-16 Run Set

The run set used to update this note showed three useful facts.

- All three branches passed the shared `mlp_core` dual-simulator regression on both `iverilog` and `verilator`, with `38/38` vectors passing and zero handshake, latency, coverage, or output mismatches.
- `semantic-closure` passed. Lean bridge export, frozen-contract consistency, overflow bounds, and contract-vs-RTL datapath equivalence all closed successfully.
- `artifact-consistency` for `rtl-formalize-synthesis` passed once wrapper correctness was judged by structural validation plus proof metadata, rather than by raw timestamp ordering alone.

The interesting point is not only that the runs passed. The interesting point is that they passed while the implementations remained structurally different:

- `rtl-synthesis` preserved the baseline datapath and replaced only the controller path
- `rtl-formalize-synthesis` did not preserve the baseline layering at all, yet still matched the same comparable `mlp_core` boundary

This means the repository's comparison story is doing real work. It is not rewarding branches for looking similar internally. It is rewarding them for preserving the same top-level machine contract through different implementation strategies.

## Bench And Formal Comparison

| Dimension | `rtl` | `rtl-synthesis` | `rtl-formalize-synthesis` |
| --- | --- | --- | --- |
| Shared executable bench | shared `mlp_core` dual-simulator bench | same shared `mlp_core` bench | same shared `mlp_core` bench |
| Internal observability bench | required | required because the mixed-path branch still preserves the internal baseline-oriented surface | not required |
| Shared top-level SMT | required | required | required |
| Controller-specific formal | `controller_interface` SMT | controller equivalence against synthesized core and mixed-path closed-loop equivalence | not applicable at a preserved controller boundary |
| Fresh generation check | handwritten baseline; not generation-driven | fresh Spot synthesis flow summary | Lean/Sparkle emit plus wrapper freshness and structural check |
| Primary branch claim | canonical handwritten baseline | generated controller preserves closed-loop `mlp_core` behavior after adapter integration | generated full-core branch preserves comparable `mlp_core` behavior through a stable wrapper |

## Why The Formalization Matters

The formalization path is not just "more verification." It explains why large structural differences can still be acceptable.

In the 2026-03-16 `semantic-closure` run, the frozen contract modeled hidden products as `16-bit`, while the RTL-style encoding widened hidden products to `24-bit` after sign extension to match `mac_unit` behavior. The solver still proved equivalence through all of the following:

- hidden MAC contributions
- hidden pre-activations
- hidden activations
- output products
- final score
- final thresholded `out_bit`

That is the important semantic result. The repository does not require textual sameness or per-layer isomorphism across branches. It requires a chain of evidence that the branches implement the same top-level machine contract.

For `rtl-formalize-synthesis`, that chain is intentionally split:

- Lean refinement and bridge export explain the intended meaning of the generated design
- emitted-subset and backend metadata checks narrow what Sparkle backend behavior is being relied on
- wrapper structural validation shows that the stable `mlp_core` surface still matches the raw generated core
- shared simulation and shared top-level SMT show that the resulting comparable artifact behaves like the baseline at the repository boundary

This is why the formalized branch remains meaningful even though it is the least visually similar to the handwritten baseline. The value of formalization here is not cosmetic symmetry. The value is that semantic preservation remains reviewable even after the implementation stops looking hand-layered.

## Actual Circuit Comparison

### Common comparable top-level view

These are the flattened whole-circuit blueprints that should be compared first:

- baseline: ![rtl blueprint](../rtl/results/canonical/blueprint/blueprint.svg)
- controller-synthesis branch: ![rtl-synthesis blueprint](../rtl-synthesis/results/canonical/blueprint/blueprint.svg)
- Lean/Sparkle branch: ![rtl-formalize-synthesis blueprint](../rtl-formalize-synthesis/results/canonical/blueprint/blueprint.svg)

Interpretation:

- `rtl` shows the manually layered full-core structure
- `rtl-synthesis` shows the same full-core shell with a controller replacement path
- `rtl-formalize-synthesis` shows the stable wrapper boundary, not the whole raw generated internal structure

### Why only `mlp_core.svg` is shown here

This document intentionally embeds only the branch-local flattened `blueprint.svg` views.

That keeps the visual comparison focused on one uniform file name:

- `rtl/results/canonical/blueprint/blueprint.svg`
- `rtl-synthesis/results/canonical/blueprint/blueprint.svg`
- `rtl-formalize-synthesis/results/canonical/blueprint/blueprint.svg`

The actual stable comparable semantic surface remains:

- `rtl/results/canonical/blueprint/mlp_core.svg`
- `rtl-synthesis/results/canonical/blueprint/mlp_core.svg`
- `rtl-formalize-synthesis/results/canonical/blueprint/mlp_core.svg`

Branch-specific internal review artifacts still exist, but they are not shown inline here:

- `rtl`: `controller.svg`, `mac_unit.svg`, `relu_unit.svg`, `weight_rom.svg`
- `rtl-synthesis`: `controller.svg`, `controller_spot_core.svg`
- `rtl-formalize-synthesis`: `sparkle_mlp_core.svg`

Those files remain useful when the question is about branch-local implementation detail rather than the shared top-level comparison boundary.

## How To Read The Three Branches

If the question is "do these branches implement the same top-level machine contract?", compare:

1. shared `mlp_core` simulation
2. shared top-level SMT
3. branch-local `mlp_core.svg`

If the question is "how is each branch built internally?", compare:

- baseline layered blueprints for `rtl`
- controller wrapper vs synthesized controller core for `rtl-synthesis`
- stable wrapper vs raw full-core view for `rtl-formalize-synthesis`

If the question is "which branch has the strongest local evidence for its own generation story?", the answer differs by branch:

- `rtl`: human-auditable layered baseline
- `rtl-synthesis`: controller equivalence and mixed-path closed-loop equivalence
- `rtl-formalize-synthesis`: Lean refinement theorem, emitted-subset contract, wrapper structural validation, and downstream replay

## Bottom Line

The repository compares the three RTL branches at one deliberate common surface: canonical `mlp_core`.

Below that surface:

- `rtl` optimizes for layered clarity
- `rtl-synthesis` optimizes for a narrow generated controller claim
- `rtl-formalize-synthesis` optimizes for a full-core generated claim aligned with the proof/emission boundary

That asymmetry is intentional. The branch comparison is meaningful because the common top-level contract is aligned, not because every internal layer is forced into the same shape.
