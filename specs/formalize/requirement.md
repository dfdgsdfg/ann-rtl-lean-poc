# Formalize Requirements

## 1. Purpose

This document defines the formalization and proof requirements for the Tiny Neural Inference ASIC.

The `formalize` domain covers:

- Lean models for the neural inference stack
- RTL machine semantics
- Correctness theorems
- Supporting invariants and termination proofs
- Temporal and timing properties over RTL execution traces

In this repository, `formalize` is the canonical vanilla Lean proof path. Solver-assisted Lean automation, if added, belongs to a separate optional domain under `specs/formalize-smt/`.

## 2. Network Shape

The target network is a `4 → 8 → 1` fixed-point MLP as frozen in `specs/contract/`. Concrete parameters:

- 4 signed int8 inputs
- 8 hidden neurons, with int8 × int8 → int16 MAC accumulated in int32
- 1 binary output, with int16 × int8 → int24 MAC accumulated in int32
- ReLU activation on the hidden layer
- Weights and biases are auto-generated constants embedded directly in `Defs/SpecCore.lean`

The formalization must distinguish between:

- a mathematical input domain used only for the ideal MLP definition
- a hardware-contract input domain with exactly four signed 8-bit lanes

Only the mathematical layer may use unrestricted `Int` for idealized arithmetic semantics. Every hardware-facing value-carrying machine register and contract-level arithmetic definition must use bounded signed representations that match the contract widths, for example `BitVec`-based wrappers or equivalent bounded types. Controller indices may remain `Nat` in the machine model provided their legal ranges and phase-appropriate uses are enforced by proved invariants.

## 3. Verification Scope

Lean must model and verify:

1. The mathematical neural inference definition
2. The fixed-point implementation definition
3. The RTL state-machine semantics
4. Functional agreement between RTL execution and the fixed-point model
5. FSM termination
6. Index safety
7. Optional accumulator overflow bounds
8. Interface-timing properties for `start`, `busy`, `done`, and output validity
9. Bounded temporal properties such as eventual completion and output stability after completion

## 4. Formal Layers

The Lean development must include:

1. Mathematical specification
2. Fixed-point implementation model
3. RTL machine model
4. A temporal or trace layer for reasoning about timing-sensitive RTL behavior

The baseline formalization must also expose a reusable interface boundary for future alternate proof lanes. In particular, if the repository wants an SMT-backed alternate proof lane later, `formalize/` must make it possible to import shared definitions and proof interfaces without being forced to import the finished vanilla proofs of the same theorem families.

Expected top-level definitions:

- `toMathInput : Input8 -> MathInput`
- `mlpSpec : MathInput -> Bool`
- `mlpFixed : Input8 -> Bool`
- `step : State -> State`
- `run : Nat -> State -> State`

Theorems about RTL behavior, fixed-point behavior, temporal properties, and machine execution must quantify over the hardware-contract input domain, not over unrestricted mathematical inputs.

For timing-faithful verification, the formalization must also define a sampled external trace that includes:

- `start`
- the sampled `in0..in3` transaction inputs used by the RTL `LOAD_INPUT` cycle

The formalization does not need a full general-purpose temporal-logic framework, but it must support finite-trace properties such as:

- always
- eventually within `N`
- stability after a condition becomes true

This layer must be implemented as a project-local temporal or trace vocabulary that is checked as part of this repository. External temporal-logic libraries or papers may be used as design references, but they are not required dependencies and are not part of the acceptance contract.

The formalization must model the current RTL timing contract exactly:

- `done` is a level signal equal to `state = DONE`, not a pulse
- `busy` is true exactly when `state ≠ IDLE ∧ state ≠ DONE`
- accepted `start` is a sampled event that occurs only from `IDLE`
- `start` is also sampled in `DONE` to implement hold-high and release-to-`IDLE` behavior
- the transaction input vector is captured from `in0..in3` on the `LOAD_INPUT` cycle, one cycle after accepted `start`
- the controller remains in `DONE` while sampled `start = true`
- a sampled `start = false` in `DONE` returns the machine to `IDLE`
- while sampled `start = false` in `IDLE`, the visible controller phase remains `IDLE`
- the timing-faithful trace must model the RTL idle-wait cleanup behavior: on the `IDLE ∧ ¬start` self-loop, `hiddenIdx` and `inputIdx` are driven to `0`, including after a `DONE -> IDLE` release followed by continued idle waiting
- externally valid output is first observed together with `done = true`

Proof-structure requirements for this repository:

- Linear arithmetic obligations should be normalized into the decidable Presburger fragment whenever possible. Index bounds, cycle counts, and phase-legality facts are expected to be discharged by `omega`, `linarith`, `decide`, or `native_decide`.
- Nonlinear arithmetic, wraparound reasoning, and sign-sensitive case splits must be isolated behind helper lemmas instead of being interleaved throughout top-level machine or temporal proofs.
- Public theorems must carry the phase and context assumptions they need explicitly. Safety arguments may not rely primarily on out-of-range getters returning zero or out-of-range setters being ignored.
- Proof structure should avoid hard-coding the current `4 -> 8 -> 1` constants in repetitive public case splits when a reusable finite-index helper or decidable control lemma would suffice.

## 5. Main Correctness Goal

The central theorem targets two properties for all representable hardware inputs:

**Termination** — the machine reaches `done` within a bounded cycle count:

```text
rtlTerminationGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).phase = .done
```

**Functional correctness** — the machine output equals the fixed-point model:

```text
rtlCorrectnessGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).output = mlpFixed input
```

Where `totalCycles` is a concrete constant (`76`) for the current fixed controller, `initialState` loads the hardware-domain input into machine registers with all other state zeroed, and `run` applies `step` the given number of times.

If the repository also claims agreement with the unrestricted mathematical network, that claim must be stated separately as a bridge theorem over hardware-domain inputs:

```text
fixed_matches_math (input : Input8) : Prop :=
  mlpFixed input = mlpSpec (toMathInput input)
```

This bridge theorem is distinct from the RTL theorem. The hardware-facing proof target must remain stated over the representable hardware domain.

This repository uses two related timing views:

- an operational `run` view that captures the accepted transaction at a fixed cycle budget
- a timing-faithful trace view that models sampled `start`, `LOAD_INPUT` data capture, and exact `DONE` behavior

The formalization must connect these views and prove that an accepted `start` reaches observable `done` in exactly `76` cycles for the current controller, and that the final output agrees with the input sampled on the `LOAD_INPUT` cycle.

Temporal correctness is a mandatory part of the formalization scope for this milestone. At minimum, the repository must state and prove named theorems for:

- accepted `start` implies `done` at cycle `76` for the current controller, and therefore within the bounded cycle count
- `busy` stays asserted throughout the active computation window, specifically cycles `1..75` of an accepted transaction
- `done` implies the output is valid
- output remains stable while the machine remains in `done`
- `done ∧ start` holds the machine in `done`
- `done ∧ ¬start` returns the machine to `idle`
- the final hidden MAC boundary, the final hidden neuron boundary, and the final output MAC boundary each transition to the correct successor phase with the current guard-cycle behavior

These timing theorems are necessary but not sufficient for milestone completion. The stronger boundary package below is also mandatory for this milestone and is not deferred follow-up work.

Supporting proofs must include:

- Termination (phase reaches `.done`)
- State invariants (per-phase)
- Index bounds (`hiddenIdx ≤ 8`, `inputIdx ≤ 8`)
- Temporal progress from accepted start to done
- Output stability while the machine remains in `done`
- Handshake timing consistency for `busy` and `done`
- Proof that the `IDLE ∧ ¬start` self-loop preserves `IDLE` and performs the documented controller-index cleanup without disturbing the datapath contents
- Boundary-condition proofs for the final hidden MAC step, the final hidden neuron transition, and the final output MAC step
- Proof that the hidden and output guard cycles perform no MAC work and only advance control
- Proof that boundary transitions do not perform out-of-range reads or duplicate or skip required work
- Proof that `BIAS_OUTPUT` registers the final output and that externally valid output first appears in `DONE`
- A bridge theorem showing how hardware-domain inputs are interpreted by the mathematical model, if `mlpSpec` remains defined over a wider mathematical domain

The mathematical model and the hardware-facing fixed-point model must not share an unrestricted input domain by accident. If the mathematical layer uses unbounded `Int`, it must be connected to the hardware-facing layer only through the explicit `toMathInput` bridge from representable hardware inputs. If bit-accurate wrappers introduce truncation, sign extension, or wraparound behavior, the bridge theorem must state the exact relationship instead of collapsing the two models into one unconstrained theorem.

Termination alone is not sufficient. The formalization must also capture timing-sensitive facts about when results become valid and how long they remain valid.

The most important boundary obligations are:

- after the fourth hidden-layer MAC for one neuron, `inputIdx` becomes `4`
- the next cycle is a guard cycle in `MAC_HIDDEN` with no MAC work, and the following phase is `BIAS_HIDDEN`
- after the last hidden neuron is committed, the next computation phase is `MAC_OUTPUT`
- after the eighth output-layer MAC, `inputIdx` becomes `8`
- the next cycle is a guard cycle in `MAC_OUTPUT` with no MAC work, and the following phase is `BIAS_OUTPUT`
- after `BIAS_OUTPUT`, the next visible state is `DONE`, where valid output is externally observable and remains stable while `DONE` holds

All of the boundary obligations above are milestone-critical. It is not sufficient to prove only the weaker guard-cycle phase-transition facts; the repository must also prove the no-duplicate, no-skip, no-out-of-range-read, and `BIAS_OUTPUT`/`DONE` observability obligations as named public theorems.

## 6. Lean Artifact Requirements

Lean files:

```text
formalize/
  src/
    TinyMLP.lean                          -- root import hub (imports all submodules)
    TinyMLP/
      Defs/SpecCore.lean                 -- mathematical model, Input8/MathInput domains, bounded value wrappers, shared arithmetic helpers, weight constants, toMathInput, mlpSpec
      Interfaces/ArithmeticProofProvider.lean
                                          -- proof interface for arithmetic helper families required by shared fixed-point defs
      Defs/FixedPointCore.lean           -- hardware-domain executable arithmetic and shared fixed-point definitions
      ProofsVanilla/SpecArithmetic.lean  -- baseline arithmetic lemmas and baseline provider value
      ProofsVanilla/FixedPoint.lean      -- baseline proofs for fixed-point executable definitions and the hardware→math bridge
      Machine.lean                       -- State, Phase, step, run, initialState, totalCycles with bounded value storage and invariant-backed controller indices
      Temporal.lean                      -- temporal/trace layer and mandatory timing theorems
      Simulation.lean                    -- operational bridge lemmas used by temporal and end-state proofs
      Correctness.lean                   -- top-level goals and proved theorems
      Invariants.lean                    -- IndexInvariant, step/run preservation proofs
```

The current exposure split is arithmetic-first. The repository now exposes the shared arithmetic surface using:

```text
formalize/
  src/
    TinyMLP/
      Defs/               -- shared definitions, constants, and executable functions
      Interfaces/         -- proof interfaces consumed by shared defs
      ProofsVanilla/      -- current baseline proofs and provider values selected locally by consuming files
```

The current checked-in baseline still realizes this split first at the arithmetic and fixed-point executable layer. However, the purpose of that split is to support an alternate proof lane that can eventually mirror the same public theorem surface without importing vanilla proof modules as an oracle.

## 7. Reproducibility Requirements

The formal flow must be reproducible by running `cd formalize && lake build` using the pinned Lean toolchain (currently v4.27.0). A successful `lake build` with zero `sorry` in the targeted files constitutes proof that all claimed theorems are machine-checked.

The baseline `formalize` build should remain understandable as a solver-independent Lean path. Any optional SMT-backed secondary proof lane must be documented separately rather than silently becoming part of the baseline contract.

The repository should clearly show:

- Which theorem is the main end-to-end correctness statement (`rtlCorrectnessGoal`, `rtlTerminationGoal` in `Correctness.lean`)
- Which temporal theorem set is mandatory for milestone completion, and where each theorem lives
- Which project-local temporal layer implementation is used, and where its operators and predicates are defined
- Which assumptions are required
- Which generated or fixed constants are used (the `AUTO-GENERATED WEIGHTS` block in `Defs/SpecCore.lean`)
- Whether any optional bounds proofs are incomplete

## 8. Acceptance Criteria

The `formalize` domain is complete when:

1. The Lean models for spec, fixed-point behavior, machine execution, and temporal/trace reasoning are defined.
2. The main correctness theorem (`rtlCorrectnessGoal`) is stated and proved over the hardware-contract input domain.
3. The termination theorem (`rtlTerminationGoal`) is proved.
4. The mandatory temporal theorem set is stated and proved: accepted `start` reaches `done` at cycle `76`, `busy` holds throughout active execution, `done` implies output validity, `done ∧ start` holds completion, `done ∧ ¬start` returns to `idle`, the `IDLE ∧ ¬start` self-loop performs controller cleanup, output remains stable in `done`, the final output agrees with the transaction input sampled on the `LOAD_INPUT` cycle, and the three named boundary-transition properties are proved with the current guard-cycle semantics.
5. The stronger boundary theorem package is also stated and proved as milestone-critical scope: guard cycles perform no MAC work, boundary steps do not duplicate or skip required work, boundary steps do not perform out-of-range reads, and `BIAS_OUTPUT` is the register-update cycle while `DONE` is the first externally valid completion cycle.
6. Hardware-facing arithmetic and value-storage types use bounded signed representations that match the contract widths; unrestricted `Int` is confined to the mathematical layer, while controller index legality is enforced by proved invariants rather than bounded index field types.
7. If `mlpSpec` uses a wider mathematical domain, the repository states and proves the explicit hardware-to-math bridge theorem.
8. Index-safety lemmas are proved (`IndexInvariant` preserved by `step` and `run`).
9. Public proof structure follows the project proof-engineering rules: linear arithmetic is pushed into decidable fragments, nonlinear reasoning is factored into helper lemmas, and context-sensitive safety claims carry explicit phase assumptions.
10. The baseline module structure is exposed cleanly enough that future alternate proof lanes can reuse shared definitions and proof interfaces while mirroring the same public theorem surface without importing the finished vanilla proofs of the same theorem families as an oracle. The currently exposed hook starts at the arithmetic and shared fixed-point executable layer via `Defs/*` and `Interfaces/ArithmeticProofProvider.lean`, and further exposure work may be needed as the alternate lane grows.
11. `cd formalize && lake build` succeeds with zero `sorry` in all files under `formalize/src/`. No `axiom` declarations beyond Lean's built-in foundations. Use of `decide`, `omega`, and `native_decide` is acceptable for concrete arithmetic obligations.
