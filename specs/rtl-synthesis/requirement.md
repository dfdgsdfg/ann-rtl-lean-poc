# RTL-Synthesis Requirements

## 1. Purpose

This document defines the requirements for synthesizing the controller contract from [`rtl/src/controller.sv`](../../rtl/src/controller.sv) using a reactive-synthesis workflow.

In this repository, the `rtl-synthesis` domain means:

- temporal-specification encoding of the controller contract
- controller synthesis from that specification
- translation or wrapping of the synthesized controller into an RTL-consumable artifact

It does **not** mean ASIC logic synthesis. That remains the responsibility of `specs/asic/`.

## 2. Scope

The `rtl-synthesis` domain has:

- `artifact_kind = generated_controller_rtl`
- `assembly_boundary = mixed_path_mlp_core`
- `evidence_boundary = shared_full_core_top_level_bench` for the primary claim, with controller-scoped comparison and internal-observability replay as secondary evidence
- `evidence_method = closed_loop_formal_plus_controller_formal_plus_dual_simulator_regression`

This split is intentional. The repository is explicitly saying that synthesis is limited to the controller, while the primary evidence must still be collected at the mixed-path `mlp_core` boundary.

It covers:

- the `start` / `busy` / `done` handshake contract
- the FSM phase ordering implemented by `controller.sv`
- the controller outputs consumed by [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)
- the assumptions required because `hidden_idx` and `input_idx` are datapath-owned signals

It does not cover:

- neural-network arithmetic synthesis
- ROM generation
- datapath synthesis for MAC, ReLU, or hidden-register storage
- replacement of the hand-written `rtl/` baseline as the canonical implementation

The reason is methodological, not temporary. GR(1)/TLSF-style synthesis is a good fit for finite control but not for this MLP datapath. The controller can be expressed through phase bits and guard predicates. The datapath cannot be lowered cleanly to the same style of game because it includes signed arithmetic, ROM contents, accumulated state, and observations derived from counters the controller does not own. Even the controller-scoped specification already requires an abstraction layer for datapath-owned counters. Extending the generation scope to MAC, ReLU, ROM, and accumulator behavior would materially increase the abstraction burden and would likely produce an artifact that is not useful as a practical implementation candidate.

The validation priority is:

- primary: closed-loop mixed-path equivalence at the `mlp_core` boundary
- secondary: controller-scoped equivalence under documented counter-abstraction assumptions

This branch therefore has two distinct surfaces that the spec must keep separate:

- generation surface: controller-only synthesis and translation
- export surface: a branch-local full comparable `mlp_core` RTL tree used for branch comparison and downstream consumption

The export surface must be self-contained under `rtl-synthesis/sv/` even when the generated branch still reuses baseline datapath modules.

## 3. Behavioral Target

The synthesized controller must be trace-equivalent to the current hand-written controller for all traces satisfying the stated environment assumptions.

The target FSM states are:

- `IDLE`
- `LOAD_INPUT`
- `MAC_HIDDEN`
- `BIAS_HIDDEN`
- `ACT_HIDDEN`
- `NEXT_HIDDEN`
- `MAC_OUTPUT`
- `BIAS_OUTPUT`
- `DONE`

The target transition behavior is the same as [`rtl/src/controller.sv`](../../rtl/src/controller.sv):

- `IDLE` -> `LOAD_INPUT` when `start`
- `IDLE` -> `IDLE` when `!start`
- `LOAD_INPUT` -> `MAC_HIDDEN`
- `MAC_HIDDEN` -> `MAC_HIDDEN` until the hidden-loop terminal condition is observed
- `MAC_HIDDEN` -> `BIAS_HIDDEN` on the hidden-loop terminal condition
- `BIAS_HIDDEN` -> `ACT_HIDDEN`
- `ACT_HIDDEN` -> `NEXT_HIDDEN`
- `NEXT_HIDDEN` -> `MAC_HIDDEN` unless the last hidden neuron has completed
- `NEXT_HIDDEN` -> `MAC_OUTPUT` after the last hidden neuron
- `MAC_OUTPUT` -> `MAC_OUTPUT` until the output-loop terminal condition is observed
- `MAC_OUTPUT` -> `BIAS_OUTPUT` on the output-loop terminal condition
- `BIAS_OUTPUT` -> `DONE`
- `DONE` -> `DONE` while `start`
- `DONE` -> `IDLE` when `!start`

## 4. Interface Modeling Requirements

The current RTL module boundary is not directly ideal for GR(1) synthesis, because `controller.sv` reads datapath-owned counters:

- `hidden_idx`
- `input_idx`

The synthesis specification must therefore introduce an explicit abstraction layer.

That abstraction layer is a limitation of the generation method, not just a notation choice. The requirement is to keep the abstraction boundary narrow enough that the generated controller still integrates into the real datapath and can be validated at the mixed-path `mlp_core` boundary without pretending the datapath itself was synthesized from TLSF.

### Required Environment Inputs

At minimum, the synthesis model must represent:

- `start`
- `rst_n` or a synchronous reset abstraction derived from it
- whether the hidden-layer loop is still in its useful MAC range
- whether the hidden-layer loop has reached its guard-cycle boundary
- whether the current hidden neuron is the last hidden neuron
- whether the output-layer loop is still in its useful MAC range
- whether the output-layer loop has reached its guard-cycle boundary

The preferred representation is predicate abstraction of the raw counters rather than exposing full 4-bit buses to the synthesis engine.

### Required System Outputs

The synthesized artifact must determine:

- controller phase
- `load_input`
- `clear_acc`
- `do_mac_hidden`
- `do_bias_hidden`
- `do_act_hidden`
- `advance_hidden`
- `do_mac_output`
- `do_bias_output`
- `done`
- `busy`

The preferred synthesis outputs are one-hot phase booleans plus derived control outputs. A wrapper may then reconstruct the 4-bit `state` encoding expected by `mlp_core`.

## 5. Environment Assumption Requirements

The synthesized controller is only expected to match the hand-written controller under traces that satisfy datapath-consistency assumptions.

Those assumptions must include:

- the hidden-loop "active" and "guard reached" predicates are mutually exclusive when the controller is in `MAC_HIDDEN`
- the output-loop "active" and "guard reached" predicates are mutually exclusive when the controller is in `MAC_OUTPUT`
- after `LOAD_INPUT`, the hidden loop begins from its first useful MAC position
- after `ACT_HIDDEN`, the next hidden-loop entry begins with the hidden-loop counter reset
- after `NEXT_HIDDEN` on the last hidden neuron, the output loop begins from its first useful MAC position
- after `do_bias_output`, the output-loop guard condition remains consistent with the `DONE` entry behavior
- reset drives the controller back to the `IDLE` contract

If exact `76`-cycle latency is claimed, the assumptions must be strong enough to enforce the concrete counter schedule implemented by [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv), not just eventual loop completion.

## 6. Guarantee Requirements

The synthesis spec must guarantee:

- exactly one controller phase is active at a time
- the phase transition relation matches the hand-written FSM
- `load_input <-> phase = LOAD_INPUT`
- `clear_acc <-> phase = LOAD_INPUT`
- `do_mac_hidden <-> phase = MAC_HIDDEN` and hidden-loop-active
- `do_bias_hidden <-> phase = BIAS_HIDDEN`
- `do_act_hidden <-> phase = ACT_HIDDEN`
- `advance_hidden <-> phase = NEXT_HIDDEN`
- `do_mac_output <-> phase = MAC_OUTPUT` and output-loop-active
- `do_bias_output <-> phase = BIAS_OUTPUT`
- `done <-> phase = DONE`
- `busy <-> phase != IDLE && phase != DONE`

The guard-cycle behavior is mandatory:

- when the hidden-loop guard condition is observed in `MAC_HIDDEN`, `do_mac_hidden` must be low and the next phase must be `BIAS_HIDDEN`
- when the output-loop guard condition is observed in `MAC_OUTPUT`, `do_mac_output` must be low and the next phase must be `BIAS_OUTPUT`

The restart behavior is also mandatory:

- `DONE && start` holds `DONE`
- `DONE && !start` returns to `IDLE`

## 7. Specification Format Requirements

The source specification must be written in TLSF or a mechanically generated format that lowers to TLSF.

The practical target is a GR(1)-style fragment:

- environment initialization
- system initialization
- environment safety assumptions
- system safety guarantees
- environment liveness assumptions only if required by the selected tool
- system liveness guarantees only if required by the selected tool

If a tool requires fairness clauses beyond the safety-only controller contract, the added clauses must be the weakest ones that preserve the intended controller behavior and must be documented explicitly.

## 8. Artifact Requirements

The synthesis flow must produce or record:

- the source TLSF specification
- the chosen tool and version
- the realizability result
- the synthesized controller artifact, such as AIGER, HOA, Mealy/Moore machine, or generated Verilog wrapper input
- the translation step from the synthesis-tool artifact into an RTL-consumable form
- a branch-local comparable full-core RTL export tree under `rtl-synthesis/sv/`
- a branch-local schematic export tree under `rtl-synthesis/blueprint/`
- a controller-scoped comparison report against [`rtl/src/controller.sv`](../../rtl/src/controller.sv)
- a mixed-path full-core comparison report against [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)

The normalized branch-local export tree must provide a full `mlp_core`-comparable file layout, even though the generation scope remains controller-only. At minimum, that comparable surface should make these branch-owned paths available:

```text
rtl-synthesis/
  sv/
    mlp_core.sv
    mac_unit.sv
    relu_unit.sv
    controller.sv
    weight_rom.sv
  blueprint/
    mlp_core.svg
```

If the branch reuses baseline RTL modules, that reuse must be explicit inside the branch-local export tree:

- by checked-in symlinks such as `ln -s ../../rtl/sv/mac_unit.sv rtl-synthesis/sv/mac_unit.sv`
- or by branch-local override files that wrap, replace, or pin the reused artifact contract

Implicit downstream consumption of `rtl/src/*.sv` outside the branch-local `rtl-synthesis/sv/` tree is not an acceptable comparison contract.

## 9. Validation Requirements

Validation must cover at least:

- bounded closed-loop equivalence between the baseline `mlp_core` assembly and the synthesized-controller mixed-path `mlp_core` assembly under common external inputs
- trace-level controller equivalence or refinement against the hand-written controller under the documented assumptions
- handshake agreement for `start`, `busy`, `done`
- agreement on guard-cycle behavior in `MAC_HIDDEN` and `MAC_OUTPUT`
- agreement on hold-in-`DONE` and release-to-`IDLE` behavior
- integration with the existing datapath contract represented through the branch-local comparable `rtl-synthesis/sv/` export tree, including the shared full-core simulation bench reused by `rtl-synthesis-sim`

The maintained experiment report must surface the primary `closed_loop_mlp_core_equivalence` result and the secondary `controller_interface_equivalence` result directly from the fresh-flow summary. It must not downgrade the branch to a passing result when only simulation passes, and it must skip the branch rather than use a committed snapshot fallback when the required fresh-flow toolchain is unavailable.

The maintained comparison contract must make it obvious which files are generated, which files are reused from the baseline, and where override boundaries exist. A reviewer should be able to inspect `rtl-synthesis/sv/` alone and understand the full compared assembly without reverse-engineering implicit path reuse elsewhere in the repository.

## 10. Acceptance Criteria

The `rtl-synthesis` domain is complete when:

1. A controller-scoped reactive-synthesis specification exists and is checked into the repository.
2. The specification documents the abstraction from raw counters to synthesis-friendly predicates.
3. The specification documents the required environment assumptions induced by the datapath-owned counters.
4. A synthesis tool can report realizability for the specification.
5. A synthesized controller artifact can be translated or wrapped into an RTL-consumable form.
6. The branch materializes a self-contained comparable export tree at `rtl-synthesis/sv/`, with any baseline reuse represented explicitly through branch-local symlinks or override files.
7. The synthesized artifact is compared against the baseline `mlp_core` assembly as the primary soundness claim.
8. The branch provides `rtl-synthesis/blueprint/mlp_core.svg` as the minimum comparable diagram artifact.
9. The repository also records the secondary controller-scoped comparison against [`rtl/src/controller.sv`](../../rtl/src/controller.sv) and keeps its assumption profile explicit.
10. If exact-cycle equivalence is claimed, the repository records the stronger timing assumptions that make that claim true.
