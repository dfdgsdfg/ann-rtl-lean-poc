# Spot Controller Wrapper

This directory contains the committed RTL-side wrapper for the `rtl-synthesis` controller-generated, mixed-path-integrated experiment.

- `controller_spot_compat.sv` keeps the sampled `controller.sv` port interface used by the mixed-path simulation boundary.
- The actual synthesized phase machine is generated into `build/rtl-synthesis/spot/generated/controller_spot_core.sv`.
- `build/rtl-synthesis/spot/generated/controller.sv` is a build-only alias used for mixed-path simulation with `mlp_core.sv`.
- `rtl-synthesis-sim` reuses `simulations/rtl/testbench.sv`; there is no branch-local `simulations/rtl-synthesis/*.sv` bench.

Entry points:

```bash
make rtl-synthesis-smoke
make rtl-synthesis
make rtl-synthesis-sim
```

Scope convention:

- `generation_scope`: controller
- `integration_scope`: mixed-path `mlp_core`
- `validation_scope`: mixed-path `mlp_core` for the primary claim
- `validation_method`: bounded controller-formal parity plus shared full-core simulation
