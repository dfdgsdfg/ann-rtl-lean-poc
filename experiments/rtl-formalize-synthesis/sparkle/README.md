# Sparkle Full-Core Track

This directory holds the branch-local full-core generated RTL artifacts for `rtl-formalize-synthesis`.

Files:

- `sparkle_mlp_core.sv`: raw Sparkle-emitted full-core RTL
- `sparkle_mlp_core_wrapper.sv`: stable `mlp_core` boundary used by the shared simulation bench and experiment flows

Generation command:

```bash
make rtl-formalize-synthesis-emit
```

Validation commands:

```bash
make rtl-formalize-synthesis-sim
python3 experiments/run.py --family branch-compare
python3 experiments/run.py --family qor
```

Scope and trust boundary:

- `generation_scope`: full-core
- `integration_scope`: full-core `mlp_core`
- `validation_scope`: full-core `mlp_core`
- `validation_method`: shared full-core simulation plus downstream QoR/post-synth comparison families
- semantic baseline: `rtl/src/mlp_core.sv`
- stable downstream module boundary: `sparkle_mlp_core_wrapper.sv`
- proof boundary: the current Lean refinement in `rtl-formalize-synthesis/` still covers controller semantics only; there is not yet a full-core theorem for the emitted Sparkle design
- backend trust boundary: Sparkle-to-Verilog remains trusted code generation
- RTL validation: shared `mlp_core` vector regression, branch-comparison summaries, QoR characterization, and downstream synthesis flows

Wrapper mapping:

- generated Lean namespace: `TinyMLP.Sparkle`
- raw generated module: `TinyMLP_sparkleMlpCorePacked`
- stable downstream module boundary: `mlp_core`
- current protection level: if Sparkle changes raw packing order, the shared full-core regression and branch-comparison flows should fail, but there is no separate structural proof of the wrapper bit slices
