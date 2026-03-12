# Open-Source RTL Tools by Domain

Date: 2026-03-12

## Scope

This note groups current open-source RTL tools by workflow domain for this repository.

The target workflow is a small SystemVerilog RTL project with:

- simple synthesizable RTL
- simulation and linting
- open-source synthesis
- optional formal checks alongside Lean proofs

## 1. Authoring, Parsing, and Lint

### `Verible`

Use for:

- formatting
- style lint
- editor integration

Why it matters:

- best open-source choice for keeping RTL style stable
- useful for reviewability and CI checks

## 2. SystemVerilog Frontend and Elaboration

### `Slang`

Use for:

- parsing
- elaboration
- semantic checking

Why it matters:

- strongest practical open-source frontend for modern SystemVerilog
- good first parser to trust before relying on richer language constructs

### `Surelog + UHDM`

Use for:

- preprocessing and parsing
- elaboration
- interoperability through UHDM

Why it matters:

- good when multiple tools need to consume a common frontend result
- useful if the project later grows into a more complex tool flow

## 3. Simulation

### `Verilator`

Use for:

- main RTL simulation
- fast regressions
- lint-like design checks

Why it matters:

- strongest practical open-source simulator for compiled design-oriented runs
- a good fit for cycle-sensitive FSM verification

### `Icarus Verilog`

Use for:

- simple smoke tests
- second-opinion simulation on small benches

Why it matters:

- still useful as a lightweight compatibility check

## 4. Feature-Support Tracking

### `sv-tests`

Use for:

- checking whether a given frontend really supports a feature
- comparing tool capability before adopting unusual SystemVerilog constructs

Why it matters:

- prevents guessing based on outdated assumptions

## 5. Synthesis

### `Yosys`

Use for:

- synthesis
- netlist generation
- integration with the current ASIC flow

Why it matters:

- the standard open-source synthesis anchor for this repository

Caution:

- synthesis support is not the same as full SystemVerilog support
- keep core RTL conservative and synthesizable

### `yosys-slang`

Use for:

- stronger SystemVerilog frontend support in Yosys flows

Why it matters:

- useful if native Yosys frontend limitations become painful

## 6. Automated Formal Checking

### `SymbiYosys`

Use for:

- bounded checks
- assertion-driven sanity checks
- complementary bug finding next to Lean proofs

Why it matters:

- especially useful for control, handshake, and timing sanity properties

## Recommended Tool Stack for This Repository

### Editing and style

- `Verible`

### Parser confidence

- `Slang`
- `sv-tests`

### Simulation

- `Verilator`
- optional `Icarus Verilog` smoke checks

### Synthesis

- `Yosys`
- optional `yosys-slang`

### Formal complement

- Lean for semantic proofs
- optional `SymbiYosys` for automated bounded checks

## Bottom Line

There is no single open-source RTL tool that does everything best.

For this repository, the practical stack is:

- `Verible`
- `Slang`
- `Verilator`
- `Yosys`
- `sv-tests`

with `Surelog`, `yosys-slang`, and `SymbiYosys` added only when their specific role is needed.

## Sources

- Verilator guide: https://verilator.org/guide/latest/
- Icarus Verilog docs: https://steveicarus.github.io/iverilog/
- Slang docs: https://sv-lang.com/
- Surelog: https://github.com/chipsalliance/Surelog
- Verible docs: https://verible.readthedocs.io/
- Yosys docs: https://yosyshq.readthedocs.io/projects/yosys/en/stable/
- yosys-slang: https://github.com/povik/yosys-slang
- SymbiYosys docs: https://yosyshq.readthedocs.io/projects/sby/en/latest/
- sv-tests results: https://chipsalliance.github.io/sv-tests-results/
