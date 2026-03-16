# SMT Requirements

## 1. Purpose

This document defines the requirements for solver-backed verification outside the Lean kernel in the Tiny Neural Inference ASIC repository.

In this repository, the `smt` domain means:

- SMT-backed checking of RTL safety, timing, and equivalence properties
- solver-based overflow and width-safety analysis over the frozen fixed-point contract
- reproducible recording of the solver-facing assumptions, properties, and toolchain choices

It does **not** mean:

- replacing the Lean formalization as the main semantic proof backbone
- SMT-assisted theorem proving inside Lean; that belongs to `specs/formalize-smt/`
- replacing simulation as the practical regression flow
- replacing the canonical hand-written RTL baseline
- ASIC logic synthesis

## 2. Scope

The `smt` domain is a verification and automation layer that sits beside `rtl`, `formalize`, and `simulations`.

It covers:

- controller and top-level RTL property checking for [`rtl/results/canonical/sv/controller.sv`](../../rtl/results/canonical/sv/controller.sv) and [`rtl/results/canonical/sv/mlp_core.sv`](../../rtl/results/canonical/sv/mlp_core.sv)
- QF_BV-style reasoning about fixed widths, wraparound, guards, and bounded traces
- equivalence-style checks between RTL-level behavior and the frozen contract where practical

It does not cover:

- ANN training or quantization
- replacement of the frozen contract in `contract/results/canonical/`
- unrestricted theorem proving outside the Lean kernel
- proof automation tactics inside `formalize/`
- generated RTL becoming canonical without separate validation

## 3. Verification Target Requirements

The SMT domain must target the same frozen arithmetic and control contract used elsewhere in the repository.

Required verification targets:

1. Handshake and control properties
2. Boundary and guard-cycle properties
3. Width and overflow properties over the frozen quantized datapath
4. Optional equivalence properties between two machine-readable views

The first milestone should prioritize control correctness over arithmetic sophistication.

## 4. RTL Property Requirements

At minimum, the SMT layer must be able to state and check properties for:

- accepted `start` causing the correct transition out of `IDLE`
- `busy` being high throughout active execution and low in `IDLE` and `DONE`
- `done` matching entry into `DONE`
- hold-in-`DONE` while `start`
- release-to-`IDLE` when `!start`
- hidden guard-cycle behavior after the fourth hidden MAC
- output guard-cycle behavior after the eighth output MAC
- absence of duplicate or skipped control work at the boundary transitions
- absence of out-of-range loop reads at the hidden and output boundaries

If exact `76`-cycle completion is claimed in the SMT layer, the property set must also record the environment assumptions that make that statement true.

## 5. Arithmetic and Datapath Requirements

The SMT layer may check arithmetic properties over the frozen contract, but those checks must remain tied to the committed quantized payload in [`contract/results/canonical/weights.json`](../../contract/results/canonical/weights.json).

Allowed target properties include:

- hidden-product widths fit signed `int16`
- output-product widths fit signed `int24`
- accumulator ranges fit signed `int32`
- sign extension and wraparound behavior are modeled consistently with the contract
- miter-style equivalence between two width-accurate encodings of the same frozen network

If such properties are solver-checked directly, the encoding must make the bit widths and overflow rules explicit rather than relying on unbounded integer arithmetic by accident.

## 6. Tooling Requirements

The SMT domain must prefer tools that fit the target problem instead of treating all solver work as one undifferentiated task.

Recommended roles:

- RTL property checking: SymbiYosys / Yosys-SMTBMC with an SMT backend
- bitvector-heavy arithmetic analysis: a QF_BV-strong solver such as Bitwuzla, Z3, or cvc5

The stable asset in this repository is the property set and contract assumptions, not a single solver's output format.

Solver-assisted Lean proof automation, if adopted, must be specified separately in `specs/formalize-smt/`.

## 7. Artifact Requirements

The SMT flow must record or generate:

- the source property files and harnesses
- the tool and version used
- the selected backend solver
- the assumptions required by each property family
- a machine-runnable command path for reproducing the check
- a concise pass/fail summary suitable for CI or local review

Large transient solver logs, traces, or proof dumps do not need to be committed unless the repository explicitly chooses to keep them as debugging artifacts.

## 8. Integration Requirements

The SMT layer must integrate with the rest of the repository as a complement, not a parallel source of truth.

Integration rules:

- the frozen contract remains the arithmetic source of truth
- the hand-written RTL remains the canonical implementation baseline
- Lean remains the main semantic proof layer
- SMT results may strengthen confidence and catch shallow bugs quickly, but they do not by themselves replace the end-to-end correctness argument

If SMT checks are wired into a command or CI target, a failed property check should be treated as a verification failure, not as advisory output.

## 9. Acceptance Criteria

The `smt` domain is complete for its first milestone when:

1. A checked-in SMT requirements document and design document exist under `specs/smt/`.
2. The repository records a solver-backed verification strategy for RTL control properties.
3. The repository records how frozen arithmetic assumptions enter any SMT encoding.
4. The repository explicitly separates SMT-backed verification from both the Lean proof backbone and any optional SMT-assisted Lean flow.
5. The intended artifacts, assumptions, and reproduction commands are specified clearly enough to implement without re-deciding the scope.
