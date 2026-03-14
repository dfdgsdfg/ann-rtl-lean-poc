# RTL-Formalize-Synthsis Requirements

## 1. Purpose

This document defines the requirements for a Lean-to-RTL path based on [Verilean/sparkle](https://github.com/Verilean/sparkle).

The `rtl-formalize-synthesis` domain covers:

- expressing hardware in Lean using Sparkle's Signal DSL
- generating Verilog/SystemVerilog from that Lean description
- relating the generated hardware to this repository's existing contract and formal models

This domain is distinct from:

- `formalize`: pure Lean specs, machine models, and proofs
- `rtl-synthesis`: reactive controller synthesis from temporal specifications such as GR(1)/TLSF
- `asic`: logic synthesis and physical-design flow

## 2. Scope

The target is a generated RTL implementation derived from Lean.

The first practical target should be intentionally smaller than full `mlp_core`.

The preferred first milestone is one of:

1. controller-only generation that matches [`rtl/src/controller.sv`](../../rtl/src/controller.sv)
2. controller plus one or two simple primitives, such as ReLU or ROM access structure

For controller-only scope, the repository may satisfy the exact `controller.sv` module boundary with a thin stable wrapper around the emitted Sparkle module, as long as that wrapper preserves the same parameters, ports, and controller behavior.

For this controller-only milestone, code generation alone is not enough. The milestone must also include a Lean refinement result connecting the relevant pure controller semantics in `formalize/` to the Sparkle Signal DSL controller model used for emission.

This smaller scope is deliberate:

- it is more balanced with Sparkle's plausible near-term strengths as a Lean-hosted hardware DSL
- it keeps the first generated artifact inspectable
- it avoids pretending the current proof-oriented Lean files can already replace the whole RTL tree
- it still produces a meaningful generated-RTL comparison against the hand-written baseline

The domain may be delivered incrementally:

1. controller-only generation
2. controller plus simple datapath primitives
3. full generated top-level core

The current hand-written RTL in `rtl/` remains the canonical baseline until the generated path proves equivalent or better on the repository's validation suite.

## 3. Upstream Tool Assumption

The intended upstream tool is Sparkle HDL.

The design assumptions for this repository are based on the public Sparkle project claim that it supports:

- hardware description in Lean 4
- a Signal DSL for synthesizable hardware
- Verilog/SystemVerilog emission through commands such as `#synthesizeVerilog` and `#writeVerilogDesign`

This repository must treat Sparkle as an external dependency and a trusted code-generation boundary. Lean proofs about the high-level model do not automatically prove the emitted RTL.

For the controller-only milestone, the required connection is:

- pure Lean controller model in `formalize/`
- proved refinement into the Sparkle Signal DSL controller model
- emitted RTL validated separately by simulation and SMT comparison

## 4. Behavioral Requirements

The required behavior depends on the declared implementation scope.

### Controller-Only Scope

For the preferred first milestone, the generated RTL must preserve:

- the controller FSM state ordering
- the `start` / `busy` / `done` handshake contract
- the current guard-cycle behavior in `MAC_HIDDEN` and `MAC_OUTPUT`
- the `DONE` hold and release behavior

This is already meaningful because it exercises:

- explicit state
- synchronous control logic
- finite-state sequencing
- RTL emission from Lean

### Extended or Full-Core Scope

If the generated path claims more than controller-only scope, it must additionally preserve the current contract-domain behavior:

- 4 signed int8 inputs
- 8 hidden neurons
- 1 binary output
- signed fixed-point arithmetic and two's-complement wraparound
- the same frozen weights and biases as `contract/result/weights.json`

For extended or full-core scope, the generated RTL path must also preserve the current handshake and timing contract:

- `start` sampled in `IDLE`
- `busy` high exactly outside `IDLE` and `DONE`
- `done` high exactly in `DONE`
- `out_bit` valid when `done`
- exact guard-cycle behavior in `MAC_HIDDEN` and `MAC_OUTPUT`
- exact `76`-cycle latency if full behavioral equivalence is claimed

Any reduced scope must be stated explicitly and must not be described as full `mlp_core` equivalence.

## 5. Modeling Requirements

The synthesizable Lean path must be written in a hardware-restricted subset appropriate for Sparkle's Signal DSL.

At minimum, the generated path must distinguish:

- elaboration-time Lean values used for configuration and code generation
- hardware-time signals and state used for RTL generation

Required modeling rules:

- hardware-visible storage must use bounded representations such as `BitVec`, `Bool`, or Sparkle-compatible signal types
- unrestricted Lean `Int` and `Nat` may appear in pure specification code or elaboration-time helpers, but not as unbounded synthesizable state
- controller state must be explicit
- cycle-by-cycle sequencing must be explicit
- reset behavior must be explicit
- arithmetic width changes and sign extension must be explicit

If Sparkle state is represented with `Signal.loop` and named-field macros such as `declare_signal_state`, the repository should use those patterns consistently instead of ad hoc positional tuple access.

## 6. Contract Integration Requirements

The Lean-to-RTL path must integrate with the existing frozen contract flow.

At minimum, it must consume the same canonical parameter payload used elsewhere in the repository:

- `contract/result/weights.json`

Allowed integration strategies include:

- generating Sparkle Lean constants from the contract
- generating a Sparkle-friendly data module from the same Python freeze pipeline
- mechanically translating the contract payload into a Sparkle ROM definition

Manual duplication of weights between the contract and Sparkle sources is not acceptable.

## 7. Artifact Requirements

The `rtl-formalize-synthesis` flow must produce or define:

- Lean source implementing the Sparkle hardware description
- an emitted Verilog/SystemVerilog artifact
- a documented command path that generates the artifact
- the generated artifact location
- a statement of which module boundary is implemented: controller-only, datapath-only, or full core

If Sparkle emits multiple intermediate artifacts, the repository must document which one is the stable input to downstream simulation and synthesis.

## 8. Validation Requirements

The generated RTL must be validated against the repository baseline.

Required validation levels:

1. **Build validation**

- the Lean Sparkle source elaborates successfully
- the Verilog/SystemVerilog emission command succeeds

2. **Behavioral validation**

- the generated RTL passes the existing simulation-vector flow for the implemented scope
- the generated RTL matches the expected handshake semantics for the implemented scope
- controller-only scope must, at minimum, be checked against the hand-written controller contract and an integration harness
- primitive-only additions must be checked against directed tests or a wrapper-level comparison if full vector regression is not yet appropriate

3. **Comparison validation**

- the generated RTL is compared against the hand-written `rtl/` baseline
- differences in timing, state structure, and signal naming are documented

If full `mlp_core` equivalence is claimed, validation must include the repository's current simulation regression and the exact-cycle timing contract.

If only controller-level equivalence is claimed, the validation obligation is smaller:

- phase ordering agreement
- guard-cycle agreement
- `busy` / `done` agreement
- hold-in-`DONE` and release-to-`IDLE` agreement
- emitted-RTL agreement checked at the stable wrapper boundary with simulation and SMT

## 9. Proof and Trust-Boundary Requirements

This domain must make the proof boundary explicit.

The minimum required statements are:

- which properties are proved in pure Lean over the mathematical or machine model
- which controller-level properties are proved about the Sparkle Signal DSL model
- which properties are assumed about Sparkle's code generator
- whether any equivalence result is a theorem about the Signal DSL model, a simulation result about the emitted RTL, or both
- whether the claim being made is controller-only, primitive-level, or full-core

Required for the controller-only milestone:

- a refinement theorem from the repository's pure Lean controller model to the Sparkle Signal DSL controller model
- an explicit statement that this theorem stops at the Signal DSL semantics and does not, by itself, prove the emitted RTL

Desired but not mandatory for the first milestone:

- a structured argument that the generated RTL preserves the Signal DSL semantics relied on by that theorem

## 10. Acceptance Criteria

The `rtl-formalize-synthesis` domain is complete when:

1. A Sparkle-based Lean hardware description exists for a declared small but meaningful scope, preferably controller-only as the first milestone.
2. The repository documents the exact command used to emit Verilog/SystemVerilog from that Lean source.
3. The emitted RTL artifact is stored or reproducibly regenerated from committed sources.
4. The generated path consumes the same frozen contract payload as the rest of the repository when the declared scope depends on contract data.
5. The generated RTL is validated against the repository comparison flow for its declared scope.
6. The controller-only milestone includes a refinement theorem from the repository's pure Lean controller model to the Sparkle Signal DSL controller model.
7. The repository explicitly states that Sparkle-to-Verilog remains a trusted backend boundary and that emitted RTL is validated by simulation/SMT rather than proved in Lean.
8. Any stronger claim beyond controller-level equivalence states the additional validation burden it satisfies.
9. If full replacement of `rtl/src/mlp_core.sv` is claimed, the generated RTL matches the current handshake contract and exact `76`-cycle latency.
