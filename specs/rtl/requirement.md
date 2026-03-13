# RTL Requirements

## 1. Purpose

This document defines the RTL requirements for the Tiny Neural Inference ASIC.

The `rtl` domain covers:

- Neural inference behavior to be implemented in hardware
- Fixed-point and signed arithmetic rules
- Datapath and controller requirements
- Memory organization and required source files

## 2. Functional Model

The RTL must implement a two-layer MLP with the following shape:

- Input dimension: `4`
- Hidden dimension: `8`
- Output dimension: `1`
- Hidden activation: `ReLU`
- Final output: binary classification

The hardware-visible behavior is:

```text
h_i = ReLU(sum_j (W1[i,j] * x_j) + b1[i])
y = sum_i (W2[i] * h_i) + b2
out = (y > 0)
```

## 3. Data Representation

Floating-point arithmetic is out of scope. All operations must use signed integer or fixed-point style arithmetic.

| Component | Type |
| --- | --- |
| Input | `int8` |
| Weight | `int8` |
| Hidden activation | `int16` |
| Accumulator | `int32` |
| Bias | `int32` |
| Output | `1 bit` |

## 4. Arithmetic Semantics

- Hidden-layer multiplication must behave as `int8 * int8 -> int16` (or equivalently, sign-extend `int8` to `int16` and compute `int16 * int8 -> int24`; the mathematical result is identical since `int8 * int8` never overflows `int16`).
- Output-layer multiplication must behave as `int16 * int8 -> int24`.
- Products must be sign-extended to `int32` before accumulation.
- Accumulation must use a signed `int32` accumulator.
- ReLU must behave as:

```text
ReLU(x) = 0, if x < 0
ReLU(x) = x, otherwise
```

- Arithmetic must follow signed two's complement semantics.
- Overflow policy must be wraparound, not saturation.
- Narrow values consumed by a wider stage must be sign-extended.

## 5. Architecture Requirements

### Compute Strategy

The RTL must use a sequential MAC-reuse architecture with:

- One multiplier
- One accumulator register
- Sequential weight reads
- Hidden neurons computed one at a time

### Required Datapath Components

The RTL must include at least:

- Multiplier
- Accumulator register
- Bias adder
- ReLU unit
- Comparator implementing `y > 0`

### Control FSM

The controller must implement the following states:

- `IDLE`
- `LOAD_INPUT`
- `MAC_HIDDEN`
- `BIAS_HIDDEN`
- `ACT_HIDDEN`
- `NEXT_HIDDEN`
- `MAC_OUTPUT`
- `BIAS_OUTPUT`
- `DONE`

The FSM must satisfy:

- Deterministic transition behavior
- Guaranteed termination after `start`
- Sequential computation of all hidden neurons before the output stage

### Interface Timing Contract

The RTL must define and preserve the timing meaning of its control signals.

For the current `4 → 8 → 1` controller, the contract is exact, not approximate:

- `start` is sampled in `IDLE` for transaction acceptance and in `DONE` for hold/release behavior
- if `start = 1` is sampled in `IDLE`, the transaction is accepted on that rising clock edge and the next visible state is `LOAD_INPUT`
- the transaction input vector is captured from `in0..in3` on the `LOAD_INPUT` cycle, so those inputs must remain stable through that sampling edge
- `busy` is a level signal defined by `state != IDLE && state != DONE`
- `done` is a level signal defined by `state == DONE`; it is not a pulse
- `out_bit` is externally valid exactly when `done = 1`
- `BIAS_OUTPUT` computes and registers the final output bit on the transition into `DONE`; externally, `done = 1` and valid `out_bit` are first observed together
- while the machine remains in `DONE`, `out_bit` must remain stable
- while `start = 1` is held in `DONE`, the machine must remain in `DONE`
- a new transaction requires `start` to be sampled low in `DONE` so the machine returns to `IDLE`; only a later sampled high in `IDLE` may begin the next transaction

The exact restart semantics above are part of the normative RTL contract and must be consumed consistently by simulation and formalization.

### Exact Cycle Contract

Cycle numbers below are counted from the rising edge that accepts `start` in `IDLE`.

- Cycle `1`: `LOAD_INPUT` and input-vector capture from `in0..in3`
- Cycles `2..65`: hidden-layer processing
- Cycles `66..74`: output-layer MAC processing
- Cycle `75`: `BIAS_OUTPUT`
- Cycle `76`: `DONE`

For the current controller, the latency from accepted `start` to observable `done = 1` is exactly `76` cycles.

The per-phase schedule is:

- each hidden neuron consumes exactly `8` cycles:
  - `4` MAC cycles with useful multiply-accumulate work
  - `1` guard transition cycle in `MAC_HIDDEN` with `input_idx = 4` and no MAC update
  - `1` cycle in `BIAS_HIDDEN`
  - `1` cycle in `ACT_HIDDEN`
  - `1` cycle in `NEXT_HIDDEN`
- the output stage consumes exactly `11` cycles:
  - `8` MAC cycles with useful multiply-accumulate work
  - `1` guard transition cycle in `MAC_OUTPUT` with `input_idx = 8` and no MAC update
  - `1` cycle in `BIAS_OUTPUT`
  - `1` cycle in `DONE`

### Boundary-Condition Verification Obligations

The RTL definition must make the following boundary conditions explicit and verifiable:

- the fourth hidden-layer MAC updates `input_idx` from `3` to `4`; the machine then spends one guard cycle in `MAC_HIDDEN` with no MAC update before entering `BIAS_HIDDEN`
- the eighth hidden neuron transitions from `NEXT_HIDDEN` to `MAC_OUTPUT` while resetting the reused counters exactly as implemented
- the eighth output-layer MAC updates `input_idx` from `7` to `8`; the machine then spends one guard cycle in `MAC_OUTPUT` with no MAC update before entering `BIAS_OUTPUT`
- `BIAS_OUTPUT` registers the final accumulator value and `out_bit`, and the next visible state is `DONE`
- `DONE` holds a stable output until the documented restart or return-to-idle condition
- no boundary transition may read an out-of-range input, hidden activation, or weight entry
- no boundary transition may duplicate a MAC operation, skip a required MAC operation, or reuse a stale accumulator value across phase changes

These obligations are part of the RTL contract, not just implementation details.

### Memory Organization

Weights and biases must be stored as ROM-like constants:

- `W1 : [8][4]`
- `b1 : [8]`
- `W2 : [8]`
- `b2 : scalar`

Allowed implementation styles:

- SystemVerilog or Verilog constant arrays
- Memory initialization files behind a ROM wrapper

## 6. Required RTL Files

```text
rtl/
  src/
    mlp_core.sv
    mac_unit.sv
    relu_unit.sv
    controller.sv
    weight_rom.sv
```

## 7. Acceptance Criteria

The `rtl` domain is complete when:

1. A reference implementation can evaluate any valid `int8[4]` input under the same arithmetic assumptions.
2. The RTL produces the same final classification as the fixed-point model used by simulation and formalization.
3. The RTL machine terminates for every started inference.
4. The architecture and state semantics are stable enough to be consumed by the `formalize` domain.
5. Boundary transitions at the final MAC and phase edges are explicitly verified by simulation and formalization.
6. The exact `76`-cycle latency, level-based `done`, level-based `busy`, and `out_bit` validity contract are explicitly verified against the current RTL behavior.
