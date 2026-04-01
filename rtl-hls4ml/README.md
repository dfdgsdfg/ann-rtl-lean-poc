# rtl-hls4ml

Fourth implementation branch: hls4ml-generated full-core RTL for the 4->8->1 MLP.

## Overview

This branch uses [hls4ml](https://github.com/fastmachinelearning/hls4ml) as an alternative RTL generation path. The frozen contract weights are loaded into an hls4ml model, and the generated output is wrapped to match the repository's standard `mlp_core` interface.

Unlike `rtl-formalize-synthesis`, this branch has **no Lean proof story**. Correctness is backed by simulation regression and the shared SMT formal property suite (boundary behavior, range safety, transaction capture, bounded latency).

## Quick Start

```bash
# Generate canonical SV files from frozen contract
make rtl-hls4ml

# Run simulation regression
make rtl-hls4ml-sim

# Run SMT formal checks
make smt-rtl-hls4ml

# Generate schematics
make rtl-hls4ml-blueprint

# Full canonical flow (generate + blueprint)
make rtl-hls4ml-canonical

# Validate canonical files match frozen contract
make rtl-hls4ml-check
```

## Structure

```
rtl-hls4ml/
  src/generate.py                  # hls4ml model construction
  scripts/generate_wrapper.py      # wrapper + supporting module generation
  runners/
    emit.py                        # CLI: --emit or --check
    blueprint.py                   # schematic generation
  results/canonical/
    sv/                            # normalized export tree
      mlp_core.sv                  # stable top-level module
      weight_rom.sv                # frozen contract weights
      mac_unit.sv                  # multiply-accumulate unit
      relu_unit.sv                 # ReLU activation unit
    blueprint/                     # SVG schematics
```

## Branch Comparison

| Aspect | rtl | rtl-synthesis | rtl-formalize-synthesis | rtl-hls4ml |
| --- | --- | --- | --- | --- |
| Style | Handwritten | Ltlsynt controller | Sparkle full-core | hls4ml full-core |
| Scope | Full core | Controller only | Full core | Full core |
| Trust | Canonical | Equivalence proofs | Lean proofs | SMT + simulation |
