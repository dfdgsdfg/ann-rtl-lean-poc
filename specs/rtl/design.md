# RTL Design

## 1. Design Goals

The RTL should be:

- Small enough for a compact ASIC implementation
- Deterministic enough to debug by waveform inspection
- Close enough to the reference math to avoid semantic drift

## 2. Inference Pipeline

The execution plan is a two-phase sequential pipeline:

```text
for i in 0..7:
  acc = 0
  for j in 0..3:
    acc += W1[i,j] * x[j]
  acc += b1[i]
  h[i] = ReLU(acc)

acc = 0
for i in 0..7:
  acc += W2[i] * h[i]
acc += b2
out = (acc > 0)
```

This schedule is intentionally simple so the same operational structure can be reused in:

- Python reference code
- RTL control logic

## 3. Numeric Design Choices

- Inputs and weights remain stored as signed `int8`.
- Hidden activations are stored as signed `int16` values after `ReLU`.
- Partial sums use signed `int32`.
- Output-stage products are widened before accumulation.
- Arithmetic uses two's complement wraparound semantics throughout.

## 4. RTL Structure

### Module Decomposition

The RTL is split into five modules:

- `mlp_core.sv`: top-level integration
- `mac_unit.sv`: signed multiply and accumulate datapath primitive
- `relu_unit.sv`: combinational activation unit
- `controller.sv`: FSM and loop-counter control
- `weight_rom.sv`: constant storage for weights and biases

### Top-Level Interface

The top-level ports are:

- `clk`
- `rst_n`
- `start`
- `in0`, `in1`, `in2`, `in3` (four signed `int8` inputs)
- `done`
- `busy`
- `out_bit`

### Handshake Timing

The current controller exposes a level-based handshake contract:

- `start` is sampled in `IDLE` for transaction acceptance and in `DONE` for hold/release behavior
- if `start = 1` is sampled in `IDLE`, the transaction is accepted on that edge and the next visible state is `LOAD_INPUT`
- the transaction input vector is captured from `in0..in3` on the `LOAD_INPUT` cycle, so those inputs must remain stable through that sampling edge
- `busy` is high in every state except `IDLE` and `DONE`
- `done` is high in `DONE` and is a level, not a pulse
- the output bit is externally valid exactly when `done` is high
- `out_bit` is computed in `BIAS_OUTPUT`, registered on the edge into `DONE`, and then held while the machine remains in `DONE`
- the controller remains in `DONE` while `start` stays high
- returning to `IDLE` requires `start = 0` to be sampled in `DONE`
- a later sampled `start = 1` in `IDLE` begins the next transaction

This timing contract is as important as the arithmetic datapath, because many RTL bugs come from phase ordering and result-validity timing rather than from the multiply-accumulate math itself.

### Exact Cycle Schedule

For the current fixed `4 → 8 → 1` controller, timing is cycle-accurate and should be documented that way.

Cycle numbers below are counted from the rising edge that accepts `start` while the machine is in `IDLE`.

| Accepted-start cycle | Visible state | Notes |
|---|---|---|
| `1` | `LOAD_INPUT` | Input registers load from `in0..in3`; counters cleared |
| `2..65` | hidden-layer states | `8` hidden neurons × `8` cycles per neuron |
| `66..74` | `MAC_OUTPUT` | `8` useful MAC cycles plus `1` guard cycle |
| `75` | `BIAS_OUTPUT` | Add `b2`, register final accumulator and `out_bit` |
| `76` | `DONE` | `done = 1`, valid `out_bit` first externally observable |

This yields an exact latency of `76` cycles from accepted `start` to observable `done`.

### Boundary Conditions

The most failure-prone controller boundaries are:

- the fourth hidden-layer MAC for a neuron, where `input_idx` changes from `3` to `4`
- the following guard cycle in `MAC_HIDDEN`, where no MAC should occur and the FSM advances to `BIAS_HIDDEN`
- the step after the eighth hidden neuron finishes, where `NEXT_HIDDEN` must hand off to `MAC_OUTPUT`
- the eighth output-layer MAC, where `input_idx` changes from `7` to `8`
- the following guard cycle in `MAC_OUTPUT`, where no MAC should occur and the FSM advances to `BIAS_OUTPUT`
- the transition from `BIAS_OUTPUT` into `DONE`, where valid `out_bit` first becomes externally observable together with `done`
- the transition from `DONE` back to `IDLE` when `start` is deasserted

These boundaries should be treated as first-class verification targets, because off-by-one errors and stale-register reuse typically appear there rather than in the middle of a steady-state MAC loop.

### State and Registers

The machine state includes:

- FSM state register
- Hidden neuron index (`hidden_idx`)
- Input/output index (`input_idx`) — reused as the loop counter for both hidden-layer input MAC and output-layer weight MAC
- `int32` accumulator
- Register file for `8` hidden activations (`int16`)
- Output register (`out_bit`)

### Transition Cycles

The MAC_HIDDEN and MAC_OUTPUT states each include one transition guard cycle at the end of their loop: after the last MAC operation increments `input_idx` to the terminal value, the next cycle remains in the same state with `do_mac_*` gated off and only serves to advance the FSM.

This is not an abstract scheduling note. It is part of the current architectural contract:

- `MAC_HIDDEN` occupies `5` cycles for `4` useful MAC operations
- each hidden neuron therefore occupies `8` cycles total when `BIAS_HIDDEN`, `ACT_HIDDEN`, and `NEXT_HIDDEN` are included
- `MAC_OUTPUT` occupies `9` cycles for `8` useful MAC operations
- `BIAS_OUTPUT` then occupies `1` cycle and `DONE` becomes visible on the next cycle

Temporal proofs and simulation scoreboards should treat these guard cycles as mandatory behavior, because many off-by-one bugs come from accidentally eliding them.

## 5. FSM Design

Operational meaning of each state:

- `IDLE`: wait for `start`
- `LOAD_INPUT`: latch input vector and clear counters
- `MAC_HIDDEN`: accumulate one hidden-layer product
- `BIAS_HIDDEN`: add `b1[i]`
- `ACT_HIDDEN`: apply `ReLU` and store the hidden activation
- `NEXT_HIDDEN`: advance the hidden index or switch phase
- `MAC_OUTPUT`: accumulate `W2[i] * h[i]`
- `BIAS_OUTPUT`: add `b2` and compute `y > 0`
- `DONE`: hold the final result

This state split is slightly verbose, but it keeps the semantics obvious and easy to debug.

These state transitions are also the basis for temporal proofs in the `formalize` domain, not just end-state correctness proofs.

## 6. Memory Layout

The ROM exposes direct indexed access to:

- `W1[hidden_idx][input_idx]`
- `b1[hidden_idx]`
- `W2[input_idx]` (reuses `input_idx` during the output phase)
- `b2`

ROM contents are auto-generated from the contract weights and embedded directly in the SystemVerilog source (`weight_rom.sv`). The generation is handled by `contract/src/downstream_sync.py`.

## 7. Resolved Design Decisions

- **Top-level port naming:** inputs are `in0`..`in3` (separate signed `int8` ports), output is `out_bit`, handshake is `start`/`done`/`busy`.
- **Handshake semantics:** `done` is a level in `DONE`, not a pulse; `busy` is low in both `IDLE` and `DONE`; the controller remains in `DONE` while `start` stays high.
- **Hidden activation truncation:** `relu_unit` truncates the `int32` accumulator to `int16` after applying ReLU.
- **ROM contents:** auto-generated and embedded in HDL by the contract freeze pipeline.
- **Index reuse:** a single `input_idx` counter is reused for both hidden-layer input indexing and output-layer weight indexing.
- **MAC unit sharing:** a single `mac_unit(A_WIDTH=16, B_WIDTH=8)` is shared between hidden and output layers. Hidden-layer `int8` inputs are sign-extended to `int16` before entering the multiplier, producing an `int24` product that is sign-extended to `int32` for accumulation. This is mathematically equivalent to `int8 * int8 → int16 → int32` but uses a wider multiplier to match the output layer's `int16 * int8 → int24` requirement.
