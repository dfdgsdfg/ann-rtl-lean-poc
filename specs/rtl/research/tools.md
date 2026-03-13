# RTL Tools: Open-Source and Industry Reference

Date: 2026-03-13

## Scope

This document covers the digital design toolchain — open-source tools, their industry counterparts, what this project uses, and where the gaps are. It is organized by workflow stage.

## 1. HDL Authoring, Lint, and Formatting

| | Open-source | Industry |
|---|---|---|
| **Lint & style** | Verible | Synopsys SpyGlass, Cadence HAL, Mentor Questa Lint |
| **Language server** | Verible LSP, svls | Built into vendor IDEs (Synopsys Verdi, Cadence SimVision) |
| **Formatting** | Verible formatter | Synopsys SpyGlass auto-format |

### Open-source detail

**Verible** — best open-source SystemVerilog linter and formatter. Integrates with VS Code and CI pipelines. Covers style, naming conventions, and basic structural checks. `svls` is a lighter alternative language server.

Use for: formatting, style lint, editor integration.

### Industry detail

**SpyGlass** (Synopsys) — de facto standard for RTL lint in production. Goes far beyond style: catches CDC (clock domain crossing) issues, X-propagation problems, power-intent violations, and structural design rule violations. HAL (Cadence) and Questa Lint (Siemens/Mentor) serve similar roles.

### Gap

SpyGlass CDC analysis has no open-source equivalent. For single-clock designs like this project, the gap is not relevant.

## 2. SystemVerilog Frontend and Parsing

| | Open-source | Industry |
|---|---|---|
| **Parser / elaboration** | Slang | Synopsys VCS parser, Cadence Xcelium parser |
| **Preprocessing + IR** | Surelog + UHDM | Vendor-internal frontends |
| **Feature compliance** | sv-tests | IEEE 1800 compliance suites (vendor-internal) |

### Open-source detail

**Slang** — strongest open-source SystemVerilog frontend. Handles most of IEEE 1800-2017. Good first parser to trust before relying on richer language constructs.

**Surelog + UHDM** — preprocessing, parsing, and elaboration with a shared intermediate representation. Useful when multiple tools need to consume a common frontend result.

**sv-tests** — community test suite for checking which SystemVerilog features each tool actually supports. Prevents guessing based on outdated assumptions.

### Industry detail

Commercial simulators (VCS, Xcelium) have the most complete SystemVerilog frontends. They support the full language including UVM, constrained random, and coverage constructs that open-source tools cannot handle yet.

## 3. Simulation

| | Open-source | Industry |
|---|---|---|
| **Compiled simulation** | Verilator | Synopsys VCS, Cadence Xcelium |
| **Interpreted simulation** | Icarus Verilog | Aldec Riviera-PRO |
| **Waveform viewer** | GTKWave | Synopsys Verdi, Cadence SimVision |
| **Waveform format** | VCD, FST | FSDB (Synopsys proprietary), VCD |
| **UVM support** | Limited (Verilator partial) | Full UVM in VCS, Xcelium |
| **Mixed-signal** | None | Cadence AMS Designer, Synopsys CustomSim |
| **Python testbench** | cocotb | Not standard (some Verdi integration) |

### Open-source detail

**Verilator** — compiles SystemVerilog to C++. Very fast for RTL-level simulation. Does not support full SystemVerilog testbench constructs (delays, fork-join, classes). Strongest practical open-source simulator for compiled, cycle-sensitive FSM verification.

**Icarus Verilog** — interpreted Verilog simulator. Supports delays and basic testbench constructs. Slower but more portable. Useful as a lightweight second-opinion compatibility check.

**GTKWave** — reads VCD and FST waveforms for visual signal inspection.

**cocotb** — Python-based testbench framework running on top of Verilator or Icarus. Closest open-source alternative to UVM-style verification.

### Industry detail

**VCS** (Synopsys) and **Xcelium** (Cadence) are the two dominant simulators. They support UVM (Universal Verification Methodology), constrained random generation, functional coverage, and assertion-based verification. Handle multi-million gate designs.

**Verdi** (Synopsys) provides deep debug: schematic-linked waveforms, FSM visualization, protocol analysis, and FSDB format.

### Gap

UVM-class testbenches are the industry standard for verification. Open-source tools cannot run them. For this project's size, directed testbenches in plain SystemVerilog are sufficient.

## 4. Synthesis

| | Open-source | Industry |
|---|---|---|
| **Logic synthesis** | Yosys | Synopsys Design Compiler (DC), Cadence Genus |
| **Enhanced SV frontend** | yosys-slang | Built into DC and Genus |
| **FPGA synthesis** | Yosys (+ nextpnr) | Xilinx Vivado, Intel Quartus |
| **Power analysis** | Rough estimates via Yosys | Synopsys PrimePower, Cadence Joules |

### Open-source detail

**Yosys** — standard open-source synthesis tool. Reads Verilog/SystemVerilog, optimizes logic via ABC, maps to technology libraries. The synthesis anchor for this repository.

Caution: synthesis support is not the same as full SystemVerilog support. Keep core RTL conservative and synthesizable.

**yosys-slang** — uses Slang as a frontend for Yosys, improving SystemVerilog parsing. Useful if native Yosys frontend limitations become painful.

**nextpnr** — open-source FPGA place-and-route. Pairs with Yosys for fully open FPGA flows (Lattice iCE40, ECP5).

### Industry detail

**Design Compiler** (Synopsys) — most widely used synthesis tool in ASIC design. Produces higher quality-of-results (QoR) than Yosys on complex designs: better area, timing, and power. Supports DFT insertion (scan chains, BIST, JTAG).

**Genus** (Cadence) — competing synthesis tool with similar capabilities.

**Vivado** (AMD/Xilinx) and **Quartus** (Intel/Altera) — proprietary FPGA synthesis with vendor-specific optimization.

### Gap

DFT insertion. Production ASICs require scan chains for manufacturing test. Yosys has no DFT support. For research shuttle runs, this is acceptable.

## 5. Static Timing Analysis (STA)

| | Open-source | Industry |
|---|---|---|
| **STA engine** | OpenSTA | Synopsys PrimeTime |
| **Integrated in P&R** | OpenROAD (uses OpenSTA) | PrimeTime (standalone sign-off) |
| **Multi-corner/multi-mode** | OpenSTA (basic) | PrimeTime (full MCMM) |
| **Signal integrity** | Not available | PrimeTime SI |

### Open-source detail

**OpenSTA** — runs inside OpenROAD and provides timing reports during place and route. Handles basic multi-corner analysis.

### Industry detail

**PrimeTime** (Synopsys) — industry sign-off STA tool. All foundries accept PrimeTime results for tapeout sign-off. Handles crosstalk (SI), on-chip variation (OCV), and statistical timing (SSTA). No open-source equivalent.

## 6. Place and Route

| | Open-source | Industry |
|---|---|---|
| **Automated P&R flow** | OpenLane / OpenLane2 | Synopsys Fusion Compiler, Cadence Innovus |
| **Core P&R engine** | OpenROAD | Same tools (internal engines) |
| **Clock tree synthesis** | OpenROAD CTS | Innovus CTS, ICC2 CTS |
| **Floorplanning** | OpenROAD GUI | Innovus Floorplan, ICC2 |
| **Power planning** | OpenROAD PDN | Built into Innovus, ICC2 |

### Open-source detail

**OpenLane** — wraps OpenROAD, Yosys, Magic, and other tools into an automated RTL-to-GDSII flow. OpenLane2 is the next-generation version with a Python API.

**OpenROAD** — capable P&R engine handling placement, CTS, routing, and optimization.

### Industry detail

**Innovus** (Cadence) and **Fusion Compiler / ICC2** (Synopsys) are the two dominant P&R platforms. They handle designs with billions of transistors, multi-patterning lithography, and advanced node constraints (FinFET, GAA). They provide in-tool timing closure, power optimization, and physical verification.

## 7. Physical Verification (DRC, LVS, Parasitic Extraction)

| | Open-source | Industry |
|---|---|---|
| **DRC** | Magic, KLayout DRC | Siemens Calibre, Synopsys ICV |
| **LVS** | Magic + netgen | Siemens Calibre, Synopsys ICV |
| **Parasitic extraction** | Magic (basic SPICE) | Synopsys StarRC, Cadence QRC |
| **Layout viewer/editor** | KLayout, Magic | Cadence Virtuoso Layout Suite |
| **Layout format** | GDSII, OASIS | GDSII, OASIS |

### Open-source detail

**Magic** — handles DRC and basic LVS for older process nodes. Also does basic parasitic extraction.

**netgen** — LVS by comparing SPICE netlists.

**KLayout** — excellent layout viewer with scripted DRC support and Python API.

### Industry detail

**Calibre** (Siemens EDA, formerly Mentor) — gold standard for physical verification. Foundries provide Calibre rule decks as the reference.

**StarRC** (Synopsys) and **QRC** (Cadence) — parasitic extraction with accuracy required for sign-off at advanced nodes.

### Gap

Foundry sign-off. Most foundries require Calibre or ICV results for tapeout acceptance. Open-source DRC/LVS is useful for development but may not be accepted as final sign-off. Sky130 provides Magic-compatible rule decks, so this gap is smaller on that PDK.

## 8. Formal Verification

| | Open-source | Industry |
|---|---|---|
| **Theorem proving** | Lean 4 (this project) | Not common in RTL flows |
| **Model checking / BMC** | SymbiYosys (Yosys + solvers) | Synopsys VC Formal, Cadence JasperGold |
| **Equivalence checking** | Yosys `equiv_*` commands | Synopsys Formality, Cadence Conformal |
| **Assertion synthesis** | Manual SVA + SymbiYosys | GoldMine (auto-generated assertions) |

### Open-source detail

**Lean 4** — this project uses Lean for mathematical proofs about the design specification. This is unconventional and stronger than typical formal verification: it proves properties for all inputs, not just bounded traces.

**SymbiYosys** — bounded model checking and k-induction using SAT/SMT solvers. Useful for control, handshake, and timing sanity properties as a complement to Lean proofs.

**Yosys equivalence** — basic equivalence checking between RTL and netlist. Limited to small designs.

### Industry detail

**JasperGold** (Cadence) and **VC Formal** (Synopsys) — dominant formal verification platforms. Support property checking (SVA assertions), coverage analysis, sequential equivalence, and automatic bug hunting.

**Formality** (Synopsys) and **Conformal** (Cadence) — check that the synthesized netlist is logically equivalent to the RTL. A critical sign-off step for any tapeout.

### Gap

Equivalence checking at scale. Yosys equivalence is limited to small designs. For production tapeout, Formality or Conformal is required.

## 9. Design for Test (DFT)

| | Open-source | Industry |
|---|---|---|
| **Scan insertion** | None | Synopsys DFT Compiler, Cadence Modus |
| **ATPG** | None | Synopsys TetraMAX, Cadence Modus |
| **BIST** | Manual RTL | Synopsys DFT Compiler |
| **JTAG / boundary scan** | Manual RTL | Synopsys DFT Compiler |

### Open-source detail

No open-source DFT tool exists. For research and education projects, DFT is typically skipped. For shuttle runs (efabless/Google MPW), designs are small enough that functional test suffices.

### Industry detail

Every production ASIC includes scan chains for manufacturing test. DFT Compiler inserts scan flip-flops and TetraMAX generates test patterns (ATPG). Without DFT, you cannot test chips on ATE in a factory. Hard requirement for mass production.

## 10. PDK and Standard Cell Libraries

| | Open-source | Industry |
|---|---|---|
| **130nm** | SkyWater Sky130 (open PDK) | GlobalFoundries 130nm (commercial) |
| **90nm** | GlobalFoundries GF180MCU (open PDK) | TSMC 90nm |
| **Advanced nodes** | None | TSMC 5nm/3nm, Samsung, Intel |
| **Standard cells** | Sky130 std cells, OpenRAM | ARM Artisan, Synopsys DesignWare |
| **Memory compiler** | OpenRAM | Synopsys, ARM memory compilers |
| **IP blocks** | Limited (OpenCores, PULP) | Synopsys DesignWare, ARM CoreLink |

### Open-source detail

**Sky130** — most mature open PDK, provided by SkyWater and Google. This project targets Sky130.

**GF180MCU** — GlobalFoundries open PDK, another option for open-source tapeout.

**OpenRAM** — generates SRAM macros for open PDKs.

**efabless chipIgnite** — shuttle program offering free/low-cost tapeout on Sky130.

### Industry detail

TSMC provides PDKs for 5nm, 3nm, and below under strict NDA. Standard cell libraries from ARM and Synopsys are licensed and highly optimized. Memory compilers generate SRAM/ROM macros tuned for each process node.

## 11. IP and SoC Integration

| | Open-source | Industry |
|---|---|---|
| **CPU cores** | RISC-V (PULP, Rocket, BOOM) | ARM Cortex, Synopsys ARC |
| **Bus interconnect** | AXI/AHB open implementations | ARM AMBA (licensed), Synopsys CoreLink |
| **Peripheral IP** | OpenCores (UART, SPI, I2C) | Synopsys DesignWare, Cadence IP |
| **SoC integration** | Manual / FuseSoC | Synopsys Platform Architect, ARM SoC Designer |
| **Security SoC** | OpenTitan | ARM TrustZone, vendor-specific |

### Open-source detail

RISC-V has created a rich ecosystem of open CPU cores. FuseSoC is a package manager for HDL IP blocks. OpenTitan is a full open-source secure microcontroller SoC.

### Industry detail

ARM dominates the commercial IP market. A typical SoC license includes CPU, GPU, interconnect, and peripheral IP. Synopsys DesignWare provides hundreds of verified IP blocks (USB, PCIe, DDR, Ethernet).

## 12. CI/CD and Infrastructure

| | Open-source | Industry |
|---|---|---|
| **Build system** | Make, FuseSoC, hdlmake | Synopsys VCS Makefile templates |
| **Regression management** | Custom scripts | Synopsys Verdi Regression, Cadence vManager |
| **Coverage merging** | Manual | vManager, Verdi coverage |
| **Version control** | Git | Git + Perforce (for large binary PDK files) |

## Summary: This Project's Stack

| Stage | What we use | Industry equivalent | Gap severity |
|---|---|---|---|
| Lint | (not yet) | SpyGlass | Low — Verible covers basics |
| Frontend | (not yet) | VCS/Xcelium parser | Low — Slang available |
| Simulation | Verilator + Icarus | VCS + Xcelium | Low — sufficient for this size |
| Synthesis | Yosys | Design Compiler | Low — design is small |
| P&R | OpenLane / OpenROAD | Innovus / ICC2 | Medium — not fully exercised |
| STA | OpenSTA | PrimeTime | Medium — no sign-off equivalence |
| DRC/LVS | Magic + netgen | Calibre | Medium — Sky130 decks exist |
| Formal | Lean 4 | VC Formal / JasperGold | Different approach — stronger proofs |
| DFT | None | DFT Compiler | High for production, N/A for research |
| PDK | Sky130 | TSMC / Samsung | N/A — different targets |

For a research/education project on Sky130, the open-source stack is viable end-to-end. The gaps become critical only at advanced nodes or for mass production.

## Recommended Stack for This Repository

### Now in use

- **Verilator** + **Icarus Verilog** — dual-simulator regression
- **Yosys** — synthesis
- **OpenLane / OpenROAD** — place and route (config exists, not fully exercised)
- **Lean 4** — formal proofs

### Recommended additions

- **Verible** — lint and formatting
- **Slang** — parser confidence before adopting new SV constructs
- **sv-tests** — feature support tracking
- **SymbiYosys** — bounded model checking as complement to Lean proofs

### Add only when needed

- **Surelog + UHDM** — if multiple tools need a shared frontend
- **yosys-slang** — if Yosys SV parsing becomes limiting
- **cocotb** — if Python-driven testbenches become useful

## Sources

- Verilator: https://verilator.org/guide/latest/
- Icarus Verilog: https://steveicarus.github.io/iverilog/
- Slang: https://sv-lang.com/
- Surelog: https://github.com/chipsalliance/Surelog
- Verible: https://verible.readthedocs.io/
- Yosys: https://yosyshq.readthedocs.io/projects/yosys/en/stable/
- yosys-slang: https://github.com/povik/yosys-slang
- SymbiYosys: https://yosyshq.readthedocs.io/projects/sby/en/latest/
- sv-tests: https://chipsalliance.github.io/sv-tests-results/
- OpenLane: https://openlane.readthedocs.io/
- OpenROAD: https://openroad.readthedocs.io/
- Sky130 PDK: https://skywater-pdk.readthedocs.io/
- cocotb: https://docs.cocotb.org/
