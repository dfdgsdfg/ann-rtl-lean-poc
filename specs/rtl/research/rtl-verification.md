# RTL Verification Research

Date: 2026-03-12

## Question

What does the current open-source RTL verification stack look like, and what should this repository actually use?

## Short Answer

Open-source RTL verification is now good enough for a serious small-to-medium workflow, but it is still assembled from several tools rather than one complete environment.

For this repository, the practical verification stack is:

- `Verible` for style and lint
- `Slang` for parser and semantic confidence
- `Verilator` for fast simulation and coverage
- `cocotb` for Python-driven testbench growth if needed
- `SymbiYosys` for formal property checks
- `EQY` for equivalence checking
- `MCY` for mutation-coverage style testbench quality checks

The main open-source strength is:

- fast simulation
- Python-based testbenches
- Yosys-based formal and equivalence flows

The main limitation is:

- there is still no single open-source verification stack that feels like a full commercial SV/UVM + formal + coverage manager environment

That last point is an inference from the tool landscape below, not a claim copied from one source.

## 1. Verification Domains

For a small RTL project, verification work naturally splits into these domains:

1. lint and structural checks
2. simulation-based functional checking
3. property-based formal checking
4. equivalence checking
5. coverage and test-quality analysis
6. optional methodology and testbench organization

The current open-source ecosystem has reasonable answers for all six, but they are spread across different tools.

## 2. Lint and Structural Checks

### `Verible`

Best use:

- formatting
- style lint
- rule enforcement in CI
- project-wide source hygiene

Why it matters:

- the official project describes it as a suite of SystemVerilog developer tools, including a parser, style-linter, formatter, and language server
- its lint flow is specifically meant to catch constructs considered undesirable according to a style guide

Practical role in this repository:

- first line of verification before simulation
- keep RTL readable and consistent
- catch avoidable structural issues early

## 3. Parser and Semantic Confidence

### `Slang`

Best use:

- parsing
- elaboration
- semantic checking

Why it matters:

- strongest practical open-source SystemVerilog frontend today
- useful before depending on less common SystemVerilog constructs

Practical role in this repository:

- validate RTL source quality before simulation and synthesis
- act as the frontend we trust first when tool support is ambiguous

### `sv-tests`

Best use:

- checking actual feature support across open-source tools

Why it matters:

- avoids adopting a language feature that parses in one tool but breaks later in another

Practical role in this repository:

- feature-support reference
- especially useful before adding unusual SystemVerilog syntax to RTL or benches

## 4. Simulation-Based Verification

### `Verilator`

Best use:

- main RTL simulation
- fast regressions
- design-oriented lint
- coverage collection

Why it matters:

- the official project describes Verilator as an open-source SystemVerilog simulator and lint system
- it can perform lint checks and optionally insert assertion checks and coverage-analysis points
- its compiled simulation model is the strongest open-source option for fast regression-style runs

Practical role in this repository:

- main engine for RTL regression
- especially good for checking cycle-sensitive FSM behavior over many tests

### `Icarus Verilog`

Best use:

- simple smoke tests
- small standalone compatibility checks

Why it matters:

- still useful as a lightweight second opinion

Practical role in this repository:

- optional fallback simulator
- not the primary long-term verification engine

## 5. Python Testbench and Verification Methodology

### `cocotb`

Best use:

- Python-driven testbenches
- scoreboard logic
- stimulus generation
- regression scripting

Why it matters:

- the official docs describe cocotb as a coroutine-based cosimulation testbench environment for verifying VHDL and SystemVerilog RTL using Python
- this is the most mature open-source Python verification framework in common use

Practical role in this repository:

- a strong option if the current simple testbench grows into richer verification logic
- especially attractive because this repository already uses Python in the ANN and contract flows

### `pyuvm`

Best use:

- UVM-like organization in Python
- structured components such as monitor, scoreboard, coverage, driver, and environment

Why it matters:

- the docs explicitly frame it as Python plus IEEE 1800.2 ideas
- useful if we want more UVM-style structure without committing to a full SystemVerilog UVM stack

Practical role in this repository:

- optional
- only worth adding if the bench becomes complex enough to justify that structure

Inference:

- open-source verification today is more mature in Python-based methodology than in full open-source SV-UVM parity

## 6. Formal Property Verification

### `SymbiYosys`

Best use:

- bounded safety proofs
- unbounded safety proofs
- liveness checks
- generating testbenches from cover statements

Why it matters:

- the official docs describe it as a front-end driver for Yosys-based formal hardware verification flows
- it is the main open-source formal entry point for RTL assertions and property checks

Practical role in this repository:

- complement Lean proofs with automatic bug-finding
- particularly useful for controller, handshake, and temporal sanity properties

Important distinction:

- Lean is good for semantic proof and proof architecture
- SymbiYosys is good for automated property checking and counterexample generation

These are complementary, not interchangeable.

## 7. Equivalence Checking

### `EQY`

Best use:

- formal hardware equivalence checking
- comparing two RTL or netlist-related views of a design

Why it matters:

- the official docs describe EQY as a front-end driver for Yosys-based formal hardware equivalence checking

Practical role in this repository:

- compare contract-driven RTL revisions
- check equivalence across refactors
- eventually compare pre/post optimization or generated variants

This is especially relevant if the RTL changes while the mathematical contract stays fixed.

## 8. Coverage and Test-Quality Analysis

### Verilator coverage

Best use:

- line, branch, expression, toggle, and user coverage reporting
- annotated source reports
- merged coverage across multiple runs

Why it matters:

- the official `verilator_coverage` docs support annotated source, point-level display, merging, and ranking coverage contributions from tests

Practical role in this repository:

- quick coverage closure feedback for simulation regressions

### `MCY`

Best use:

- mutation coverage
- checking whether the testbench actually detects meaningful design perturbations

Why it matters:

- the official docs say MCY helps designers understand and improve testbench coverage
- it generates many mutations, filters them with formal techniques, and runs the testbench against relevant mutations

Practical role in this repository:

- stronger signoff than plain code coverage
- useful if we want to know whether a “passing” regression suite is actually discriminating enough

## 9. What This Means for This Repository

For this repository, the realistic verification plan is:

### Stage 1: baseline verification

- `Verible` for lint and style
- `Verilator` for simulation
- existing simple self-checking benches

### Stage 2: stronger functional verification

- grow the bench with Python-side support
- adopt `cocotb` if the SystemVerilog testbench becomes painful
- add coverage reporting with Verilator

### Stage 3: property and timing verification

- use Lean for semantic and temporal proofs tied to the machine model
- use `SymbiYosys` for automatically checked safety and timing properties

### Stage 4: change validation and test-quality closure

- use `EQY` for equivalence checks across RTL revisions
- use `MCY` for mutation-coverage style test quality checks

## 10. Recommended Stack

If we keep this project intentionally small and rigorous, the recommended stack is:

- `Verible` for style and lint
- `Slang` for parser confidence
- `Verilator` for primary simulation
- optional `cocotb` for Python-driven verification growth
- `SymbiYosys` for automated formal checks
- `EQY` for equivalence
- optional `MCY` for mutation-coverage style signoff

## 11. Bottom Line

Open-source RTL verification in 2026 is strong enough to support this repository well.

The strongest parts are:

- simulation speed
- Python-based testbench productivity
- Yosys-based formal and equivalence checking

The practical lesson is:

- do not search for one perfect tool
- build a layered verification flow
- use Lean for proof-oriented semantics
- use YosysHQ tools for automated property, equivalence, and coverage-style closure

## Sources

- Verilator: https://verilator.org/guide/latest/
- Verilator coverage: https://verilator.org/guide/latest/exe_verilator_coverage.html
- Icarus Verilog: https://steveicarus.github.io/iverilog/
- Verible: https://github.com/chipsalliance/verible
- Slang: https://sv-lang.com/
- cocotb docs: https://docs.cocotb.org/en/stable/
- pyuvm docs: https://pyuvm.readthedocs.io/en/latest/
- SymbiYosys docs: https://symbiyosys.readthedocs.io/en/latest/
- EQY docs: https://yosyshq.readthedocs.io/projects/eqy/en/latest/
- MCY docs: https://yosyshq.readthedocs.io/projects/mcy/en/latest/
- sv-tests results: https://chipsalliance.github.io/sv-tests-results/
