# Implementation Branch Comparison Guide

This note defines how to compare implementation branches in this repository without confusing experiment tracks with the current source of truth.

## Position

The committed hand-written RTL in `rtl/` remains the canonical implementation.

If we add a generated candidate from Lean or from a synthesis tool, it should be treated as:

- an experiment artifact
- kept separate from `rtl/`
- compared against the frozen contract and the existing RTL

The current repository does **not** have a direct Lean-to-SystemVerilog backend. The Lean files are the proof and machine-model side of the contract, not an HDL generator.

## Recommended Scope

Split the work into two distinct experiment tracks:

1. **Generated RTL from Lean-adjacent sources**

This means any candidate RTL produced from:

- a custom Lean extraction/codegen path
- a translator from a Lean machine description into RTL
- a manually curated "generated" RTL that claims to follow the Lean machine exactly

2. **Reactive-synthesis controller experiments**

This means generating only the controller/FSM from a temporal or GR(1)-style specification and then pairing it with the existing datapath assumptions.

The arithmetic datapath should stay anchored to the frozen contract. Reactive synthesis is a plausible experiment for the controller; it is not a practical replacement for the full ANN datapath flow in this repository.

## Guardrails

- Do not overwrite `rtl/src/*.sv` with generated outputs.
- Keep generated candidates in clearly separate branch-owned paths such as `experiments/rtl-formalize-synthesis/<tool-or-variant>/` or `experiments/rtl-synthesis/<tool-or-variant>/`.
- Treat `contract/result/weights.json` as the shared semantic anchor for all implementation variants.
- Treat `formalize/` as the semantic/proof anchor until a trustworthy generator exists.
- Treat reactive synthesis as controller-only unless there is a precise story for arithmetic and ROM integration.

## Comparison Matrix

Any implementation-branch comparison should report at least:

- **Functional agreement**: does the candidate match the frozen Python/contract behavior on the generated vector set?
- **Cycle agreement**: does it preserve the `76`-cycle transaction timing and the `start` / `busy` / `done` contract?
- **Trace agreement**: does its phase ordering match the expected machine schedule, especially guard cycles and `DONE` behavior?
- **QoR comparison**: synthesized area, cell count, and timing slack relative to the hand-written RTL
- **Readability / inspectability**: is the result small enough to be educational and reviewable?

## Reactive-Synthesis Track

The clean experiment is to synthesize a controller equivalent to `rtl/src/controller.sv`, not to synthesize the entire neural-network circuit.

Recommended flow:

1. encode the controller handshake and phase-ordering contract in a reactive-synthesis-friendly form
2. synthesize a controller candidate
3. translate or wrap the result into a Verilog/SystemVerilog-compatible controller module
4. run the existing simulation vectors against the combined design
5. compare timing and QoR against the hand-written controller

This keeps the research question sharp:

- can a synthesized controller satisfy the same reactive contract?
- what is the cost relative to the hand-written FSM?

## Success Criteria

This experiment is worth keeping only if it produces a report that clearly states:

- what source produced the generated RTL
- what version or commit of the generator/spec was used
- where the generated artifact lives
- whether it matches the frozen contract and handshake timing
- whether Yosys synthesis makes it better, worse, or equivalent to `rtl/`
