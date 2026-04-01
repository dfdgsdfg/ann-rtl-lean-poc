# RTL-HLS4ML Design

## 1. Design Goal

The goal of this domain is to add an hls4ml-based RTL generation path as a fourth implementation branch for comparison against the hand-written baseline, the reactive-synthesis controller, and the Lean/Sparkle-generated full core.

The intended flow is:

```text
frozen contract
  -> hls4ml Keras model with frozen weights
  -> hls4ml HLS project (reference artifact)
  -> stable wrapper mlp_core.sv + supporting modules
  -> normalized branch-local sv/ export tree
  -> branch-local blueprint/mlp_core.svg
  -> existing simulation and branch-comparison flow
```

## 2. Domain Boundary

This domain is the simplest of the four implementation branches:

- **No formal proofs**: unlike `rtl-formalize-synthesis`, there are no Lean theorems
- **No reactive synthesis**: unlike `rtl-synthesis`, there is no temporal specification
- **Full-core generation**: like `rtl-formalize-synthesis`, the entire mlp_core is generated
- **Validation-backed only**: all correctness claims come from simulation regression

## 3. Architecture

### 3.1 Two-Layer Generation

1. **hls4ml layer** (`src/generate.py`)
   - Builds a Keras model matching the 4->8->1 MLP architecture
   - Loads frozen int8 weights from the contract
   - Configures hls4ml with matching fixed-point precision
   - Generates an HLS project as a reference artifact

2. **Wrapper layer** (`scripts/generate_wrapper.py`)
   - Generates the stable `mlp_core.sv` with the sequential-MAC FSM
   - Generates `weight_rom.sv` from the frozen contract weights
   - Reuses the baseline `mac_unit.sv` and `relu_unit.sv` patterns
   - Ensures cycle-exact compatibility with the shared testbench

### 3.2 Repository Shape

```text
rtl-hls4ml/
  src/
    generate.py              # hls4ml model construction and HLS generation
  scripts/
    generate_wrapper.py      # stable wrapper and supporting module generation
  runners/
    emit.py                  # CLI entrypoint for generation flow
    blueprint.py             # schematic generation
  results/
    canonical/
      sv/                    # normalized export tree
        mlp_core.sv
        weight_rom.sv
        mac_unit.sv
        relu_unit.sv
      blueprint/
        mlp_core.svg
        blueprint.svg
  test/
```

## 4. Integration

### 4.1 Simulation

The branch plugs into the shared simulation runner with:

```bash
python3 simulations/runners/run.py --branch rtl-hls4ml --profile shared --simulator all
```

### 4.2 Makefile

```bash
make rtl-hls4ml          # generate canonical artifacts
make rtl-hls4ml-sim      # run simulation regression
make rtl-hls4ml-blueprint # generate schematics
```

### 4.3 Experiments

The branch is included in `branch-compare` and `qor` experiment families through `prepare_hls4ml_branch()` in `experiments/src/run.py`.

## 5. Validation Strategy

Validation combines simulation, SMT formal checks, and comparison:

1. **Shared regression**: pass all test vectors via the shared testbench
2. **SMT formal checks**: pass the shared `mlp_core` formal property families (boundary behavior, range safety, transaction capture, bounded latency) via Yosys-SMTBMC + Z3
3. **Branch comparison**: compare against baseline at the `mlp_core` boundary
4. **QoR comparison**: area and timing comparison via Yosys synthesis

## 6. Main Risks

### 6.1 No Lean Proof Chain

Unlike the Sparkle branch, there is no Lean refinement theorem connecting hls4ml output to the repository's formal models. The branch inherits bounded SMT formal guarantees through the shared `mlp_core` property families, but these are weaker than the unbounded Lean proofs available for `rtl-formalize-synthesis`.

### 6.2 hls4ml Interface Mismatch

hls4ml's native output uses HLS-specific interfaces (ap_ctrl_hs, ap_fixed types) that do not match the repository's sequential-MAC microarchitecture. The wrapper layer bridges this gap by implementing the exact same FSM as the baseline.

## 7. Resolved Design Decisions

| Decision | Resolution | Rationale |
| --- | --- | --- |
| Role of hls4ml | Alternative generation path for comparison | Complements formal and reactive-synthesis approaches |
| Wrapper strategy | Full reimplementation of baseline FSM | Ensures cycle-exact compatibility with shared testbench |
| Trust model | SMT bounded formal + simulation | No Lean proofs; bounded SMT formal via shared mlp_core families |
| Weight source | Frozen contract pipeline | Prevents semantic drift |
