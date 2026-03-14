# Spot Controller Wrapper

This directory contains the committed RTL-side wrapper for the `rtl-synthsis` experiment.

- `controller_spot_compat.sv` keeps the raw `controller.sv` port interface.
- The actual synthesized phase machine is generated into `build/rtl-synthsis/spot/generated/controller_spot_core.sv`.
- `build/rtl-synthsis/spot/generated/controller.sv` is a build-only alias used for mixed-path simulation with `mlp_core.sv`.

Entry points:

```bash
make rtl-synthsis
make rtl-synthsis-sim
```
