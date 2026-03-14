# SMT Domain

This directory implements the current SMT scope described in [`specs/smt/requirement.md`](../specs/smt/requirement.md) and [`specs/smt/design.md`](../specs/smt/design.md).

Current scope:

- RTL-backed control proofs for [`rtl/src/controller.sv`](../rtl/src/controller.sv) and [`rtl/src/mlp_core.sv`](../rtl/src/mlp_core.sv)
- solver-backed overflow and width checks over the frozen contract in [`contract/result/weights.json`](../contract/result/weights.json)
- solver-backed arithmetic equivalence checks between the frozen contract view and an RTL-style bitvector view
- explicit export of the frozen arithmetic assumptions used by the contract-side proofs

The RTL proof set now includes:

- real no-out-of-range selector/ROM-hit checks at the hidden and output boundaries
- accepted-start transaction capture checks for `LOAD_INPUT` and `input_regs`

Current non-goals:

- replacing the Lean proof layer
- replacing simulation as the practical regression flow
- full cycle-by-cycle arithmetic equivalence for the sequential `mlp_core`
- SMT-assisted theorem proving inside Lean

The implementation uses Yosys + `yosys-smtbmc` with `z3` for RTL properties, and direct `z3` QF_BV batches for the contract-side arithmetic checks.

## Commands

Run the complete SMT flow:

```bash
make smt
```

Run only the RTL control checks:

```bash
python3 smt/rtl/check_control.py --summary build/smt/rtl_control_summary.json
```

Export the frozen arithmetic assumptions:

```bash
python3 smt/contract/export_assumptions.py --output build/smt/contract_assumptions.json
```

Run only the contract overflow checks:

```bash
python3 smt/contract/overflow/check_bounds.py --summary build/smt/contract_overflow_summary.json
```

Run only the contract equivalence checks:

```bash
python3 smt/contract/equivalence/check_equivalence.py --summary build/smt/contract_equivalence_summary.json
```

Generated artifacts:

- `build/smt/rtl_control_summary.json`
- `build/smt/contract_assumptions.json`
- `build/smt/contract_overflow_summary.json`
- `build/smt/contract_equivalence_summary.json`

These summaries record the solver/tool version, the assumptions used for each property family, and a concise pass/fail result suitable for CI or local review.
