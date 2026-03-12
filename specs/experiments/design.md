# Experiment Design

## 1. Design Goals

The experiment layer should make it easy to answer practical questions about the project without changing the core implementation.

The design should favor:

- Small, repeatable experiments
- Easy comparison across runs
- Low setup overhead
- Traceability back to committed inputs

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

## 3. Recording Strategy

Each experiment should keep a stable mapping between:

- Input configuration
- Tool command
- Output artifact
- Result summary

This can be implemented with scripts plus short markdown reports.

## 4. Suggested Workflow

1. Export a fixed parameter set
2. Generate vectors
3. Run simulation or synthesis
4. Parse outputs into a summary
5. Save the summary in a documented location

## 5. Success Signal

The experiment layer is doing its job when someone can rerun a comparison and understand what changed without reverse-engineering the repository.
