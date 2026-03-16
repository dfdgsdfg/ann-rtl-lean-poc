# MLP core ASIC Canonical Specification

## Topology

- input neurons: 4
- hidden neurons: 8
- output neurons: 1
- activation: ReLU
- decision rule: `out = (score > 0)`

## Arithmetic

- inputs: signed `int8`
- first-layer weights: signed `int8`
- hidden activations: signed `int16`
- hidden products: `int8 * int8 -> int16`, then sign-extended into the `int32` accumulator
- output-layer weights: signed `int8`
- output products: `int16 * int8 -> int24`, then sign-extended into the `int32` accumulator
- accumulators and biases: signed `int32`
- overflow policy: signed two's complement wraparound
- quantization rounding: round half away from zero
- quantization clipping: signed saturation to the destination width

## Verified Boundedness

<!-- BEGIN AUTO-GENERATED BOUNDEDNESS -->
- checked scope: all signed `int8` inputs `[-128, 127]`
- hidden products: safe bound `[-256, 254]` within signed `int16`
- hidden pre-activations: safe bound `[-638, 637]` within signed `int32`
- hidden activations after ReLU: safe bound `[0, 637]` within signed `int16`
- output products: safe bound `[-512, 637]` within signed `int24`
- output accumulator: safe bound `[-1021, 1020]` within signed `int32`

These verified bounds justify treating the current frozen fixed-point model as range-safe for the generated RTL and Lean artifacts.
<!-- END AUTO-GENERATED BOUNDEDNESS -->

## Canonical Weights

<!-- BEGIN AUTO-GENERATED WEIGHTS -->
`W1` (`8 x 4`)

| hidden | x0 | x1 | x2 | x3 |
| --- | ---: | ---: | ---: | ---: |
| h0 |  0 |  0 |  0 |  0 |
| h1 |  0 |  0 |  0 | -1 |
| h2 |  2 |  1 |  1 | -1 |
| h3 |  0 |  0 |  0 | -1 |
| h4 | -1 |  0 |  0 |  0 |
| h5 | -1 |  1 | -1 |  1 |
| h6 |  0 | -1 |  1 | -1 |
| h7 |  1 |  2 |  0 |  0 |

`b1`

```text
[0, 0, 1, 1, 0, 2, 1, -1]
```

`W2`

```text
[0, 0, 1, 0, -1, -1, 1, -1]
```

`b2`

```text
-1
```
<!-- END AUTO-GENERATED WEIGHTS -->

## Sequential-MAC Microarchitecture

The RTL computes one hidden neuron at a time:

```text
IDLE
  -> LOAD_INPUT
  -> MAC_HIDDEN   (4 MAC operations, 5 clock cycles per hidden neuron)
  -> BIAS_HIDDEN
  -> ACT_HIDDEN
  -> NEXT_HIDDEN
  -> MAC_OUTPUT   (8 MAC operations, 9 clock cycles)
  -> BIAS_OUTPUT
  -> DONE
```

Each MAC phase includes one transition cycle after the last MAC operation where the index has reached its terminal value and the FSM advances to the next state without performing a MAC.

Cycle budget for one inference:

- `1` cycle: `IDLE -> LOAD_INPUT`
- `1` cycle: `LOAD_INPUT -> MAC_HIDDEN`
- `8 * (5 + 1 + 1 + 1) = 64` cycles: all hidden neurons (5 MAC_HIDDEN + 1 BIAS + 1 ACT + 1 NEXT per neuron)
- `9 + 1 = 10` cycles: output accumulation (9 MAC_OUTPUT + 1 BIAS_OUTPUT)

Total: `76` cycles from the abstract Lean machine's `initialState` to `DONE`.
