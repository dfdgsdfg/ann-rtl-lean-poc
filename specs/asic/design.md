# ASIC Design

## 1. Design Goals

The ASIC flow should prioritize:

- Reproducibility
- Simplicity
- Compatibility with open-source tooling
- Enough reporting to compare implementation choices

## 2. Synthesis Plan

The initial flow should use a straightforward `Yosys` script that:

- Reads all RTL files
- Sets the top module
- Performs synthesis for the selected library
- Writes a gate-level netlist
- Emits area and timing related reports

This should be the first ASIC milestone, before spending effort on physical design.

## 3. Physical Design Plan

After synthesis is stable, the design can be pushed into `OpenLane` or `OpenROAD` for:

- Floorplanning
- Placement
- Clock-tree construction if required
- Routing
- Final design reports

Because this is a toy research ASIC, physical design should be treated as a reproducibility milestone rather than an optimization contest.

## 4. Configuration Strategy

The ASIC scripts should avoid hidden manual steps. The flow should be launchable from version-controlled configuration files and documented commands.

Useful configuration outputs include:

- Synthesis script
- Library and PDK selection
- Floorplan parameters
- Report locations

## 5. Artifact Strategy

Generated ASIC artifacts should be easy to inspect and compare across runs:

- Netlist output
- Area report
- Timing report
- Power estimate
- Optional layout artifacts

Where practical, the repository should preserve report summaries and regenerate large artifacts on demand.
