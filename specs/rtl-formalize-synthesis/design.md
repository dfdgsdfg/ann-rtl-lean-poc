# RTL-Formalize-Synthesis Design

## 1. Design Goal

The goal of this domain is to add a Lean-hosted RTL generation path using Sparkle HDL without collapsing the existing repository boundaries.

The intended flow is:

```text
frozen contract
  -> pure Lean spec / machine / temporal semantics
  -> Sparkle Signal DSL full-core model
  -> full-core refinement theorem
  -> raw emitted Verilog/SystemVerilog (trusted backend)
  -> stable generated `mlp_core` wrapper/adapter when needed
  -> normalized branch-local `sv/` export tree
  -> branch-local `blueprint/mlp_core.svg`
  -> existing simulation and SMT/ASIC comparison flow
```

This is not "compile arbitrary Lean to hardware." It is "re-express the full `mlp_core` hardware in a synthesizable Lean DSL and emit RTL from that DSL."

## 2. Domain Boundary

The repository has three adjacent but different formal-generation stories:

- `formalize`: prove the intended behavior in Lean
- `rtl-formalize-synthesis`: implement the full hardware in Lean using Sparkle and emit RTL
- `rtl-synthesis`: synthesize a controller from temporal logic such as GR(1)/TLSF

This separation matters because the implementation styles and trust boundaries are different.

### `formalize`

- pure spec
- fixed-point model
- machine model
- temporal proofs

### `rtl-formalize-synthesis`

- synthesizable Sparkle Signal DSL implementation of the full core
- bounded hardware state declarations
- Sparkle-backed Verilog/SystemVerilog emission
- full-core semantic alignment with the `mlp_core` contract

### `rtl-synthesis`

- temporal specification of controller behavior
- automatic controller generation from that specification

The semantic center of this domain is the generated top-level `mlp_core`. A generated wrapper or adapter may still be part of the stable downstream artifact contract when the raw Sparkle-emitted module uses backend-specific packing or reset conventions. For comparison and downstream consumption, that contract should be re-expressed through a normalized branch-local export surface under `rtl-formalize-synthesis/results/canonical/sv/`.

## 3. Recommended Architecture

### 3.1 Three-Layer Lean Story

The clean architecture is:

1. **Pure spec layer**

- the existing Lean mathematical, machine, and temporal models remain the semantic anchor

2. **Sparkle implementation layer**

- a Sparkle Signal DSL implementation expresses the full controller and datapath in synthesizable form
- this layer is connected back to `formalize/` by a full-core refinement theorem over the cycle-visible `mlp_core` semantics

3. **Emission layer**

- dedicated synthesis commands emit the raw full-core Verilog/SystemVerilog artifact and any stable downstream wrapper or adapter artifact

This avoids overloading the `formalize/` files with backend-specific concerns while still closing the pure-spec-to-Signal-DSL gap at the full-core boundary.

### 3.2 Practical Repository Shape

The exact directory layout can evolve, but the design should aim for something close to:

```text
rtl-formalize-synthesis/
  lakefile.lean
  lean-toolchain
  src/
    TinyMLPSparkle.lean
    TinyMLPSparkle/
      Types.lean
      ContractData.lean
      ControllerSignal.lean
      DatapathSignal.lean
      MlpCoreSignal.lean
      Refinement.lean
      Emit.lean
```

Where:

- `Types.lean` defines bounded hardware-facing types
- `ContractData.lean` holds generated weights or ROM content derived from the frozen contract
- `ControllerSignal.lean` implements the FSM and handshake control
- `DatapathSignal.lean` implements MAC, ReLU, ROM access, register updates, and output finalization
- `MlpCoreSignal.lean` integrates the full design at the `mlp_core` boundary
- `Refinement.lean` proves the full-core bridge from the pure `formalize/` model into the Sparkle Signal DSL semantics
- `Emit.lean` contains the `#writeVerilogDesign` or equivalent full-core emission entrypoint

The final directory names are less important than preserving this separation of concerns.

## 4. Sparkle-Specific Design Rules

Sparkle appears to support a synthesizable Signal DSL, named state helpers, and Verilog/SystemVerilog emission. The design here should lean into those strengths.

### 4.1 Use Explicit Hardware State

The controller and sequential datapath should be modeled with explicit state, likely through `Signal.loop`.

For maintainability, prefer named state declarations such as Sparkle's `declare_signal_state` style over anonymous tuple indexing.

The generated design must make explicit the state needed to realize full-core semantics:

- FSM phase
- `hidden_idx`
- `input_idx`
- accumulator
- hidden activation registers
- output register
- input registers

If these elements are decomposed across multiple Sparkle modules, the integrated semantics must still be cycle-exact at the `mlp_core` boundary.

### 4.2 Keep Bounded Arithmetic Explicit

The current repository already treats width and sign semantics as contractual.

The Sparkle implementation should therefore:

- use bounded bit-width types
- make sign extension explicit
- make wraparound behavior explicit
- separate elaboration-time numeric helpers from runtime datapath signals

### 4.3 Emit RTL From Deliberate Entry Points

The repository should have a stable Lean entry point for full-core emission rather than ad hoc REPL commands.

Each emitted artifact should state:

- source Lean entry point
- pinned upstream Sparkle revision and required local patch set
- contract revision used
- emission date or reproducible generation command
- wrapper or adapter generation path when the stable downstream artifact is not the raw Sparkle module
- stable top-level module boundary
- normalized comparable branch path in `rtl-formalize-synthesis/results/canonical/sv/`

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

## 6. Full-Core Design Strategy

The generated design should preserve the current top-level semantics while allowing internal decomposition.

### 6.1 Semantic Alignment

The intended semantic correspondence is:

- pure Lean `State`, `timedStep`, and `rtlTrace` define the repository's cycle-visible baseline
- the Sparkle full-core model reproduces those same state transitions and outputs
- emitted RTL is validated against that same baseline at the top-level module boundary

The design should therefore preserve:

- exact phase ordering
- exact guard-cycle behavior
- exact hidden-index and input-index progression
- exact `LOAD_INPUT` capture and `BIAS_OUTPUT` finalization timing
- exact `76`-cycle latency from the accept cycle to the first cycle where `done` is visible

### 6.2 Structural Decomposition

A practical Sparkle structure is:

- controller logic that computes phase and control enables
- datapath logic that computes MAC, bias, activation, and output updates
- contract-derived read-only weight and bias access
- top-level integration that exposes the existing `mlp_core` boundary

This keeps the generated design inspectable without changing the semantic contract.

## 7. Validation Strategy

Validation should happen in five layers.

### 7.1 Elaboration Validation

- Lean code compiles
- Sparkle elaborates the hardware description
- emission succeeds
- the prepare flow reproduces the pinned upstream Sparkle revision and required local patch set
- any stable wrapper or adapter generation step succeeds from committed sources

### 7.2 Structural Validation

- generated ports match the intended `mlp_core` interface
- the raw Sparkle-emitted module interface is checked against the repository's wrapper or adapter assumptions
- any stable wrapper or adapter is mechanically regenerated or checked against committed output
- packed-field recovery, reset adaptation, and `FORMAL` alias signals used by the SMT harness are validated directly
- the normalized `rtl-formalize-synthesis/results/canonical/sv/` export tree presents the same comparable top-level module contract expected of the other branches
- emitted state and control signals are inspectable enough to debug schedule drift
- reset and sequential logic are emitted in a form acceptable to the downstream simulators

### 7.3 Behavioral Validation

- the repository's full-core shared simulation vectors pass
- guard-cycle behavior is preserved
- handshake timing is preserved
- the exact `76`-cycle contract is preserved, measured from the accept cycle to the first cycle where `done` is visible

### 7.4 Comparison Validation

- the generated top-level is compared against the hand-written baseline at the `mlp_core` boundary
- comparison checks are strong enough to catch arithmetic, timing, and scheduling divergence
- branch summaries document structural differences without weakening the equivalence claim

### 7.5 QoR Validation

- Yosys can synthesize the generated RTL
- area, timing, or cell-count comparison against the hand-written baseline is recorded when relevant

## 8. Proof Strategy

The proof story should be incremental without pretending Sparkle generation is proof-producing by itself.

### Phase A

Prove pure properties of the current machine, arithmetic, and temporal model in `formalize/`.

### Phase B

Prove that the Sparkle Signal DSL full-core implementation refines the relevant pure full-core model in `formalize/` at the Lean level.

### Phase C

Treat the emitted RTL as a generated artifact behind a trusted Sparkle backend, and validate it with simulation and downstream SMT/synthesis unless a stronger semantics-preservation argument is developed.

This keeps the trust boundary honest:

- proofs cover the pure spec and the Signal DSL full-core implementation model
- Sparkle-to-Verilog generation is trusted software
- emitted RTL is still checked by simulation, SMT, and synthesis

## 9. Main Risks

### 9.1 Not All Lean Is Hardware

The current pure Lean files likely contain constructs that are excellent for proofs and poor for RTL generation.

So the Sparkle path should be a deliberate re-implementation of the hardware, not an attempt to point Sparkle at the existing proof files and hope for Verilog.

### 9.2 State Explosion in a Monolithic Design

The current core is small, but a monolithic one-function implementation may still become hard to inspect and hard to relate back to the baseline schedule.

Prefer decomposing the design into:

- controller logic
- datapath logic
- top-level integration

### 9.3 False Confidence From Generation

Generated RTL is not automatically correct because it came from Lean.

Correctness still depends on:

- matching the frozen contract
- matching the intended cycle schedule
- validating the emitted design
- keeping the top-level module interface stable across backend output changes

## 10. Resolved Design Decisions

| Decision | Resolution | Rationale |
| --- | --- | --- |
| Role of Sparkle | Lean-hosted hardware DSL and emitter, not a free compiler from arbitrary Lean | Matches Sparkle's public model and avoids overclaiming |
| Repository baseline | Hand-written `rtl/` remains canonical until the generated path proves out | Keeps comparisons honest |
| Domain scope | Full generated `mlp_core` semantics at the top-level boundary | Makes the domain target explicit and removes ambiguous partial-scope claims |
| Weight source | Reuse the frozen contract pipeline | Prevents semantic drift |
| Implementation strategy | Re-implement the hardware in Sparkle Signal DSL with explicit controller/datapath state | The current proof files are not automatically synthesizable |
| Proof boundary | Full-core pure-model to Signal-DSL refinement is required; emitted RTL still sits behind a trusted backend and is validated separately | Makes the trust boundary explicit without overstating what Lean proves |
