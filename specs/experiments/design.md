# Experiment Design

## 1. Design Goals

The experiment layer should make it easy to answer practical questions about the project without changing the core implementation.

The design should favor:

- Small, repeatable experiments
- Easy comparison across runs
- Low setup overhead
- Traceability back to committed inputs
- Clear separation between canonical implementation artifacts and experimental generated variants
- Explicit comparison across implementation branches such as `rtl/`, `rtl-formalize-synthsis`, and `rtl-synthesis`

## 2. Recommended Experiment Tracks

### Functional Sweeps

Run generated vectors through:

- Python reference inference
- RTL simulation
- Assumed Lean-side semantics where applicable

The goal is to show end-to-end agreement at scale, not just with a few directed vectors.

### Quantization Sensitivity

Compare behavior under:

- Different toy-trained parameter sets
- Alternative quantization choices
- Boundary-case weights and biases

### Performance and Cost

Measure:

- Cycles per inference
- Area across synthesis runs
- Timing slack or critical-path changes

### Generated Implementation Comparisons

Compare the committed hand-written RTL against alternative implementation paths such as:

- generated RTL derived from the `rtl-formalize-synthsis` domain
- translated controller artifacts from the `rtl-synthesis` domain
- reactive-synthesis-generated FSM candidates
- mixed-path implementations such as a synthesized controller paired with the hand-written datapath

These experiments should keep the comparison honest:

- `rtl/` stays the baseline implementation
- generated artifacts live outside `rtl/`
- the frozen contract remains the semantic anchor
- `rtl-formalize-synthsis` may target controller-only, primitive-only, or full-core generation, but the declared scope must be explicit
- `rtl-synthesis` is scoped first to the controller, not the ANN datapath

### RTL-Formalize-Synthsis Studies

Compare Sparkle-generated RTL against the hand-written baseline and the pure Lean model.

Typical questions:

- does the Sparkle implementation preserve the current handshake and timing contract?
- does the generated RTL preserve fixed-point arithmetic and ROM semantics?
- how much of the baseline can be replaced: controller-only, primitive path, or full core?
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

- Input configuration
- Tool command
- Output artifact
- Result summary
- Source spec or generator revision when the artifact is generated rather than hand-written
- Implementation branch and declared scope, such as baseline RTL, Sparkle controller-only RTL, or GR(1)-synthesized controller
- Validation level, such as theorem-level model comparison, RTL simulation agreement, or QoR-only comparison

This can be implemented with scripts plus short markdown reports.

## 4. Suggested Workflow

1. Export a fixed parameter set
2. Select the implementation branch to compare: `rtl/`, `rtl-formalize-synthsis`, `rtl-synthesis`, or a mixed path
3. Generate vectors
4. Materialize the candidate implementation variant
5. Run simulation or synthesis
6. Parse outputs into a summary
7. Save the summary in a documented location

For implementation-branch comparisons, the summary should include:

- functional agreement against the same vector set
- cycle/handshake agreement
- synthesis report deltas
- exact generator, synthesis-spec, or wrapper provenance
- declared implementation scope, such as controller-only or full core
- explicit trust-boundary statement when the artifact comes from `rtl-formalize-synthsis`

## 5. Success Signal

The experiment layer is doing its job when someone can rerun a comparison between the hand-written RTL, the `rtl-formalize-synthsis` path, and the `rtl-synthesis` path and understand what changed without reverse-engineering the repository.
