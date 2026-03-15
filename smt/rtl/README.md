# RTL Formal Checks

This subtree contains the RTL-backed formal runners for the SMT domain.

Current entrypoints:

- `check_control.py` for both the hand-written baseline RTL source set and the Sparkle full-core source set

The baseline `check_control.py` flow proves against the real RTL:

- [`rtl/src/controller.sv`](../../rtl/src/controller.sv)
- [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)

The Sparkle branch uses the same harness family at the shared `mlp_core` boundary, but swaps in these generated sources:

- [`experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core_wrapper.sv`](../../experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core_wrapper.sv)
- [`experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core.sv`](../../experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core.sv)

Implementation notes:

- Yosys elaborates the formal tops in `smt/rtl/controller/` and `smt/rtl/mlp_core/`
- `yosys-smtbmc` runs the bounded proofs with `z3` as the backend solver
- `mlp_core` exposes `FORMAL`-only debug outputs so the harnesses can observe real internal control signals without changing the non-formal build

It proves these property families:

- `controller_interface`
- `boundary_behavior`
- `range_safety`
- `transaction_capture`
- `bounded_latency`

The baseline branch runs all five families. The Sparkle branch runs the four `mlp_core` families against the generated wrapper-backed source set and leaves `controller_interface` on the hand-written controller RTL only.

`range_safety` proves the real selector and ROM lookup hits used by `mac_a`/`weight_rom`, so the boundary checks are not satisfied by silent default-zero fallthroughs.

`transaction_capture` proves that the accepted `start` reaches `LOAD_INPUT`, samples `in0..in3` into `input_regs`, and keeps those captured values stable for the rest of the bounded transaction.

The exact-latency proof uses these assumptions:

- initial visible state is `IDLE`
- `hidden_idx = 0` and `input_idx = 0` on the accept cycle
- `start` is high for the accept cycle only
- `start` is low for all later cycles, so `DONE` can release
- no reset occurs during the bounded trace
