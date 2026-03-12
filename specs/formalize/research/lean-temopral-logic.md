# Lean Temporal Logic Research

Date: 2026-03-12 (audited 2026-03-12)

## Question

Is there a mature temporal-logic library in the Lean community that we should depend on for RTL timing verification?

## Short Answer

There is no widely-adopted, community-standard Lean 4 temporal-logic library. However, credible academic work does exist — most notably **LeanLTL**, a peer-reviewed LTL/LTLf framework published at ITP 2025. Two other independent projects (Lentil for TLA, LeanearTemporalLogic for LTL) are also active.

None of these are on Lean Reservoir or widely adopted yet. For this repository, the practical conclusion is: evaluate LeanLTL as a potential dependency for finite-trace reasoning, but be prepared to define a project-local temporal layer if it does not fit.

## What I Found

### 1. The standard Lean base is `mathlib4`, not a temporal-logic framework

`mathlib4` describes itself as the main user-maintained Lean 4 library containing programming infrastructure, mathematics, and tactics. It is the obvious dependency for core definitions and proofs, but it does not contain a dedicated temporal-logic layer. Temporal logic is not currently a standard first-class community library in the same way that algebra, topology, or general tactics are.

### 2. LeanLTL — peer-reviewed LTL/LTLf in Lean 4

`UCSCFormalMethods/LeanLTL` is the most substantial temporal-logic project found in the Lean 4 ecosystem:

- Published at **ITP 2025** (16th International Conference on Interactive Theorem Proving, September 2025)
- Authors: Eric Vin, Kyle A. Miller, Daniel J. Fremont (UC Santa Cruz)
- NSF-funded (Award No. 2303564)
- Supports both **LTL** (infinite traces) and **LTLf** (finite traces)
- Provides custom Lean 4 tactics for temporal reasoning
- Combines LTL syntax with arbitrary Lean expressions
- 15 stars, 92 commits on GitHub
- Paper: `LIPIcs.ITP.2025.37`
- Not registered on Lean Reservoir

LTLf support is directly relevant to our bounded-trace RTL timing proofs. This project is academically validated but not yet widely adopted.

### 3. Lentil — TLA in Lean 4

`verse-lab/Lentil` is a port of `coq-tla` (Temporal Logic of Actions) to Lean 4:

- 15 stars, 42 commits, Apache 2.0
- Active development
- TLA is more oriented toward distributed protocol verification than hardware timing, but the operators overlap

### 4. LeanearTemporalLogic — independent LTL effort

`mrigankpawagi/LeanearTemporalLogic` is an independent LTL formalization:

- 3 stars, 70 commits
- Self-described as **not ready for use as a dependency**
- Ambitious goals including model-checking algorithms and Buchi automata

### 5. Adjacent logic work

The Lean ecosystem has active logic formalization in neighboring areas:

- `FormalizedFormalLogic/Foundation` (212 stars, 1,371 commits) — mathematical logic, modal logic, provability logic. Substantial but no temporal logic.
- `FormalizedFormalLogic/NonClassicalModalLogic` — created 2026-03-11 with 5 commits. Too new to characterize.
- `lean4-pdl` (15 stars, 1,007 commits) — Propositional Dynamic Logic, WIP but very active. Listed on Reservoir.

These are useful for ideas on syntax, Kripke semantics, and proof organization, but none provide temporal-logic operators.

### 6. The word `Temporal` in Lean packages can be misleading

The Reservoir package `leanSpec` includes a `Temporal` module, but its own description says that module is "a simple theory of dates, times, durations and intervals." That is useful for program specification, but it is not an LTL or CTL library.

### 7. Earlier exploratory work

- Miguel Raz's page titled "WIP Linear Temporal Logic in Lean4" (last modified May 2025) — points to external material and a Lean 3 direction rather than an established Lean 4 package.
- A 2023 GitHub gist `mc.lean` defining an `LTL` datatype and trace semantics — a standalone gist using Lean 3 style imports.

## Assessment

1. There is no widely-adopted community-standard Lean 4 temporal-logic library, and none are registered on Lean Reservoir.
2. However, **LeanLTL is a credible peer-reviewed project** that supports LTLf (finite traces) with custom tactics — directly relevant to our RTL timing proofs.
3. Two other independent projects (Lentil, LeanearTemporalLogic) show growing activity in this space.
4. The closest active adjacent work is in modal logic and dynamic logic.

The landscape is no longer "no serious work exists." It is "emerging academic work exists but is not yet ecosystem-standard."

## Recommendation For This Repository

**Evaluate LeanLTL before building from scratch.** Its LTLf support and custom tactics may cover part of what we need for bounded-trace RTL timing proofs. If it fits:

- Depend on LeanLTL for finite-trace temporal operators
- Build project-specific timing lemmas on top of LeanLTL's primitives

If LeanLTL does not fit (e.g., mismatched trace model, too heavy for our simple FSM), build a small internal finite-trace temporal layer:

- `Trace := Nat -> State`
- `AlwaysUpTo : Nat -> (State -> Prop) -> State -> Prop`
- `EventuallyWithin : Nat -> (State -> Prop) -> State -> Prop`
- `StableAfter : Nat -> (State -> Prop) -> State -> Prop`

Recommended proof targets (regardless of which approach):

- accepted start implies `done` within `N` cycles
- `busy` remains true throughout the active execution window
- `done` implies output validity
- output remains stable while the machine remains in `done`
- phase ordering cannot skip required controller stages

If later we want a richer logic layer, the most realistic next step is probably:

1. keep the finite-trace operators as the proof-facing interface
2. optionally add a shallow syntax for bounded temporal formulas
3. borrow organization ideas from LeanLTL, modal, or dynamic-logic Lean projects

## Bottom Line

As of 2026-03-12, I would not plan this project around a widely-adopted external Lean temporal-logic library — none exists at that maturity level.

I would plan around:

- `mathlib4` for general proof infrastructure
- **LeanLTL as a candidate dependency** worth evaluating for LTLf support
- a project-local temporal layer as the fallback if LeanLTL does not fit
- optional inspiration from Lentil (TLA) and modal/dynamic-logic Lean projects

## Sources

- `mathlib4`: https://github.com/leanprover-community/mathlib4
- `LeanLTL` (ITP 2025): https://github.com/UCSCFormalMethods/LeanLTL
- LeanLTL paper: https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2025.37
- `Lentil` (TLA in Lean 4): https://github.com/verse-lab/Lentil
- `LeanearTemporalLogic`: https://github.com/mrigankpawagi/LeanearTemporalLogic
- `FormalizedFormalLogic/Foundation`: https://github.com/FormalizedFormalLogic/Foundation
- `FormalizedFormalLogic/NonClassicalModalLogic`: https://github.com/FormalizedFormalLogic/NonClassicalModalLogic
- `lean4-pdl` on Reservoir: https://reservoir.lean-lang.org/%40m4lvin/pdl
- `leanSpec` on Reservoir: https://reservoir.lean-lang.org/%40paulch42/leanSpec
- Miguel Raz, "WIP Linear Temporal Logic in Lean4": https://miguelraz.github.io/blog/lineartemporallogic/
- `mc.lean` LTL gist: https://gist.github.com/jaykru/6b6f937bb5a050555cb94f2de4b7b2c5
