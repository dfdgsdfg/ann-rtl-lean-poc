# Experiments

This domain is reserved for optional evaluation work:

- directed sweeps
- timing and area comparisons
- semantic-closure checks between Lean, contract, and RTL
- contract-to-ROM and downstream artifact-consistency checks
- proof and RTL regression summaries
- cross-branch implementation-comparison studies
- reactive-synthesis controller studies

Current guardrail: `rtl/` is still the canonical implementation. Any generated RTL belongs here as an experiment artifact until it proves functional, temporal, and synthesis-level equivalence or improvement.

Entry points:

```bash
make experiments
make experiments-artifact-consistency
make experiments-semantic-closure
make experiments-branch-compare
make experiments-qor
make experiments-post-synth
```

Each command writes JSON summaries and Markdown reports under `build/experiments/`.

Branch-oriented reports should record:

- `generation_scope`: what the branch actually produces
- `integration_scope`: where that generated or hand-written artifact plugs into the larger design
- `validation_scope`: the system boundary where evidence is collected
- `validation_method`: how that evidence was obtained

See:

- `implementation-branch-comparison.md`
- `rtl-formalize-synthesis/sparkle/README.md`
- `rtl-synthesis/spot/README.md`
