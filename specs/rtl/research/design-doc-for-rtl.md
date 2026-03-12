# RTL Spec and Design Docs by Domain

Date: 2026-03-12

## Scope

This note groups the most useful RTL language, design, and tool-reference documents by workflow domain.

The point is not to list every document. The point is to identify which docs should be treated as authoritative or practical for each part of the RTL workflow.

## 1. Language Specification

### IEEE `1800-2023`

Use for:

- actual SystemVerilog language truth
- edge-case syntax and semantics
- resolving disagreements between tools

Status:

- authoritative
- available through the IEEE GET / Accellera path
- should override blog posts, tutorials, and tool folklore

## 2. Practical Language Reference

### `systemverilog.dev`

Use for:

- readable practical explanations
- quick examples
- onboarding when the IEEE standard is too heavy

Status:

- practical reference
- not a replacement for the standard

## 3. Coding Style and Design Conventions

### lowRISC SystemVerilog Style Guide

Use for:

- naming rules
- structural conventions
- synthesizable coding discipline
- review consistency

Status:

- one of the best-known open style guides for SystemVerilog RTL

## 4. Simulation Documentation

### Verilator docs

Use for:

- simulator behavior
- command-line usage
- lint and simulation configuration

### Icarus Verilog docs

Use for:

- compatibility smoke-test behavior
- small simulation command references

## 5. Parser and Frontend Documentation

### Slang docs

Use for:

- frontend capabilities
- parsing and elaboration behavior
- supported SystemVerilog language expectations

### Surelog docs

Use for:

- parser flow
- UHDM-related frontend behavior

## 6. Synthesis Documentation

### Yosys docs

Use for:

- synthesis commands
- supported flows
- open-source synthesis behavior and limitations

### yosys-slang docs

Use for:

- integrating a richer SystemVerilog frontend into synthesis

## 7. Formal and Verification Documentation

### SymbiYosys docs

Use for:

- bounded model checking
- assertion-driven checks
- open-source formal flow setup

### `sv-tests`

Use for:

- checking current feature support across tools
- deciding whether a construct is safe to adopt

This is not a design guide, but it is a critical verification reference for tool support.

## Recommended Doc Priority for This Repository

When writing or reviewing RTL in this repository, use this priority:

1. IEEE `1800-2023`
2. lowRISC style guide
3. tool docs for the exact tool being used
4. `systemverilog.dev` for readability and onboarding
5. `sv-tests` when feature-support confidence matters

## Bottom Line

The real spec is still the language standard.

The most useful open documents around it are:

- IEEE `1800-2023`
- lowRISC style guide
- `systemverilog.dev`
- official docs for Verilator, Slang, Verible, Yosys, and SymbiYosys

These are the documents this repository should treat as the default reference set.

## Sources

- IEEE 1800-2023 via Accellera / IEEE GET: https://accellera.org/downloads/ieee
- systemverilog.dev: https://systemverilog.dev/
- lowRISC style guide: https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md
- Verilator guide: https://verilator.org/guide/latest/
- Icarus Verilog docs: https://steveicarus.github.io/iverilog/
- Slang docs: https://sv-lang.com/
- Surelog: https://github.com/chipsalliance/Surelog
- Verible docs: https://verible.readthedocs.io/
- Yosys docs: https://yosyshq.readthedocs.io/projects/yosys/en/stable/
- yosys-slang: https://github.com/povik/yosys-slang
- SymbiYosys docs: https://yosyshq.readthedocs.io/projects/sby/en/latest/
- sv-tests results: https://chipsalliance.github.io/sv-tests-results/
