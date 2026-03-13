# Reactive Synthesis: Industry, Academia, and Mathematics Frontier

Date: 2026-03-13

## Question

What is the current state of reactive synthesis across industry, academia, and the mathematical frontier?

This note covers the problem itself, the tool ecosystem, industrial adoption, academic research directions, and frontier mathematics.

## Short Answer

Reactive synthesis is the problem of automatically constructing a correct-by-construction reactive system from a temporal logic specification.

The core idea is:

- you write a specification (typically in LTL or GR(1))
- a tool automatically produces a finite-state controller that satisfies it against all possible environment behaviors
- correctness is guaranteed by construction

The mathematical foundation is two-player infinite-duration game theory over omega-automata.

The current state is:

1. the theory is deep and mature
2. the academic tooling is active and competitive (SYNTCOMP)
3. industrial adoption is essentially zero
4. the frontier mathematics is moving toward quantitative games, hyperproperties, infinite-state synthesis, and connections to machine learning

For this repository, reactive synthesis solves a different problem than the one we are working on. We already have a controller and are verifying it. Synthesis would produce a controller from a spec.

## 1. What Reactive Synthesis Is

### 1.1 The problem

Instead of:

- design a controller by hand, then verify it

reactive synthesis asks:

- write a formal specification, then automatically generate a correct controller

The specification is typically in Linear Temporal Logic (LTL) or the GR(1) fragment. The output is usually a Mealy machine, Moore machine, or AIGER circuit.

### 1.2 Game-theoretic formulation

Synthesis is modeled as a two-player zero-sum game:

- **system**: the controller to be synthesized
- **environment**: an adversarial or nondeterministic external agent

The specification defines the winning condition. The synthesis algorithm asks:

1. **realizability**: does a winning strategy for the system exist?
2. **synthesis**: if yes, extract a finite-state winning strategy

### 1.3 Historical arc

- Church (1957/1963): posed the synthesis problem
- Buchi and Landweber (1969): solved it via automata on infinite words with non-elementary complexity
- Rabin (1972): solved the S1S satisfiability problem using tree automata
- Pnueli and Rosner (1989): reformulated for LTL and proved **2EXPTIME-completeness**
- Piterman, Pnueli, and Sa'ar (2006): introduced **GR(1) synthesis**, polynomial in state space size

### 1.4 The standard pipeline

1. translate LTL formula to a nondeterministic Buchi automaton (exponential blowup)
2. determinize to a deterministic parity automaton (another exponential blowup)
3. interpret the DPA as a parity game on a finite arena
4. solve the parity game to determine realizability and extract a winning strategy

The two exponential blowups yield the 2EXPTIME complexity.

## 2. Academic State

### 2.1 Key research groups

- **Bernd Finkbeiner's Reactive Systems Group (CISPA, Saarland)**: synthesis from hyperproperties, Temporal Stream Logic (TSL), bounded synthesis, compositional synthesis. Develops BoSy and Issy.
- **Jan Kretinsky, Tobias Meggendorfer (TU Munich / Masaryk University)**: Strix development, on-the-fly LTL-to-DPA translation, parity game solving.
- **Roderick Bloem's group (TU Graz)**: bounded synthesis, SYNTCOMP organization.
- **Swen Jacobs (CISPA)**: lazy synthesis, safety specifications, SafetySynth.
- **Orna Kupferman (Hebrew University)**: automata-theoretic approaches, safraless constructions, complexity.
- **Shaull Almagor, Guy Avni**: quantitative synthesis, mean-payoff games.
- **Maoz et al. (Tel Aviv University)**: Spectra language for practical GR(1) synthesis. ICSE 2023 end-to-end case study.
- **Rudiger Ehlers (Clausthal)**: Slugs GR(1) synthesis tool, synthesis for robotics.
- **Philipp Heim (CISPA)**: Issy tool for infinite-state reactive synthesis (CAV 2025).

### 2.2 Key conferences

- **CAV** (Computer Aided Verification): premier venue for synthesis tool papers
- **TACAS** (Tools and Algorithms for the Construction and Analysis of Systems)
- **FMCAD** (Formal Methods in Computer-Aided Design)
- **LICS** (Logic in Computer Science): theoretical complexity results
- **SYNT Workshop** (co-located with CAV): dedicated synthesis workshop
- **HSCC** (Hybrid Systems: Computation and Control): cyber-physical synthesis

### 2.3 SYNTCOMP

The annual Reactive Synthesis Competition, running since 2014.

Tracks:

- LTL realizability and synthesis (TLSF format)
- parity game realizability (extended HOA format)
- LTLf realizability (finite-trace LTL, added recently)

SYNTCOMP 2025 results:

- Strix won the LTL sequential realizability track (424/434 benchmarks)
- simpleBDDSolver won the parity game track (186/274)
- SYNTCOMP 2026 has already issued its call for benchmarks and solvers

### 2.4 Recent research directions

- **Synthesis from richer logics**: HyperLTL synthesis (decidable for restricted fragments, undecidable for full HyperLTL — Finkbeiner et al., CAV 2018/2019). TSL separating control and data.
- **Bounded synthesis** (Finkbeiner and Schewe, 2013): incrementally searches for implementations of increasing size, encoding into SAT/QBF/DQBF.
- **Compositional synthesis** (Finkbeiner and Passing, ATVA 2021): decomposes multi-process synthesis into individual problems connected by assume-guarantee certificates.
- **LTLf synthesis**: synthesis over finite traces, relevant for planning and AI agents.
- **Fully Generalized Reactivity(1)** (2024): extending GR(1) to handle more expressive fairness conditions while retaining efficient synthesis.
- **Infinite-state reactive synthesis**: the Issy tool (CAV 2025) extends synthesis to infinite-state games combined with temporal formulas.

## 3. Tools

| Tool | Input | Output | Approach | Status |
| --- | --- | --- | --- | --- |
| Strix | LTL (TLSF) | Mealy machines, AIGER | on-the-fly LTL-to-DPA + strategy iteration | active, dominant SYNTCOMP winner 2018-2025 |
| BoSy | LTL (TLSF) | AIGER | bounded synthesis via SAT/QBF/DQBF | active |
| ltlsynt | LTL | Mealy machines, AIGER | LTL-to-parity-automaton via Spot + Zielonka's algorithm | active, part of Spot toolchain |
| Slugs | GR(1) specs | finite-state controllers | BDD-based GR(1) fixpoint computation | maintained, used in robotics |
| Spectra | Spectra language (GR(1)) | Java controllers, robot controllers | GR(1) synthesis with BDD optimizations | active, Eclipse-based IDE |
| Acacia-bonsai | LTL | AIGER | antichain-based safety game reduction | successor to Acacia+ |
| SafetySynth | safety specs (AIGER) | controllers | symbolic backward fixpoint using CUDD BDDs | maintained |
| Issy | Issy format, TSL-MT | infinite-state controllers | infinite-state game solving + temporal formulas | new (CAV 2025) |
| simpleBDDSolver | parity games | strategies | BDD-based symbolic parity game solving | active, won SYNTCOMP parity 2025 |

Output formats: most tools produce Mealy/Moore machines or AIGER circuits (And-Inverter Graphs used in hardware verification).

## 4. Industry Adoption

### 4.1 The honest assessment

Reactive synthesis is barely used in industry.

### 4.2 Barriers to adoption

1. **Specification difficulty**: writing correct, complete LTL/GR(1) specifications is fundamentally different from programming. The ICSE 2023 end-to-end study (Ma'ayan et al.) found that specification writing was the dominant difficulty even in a controlled academic setting.

2. **Scalability**: full LTL synthesis is 2EXPTIME-complete. Even GR(1) synthesis, polynomial in state space size, suffers BDD blowups on realistic designs. Synthesis tools handle tens to low hundreds of state bits. Industrial designs have thousands.

3. **Output format gap**: synthesis tools produce Mealy machines or AIGER circuits, not SystemVerilog or VHDL. Translation to industrial HDL is an additional engineering step.

4. **Debugging opacity**: when a specification is unrealizable, explaining why to an engineer is extremely difficult. Counterexample generation for unrealizability is an active research problem.

5. **Integration with existing workflows**: industrial hardware design relies on EDA tool flows (Synopsys, Cadence, Siemens). Synthesis tools exist entirely outside this ecosystem.

6. **Verification is more mature and trusted**: industry already struggles to adopt model checking. Synthesis is a further leap.

### 4.3 Where it has been used (limited)

- **Robotics**: GR(1) synthesis via Slugs/Spectra for high-level discrete mission planning. Most successful application domain.
- **ARM**: some exploration of synthesis for bus protocol controllers (research stage).
- **Intel**: research collaborations on synthesis for cache coherence protocols (not production).
- **IBM**: early involvement with the RATSY tool for assume-guarantee synthesis.

### 4.4 Commercial tools

There are no commercially available reactive synthesis tools. Some formal verification suites (e.g., Cadence JasperGold) have synthesis-adjacent features, but these are not reactive synthesis in the academic sense.

## 5. Mathematics Frontier

### 5.1 Automata theory

The automata-theoretic approach (Vardi and Wolper, 1986) remains the dominant paradigm.

Key automaton types:

- **Buchi automata**: accept if some accepting state is visited infinitely often. Nondeterministic Buchi cannot always be determinized to deterministic Buchi.
- **Parity automata**: generalize Buchi/co-Buchi/Rabin/Streett. Each state has a priority; acceptance requires the minimum priority seen infinitely often to be even.
- **Rabin/Streett automata**: alternative acceptance conditions equivalent to parity conditions with different algorithmic properties.

### 5.2 Game theory

Reactive synthesis reduces to solving two-player zero-sum games on finite graphs.

Qualitative games:

- safety, reachability, Buchi, parity, Rabin, Streett, Muller winning conditions
- the key algorithmic question is computing the winning region

Quantitative games (frontier direction):

- **mean-payoff games**: maximize or minimize long-run average of weights
- **energy games**: maintain energy level above zero
- **discounted-sum games**: weighted with a discount factor
- **multi-dimensional quantitative games**: combining multiple objectives simultaneously (Chatterjee, Doyen, Henzinger, Raskin, 2012)
- **stochastic games**: games against probabilistic environments

### 5.3 Quasipolynomial parity game solving

The breakthrough: Calude, Jain, Khoussainov, Li, and Stephan (STOC 2017) proved parity games can be solved in **quasipolynomial time** — O(n^{O(log n)}) — breaking a decades-long barrier where best known algorithms were mildly exponential.

Parity games were known to be in NP ∩ co-NP (Emerson and Jutla, 1991), suggesting polynomial-time solvability, but no polynomial algorithm was known.

Follow-up work:

- Jurdzinski and Lazic (2017): succinct progress measures in quasipolynomial time
- Lehtinen (2018): register games providing clean characterization of quasipolynomial separating automata
- Parys (2019): modified Zielonka's recursive algorithm to run in quasipolynomial time
- Czerwinski et al. (2019): unified several quasipolynomial algorithms through a common framework

Practical impact: despite the theoretical breakthrough, practical solvers still primarily use Zielonka's exponential-time algorithm or strategy iteration, because quasipolynomial algorithms have large constants. Strix uses explicit-state strategy iteration.

Open problem: whether parity games are solvable in **polynomial time** remains open.

### 5.4 Fixpoint theory

Parity games and mu-calculus model checking are intimately connected via fixpoint theory:

- the modal mu-calculus (Kozen, 1983) expresses properties as nested least and greatest fixpoints
- Emerson and Jutla (1991) showed solving parity games is equivalent to mu-calculus model checking
- Zielonka's algorithm (1998) solves parity games by recursively computing fixpoints
- universal algorithms for parity games can be adapted to compute nested fixpoints over arbitrary finite complete lattices (Hausmann and Schroder, LICS 2022)

### 5.5 Synthesis beyond LTL

- **Hyperproperties (HyperLTL)**: synthesis of systems free of information leaks, symmetric, or fault-tolerant. Full HyperLTL synthesis is undecidable, but restricted fragments are decidable (Finkbeiner et al., CAV 2018/2019).
- **TSL (Temporal Stream Logic)**: separates control and data in temporal specifications (Finkbeiner et al., CAV 2019). Extended to TSL modulo theories (FoSSaCS 2022). Used to synthesize an Android music player and an autonomous vehicle controller.
- **Probabilistic environments**: synthesis in MDPs or stochastic games where the specification must hold with probability 1 or above a threshold.
- **Partial information / imperfect information games**: the environment has information the system lacks. Generally undecidable. Decidable for specific information architectures.

### 5.6 Distributed synthesis

Pnueli and Rosner (1990) proved that distributed synthesis (synthesizing multiple interacting processes from a global specification) is **undecidable** in general.

Decidable cases and workarounds:

- **pipeline architectures**: linear chains with unidirectional communication (the only general decidable case)
- **compositional synthesis** (Finkbeiner and Passing, 2021): avoids full distributed synthesis by searching for assume-guarantee certificates
- **bounded synthesis for distributed systems**: encodes the problem as DQBF and searches for solutions up to a bounded size

### 5.7 Synthesis for cyber-physical / hybrid systems

- **STL synthesis**: Raman and Donze (HSCC 2015) developed synthesis from Signal Temporal Logic, encoding STL as mixed integer-linear constraints.
- **PESSOA 2.0**: synthesizes controllers for cyber-physical systems using discrete abstractions of continuous dynamics.
- **Abstraction-based synthesis**: the dominant approach. Abstract continuous dynamics into a finite-state model, synthesize a discrete controller, and refine via CEGAR loops.

### 5.8 Connections to machine learning

- **Neural-guided synthesis (2025)**: pipelines that transform LTL specifications into verified deep neural networks via reinforcement learning with post-training formal verification.
- **Neuro-symbolic approaches**: neural networks guide the search through a space of programs constrained by formal grammars or logical specifications.
- **The gap**: ML provides probabilistic guarantees while synthesis demands absolute correctness. The most promising direction is using ML to guide the search in exact synthesis algorithms rather than replacing them.

## 6. Maturity Map

| Area | Current status | Why it matters |
| --- | --- | --- |
| LTL synthesis | mature theory, active tooling | the standard formulation since Pnueli and Rosner 1989 |
| GR(1) synthesis | mature and practical | polynomial complexity, most tractable fragment |
| SYNTCOMP ecosystem | active competition since 2014 | drives tool improvement and benchmarking |
| Quasipolynomial parity games | theoretical breakthrough, limited practical impact | narrows the gap toward polynomial solvability |
| Bounded synthesis | active | SAT/QBF-based, avoids full determinization |
| Compositional synthesis | active frontier | makes multi-process synthesis practical |
| HyperLTL synthesis | frontier | synthesis with information-flow and symmetry guarantees |
| TSL synthesis | frontier | separates control from data |
| Distributed synthesis | fundamentally hard (undecidable in general) | practically important but theoretically blocked |
| Infinite-state synthesis | frontier (Issy, CAV 2025) | extends synthesis beyond finite-state games |
| CPS/hybrid synthesis | frontier but promising | bridges discrete synthesis and continuous dynamics |
| ML-guided synthesis | early frontier | potential to scale synthesis via learned heuristics |
| Industrial adoption | essentially zero | specification difficulty and scalability are the main blockers |

## 7. What This Means for This Repository

This repository is currently about:

- a small RTL controller designed by hand
- Lean proofs of its correctness
- bounded traces and temporal properties
- functional equivalence between fixed-point and spec-level models

That means reactive synthesis solves a different problem than the one we are working on.

### 7.1 Why synthesis does not help us directly

1. **Our controller already exists.** We are verifying, not synthesizing.
2. **Scale mismatch.** Our controller is small enough that manual design plus Lean proofs is entirely tractable.
3. **Datapath is the hard part.** Synthesis operates on Boolean/finite-state control logic. It has nothing to say about fixed-point arithmetic, MAC operations, or ReLU correctness, which is where our Lean proofs have their substance.
4. **Output format gap.** Synthesis tools produce Mealy machines or AIGER circuits, not SystemVerilog.
5. **No Lean integration.** There is no pipeline connecting reactive synthesis tools to Lean proofs.

### 7.2 Where the ideas are intellectually relevant

- Our Lean proofs already use the same mathematical foundations: invariants, traces, bounded temporal operators, and fixpoints are the verification side of the same game-theoretic coin.
- If we were designing the controller from scratch, we could in theory specify its behavior in GR(1) and synthesize it. But this would produce a black-box Mealy machine, not readable SystemVerilog.
- For future, more complex controllers, synthesis could help generate initial designs that are correct by construction. No existing toolchain supports this end-to-end with Lean.

### 7.3 Recommendation

Continue with manual RTL design plus Lean verification. It is more practical, more transparent, and better suited to our project's scale.

If a future version of this project involves designing a new controller from a temporal specification, GR(1) synthesis via Slugs or Spectra would be the most practical entry point.

## Sources

- Church, *Application of recursive arithmetic to the problem of circuit synthesis* (1957)
- Buchi and Landweber, *Solving sequential conditions by finite-state strategies* (1969)
- Pnueli and Rosner, *On the synthesis of a reactive module*: <https://dl.acm.org/doi/10.1145/75277.75293> (1989)
- Pnueli and Rosner, *Distributed reactive systems are hard to synthesize* (1990)
- Piterman, Pnueli, and Sa'ar, *Synthesis of Reactive(1) Designs*: <https://link.springer.com/chapter/10.1007/11609773_24> (2006)
- Calude, Jain, Khoussainov, Li, and Stephan, *Deciding Parity Games in Quasipolynomial Time*: <https://dl.acm.org/doi/10.1145/3055399.3055409> (2017)
- Jurdzinski and Lazic, *Succinct progress measures for solving parity games*: <https://link.springer.com/article/10.1007/s10009-019-00509-3> (2017)
- Parys, *Parity Games: Zielonka's Algorithm in Quasi-Polynomial Time*: <https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.MFCS.2019.10> (2019)
- Finkbeiner and Schewe, *Bounded synthesis* (2013)
- Finkbeiner et al., *Synthesizing Reactive Systems from Hyperproperties*: <https://link.springer.com/chapter/10.1007/978-3-319-96145-3_16> (2018)
- Finkbeiner, Klein, Piskac, and Santolucito, *Temporal Stream Logic: Synthesis Beyond the Bools*: <https://link.springer.com/chapter/10.1007/978-3-030-25540-4_35> (2019)
- Finkbeiner and Passing, *Compositional Synthesis of Modular Systems*: <https://link.springer.com/chapter/10.1007/978-3-030-88885-5_20> (2021)
- Ma'ayan et al., *Using Reactive Synthesis: An End-to-End Exploratory Case Study*: <https://smlab.cs.tau.ac.il/syntech/exploratory/exploratory-icse23.pdf> (2023)
- Heim et al., *Issy: A Comprehensive Tool for Infinite-State Reactive Synthesis*: <https://link.springer.com/chapter/10.1007/978-3-031-98685-7_14> (2025)
- Meyer, Sickert, and Luttenberger, *Strix: Explicit Reactive Synthesis Strikes Back!*: <https://link.springer.com/chapter/10.1007/978-3-319-96145-3_31> (2018)
- Faymonville et al., *BoSy: An Experimentation Framework for Bounded Synthesis*: <https://arxiv.org/abs/1803.09566> (2018)
- Michaud and Colange, *Dissecting ltlsynt*: <https://link.springer.com/article/10.1007/s10703-022-00407-6> (2022)
- Ehlers and Raman, *Slugs: Extensible GR(1) Synthesis*: <https://link.springer.com/chapter/10.1007/978-3-319-41540-6_18> (2016)
- SYNTCOMP: <https://www.syntcomp.org/>
- SYNTCOMP 2025 results: <https://www.syntcomp.org/syntcomp-2025-results/>
- Strix: <https://strix.model.in.tum.de/>
- Spot / ltlsynt: <https://spot.lre.epita.fr/ltlsynt.html>
- Spectra / SYNTECH: <https://smlab.cs.tau.ac.il/syntech/>
- Raman and Donze, *Reactive Synthesis from Signal Temporal Logic Specifications*: <https://dl.acm.org/doi/10.1145/2728606.2728628> (2015)
- Chatterjee, Doyen, Henzinger, and Raskin, *Strategy synthesis for multi-dimensional quantitative objectives*: <https://link.springer.com/article/10.1007/s00236-013-0182-6> (2012)
- Hausmann and Schroder, *Universal algorithms for parity games and nested fixpoints*: <https://link.springer.com/chapter/10.1007/978-3-031-22337-2_12> (2022)
