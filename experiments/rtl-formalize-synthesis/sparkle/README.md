# Sparkle Controller Track

This directory holds the branch-local generated-controller experiment for `rtl-formalize-synthesis`, including the controller-only refinement bridge into the Sparkle Signal DSL model.

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
- Lean refinement boundary: the controller milestone includes a theorem connecting the relevant pure controller semantics in `formalize/` to the `TinyMLP.Sparkle` Signal DSL controller model
- backend trust boundary: Sparkle-to-Verilog remains trusted code generation and is not proved by the Lean refinement theorem
- accepted limitation: the wrapper's unpacking of the raw generated `out` bus is a documented manual bit-layout contract, not a separate Lean theorem
- RTL validation: Sparkle elaboration, `82`-cycle bounded formal wrapper-equivalence checks for `4/8`, `3/5`, and `1/1`, an `82`-cycle invalid-state recovery/parity proof, and directed simulation traces for `4/8` and `3/5`

Wrapper mapping:

- generated Lean namespace: `TinyMLP.Sparkle`
- raw generated module: `TinyMLP_sparkleControllerPacked` via the compatibility emit alias in `TinyMLP.sparkleControllerPacked`
- stable downstream module boundary: `sparkle_controller_wrapper`
- wrapper parameters: `INPUT_NEURONS`, `HIDDEN_NEURONS`
- generated ports: `_gen_start`, `_gen_hidden_idx`, `_gen_input_idx`, `_gen_inputNeurons4b`, `_gen_hiddenNeurons4b`, `_gen_lastHiddenIdx`, `clk`, `rst`, `out`
- packed output bus: `{state[3:0], load_input, clear_acc, do_mac_hidden, do_bias_hidden, do_act_hidden, advance_hidden, do_mac_output, do_bias_output, done, busy}`
- current protection level: if Sparkle changes raw packing order, the wrapper-boundary SMT equivalence and simulation regressions should fail, but there is no dedicated structural proof of the bit slices themselves
