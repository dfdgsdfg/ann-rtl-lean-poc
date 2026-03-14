# RTL-Formalize-Synthsis Design

## 1. Design Goal

The goal of this domain is to add a Lean-hosted RTL generation path using Sparkle HDL without collapsing the existing repository boundaries.

The intended flow is:

```text
frozen contract
  -> pure Lean spec / machine model
  -> Sparkle Signal DSL implementation
  -> emitted Verilog/SystemVerilog
  -> existing simulation and ASIC comparison flow
```

This is not "compile arbitrary Lean to hardware." It is "re-express the hardware in a synthesizable Lean DSL and emit RTL from that DSL."

The first milestone should also be smaller than the full repository baseline. Unlike the `rtl-synthesis` domain, it does not have to be controller-only forever, but it should start from a narrow scope that is realistic for Sparkle and still meaningful for this repository.

## 2. Domain Boundary

The repository now has three adjacent but different formal-generation stories:

- `formalize`: prove the intended behavior in Lean
- `rtl-formalize-synthsis`: implement hardware in Lean using Sparkle and emit RTL
- `rtl-synthesis`: synthesize a controller from temporal logic such as GR(1)/TLSF

This separation matters because the implementation styles and trust boundaries are different.

### `formalize`

- pure spec
- fixed-point model
- machine model
- temporal proofs

### `rtl-formalize-synthsis`

- synthesizable Signal DSL implementation
- hardware state declarations
- Sparkle-backed Verilog/SystemVerilog emission
- staged scope, beginning with a small generated RTL artifact rather than full-core replacement

### `rtl-synthesis`

- temporal specification of controller behavior
- automatic controller generation from that specification

## 3. Recommended Architecture

### 3.1 Three-Layer Lean Story

The clean architecture is:

1. **Pure spec layer**

- the existing Lean mathematical and machine models remain the semantic anchor

2. **Sparkle implementation layer**

- a Sparkle Signal DSL implementation expresses the same controller or datapath in synthesizable form

3. **Emission layer**

- dedicated synthesis commands emit Verilog/SystemVerilog artifacts

This avoids overloading the current `formalize/` files with backend-specific concerns.

### 3.2 Scope Philosophy

The right scope for `rtl-formalize-synthsis` is:

- smaller than full `mlp_core` at first
- larger than a toy disconnected from this repository
- aligned with what Sparkle is likely to handle cleanly today

That balance suggests:

1. first milestone: controller-only
2. second milestone: controller plus one or two small datapath pieces
3. later milestone: full core if the earlier stages prove stable

This is different from the `rtl-synthesis` domain in motivation, but similar in discipline: start with a small, defensible target before claiming full replacement of the baseline RTL.

### 3.3 Practical Repository Shape

The exact directory layout can evolve, but the design should aim for something close to:

```text
rtl-formalize-synthsis/
  lakefile.lean
  lean-toolchain
  src/
    TinyMLP.lean
    TinyMLP/
      Types.lean
      ContractData.lean
      ControllerSignal.lean
      DatapathSignal.lean
      MlpCoreSignal.lean
      Emit.lean
```

Where:

- `Types.lean` defines bounded hardware-facing types
- `ContractData.lean` holds generated weights or ROM content derived from the frozen contract
- `ControllerSignal.lean` implements the FSM in Sparkle
- `DatapathSignal.lean` implements MAC, ReLU, ROM, and register-transfer behavior
- `MlpCoreSignal.lean` integrates the full design
- `Emit.lean` contains the `#writeVerilogDesign` or equivalent emission entrypoints

The final directory names are less important than preserving this separation of concerns.

## 4. Sparkle-Specific Design Rules

Sparkle appears to support a synthesizable Signal DSL, named state helpers, and Verilog/SystemVerilog emission. The design here should lean into those strengths.

### 4.1 Use Explicit Hardware State

The controller and sequential datapath should be modeled with explicit state, likely through `Signal.loop`.

For maintainability, prefer named state declarations such as Sparkle's `declare_signal_state` style over anonymous tuple indexing.

This matters especially for the current RTL, which carries:

- FSM phase
- `hidden_idx`
- `input_idx`
- accumulator
- hidden activation registers
- output register
- input registers

For the first milestone, only the subset needed by the declared scope should be modeled. If the scope is controller-only, do not force hidden registers and arithmetic state into the first generated artifact.

### 4.2 Keep Bounded Arithmetic Explicit

The current repository already treats width and sign semantics as contractual.

The Sparkle implementation should therefore:

- use bounded bit-width types
- make sign extension explicit
- make wraparound behavior explicit
- separate elaboration-time numeric helpers from runtime datapath signals

### 4.3 Emit RTL From Deliberate Entry Points

The repository should have stable Lean entry points for emission rather than ad hoc REPL commands.

That means a file or executable dedicated to:

- emit controller-only RTL
- emit datapath primitive RTL
- emit full-core RTL

Each emitted artifact should state:

- source Lean entry point
- contract revision used
- emission date or reproducible generation command
- declared scope, such as controller-only or controller-plus-ReLU

## 5. Integration With Existing Contract Flow

The current repository already uses `contract/src/downstream_sync.py` to generate:

- [`rtl/src/weight_rom.sv`](../../rtl/src/weight_rom.sv)
- [`formalize/src/TinyMLP/Defs/SpecCore.lean`](../../formalize/src/TinyMLP/Defs/SpecCore.lean)

The Sparkle path should join that same synchronization flow rather than fork a new manual path.

Recommended direction:

- extend the contract freeze pipeline to also generate a Sparkle data module
- keep the frozen weights as the single semantic source of truth
- avoid hand-copying constants into Sparkle files

Possible outputs:

- Sparkle ROM definitions
- Lean constants in a Sparkle-friendly module
- generated initialization code for memories or mux-tree ROMs

## 6. Implementation Milestones

The domain should be staged.

### Milestone 1: Controller-Only

Implement the current FSM in Sparkle and emit controller RTL.

Success signal:

- the emitted controller matches [`rtl/src/controller.sv`](../../rtl/src/controller.sv) on phase ordering and handshake behavior

The comparison boundary may be a thin stable wrapper around the raw Sparkle-emitted module when that wrapper is what preserves the exact `controller.sv` parameter and port interface for downstream RTL, simulation, and SMT flows.

This is the preferred first milestone because it is:

- meaningful inside this repository
- small enough to inspect
- structurally close to Sparkle's likely strengths
- easy to compare against an existing hand-written baseline

### Milestone 2: Shared Primitive Path

Implement Sparkle versions of one or two small building blocks:

- ReLU
- MAC primitive
- ROM access abstraction

Success signal:

- primitive-level outputs match the current RTL semantics on directed tests
- the added scope is still simple enough that generated RTL remains inspectable

### Milestone 3: Full Core

Implement the full `mlp_core` in Sparkle and emit a top-level design compatible with the existing simulation flow.

Success signal:

- the generated top-level can run the current vector regression
- the `76`-cycle contract remains intact

## 7. Validation Strategy

Validation should happen in four layers.

### 7.1 Elaboration Validation

- Lean code compiles
- Sparkle elaborates the hardware description
- emission succeeds

### 7.2 Structural Validation

- generated ports match the intended interface
- emitted state and control signals are inspectable
- reset and sequential logic are emitted in a form acceptable to the downstream simulators

### 7.3 Behavioral Validation

- existing simulation vectors pass for the implemented scope
- guard-cycle behavior is preserved
- handshake timing is preserved

The intended burden scales with scope:

- controller-only: compare against `controller.sv` and controller-level harness behavior
- primitive path: directed equivalence checks for the implemented primitive boundary
- full core: run the repository's full vector regression

### 7.4 QoR Validation

- Yosys can synthesize the generated RTL
- area/timing/cell-count comparison against the hand-written baseline is recorded

## 8. Proof Strategy

The recommended proof story is incremental rather than pretending Sparkle generation is proof-producing by itself.

### Phase A

Prove pure properties of the current machine and arithmetic model in `formalize/`.

### Phase B

Prove that the Sparkle Signal DSL implementation refines the relevant pure model at the Lean level, as far as practical.

### Phase C

Treat the emitted RTL as a generated artifact validated by simulation and downstream synthesis unless a stronger semantics-preservation argument is developed.

This keeps the trust boundary honest:

- proofs cover the spec and implementation model
- generation is trusted software
- emitted RTL is still checked by simulation and synthesis

## 9. Main Risks

### 9.1 Not All Lean Is Hardware

The current pure Lean files likely contain constructs that are excellent for proofs and poor for RTL generation.

So the Sparkle path should be a deliberate re-implementation of the hardware, not an attempt to point Sparkle at the existing proof files and hope for Verilog.

### 9.2 State Explosion in a Monolithic Design

The current core is small, but even here a monolithic one-function implementation may become hard to inspect.

Prefer decomposing the design into:

- controller
- datapath primitives
- top-level integration

This is also why the first milestone should stay narrow. A small successful Sparkle artifact is more useful than an ambitious full-core attempt that produces unreadable or unvalidated RTL.

### 9.3 False Confidence From Generation

Generated RTL is not automatically correct because it came from Lean.

Correctness still depends on:

- matching the frozen contract
- matching the intended cycle schedule
- validating the emitted design

## 10. Resolved Design Decisions

| Decision | Resolution | Rationale |
| --- | --- | --- |
| Role of Sparkle | Lean-hosted hardware DSL and emitter, not a free compiler from arbitrary Lean | Matches Sparkle's public model and avoids overclaiming |
| Repository baseline | Hand-written `rtl/` remains canonical until the generated path proves out | Keeps comparisons honest |
| First milestone scope | Prefer controller-only, then small primitive extensions | Balanced with Sparkle's likely strengths and easier to validate |
| Weight source | Reuse the frozen contract pipeline | Prevents semantic drift |
| Implementation strategy | Re-implement the hardware in Sparkle Signal DSL | The current proof files are not automatically synthesizable |
| Proof boundary | Pure-model proofs plus optional refinement to Signal DSL; emitted RTL still validated separately | Makes the trust boundary explicit |
