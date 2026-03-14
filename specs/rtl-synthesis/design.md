# RTL-Synthesis Design

## 1. Design Goal

The purpose of this domain is to restate the existing controller contract as a reactive-synthesis problem:

- source contract: [`rtl/src/controller.sv`](../../rtl/src/controller.sv)
- integration context: [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)
- target form: a synthesized controller artifact equivalent to the hand-written FSM under explicit assumptions

The design target is narrow on purpose. We are not synthesizing the neural-network datapath. The generation scope is the controller only.

Validation is intentionally split:

- primary: validate the synthesized controller at the mixed-path `mlp_core` boundary when both designs share the same datapath context
- secondary: keep the exact-schedule controller-scoped proof as a conditional artifact that documents the abstraction boundary

This asymmetry is intentional:

- `generation_scope = controller`
- `validation_scope = mixed-path mlp_core`

The repository is not treating those as mismatched scopes by accident. It is stating that controller generation is the only defensible synthesis target here, while mixed-path `mlp_core` validation is the only defensible primary soundness claim.

## 2. Why Controller-Only

Reactive synthesis is a natural fit for discrete control logic and a poor fit for the arithmetic datapath in this repository.

The controller already has the right shape:

- finite-state
- reactive over time
- driven by a small handshake surface
- dependent on a few counter-derived conditions

The datapath does not:

- it contains arithmetic and storage structure rather than a pure reactive game objective
- it depends on ROM contents and signed arithmetic rather than only temporal control laws
- it is already straightforward to keep hand-written and validate by simulation

More concretely, GR(1)/TLSF-style synthesis is a good fit for finite control but a bad fit for this MLP datapath.

The controller can be abstracted into:

- phase bits
- guard predicates
- restart and hold conditions

The datapath cannot be abstracted as cleanly:

- it carries signed arithmetic rather than only reactive control choices
- it depends on concrete ROM contents and weight lookups
- it carries accumulated state across many cycles
- it depends on counters that are partly owned outside the synthesized controller

Even the controller-scoped specification already needs abstraction around datapath-owned counters. Extending the synthesis surface to MAC, ReLU, ROM, and accumulator behavior would sharply increase the abstraction burden and likely produce an artifact that is either unrealizable, too assumption-heavy, or not useful as a replacement candidate.

So the clean split is:

- synthesize the controller
- keep the datapath hand-written
- integrate the result at the `mlp_core` boundary and compare it against the baseline FSM

## 3. Abstraction Strategy

### 3.1 Problem With the Raw RTL Interface

[`rtl/src/controller.sv`](../../rtl/src/controller.sv) consumes `hidden_idx[3:0]` and `input_idx[3:0]`.

That interface is awkward for GR(1)/TLSF for two reasons:

- synthesis tools usually work best over Boolean control predicates, not arbitrary 4-bit arithmetic relations
- the counters are not owned by the controller; they are updated in [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)

So the synthesis problem must explicitly model a controller reacting to datapath observations, not a closed machine with total control over every state variable.

### 3.2 Predicate Abstraction

The recommended abstraction is:

| Concrete RTL observation | Abstract synthesis input |
| --- | --- |
| `start` | `start` |
| `!rst_n` sampled on a clock boundary | `reset` |
| `input_idx < 4` during `MAC_HIDDEN` | `hidden_mac_active` |
| `input_idx == 4` during `MAC_HIDDEN` | `hidden_mac_guard` |
| `hidden_idx == 7` during `NEXT_HIDDEN` | `last_hidden` |
| `input_idx < 8` during `MAC_OUTPUT` | `output_mac_active` |
| `input_idx == 8` during `MAC_OUTPUT` | `output_mac_guard` |

This abstraction is sufficient to express the transition decisions made by the hand-written controller.

### 3.3 System Representation

The recommended system outputs are one-hot phase bits:

- `phase_idle`
- `phase_load_input`
- `phase_mac_hidden`
- `phase_bias_hidden`
- `phase_act_hidden`
- `phase_next_hidden`
- `phase_mac_output`
- `phase_bias_output`
- `phase_done`

Control outputs are then constrained as derived signals:

- `load_input <-> phase_load_input`
- `clear_acc <-> phase_load_input`
- `do_bias_hidden <-> phase_bias_hidden`
- `do_act_hidden <-> phase_act_hidden`
- `advance_hidden <-> phase_next_hidden`
- `do_bias_output <-> phase_bias_output`
- `done <-> phase_done`
- `busy <-> !(phase_idle || phase_done)`
- `do_mac_hidden <-> phase_mac_hidden && hidden_mac_active`
- `do_mac_output <-> phase_mac_output && output_mac_active`

The wrapper layer can encode the one-hot phases back into the 4-bit `state` output used by [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv).

## 4. GR(1)-Shaped Specification Plan

TLSF is the source format. The formulas should stay in a GR(1)-friendly shape so tools such as Strix, ltlsynt, or a future Slugs-compatible lowering remain practical.

### 4.1 System Initialization

The synthesis model should initialize to:

- `phase_idle`
- all other phase bits low
- all derived control outputs low
- `busy = 0`
- `done = 0`

If reset is modeled explicitly, reset should force or re-enter this initialization contract on the next sampled step.

### 4.2 System Safety Guarantees

The core next-state contract is:

```text
G(phase_idle       && !start            -> X phase_idle)
G(phase_idle       &&  start            -> X phase_load_input)
G(phase_load_input                     -> X phase_mac_hidden)
G(phase_mac_hidden && !hidden_mac_guard -> X phase_mac_hidden)
G(phase_mac_hidden &&  hidden_mac_guard -> X phase_bias_hidden)
G(phase_bias_hidden                    -> X phase_act_hidden)
G(phase_act_hidden                     -> X phase_next_hidden)
G(phase_next_hidden && !last_hidden    -> X phase_mac_hidden)
G(phase_next_hidden &&  last_hidden    -> X phase_mac_output)
G(phase_mac_output && !output_mac_guard -> X phase_mac_output)
G(phase_mac_output &&  output_mac_guard -> X phase_bias_output)
G(phase_bias_output                    -> X phase_done)
G(phase_done       &&  start            -> X phase_done)
G(phase_done       && !start            -> X phase_idle)
```

Plus:

- one-hot exclusivity over phase bits
- exact definitions of the derived control outputs

### 4.3 Environment Safety Assumptions

Because the controller does not own the counters, the specification must constrain the abstract environment.

The minimum assumptions are:

- `hidden_mac_active` and `hidden_mac_guard` are not simultaneously true
- `output_mac_active` and `output_mac_guard` are not simultaneously true
- when the controller is in `MAC_HIDDEN`, the environment presents a hidden-loop observation consistent with the datapath counter contract
- when the controller is in `MAC_OUTPUT`, the environment presents an output-loop observation consistent with the datapath counter contract
- after `LOAD_INPUT`, the next hidden-loop observation corresponds to a reset hidden MAC counter
- after `ACT_HIDDEN`, the next hidden-loop observation again starts from the first hidden MAC position
- after `NEXT_HIDDEN && last_hidden`, the output-loop observation starts from the first output MAC position

For exact timing, these assumptions should be strengthened to the concrete datapath schedule instead of allowing arbitrary stuttering.

## 5. Timing Strategy

The hand-written controller has exact timing only because the datapath counters evolve in a particular way.

That means there are two legitimate synthesis claims:

1. **Control-law equivalence**

The synthesized controller makes the same decisions as `controller.sv` for all abstract counter observations satisfying the assumptions.

2. **Exact-cycle equivalence**

The synthesized controller reaches `DONE` in exactly `76` cycles after accepted `start`.

The second claim is stronger and requires stronger assumptions:

- the hidden loop presents exactly four active MAC observations followed by one guard observation per hidden neuron
- `NEXT_HIDDEN` occurs once per hidden neuron
- the output loop presents exactly eight active MAC observations followed by one guard observation

The design should separate these claims instead of smuggling the stronger one in implicitly.

The implemented flow therefore treats the exact-schedule TLSF result as secondary and uses a closed-loop mixed-path `mlp_core` equivalence check as the primary soundness claim.

## 6. Reset Modeling

The RTL controller uses an asynchronous active-low reset in Verilog.

Reactive synthesis tools typically use synchronous trace semantics, so the synthesis spec should model reset as a sampled input such as `reset`.

The wrapper strategy is:

- synthesis model: synchronous reset-to-idle contract
- generated RTL wrapper: maps the sampled reset behavior back onto the concrete module interface

This keeps the synthesis problem finite-trace and tool-friendly while preserving the externally visible reset contract.

## 7. Artifact Plan

The intended artifact chain is:

```text
controller contract
  -> TLSF spec
  -> synthesis tool result
  -> translated controller artifact
  -> Verilog/SystemVerilog wrapper
  -> comparison against rtl/src/controller.sv
```

Current repository shape for the implemented flow:

```text
rtl-synthesis/
  controller/
    controller.tlsf
    README.md
    run_flow.py
    formal/
      formal_controller_spot_equivalence.sv
      formal_closed_loop_mlp_core_equivalence.sv

build/
  rtl-synthesis/
    spot/
      generated/
      logs/
```

The committed source assets live under `rtl-synthesis/controller/`. Generated flow outputs are written under `build/rtl-synthesis/spot/`.

## 8. Tooling Direction

A practical initial tool strategy is:

- source format: TLSF
- first synthesis target: Strix or ltlsynt
- first generated artifact: AIGER or Mealy/Moore machine
- lowering step: wrapper or translator to SystemVerilog-compatible control logic

The design should avoid tool lock-in. The stable asset is the temporal contract, not any one solver's output format.

## 9. Validation Plan

The synthesized controller should be validated in three layers:

1. **Spec-level**

- the TLSF file parses
- the realizability result is recorded

2. **Controller-level secondary**

- the synthesized controller agrees with [`rtl/src/controller.sv`](../../rtl/src/controller.sv) on phase ordering
- `busy` and `done` match
- guard-cycle behavior matches
- hold-in-`DONE` and release-to-`IDLE` match

3. **Integrated RTL-level primary**

- the wrapped synthesized controller can replace the hand-written controller inside [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)
- the primary formal claim compares baseline and mixed-path `mlp_core` assemblies under the same post-reset external inputs
- the existing simulation vectors still pass
- Yosys synthesis can compare QoR against the hand-written baseline

## 10. Resolved Design Decisions

| Decision | Resolution | Rationale |
| --- | --- | --- |
| Scope | Controller-only | Reactive synthesis fits control logic, not the ANN datapath |
| Interface encoding | Predicate abstraction over counter buses | Better fit for GR(1)/TLSF and closer to the true decision surface |
| System state encoding | One-hot phase bits | Simpler safety constraints and easier wrapper reconstruction |
| Reset model | Synchronous abstraction in the synthesis spec | Matches synthesis-tool semantics better than raw async reset |
| Equivalence target | Hand-written `controller.sv` under explicit assumptions | The counters are datapath-owned, so equivalence must be conditional |
| Exact-cycle claim | Separate stronger claim | `76` cycles depends on counter-schedule assumptions, not only the controller transition graph |
