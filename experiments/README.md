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

Each command writes runtime artifacts under `build/experiments/{runs,canonical}/` and JSON summaries plus Markdown reports under `reports/experiments/{runs,canonical}/`.

Branch-oriented reports should record:

- `artifact_kind`: what kind of implementation artifact the branch contributes
- `assembly_boundary`: where that artifact plugs into the larger design
- `evidence_boundary`: where evidence is collected for the recorded claim
- `evidence_method`: how that evidence was obtained
- `simulation_profile`: when simulation is involved, which bench, vectors, and simulators define the support boundary

See:

- `implementation-branch-comparison.md`
- `rtl-formalize-synthesis/sparkle/README.md`
- `rtl-synthesis/spot/README.md`
