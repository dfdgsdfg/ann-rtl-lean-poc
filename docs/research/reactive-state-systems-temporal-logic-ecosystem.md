# Reactive State Systems, Temporal Logic, and the Prover/Solver Ecosystem

Date: 2026-03-12

## Question

What is the current conceptual and tooling landscape for:

- reactive state systems
- temporal logic
- the related mathematics behind them
- the theorem prover, model checker, and solver ecosystem around them

And, given this repository, what is the practical stack to use?

## Short Answer

Reactive systems are best modeled as transition systems that produce traces.

The mathematics that matters most is not exotic:

- sets and relations
- inductive and coinductive definitions
- traces and streams
- invariants and reachability
- safety, liveness, and fairness
- simulation, bisimulation, and refinement
- fixed points behind temporal reasoning

Temporal logic is not one thing.

- `LTL` is good for trace properties.
- `CTL` and `CTL*` are good when branching structure matters directly.
- `TLA+` is especially good for action-based system specifications and refinement.
- `LTLf` is good when the property is really about finite executions.
- the modal `μ`-calculus is the fixed-point umbrella behind much of the theory.

The tool ecosystem is now clearly split into layers:

1. interactive proof assistants
2. model checkers
3. SMT/SAT backends
4. automata and synthesis tooling
5. hardware-specific formal front ends

For this repository, the practical recommendation is:

- keep Lean as the semantic and proof authority
- define a small project-local finite-trace layer for RTL timing properties
- use a hardware model checker such as `SBY`/Yosys for fast bug-finding and counterexamples
- optionally use `nuXmv` or `TLA+` tooling only if the project grows into richer control/protocol reasoning

That is the current best fit.

## 1. Reactive State Systems: The Mathematical Backbone

### 1.1 Core object

A reactive state system is usually modeled as some variant of:

- a set of states `S`
- a set of initial states `I`
- a transition relation `R ⊆ S × S`
- sometimes a labeling function `L` from states to atomic propositions

If the system is input-driven, it is often cleaner to model:

- `step : Input -> State -> State`, or
- `R ⊆ S × Input × S`

For this repository, the second style is often unnecessary if the control inputs are already sampled into the machine state. Then the simpler object is:

- `step : State -> State`
- `run : Nat -> State -> State`

### 1.2 Traces

The semantic object that temporal logic talks about is usually a trace:

- finite trace for bounded executions
- infinite trace for ongoing reactive behavior

A trace can be modeled as:

- `Nat -> State` for infinite discrete time
- `Fin (n+1) -> State` or a list/array for bounded runs

This matters because many properties that look "state-based" are really trace properties.

Examples:

- "eventually `done`"
- "`busy` remains high until `done`"
- "once `done`, output stays stable"

These are not just predicates on one state. They quantify over positions on a trace.

### 1.3 Safety, liveness, fairness

This is still the most useful conceptual split.

- Safety: something bad never happens.
- Liveness: something good eventually happens.
- Fairness: the environment or scheduler is not allowed to starve enabled progress forever.

In RTL-style finite transactions, many useful claims are bounded liveness claims:

- accepted start implies `done` within `N` cycles

That is simpler than general liveness over infinite behavior.

### 1.4 Invariants and inductive invariants

An invariant is a predicate true in all reachable states.

An inductive invariant is the proof-friendly version:

- true initially
- preserved by every transition

This is the bridge between theorem proving and model checking:

- proof assistants use inductive invariants explicitly
- model checkers search for them, approximate them, or prove them automatically

### 1.5 Simulation, bisimulation, and refinement

These are the mathematically clean ways to relate layers of abstraction.

- simulation: implementation matches the abstract behavior in one direction
- bisimulation: both systems match each other step-for-step up to observation
- refinement: concrete system preserves the guarantees of the abstract one

For hardware verification, refinement is usually the practical notion:

- RTL machine refines a higher-level functional or transactional model

### 1.6 Fixed points

A lot of temporal logic and verification algorithmics reduces to fixed points.

- reachability is a least fixed point
- invariance is often expressed through greatest fixed-point style reasoning
- the modal `μ`-calculus makes this explicit

This is why induction, coinduction, and fixpoint engines keep reappearing across the ecosystem.

## 2. Temporal Logic Map

### 2.1 LTL

`LTL` is the standard trace logic over linear executions.

Main operators:

- `X` next
- `F` eventually
- `G` always
- `U` until

Best fit:

- safety/liveness over traces
- protocol properties
- hardware properties over ongoing runs

Strength:

- direct and readable for single-trace behavior

Limitation:

- no explicit path quantifiers

### 2.2 CTL and CTL*

`CTL` and `CTL*` reason over branching futures, not just one path.

Best fit:

- symbolic model checking
- properties that inherently quantify over possible next behaviors

Rule of thumb:

- use these when the tree of futures matters directly
- do not reach for them if your intended properties are just over one execution trace

### 2.3 TLA+

`TLA+` is best understood as action-based temporal specification.

Its common canonical shape is:

- `Init /\ [][Next]_vars`

Strengths:

- excellent for concurrent and distributed system specs
- explicit action style
- strong refinement story
- natural use of stuttering

Important caveat:

- `TLA+` is a specification language first, not a bit-accurate hardware proof system

### 2.4 LTLf

`LTLf` is LTL interpreted over finite traces.

This is often the cleanest logic for:

- bounded workflows
- terminating transactions
- tests and monitorable obligations

For this repository, many timing claims are closer to `LTLf` than to full infinite-trace `LTL`.

### 2.5 Real-time variants

`MTL` and `STL` add timing constraints over dense or metric time.

These are important for:

- cyber-physical systems
- timed control
- analog or mixed-signal timing claims

For the current repository, they are probably not first-order needs.

Cycle-bounded discrete-time reasoning is enough for the main RTL story.

### 2.6 Modal μ-calculus

This is the theory-heavy logic in the background.

Why it matters:

- it explains why fixed-point algorithms are central
- it connects temporal logic, automata, and symbolic verification

Why it may not matter operationally:

- many engineers never write a `μ`-calculus formula directly
- they still use tools whose algorithms are shaped by it

## 3. Tool Ecosystem by Layer

### 3.1 Interactive proof assistants

#### Lean 4

Current position:

- strong as a programmable theorem prover
- strong for project-local semantics and proofs
- strong when the target artifact is a machine-checked theorem over a custom model

Weak point for this topic:

- there is still no clearly mature community-standard Lean 4 temporal-logic library for RTL-style work

That matches the existing repo note in [lean-temopral-logic.md](/Users/dididi/workspaces/ann-rtl-lena/specs/formalize/research/lean-temopral-logic.md).

Practical implication:

- Lean is a very good place to define `State`, `step`, `run`, bounded traces, and timing lemmas
- Lean is not the place to wait for a ready-made industrial temporal-logic ecosystem

#### Rocq Prover

Current position:

- mature industrial-strength interactive prover
- broad verification history across software, hardware, and mathematics
- supports extraction and strong proof engineering

Strength:

- very rich ecosystem and long verification lineage

Tradeoff:

- for this repository, switching from Lean to Rocq would not be justified unless there were a missing Rocq-specific library that materially changes the proof burden

#### Isabelle/HOL

Current position:

- still one of the strongest mature environments for logic-heavy verification
- very good automation story via `Sledgehammer`
- strong counterexample support via `Nitpick`
- rich libraries and the Archive of Formal Proofs

Strength:

- very balanced interactive + automated workflow

Tradeoff:

- excellent if you are committing to Isabelle as the main prover
- not obviously worth introducing into this repository alongside Lean unless you are deliberately changing foundations

#### TLAPS

Current position:

- useful proof checker for `TLA+`
- good for hierarchical deductive proofs over TLA+ specifications

Important limitation:

- the current TLAPS home page still states that the current release does not perform temporal reasoning generally and is mainly suitable for safety proofs

Practical implication:

- TLAPS is useful for proving safety properties of TLA+ specs
- it is not a replacement for a full temporal proof ecosystem

### 3.2 Model checkers and spec analyzers

#### TLC

What it is:

- the classic explicit-state model checker for TLA+

Best fit:

- finite models
- design-stage debugging
- quick counterexamples

Strength:

- excellent for catching spec bugs early

Limitation:

- explicit-state explosion
- not the best tool for arithmetic-heavy symbolic state spaces

#### Apalache

What it is:

- symbolic model checker for TLA+
- translates TLA+ reasoning obligations into SMT, especially `Z3`

Current significance:

- one of the most practically relevant TLA+ tools today
- supports bounded model checking, symbolic execution, and inductiveness checking

Best fit:

- symbolic safety reasoning over rich TLA+ specs

#### Spin / Promela

What it is:

- classic on-the-fly model checker for concurrent/distributed systems
- centered on `Promela`
- supports `LTL`, partial-order reduction, simulation, and exhaustive verification

Best fit:

- software concurrency
- message-passing protocols
- interleaving-heavy control behavior

Limitation for this repo:

- less natural than hardware-focused flows for bit-accurate RTL datapaths

#### nuXmv

What it is:

- symbolic model checker for finite-state and infinite-state systems
- extends NuSMV with SAT- and SMT-based engines

Current significance:

- still a serious tool for symbolic transition-system verification
- supports modern algorithms including IC3-family and SMT-based methods

Best fit:

- symbolic transition systems
- VMT-based workflows
- requirements/property checking where classical symbolic model checking is the right shape

#### Kind 2

What it is:

- SMT-based automatic model checker for Lustre

Best fit:

- synchronous reactive systems
- control logic already modeled in Lustre

Practical note:

- conceptually relevant because it shows what a synchronous-reactive verification stack looks like
- not the most direct fit for a Verilog + Lean repository unless a Lustre translation layer exists

#### Alloy 6

What it is:

- relational modeling language and analyzer
- now includes mutable state and temporal logic support

Best fit:

- structural design exploration
- bounded behavioral models
- fast finite-scope counterexample search

Important tradeoff:

- excellent for finite relational models
- not a substitute for theorem proving or bit-precise RTL verification

#### Yosys + SBY

What it is:

- open hardware formal flow around Yosys
- `SBY` drives bounded proofs, unbounded proofs, cover, and liveness tasks
- can use `yosys-smtbmc`, `ABC`, `AIGER` engines, and external SMT solvers

For this repository, this is the most practically important external verification ecosystem besides Lean.

Why:

- direct relevance to Verilog/SystemVerilog RTL
- fast counterexample production
- good at finding real bugs early
- complements theorem proving instead of replacing it

### 3.3 SMT and SAT backends

#### Z3

Current position:

- still one of the default SMT backends across many tools
- supports tactics, quantifiers, and a fixedpoint engine

Best fit:

- arithmetic and bit-vector reasoning
- bounded verification backends
- symbolic encodings of transition systems

#### cvc5

Current position:

- strong modern SMT solver
- supports SyGuS
- has explicit proof production support in CPC, Alethe, and LFSC-related flows

Why it matters here:

- if proof artifacts or independently checkable solver evidence starts to matter, cvc5 becomes especially attractive

#### SAT/BDD substrate

Even when not visible at the top level, many verification stacks still depend on:

- SAT solving
- BDDs
- IC3/PDR
- automata emptiness checks

This is why the same algorithmic themes reappear in `nuXmv`, Yosys formal flows, and LTL/automata libraries.

### 3.4 Automata and synthesis tooling

#### Spot

What it is:

- a major library for `LTL`, ω-automata, and model-checking support

Why it matters:

- this is one of the clearest practical bridges between temporal-logic theory and actual toolchains
- it supports translation, equivalence, simplification, hierarchy checks, and finite-trace support tricks

#### Strix

What it is:

- reactive `LTL` synthesis tool

Best fit:

- when the goal is not only verifying a controller but synthesizing one from a temporal spec

This is more future-looking for this repository, but still relevant to the ecosystem map.

## 4. Related Mathematics That Actually Pays Off

If the goal is practical formal reasoning, the mathematics worth learning in order is:

1. transition systems and traces
2. induction and coinduction
3. safety/liveness/fairness
4. invariants and ranking/progress arguments
5. simulation and refinement
6. automata on infinite words
7. fixed points and the modal `μ`-calculus

For a hardware-leaning repository like this one, the best return-on-time is:

- inductive invariants
- bounded temporal operators
- trace semantics
- refinement between RTL and functional models

The more theory-heavy automata and `μ`-calculus material is valuable mainly because it explains the behavior of external tools.

## 5. Assessment for This Repository

This repository is currently:

- Lean-based for machine-checked proofs
- RTL-based for implementation artifacts
- focused on bounded-cycle behavior of a concrete state machine

That means the mathematically natural proof interface is:

- finite traces over `run`
- invariants over reachable machine states
- bounded eventuality and stability operators

### Recommended stack

#### 1. Keep Lean as the proof authority

Use Lean for:

- state semantics
- functional correctness
- termination
- bounded temporal lemmas
- output stability
- phase-ordering facts

#### 2. Keep temporal logic shallow and project-local

Define the temporal layer you need directly over `run`.

Recommended operators:

- `AlwaysUpTo`
- `EventuallyWithin`
- `StableAfter`
- optionally `UntilWithin`

This remains the cleanest fit for the current repository.

#### 3. Add hardware model checking externally if you want faster bug discovery

Most useful external complement:

- `SBY` / Yosys formal

Use it for:

- quick assertion failures
- bounded counterexample search
- sanity-checking handshake rules
- checking simple liveness or cover reachability

This gives a "find bugs fast" path that Lean is not designed to optimize for.

#### 4. Only add TLA+ tooling if the control story grows

Use `TLA+` plus `TLC` or `Apalache` if:

- the design grows into protocol-like control
- multiple interacting agents appear
- refinement between architectural control levels becomes the hard part

Do not add TLA+ just to prove a small single-transaction RTL machine.

#### 5. Treat `nuXmv` as optional, not default

`nuXmv` becomes attractive if:

- you want a symbolic transition-system workflow
- you export to VMT
- you want IC3/SMT model checking without committing to TLA+

For the current repository, `SBY` is the simpler first add-on.

## Bottom Line

The conceptual center of this topic is:

- transition systems
- traces
- invariants
- bounded temporal properties

The ecosystem center is:

- Lean / Rocq / Isabelle for proofs
- TLC / Apalache / Spin / nuXmv / Kind 2 / Alloy for model checking and analysis
- Z3 / cvc5 as solver backends
- Spot / Strix for automata and synthesis
- Yosys / SBY for practical RTL formal work

For this repository specifically, the right answer is not "pick the biggest temporal logic ecosystem."

It is:

1. keep Lean for trusted proofs
2. keep temporal reasoning finite-trace and local
3. use Yosys/SBY as the first external formal engine if you want fast counterexamples
4. add TLA+ or nuXmv only if the system evolves into a richer reactive-control problem

## Sources

- Lean 4 documentation, *Theorem Proving in Lean 4*: <https://docs.lean-lang.org/theorem_proving_in_lean4/>
- Lean 4 paper: <https://lean-lang.org/papers/lean4.pdf>
- Functional Programming in Lean: <https://leanprover.github.io/functional_programming_in_lean/>
- Mathematics in Lean: <https://leanprover-community.github.io/mathematics_in_lean/index.html>
- Rocq Prover home: <https://rocq-prover.org/>
- Rocq Prover overview: <https://rocq-prover.org/about>
- Isabelle home: <https://isabelle.in.tum.de/website-Isabelle2025-RC1/>
- Isabelle documentation index: <https://isabelle.in.tum.de/library/Doc/index.html>
- Sledgehammer guide: <https://isabelle.in.tum.de/website-Isabelle2025-RC3/dist/Isabelle2025-RC3/doc/sledgehammer.pdf>
- Nitpick guide: <https://isabelle.in.tum.de/doc/nitpick.pdf>
- TLA+ book, *Specifying Systems*: <https://lamport.azurewebsites.net/tla/book-21-07-04.pdf>
- TLA+ Hyperbook: <https://lamport.azurewebsites.net/tla/hyperbook.html>
- TLA+ Toolbox: <https://lamport.azurewebsites.net/tla/toolbox.html>
- TLC overview: <https://docs.tlapl.us/using%3Atlc%3Astart>
- TLAPS home: <https://proofs.tlapl.us/doc/web/content/Home.html>
- TLAPS unsupported features: <https://proofs.tlapl.us/doc/web/content/Documentation/Unsupported_features.html>
- Apalache home: <https://apalache-mc.org/>
- Apalache docs: <https://apalache-mc.org/docs>
- Spin general description: <https://spinroot.com/spin/what.html>
- Spin manual: <https://spinroot.com/spin/Man/Manual.html>
- nuXmv home: <https://nuxmv.fbk.eu/>
- nuXmv features: <https://nuxmv.fbk.eu/features.html>
- nuXmv user manual: <https://nuxmv.fbk.eu/downloads/nuxmv-user-manual.pdf>
- Kind 2 docs: <https://kind.cs.uiowa.edu/kind2_user_docs/v1.7.0/home.html>
- Alloy home: <https://alloytools.org/>
- Alloy 6 temporal features: <https://alloytools.org/alloy6.html>
- Alloy documentation: <https://alloytools.org/documentation.html>
- Z3 guide: <https://microsoft.github.io/z3guide/>
- Z3 fixedpoints: <https://microsoft.github.io/z3guide/programming/Z3%20Python%20-%20Readonly/Fixedpoints/>
- cvc5 home: <https://cvc5.github.io/>
- cvc5 docs: <https://cvc5.github.io/docs/latest/index.html>
- cvc5 proof production: <https://cvc5.github.io/docs-ci/docs-main/proofs/proofs.html>
- Spot home: <https://spot.lre.epita.fr/>
- Spot concepts: <https://spot.lre.epita.fr/concepts.html>
- Spot temporal logic formulas: <https://spot.lre.epita.fr/tl.pdf>
- Strix home: <https://strix.model.in.tum.de/>
- Yosys introduction: <https://yosyshq.readthedocs.io/projects/yosys/en/stable/introduction.html>
- Yosys symbolic model checking: <https://yosyshq.readthedocs.io/projects/yosys/en/0.44/using_yosys/more_scripting/model_checking.html>
- SymbiYosys docs: <https://yosyshq.readthedocs.io/projects/sby/en/stable/>
- SymbiYosys engine reference: <https://yosyshq.readthedocs.io/projects/sby/en/latest/reference.html>
