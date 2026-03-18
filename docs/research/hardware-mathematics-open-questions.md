# Hardware Mathematics: Questions and Literature Map

Date: 2026-03-17

## Abstract

This note collects the questions suggested by [`hardware-mathematics.md`](../hardware-mathematics.md) and ties them to concrete proof and RTL artifacts in this repository.

The smaller questions are:

- can the current sheaf/descent language be made literal?
- can the single-transaction bridge be extended to a compositional multi-transaction semantics?
- can Lean's `controlOf` reduction and the synthesis-side predicate abstraction be related by a genuine abstraction theory?
- what replaces the current control-only reduction once control becomes data-dependent?
- what semantics emerges when modular overflow is treated as active dynamics rather than an excluded case?
- can the current Lean-to-RTL trust boundary be replaced by a semantics-preserving bridge down to a carefully delimited synthesizable RTL subset?

The larger topics are:

- coalgebraic recasting of the machine and branch equivalence story
- open-system semantics for modular decomposition
- richer semantics of time beyond plain discrete traces
- proof-carrying or proof-producing synthesis artifacts

Each question below is written on two levels at once:

- a mathematical target
- a concrete binding to the repository's proof objects, RTL boundaries, or verification workflow

The goal is to keep the mathematics tied to actual repository artifacts such as `rtlTrace`, `controlOf`, `mlp_core`, and `mlpFixed_eq_mlpSpec`.

## 1. Scope

[`hardware-mathematics.md`](../hardware-mathematics.md) records the mathematical structure that is already visible in the repository. This note records what still looks open, which directions are likely to matter, and which references are most useful to keep in view next.

This is not a general survey. It is a problem-driven note centered on one codebase. Its use is:

- to identify which claims can become theorems
- to identify which comparisons can become explicit semantic bridges
- to distinguish background from genuinely open questions
- to keep each claim tied to a concrete proof artifact such as `rtlTrace`, `controlOf`, `mlp_core`, or `mlpFixed_eq_mlpSpec`

## 2. Questions

### 2.1 Q1: Make sheaf and descent literal

The current document uses sheaf and descent language to explain:

- how local proofs glue into global theorems
- how multiple RTL implementations agree at the shared `mlp_core` boundary

That is already mathematically suggestive, but it is not yet a literal site-theoretic or stack-theoretic construction.

The next step would be to define:

- an actual site or coverage structure for local proof obligations
- the corresponding local sections or descent data
- a precise gluing theorem
- a descent-style comparison object for the hand-written, reactive-synthesis, and Sparkle branches

Why this matters:

- it would convert one of the document's most philosophical sections into one of its most rigorous sections
- it would make "local proof -> global theorem" more than a metaphor
- it would sharpen what it means for three internally different RTLs to agree at one observable boundary
- it is the clearest route from semantic exposition to a theorem-level result

Concrete binding in this repository:

- the natural local proof objects are the phase- and transition-scoped lemmas around [`IndexInvariant`](../temporal-verification-of-reactive-hardware.md), [`busy_during_active_window`](../temporal-verification-of-reactive-hardware.md), and the shared `mlp_core` boundary comparison described in [`generated-rtl.md`](../generated-rtl.md)
- the common observable boundary is not an abstract interface class but the concrete top-level `mlp_core` interface shared by the handwritten RTL, the reactive-synthesis branch, and the Sparkle branch
- the concrete work is therefore to reorganize already-existing local proof obligations and cross-branch boundary claims into a genuine gluing story

References:

- What these references provide: [Attiya, Castañeda, and Nowak (2023)](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.DISC.2023.5) treat task solvability as the existence of continuous simplicial maps in general models of computation, while [Felber, Flores, and Galeana (2025)](https://arxiv.org/abs/2503.02556) recast solvability as the existence of global sections of a task sheaf over an execution cut.
- Connection to this repository: the local Lean lemmas around `IndexInvariant` and the cross-branch `mlp_core` agreements already behave like local proof pieces over a shared observable boundary. `Q1` is to turn that intuition into an actual gluing statement.
- What carries over and what does not: `Attiya et al.` supply the local/global solvability foundation and `Felber et al.` supply the sheaf language, but neither reference gives a hardware proof-decomposition theorem directly. The site, coverage, and local proof objects still have to be defined from this repository's proof structure.
- Use here: `Attiya et al. 2023` are the foundation for the question; `Felber 2025` remains the primary recent guide for making the sheaf/descent wording literal. [Schultz and Spivak (2017)](https://arxiv.org/abs/1710.10258) stay as broad time-semantics background.

### 2.2 Q2: Extend the bridge theorem beyond one transaction

[`hardware-mathematics.md`](../hardware-mathematics.md) presents the `run` versus `rtlTrace` bridge as a partial natural-isomorphism story on the active interval `[2, 76]`.

That is enough for the repository's current theorem stack, but [`generated-rtl.md`](../generated-rtl.md) is explicit that all current approaches are blind to multi-transaction behavior.

So the open problem is not just "prove more cycles." It is:

- define a semantics of transaction composition
- explain how accepted starts interact across longer traces
- say when two transaction windows compose cleanly
- replace the current single-window bridge with something stable under repeated transactions

At the moment the repository has a theory of one transaction. It does not yet have a theory of transaction sequences.

If pursued:

- a compositional trace theorem connecting specification-time and implementation-time semantics
- a stronger bridge between theorem proving and model checking over repeated executions

Concrete binding in this repository:

- the concrete mathematical objects are [`rtlTrace`](../temporal-verification-of-reactive-hardware.md), the `run`-based theorem stack described in [`hardware-mathematics.md`](../hardware-mathematics.md), and the bounded mixed-path validation story in [`generated-rtl.md`](../generated-rtl.md)
- the current bridge is meaningful on one accepted transaction, while the actual hardware-facing question is whether repeated start pulses or longer traces admit a compositional semantics
- the concrete work item is therefore to expose transaction boundaries, admissible schedules, and restart/overlap assumptions explicitly in the proof language

References:

- What these references provide: [De Giacomo and Vardi (2015)](https://www.diag.uniroma1.it/degiacom/papers/2015/IJCAI15dv.pdf) put finite-trace synthesis on DFA reachability games, [Geatti, Gianola, and Gigante (2022)](https://www.ijcai.org/proceedings/2022/366) extend finite traces to first-order formulas over theories, and [Winkler (2025)](https://arxiv.org/abs/2508.18149) adds lookback and gives decidable fragments for first-order `LTLf` synthesis with bounded cross-state interaction.
- Connection to this repository: the current `run` versus `rtlTrace` bridge is already finite-trace-shaped and single-window-shaped. The missing step is not more local proof, but an explicit composition semantics for repeated transaction windows and their restart conditions.
- What carries over and what does not: these references justify finite-trace, modulo-theories, and cross-state-comparison language as the right setting, but they do not solve the repository's hardware-specific bridge between repeated `run` segments and repeated `rtlTrace` windows.
- Use here: `Q2` is best anchored by a chain, not a single focal reference: `De Giacomo/Vardi` for finite-trace synthesis, `Geatti et al.` for first-order finite-trace semantics, and `Winkler` for the nearest recent control-oriented extension. [Peressotti (2025)](https://arxiv.org/abs/2507.22536) remains only as an abstract hint toward an infinite-trace extension.

### 2.3 Q3: Formalize `controlOf` versus TLSF predicate abstraction

The Lean formalization has:

- a control projection `controlOf`
- a finite-base reasoning pattern for phase-only properties

The reactive-synthesis branch has:

- boolean predicate abstraction over control-relevant signals
- a reduced game arena in which only those predicates matter

The main document already suggests that these are two views of the same control-relevant reduction. The next step is to formalize that suggestion as:

- abstraction and concretization maps
- a Galois connection or adjunction
- an abstract-interpretation-style soundness theorem
- an account of what information is preserved and what is forgotten

Why this matters:

- it would create a principled bridge between the Lean proof layer and the synthesis abstraction layer
- it would say exactly when the boolean controller abstraction is faithful to the richer machine semantics
- it has the right shape for a clear abstraction/refinement result

Concrete binding in this repository:

- the concrete Lean-side artifacts are [`controlOf`](../temporal-verification-of-reactive-hardware.md), `control_step_agrees`, and the finite-base temporal arguments in [`temporal-verification-of-reactive-hardware.md`](../temporal-verification-of-reactive-hardware.md)
- the concrete synthesis-side artifact is the controller abstraction encoded in [`rtl-synthesis/controller/controller.tlsf`](../../rtl-synthesis/controller/controller.tlsf) and discussed in [`generated-rtl.md`](../generated-rtl.md)
- the concrete task is to say whether those two reductions are merely analogous or are linked by an explicit abstraction/concretization theorem

References:

- What these references provide: [Rodríguez and Sánchez (2023)](https://arxiv.org/abs/2310.17292) show how to replace theory literals by Boolean variables plus an additional dependency condition while preserving realizability; [Rodríguez, Gorostiaga, and Sánchez (2024)](https://arxiv.org/abs/2407.09348) then build a synthesis procedure on top of that Boolean abstraction; [Walker and Ryzhyk (2014)](https://www.cs.utexas.edu/~hunt/fmcad/fmcad14/proceedings/35_walker.pdf) provide the broader game-side predicate-abstraction background.
- Connection to this repository: `controlOf` forgets datapath values and keeps control-relevant structure, while the TLSF/controller side forgets theory values and keeps Boolean control-relevant predicates. The mathematical task is to compare those two forgetful maps.
- What carries over and what does not: the 2023 paper is directly about the abstraction layer that matters here, and the 2024 paper is directly about using that layer for synthesis. What is still missing is a Lean-side abstraction/concretization theorem relating those reductions to `controlOf` and `control_step_agrees`.
- Use here: `Rodríguez and Sánchez 2023` is the right primary reference for `Q3`; `Rodríguez et al. 2024` stays as the follow-on construction; `Walker and Ryzhyk 2014` remain general predicate-abstraction background.

### 2.4 Q4: Understand the boundary of data-independent control

The current finite-base story works because control does not depend on datapath values.

That is a feature of the present repository, but it is also a boundary condition. Once future designs add:

- early exit
- saturation-driven branching
- controller decisions based on arithmetic values
- mixed control/data modes

the current projection story will no longer apply unchanged.

The next mathematical problem is to understand what replaces the current reduction:

- indexed transition semantics
- richer fiber dependencies
- control layers parameterized by arithmetic state

This is the cleanest "stress test" of the current framework.

If pursued:

- a mathematically clean account of when finite-base reasoning breaks
- a transition from finite control reasoning to indexed or dependent transition semantics

Concrete binding in this repository:

- the present finite-base reduction is visible in the control-only reasoning around [`controlOf`](../temporal-verification-of-reactive-hardware.md) and the active-window lemmas proved over the finite control projection
- any future controller behavior that branches on arithmetic state would immediately change the proof shape of those arguments, not merely add a new implementation detail
- the concrete task is therefore to identify exactly which current proofs depend on data-independence and how those proofs must be reformulated when the dependency appears

References:

- What this reference provides: [Akshay, Basa, Chakraborty, and Fried (2024)](https://arxiv.org/abs/2401.11290) lift the notion of uniquely defined outputs from Boolean functional synthesis into reactive synthesis, show that dependent outputs are common in benchmarks, and exploit that dependency to project them away and reconstruct them later.
- Connection to this repository: the current proof story also works by projecting away datapath information that does not affect control. This reference gives the clearest technical language for why such a reduction is valid only under a dependency hypothesis.
- What carries over and what does not: the paper explains why the current control/data split can be powerful, but it does not solve the next problem for us. Once control decisions depend on arithmetic state, the repository will need indexed or dependent transition semantics rather than another round of output elimination.
- Use here: `Akshay et al. 2024` remains the primary reference for `Q4`. [Rodríguez et al. 2024](https://arxiv.org/abs/2407.09348) is useful only when the discussion shifts from eliminable variables to richer theory-aware abstractions.

### 2.5 Q5: Go beyond the injective-safe quotient regime

The present quotient-geometry story is about the safe regime where modular arithmetic agrees with unbounded arithmetic on the actual computation range.

That is exactly the right theorem for the current branch-comparison story, but it leaves open the more interesting case where wrapping is semantically active.

The next step would be to treat overflow not merely as a forbidden error mode, but as part of the reachable geometry:

- wrapped versus unwrapped fibers
- phase-dependent overflow regions
- transition systems whose reachable structure changes when quotienting becomes active

This would turn the current "no wrap occurs" theorem into a larger theory of what modular geometry does when it does occur.

If pursued:

- a semantics of modular arithmetic that is structurally richer than simple overflow exclusion
- a clearer bridge between hardware arithmetic practice and quotient-geometric reasoning

Concrete binding in this repository:

- the concrete arithmetic anchor is [`mlpFixed_eq_mlpSpec`](../from-ann-to-proven-hardware.md), together with the QF_BV confirmation path described in [`solver-backed-verification.md`](../solver-backed-verification.md)
- the current branch-comparison story works because the hardware remains in an injective-safe range; the question begins exactly where that safety argument stops being the whole story
- the concrete work is to move from "overflow excluded by theorem" to "overflow represented inside the state semantics" without losing contact with the actual fixed-width RTL

References:

- What these references provide: [Graham-Lengrand, Jovanović, and Dutertre (2020)](https://arxiv.org/abs/2004.07940) show how to do word-level bitvector reasoning in an MCSAT setting using BDD domains and explanation mechanisms; [Rath, Eisenhofer, Kaufmann, Bjørner, and Kovács (2024)](https://arxiv.org/abs/2406.04696) push further to polynomial bitvector arithmetic over `Z/2^w Z`, extracting intervals and generating lemmas on demand without collapsing everything into bit-blasting.
- Connection to this repository: the current arithmetic story treats fixed-width hardware mostly through a safe-range theorem. These references instead treat modular bitvector arithmetic as its own semantic domain, which is exactly the conceptual move needed once overflow becomes active rather than excluded.
- What carries over and what does not: these are solver papers, not RTL machine-semantics papers, so they do not directly give a quotient-geometry theorem for our state space. They do, however, justify treating wrapped arithmetic as first-class semantics instead of as a hidden integer approximation.
- Use here: `PolySAT 2024` remains the primary recent reference for `Q5`; `Graham-Lengrand et al. 2020` are the key foundational support; [MoXIchecker (2024)](https://arxiv.org/abs/2407.15551) and [Btor2-Cert (2024)](https://www.sosy-lab.org/research/btor2-cert/) remain workflow support rather than arithmetic anchors.

### 2.6 Q6: Shrink the Lean-to-Verilog semantic gap

The current repository is explicit that its strongest results are not yet a single end-to-end theorem from mathematics to Verilog.

There are really two closely related gaps:

- the handwritten `rtl/` branch depends on a non-formal correspondence between the Lean `step` / `timedStep` model and the checked-in SystemVerilog
- the `rtl-formalize-synthesis/` branch proves refinement down to the Sparkle Signal DSL semantics, but still trusts the DSL-to-Verilog lowering path and wrapper reconstruction below that proof boundary

So the open problem is not just "add more validation." It is to replace part of the current trust boundary with a formally defined bridge for a carefully delimited synthesizable RTL subset close to the code this repository actually handwrites and emits.

The next step would be to define:

- a formal semantics for the concrete synthesizable RTL constructs that the repository actually uses
- an observational equivalence or trace semantics at the concrete `mlp_core` boundary
- a simulation or refinement theorem from Lean-side machine traces to RTL traces, or from Sparkle DSL traces to emitted RTL traces, for that restricted subset
- a proof-producing or independently checkable translation story for generated RTL, together with a separate account of what remains trusted in handwritten wrappers and backend lowering

Why this matters:

- it directly targets the repository's largest remaining trust boundary
- it would sharpen what the current Lean/SMT/simulation combination proves versus what it only corroborates
- it is the clearest route from "strong evidence" to a narrower and more honest end-to-end semantic claim
- it ties the repository's current practical limitation to a live research problem rather than to a documentation accident

Concrete binding in this repository:

- the handwritten gap is between `formalize/src/MlpCore/Defs/MachineCore.lean`, `formalize/src/MlpCore/Defs/TemporalCore.lean`, and the checked-in RTL under `rtl/results/canonical/sv/`
- the generated gap is between `rtl-formalize-synthesis/src/MlpCoreSparkle/*.lean` and the emitted `rtl-formalize-synthesis/results/canonical/sv/sparkle_mlp_core.sv`
- the stable-wrapper gap is the bit-slicing reconstruction in `rtl-formalize-synthesis/results/canonical/sv/mlp_core.sv`
- the current `smt/` checks and branch-comparison workflows are implementation-side cross-checks, not semantics-preservation theorems

What would have to be parameterized for a genuinely generalized theorem:

- network shape and state schema
  Right now the proved Sparkle branch is fixed to one concrete state shape: 4 external inputs, 8 hidden registers, one output bit, one accumulator, one packed 299-bit payload layout, and one specific phase graph. A generalized theorem would need these to become parameters rather than literals scattered through `MlpCoreState`, packing code, and control invariants.
- learned parameters and contract tables
  The current Sparkle proof bakes in one frozen instance of `w1Data`, `b1Data`, `w2Data`, and `b2Data`. To move from "this MLP for all inputs" to "arbitrary MLPs in a family," the theorem statement would need weights and biases as parameters, together with the exact well-formedness conditions they must satisfy.
- arithmetic interpretation
  Widths, signedness, fixed-point conventions, and overflow discipline are currently chosen once and then proved around. A generalized statement would need these arithmetic choices factored out explicitly, or else it would remain tied to the current `Input8` / `Hidden16` / `Acc32` story.
- pure-machine / Signal-DSL correspondence data
  The present proof connects one pure `timedStep` semantics to one concrete Sparkle `Signal.loop` body for this design. A generalized theorem would need a parameterized simulation package: state encoding, decode/encode compatibility, next-state correspondence, and the invariants that make those bridges legal.
- emitted subset and backend contract
  Even the backend claim is currently scoped to one declared emitted subset, one entrypoint, and one wrapper discipline. A more general theorem would need to say which Sparkle constructs, bundling conventions, register-discipline assumptions, and wrapper reconstruction patterns are part of the accepted fragment.

In other words, the current theorem is universal over input traces but not over architecture. The research problem is to replace "one checked-in MLP instance" with a parameterized family of machines, data tables, encodings, and emit contracts, without making the theorem so abstract that it loses contact with the actual RTL artifacts this repository emits.

References:

- What these references provide: [Meredith, Katelman, Meseguer, and Rosu (2010)](https://www.ideals.illinois.edu/items/17155) provide a foundational executable semantics of Verilog and explicitly position it as a rigorous starting point rather than a final word on the language; [Lööw and Myreen (2019)](https://www.doc.ic.ac.uk/~aloow/papers/formalise19.pdf) provide a proof-producing translator from HOL circuit descriptions to a targeted Verilog subset together with a semantics meant to support automated and interactive reasoning; [Chen et al. (2023)](https://doi.org/10.1145/3622805) give a core-language semantics (`λV`) aimed at making Verilog tractable without pretending to formalize every corner of the full language at once; [Lööw (2025)](https://arxiv.org/abs/2502.19348) sharpens the current state of the problem by arguing that previous formalizations still failed to support real-world hardware designs cleanly, and by repairing the semantics enough to execute such designs; [Choi, Kim, and Kang (2025)](https://doi.org/10.1145/3763084) push the latest step further by proposing a deductive-friendly least-fixpoint semantics and proving it equivalent to the standard scheduling semantics for synthesizable designs.
- Connection to this repository: these works justify treating `Q6` as a semantics-and-translation problem for a deliberately small HDL subset, not as a claim that one should first formalize all of Verilog or SystemVerilog. They also suggest two realistic technical shapes for progress: either define a tractable core or equivalent semantics for the RTL fragment the repository actually uses, or build a proof-producing path from a narrower in-logic circuit language down to a targeted Verilog subset.
- What carries over and what does not: the papers support a realistic strategy of "pick the subset first, then prove refinement for that subset." They do not by themselves identify the correspondence between the repository's Lean machine model and its handwritten SystemVerilog, nor do they close the remaining gap across wrapper reconstruction and downstream elaboration. In particular, the repository's concrete `mlp_core` interface, packed payload convention, and Sparkle wrapper discipline would still need a repository-specific semantics account.
- Use here: `Lööw 2025` is the best current framing reference for why this remains a live problem; `Choi/Kim/Kang 2025` are the strongest direct signal for an equivalent deductive-friendly semantics; `Lööw/Myreen 2019` are the clearest proof-producing precedent; `Chen et al. 2023` are the best core-language bridge; `Meredith et al. 2010` remain the foundational executable-semantics anchor.
- Adjacent recent trends: [Btor2-Cert (2024)](https://www.sosy-lab.org/research/btor2-cert/) and [Certifying Phase Abstraction (2024)](https://arxiv.org/abs/2405.04297) show a parallel trend toward shrinking the trusted computing base with independently checkable certificates even when a full foundational semantics is not yet available; [ChiSA (2026)](https://doi.org/10.1145/3776660) shows another nearby trend of moving some verification effort upward into generator-native intermediate representations rather than forcing every argument through flattened Verilog.

### 2.7 Smaller Topics in More Detail

The first three questions are the ones more tightly tied to the repository's current artifacts:

- mathematically nontrivial
- close to the repository's existing artifacts
- realistic candidates for mechanization
- easy to state in terms already used in adjacent formal-methods literature

For that reason, it is useful to spell out what those topics would require in a bit more detail.

#### 2.7.1 Q1 in detail: from sheaf-flavored rhetoric to literal local-to-global mathematics

Minimal mathematical objects:

- a base category or preorder of local proof contexts
- a coverage, Grothendieck topology, or at least an explicit gluing discipline
- a presheaf or indexed family assigning local proof obligations to each context
- compatibility conditions for local transition proofs

Possible theorem shapes:

- if local proof obligations satisfy compatibility on overlaps, then they glue to a global trace theorem
- the three RTL realizations define descent data over a common observable boundary
- agreement at the `mlp_core` boundary can be characterized as a descent condition rather than as three ad hoc comparison lemmas

Concrete work items in this repository:

- isolate the current per-step or per-phase lemmas in Lean as local objects
- define a small category of windows, phases, or proof contexts
- express compatibility as explicit equations or commuting diagrams
- prove a global theorem from those compatibility conditions

Possible direction:

- semantically, this could give a literal local-to-global account for a mechanized hardware proof stack
- methodologically, it could show how sheaf/descent language can be used without remaining purely metaphorical

Main risk:

- a weakly chosen site or coverage can make the construction look artificial
- the burden is therefore to show that the chosen local objects are dictated by the proof architecture rather than retrofitted to the theorem

#### 2.7.2 Q2 in detail: from one active window to compositional transaction semantics

Minimal mathematical objects:

- a trace semantics carrying explicit transaction boundaries
- a notion of accepted start, completion, and interference between windows
- a composition law for transaction segments, possibly partial rather than total
- a specification-side semantics and an implementation-side semantics defined over the same composition structure

Possible theorem shapes:

- a compositional bridge theorem stable under repeated non-overlapping transactions
- a characterization of when transactions commute, concatenate, or interfere
- a normal-form theorem reducing long traces to compositions of transaction windows under explicit assumptions

Concrete work items in this repository:

- extend `run` and `rtlTrace` to expose transaction boundaries more explicitly
- formalize admissible multi-transaction schedules
- prove the bridge theorem first for separated transactions, then for weaker hypotheses if possible
- align the theorem with simulation and RTL traces so that the result is not Lean-only

Possible direction:

- this naturally points toward a compositional semantics tied to a concrete hardware-control architecture
- it also addresses a real limitation of the current proof story, which remains single-transaction in practice

Main risk:

- the active-window theorem may not scale cleanly if environment assumptions are underspecified
- the semantics of overlap and restart conditions must therefore be made explicit very early

#### 2.7.3 Q3 in detail: abstraction theory between theorem proving and synthesis

Minimal mathematical objects:

- a concrete machine state space `S`
- an abstract control-relevant predicate space `A`
- an abstraction map `α : S -> A`
- a concretization map `γ` into subsets or predicates over `S`
- a simulation or refinement relation linking concrete and abstract transition systems

Possible theorem shapes:

- `α` is sound for control-relevant safety/liveness properties
- `α` is optimal relative to a chosen family of predicates
- the Lean-side `controlOf` reduction and the synthesis-side predicate abstraction factor through a common abstract layer

Concrete work items in this repository:

- enumerate which TLSF predicates correspond directly to Lean-side control observations
- define an explicit abstract transition system rather than only describing it informally
- prove preservation results for the relevant temporal properties
- connect the result to existing finite-base proofs and synthesis artifacts

Possible direction:

- this is the clearest bridge between theorem proving, abstraction, and reactive synthesis in the current repository
- it also avoids requiring that the entire direction be framed in categorical language, even if category-theoretic language remains useful in the background

Main risk:

- the best abstraction for synthesis may not match the cleanest abstraction for proof
- the project may therefore need to prove a comparison theorem between two abstractions rather than forcing a single canonical one

#### 2.7.4 Other smaller questions

`Q4` and `Q5` are still important, but they are less directly grounded in the repository's current proof objects:

- `Q4` becomes more concrete once the repository actually contains data-dependent control
- `Q5` becomes more concrete once overflow is promoted from excluded corner case to first-class semantic behavior

`Q6` is also already concrete, but in a different way:

- the trust boundary between Lean, handwritten RTL, Sparkle DSL semantics, and emitted RTL is already explicit in the repository's main verification documents
- unlike `Q1`-`Q3`, however, progress on `Q6` depends less on reorganizing existing local proof objects and more on importing or developing a workable formal semantics for a practical RTL subset

In both cases, the mathematics may become deeper, but the immediate empirical grounding inside the repository is currently weaker than for `Q1`-`Q3`.

## 3. Larger Topics

### 3.1 Topic A: Coalgebra as the mature alternative foundation

Coalgebra remains the cleanest mature categorical language for state-based systems (see e.g. Kori et al. 2024, Luckhardt et al. 2025 in §5.3 below).

That matters here because a coalgebraic recasting could provide:

- a standard account of one-step behavior
- a cleaner notion of bisimulation
- a more canonical language for behavioral equivalence across branches

This would not replace the Grothendieck/presheaf viewpoint. It would complement it by giving the repository a more standard state-based categorical foundation.

### 3.2 Topic B: Open systems, wiring, and double categories

If the design grows more modular, a natural next language is probably not another theorem about one closed machine. It is a compositional language for open pieces.

The relevant categorical systems-theory literature (see §5.4 below) points to:

- open systems
- wiring diagrams
- polynomial functors
- double categories

Why this matters here:

- controller, datapath, wrapper, reset bridge, and environment could all be treated as open components
- the mathematics would then describe not just validation of artifacts, but laws of interconnection
- "what composes with what" would become a first-class mathematical question

This is one natural route from semantics to architecture.

### 3.3 Topic C: Richer time semantics

The repository currently uses a deliberately conservative discrete-time story. That is sensible.

Sheaf/topos semantics of time and temporal type theory (Schultz–Spivak 2017, §5.1 below) become relevant once one wants:

- local time windows as first-class semantic objects
- asynchronous behavior to be modeled internally rather than patched externally
- stronger bridges between discrete and richer timing models

This matters especially because the main document already acknowledges the asynchronous-reset gap between the RTL and the synchronous Signal DSL semantics.

### 3.4 Topic D: Proof-producing synthesis

One of the central ideas in the main document is that synthesis and verification can be framed as two approaches to the same universally quantified statement.

Right now that is a semantic comparison. The open question is whether it can become a structural one:

- can synthesis produce proof-relevant artifacts?
- can a synthesized controller be compared directly with a proof term?
- can the constructive content of the winning strategy and the Lean theorem be aligned?

If so, the current conceptual bridge between "winning strategy" and "Π-type witness" could become a concrete topic in its own right.

## 4. Smaller and Larger Topics

Smaller topics, closer to the current repository artifacts:

- a literal local-to-global theorem for the current proof decomposition
- a compositional transaction semantics for `run` and `rtlTrace`
- an abstraction theorem relating `controlOf` and the TLSF-side Boolean reduction
- a semantics-preserving bridge that reduces the current Lean-to-RTL trust gap

Larger topics, which become more concrete as the repository evolves:

- the boundary of data-independent control once arithmetic state enters the controller
- overflow-active semantics once modular arithmetic becomes part of the reachable machine behavior
- coalgebraic, open-system, richer-time, or proof-producing reformulations of the current framework

## 5. Notes

### 5.1 Sheaf, descent, and richer time semantics

Foundational starting points:

- [Hagit Attiya, Armando Castañeda, and Thomas Nowak, *Topological Characterization of Task Solvability in General Models of Computation* (2023)](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.DISC.2023.5). This is the most representative task-solvability foundation behind the repository's local-to-global language.
- [Patrick Schultz and David I. Spivak, *Temporal Type Theory: A topos-theoretic approach to systems and behavior* (2017)](https://arxiv.org/abs/1710.10258). This remains the clearest canonical reference for interpreting time-indexed behavior inside a sheaf/topos semantics.

Recent signals:

- [Stephan Felber, Bernardo Hummes Flores, and Hugo Rincon Galeana, *A Sheaf-Theoretic Characterization of Tasks in Distributed Systems* (2025)](https://arxiv.org/abs/2503.02556). The strongest repository-relevant point is that solvability is characterized by the existence of global sections, with cohomology used to expose obstructions.
- [Marco Peressotti, *Infinite Traces by Finality: a Sheaf-Theoretic Approach* (2025)](https://arxiv.org/abs/2507.22536). This is relevant once the repository moves beyond finite active windows into compositional infinite-trace semantics.

Current trend:

- task-solvability work is making the topological side of local-to-global reasoning more explicit, while newer sheaf papers try to recast that solvability story in global-section language
- richer semantics of time are increasingly studied through **sheaves, guarded recursion, and final-coalgebra constructions**, rather than only through plain `ℕ`-indexed traces

Repository relevance:

- this is the literature that now separates the topological foundation of task solvability from the newer sheaf recasting, which is exactly the distinction `Q1` needs

### 5.2 Reactive synthesis, abstraction, and the post-GR(1) frontier

Selected references:

- [Giuseppe De Giacomo and Moshe Y. Vardi, *Synthesis for LTL and LDL on Finite Traces* (2015)](https://www.diag.uniroma1.it/degiacom/papers/2015/IJCAI15dv.pdf). This is the foundational finite-trace synthesis reference underneath `Q2`.
- [Luca Geatti, Alessandro Gianola, and Nicola Gigante, *Linear Temporal Logic Modulo Theories over Finite Traces* (2022)](https://www.ijcai.org/proceedings/2022/366). This is the semantic base for the `LTLf`-modulo-theories side of the repository's transaction question.
- [Andoni Rodríguez and César Sánchez, *Boolean Abstractions for Realizability Modulo Theories* (2023)](https://arxiv.org/abs/2310.17292). This is the direct abstraction-theorem reference for the repository's `controlOf` versus predicate-abstraction comparison.
- [Andoni Rodríguez, Felipe Gorostiaga, and César Sánchez, *Predictable and Performant Reactive Synthesis Modulo Theories via Functional Synthesis* (2024)](https://arxiv.org/abs/2407.09348). This is best used as the follow-on synthesis construction built on top of the abstraction layer.
- [S. Akshay, Eliyahu Basa, Supratik Chakraborty, and Dror Fried, *On Dependent Variables in Reactive Synthesis* (2024)](https://arxiv.org/abs/2401.11290). This paper is important for understanding which variables are genuinely control-relevant and which can be reconstructed from the rest.
- [Sarah Winkler, *First-Order LTLf Synthesis with Lookback* (2025)](https://arxiv.org/abs/2508.18149). This is useful evidence that finite-trace synthesis is moving toward richer first-order constraints and cross-instant comparisons, not just propositional `LTLf`.

Competition and community signals:

- [SYNTCOMP](https://www.syntcomp.org/) remains the clearest public indicator of what tool builders currently treat as important. The site notes that the competition runs annually and that **LTLf tracks were added in 2023**, while the **2025** competition results are now posted there.
- [Dagstuhl Seminar 24171, *Automated Synthesis: Functional, Reactive and Beyond* (2024)](https://www.dagstuhl.de/24171/) is useful as a field-level signal. The seminar summary explicitly highlights synergy between functional and reactive synthesis, benchmark standardization, general-theory/SMT synthesis, and links to machine learning.

Current trend:

- finite-trace synthesis and synthesis modulo theories are converging on richer first-order constraints, but the decisive technical move is still abstraction down to a finite Boolean core
- preprocessing that isolates control-relevant variables or dependency constraints is becoming as important as the core solver

Repository relevance:

- this is the literature most closely aligned with the repository's `controlOf` projection, TLSF abstraction, and the still-open question of how one accepted transaction scales into structured finite-trace semantics

### 5.3 Coalgebra, equivalence, and compositional behavior

Selected references:

- [Mayuko Kori, Kazuki Watanabe, Jurriaan Rot, and Shin-ya Katsumata, *Composing Codensity Bisimulations* (2024)](https://arxiv.org/abs/2404.08308). This is a strong reference for the claim that recent coalgebraic work is heavily centered on **compositionality of behavioral equivalence**.
- [Daniel Luckhardt, Harsh Beohar, and Clemens Kupke, *Expressivity of bisimulation pseudometrics over analytic state spaces* (2025)](https://arxiv.org/abs/2505.23635). This shows that the area is not stopping at exact bisimulation, but is moving toward **quantitative behavioral distances** and modal expressivity results.
- [Marco Peressotti, *Infinite Traces by Finality: a Sheaf-Theoretic Approach* (2025)](https://arxiv.org/abs/2507.22536) also belongs here because it connects infinite traces, finality, and guarded structure in a way that coalgebraists will immediately recognize.
- [Todd Schmid, *Coalgebraic Path Constraints* (2026)](https://arxiv.org/abs/2603.12204). This is a very recent sign that the area is still actively developing new algebra-flavored specification languages for behavioral properties.

Current trend:

- coalgebra is still the mature standard language for state-based behavior
- the newer literature is emphasizing:
  - compositionality of equivalence
  - quantitative metrics, not just yes/no bisimilarity
  - tighter links between modal logic, fibrations, and behavioral distance

Repository relevance:

- if the repository wants a more standard semantics for cross-branch equivalence, recent coalgebraic work offers a better-developed destination than trying to force every claim through Grothendieck language alone

### 5.4 Open systems, interfaces, and modular composition

Selected references:

- [Sophie Libkind and David Jaz Myers, *Towards a double operadic theory of systems* (2025)](https://arxiv.org/abs/2505.18329). This is especially relevant because one of the examples is **deterministic Moore machines over lenses**, which is much closer to this repository than generic abstract systems theory.
- [John C. Baez, *Double Categories of Open Systems: the Cospan Approach* (2025)](https://arxiv.org/abs/2509.22584). This is a strong overview of the current cospan/decorated-cospan/double-category direction for open systems.

Current trend:

- categorical systems theory is shifting from **closed-machine semantics** toward **interface-aware and composition-first semantics**
- lenses, wiring diagrams, structured cospans, decorated cospans, and double categories are increasingly used as the organizing language

Repository relevance:

- if the repository grows beyond one tightly packaged core and begins reasoning separately about controller, datapath, wrapper, and environment, this literature becomes much more relevant than another layer of closed-state semantics

### 5.5 Bit-vector arithmetic, certification, and proof-carrying artifacts

Selected references:

- [Jakob Rath, Clemens Eisenhofer, Daniela Kaufmann, Nikolaj Bjørner, and Laura Kovács, *POLYSAT: Word-level Bit-vector Reasoning in Z3* (2024)](https://arxiv.org/abs/2406.04696). This is the strongest recent word-level arithmetic paper for the repository's overflow and quotient-semantics question.
- [Stéphane Graham-Lengrand, Dejan Jovanović, and Bruno Dutertre, *Solving bitvectors with MCSAT: explanations from bits and pieces* (2020)](https://arxiv.org/abs/2004.07940). This is the most relevant cited predecessor for word-level bitvector explanations and conflict analysis.
- [Salih Ates, Dirk Beyer, Po-Chun Chien, and Nian-Ze Lee, *MoXIchecker: An Extensible Model Checker for MoXI* (2024)](https://arxiv.org/abs/2407.15551). This is relevant when the arithmetic discussion shifts toward theory-rich model checking infrastructure.
- [Zsófia Ádám, Dirk Beyer, Po-Chun Chien, Nian-Ze Lee, and Nils Sirrenberg, *Btor2-Cert: A Certifying Hardware-Verification Framework Using Software Analyzers* (TACAS 2024)](https://www.sosy-lab.org/research/btor2-cert/). This is directly relevant because it studies how hardware-verification results can be independently checked through witness translation and validation.
- [Nils Froleyks, Emily Yu, Armin Biere, and Keijo Heljanko, *Certifying Phase Abstraction* (2024)](https://arxiv.org/abs/2405.04297). This is important because it shows certification being pushed into exactly the sort of preprocessing step that often sits between mathematical intent and model-checking reality.

Current trend:

- one strand is pushing word-level arithmetic and explanation mechanisms beyond full bit-blasting
- another strand is pushing **witness validation, independent certificate checking, and certifying preprocessing** into the hardware-verification stack

Repository relevance:

- for this repository, arithmetic semantics and certification should be treated as related but distinct agendas: `PolySAT` and `Graham-Lengrand et al.` for overflow-active reasoning, `MoXIchecker`, `Btor2-Cert`, and `Froleyks et al.` for checkable proof infrastructure

### 5.6 Verilog semantics and proof-producing translation

Selected references:

- [Patrick Meredith, Michael Katelman, Jose Meseguer, and Grigore Rosu, *A formal executable semantics of Verilog* (MEMOCODE 2010)](https://www.ideals.illinois.edu/items/17155). This is the foundational executable-semantics reference for the language side of the repository's trust-boundary problem.
- [Andreas Lööw and Magnus O. Myreen, *A Proof-Producing Translator for Verilog Development in HOL* (FormaliSE 2019)](https://www.doc.ic.ac.uk/~aloow/papers/formalise19.pdf). This is the clearest proof-producing precedent for linking higher-order logic artifacts to a targeted Verilog subset.
- [Qinlin Chen, Nairen Zhang, Jinpeng Wang, Tian Tan, Chang Xu, Xiaoxing Ma, and Yue Li, *The Essence of Verilog: A Tractable and Tested Operational Semantics for Verilog* (OOPSLA 2023)](https://doi.org/10.1145/3622805). This is the best core-language precedent for reducing Verilog to a tractable semantic kernel rather than attacking the full language monolithically.
- [Andreas Lööw, *The Simulation Semantics of Synthesisable Verilog* (2025)](https://arxiv.org/abs/2502.19348). This is the strongest current signal that the semantics problem remains active: it revisits the most complete prior formalization, repairs it, and emphasizes the gap between mathematical definitions and real-world executable hardware models.
- [Joonwon Choi, Jaewoo Kim, and Jeehoon Kang, *Revamping Verilog Semantics for Foundational Verification* (OOPSLA 2025)](https://doi.org/10.1145/3763084). This is the clearest recent signal that one can replace raw scheduling semantics with an equivalent deductive-friendly semantics and still aim for foundational verification over synthesizable designs.

Current trend:

- executable and proof-oriented formalizations of Verilog do exist, but they remain highly sensitive to the chosen subset and to whether the semantics is rich enough to cover real synthesizable designs
- a newer strand is no longer trying only to formalize the standard "as written", but to define a tractable core or an equivalent least-fixpoint semantics that is better suited to deductive reasoning while remaining faithful to synthesizable behavior
- proof-producing translation is a realistic route for generated artifacts when the source language is already disciplined, but it does not automatically solve handwritten RTL, wrapper logic, or backend lowering

Repository relevance:

- this is the literature most directly connected to the repository's largest trust boundary: the distance between Lean machine semantics, Sparkle DSL semantics, emitted RTL, and handwritten SystemVerilog
- it suggests a narrower and more defensible `Q6`: define a workable semantics for the exact synthesizable constructs used here, then prove refinement or translation results at that boundary instead of claiming a full HDL semantics all at once
