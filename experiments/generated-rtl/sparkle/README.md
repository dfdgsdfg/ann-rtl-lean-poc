# Sparkle Controller Track

This directory holds the generated-controller experiment for `rtl-formalize-synthsis`.

Files:

- `sparkle_controller.sv`: generated Sparkle RTL artifact
- `sparkle_controller_wrapper.sv`: stable wrapper matching `rtl/src/controller.sv`

Generation command:

```bash
make rtl-formalize-synthsis-emit
```

Validation commands:

```bash
make smt-generated-controller
make sim-generated-controller
```

Scope and trust boundary:

- scope: controller-only
- semantic baseline: `rtl/src/controller.sv`
- proof boundary: the hand-written Lean proofs in `formalize/` do not prove Sparkle codegen
- v1 validation: Sparkle elaboration plus RTL equivalence checks against the hand-written controller

Wrapper mapping:

- generated module: `TinyMLP_sparkleControllerPacked`
- generated ports: `_gen_start`, `_gen_hidden_idx`, `_gen_input_idx`, `clk`, `rst`, `out`
- packed output bus: `{state[3:0], load_input, clear_acc, do_mac_hidden, do_bias_hidden, do_act_hidden, advance_hidden, do_mac_output, do_bias_output, done, busy}`
