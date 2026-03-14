# Controller Reactive-Synthesis Flow

This directory contains the committed source inputs for the `rtl-synthesis` controller experiment.

Stable source assets:

- `controller.tlsf`: TLSF contract for the controller phase machine
- `formal/formal_controller_spot_equivalence.sv`: bounded exact-schedule sampled-interface equivalence harness against `rtl/src/controller.sv`
- `formal/formal_closed_loop_mlp_core_equivalence.sv`: bounded mixed-path full-core equivalence harness against `rtl/src/mlp_core.sv`
- `run_flow.py`: driver that runs `ltlsynt`, translates AIGER with Yosys, and checks both secondary controller-only parity and primary closed-loop parity

The committed TLSF uses the `exact_schedule_v1` assumption profile:

- phase-conditioned hidden/output MAC predicate consistency
- explicit hidden MAC position bits for the concrete `0 -> 1 -> 2 -> 3 -> 4` schedule
- explicit hidden-neuron ordinal bits for the concrete `0 -> 1 -> ... -> 7` schedule
- explicit output MAC position bits for the concrete `0 -> 1 -> ... -> 7 -> 8` schedule
- restart assumptions for `LOAD_INPUT`, hidden-neuron rollover, output entry, and `DONE` hold/release behavior

The current flow records two formal claims:

- primary: bounded `82`-cycle closed-loop `mlp_core` mixed-path equivalence over a post-reset accepted transaction window, with the hand-written datapath driving both baseline and synthesized-controller assemblies
- secondary: bounded `80`-cycle sampled controller-interface equivalence through `MAC_OUTPUT`, `BIAS_OUTPUT`, `DONE`, and `DONE` hold/release under `exact_schedule_v1`

Generated outputs are written under `build/rtl-synthesis/spot/`.

The committed compatibility wrapper lives in:

- `experiments/rtl-synthesis/spot/controller_spot_compat.sv`

That wrapper is paired with the build-generated `controller_spot_core.sv` and build-generated `controller.sv` alias for mixed-path simulation. The mixed-path simulation path reuses `simulations/rtl/testbench.sv`; there is no branch-local `rtl-synthesis` bench file.

The sampled controller-interface harness models reset at sampled clock boundaries. Sub-cycle async reset parity remains covered by the wrapper-focused tests and the mixed-path simulation regressions, not by the secondary controller-only claim.

Required external tools for `make rtl-synthesis`:

- `ltlsynt`
- `syfco`
- `yosys`
- `yosys-smtbmc`
- `z3`

Additional tools for `make rtl-synthesis-sim`:

- `iverilog`
- `vvp`
- `verilator`

Typical entry points:

```bash
make rtl-synthesis-smoke
make rtl-synthesis
make rtl-synthesis-sim
```
