# Controller Reactive-Synthesis Flow

This directory contains the committed source inputs for the `rtl-synthesis` controller experiment.

Stable source assets:

- `controller.tlsf`: TLSF contract for the controller phase machine
- `formal/formal_controller_spot_equivalence.sv`: raw-port equivalence harness against `rtl/src/controller.sv`
- `run_flow.py`: driver that runs `ltlsynt`, translates AIGER with Yosys, and checks formal equivalence

The committed TLSF uses the `exact_schedule_v1` assumption profile:

- phase-conditioned hidden/output MAC predicate consistency
- explicit hidden MAC position bits for the concrete `0 -> 1 -> 2 -> 3 -> 4` schedule
- explicit hidden-neuron ordinal bits for the concrete `0 -> 1 -> ... -> 7` schedule
- explicit output MAC position bits for the concrete `0 -> 1 -> ... -> 7 -> 8` schedule
- restart assumptions for `LOAD_INPUT`, hidden-neuron rollover, output entry, and `DONE` hold/release behavior

Generated outputs are written under `build/rtl-synthesis/spot/`.

The committed compatibility wrapper lives in:

- `experiments/generated-rtl/rtl-synthesis/spot/controller_spot_compat.sv`

That wrapper is paired with the build-generated `controller_spot_core.sv` and build-generated `controller.sv` alias for mixed-path simulation.

Required external tools:

- `ltlsynt`
- `syfco`
- `yosys`
- `yosys-smtbmc`
- `z3`

Typical entry points:

```bash
make rtl-synthesis
make rtl-synthesis-sim
```
