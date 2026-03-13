# Formalize Design

## 1. Design Goals

The formalization should be:

- Close to the intended hardware semantics
- Layered enough to isolate proof complexity
- Reproducible from committed sources
- Reviewable as a vanilla Lean proof path without requiring an external SMT solver
- Structured so machine proofs do not hide arithmetic assumptions
- Explicit enough to reason about cycle-level timing behavior

This domain is the canonical baseline formalization. If the repository later adopts SMT-assisted Lean proof automation, that belongs to a separate optional workflow documented under `specs/formalize-smt/`.

## 2. Modeling Strategy

The formal stack should be split into four layers:

1. `mlp_spec`: pure mathematical MLP definition over a mathematical input domain
2. `mlp_fixed`: contract-domain fixed-point model over representable signed 8-bit inputs
3. `Machine`: RTL-like state machine with bounded machine storage and bounded `run`
4. `Temporal`: a project-local finite-trace layer over machine executions

This layering keeps arithmetic reasoning separate from control-state reasoning.

The critical design rule is: unrestricted `Int` belongs only to the mathematical layer for arithmetic and value semantics. Hardware-facing data definitions must encode the contract domain in their types. Controller indices may remain `Nat` in the machine model if their legal ranges and phase-appropriate uses are justified by explicit invariants.

Recommended domain split:

- `MathInput`: ideal mathematical inputs used only by `mlpSpec`
- `Input8`: hardware-contract inputs with four signed 8-bit lanes
- `toMathInput : Input8 -> MathInput`: explicit interpretation bridge

Proof engineering rules for this repository:

- Separate linear Presburger obligations from nonlinear arithmetic. Index, phase-counting, and simple range obligations should normalize to `omega`, `linarith`, `decide`, or `native_decide`; wraparound, sign-case splits, and other nonlinear facts should be isolated behind helper lemmas.
- Keep context assumptions explicit. Public safety and transition theorems should state the phase and range hypotheses they rely on, rather than relying on out-of-range getters returning zero or out-of-range setters becoming no-ops.
- Treat control-context extension explicitly. When a theorem moves from one phase to the next, the statement should make clear which fields are preserved, which are reset, and which new equalities or bounds become available.
- Prefer decidable fragments for controller proofs. Finite-state control and index reasoning should reduce to the Presburger or finite-decision fragment instead of expanding the current `4 -> 8 -> 1` constants by hand throughout public proofs.

## 3. Temporal Strategy

For RTL verification, timing is often the hardest part. End-state functional correctness is not enough by itself.

The temporal theorem set is a required deliverable for this milestone, not future work. The canonical implementation should stay project-local so it is versioned, reviewable, and build-checked with the rest of the formalization.

For this milestone, the stronger boundary package is also required scope, not optional follow-up. Guard-cycle transition facts alone are insufficient; the proof surface must also rule out duplicate work, skipped work, and out-of-range reads at the boundary cycles, and it must make the `BIAS_OUTPUT`/`DONE` observability contract explicit.

The temporal layer only needs the operators that match this controller proof scope:

- state observations over finite traces
- always on a bounded interval
- eventually within `N`
- exact-cycle obligations
- output stability after completion

External temporal-logic libraries or papers may still be useful as references for naming or structuring operators, but they should not be required to build or understand this repository.

The temporal layer should focus on properties such as:

- once a transaction is accepted, `done` is reached exactly `76` cycles later for the current controller
- `busy` stays asserted throughout the active computation window and is low in both `IDLE` and `DONE`
- `done` implies the output is valid
- while the machine remains in `done`, the output stays stable
- `done ∧ start` keeps the machine in `done`
- `done ∧ ¬start` returns the machine to `idle`
- while the machine waits in `IDLE` with sampled `start = false`, the temporal model reflects the RTL idle-cleanup self-loop that drives `hiddenIdx` and `inputIdx` back to `0`
- phase ordering cannot skip required computation stages
- final-iteration boundaries transition to the correct next phase without off-by-one behavior, including the explicit guard cycles in `MAC_HIDDEN` and `MAC_OUTPUT`

Because exact handshake timing is part of the current proof scope, the temporal layer should be defined over an explicit sampled external trace. That trace must include both sampled `start` values and the `in0..in3` transaction input captured on the RTL `LOAD_INPUT` cycle, rather than reasoning only over post-acceptance state evolution.

## 4. File Responsibilities

- `TinyMLP.lean`: root import hub — imports all submodules so `lake build` checks everything
- `Spec.lean`: `MathInput`, `Input8`, `toMathInput`, bounded integer wrapper definitions shared by later layers, frozen weight constants (auto-generated block), and `mlpSpec`
- `FixedPoint.lean`: contract-domain arithmetic operators, `mlpFixed`, and the hardware-to-math bridge theorem
- `Machine.lean`: `Phase`, `State`, `step`, `run`, `initialState`, `totalCycles`, with bounded hardware-facing value storage and invariant-backed controller indices
- `Temporal.lean`: machine-trace definitions, local temporal operators, and named temporal formulas over controller behavior
- `Invariants.lean`: `IndexInvariant`, step/run preservation proofs
- `Correctness.lean`: top-level goal definitions for functional, termination, and temporal properties
- `Simulation.lean`: supporting operational lemmas that connect `run` to the trace-level temporal statements

## 5. Proof Strategy

A practical proof order is:

1. Define `MathInput` and `mlpSpec`
2. Define `Input8`, contract-domain arithmetic, and `toMathInput`
3. Define `mlpFixed` over `Input8`
4. Prove the hardware-to-math bridge theorem over `Input8`
5. Define `State`, `step`, and `run` over bounded hardware-facing value storage, with controller indices justified by invariants
6. Define a timing-faithful local trace view over the machine execution
7. Prove invariants for each FSM phase
8. Prove termination into `DONE`
9. Prove temporal properties for `busy`, `done`, phase ordering, and output validity
10. Prove the stronger boundary package: no duplicate work, no skipped work, no out-of-range reads, and `BIAS_OUTPUT`/`DONE` observability
11. Prove the machine output equals `mlpFixed`

This order avoids mixing the hardest arithmetic and machine-state obligations too early.

## 6. Machine Modeling Plan

The Lean `State` fields map to RTL signals as follows:

| Lean `State` field | RTL signal (`mlp_core`) | Width |
|---|---|---|
| `regs : Input8` | `input_regs[0:3]` | signed [7:0] × 4 |
| `hidden : Hidden16` | `hidden_regs[0:7]` | signed [15:0] × 8 |
| `accumulator : Acc32` | `acc_reg` | signed [31:0] |
| `hiddenIdx : Nat` | `hidden_idx` | [3:0] |
| `inputIdx : Nat` | `input_idx` | [3:0] |
| `phase : Phase` | `state` (controller) | [3:0] |
| `output : Bool` | `out_bit` | 1 bit |

The exact Lean wrapper names may vary, but the hardware-facing value storage must be width-accurate. In this milestone, `hiddenIdx` and `inputIdx` may remain `Nat`; their legality is part of the invariant layer rather than a requirement to encode them as bounded index field types. Using unrestricted `Int` for arithmetic value storage should be treated as a temporary simplification, not the target design.

The Lean `Phase` constructors map one-to-one to the controller FSM states:

| Lean `Phase` | RTL `state` |
|---|---|
| `.idle` | `IDLE (4'd0)` |
| `.loadInput` | `LOAD_INPUT (4'd1)` |
| `.macHidden` | `MAC_HIDDEN (4'd2)` |
| `.biasHidden` | `BIAS_HIDDEN (4'd3)` |
| `.actHidden` | `ACT_HIDDEN (4'd4)` |
| `.nextHidden` | `NEXT_HIDDEN (4'd5)` |
| `.macOutput` | `MAC_OUTPUT (4'd6)` |
| `.biasOutput` | `BIAS_OUTPUT (4'd7)` |
| `.done` | `DONE (4'd8)` |

The operational `step` function follows the same datapath work partition and the same per-phase sequencing as `mlp_core.sv`, making the theorem directly traceable to RTL signals without an informal translation step.

The exact `IDLE`, `LOAD_INPUT`, and `DONE` interface semantics are then recovered in the temporal layer:

- the operational `step` view is intentionally simplified for accepted-transaction reasoning
- the timing-faithful `timedStep` view must match `controller.sv` exactly for sampled `start`, `LOAD_INPUT` data capture, `busy`, `done`, and restart behavior
- in particular, the `IDLE ∧ ¬start` self-loop is not a pure no-op: the temporal layer must include the datapath cleanup behavior that zeroes the controller indices while the machine waits idle

The current state-machine model is a good base for end-state correctness, but a timing-faithful layer should additionally model the control-handshake conditions that determine when a transaction is considered accepted.

A practical architecture is to keep two views:

- an operational view based on `step` and `run`
- a temporal view based on a project-local finite trace derived from that execution

The split is deliberate: the operational view may assume a preloaded `regs` field for symbolic-simulation proofs, while the temporal view must model the external transaction boundary, including the fact that `in0..in3` are sampled on the `LOAD_INPUT` cycle rather than on the accepted-`start` edge.

The proof burden is then split cleanly:

- operational lemmas explain what `run` does
- temporal theorems state what must always or eventually hold along the trace

For the current RTL, the timing-faithful view should make the following schedule explicit:

- accepted `start` at cycle `0`
- `LOAD_INPUT` and external input capture at cycle `1`
- hidden-layer work across cycles `2..65`
- output-layer MAC across cycles `66..74`
- `BIAS_OUTPUT` at cycle `75`
- `DONE` and externally valid output at cycle `76`

This exact schedule should appear in theorem statements or helper lemmas, not just prose.

## 7. Useful Invariants

Recommended invariant categories:

- Indexes always stay in range
- The idle-wait normal form is explicit: after an `IDLE ∧ ¬start` cleanup step, `hiddenIdx = 0` and `inputIdx = 0`
- The accumulator matches the current partial sum
- Hidden activations already written match the fixed-point hidden-layer definition
- Unwritten hidden slots are irrelevant to the current phase
- `DONE` implies a stable output bit
- Every hardware-facing value stays within its representable width or follows the documented wraparound semantics

## 8. Mandatory Timing Properties To Prove

The following timing-focused proof targets are required for milestone completion:

- accepted start implies `done` exactly at cycle `76`
- `busy` is true throughout the active execution window, specifically cycles `1..75`
- `done` implies the machine has a valid completed result
- once `done` is reached, output remains stable until restart semantics allow a new transaction
- `done ∧ start` preserves `done`
- `done ∧ ¬start` transitions to `idle`
- the `IDLE ∧ ¬start` self-loop performs the documented controller cleanup: phase stays `IDLE`, `hiddenIdx` and `inputIdx` are driven to `0`, and datapath contents are otherwise preserved
- the phase trace follows the allowed controller ordering
- the last hidden MAC step, the hidden guard cycle, the last hidden neuron, the last output MAC step, and the output guard cycle each transition to the correct successor phase
- boundary steps do not perform out-of-range memory access
- boundary steps do not duplicate or skip required work
- `BIAS_OUTPUT` is the register-update cycle for the final output, while `DONE` is the first externally valid-completion cycle

These temporal properties are the minimum proof set needed to claim timing-aware RTL correctness rather than pure end-state equality. Proving only the weaker guard-cycle transition facts is not enough for milestone completion.

## 9. Resolved Formal Decisions

| Decision | Resolution | Rationale |
|---|---|---|
| Mathematical vs hardware input domain | **Separate `MathInput` and `Input8`** | Hardware-facing theorems must quantify over representable signed 8-bit inputs. If the mathematical layer uses unrestricted `Int`, it must be reached through an explicit `toMathInput` bridge. |
| Hardware-to-math relationship | **State it as a separate bridge theorem** | `rtlCorrectnessGoal` should target the contract-domain model. Agreement with the unrestricted mathematical model, if claimed, must be proved separately over `Input8`. |
| How ANN constants enter Lean | **Inline auto-generated block** in `Spec.lean` (between `BEGIN/END AUTO-GENERATED WEIGHTS` markers) | Constants are match-expression definitions (`w1At`, `b1At`, `w2At`, `b2`), generated from the training/export pipeline and committed directly. |
| Machine model granularity | **One-to-one FSM state mapping with a timing-faithful overlay** | Each RTL state has a corresponding `Phase` constructor. The operational `step` model handles accepted-transaction sequencing; the temporal layer restores exact `IDLE`/`DONE` handshake semantics from the RTL. |
| Temporal layer implementation | **Use a project-local finite-trace layer** | Keep the temporal vocabulary versioned and build-checked inside this repository. External libraries or papers may inform the design, but they are not dependencies. |
| Boundary-theorem scope | **The strong boundary package is milestone-critical** | Public proofs must cover no-duplicate/no-skip/no-out-of-range boundary obligations and the `BIAS_OUTPUT`/`DONE` observability contract, not only the weaker guard-cycle phase transitions. |
| Exact timing contract | **Adopt the current RTL schedule exactly** | `done` is a level in `DONE`, the transaction latency is `76` cycles from accepted `start`, and both MAC phases include a guard cycle after the last useful multiply. |
| Overflow-bound proofs | **Not optional once arithmetic becomes width-accurate** | If machine storage is modeled with bounded signed types or wraparound semantics, overflow behavior is part of the contract model, not an afterthought. |
