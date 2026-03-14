# Experiment Requirements

## 1. Purpose

This document defines optional but recommended experiment requirements for the Tiny Neural Inference ASIC.

The `experiments` domain covers:

- Semantic-closure experiments between Lean fixed-point semantics, frozen contract artifacts, and committed RTL
- Artifact-consistency checks around the frozen contract boundary
- Cycle, latency, area, and timing measurements
- Post-synthesis validation once synthesized netlists exist
- Generated-implementation comparisons
- `rtl-formalize-synthesis` generated-RTL comparisons
- Reactive-synthesis controller experiments
- Cross-branch comparisons between baseline RTL, Sparkle-generated RTL, and controller-synthesis artifacts

## 2. Experiment Scope

Experiments are not required for minimum project completion, but they are expected to make the repository useful as a research and education artifact.

The experiment scope should be organized by validation boundary rather than by tool:

### Semantic Closure

This family exists to close the main proof-to-implementation gap in the repository.

- Functional agreement sweeps over generated vectors
- Lean fixed-point <-> RTL datapath equivalence

### Artifact Consistency

This family keeps the frozen artifacts aligned across the frozen contract and its downstream consumers.

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
- Controller-generated reactive synthesis from `rtl-synthesis` versus `rtl/src/controller.sv`
- Mixed-path experiments, such as a synthesized controller paired with the hand-written datapath
- Scope-staged `rtl-formalize-synthesis` experiments: controller-only, primitive path, or full core

The experiment domain must treat the three RTL implementation branches as distinct generation/integration/validation profiles:

- `rtl/`: full-core generation, full-core integration, full-core validation
- `rtl-synthesis`: controller generation with mixed-path integration unless it explicitly replaces more than the controller
- `rtl-formalize-synthesis`: full-core generated branch or other declared generated scope, but never implicitly baseline-equivalent

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

The experiment directory structure should default to branch-first organization:

- `experiments/rtl/`
- `experiments/rtl-synthesis/`
- `experiments/rtl-formalize-synthesis/`

Tool-specific or generator-specific subfolders are acceptable underneath those branch folders when needed.

## 5. Acceptance Criteria

The `experiments` domain is complete when:

1. At least one semantic-closure experiment is automated.
2. An automated contract -> ROM consistency check exists.
3. At least one implementation metric is measured, such as cycles, area, or timing.
4. The command path from source inputs to recorded outputs is documented.
5. Post-synthesis simulation is documented and reproducible once synthesized netlists are part of the active flow.
6. Any `rtl-formalize-synthesis` or `rtl-synthesis` experiment records both provenance and comparison against the committed `rtl/` baseline.
7. Any generated implementation experiment states its declared generation scope, such as controller, primitive path, or full core.
8. Any generated implementation experiment states its integration scope, validation scope, and whether its strongest claim is a theorem-level model comparison, an RTL simulation result, or a synthesis/QoR comparison.
9. Cross-branch experiment records also state the branch generation, integration, and validation scopes rather than collapsing them into a single support label.
10. The directory structure makes branch identity visible without requiring the reader to infer it from tool names alone.
