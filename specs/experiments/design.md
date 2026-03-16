# Experiment Design

## 1. Design Goals

The experiment layer should make it easy to answer practical questions about the project without changing the core implementation.

The design should favor:

- Small, repeatable experiments
- Easy comparison across runs
- Low setup overhead
- Traceability back to committed inputs
- Clear separation between canonical implementation artifacts and experimental generated variants
- Explicit comparison across implementation branches such as `rtl/`, `rtl-formalize-synthesis`, and `rtl-synthesis`
- Explicit declaration of generation, integration, and validation scopes for each branch under comparison

## 2. Experiment Families

The experiment layer should be organized by the uncertainty each family is meant to reduce.

### Semantic Closure

Run generated vectors through:

- Python reference inference
- RTL simulation
- Assumed Lean-side semantics where applicable

The goal is to show end-to-end agreement at scale, not just with a few directed vectors.

This family should also include an explicit Lean fixed-point <-> RTL datapath equivalence study. That comparison closes the main unverified gap between the formal model and the committed datapath implementation.

### Artifact Consistency

First, check artifact consistency automatically:

- Contract -> ROM automatic consistency check

This family is about keeping frozen downstream artifacts aligned with the contract that feeds RTL, Lean, and simulation assets.

### Implementation Characterization

Measure:

- Cycles per inference
- Area across synthesis runs
- Timing slack or critical-path changes

QoR studies should use real synthesis outputs and the frozen contract inputs used elsewhere in the repository. The point is to characterize actual implementations, not hypothetical deltas.

### Flow-Stage Validation

Post-synthesis simulation should be added once the ASIC flow produces synthesized netlists or equivalent downstream artifacts.

This family checks that synthesis preserves the intended behavior under the same benches or vector suites used before synthesis.

### Generated Implementation Comparisons

Compare the committed hand-written RTL against alternative implementation paths such as:

- generated RTL derived from the `rtl-formalize-synthesis` domain
- translated controller artifacts from the `rtl-synthesis` domain
- reactive-synthesis-generated FSM candidates
- mixed-path implementations such as a synthesized controller paired with the hand-written datapath

These experiments should keep the comparison honest:

- `rtl/` stays the baseline implementation
- generated artifacts live outside `rtl/`
- the frozen contract remains the semantic anchor
- `rtl-formalize-synthesis` may target controller, primitive-only, or full-core generation, but the declared generation and validation scopes must be explicit
- `rtl-synthesis` is generation-scoped first to the controller, not the ANN datapath

Current branch conventions should be recorded as part of the experiment design:

- `rtl/`: full-core generation, full-core integration, full-core validation
- `rtl-synthesis`: controller generation, mixed-path integration, mixed-path-primary validation by swapping only the controller and reusing the baseline datapath, while still exporting a branch-local full comparable `sv/` tree
- `rtl-formalize-synthesis`: full-core generation, full-core integration, full-core validation once the emitted `mlp_core` path is materialized and validated

### RTL-Formalize-Synthsis Studies

Compare Sparkle-generated RTL against the hand-written baseline and the pure Lean model.

Typical questions:

- does the Sparkle implementation preserve the current handshake and timing contract?
- does the generated RTL preserve fixed-point arithmetic and ROM semantics?
- how much of the baseline can be replaced: controller, primitive path, or full core?
- what trust boundary remains between the pure Lean proof layer and the emitted RTL?

### RTL-Synthesis Studies

Compare controller artifacts produced from temporal specifications against `rtl/src/controller.sv`.

Typical questions:

- does the synthesized controller preserve phase ordering?
- does it preserve `start` / `busy` / `done` behavior?
- what environment assumptions were required to make the controller realizable?
- what is the QoR cost of a synthesized controller versus the hand-written FSM?

## 3. Recording Strategy

Each experiment should keep a stable mapping between:

- Experiment family and target validation boundary
- Input configuration
- Tool command
- Output artifact
- Result summary
- Source spec or generator revision when the artifact is generated rather than hand-written
- Implementation branch and declared generation scope, such as baseline full-core RTL, Sparkle full-core RTL, or GR(1)-synthesized controller
- Declared integration scope, such as full-core `mlp_core` or mixed-path `mlp_core`
- Declared validation scope, such as full-core `mlp_core`, mixed-path `mlp_core`, or controller trace parity
- Validation method, such as theorem-level model comparison, RTL simulation agreement, or QoR characterization

This can be implemented with scripts plus short markdown reports.

## 4. Recommended Layout

The experiment directory should prefer branch-oriented folders over tool-oriented folders when the main question is cross-branch support.

Recommended structure:

```text
experiments/
  rtl/
    ...
  rtl-synthesis/
    ...
  rtl-formalize-synthesis/
    ...
```

Comparable RTL inputs should come from the aligned branch export surfaces:

- `rtl/results/canonical/sv/`
- `rtl-synthesis/results/canonical/sv/`
- `rtl-formalize-synthesis/results/canonical/sv/`

Comparable top-level diagrams should come from:

- `rtl/results/canonical/blueprint/mlp_core.svg`
- `rtl-synthesis/results/canonical/blueprint/mlp_core.svg`
- `rtl-formalize-synthesis/results/canonical/blueprint/mlp_core.svg`

Within each branch folder, the experiment files should separate:

- committed wrappers or compatibility shims
- generated artifacts or references to generated artifact locations
- branch-specific reports and README notes

Layout rules:

- branch identity should be obvious from the path alone
- generated artifacts should stay outside the canonical `rtl/` source tree
- mixed-path experiments should live under the branch that owns the replacement logic, not under the baseline branch
- if tool-specific subfolders are needed, they should sit underneath the branch folder rather than replacing the branch layer
- if a generated branch reuses baseline RTL, that reuse should be materialized inside the branch-local `sv/` tree through symlinks or override files instead of hidden direct references to `rtl/src/`

## 5. Suggested Workflow

1. Select the experiment family: semantic closure, artifact consistency, implementation characterization, flow-stage validation, or generated implementation comparison
2. Export a fixed parameter set
3. Select the implementation branch to compare: `rtl/`, `rtl-formalize-synthesis`, `rtl-synthesis`, or a mixed path
4. Declare the generation, integration, and validation scopes for that branch
5. Generate vectors or consistency inputs
6. Materialize the candidate implementation variant
7. Run simulation, comparison, or synthesis
8. Parse outputs into a summary
9. Save the summary in a documented location

For implementation-branch comparisons, the summary should include:

- functional agreement against the same vector set
- cycle/handshake agreement
- synthesis report deltas
- whether the experiment is a semantic-closure check, a boundary-robustness study, a QoR characterization, or a post-synthesis validation run
- exact generator, synthesis-spec, or wrapper provenance
- declared generation scope, such as controller or full core
- declared integration scope, such as mixed-path `mlp_core` or full-core `mlp_core`
- declared validation scope and method, such as mixed-path `mlp_core` simulation, controller trace parity, or QoR characterization
- explicit trust-boundary statement when the artifact comes from `rtl-formalize-synthesis`

## 6. Success Signal

The experiment layer is doing its job when someone can rerun a comparison between the hand-written RTL, the `rtl-formalize-synthesis` path, and the `rtl-synthesis` path and understand what changed without reverse-engineering the repository.
