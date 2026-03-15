# Spot Controller Wrapper

This directory contains the committed RTL-side wrapper for the `rtl-synthesis` controller-generated, mixed-path-integrated experiment.

- `controller_spot_compat.sv` keeps the sampled `controller.sv` port interface used by the mixed-path simulation boundary.
- The actual synthesized phase machine is generated into `build/rtl-synthesis/spot/generated/controller_spot_core.sv`.
- `build/rtl-synthesis/spot/generated/controller.sv` is a build-only alias used for mixed-path simulation with `mlp_core.sv`.
- `rtl-synthesis-sim` reuses `simulations/rtl/testbench.sv`; there is no branch-local `simulations/rtl-synthesis/*.sv` bench.
- `branch-compare` consumes `build/rtl-synthesis/spot/rtl_synthesis_summary.json` and reports the fresh-flow `closed_loop_mlp_core_equivalence` and `controller_interface_equivalence` steps before the shared simulation steps.
- If the fresh-flow toolchain is unavailable, experiment families record `rtl-synthesis` as `skip`; they do not fall back to a committed snapshot.

Entry points:

```bash
make rtl-synthesis-smoke
make rtl-synthesis
make rtl-synthesis-sim
make rtl-synthesis-iverilog
make rtl-synthesis-verilator
```

Boundary convention:

- `artifact_kind`: `generated_controller_rtl`
- `assembly_boundary`: `mixed_path_mlp_core`
- `evidence_boundary`: `shared_full_core_top_level_bench`
- `evidence_method`: `closed_loop_formal_plus_controller_formal_plus_dual_simulator_regression`
- secondary simulation evidence: `internal_observability_bench` replay for branches that still preserve the baseline internal surface
