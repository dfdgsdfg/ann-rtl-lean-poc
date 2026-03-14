# RTL-Formalize-Synthesis Requirements

## 1. Purpose

This document defines the requirements for a Lean-to-RTL path based on [Verilean/sparkle](https://github.com/Verilean/sparkle).

The `rtl-formalize-synthesis` domain covers:

- expressing the TinyMLP hardware in Lean using Sparkle's Signal DSL
- generating Verilog/SystemVerilog from that Lean description
- relating the generated hardware to this repository's existing contract and formal models

This domain is distinct from:

- `formalize`: pure Lean specs, machine models, and proofs
- `rtl-synthesis`: reactive controller synthesis from temporal specifications such as GR(1)/TLSF
- `asic`: logic synthesis and physical-design flow

## 2. Scope

The target is a generated full-core implementation of `mlp_core` derived from Lean.

The normative downstream boundary for this domain is the full top-level module interface currently provided by [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv):

- `clk`
- `rst_n`
- `start`
- signed `in0`, `in1`, `in2`, `in3`
- `done`
- `busy`
- `out_bit`

Auxiliary generated artifacts such as controller-only or primitive-only submodules may exist as implementation details, but they do not satisfy this domain contract on their own.

The current hand-written RTL in `rtl/` remains the canonical baseline until the generated path proves equivalent or better on the repository's validation suite.

## 3. Upstream Tool Assumption

The intended upstream tool is Sparkle HDL.

The design assumptions for this repository are based on the public Sparkle project claim that it supports:

- hardware description in Lean 4
- a Signal DSL for synthesizable hardware
- Verilog/SystemVerilog emission through commands such as `#synthesizeVerilog` and `#writeVerilogDesign`

This repository must treat Sparkle as an external dependency and a trusted code-generation boundary. Lean proofs about the Sparkle Signal DSL model do not automatically prove the emitted RTL.

The required semantic connection for this domain is:

- pure Lean machine and temporal semantics in `formalize/`
- proved refinement into a Sparkle Signal DSL full-core model of `mlp_core`
- emitted RTL validated separately by simulation, SMT, and synthesis comparison

## 4. Behavioral Requirements

The generated full-core implementation must preserve the current contract-domain behavior:

- 4 signed int8 inputs
- 8 hidden neurons
- 1 binary output bit
- signed fixed-point arithmetic and two's-complement wraparound
- the same frozen weights and biases as `contract/result/weights.json`

The generated full-core implementation must preserve the current handshake and timing contract:

- `start` is sampled only in `IDLE`
- an accepted `start` transitions to `LOAD_INPUT`
- `LOAD_INPUT` captures the current `in0` through `in3` values and clears the hidden registers, accumulator, indices, and output register exactly as the baseline does
- `busy` is high exactly outside `IDLE` and `DONE`
- `done` is high exactly in `DONE`
- `out_bit` is valid when `done`
- `DONE` holds while `start` remains high and returns to `IDLE` when `start` goes low
- accepted `start` to `done` latency is exactly `76` cycles

The generated full-core implementation must preserve the current cycle-exact state schedule:

- the same phase ordering through `IDLE`, `LOAD_INPUT`, `MAC_HIDDEN`, `BIAS_HIDDEN`, `ACT_HIDDEN`, `NEXT_HIDDEN`, `MAC_OUTPUT`, `BIAS_OUTPUT`, and `DONE`
- the same guard-cycle behavior in `MAC_HIDDEN` and `MAC_OUTPUT`
- the same hidden-index and input-index progression at every phase boundary
- the same final hidden-neuron handoff into output accumulation
- the same output finalization point in `BIAS_OUTPUT`

Reset-visible behavior must also match the current baseline at the top-level boundary:

- reset behavior must be explicit
- registers and indices must initialize to the same zero or false values as the current RTL
- no reset-time behavior may contradict the external `mlp_core` contract

## 5. Modeling Requirements

The synthesizable Lean path must be written in a hardware-restricted subset appropriate for Sparkle's Signal DSL.

At minimum, the generated path must distinguish:

- elaboration-time Lean values used for configuration and code generation
- hardware-time signals and state used for RTL generation

Required modeling rules:

- hardware-visible storage must use bounded representations such as `BitVec`, `Bool`, or Sparkle-compatible signal types
- unrestricted Lean `Int` and `Nat` may appear in pure specification code or elaboration-time helpers, but not as unbounded synthesizable state
- the full machine state required to realize `mlp_core` semantics must be explicit, including phase, input registers, hidden registers, accumulator, indices, and output register
- cycle-by-cycle sequencing must be explicit
- reset behavior must be explicit
- arithmetic width changes, sign extension, and wraparound points must be explicit

Controller and datapath decomposition is allowed, but the integrated Sparkle design must define the same cycle-visible semantics as the full-core baseline.

If Sparkle state is represented with `Signal.loop` and named-field macros such as `declare_signal_state`, the repository should use those patterns consistently instead of ad hoc positional tuple access.

## 6. Contract Integration Requirements

The Lean-to-RTL path must integrate with the existing frozen contract flow.

At minimum, it must consume the same canonical parameter payload used elsewhere in the repository:

- `contract/result/weights.json`

Allowed integration strategies include:

- generating Sparkle Lean constants from the contract
- generating a Sparkle-friendly data module from the same Python freeze pipeline
- mechanically translating the contract payload into a Sparkle ROM or equivalent bounded lookup structure

Manual duplication of weights and biases between the contract and Sparkle sources is not acceptable.

## 7. Artifact Requirements

The `rtl-formalize-synthesis` flow must produce or define:

- Lean source implementing the Sparkle full-core hardware description
- Lean source or generated data modules carrying the frozen contract payload needed by the full core
- an emitted Verilog/SystemVerilog artifact implementing the full `mlp_core` boundary
- a documented command path that generates the artifact
- the generated artifact location
- the stable top-level artifact used by downstream simulation, SMT, and synthesis flows

If Sparkle emits multiple intermediate artifacts, the repository must document which one is the stable full-core input to downstream consumers.

## 8. Validation Requirements

The generated RTL must be validated against the repository baseline.

Required validation levels:

1. **Build validation**

- the Lean Sparkle source elaborates successfully
- the Verilog/SystemVerilog emission command succeeds

2. **Behavioral validation**

- the generated RTL passes the repository's existing full-core simulation-vector flow at the `mlp_core` boundary
- the generated RTL matches the expected handshake semantics
- the generated RTL matches the exact `76`-cycle timing contract
- the generated RTL preserves the documented phase-boundary and guard-cycle behavior exercised by the shared regression bench

3. **Comparison validation**

- the generated RTL is compared against the hand-written `rtl/` baseline at the full-core boundary
- comparison checks are strong enough to detect arithmetic, timing, or cycle-schedule drift
- differences in internal naming or structural decomposition may be documented, but externally visible semantics must remain equivalent

4. **Downstream compatibility validation**

- Yosys or equivalent downstream synthesis tooling accepts the generated RTL
- generated RTL is usable by the repository's existing simulation, SMT, and ASIC-facing flows

## 9. Proof and Trust-Boundary Requirements

This domain must make the proof boundary explicit.

The minimum required statements are:

- which properties are proved in pure Lean over the mathematical, machine, and temporal model
- which full-core properties are proved about the Sparkle Signal DSL model
- which properties are assumed about Sparkle's code generator
- whether any equivalence result is a theorem about the Signal DSL model, a validation result about the emitted RTL, or both
- whether the claim being made is about the Signal DSL full-core model, the emitted RTL, or both

Required for this domain:

- a refinement theorem from the repository's pure Lean full-core machine and temporal semantics to the Sparkle Signal DSL full-core model
- theorem statements strong enough to cover the cycle-visible semantics relied on by the external `mlp_core` contract
- an explicit statement that the Lean theorem stops at the Signal DSL semantics and does not, by itself, prove the emitted RTL

Desired but not mandatory:

- a structured semantics-preservation argument between the Sparkle Signal DSL model and the emitted RTL
- direct structural checks for generated interface packing or backend-specific lowering details if those details become part of the stable downstream artifact contract

## 10. Acceptance Criteria

The `rtl-formalize-synthesis` domain is complete when:

1. A Sparkle-based Lean hardware description exists for the full `mlp_core` boundary.
2. The repository documents the exact command used to emit Verilog/SystemVerilog from that Lean source.
3. The emitted full-core RTL artifact is stored or reproducibly regenerated from committed sources.
4. The generated path consumes the same frozen contract payload as the rest of the repository.
5. The generated RTL matches the current `mlp_core` interface, handshake contract, cycle schedule, and exact `76`-cycle latency.
6. The generated RTL passes the repository's full-core regression and comparison flow.
7. A Lean refinement theorem connects the repository's pure Lean full-core semantics to the Sparkle Signal DSL full-core model.
8. The repository explicitly states that Sparkle-to-Verilog remains a trusted backend boundary and that emitted RTL is validated by simulation, SMT, and synthesis rather than proved in Lean alone.
