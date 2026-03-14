# RTL Formal Checks

`check_control.py` is the RTL-backed formal runner for the SMT domain.

It proves against the real RTL:

- [`rtl/src/controller.sv`](../../rtl/src/controller.sv)
- [`rtl/src/mlp_core.sv`](../../rtl/src/mlp_core.sv)

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

`range_safety` proves the real selector and ROM lookup hits used by `mac_a`/`weight_rom`, so the boundary checks are not satisfied by silent default-zero fallthroughs.

`transaction_capture` proves that the accepted `start` reaches `LOAD_INPUT`, samples `in0..in3` into `input_regs`, and keeps those captured values stable for the rest of the bounded transaction.

The exact-latency proof uses these assumptions:

- initial visible state is `IDLE`
- `hidden_idx = 0` and `input_idx = 0` on the accept cycle
- `start` is high for the accept cycle only
- `start` is low for all later cycles, so `DONE` can release
- no reset occurs during the bounded trace
