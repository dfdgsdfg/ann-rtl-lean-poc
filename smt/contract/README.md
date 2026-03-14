# Contract SMT Checks

This subtree holds the contract-tied SMT entrypoints for the frozen network in [`contract/result/weights.json`](../../contract/result/weights.json).

The scripts use the `z3` CLI directly and keep the arithmetic source of truth in the frozen contract:

- `python3 smt/contract/export_assumptions.py --output build/smt/contract_assumptions.json`
  - exports the frozen widths, quantization rules, and boundedness facts used by the other checks
- `python3 smt/contract/overflow/check_bounds.py --summary build/smt/contract_overflow_summary.json`
  - proves the hidden/output product bounds, hidden/output accumulator bounds, and sign-extension / wide-sum obligations
- `python3 smt/contract/equivalence/check_equivalence.py --summary build/smt/contract_equivalence_summary.json`
  - proves a layered arithmetic miter between the contract view and an RTL-style bitvector view

One intentional modeling detail is easy to miss in the code: the frozen contract treats hidden products as `int8 x int8 -> int16`, while the RTL-style view mirrors `mlp_core` by sign-extending the hidden input lane to 16 bits before multiply, yielding a 24-bit intermediate product. The overflow and equivalence summaries record that distinction explicitly and prove the two views agree after sign extension into the accumulator.

Optional debug artifact:

- add `--dump-smt <path>` to either proof script to save the generated SMT-LIB batch query

Generated summaries:

- `build/smt/contract_assumptions.json`
- `build/smt/contract_overflow_summary.json`
- `build/smt/contract_equivalence_summary.json`

The shared helper in [`common.py`](./common.py) validates the frozen contract rules before building the SMT encodings, so the scripts fail fast if the repository changes the overflow or clipping policy without updating the model.
