# Sparkle Full-Core Track

This directory holds the branch-local full-core generated RTL artifacts for `rtl-formalize-synthesis`.

Files:

- `sparkle_mlp_core.sv`: raw Sparkle-emitted full-core RTL
- `sparkle_mlp_core_wrapper.sv`: stable generated `mlp_core` boundary used by the shared simulation bench, SMT flow, and experiment families

Generation command:

```bash
make rtl-formalize-synthesis-emit
```

Validation commands:

```bash
make rtl-formalize-synthesis-sim
make rtl-formalize-synthesis-iverilog
make rtl-formalize-synthesis-verilator
make smt-rtl-formalize-synthesis
python3 experiments/run.py --family branch-compare
python3 experiments/run.py --family qor
```

Boundary and trust profile:

- `artifact_kind`: `generated_full_core_rtl`
- `assembly_boundary`: `full_core_mlp_core`
- `evidence_boundary`: `shared_full_core_top_level_bench`
- `evidence_method`: `dual_simulator_regression` in the direct simulation path, with downstream QoR and post-synth families layered on separately
- `simulation_profile`: shared `simulations/rtl/testbench.sv`, shared vector artifacts, and required dual-simulator replay under Icarus and Verilator
- internal observability: not required for this branch; the internal bench remains a baseline-oriented secondary check only
- semantic baseline: `rtl/src/mlp_core.sv`
- stable downstream module boundary: `sparkle_mlp_core_wrapper.sv`
- proof boundary: `Refinement.lean` proves the full-core bridge from the pure Lean machine/temporal semantics to the actual Sparkle Signal DSL full-core state/view (`sparkleMlpCoreState_refines_rtlTrace`, `sparkleMlpCoreView_refines_rtlTrace`); the Lean theorem stops at Signal DSL semantics
- backend trust boundary: Sparkle-to-Verilog remains trusted code generation
- RTL validation: shared `mlp_core` vector regression, branch-comparison summaries, branch-aware SMT checks, QoR characterization, and downstream synthesis flows

Wrapper mapping:

- generated Lean namespace: `TinyMLP.Sparkle`
- raw generated module: `TinyMLP_sparkleMlpCorePacked`
- stable downstream module boundary: `mlp_core`
- wrapper generation path: `make rtl-formalize-synthesis-emit` regenerates both the raw module and this stable wrapper from committed sources
- artifact freshness policy: generated-core freshness is checked against emit inputs, while proof-only Lean drift is reported separately in artifact-consistency without gating branch freshness
- current protection level: if Sparkle changes raw packing order, the generated wrapper, shared full-core regression, and branch-aware SMT flow should fail, but there is no separate structural proof of the wrapper bit slices
