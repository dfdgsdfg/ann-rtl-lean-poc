# Controller Reactive-Synthesis Flow

This directory contains the committed source inputs for the `rtl-synthesis` controller experiment.

Stable source assets:

- `controller.tlsf`: TLSF contract for the controller phase machine
- `formal/formal_controller_spot_equivalence.sv`: bounded exact-schedule sampled-interface equivalence harness against `rtl/src/controller.sv`
- `run_flow.py`: driver that runs `ltlsynt`, translates AIGER with Yosys, and checks bounded formal equivalence

The committed TLSF uses the `exact_schedule_v1` assumption profile:

- phase-conditioned hidden/output MAC predicate consistency
- explicit hidden MAC position bits for the concrete `0 -> 1 -> 2 -> 3 -> 4` schedule
- explicit hidden-neuron ordinal bits for the concrete `0 -> 1 -> ... -> 7` schedule
- explicit output MAC position bits for the concrete `0 -> 1 -> ... -> 7 -> 8` schedule
- restart assumptions for `LOAD_INPUT`, hidden-neuron rollover, output entry, and `DONE` hold/release behavior

The current formal result recorded by `run_flow.py` is a bounded `80`-cycle sampled controller-interface equivalence check through `MAC_OUTPUT`, `BIAS_OUTPUT`, `DONE`, and `DONE` hold/release under those `exact_schedule_v1` assumptions.

Generated outputs are written under `build/rtl-synthesis/spot/`.

The committed compatibility wrapper lives in:

- `experiments/rtl-synthesis/spot/controller_spot_compat.sv`

That wrapper is paired with the build-generated `controller_spot_core.sv` and build-generated `controller.sv` alias for mixed-path simulation, and it only claims parity at the sampled controller boundary used by the mixed-path bench.

The formal harness models reset at sampled clock boundaries. Sub-cycle async reset parity is covered by the mixed-path simulation regressions, not by the sampled formal claim.

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
