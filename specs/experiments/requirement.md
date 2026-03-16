# Experiment Requirements

## 1. Purpose

This document defines the experiment and reporting layer for the Tiny Neural Inference ASIC.

The `experiments` domain covers:

- common experiments such as semantic closure, branch comparison, QoR, and post-synthesis characterization
- branch-specific experiments and reports attached to `rtl/`, `rtl-synthesis`, or `rtl-formalize-synthesis`
- orchestration and summary surfaces that report experiment outcomes without redefining the verification core on their own

## 2. Experiment Scope

Experiments are not the repository's `common required` verification core. They are the reporting and characterization layer that sits on top of the required simulation, SMT, and branch-specific validation steps.

The experiment scope should be organized by validation boundary rather than by tool:

### Common Experiments

These families are shared reporting or characterization surfaces:

- semantic closure
- branch comparison
- QoR
- post-synthesis validation

### Branch-Specific Experiments

These families are owned by one implementation branch and may report branch-local validation or characterization:

- Sparkle artifact-consistency and freshness studies
- reactive-synthesis realizability and translation studies
- branch-local wrapper or adapter review reports

### Semantic Closure

This family exists to close the main proof-to-implementation gap in the repository.

- Functional agreement sweeps over generated vectors
- Lean fixed-point <-> RTL datapath equivalence

### Artifact Consistency

This family keeps frozen artifacts aligned across the frozen contract and its downstream consumers.

When a branch uses an experiment runner to report artifact-consistency or wrapper-freshness results, that runner remains part of the `experiments` domain even if a branch spec separately classifies the underlying validation as `branch-specific required`.

- Contract -> ROM automatic consistency check

### Implementation Characterization

This family records concrete implementation cost using real tool outputs.

- Latency measurement in cycles for one inference
- Area and timing comparisons across synthesis settings
- QoR comparison on real run data

### Flow-Stage Validation

This family becomes required once the ASIC flow produces synthesized netlists or equivalent downstream implementation artifacts.

- Post-synthesis simulation

### Generated Implementation Comparisons

This family compares the baseline against alternative implementation paths without collapsing branch-support boundaries.

- Generated RTL from `rtl-formalize-synthesis` versus hand-written `rtl/`
- Controller-generated reactive synthesis from `rtl-synthesis` versus `rtl/results/canonical/sv/controller.sv`
- Mixed-path experiments, such as a synthesized controller paired with the hand-written datapath
- Scope-staged `rtl-formalize-synthesis` experiments: controller-only, primitive path, or full core

The experiment domain must treat the three RTL implementation branches as distinct generation/integration/validation profiles:

- `rtl/`: full-core generation, full-core integration, full-core validation
- `rtl-synthesis`: controller generation with mixed-path integration unless it explicitly replaces more than the controller, but branch-local comparison still happens through a full comparable export tree
- `rtl-formalize-synthesis`: full-core generated branch or other declared generated scope, but never implicitly baseline-equivalent

Experiment families should be labeled with one of these statuses:

- `soft-gate experiment`: may record `pass`, `fail`, or `skip`, but does not by itself redefine normative branch support
- `advisory/optional experiment`: non-gating characterization

An experiment becomes required only when a branch spec explicitly imports it as `branch-specific required`. The default for this domain is reporting, not normative branch gating.

## 3. Reproducibility Requirements

Experiment outputs must be reproducible from:

- Committed scripts
- Versioned exported weights
- Documented commands
- Captured report locations
- Generator version or specification revision when artifacts are synthesized or generated
- Declared implementation branch
- Declared generation scope
- Declared integration scope
- Declared validation scope and method
- Tool versions for Sparkle or the selected reactive-synthesis tool when applicable
- Wrapper or translation revision when the generated artifact is not directly simulator-ready

Ad hoc manual experiments are not sufficient.

## 4. Output Requirements

Experiment results should produce at least one of the following:

- Markdown summaries
- Generated tables
- Logged report extracts
- Saved vector-sweep results
- Lean/RTL equivalence reports or explicitly scoped comparison logs
- Contract-to-ROM consistency reports
- Implementation-comparison reports with baseline and candidate artifact paths
- Branch-comparison reports that identify whether the result comes from `rtl/`, `rtl-formalize-synthesis`, or `rtl-synthesis`
- Post-synthesis simulation logs when the compared artifact is synthesized
- Scope notes that identify the generation scope, integration scope, validation scope, and validation method for the recorded evidence
- Experiment status notes that identify whether the record is `soft-gate` or `advisory/optional`
- Branch-local artifact paths that resolve to `rtl/results/canonical/sv/`, `rtl-synthesis/results/canonical/sv/`, or `rtl-formalize-synthesis/results/canonical/sv/` rather than undocumented cross-branch source paths
- Branch-local diagram paths that resolve to `rtl/results/canonical/blueprint/mlp_core.svg`, `rtl-synthesis/results/canonical/blueprint/mlp_core.svg`, or `rtl-formalize-synthesis/results/canonical/blueprint/mlp_core.svg`

The experiment directory structure should default to branch-first organization:

- `experiments/rtl/`
- `experiments/rtl-synthesis/`
- `experiments/rtl-formalize-synthesis/`

Tool-specific or generator-specific subfolders are acceptable underneath those branch folders when needed.

Cross-branch comparison should treat the normalized `*/sv/` trees as the comparable RTL inputs. If a generated branch still reuses baseline RTL files, that reuse must be represented explicitly inside the branch-local export tree through symlinks or override files rather than by silently pointing comparison commands at `rtl/results/canonical/sv/`.

## 5. Acceptance Criteria

The `experiments` domain is complete when:

1. The repository documents `experiments` as a reporting and characterization layer rather than as the shared verification core.
2. At least one common experiment family is automated.
3. At least one branch-specific experiment family is documented or automated for a generated branch.
4. An automated contract -> ROM consistency check exists.
5. At least one implementation metric is measured, such as cycles, area, or timing.
6. The command path from source inputs to recorded outputs is documented.
7. Post-synthesis simulation is documented and reproducible once synthesized netlists are part of the active flow.
8. Any `rtl-formalize-synthesis` or `rtl-synthesis` experiment records both provenance and comparison against the committed `rtl/` baseline.
9. Any generated implementation experiment states its declared generation scope, such as controller, primitive path, or full core.
10. Any generated implementation experiment states its integration scope, validation scope, validation method, and experiment status.
11. Cross-branch experiment records also state the branch generation, integration, and validation scopes rather than collapsing them into a single support label.
12. The directory structure makes branch identity visible without requiring the reader to infer it from tool names alone.
13. Cross-branch experiment inputs resolve through `rtl/results/canonical/sv/`, `rtl-synthesis/results/canonical/sv/`, and `rtl-formalize-synthesis/results/canonical/sv/`.
14. Each compared branch exposes at least `blueprint/mlp_core.svg` as a normalized top-level diagram artifact.
