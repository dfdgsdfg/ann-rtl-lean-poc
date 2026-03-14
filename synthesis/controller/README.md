# Controller Reactive-Synthesis Flow

This directory contains the committed source inputs for the `rtl-synthsis` controller experiment.

Stable source assets:

- `controller.tlsf`: TLSF contract for the controller phase machine
- `formal/formal_controller_spot_equivalence.sv`: raw-port equivalence harness against `rtl/src/controller.sv`
- `run_flow.py`: driver that runs `ltlsynt`, translates AIGER with Yosys, and checks formal equivalence

Generated outputs are written under `build/rtl-synthsis/spot/`.

The committed compatibility wrapper lives in:

- `experiments/generated-rtl/rtl-synthsis/spot/controller_spot_compat.sv`

That wrapper is paired with the build-generated `controller_spot_core.sv` and build-generated `controller.sv` alias for mixed-path simulation.

Required external tools:

- `ltlsynt`
- `syfco`
- `yosys`
- `yosys-smtbmc`
- `z3`

Typical entry points:

```bash
make rtl-synthsis
make rtl-synthsis-sim
```
