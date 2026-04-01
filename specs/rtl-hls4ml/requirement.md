# RTL-HLS4ML Requirements

## 1. Purpose

This document defines the requirements for an hls4ml-based RTL generation path.

The `rtl-hls4ml` domain covers:

- converting the frozen contract MLP into an hls4ml model
- generating Verilog/SystemVerilog from hls4ml
- wrapping the generated output to match the repository's standard `mlp_core` boundary

This domain is distinct from:

- `rtl`: hand-written baseline RTL
- `rtl-synthesis`: reactive controller synthesis from temporal specifications
- `rtl-formalize-synthesis`: Lean/Sparkle-based RTL generation with formal proofs
- `formalize`: pure Lean specs, machine models, and proofs

## 2. Scope

The target is a generated full-core implementation of `mlp_core` derived from hls4ml.

The normative downstream boundary for this domain is the full top-level module interface currently provided by `rtl/results/canonical/sv/mlp_core.sv`:

- `clk`
- `rst_n`
- `start`
- signed `in0`, `in1`, `in2`, `in3`
- `done`
- `busy`
- `out_bit`

The current hand-written RTL in `rtl/` remains the canonical baseline.

## 3. Upstream Tool Assumption

The intended upstream tool is [hls4ml](https://github.com/fastmachinelearning/hls4ml).

hls4ml converts trained neural network models (Keras, PyTorch, ONNX) into HLS C++ code targeting FPGA synthesis through Vivado HLS or Vitis HLS. For this repository, hls4ml is used as an alternative generation path for comparison against the hand-written and Lean-generated implementations.

The repository must treat hls4ml as an external tool with no formal verification story. Unlike the `rtl-formalize-synthesis` branch, there are no Lean proofs connecting the hls4ml output to the repository's formal models. All correctness claims for this branch are validation-backed through simulation and comparison.

## 4. Behavioral Requirements

The generated full-core implementation must preserve the current contract-domain behavior:

- 4 signed int8 inputs
- 8 hidden neurons
- 1 binary output bit
- signed fixed-point arithmetic and two's-complement wraparound
- the same frozen weights and biases as `contract/results/canonical/weights.json`

The generated full-core implementation must preserve the current handshake and timing contract:

- `start` is sampled only in `IDLE`
- `busy` is high exactly outside `IDLE` and `DONE`
- `done` is high exactly in `DONE`
- `out_bit` is valid when `done`
- `done` becomes visible exactly `76` cycles after the accept cycle

## 5. Contract Integration Requirements

The hls4ml path must consume the same canonical parameter payload used elsewhere in the repository:

- `contract/results/canonical/weights.json`

The generation script reads the frozen contract weights and constructs the hls4ml model programmatically, ensuring no manual weight duplication.

## 6. Artifact Requirements

The `rtl-hls4ml` flow must produce:

- a stable top-level `mlp_core.sv` implementing the repository `mlp_core` boundary
- supporting modules: `weight_rom.sv`, `mac_unit.sv`, `relu_unit.sv`
- a normalized comparable full-core RTL export tree under `rtl-hls4ml/results/canonical/sv/`
- a normalized schematic export tree under `rtl-hls4ml/results/canonical/blueprint/`

The normalized export tree:

```text
rtl-hls4ml/
  results/
    canonical/
      sv/
        mlp_core.sv
        weight_rom.sv
        mac_unit.sv
        relu_unit.sv
      blueprint/
        blueprint.svg
        mlp_core.svg
```

## 7. Validation Requirements

The generated RTL must be validated against the repository baseline.

Inherited `common required` core:

- `contract-preflight`
- branch-local canonical surface existence under `rtl-hls4ml/results/canonical/`
- shared `mlp_core` dual-simulator regression owned by `simulations`
- shared top-level SMT family owned by `smt` at the `mlp_core` boundary

Required validation methods:

1. **Behavioral validation**: the repository's full-core shared simulation vectors pass
2. **SMT validation**: the shared `mlp_core` formal property families pass (boundary behavior, range safety, transaction capture, bounded latency)
3. **Comparison validation**: the generated RTL is compared against the hand-written baseline at the full-core boundary
4. **Downstream compatibility**: Yosys or equivalent synthesis tooling accepts the generated RTL

## 8. Proof and Trust-Boundary Requirements

This branch has no Lean formal proof story. Unlike `rtl-formalize-synthesis`, there are no refinement theorems connecting hls4ml output to the repository's Lean models.

However, this branch inherits the shared SMT verification core:

- **Boundary behavior**: hidden and output MAC boundary guard cycles, no duplicate/skipped transitions
- **Range safety**: MAC enables, selector reads, and ROM hits are in-range; guard cycles drive operands to zero
- **Transaction capture**: accepted start captures inputs and keeps them stable
- **Bounded latency**: exact 76-cycle latency from accept to done, verified by SMT solver

These SMT checks provide bounded formal guarantees stronger than simulation alone, though weaker than the Lean refinement theorems available for `rtl-formalize-synthesis`.

The branch also includes:

- simulation regression against shared test vectors
- branch-comparison experiments against the baseline
- QoR comparison through Yosys synthesis

## 9. Acceptance Criteria

The `rtl-hls4ml` domain is complete when:

1. The generation script produces a stable `mlp_core` boundary from the frozen contract weights.
2. The generated RTL passes the repository's full-core simulation regression.
3. The generated RTL matches the current `mlp_core` interface and 76-cycle latency contract.
4. The branch is integrated into the simulation, experiment, and Makefile infrastructure.
