# SMT Tools, Industry & Ecosystem Research

## 1. Major SMT Solvers

### Z3 (Microsoft Research)

- Version: 4.16.0 (February 2026)
- License: MIT
- Strengths: Broadest theory support (bitvectors, arrays, floating-point, strings, integers, reals, datatypes, sequences, finite sets, separation logic, finite fields, uninterpreted functions). Dominant general-purpose solver. Won every category in the single-query track at SMT-COMP 2024.
- Backing: Microsoft Research, RiSE group. 2019 Herbrand Award, 2015 ACM SIGPLAN Software Award, 2018 ETAPS Test of Time Award.
- Maintenance: Very active, multiple releases per quarter.

### cvc5 (Stanford / Iowa)

- Version: 1.3.3 (February 2026)
- License: BSD 3-Clause
- Strengths: Strongest proof-producing solver (CPC and Alethe formats). Excellent for quantified reasoning, strings, datatypes. Key solver for proof-assistant integration (Lean, Isabelle).
- Backing: Stanford (Centaur, Center for Blockchain Research, Agile Hardware Center) and University of Iowa. NSF POSE Phase II grant for open-source ecosystem. Additional funding from DARPA, AFOSR, Amazon, Intel, Google, Meta, Certora.
- Maintenance: Very active. Successor to CVC4.

### Bitwuzla (Stanford / JKU Linz)

- Version: 0.8.2 (August 2025)
- License: MIT
- Strengths: State-of-the-art for fixed-size bitvectors (QF_BV), floating-point, arrays, and UFs. Won 26/56 division awards at SMT-COMP 2023. Distinguished paper at CAV 2023. Features an abstraction module for BV arithmetic on wide operands (>= 33 bits).
- Backing: Aina Niemetz and Mathias Preiner (Stanford).
- Maintenance: Active. Successor to Boolector (now deprecated).

### Yices 2 (SRI International)

- Version: 2.7.0 (July 2025)
- License: GPLv3
- Strengths: Efficient for quantifier-free theories, especially linear arithmetic and bitvectors. Strong incremental solving.
- Backing: SRI International Computer Science Laboratory.
- Maintenance: Active.

### Boolector (JKU Linz) -- Deprecated

- Final version: 3.2.3
- Status: Superseded by Bitwuzla. No longer maintained.

### Other Notable

- **STP**: QF_BV and arrays. Used in KLEE symbolic execution.
- **MathSAT 5** (FBK, Italy): Arithmetic theories and interpolation.
- **veriT** (Inria/LORIA): Proof production in Alethe format. Integrated into Isabelle/Sledgehammer.

## 2. SMT-LIB Standard

- Current version: SMT-LIB v2.7 (reference updated February 2025)
- Governance: Clark Barrett, Pascal Fontaine, Cesare Tinelli

### Theories Relevant to Hardware Verification

| Logic | Description | Hardware relevance |
|---|---|---|
| QF_BV | Quantifier-free fixed-size bitvectors | Primary logic for RTL verification. Signed/unsigned arithmetic, bitwise ops, shifts, extract, concat. |
| QF_ABV | QF bitvectors + arrays | Memory: register files, RAMs, FIFOs |
| QF_AUFBV | QF bitvectors + arrays + UFs | Memory + abstracted functional units |
| BV | Quantified bitvectors | Parameterized / bit-width-independent proofs |
| QF_UFBV | QF bitvectors + UFs | Module-level abstraction |
| QF_FP | Quantifier-free floating-point | FPU verification |
| QF_ABVFPLRA | Combined BV + FP + LRA + arrays | Mixed-domain hardware |

## 3. SMT in Hardware/RTL Verification

### Techniques

**Bounded model checking (BMC)**: Unroll FSM for k steps, encode transition relation + negated property as QF_BV formula. Satisfying assignment = counterexample. Word-level SMT avoids exponential bit-blasting blowup for wide datapaths. Dominant technique for shallow bug finding.

**Equivalence checking**: Verify two circuit representations produce identical outputs. Miter circuit encoded as QF_BV satisfiability.

**Property verification**: SVA/LTL properties checked via k-induction (BMC + inductive step) or full model checking with SMT backends.

### Commercial Tools

- **Cadence JasperGold**: Industry-leading formal platform. Bounded and unbounded proofs via k-induction. Multiple verification "Apps." Scalable on AWS.
- **Synopsys VC Formal**: Formal platform integrated with riscv-formal framework.
- **Siemens Questa Formal** (formerly Mentor): Formal verification suite.
- **OneSpin 360 DV** (now Siemens): Operational SVA-based formal verification.

All use SAT/SMT internally (typically proprietary engines alongside open-source solver technology).

### Open-Source Flows

- **SymbiYosys (sby)**: Front-end for Yosys-based formal. Bounded/unbounded verification, cover, liveness. Uses `write_smt2` to produce SMT-LIB2, invokes Z3, Yices, CVC4, or cvc5.
- **Yosys-SMTBMC**: Core engine behind SymbiYosys. Verilog/SV to SMT-LIB2, BMC and k-induction.
- **EBMC 5.9** (February 2026): CPROVER ecosystem. Verilog 2005, SV 2017, ISCAS89. Properties in LTL or SVA. BMC and k-induction.
- **riscv-formal**: Instruction-level formal for RISC-V. SymbiYosys and VC Formal backends.
- **OpenTitan**: Google's open-source silicon root-of-trust. Uses JasperGold for hardware module verification.

## 4. SMT + Proof Assistant Integration

### Lean 4

**lean-smt** (TACAS/CAV 2025):
- Architecture: preprocess Lean goal, translate to SMT-LIB, call cvc5 via FFI, receive CPC proof, reconstruct as native Lean proof checked by kernel.
- Performance: 15,271 / 21,595 benchmarks verified (71% reconstruction).
- Available on Lean Reservoir.

**querySMT** (arXiv 2601.14495, January 2026):
- Uses lean-auto to export to cvc5, instruments cvc5 to report preprocessing and theory reasoning as "hints," translates hints into self-contained Lean proof using `grind` + `duper`.
- Key advantage: final proof is kernel-checkable without external solver dependency.

**lean-auto** (CAV 2025):
- Lean 4 to automated prover interface. Monomorphization, universe normalization, HOL translation. Combined with Duper: 36.6% of benchmarks solved.

**Duper**: Higher-order superposition prover in Lean 4. Proof reconstruction backend for lean-smt and querySMT.

**Aesop**: White-box best-first proof search. Rule-based (like Isabelle's `auto`). Not SMT-based but complementary.

### Coq

- **SMTCoq**: Checks proof witnesses from veriT and CVC4. Formally verified checker within Coq.
- **CoqHammer**: First-order ATP hammer with proof reconstruction.
- **CoqQFBV**: Certified SMT solver for QF_BV, implemented and verified entirely in Coq. Directly relevant to hardware verification.

### Isabelle/HOL

- **Sledgehammer**: Most mature proof-assistant/ATP integration. Dispatches to Z3, cvc5, veriT, E, SPASS, Vampire. Uses Alethe for SMT proof reconstruction.
- **SMT method**: Direct SMT solver integration.
- **ITP 2025 milestone**: cvc5 now produces Alethe proofs for Isabelle reconstruction (previously veriT only). Cut reconstruction failures by 50%, reduced checking time by 13%.
- **Carcara**: Independent Rust proof checker/elaborator for Alethe. Supports both Isabelle and Coq pipelines.

### Common Architecture

1. Export goal to SMT-LIB
2. Solve with external solver (cvc5, Z3, veriT)
3. Receive proof certificate (Alethe, CPC, or native)
4. Reconstruct/replay within proof assistant kernel
5. SMT solver is NOT in the trusted computing base

Note: Z3's proof certificates are coarse-grained, making reconstruction harder than cvc5/veriT Alethe proofs.

## 5. SMT for Fixed-Point / Bounded Integer Arithmetic

### QF_BV for Fixed-Point

Fixed-point numbers = bitvectors with implicit binary point. All operations map directly:

- Addition/subtraction: `bvadd`/`bvsub` on aligned representations
- Multiplication: `bvmul` with width extension and truncation
- Rounding/truncation: `extract` and shift
- Sign extension: `sign_extend`

### Dedicated Fixed-Point Theory

Brillout, Kroening et al. (IJCAR 2020) formalized an SMT theory of fixed-point arithmetic:
- Semantics based on exact rational arithmetic
- Decision procedures encode into both bitvectors and reals
- Handles rounding modes and overflow explicitly
- Status: research-stage, not yet in mainstream solvers

### Overflow Checking

- Explicit overflow predicates: compute at extended width, assert fits in target
- Saturation arithmetic: encode clamp behavior, verify equivalence
- QF_BV naturally supports signed and unsigned overflow detection
- SMT-LIB discussions on native overflow operations are ongoing

### Quantifier-Free vs. Quantified

- **QF_BV**: Decidable (NP-complete). Standard for fixed-width. Solved via bit-blasting or word-level reasoning.
- **BV**: For parameterized proofs ("for all widths N >= 8, ..."). Generally undecidable, decidable fragments exist. Significantly harder.

### Application to Quantized Neural Network Verification

- ESBMC used to verify quantized NNs via SMT-based BMC (Cordeiro et al., 2021)
- 2025 work: "Formal Specification and SMT Verification of Quantized Neural Network for Autonomous Vehicles" (ScienceDirect) and ENAC formal verification paper
- Verification is PSPACE-hard
- Must account for quantization parameters, zero points, scale factors per operation
- Scalability ceiling: networks > few hundred neurons intractable for direct SMT encoding
- Practical approach: compositional and layer-by-layer verification

### Known Limitations

1. **Wide multiplication**: 16x16 or 32x32 bitvector multiplication produces hard SAT instances. Bitwuzla's abstraction module partially addresses this.
2. **MAC chain precision**: Tracking precision growth across many accumulations expands formula size linearly.
3. **No mainstream fixed-point theory**: Brillout et al. remains research-only.
4. **Full network scale**: Intractable. Layer/operator-level verification is practical.

## 6. Industry Trends & Ecosystem Health

### Funding

- Z3: Microsoft Research (continuous since ~2007). MIT licensed.
- cvc5: NSF POSE Phase II + DARPA + AFOSR + industry (Amazon, Intel, Google, Meta, Certora). BSD licensed.
- Bitwuzla: Stanford (Centaur). MIT licensed.
- Yices 2: SRI International (DoD/NASA). GPLv3.
- All four major solvers had multiple releases in 2025-2026.

### SMT-COMP Trends

- 2024 (19th edition, CAV): Z3 dominated single-query track (every category). Z3-alpha also strong.
- 2023: Bitwuzla dominated BV/FP (26/56 divisions).
- 2025: Took place; results at smt-comp.github.io/2025/.
- Pattern: Z3 and cvc5 compete for breadth, Bitwuzla for BV/FP depth.

### Industrial Adoption

- **AWS**: Z3 at massive scale. Authorization engine (1B calls/sec) in Dafny + Z3. Zelkova (S3 policy analysis) uses Z3/CVC4/CVC5 (tens of millions of calls/day). Cedar language uses Dafny + Z3.
- **Hardware**: JasperGold (Cadence), VC Formal (Synopsys), Questa Formal (Siemens) are dominant. Formal verification adoption growing for security-critical and safety-critical designs.
- **RISC-V**: riscv-formal and OpenTitan driving open-source formal adoption.

### Adoption Barriers (2024 survey, 130 experts)

- 71.5%: "Engineers lack proper training"
- 66.9%: "Academic tools not professionally maintained"
- 66.9%: "Not integrated in industrial design lifecycle"
- 63.8%: "Steep learning curve"

### Emerging Trends

- **LLM + formal verification**: AI-assisted spec generation and proof automation (Dafny-annotator at AWS, LeanCopilot).
- **Proof-producing solvers**: cvc5 CPC/Alethe proofs + lean-smt/querySMT = SMT results trusted in proof assistants. Most significant technical trend.
- **Cloud-scale formal methods**: AWS demonstrates SMT-based verification at production scale.
- **Hardware formal growth**: Semiconductor Engineering reports growing value driven by design complexity and security requirements.

## 7. Relevance to This Project

This project formalizes a 4-8-1 quantized MLP inference chip. The fixed-point arithmetic uses int8 inputs, int8 weights, int16 hidden products, int24 output products, and int32 accumulators.

### Where SMT fits

| Task | Approach | Tool |
|---|---|---|
| RTL property checking (SVA) | BMC + k-induction over QF_BV | SymbiYosys + Z3/Yices |
| RTL equivalence to contract | Miter + QF_BV | SymbiYosys or EBMC |
| Overflow absence (fixed-point chain) | QF_BV with explicit width predicates | Z3 or Bitwuzla directly |
| Lean proof automation | SMT tactic for arithmetic subgoals | lean-smt or querySMT + cvc5 |
| Full-stack bridge (Lean + RTL) | Export SMT-LIB from SymbiYosys, check in Lean | Experimental |

### Recommended additions to this stack

1. **SymbiYosys**: Add SVA assertions to RTL (`rtl/results/canonical/sv/*.sv`), run BMC as CI complement to Lean proofs. Catches shallow bugs fast.
2. **lean-smt or querySMT**: Use for arithmetic lemmas in `Defs/SpecCore.lean` bounds proofs (e.g., `int8_mul_int8_bounds`, `hiddenSpecAt8_*_bounds`). Could replace manual `by_cases` + `omega` proofs with automated SMT calls.
3. **Bitwuzla**: Best choice if standalone QF_BV queries are needed for overflow analysis of the MAC datapath.

### What SMT does NOT replace

- The Lean formalization's value is in the unbounded, machine-checked, compositional proof. SMT provides bounded verification and automation but cannot replace the full correctness argument.
- SMT is strongest as a complement: fast bug-finding (BMC) and proof automation (tactics) alongside the Lean proof backbone.

## References

- Z3 releases: github.com/z3prover/z3/releases
- cvc5 releases: github.com/cvc5/cvc5/releases
- Bitwuzla: github.com/bitwuzla/bitwuzla
- Yices 2: yices.csl.sri.com
- SMT-LIB v2.7: smt-lib.org/papers/smt-lib-reference-v2.7-r2025-02-05.pdf
- SMT-COMP 2025: smt-comp.github.io/2025
- SymbiYosys: github.com/YosysHQ/sby
- EBMC: cprover.org/ebmc
- lean-smt: arXiv 2505.15796 (TACAS/CAV 2025)
- querySMT: arXiv 2601.14495 (January 2026)
- lean-auto: Springer CAV 2025
- SMTCoq: smtcoq.github.io
- Alethe in Isabelle: LIPIcs.ITP.2025.26
- Carcara: Springer 2023
- Fixed-point SMT theory: Brillout et al., IJCAR 2020
- Quantized NN SMT verification: arXiv 2106.05997
- ENAC formal verification: hal-05127878v1
- NSF POSE cvc5: nsf.elsevierpure.com
- AWS formal methods: CACM Systems Correctness
- Formal methods survey: ACM 10.1145/3689374
