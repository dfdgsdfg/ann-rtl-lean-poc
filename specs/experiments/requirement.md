# Experiment Requirements

## 1. Purpose

This document defines optional but recommended experiment requirements for the Tiny Neural Inference ASIC.

The `experiments` domain covers:

- Functional sweeps
- Quantization sensitivity checks
- Cycle and latency measurements
- ASIC report comparisons
- Generated-implementation comparisons
- `rtl-formalize-synthsis` generated-RTL comparisons
- Reactive-synthesis controller experiments
- Cross-branch comparisons between baseline RTL, Sparkle-generated RTL, and controller-synthesis artifacts

## 2. Experiment Scope

Experiments are not required for minimum project completion, but they are expected to make the repository useful as a research and education artifact.

Recommended experiment tracks:

- Functional agreement sweeps over generated vectors
- Sensitivity to different quantized weights and biases
- Latency measurement in cycles for one inference
- Area and timing comparisons across synthesis settings
- Generated RTL from `rtl-formalize-synthsis` versus hand-written `rtl/`
- Controller-only reactive synthesis from `rtl-synthsis` versus `rtl/src/controller.sv`
- Mixed-path experiments, such as a synthesized controller paired with the hand-written datapath
- Scope-staged `rtl-formalize-synthsis` experiments: controller-only, primitive path, or full core

## 3. Reproducibility Requirements

Experiment outputs must be reproducible from:

- Committed scripts
- Versioned exported weights
- Documented commands
- Captured report locations
- Generator version or specification revision when artifacts are synthesized or generated
- Declared implementation branch and scope
- Tool versions for Sparkle or the selected reactive-synthesis tool when applicable
- Wrapper or translation revision when the generated artifact is not directly simulator-ready

Ad hoc manual experiments are not sufficient.

## 4. Output Requirements

Experiment results should produce at least one of the following:

- Markdown summaries
- Generated tables
- Logged report extracts
- Saved vector-sweep results
- Implementation-comparison reports with baseline and candidate artifact paths
- Branch-comparison reports that identify whether the result comes from `rtl/`, `rtl-formalize-synthsis`, or `rtl-synthsis`

## 5. Acceptance Criteria

The `experiments` domain is complete when:

1. At least one functional experiment is automated.
2. At least one implementation metric is measured, such as cycles, area, or timing.
3. The command path from source inputs to recorded outputs is documented.
4. Any `rtl-formalize-synthsis` or `rtl-synthsis` experiment records both provenance and comparison against the committed `rtl/` baseline.
5. Any generated implementation experiment states its declared scope, such as controller-only, primitive path, or full core.
6. Any generated implementation experiment states whether its strongest claim is a theorem-level model comparison, an RTL simulation result, or a synthesis/QoR comparison.
