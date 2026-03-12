# ASIC Requirements

## 1. Purpose

This document defines the ASIC implementation requirements for the Tiny Neural Inference ASIC.

The `asic` domain covers:

- Logic synthesis
- Physical design when feasible
- Report generation
- Reproducible open-source flow configuration

## 2. Toolchain Requirements

The preferred open-source ASIC flow is:

- `Yosys`
- `OpenROAD`
- `OpenLane`
- `Sky130 PDK`

Equivalent open-source tooling is acceptable if the generated outputs are comparable and reproducible.

## 3. Synthesis Requirements

The ASIC flow must generate:

- Gate-level netlist
- Area report
- Timing report
- Power estimate

The synthesis entry point must consume the project RTL with `mlp_core` or the chosen top module as the synthesis top.

## 4. Physical Design Requirements

When feasible, the flow should additionally perform:

- Floorplanning
- Placement
- Routing
- Final `GDS` generation

Physical design is optional for project completion, but the synthesis flow is required.

## 5. Required Files

Suggested ASIC files:

```text
asic/
  yosys.tcl
  openlane/
    floorplan.tcl
```

Equivalent file names are acceptable if the same responsibilities are covered.

## 6. Acceptance Criteria

The `asic` domain is complete when:

1. RTL synthesis completes successfully.
2. A gate-level netlist is generated.
3. Area and timing reports are produced.
4. The flow is reproducible from committed scripts or documented commands.

The domain exceeds baseline completion if physical-design outputs are also generated.
