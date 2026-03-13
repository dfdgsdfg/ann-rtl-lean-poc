# Formal Verification for HDL: Current State, Tools, Ecosystem, and Industry

Date: 2026-03-13

## Question

What is the current state of formal verification for hardware description languages?

What tools exist, how mature is the ecosystem, and how does the industry actually use formal verification today?

## Short Answer

Formal verification for HDL is now a structural necessity in the semiconductor industry, not an optional enhancement.

The main forces shaping the current landscape are:

- rising RTL complexity outpacing simulation-only flows
- only 14% of projects achieving first-silicon success in 2024 (the lowest in two decades)
- 75% of projects experiencing schedule slippage
- roughly 70% of total project time spent on functional verification

The commercial ecosystem is dominated by three vendors:

- Cadence JasperGold
- Synopsys VC Formal
- Siemens Questa One (incorporating OneSpin)

The open-source ecosystem is anchored by:

- SymbiYosys / Yosys formal flows
- ABC (Berkeley)
- SMT solvers (Z3, cvc5, Bitwuzla)
- BTOR2 as an interchange format

The fastest-moving trend is AI/ML integration:

- ML-powered engine selection and parameterization
- LLM-based assertion generation
- agentic AI workflows for autonomous verification planning

For this repository, the practical relevance is:

- SymbiYosys remains the right open-source formal entry point for the RTL layer
- Lean remains the right proof authority for semantic and temporal guarantees
- the commercial ecosystem is context for understanding industry practice, not a dependency

## 1. Industry Adoption

### 1.1 Scale of verification effort

According to the 2024 Wilson Research Group IC/ASIC Functional Verification Trend Report, approximately 70% of total project time is spent on functional verification. This figure has held steady since roughly 2008. Verification engineers spend the largest portion of their time debugging.

In the 2024 study:

- only 14% of projects achieved first-silicon success — the lowest rate in two decades
- 75% of projects experienced schedule slippage, up from a historical ~65%

These numbers are the context for why formal verification adoption is growing. Simulation alone cannot keep pace with rising RTL complexity and shrinking tape-out schedules.

### 1.2 Growth rates

IC/ASIC formal property checking adoption is increasing at approximately 5.8% CAGR.

Automatic formal applications (connectivity checking, register verification, X-propagation analysis, CDC) are growing faster, at approximately 8.7% CAGR. The growth in automatic apps is a key driver because they reduce the expertise barrier.

### 1.3 Who uses it

All major semiconductor companies use formal verification as part of their verification methodology:

- Intel, AMD, NVIDIA, Qualcomm, Apple, Arm, Broadcom, and others
- IP vendors and design houses
- FPGA teams — the 2024 FPGA report noted 87% of FPGA projects reported non-trivial bug escapes into production

The growth is also reaching specialized formal verification consultancies:

- Axiomise (UK) reports having trained over 1,000 engineers and worked with 20+ customers
- LUBIS EDA (Germany) saw 40%+ customer growth in 2025 and expanded its formal verification team by 80%

## 2. Commercial EDA Tools

### 2.1 Cadence JasperGold

JasperGold is generally considered the market leader in breadth of formal apps. Now in its third generation ("Smart JasperGold"), it uses machine-learning-enhanced proof technology.

Key apps:

- Formal Property Verification (FPV) — core assertion-based verification
- Connectivity Verification — static, temporal, and conditional SoC connectivity
- Security Path Verification — proves secure data cannot be illegally read or overwritten
- X-Propagation Verification — tracks unknown (X) states through designs
- Sequential Equivalence Checking (SEC) — validates RTL ECOs
- Clock Domain Crossing (CDC) — formal CDC analysis
- Control/Status Register (CSR) Verification — automated register checking
- Design Coverage Verification — formal coverage metrics for sign-off
- RTL Development App — early RTL quality checks

Performance claims:

- 2X faster proof out of the box
- 5X faster regression runs
- 50%+ reduction in non-converged properties
- 2X compilation capacity with 50% memory reduction

ML selects and parameterizes solvers for faster first-time proofs and optimizes successive regression runs.

Integration: part of Cadence's full verification flow alongside Xcelium simulation, Palladium emulation, Protium prototyping, and the Verisium AI-driven verification platform.

### 2.2 Synopsys VC Formal

Synopsys's comprehensive formal solution, tightly integrated with VCS simulation and Verdi debug.

Key apps:

- Formal Property Verification (FPV) — SVA-based assertion proving
- Datapath Validation (DPV) — with HECTOR technology for ALU/FPU/DSP equivalence checking
- Automatic Extracted Properties (AEP) — auto-detects out-of-bound arrays, arithmetic overflow, X-assignments, multi-driver conflicts
- Formal Coverage Analyzer (FCA) — proves coverage points are unreachable
- Connectivity Checking (CC) — SoC-level connectivity verification
- Sequential Equivalence Checking (SEQ)
- Formal Register Verification (FRV)
- Formal X-Propagation Verification (FXP)
- Functional Safety (FuSa) — formal fault classification for ISO 26262/IEC 61508
- Security Verification (FSV) — ensures secure/non-secure data isolation
- Regression Mode Accelerator (RMA)
- Assertion IP (AIP) portfolio for standard bus protocols

AI capabilities:

- ML-powered engines deliver up to 10X speedup in formal property verification
- Synopsys.ai Copilot includes formal assertion generation with reported >80% syntax accuracy and >70% functional accuracy
- AgentEngineer prototypes demonstrated at DAC 2025

### 2.3 Siemens Questa One / OneSpin

Siemens unified its verification portfolio under the Questa One brand (available June 2025), combining legacy Questa, OneSpin (acquired 2021), and Catapult formal technologies.

Formal suite:

- PropCheck — general assertion-based formal verification with SVA, PSL, and OVL support, including multi-clocked assertions
- OneSpin Formal Verification — acquired technology for unbounded proofs, functional safety (ISO 26262, IEC 61508, DO-254), and security verification (hardware Trojan detection)
- Catapult Formal Assert / CoverCheck — formal methods for high-level synthesis designs
- Post-Silicon Debug — uses PropCheck to hunt for root causes of observed silicon failures
- CDC/RDC verification

Agentic AI Toolkit (February 2026):

- autonomous AI agents for verification
- RTL Code Agent (generates synthesizable RTL from natural language)
- Lint Agent (auto-configures and runs lint analysis)
- CDC Agent (auto-configures clock domain crossing verification)
- built on NVIDIA Llama Nemotron and NVIDIA NIM
- integrates with GitHub Copilot, Claude Code, Cursor, and Siemens' own Fuse IDE

### 2.4 Other commercial players

LUBIS EDA (Germany, founded 2020):

- formal verification consulting with a Property Generator framework for building Assertion IP systematically
- structured Plan/Prep/Execute/Sign-off methodology
- 40%+ customer growth in 2025

Axiomise (UK):

- the world's only company solely focused on formal verification training, consulting, and services
- vendor-neutral formalISA app for RISC-V processor verification
- partnered with Bluespec in July 2025
- trained 1,000+ engineers

### 2.5 Pricing and accessibility

Commercial EDA formal verification licenses are expensive:

- a single tool seat can cost $50,000+ per year
- licensing models include perpetual (expensive plus maintenance), time-based subscription (more common), and cloud pay-per-use
- the cloud EDA market is valued at $4.18 billion in 2025, projected to reach $7.52 billion by 2034
- cloud-based formal enables significant turnaround time reduction

This pricing is relevant context: the open-source stack is not just a preference but often a necessity for smaller teams.

## 3. Open-Source Tools

### 3.1 SymbiYosys (SBY) / Yosys

SymbiYosys is the primary open-source formal verification front-end, built on top of the Yosys synthesis suite.

Capabilities:

- bounded verification of safety properties (assertions)
- unbounded verification of safety properties
- test bench generation from cover statements
- verification of liveness properties
- support for multiple back-end engines including Yosys-SMTBMC and AIGER-based engines (ABC, Btor2Tools)
- recent updates (May 2025) added support for designs containing blackboxes

YosysHQ Tabby CAD Suite is the commercial extension that adds the Verific frontend for industry-grade SystemVerilog and VHDL support (including SVA), plus formal apps. This bridges some of the gap between open-source and commercial tools.

### 3.2 ABC (Berkeley)

ABC is an academic industrial-strength system for sequential logic synthesis and formal verification from UC Berkeley, maintained by Alan Mishchenko.

- operates on And-Inverter Graphs (AIGs)
- provides combinational equivalence checking (CEC) and sequential equivalence checking (SEQ) engines
- widely used as a back-end engine by other tools including SymbiYosys

### 3.3 rIC3

Hardware formal verification tool that won first place in both the bit-level track and word-level bit-vector track at HWMCC 2024 and 2025.

This is the current state-of-the-art in open hardware model checking competition results.

### 3.4 Other open-source tools

- EBMC (Enhanced Bounded Model Checker) — includes both bounded and unbounded model checking engines for hardware designs
- nuXmv/NuSMV — symbolic model checkers for finite-state and infinite-state systems using SAT/BDD/SMT techniques
- Pono — flexible SMT-based model checker from Stanford
- AVR — abstractly verifying reachability
- riscv-formal — open-source RISC-V ISA formal verification framework built on SymbiYosys

### 3.5 Open-source vs. commercial gap

The gap remains significant but is narrowing in specific areas.

Where commercial tools are clearly ahead:

- language support — open-source tools have limited SystemVerilog support; full SV/SVA requires the commercial Verific frontend in Tabby CAD
- capacity — commercial tools handle much larger designs due to decades of engine optimization
- automation — commercial apps (connectivity checking, CSR verification, security path) have no open-source equivalents
- debug and UI — commercial tools offer sophisticated GUIs, waveform viewers, proof visualization

Where open-source is strong:

- education and learning
- small designs and IP blocks
- RISC-V verification
- CI integration
- providing the back-end engines (ABC, SMT solvers) that even commercial tools use internally

## 4. Formal Verification Techniques

### 4.1 Model checking

Bounded Model Checking (BMC):

- checks properties up to k time steps using SAT solvers
- highly effective at bug finding
- introduced in 1999, it became the dominant hardware verification technique
- Intel reported advantages over BDD-based checkers on Pentium 4 designs

Unbounded Model Checking:

- proves properties for all reachable states
- techniques include k-induction, IC3/PDR (Property Directed Reachability), and interpolation
- tools like rIC3 and EBMC support both bounded and unbounded modes

Recent advances:

- ML-based engine selection — e.g., Multi-Armed Bandit reinforcement learning to pick the best BMC engine per unrolling depth

### 4.2 Equivalence checking

Combinational Equivalence Checking (CEC):

- verifies pre/post synthesis netlists are functionally identical

Sequential Equivalence Checking (SEC):

- validates RTL-to-RTL changes (ECOs), clock-gating, retiming transformations

### 4.3 Property checking (SVA/PSL)

The core formal technique:

- designers write temporal properties (assertions) in SVA or PSL
- the tool exhaustively proves or disproves them against the design
- this is where formal verification adds its unique value over simulation

### 4.4 Formal coverage analysis

Proves that uncovered simulation coverage points are truly unreachable (not just missed by simulation). This enables formal sign-off: the combination of simulation coverage plus formal unreachability proof equals complete closure.

### 4.5 Connectivity checking

Verifies SoC-level signal routing, register connections, and bus connectivity without requiring simulation. This is one of the "automatic" formal apps that scales well to chip level because it exploits structural properties.

### 4.6 X-propagation analysis

Tracks unknown/uninitialized (X) values through the design to find simulation/synthesis mismatches. Important because X-optimism in simulation can mask real bugs that appear in silicon.

### 4.7 Clock domain crossing (CDC) verification

Formal analysis of data transfers between clock domains to detect metastability, glitches, and data loss.

A new Accellera CDC/RDC Standard 1.0 was approved in March 2026, defining a vendor-neutral approach for CDC/RDC intent capture.

### 4.8 Security path verification

Proves that secure data cannot reach non-secure destinations and non-secure data cannot overwrite secure destinations. Hardware Trojan detection using formal methods is an active research area.

## 5. Standards and Languages

### 5.1 SystemVerilog Assertions (SVA)

SVA (part of IEEE 1800 SystemVerilog standard) is the dominant assertion language for hardware formal verification.

Layered structure:

- Booleans
- sequences (regular expressions over time)
- properties (temporal assertions over sequences)
- statements (assert, assume, cover, restrict)

SVA is supported by all major commercial tools and by open-source tools through the Verific frontend in Tabby CAD. Native Yosys has partial SVA support.

### 5.2 PSL (Property Specification Language)

IEEE 1850 standard. Similar layered structure to SVA. Supported by Siemens PropCheck and other tools. Less dominant than SVA in current practice but still used, especially in VHDL flows.

### 5.3 BTOR2

The standard format for word-level hardware model checking. Used in the Hardware Model Checking Competition (HWMCC). Btor2Tools provides parsers and simulators. Increasingly important as an interchange format between tools.

### 5.4 SMT-LIB

Standard format for SMT solver interaction. Used by formal tools' back-end engines. Yosys-SMTBMC generates SMT-LIB queries for verification.

### 5.5 UPF (Unified Power Format)

IEEE 1801 standard for specifying power intent. Used in low-power verification and formal analysis of power domain crossings.

### 5.6 Portable Stimulus Standard (PSS)

PSS 3.0 was released in August 2024, adding behavioral coverage, PSS-SystemVerilog mapping, and formal semantics. PSS is complementary to formal verification — it enables portable test intent that can be used across simulation, emulation, and formal.

## 6. Industry Trends

### 6.1 Shift-left verification

Formal verification is the ultimate shift-left technique — it can find bugs before a simulation testbench exists. Cloud-based formal further enables shift-left by providing on-demand compute for faster turnaround.

### 6.2 Formal sign-off

The industry is moving from "formal as bug hunting" to "formal as sign-off."

Structured methodologies are emerging:

- LUBIS EDA's Plan/Prep/Execute/Sign-off flow
- Axiomise's structured formal verification training
- the concept of "seven steps of formal signoff" in the industry literature

Formal sign-off means: for a given block, every property is either proven, covered by assumption justification, or bounded with explicit rationale. This is a measurable completeness criterion, unlike simulation which can always run more tests.

### 6.3 Cloud-based formal verification

Running commercial formal tools on cloud infrastructure is now documented:

- Cadence JasperGold on AWS at scale
- Synopsys FlexEDA pay-per-use on cloud
- the cloud EDA market is growing rapidly

Cloud formal enables smaller teams to access commercial-grade verification without large on-premises investments.

### 6.4 Safety-critical applications

Formal verification is increasingly mandated or strongly recommended for:

Automotive (ISO 26262):

- formal fault classification, FMEA/FMEDA automation
- Synopsys VC Formal FuSa and VC Functional Safety Manager
- Cadence JasperGold for IEC 61508 SIL 4

Aerospace (DO-254):

- hardware design assurance at various design assurance levels
- OneSpin/Siemens targets safety certification with formal proofs

Industrial (IEC 61508):

- functional safety for electronic systems

### 6.5 Security verification

Hardware security verification using formal methods is a growing priority:

- formal tools verify secure data isolation
- detect potential hardware Trojan insertion points
- analyze information flow
- RISC-V AIP from Synopsys has identified security issues such as illegal access conditions during privilege escalation

### 6.6 AI/ML-assisted formal verification

This is the fastest-moving trend area.

LLM-based assertion generation (2024-2026):

- STELLAR (2026): structure-guided LLM assertion retrieval
- AssertLLM (ASP-DAC 2025): multi-LLM pipeline for SVA generation from specs and waveforms
- FLAG (2025): formal and LLM-assisted SVA generation
- LAAG-RV: LLM-assisted assertion generation for RTL verification
- CoverAssert (ETS 2026): iterative LLM-based assertion generation with coverage guidance

These methods reduce SVA development time from hours to seconds per module.

Commercial AI integration:

- Synopsys.ai Copilot with formal assertion generation (>80% syntax accuracy, >70% functional accuracy)
- Siemens Questa One Agentic Toolkit (February 2026) with autonomous AI agents
- Cadence Verisium AI platform for cross-engine analytics

### 6.7 RISC-V verification ecosystem

RISC-V has become a focal point for formal verification:

- riscv-formal: open-source framework on SymbiYosys
- VC Formal extension for riscv-formal bridges open-source and commercial
- Axiomise formalISA: vendor-neutral formal app for RISC-V ISA compliance
- Synopsys RISC-V AIP: reusable SVA assertions and RTL logic for RISC-V
- a comprehensive survey of RISC-V processor verification was published in 2025

## 7. Key Challenges and Limitations

### 7.1 State space explosion

The fundamental challenge. Each additional state variable multiplies possible states exponentially.

Formal verification is not affected by input space complexity in the way simulation is — it reasons symbolically. But it can suffer state space explosion with large designs.

Mitigation techniques:

- modular/compositional verification — decompose into components
- abstraction and cone-of-influence reduction
- heuristic helper invariants and assumptions
- bounded analysis with increasing bounds
- ML-guided engine selection

### 7.2 Complexity barriers

Formal verification remains practically limited to IP blocks and subsystems rather than full SoC-level analysis.

The symbolic expression term size grows exponentially with increasing design size. This is why:

- most formal verification targets individual IP blocks, not full chips
- automatic apps (connectivity, register, CDC) are the exception — they can scale to chip level because they exploit structural properties rather than full behavioral state spaces

### 7.3 Expertise requirements

Formal verification requires specialized skills that are in short supply:

- the semiconductor industry faces a projected 50% demand-supply gap for engineers
- formal verification expertise is among the most scarce specializations
- the growth of automatic formal apps (8.7% CAGR) vs. property checking (5.8% CAGR) reflects the industry working around the expertise barrier

This is why LLM-based assertion generation is generating so much interest — it has the potential to lower the expertise barrier significantly.

### 7.4 Integration with simulation flows

Formal and simulation are complementary but historically siloed.

Integration is improving:

- Synopsys VC Formal integrates natively with VCS and Verdi
- Cadence Verisium provides unified coverage across Jasper, Xcelium, Palladium
- Siemens Questa One unifies formal and simulation under one platform

But methodological integration — unified test plans, shared coverage, coordinated debug — remains an active challenge.

## 8. Academic and Research Frontier

### 8.1 Key conferences

- FMCAD (Formal Methods in Computer-Aided Design): the premier academic conference, held its 25th edition in 2025
- DVCon (Design and Verification Conference): 2026 edition features dedicated formal methods tracks
- DAC (Design Automation Conference): continues to feature formal verification papers and tool demonstrations

### 8.2 Hardware Model Checking Competition (HWMCC)

HWMCC 2024 (12th edition, held at FMCAD'24 in Prague) introduced mandatory model-checking certificates.

The winner was rIC3, which also won in 2025. The competition drives advancement in back-end formal engines and uses the BTOR2 format.

The introduction of mandatory certificates is significant: it means tools must now prove they are correct, not just fast.

### 8.3 Emerging research areas

LLM-assisted formal verification is the hottest area, with dozens of papers at major venues.

Other active areas:

- compositional/modular verification for scalability beyond IP blocks
- hardware-firmware co-verification — e.g., HIVE: scenario-based decomposition with automated hint extraction
- certified model checking — requiring tools to produce verifiable certificates of their results
- MoXI: tool suite for model exchange between different formal tool ecosystems, enabling interoperability

Notable prediction:

- Martin Kleppmann (December 2025): "AI will make formal verification go mainstream," arguing that LLMs will lower the barrier to writing formal specifications

### 8.4 Notable academic tools

- rIC3 — HWMCC winner, state-of-the-art hardware model checker
- EBMC — Enhanced Bounded Model Checker from the CPROVER group
- Pono — Stanford's SMT-based model checker
- Btor2-Cert — certifying hardware verification framework

## 9. Assessment for This Repository

This repository uses:

- Lean for machine-checked proofs over a functional model
- Verilog for RTL implementation
- a contract-based verification approach connecting the two

### How the industry landscape maps to this project

The industry's three-vendor commercial ecosystem is context, not a dependency.

What is directly relevant:

1. SymbiYosys is the right open-source formal tool for automated property checking of the Verilog RTL. This is already noted in the RTL verification research.

2. SVA assertions written for SymbiYosys can check safety, timing, and handshake properties automatically. This complements Lean proofs rather than replacing them.

3. The BTOR2 format is relevant if the project ever wants to use academic model checkers (rIC3, EBMC, Pono) as alternative backends.

4. The LLM-based assertion generation trend is potentially useful for this project — generating SVA assertions from the Lean-side specifications could accelerate the formal verification layer.

5. The industry's move toward formal sign-off validates this project's approach: not just simulation, but machine-checked proofs plus automated formal checking.

### What this project already does well

- Lean provides a stronger semantic foundation than any commercial formal tool — the proofs are machine-checked theorems, not tool-dependent results
- the contract-based approach is a form of refinement verification, which is the same mathematical structure the industry uses (but implemented with a theorem prover rather than a commercial tool)

### What the industry has that this project does not

- automatic formal apps (connectivity, CSR, CDC, X-prop) — these are not relevant for a small single-module design
- scalability to million-gate designs — not needed here
- GUI-based debug and waveform integration — nice to have but not blocking

### Practical recommendation

No change to the existing project stack is needed based on this landscape review.

The existing plan — Lean for semantic proofs, SymbiYosys for automated formal checking — is well-aligned with industry best practice, adapted for a small rigorous project rather than a large commercial flow.

## Sources

- Wilson Research Group / Siemens EDA 2024 IC/ASIC Functional Verification Trend Report: <https://verificationacademy.com/topics/planning-measurement-and-analysis/wrg-industry-data-and-trends/2024-siemens-eda-and-wilson-research-group-ic-asic-functional-verification-trend-report/>
- Wilson Research Group 2024 FPGA Functional Verification Trend Report: <https://resources.sw.siemens.com/en-US/white-paper-2024-wilson-research-group-fpga-functional-verification-trend-report/>
- Cadence Jasper Verification Platform: <https://www.cadence.com/en_US/home/tools/system-design-and-verification/formal-and-static-verification/jasper-verification-platform.html>
- Cadence Verisium AI-Driven Verification: <https://www.cadence.com/en_US/home/tools/system-design-and-verification/ai-driven-verification.html>
- Synopsys VC Formal: <https://www.synopsys.com/verification/static-and-formal-verification/vc-formal.html>
- Synopsys VC Formal Datasheet: <https://www.synopsys.com/content/dam/synopsys/verification/datasheets/vc-formal-ds.pdf>
- Synopsys AI Capabilities Announcement (September 2025): <https://news.synopsys.com/2025-09-03-Synopsys-Announces-Expanding-AI-Capabilities-for-its-Leading-EDA-Solutions>
- Synopsys Cloud: <https://www.synopsys.com/cloud.html>
- Synopsys Formal in Cloud: <https://www.synopsys.com/blogs/chip-design/formal-chip-design-verification-in-the-cloud.html>
- Siemens Questa One: <https://eda.sw.siemens.com/en-US/ic/questa-one/>
- Siemens Questa One Formal Verification: <https://eda.sw.siemens.com/en-US/ic/questa-one/formal-verification/>
- Siemens OneSpin Formal Verification: <https://eda.sw.siemens.com/en-US/products/ic/questa/onespin-formal-verification/>
- Siemens Questa One Agentic AI Toolkit: <https://news.siemens.com/en-us/questa-one-agentic-ai-toolkit/>
- LUBIS EDA 2025 Summary: <https://semiwiki.com/forum/threads/2025-a-defining-year-for-lubis-eda.24667/>
- Axiomise: <https://www.axiomise.com/>
- Cloud EDA Market: <https://www.precedenceresearch.com/cloud-eda-market>
- SymbiYosys Documentation: <https://symbiyosys.readthedocs.io/>
- YosysHQ Tabby CAD Datasheet: <https://www.yosyshq.com/tabby-cad-datasheet>
- ABC (Berkeley): <https://github.com/berkeley-abc/abc>
- rIC3: <https://github.com/gipsyh/rIC3>
- riscv-formal: <https://github.com/YosysHQ/riscv-formal>
- VC Formal Extension for riscv-formal: <https://blog.yosyshq.com/p/risc-v-formal-verification-framework-extension-for-synopsys-vc-formal/>
- Accellera CDC/RDC Standard 1.0: <https://www.accellera.org/news/press-releases/427-accellera-approves-clock-and-reset-domain-crossing-standard-1-0-for-release>
- Portable Stimulus Standard PSS 3.0: <https://blogs.sw.siemens.com/verificationhorizons/2024/10/09/celebrating-the-approval-of-portable-test-and-stimulus-standard-pss-3-0/>
- HWMCC 2024: <https://hwmcc.github.io/2024/>
- FMCAD: <https://www.fmcad.org/>
- DVCon: <https://dvcon.org/>
- STELLAR (2026): <https://arxiv.org/html/2601.19903>
- AssertLLM (ASP-DAC 2025): <https://dl.acm.org/doi/10.1145/3658617.3697756>
- FLAG (2025): <https://arxiv.org/pdf/2504.17226>
- LAAG-RV: <https://arxiv.org/html/2409.15281v1>
- CoverAssert (ETS 2026): <https://arxiv.org/html/2602.15388>
- HT-PGFV Hardware Trojan Detection: <https://www.mdpi.com/2079-9292/13/21/4286>
- RISC-V Processor Verification Survey (2025): <https://link.springer.com/article/10.1007/s10836-025-06169-3>
- HIVE Hardware-Firmware Co-Verification: <https://arxiv.org/html/2309.08002v2>
- Scalable Modular Formal Verification (2025): <https://hal.science/hal-05296391v1/document>
- Martin Kleppmann on AI and Formal Verification (December 2025): <https://martin.kleppmann.com/2025/12/08/ai-formal-verification.html>
- Running JasperGold on AWS: <https://aws.amazon.com/blogs/industries/running-cadence-jaspergold-formal-verification-on-aws-at-scale/>
