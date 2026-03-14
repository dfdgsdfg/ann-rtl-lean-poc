# Sparkle Controller Track

This directory holds the branch-local generated-controller experiment for `rtl-formalize-synthesis`.

Files:

- `sparkle_controller.sv`: generated Sparkle RTL artifact
- `sparkle_controller_wrapper.sv`: stable wrapper preserving the `rtl/src/controller.sv` parameter and port boundary

Generation command:

```bash
make rtl-formalize-synthesis-emit
```

Validation commands:

```bash
make smt-generated-controller
make sim-generated-controller
make smt
```

Scope and trust boundary:

- scope: controller-only
- semantic baseline: `rtl/src/controller.sv`
- stable comparison boundary: `sparkle_controller_wrapper`, not the raw emitted Sparkle module
- proof boundary: the hand-written Lean proofs in `formalize/` do not prove Sparkle codegen
- v1 validation: Sparkle elaboration, bounded formal wrapper-equivalence checks for `4/8`, `3/5`, and `1/1`, an invalid-state recovery proof, and directed simulation traces for `4/8` and `3/5`

Wrapper mapping:

- generated module: `TinyMLP_sparkleControllerPacked`
- wrapper parameters: `INPUT_NEURONS`, `HIDDEN_NEURONS`
- generated ports: `_gen_start`, `_gen_hidden_idx`, `_gen_input_idx`, `_gen_inputNeurons4b`, `_gen_hiddenNeurons4b`, `_gen_lastHiddenIdx`, `clk`, `rst`, `out`
- packed output bus: `{state[3:0], load_input, clear_acc, do_mac_hidden, do_bias_hidden, do_act_hidden, advance_hidden, do_mac_output, do_bias_output, done, busy}`
