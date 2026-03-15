# SMT Domain

This directory implements the current SMT scope described in [`specs/smt/requirement.md`](../specs/smt/requirement.md) and [`specs/smt/design.md`](../specs/smt/design.md).

Current scope:

- RTL-backed control proofs for the baseline hand-written RTL and the Sparkle full-core branch at the `mlp_core` boundary
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

The implementation uses Yosys + `yosys-smtbmc` with `z3` for RTL properties, direct `z3` QF_BV batches for the contract-side arithmetic checks, and a pure JSON export step for the frozen contract assumptions.

## Commands

Run the complete SMT flow:

```bash
make smt
```

In practice it expects `python3`, `yosys`, `yosys-smtbmc`, and `z3`.

Run only the RTL control checks:

```bash
python3 smt/rtl/check_control.py --summary build/smt/rtl_control_summary.json
```

Run only the Sparkle full-core RTL checks:

```bash
python3 smt/rtl/check_control.py --branch rtl-formalize-synthesis --summary build/smt/rtl_formalize_synthesis_summary.json
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
- `build/smt/rtl_formalize_synthesis_summary.json`
- `build/smt/contract_assumptions.json`
- `build/smt/contract_overflow_summary.json`
- `build/smt/contract_equivalence_summary.json`

These summaries record the solver/tool version, the assumptions used for each property family, and a concise pass/fail result suitable for CI or local review.

The Sparkle full-core branch is checked through the same `smt/rtl/check_control.py` runner with a branch-specific source set consisting of the generated wrapper plus raw Sparkle-emitted core. The Lean theorem still stops at Signal DSL semantics; emitted RTL remains validated by SMT, simulation, and synthesis flows rather than proved in Lean alone.
