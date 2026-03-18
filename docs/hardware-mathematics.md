# Grothendieck Construction and the Mathematical Foundations of Hardware Design

This document organizes the mathematical structures used across the formal verification documents in this repository, with the **Grothendieck construction** and **Grothendieck category** as the central axis. It shows how core concepts from digital accelerator design — combinational logic, sequential logic, finite state machines, Moore/Mealy machines, synchronous and asynchronous circuits, and HDL — are reconstructed in the language of category theory.

This is a standalone mathematical reference. The constructions described here appear concretely in four companion documents:

- [`from-ann-to-proven-hardware.md`](from-ann-to-proven-hardware.md) — the end-to-end verification pipeline and proof layers
- [`temporal-verification-of-reactive-hardware.md`](temporal-verification-of-reactive-hardware.md) — temporal theorems, the Grothendieck construction over FSM phases, and the Cartesian fibration (§7–§8 of that document)
- [`generated-rtl.md`](generated-rtl.md) — reactive synthesis, Sparkle code generation, and the encode/decode bridge across fibers (§10, §22)
- [`solver-backed-verification.md`](solver-backed-verification.md) — SMT bounded proofs, quotient geometry, and the compositional arithmetic miter (§3, §5)

---

## 1. Why the Grothendieck Construction

The formal verification in this repository addresses the same hardware through four distinct layers:

| Layer | Subject | Mathematical character |
|-------|---------|----------------------|
| Mathematical spec (`SpecCore.lean`) | Unbounded integer arithmetic | First-order arithmetic over ℤ |
| Fixed-point model (`FixedPoint.lean`) | Finite-width wrapping arithmetic | Quotient ring ℤ/2ⁿℤ |
| Machine model (`Machine.lean`) | FSM state transitions | Finite automata |
| Temporal model (`Temporal.lean`) | Reactive traces | Time-indexed traces with a presheaf-style semantics |

These layers are **not independent**. The legal state space at each layer depends on state from other layers. For example, the valid index range in the MAC_HIDDEN phase (inputIdx ≤ 4) differs from the valid range in the BIAS_HIDDEN phase (inputIdx = 4). This **phase-dependent invariant** is naturally modeled by the total space/category associated with a Grothendieck construction.

The Grothendieck construction is the universal tool for "assembling fibers that vary over a base into a single category." This document shows why it serves as a unifying language that cuts across combinational logic, sequential logic, FSMs, temporal logic, arithmetic theories, and type theory.

```mermaid
graph TB
    subgraph "Four Verification Layers — One Grothendieck Structure"
        direction TB
        SPEC["SpecCore.lean<br/>ℤ — unbounded integers"]
        FP["FixedPoint.lean<br/>ℤ/2ⁿℤ — bitvectors"]
        MACH["Machine.lean<br/>FSM states + step"]
        TEMP["Temporal.lean<br/>rtlTrace — time-indexed trace"]
    end

    SPEC -->|"quotient map<br/>mlpFixed_eq_mlpSpec"| FP
    FP -->|"state carries<br/>bounded values"| MACH
    MACH -->|"wrapped by<br/>timedStep"| TEMP

    MACH -.-|"Grothendieck construction<br/>∫F = phase-dependent<br/>index invariant"| GC["∫F"]

    style GC fill:#f5d6a8,stroke:#c9963a
```

---

## 2. Category Theory Fundamentals

### 2.1 Definition of a Category

A category **C** consists of a collection of objects Ob(**C**) and, for any two objects A, B, a collection of morphisms Hom(A, B), satisfying:

```
h ∘ (g ∘ f) = (h ∘ g) ∘ f          (associativity)
id_B ∘ f = f = f ∘ id_A             (identity)
```

for all composable f : A → B, g : B → C, h : C → D.

### 2.2 Functors

A functor F : **C** → **D** sends objects to objects and morphisms to morphisms, preserving composition and identities:

```
F(g ∘ f) = F(g) ∘ F(f)
F(id_A) = id_{F(A)}
```

A contravariant functor F : **C**ᵒᵖ → **D** reverses the direction of morphisms: F(g ∘ f) = F(f) ∘ F(g).

### 2.3 Natural Transformations

A natural transformation η : F ⇒ G between functors F, G : **C** → **D** assigns to each object X ∈ **C** a morphism η_X : F(X) → G(X), such that for every morphism f : X → Y the following square commutes:

```
G(f) ∘ η_X = η_Y ∘ F(f)
```

### 2.4 Presheaves

A presheaf on a category **C** is a contravariant functor F : **C**ᵒᵖ → **Set**. The presheaf category **Set**^(**C**ᵒᵖ) is the category of all presheaves on **C** with natural transformations as morphisms.

The most direct hardware example is a time-indexed signal. Written naively, a signal assigns a value to each clock cycle, i.e. it looks like a stream `ℕ → Set`. If one wants literal presheaf language in the sense above, one can equivalently reverse the time category and work contravariantly. This is the semantic viewpoint used for the Sparkle Signal DSL in this repository.

---

## 3. The Grothendieck Construction: Definition and Intuition

### 3.1 Basic Definition

Given a category **C** and a functor F : **C** → **Cat** (where **Cat** is the category of small categories), the **Grothendieck construction** ∫F (also written ∫_C F or **C** ⋉ F) is the category defined as follows:

**Objects:**

```
Ob(∫F) = { (c, x) | c ∈ Ob(C),  x ∈ Ob(F(c)) }
```

**Morphisms** from (c, x) to (c', x'):

```
Hom_{∫F}((c,x), (c',x')) = { (f, g) | f : c → c' in C,  g : F(f)(x) → x' in F(c') }
```

**Composition:**

```
(f', g') ∘ (f, g) = (f' ∘ f,  g' ∘ F(f')(g))
```

### 3.2 Contravariant Grothendieck Construction

For a contravariant functor F : **C**ᵒᵖ → **Cat**, the direction of g reverses:

```
Hom_{∫F}((c,x), (c',x')) = { (f, g) | f : c → c' in C,  g : x → F(f)(x') in F(c) }
```

For a presheaf F : **C**ᵒᵖ → **Set**, each F(c) is a discrete category (a set), so g becomes the equation x = F(f)(x').

### 3.3 The Projection Functor

There is a natural projection functor π : ∫F → **C** from the total category to the base:

```
π(c, x) = c
π(f, g) = f
```

This projection defines a **fibration**. The **fiber** over c ∈ **C** is π⁻¹(c) = F(c).

### 3.4 Intuition: Assembling an Indexed Family into One

The intuition behind the Grothendieck construction is simple: "a different structure F(c) sits over each base point c, and a base morphism f : c → c' induces a connection F(f) : F(c) → F(c') between fibers. The construction assembles all of this into a single category."

```mermaid
graph TB
    subgraph total["Total category ∫F"]
        direction TB
        A1["(c₁, x₁)"]
        A2["(c₁, x₂)"]
        B1["(c₂, y₁)"]
        B2["(c₂, y₂)"]
        C1["(c₃, z₁)"]
    end

    subgraph base["Base category C"]
        direction LR
        C1B["c₁"] -->|"f"| C2B["c₂"] -->|"g"| C3B["c₃"]
    end

    subgraph fibers["Fibers"]
        direction TB
        F1["F(c₁) = {x₁, x₂}"]
        F2["F(c₂) = {y₁, y₂}"]
        F3["F(c₃) = {z₁}"]
    end

    A1 -.->|"π"| C1B
    A2 -.->|"π"| C1B
    B1 -.->|"π"| C2B
    B2 -.->|"π"| C2B
    C1 -.->|"π"| C3B

    A1 -->|"(f, g)"| B2
    B1 -->|"(g, h)"| C1
```

Think of it like a building: the base **C** is the floor plan, each room c has its own furniture F(c), and the Grothendieck construction is the whole building — all rooms with all their furniture, plus the hallways (morphisms) connecting them.

---

## 4. Combinational Logic: Categorical Interpretation

### 4.1 What Is Combinational Logic

A combinational logic circuit is one whose output is determined solely by the current inputs. It has no memory elements and no state. It is composed of logic gates (AND, OR, NOT, XOR, etc.).

### 4.2 Categorical Model: Cartesian Closed Categories

The natural categorical model for combinational logic is a **Cartesian closed category (CCC)**.

| Circuit concept | Categorical counterpart |
|----------------|------------------------|
| Wire bundle (n-bit bus) | Object A ∈ Ob(**C**) |
| Gate composition | Morphism f : A → B |
| Parallel wiring | Product A × B |
| Fan-out | Diagonal morphism Δ : A → A × A |
| Constant input | Global element 1 → A |
| Lookup table (LUT) | Exponential object Bᴬ |

In HDL, `assign y = a & b;` is a morphism f : Bit × Bit → Bit. More complex combinational logic (adders, multiplexers, ROMs) is expressed as compositions of morphisms.

### 4.3 Example from This Repository

The weight ROM in this repository is pure combinational logic:

```systemverilog
always_comb begin
  unique case ({hidden_idx, input_idx})
    8'h00: w1_data = 8'sd0;
    // ...
  endcase
end
```

This is a morphism `romRead : Idx × Idx → Int8`. Since there is no state, no Grothendieck construction is needed — it is a single morphism over a single fiber. However, the moment this ROM is read with **different semantics depending on the FSM phase**, fiber structure emerges (see §6).

```mermaid
graph LR
    subgraph "Combinational logic = morphisms, no state"
        direction LR
        IN["Input bus<br/>A = Bit⁴"]
        ROM["Weight ROM<br/>f : Idx × Idx → Int8"]
        MUL["Multiplier<br/>g : Int8 × Int8 → Int16"]
        ADD["Adder<br/>h : Int16 × Int16 → Int32"]
        OUT["Output<br/>Int32"]

        IN --> ROM --> MUL --> ADD --> OUT
    end

    style ROM fill:#d4edda
    style MUL fill:#d4edda
    style ADD fill:#d4edda
```

Each box is a morphism. No feedback, no memory — just composition. This is a CCC: everything is a pure function from inputs to outputs.

### 4.4 Combinational Logic and Topoi

The fact that truth values in combinational logic are {0, 1} corresponds to the subobject classifier Ω = {true, false} in the **Set** topos. This is the categorical expression of classical logic: the law of excluded middle P ∨ ¬P holds, and every proposition is either true or false.

---

## 5. Sequential Logic: Categorical Interpretation

### 5.1 What Is Sequential Logic

A sequential logic circuit is one whose output and **next state** are determined by the current input and the **current state**. It contains memory elements such as flip-flops, registers, and latches.

### 5.2 Synchronous Sequential Circuits

In synchronous circuits, state transitions occur only on clock edges. The transition functions are:

```
next_state = δ(current_state, input)
output     = λ(current_state, input)   -- Mealy
output     = λ(current_state)          -- Moore
```

### 5.3 Asynchronous Sequential Circuits

In asynchronous circuits, input changes affect state immediately. In this repository, the asynchronous reset (`rst_n`) is an example:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) state <= IDLE;  // asynchronous reset
  else state <= next_state;    // synchronous transition
end
```

The gap between Sparkle's synchronous Signal DSL semantics and the RTL's asynchronous reset is why the reset bridging logic in `controller_spot_compat.sv` is necessary. See [`generated-rtl.md` §5](generated-rtl.md) for the adapter layer design.

### 5.4 Categorical Model of Sequential Logic: Time-Indexed Semantics

One convenient model for synchronous sequential circuits is a time-indexed semantics over the natural numbers. Written covariantly, this is a stream over **ℕ**. If one wants literal presheaf semantics in the sense of §2.4, one may equivalently reverse the time category and work contravariantly. Viewing **ℕ** as a category whose objects are natural numbers and whose sole morphisms are successors s : n → n+1:

- State stream: **ℕ** → **State** — assigns a state to each cycle
- Input stream: **ℕ** → **Input** — assigns an input to each cycle
- Output stream: **ℕ** → **Output** — assigns an output to each cycle

The `rtlTrace` in this repository has this stream-like structure:

```lean
def rtlTrace (samples : Nat → CtrlSample) : Nat → State
  | 0 => idleState
  | n + 1 => timedStep (samples n) (rtlTrace samples n)
```

This is a covariant time-indexed semantics T : **ℕ** → **State**, assigning a machine state to each natural number (cycle). After reversing time, the same data can be organized in presheaf form.

```mermaid
graph LR
    subgraph "Sequential logic = time-indexed trace"
        direction LR
        T0["cycle 0<br/>State₀<br/>(idle)"]
        T1["cycle 1<br/>State₁<br/>(loadInput)"]
        T2["cycle 2<br/>State₂<br/>(macHidden)"]
        TD["..."]
        T76["cycle 76<br/>State₇₆<br/>(done)"]

        T0 -->|"timedStep"| T1 -->|"timedStep"| T2 -->|"timedStep"| TD -->|"timedStep"| T76
    end

    subgraph "Environment input (samples)"
        direction LR
        S0["start=true<br/>inputs"]
        S1["(any)"]
        S2["(any)"]
        SD2["..."]
    end

    S0 -.-> T0
    S1 -.-> T1
    S2 -.-> T2
```

Unlike combinational logic, sequential logic has **state that persists across cycles**. The machine at cycle n+1 depends on the machine at cycle n. This is naturally a time-indexed stream, and after reversing time it can be organized as a presheaf in the categorical sense.

### 5.5 A Monad/Comonad Lens on State and Observation

The transition function `step : State → State` is an endomorphism, and `run n` is its n-fold iteration. That concrete structure is what the repository actually uses in proofs. There is also a useful algebraic lens for thinking about the same behavior.

One may view state-transforming computation through the usual **state monad** `T(X) = State → State × X`, and state-indexed observation through the **store comonad** `W(X) = State × (State → X)`. With that lens:

- register and next-state updates resemble Kleisli-style stateful computation
- read-only predicates such as `busyOf` and `doneOf` resemble observations of state
- Sparkle primitives such as `Signal.register` and `Signal.loop` make state threading and feedback explicit

```
step, run n                      -- concrete state evolution used in proofs
Signal.register, Signal.loop     -- explicit update / feedback primitives
busyOf, doneOf                   -- read-only observations of state
```

This monad/comonad language should be read as an **interpretive perspective**, not as part of the checked proof boundary. The repository does not define these monads for the hardware model or prove monad-algebra / coKleisli laws for Sparkle.

### 5.6 The Emergence of the Grothendieck Construction: Phase-Dependent State Spaces

The point where sequential circuits go beyond simple presheaves is when **the state space itself depends on the phase**. In this repository's FSM:

- MAC_HIDDEN phase: inputIdx is one of 0, 1, 2, 3, 4
- BIAS_HIDDEN phase: inputIdx is exactly 4
- MAC_OUTPUT phase: inputIdx is one of 0, 1, ..., 8
- DONE phase: inputIdx is exactly 8

The "allowed index combinations" differ at each phase. This is a functor F : **Phase** → **Set**, and its total space ∫F is the set of all legal control configurations (treated in detail in §7).

---

## 6. Finite State Machines: Categorical Interpretation

### 6.1 Definition of a Finite State Machine

A finite state machine (FSM) is a 5-tuple (Q, Σ, δ, q₀, F):
- Q: finite set of states
- Σ: input alphabet
- δ: Q × Σ → Q transition function
- q₀ ∈ Q: initial state
- F ⊆ Q: accepting states (in hardware, specific output conditions)

```mermaid
graph LR
    subgraph "Moore machine"
        direction LR
        MS["State q"] -->|"λ(q)"| MO["Output"]
    end
    subgraph "Mealy machine"
        direction LR
        MS2["State q"] --> BOTH
        MI2["Input σ"] --> BOTH["λ(q, σ)"] --> MO2["Output"]
    end
```

### 6.2 Moore Machines and Mealy Machines

**Moore machine**: output is a function of the current state only, λ : Q → Γ

**Mealy machine**: output is a function of the current state and input, λ : Q × Σ → Γ

The FSM in this repository is a hybrid:
- `done`, `busy` are Moore outputs — determined by phase alone
- `do_mac_hidden` is a Mealy output — determined by the combination of phase (MAC_HIDDEN) and input condition (inputIdx < 4)

```lean
-- Moore: determined by phase alone
def busyOf (s : State) : Bool := s.phase ≠ .idle ∧ s.phase ≠ .done

-- Mealy: phase + index condition
def doMacHidden (s : State) : Bool :=
  s.phase = .macHidden ∧ s.inputIdx < inputCount
```

### 6.3 Viewing the FSM as a Functor

The most natural way to view an FSM categorically is to construct a **transition category**.

Define a category **T** as follows:
- Objects: the phase set Phase = {idle, loadInput, macHidden, biasHidden, actHidden, nextHidden, macOutput, biasOutput, done}
- Morphisms: allowed transitions (the `AllowedPhaseTransition` from this repository)

```
idle → idle              (start = false)
idle → loadInput         (start = true)
loadInput → macHidden
macHidden → macHidden    (inputIdx < 4)
macHidden → biasHidden   (inputIdx = 4, guard cycle)
biasHidden → actHidden
actHidden → nextHidden
nextHidden → macHidden   (hiddenIdx < 7)
nextHidden → macOutput   (hiddenIdx = 7)
macOutput → macOutput    (inputIdx < 8)
macOutput → biasOutput   (inputIdx = 8, guard cycle)
biasOutput → done
done → done              (start = true)
done → idle              (start = false)
```

This transition graph is a **directed graph** and generates a free category. The `phase_ordering_ok` theorem in this repository proves that every actual transition is a morphism in this category.

### 6.4 The Grothendieck Construction over the FSM

The true categorical structure of an FSM emerges not from the transition graph alone, but when it includes the **datapath fibers** attached to each phase.

Define a functor F : **Phase** → **Set** as follows:

```
F(macHidden)  = { (h, i) ∈ ℕ² | h < 8 ∧ i ≤ 4 }
F(biasHidden) = { (h, i) ∈ ℕ² | h < 8 ∧ i = 4 }
F(actHidden)  = { (h, i) ∈ ℕ² | h < 8 ∧ i = 4 }
F(nextHidden) = { (h, i) ∈ ℕ² | h < 8 ∧ i = 0 }
F(macOutput)  = { (h, i) ∈ ℕ² | h = 0 ∧ i ≤ 8 }
F(biasOutput) = { (h, i) ∈ ℕ² | h = 0 ∧ i = 8 }
F(done)       = { (h, i) ∈ ℕ² | h = 0 ∧ i = 8 }
F(idle)       = { (h, i) ∈ ℕ² | h ≤ 8 ∧ i ≤ 8 }
F(loadInput)  = { (h, i) ∈ ℕ² | h ≤ 8 ∧ i ≤ 8 }
```

The total space is:

```
∫F = { (p, h, i) | p ∈ Phase, (h, i) ∈ F(p) }
```

This is the categorical identity of `IndexInvariant` in this repository. `IndexInvariant` is the characteristic function of ∫F. See [`temporal-verification-of-reactive-hardware.md` §7](temporal-verification-of-reactive-hardware.md) for the full preservation proof and the mermaid diagram of the fiber transition graph.

```mermaid
graph LR
    subgraph "∫F : Grothendieck construction over FSM phases"
        direction TB
        MH["F(macHidden)<br/>h < 8, i ≤ 4"]
        BH["F(biasHidden)<br/>h < 8, i = 4"]
        AH["F(actHidden)<br/>h < 8, i = 4"]
        NH["F(nextHidden)<br/>h < 8, i = 0"]
        MO["F(macOutput)<br/>h = 0, i ≤ 8"]
        BO["F(biasOutput)<br/>h = 0, i = 8"]
        DN["F(done)<br/>h = 0, i = 8"]
    end

    MH -->|"i < 4: i ↦ i+1<br/>stays in fiber"| MH
    MH -->|"i = 4: GUARD<br/>cross-fiber"| BH
    BH --> AH
    AH -->|"i ↦ 0"| NH
    NH -->|"h < 7: h ↦ h+1"| MH
    NH -->|"h = 7: h ↦ 0"| MO
    MO -->|"i < 8: i ↦ i+1"| MO
    MO -->|"i = 8: GUARD"| BO
    BO --> DN

    style MH fill:#d4edda
    style MO fill:#d4edda
    style BH fill:#f9e2ae
    style BO fill:#f9e2ae
```

Each colored box is a **fiber** — the set of legal index values for that phase. Arrows within a fiber (self-loops) are intra-fiber moves. Arrows between fibers are **cross-fiber transitions**, and the guard cycles (highlighted in yellow) are where the fiber boundary is crossed.

### 6.5 Cross-Fiber Transitions and Guard Cycles

A guard cycle is a **cross-fiber transition**. In the transition from macHidden to biasHidden:

1. Within the macHidden fiber, i increments 0 → 1 → 2 → 3 (intra-fiber movement)
2. When i = 4, macHidden → biasHidden (cross-fiber transition, **guard cycle**)
3. In the biasHidden fiber, i = 4 is preserved

The guard cycle proofs in this repository verify that these fiber transitions are correct — that the image lands in the target fiber:

```lean
theorem hiddenGuard_no_mac_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    SameDataFields s (timedStep sample s)
```

Categorically, this says that the fiber restriction of the transition morphism is well-defined.

```mermaid
graph LR
    subgraph "Guard cycle: cross-fiber transition"
        direction TB
        subgraph fib1["macHidden fiber"]
            I0["i=0"] --> I1["i=1"] --> I2["i=2"] --> I3["i=3"]
        end
        subgraph guard["Guard (i=4)"]
            I4["i=4<br/>no MAC work"]
        end
        subgraph fib2["biasHidden fiber"]
            I4B["i=4<br/>add bias"]
        end

        I3 -->|"last MAC"| I4
        I4 -->|"cross-fiber<br/>phase change"| I4B
    end

    style guard fill:#f9e2ae,stroke:#d4a843
```

The guard cycle is the "door" between two fibers. The proof `hiddenGuard_no_mac_work` guarantees that when you walk through this door, no spurious computation happens — the accumulator is untouched, and you land safely in the next fiber.

---

## 7. Fibrational Readings and the Control Projection

### 7.1 Definition of a Cartesian Fibration

A functor π : **E** → **B** is a **Cartesian fibration** if, for every morphism f : b → b' in **B** and every object e' in **E** over b', there exists a Cartesian lift f̃ : e → e' with π(f̃) = f. A morphism f̃ is **Cartesian** if for every g : e'' → e' with π(g) = f ∘ h, there exists a unique h̄ : e'' → e with π(h̄) = h and f̃ ∘ h̄ = g.

### 7.2 A Cartesian-Fibration Reading in This Repository

The projection `controlOf : State → ControlState` admits a strong fibrational reading:

```
         step
State ─────────→ State
  │                 │
  │ π = controlOf   │ π = controlOf
  ↓                 ↓
ControlState ──→ ControlState
    controlStep
```

The commutativity condition is `π ∘ step = controlStep ∘ π` where π = controlOf. This is the `control_step_agrees` theorem:

```lean
theorem control_step_agrees (s : State) :
    controlOf (step s) = controlStep (controlOf s)
```

**Why Cartesian-like**: the control transition (controlStep) does not depend on datapath values (registers, accumulator, hidden activations). The FSM is **data-independent**. This means the fiber coordinate does not influence the base dynamics, which is exactly the kind of situation for which Cartesian-fibration language is useful.

```mermaid
graph TB
    subgraph "Cartesian fibration: control is independent of data"
        direction TB
        subgraph full["Full State (infinite)"]
            S1["phase=macHidden<br/>idx=2<br/>acc=17432<br/>hidden=[...]"]
            S2["phase=biasHidden<br/>idx=4<br/>acc=17432<br/>hidden=[...]"]
        end
        subgraph ctrl["ControlState (finite, ≤729)"]
            C1["phase=macHidden<br/>idx=2"]
            C2["phase=biasHidden<br/>idx=4"]
        end

        S1 -->|"step"| S2
        C1 -->|"controlStep"| C2
        S1 -.->|"π = controlOf<br/>(forget data)"| C1
        S2 -.->|"π = controlOf"| C2
    end
```

The key insight: the **bottom row** (control) evolves identically regardless of what the accumulator, registers, or hidden values are. So you can answer phase-related questions by looking only at the finite bottom row.

### 7.3 Practical Significance of the Control Projection

The key consequence of this projection-based reduction: **properties that depend only on the base can be proved on the base alone.**

The base category **ControlState** is finite (9 phases × 9 hiddenIdx × 9 inputIdx = at most 729 reachable states). The full state space **State** is infinite (32-bit accumulator, eight 16-bit hidden registers, etc.). Thanks to the control projection, phase-related properties (active window, phase ordering, index safety) can be decided by `native_decide` on the finite space.

```lean
private theorem controlRun_active_window (k : Fin totalCycles) (hpos : 0 < k.1) :
    let ph := (controlRun k.1 initialControl).phase
    ph ≠ .idle ∧ ph ≠ .done := by
  native_decide +revert
```

This means forgetting the infinite fiber and computing on the finite base — exactly the kind of reduction that a fibrational viewpoint is meant to justify. See [`temporal-verification-of-reactive-hardware.md` §8](temporal-verification-of-reactive-hardware.md) for the full control projection technique and its use in the active window proof.

### 7.4 Projection, Sections, and Quantification

The map `controlOf : State → ControlState` is first of all a **projection**: it forgets datapath values and keeps only phase and indices.

A useful auxiliary idea is to choose a default-fill section `lift0 : ControlState → State` that reintroduces datapath fields with canonical zeros. Such a map would satisfy:

```
controlOf : State → ControlState      (forget datapath fields)
lift0     : ControlState → State      (chosen zero-filled representative)

controlOf ∘ lift0 = id
```

This captures the informal idea that one can forget data and then choose a representative full state over the same control point.

However, the repository does **not** define a canonical `lift0` or prove an adjunction `lift0 ⊣ controlOf`, and the Cartesian fibration result in §7.2 does not depend on such an adjunction. The formal fact actually used is `control_step_agrees`: stepping commutes with projection, so control-only properties can be proved on the finite base and then read back on the full state space.

More generally, presheaf and dependent-type semantics organize substitution and quantification through adjoint triples such as:

```
f_! ⊣ f* ⊣ f_*
```

or, in type-theoretic notation,

```
Σ_f ⊣ f* ⊣ Π_f
```

That is useful background for the later sections, but it is **background structure**, not a theorem instantiated here for `controlOf`, and it is not the direct reason `native_decide` works in this repository.

---

## 8. Grothendieck Topoi and Internal Logic

### 8.1 Definition of a Topos

An **elementary topos** is a category satisfying:

1. **Finite limits** exist (in particular, terminal object 1 and pullbacks)
2. **Cartesian closure**: for any objects A, B, an exponential object Bᴬ exists satisfying

```
Hom(C × A, B) ≅ Hom(C, Bᴬ)     (natural in C)
```

3. A **subobject classifier** Ω exists: an object Ω with a morphism true : 1 → Ω such that for every monomorphism m : S ↪ X, there is a unique χ_S : X → Ω making the following a pullback:

```
S ——→ 1
|       |
m       true
|       |
↓       ↓
X ——→ Ω
  χ_S
```

### 8.2 Grothendieck Topoi

A **Grothendieck topos** is a sheaf category Sh(**C**, J) over a small site (**C**, J), where J is a Grothendieck topology on **C**.

Key relationship: every Grothendieck topos is an elementary topos. The presheaf category **Set**^(**C**ᵒᵖ) is also a topos (without the sheaf condition).

### 8.3 Three Key Topos Examples

| Topos | Definition | Subobject classifier Ω | Logic |
|-------|-----------|------------------------|-------|
| **Set** | Category of sets and functions | {true, false} | Classical (LEM holds) |
| **Set**^(**C**ᵒᵖ) | Presheaves on **C** | Functor of sieves | Intuitionistic |
| Sh(**C**, J) | Sheaf topos | Functor of closed sieves | Intuitionistic |

### 8.4 Internal Logic

The **internal logic** of a topos is the logical system naturally induced by the topos structure:

- **Conjunction ∧**: product
- **Disjunction ∨**: coproduct
- **Implication →**: exponential
- **Universal ∀**: dependent product / right adjoint
- **Existential ∃**: dependent sum / left adjoint
- **True ⊤**: terminal object
- **False ⊥**: initial object

In a general topos, the law of excluded middle P ∨ ¬P **may fail**. This is intuitionistic logic. A topos where classical logic holds (a Boolean topos) is the special case where Ω is {0, 1}.

### 8.5 Significance for Hardware

| Logical system | Hardware counterpart | Where used |
|---------------|---------------------|------------|
| Classical logic | Combinational logic — every bit is 0 or 1 | SAT/SMT solvers, bitvector reasoning |
| Intuitionistic logic | Constructive proofs — proving existence extracts a value | Program extraction in Lean/Coq |
| Internal logic | Reasoning inside a topos — context-dependent truth | Temporal reasoning over presheaves |

In this repository, **temporal properties** can be read through the internal logic of a presheaf topos. "Done at cycle 76" is then understood as a stagewise truth value at time index 76, represented in the subobject-classifier presheaf Ω.

```mermaid
graph TB
    subgraph "Three topoi, three kinds of logic"
        direction LR
        subgraph set["Set topos"]
            S_OMEGA["Ω = {true, false}"]
            S_LOGIC["Classical logic<br/>LEM holds<br/>every bit is 0 or 1"]
        end
        subgraph psh["Presheaf topos"]
            P_OMEGA["Ω = sieves<br/>(time-dependent truth)"]
            P_LOGIC["Intuitionistic logic<br/>truth may vary<br/>across time"]
        end
        subgraph shv["Sheaf topos"]
            SH_OMEGA["Ω = closed sieves"]
            SH_LOGIC["Intuitionistic logic<br/>+ gluing<br/>local → global"]
        end
    end

    set -.->|"hardware bits"| HW["Combinational logic<br/>SAT/SMT"]
    psh -.->|"signals over time"| SIG["Sequential logic<br/>Temporal properties"]
    shv -.->|"local proofs glue"| VER["Verification<br/>local → global"]
```

---

## 9. The Grothendieck Construction and Dependent Types

### 9.1 What Are Dependent Types

A dependent type is a type that depends on a value. When the codomain B in a function type `A → B` varies with the element of A, we write this as the dependent function type `Π(a : A), B(a)`.

- **Dependent product (Π-type)**: `Π(a : A), B(a)` — a function choosing an element of B(a) for every a
- **Dependent sum (Σ-type)**: `Σ(a : A), B(a)` — a pair of some a and an element of B(a)

### 9.2 The Grothendieck Construction = Categorical Realization of the Dependent Sum

The objects (c, x) of the Grothendieck construction ∫F are precisely elements of the dependent sum `Σ(c : C), F(c)`. If the functor F : **C** → **Set** assigns a set F(c) to each c, the total space is `{(c, x) | c ∈ C, x ∈ F(c)}`.

In the language of type theory:

```
∫F  ↔  Σ(c : C), F(c)     (at the level of objects)
π   ↔  fst                 (projection = first component)
```

```mermaid
graph TB
    subgraph "Grothendieck = Dependent Sum"
        direction TB
        subgraph math["Category theory side"]
            GC["∫F<br/>total category"]
            BASE["C<br/>base"]
            FIB["F(c)<br/>fiber over c"]
            GC -->|"π"| BASE
            GC -.-> FIB
        end
        subgraph type["Type theory side"]
            SIG["Σ(c : C), F(c)<br/>dependent sum"]
            FST["C<br/>first component"]
            SND["F(c)<br/>second component"]
            SIG -->|"fst"| FST
            SIG -.-> SND
        end
    end

    math <-->|"same thing,<br/>different language"| type
```

### 9.3 Realization in This Repository

Lean 4's `IndexInvariant` is a phase-indexed legality predicate written as a function `State → Prop`:

```lean
def IndexInvariant (s : State) : Prop :=
  match s.phase with
  | .macHidden  => s.hiddenIdx < 8 ∧ s.inputIdx ≤ 4
  | .biasHidden => s.hiddenIdx < 8 ∧ s.inputIdx = 4
  -- ...
```

For each phase, this defines the local fiber condition on the index coordinates. The direct Grothendieck object is the Σ-shaped total space `Σ(p : Phase), F(p)`. By contrast, `IndexInvariant` is the proposition that a concrete state lands in that total space. In other words, the total legal control space is Σ-shaped, and `IndexInvariant` is its characteristic predicate on `State`.

Sparkle's `encodeState` must respect this structure:

```lean
def encodeState (s : State) : MlpCoreState := ...
```

The encoding must place each phase fiber element into the correct BitVec range. When the phase transitions from macHidden to biasHidden, the encoded index must land within the target fiber's BitVec representable range. This is the core check at the inductive step of the refinement proof. See [`generated-rtl.md` §10–§11](generated-rtl.md) for the encode/decode bridge and the refinement theorems.

### 9.4 Categorical Interpretation of Contexts and Substitution

In type theory, a **context** Γ = (x₁ : A₁, x₂ : A₂(x₁), ...) is a nested Σ-type of dependent types. A **substitution** σ : Δ → Γ is a morphism between contexts.

Hardware correspondences:
- Context = current FSM phase + index state
- Substitution = index transformation accompanying a phase transition
- Dependent type = valid index range that varies with phase

### 9.5 Σ and Π as Adjunctions

The dependent sum and dependent product are not independent operations — they form an **adjoint triple** with substitution (base change). For a morphism f : Δ → Γ in the context category:

```
Σ_f  ⊣  f*  ⊣  Π_f
```

where:
- f* : Ty(Γ) → Ty(Δ) is **substitution** — pulling a type back along f
- Σ_f : Ty(Δ) → Ty(Γ) is **dependent sum** — existential quantification along f
- Π_f : Ty(Δ) → Ty(Γ) is **dependent product** — universal quantification along f

This is the same general background as the presheaf-level `f_! ⊣ f* ⊣ f_*`. The point is that changing context and quantifying over fibers are linked operations.

In the setting of this repository:

- `Σ (p : Phase), F(p)` is the direct type-theoretic analogue of the total legal control space
- a family of data or proofs indexed by every phase would be Π-shaped
- `IndexInvariant` itself is not the Π-type; it is a predicate on `State` expressing membership in the Σ-shaped total space

The guard-cycle lemmas can be read as local compatibility facts for these phase-dependent fibers. That is the level at which the adjoint-triple background is relevant here.

---

## 10. Temporal Logic and Presheaves

### 10.1 Temporal Logic Fundamentals

Temporal logic deals with propositions that change over time.

| Symbol | Name | Meaning |
|--------|------|---------|
| **G** φ | Globally | φ at all future time points |
| **F** φ | Eventually / Future | φ at some future time point |
| **X** φ | neXt | φ at the immediately next time point |
| φ **U** ψ | Until | φ holds until ψ becomes true |

### 10.2 LTL and CTL

**LTL (Linear Temporal Logic)**: temporal properties over a single execution trace. Introduced by Pnueli (1977). The standard for specifying reactive systems.

**CTL (Computation Tree Logic)**: temporal properties over a branching execution tree. Uses path quantifiers A (all paths) and E (some path).

The TLSF specification in this repository uses LTL:

```
G(!reset && phase_idle && start -> X phase_load_input)
G(!reset && phase_mac_hidden && guard -> X phase_bias_hidden)
```

### 10.3 Presheaf Interpretation of Temporal Logic

LTL formulas admit a presheaf-style interpretation, and after reversing the time category they can be phrased in the internal logic of the presheaf topos **Set**^(**ℕ**ᵒᵖ).

Given a time-indexed trace T : **ℕ** → **State**:
- **G** φ is `∀ n : ℕ, φ(T(n))` — global truth along the trace
- **F** φ is `∃ n : ℕ, φ(T(n))` — existential quantification along the trace
- **X** φ is `φ(T(n+1))` — evaluation at the successor
- φ **U** ψ is `∃ k, ψ(T(k)) ∧ ∀ j < k, φ(T(j))` — bounded universal + existential

The temporal theorems in this repository are Lean proof versions of this interpretation:

```lean
-- G(active → busy): busy always holds during the active window
theorem busy_during_active_window ... (k : Fin totalCycles) (hpos : 0 < k.1) :
    busyOf (rtlTrace samples k.1)

-- F done: done is eventually reached
theorem acceptedStart_eventually_done ... :
    doneOf (rtlTrace samples totalCycles)
```

```mermaid
graph LR
    subgraph "Temporal logic as presheaf statements"
        direction LR
        C0["cycle 0<br/>idle"]
        C1["cycle 1<br/>load"]
        C2["cycle 2<br/>active"]
        CD["..."]
        C75["cycle 75<br/>active"]
        C76["cycle 76<br/>done"]

        C0 --> C1 --> C2 --> CD --> C75 --> C76
    end

    C2 -.- B1["busy = true"]
    CD -.- B2["busy = true"]
    C75 -.- B3["busy = true"]
    C76 -.- D["done = true<br/>output valid"]

    B1 -.- G["G(active → busy)<br/>always busy during [2,75]"]
    D -.- F["F(done)<br/>eventually done at 76"]

    style C76 fill:#d4edda
    style G fill:#fff3cd
    style F fill:#fff3cd
```

### 10.4 Modal Logic and Kripke Semantics

Modal logic is a generalization of temporal logic. In Kripke semantics:
- A set W of possible worlds
- An accessibility relation R ⊆ W × W
- □φ: φ holds in all R-accessible worlds
- ◇φ: φ holds in some R-accessible world

In temporal logic, W = ℕ (time), R = successor relation. In hardware, W = reachable states, R = FSM transitions.

A Kripke frame (W, R) gives the standard relational semantics for modal logic. By passing to the category/poset generated by that accessibility structure and then considering presheaves on it, one obtains a related categorical semantics. In that sense, the modal operators □, ◇ can be compared with universal/existential structure in an internal-logic setting.

### 10.5 Connection to Hoare Logic

A Hoare triple {P} C {Q} in Hoare logic means "if precondition P holds and program C is executed, then postcondition Q holds."

The correspondence in this repository:

```
{phase = idle ∧ start = true}   -- precondition P
  run totalCycles                -- program C (76 cycles)
{phase = done ∧ output = mlpFixed(input)}  -- postcondition Q
```

This is the combination of `rtl_correct` and `acceptedStart_eventually_done`. Hoare logic and temporal logic meet here: Hoare logic addresses the input-output relation, while temporal logic addresses the temporal properties of intermediate steps.

Dynamic logic unifies modal logic and Hoare logic: [C]φ = "after executing C, φ necessarily holds." This is a program-indexed version of the necessity operator □.

```mermaid
graph TB
    subgraph "Three logics, one machine"
        direction TB
        subgraph hoare["Hoare logic"]
            PRE["{idle ∧ start}"]
            PROG["run 76 cycles"]
            POST["{done ∧ correct output}"]
            PRE --> PROG --> POST
        end
        subgraph temporal["Temporal logic"]
            SAFE["G(active → busy)"]
            LIVE["F(done)"]
            STABLE["G(done → output stable)"]
        end
        subgraph modal["Modal logic"]
            BOX["□(start → ◇done)<br/>necessarily, start leads to<br/>possibly done"]
        end
    end

    hoare -.->|"what is computed"| RESULT["Functional<br/>correctness"]
    temporal -.->|"when it happens"| TIMING["Timing<br/>guarantees"]
    modal -.->|"across all worlds<br/>(environments)"| UNIV["Universal<br/>quantification"]
```

---

## 11. Arithmetic Theories and the Grothendieck Construction

### 11.1 Three Arithmetic Theories

| Theory | Language | Axioms | Decidability |
|--------|----------|--------|-------------|
| Presburger arithmetic | (ℕ, 0, S, +) | Axioms for addition + induction schema | **Decidable** |
| Robinson arithmetic Q | (ℕ, 0, S, +, ×) | Basic axioms for addition and multiplication (no induction) | Incomplete |
| Peano arithmetic PA | (ℕ, 0, S, +, ×) | Axioms for addition and multiplication + induction schema | Incomplete |

### 11.2 Their Place in Hardware Verification

**Presburger arithmetic**: index range checks, counter boundaries, linear inequalities. The SMT solver's `omega` decision procedure completely decides this domain. In this repository, index invariants like "inputIdx < 4" and "hiddenIdx ≤ 7" live in Presburger arithmetic.

**Robinson arithmetic**: the world changes the moment multiplication enters. `w1[i,j] * x[j]` is not free multiplication but multiplication by a fixed constant; however, in general, the inclusion of multiplication brings Gödel incompleteness.

**Peano arithmetic**: proofs where induction is essentially required. In this repository, `rtlTrace_preserves_indexInvariant` is proved by induction on the natural number n and lies in the domain of Peano arithmetic.

### 11.3 Categorical Reinterpretation

Each arithmetic theory can be viewed as a categorical object. For a theory T, one constructs the **syntactic category** **Syn**(T):
- Objects: formulas (contexts) of T
- Morphisms: provably functional relations in T

A model is a functor F_T : **Syn**(T) → **Set**. The model endows the syntactic structure with set-theoretic meaning.

**Connection to the Grothendieck construction**: consider the context category **Ctx**(T) and, for each context Γ, the set of formulas (types) definable in Γ:

```
F : Ctx(T)ᵒᵖ → Set
F(Γ) = { φ | φ is a formula in context Γ }
```

The Grothendieck construction ∫F of this functor is the totality of "context + formula" pairs, and the projection π : ∫F → **Ctx**(T) extracts the context from each pair. This is the **fibration of logic**.

### 11.4 Comparing Fibers Across Presburger, Robinson, and Peano

| Theory | Fiber F(Γ) characteristics | Automation potential |
|--------|---------------------------|---------------------|
| Presburger | Linear inequalities → decidable by QE | Fully automated (SMT `omega`) |
| Robinson | Includes multiplication → representable but incomplete | Partially automated (bit-blasting) |
| Peano | Requires induction → incomplete but powerful | Semi-automated (tactics + user guidance) |

The QF_BV (quantifier-free bitvector) proofs in this repository are essentially finite-width Presburger-like decision procedures. In bitvector arithmetic, multiplication by a fixed constant reduces to repeated addition and is therefore decidable.

```mermaid
graph TB
    subgraph "Three arithmetic theories — three levels of power"
        direction LR
        subgraph presb["Presburger<br/>(+, no ×)"]
            P1["inputIdx < 4 ?"]
            P2["hiddenIdx ≤ 7 ?"]
            P3["✓ DECIDABLE<br/>omega solves it"]
        end
        subgraph robin["Robinson Q<br/>(+, ×, no induction)"]
            R1["w * x = ?"]
            R2["overflow?"]
            R3["⚠ INCOMPLETE<br/>bit-blasting helps"]
        end
        subgraph peano["Peano PA<br/>(+, ×, induction)"]
            PA1["∀ n, invariant(n)<br/>→ invariant(n+1)"]
            PA2["✓ POWERFUL<br/>but still incomplete"]
        end
    end

    presb -->|"add ×"| robin -->|"add induction"| peano

    presb -.-> SMT["SMT omega tactic"]
    robin -.-> Z3["Z3 QF_BV"]
    peano -.-> LEAN["Lean induction proofs"]
```

---

## 12. Quotient Ring Geometry and Fixed-Point Arithmetic

### 12.1 Correspondence Between Two Models

The MLP forward-pass computation is a term in integer linear arithmetic. This term is evaluated in two models:

| Model | Domain | Arithmetic | Lean counterpart |
|-------|--------|-----------|-----------------|
| ℤ (spec) | Unbounded integers | Standard | `mlpSpec` |
| ℤ/2ⁿℤ (fixed-point) | Finite bitvectors | Modular (wrapping at each step) | `mlpFixed` |

### 12.2 Injectivity of the Quotient Map

```mermaid
graph LR
    subgraph "Quotient map: ℤ → ℤ/2ⁿℤ"
        direction TB
        subgraph unbounded["ℤ (unbounded)"]
            Z1["..., -200, ..., 0, ..., 150, ..., 40000, ..."]
        end
        subgraph bounded["ℤ/2³²ℤ (32-bit)"]
            B1["-2³¹  ...  0  ...  2³¹-1"]
        end
        subgraph safe["Safe range (actual values)"]
            SAFE["all intermediates<br/>land HERE<br/>wrapping never fires"]
        end

        unbounded -->|"quotient map q"| bounded
        safe -->|"⊂"| bounded
    end

    style safe fill:#d4edda,stroke:#28a745
```

Key theorem: for the frozen weights, the quotient map ℤ → ℤ/2ⁿℤ is **injective** on the actual computation range.

```lean
theorem mlpFixed_eq_mlpSpec (input : Input8) :
    mlpFixed input = mlpSpec (toMathInput input)
```

This means wrapping never activates. Two's-complement wrapping is declared in the model but never an active part of the computation. See [`from-ann-to-proven-hardware.md` §5](from-ann-to-proven-hardware.md) for the proof layers and [`solver-backed-verification.md` §5](solver-backed-verification.md) for the QF_BV wide-sum checks that confirm this at the bitvector level.

### 12.3 Categorical Interpretation

The quotient map q : ℤ → ℤ/2ⁿℤ is a ring homomorphism. Categorically:

- ℤ and ℤ/2ⁿℤ are objects in the category **Ring**
- q : ℤ → ℤ/2ⁿℤ is a morphism in **Ring**
- An "injective range" means a chosen subset on which q has no collisions; it is not the complement of the kernel

In the layer-by-layer MLP computation, each layer operates at a different bit width:

```
16-bit: hidden products (int8 × int8)
32-bit: accumulator (hidden MAC sums)
24-bit: output products (int16 × int8)
32-bit: output score (output MAC sums)
1-bit:  final decision (score > 0)
```

This is a **tower of quotient maps**:

```
ℤ → ℤ/2¹⁶ℤ → ℤ/2³²ℤ → ℤ/2²⁴ℤ → ℤ/2³²ℤ → ℤ/2¹ℤ
```

Whether the two views (contract view and RTL view) produce the same result at each layer is verified by a compositional miter. The correct composition of this tower is ultimately confirmed by the `out_bit` equivalence.

```mermaid
graph TB
    subgraph "Tower of quotient maps — compositional miter"
        direction TB
        L1["int8 × int8 → int16<br/>hidden products"]
        L2["Σ(int16) → int32<br/>hidden accumulator"]
        L3["ReLU: int32 → int16<br/>hidden activation"]
        L4["int16 × int8 → int24<br/>output products"]
        L5["Σ(int24) → int32<br/>output score"]
        L6["int32 > 0 → bit<br/>out_bit"]

        L1 -->|"✓ same"| L2
        L2 -->|"✓ same"| L3
        L3 -->|"✓ same"| L4
        L4 -->|"✓ same"| L5
        L5 -->|"✓ same"| L6
    end

    L6 --> SAME["out_bit identical<br/>under both views"]
    style SAME fill:#d4edda
```

### 12.4 Fibered Interpretation

In Sparkle's `encodeState`, quotient arithmetic meets Grothendieck structure. The encoding must:

1. Place each intermediate value in the correct BitVec representable range (quotient geometry)
2. Simultaneously land in the correct phase fiber (Grothendieck construction)

If an encoded index drifts out of the target fiber at a guard-cycle boundary, the refinement proof fails at precisely that transition.

---

## 13. Reactive Synthesis and Game Semantics

### 13.1 Pnueli's Program

Starting from the temporal logic introduced by Pnueli (1977), Pnueli and Rosner (1989) posed the **reactive synthesis** problem: given a temporal specification, automatically construct a system that satisfies it against all environment behaviors.

This is a **game-theoretic view**:
- Environment: chooses inputs
- System: chooses outputs
- Winning condition: an infinite game satisfying the temporal specification φ

### 13.2 GR(1) Synthesis

GR(1) (Generalized Reactivity 1) is a practical subclass of reactive synthesis. It is solvable in polynomial time when the specification has the form:

```
(GF p₁ ∧ ... ∧ GF pₘ) → (GF q₁ ∧ ... ∧ GF qₙ)
```

where GF means "infinitely often."

The TLSF specification in this repository uses only the safety fragment of GR(1) — all constraints have the form `G(condition → X consequence)`. See [`generated-rtl.md` §1–§7](generated-rtl.md) for the full reactive synthesis pipeline, predicate abstraction, and dual validation strategy.

### 13.3 Categorical Connection

The game semantics of reactive synthesis and the Lean proofs in this repository are two approaches to the **same universally quantified statement**:

```
∀ (samples : ℕ → CtrlSample), acceptedStart ... → doneOf (rtlTrace samples totalCycles)
```

- **GR(1) synthesis**: **constructs** a winning strategy for the system (constructive)
- **Lean proof**: **verifies** that a specific system wins against all environments (analytic)

Type-theoretically, this universal quantification is a dependent product (Π-type):

```
Π(samples : ℕ → CtrlSample), acceptedStart ... → doneOf (rtlTrace samples totalCycles)
```

A constructive proof constructs an element of this Π-type, and game-theoretic synthesis constructs a function — the winning strategy.

```mermaid
graph TB
    subgraph "Same universal statement, two approaches"
        direction TB
        STMT["∀ environments,<br/>start accepted → done at 76"]

        subgraph synth["Reactive synthesis (constructive)"]
            SPEC["TLSF spec"] --> TOOL["ltlsynt"] --> CTRL["synthesized controller<br/>= winning strategy"]
        end
        subgraph verify["Lean verification (analytic)"]
            MODEL["step/timedStep model"] --> PROOF["induction + case analysis"] --> THM["kernel-checked theorem"]
        end
    end

    STMT --> synth
    STMT --> verify

    style CTRL fill:#d4edda
    style THM fill:#d4edda
```

### 13.4 Predicate Abstraction and Fibration

The core technique in the reactive synthesis branch is **predicate abstraction**. It abstracts 4-bit counter buses into boolean predicates:

```
input_idx[3:0]  →  { hidden_mac_active, hidden_mac_guard,
                     output_mac_active, output_mac_guard, last_hidden }
```

This admits a **fibrational reading**. The full state space (9 phases × 16 × 16 counter values) projects onto a boolean predicate base. Since control decisions depend only on the base, this mirrors the same control-relevant abstraction pattern discussed in §7 — only Lean's `controlOf` and TLSF's predicate abstraction express it in different languages.

### 13.5 A Game-Semantic Lens

Reactive synthesis invites a game-semantic reading. The environment supplies input behavior, the system responds with control outputs, and the temporal specification marks which infinite traces count as winning.

With that lens:

- `ltlsynt` searches for a winning controller strategy
- the Lean theorem from §13.3 verifies that a particular machine meets the same universally quantified obligation over all environment behaviors
- predicate abstraction can be viewed as reducing a larger control problem to a smaller control-relevant one

This is a useful **conceptual bridge** to the game-semantics literature, but the repository does not define a full strategy category, identify strategies with functors `Env → Sys`, or reduce realizability to non-emptiness of a specific Hom-set. The precise formal content used here remains the universally quantified statement from §13.3:

```
∀ (samples : ℕ → CtrlSample), acceptedStart ... → doneOf (rtlTrace samples totalCycles)
```

Synthesis approaches that obligation constructively by building a controller; verification approaches it analytically by proving that a fixed controller satisfies it. Abramsky–Jagadeesan-style game semantics is relevant as background, but it is not the formal API used in this repository.

---

## 14. The Sheaf Condition and the Local-to-Global Principle

### 14.1 What Is a Sheaf

Given a Grothendieck topology J on a category **C**, a presheaf F : **C**ᵒᵖ → **Set** is a **sheaf** if for every covering sieve S ∈ J(c), every S-compatible family extends uniquely.

Intuition: locally compatible data can be glued into a global whole.

### 14.2 The Local-to-Global Principle in Hardware Verification

The verification in this repository is a practical application of the local-to-global principle:

**Local proofs**:
- Index preservation at each phase transition (`step_preserves_indexInvariant`)
- Overflow safety at each neuron (`hiddenSpecAt_bounds`)
- No-work proof at each guard cycle (`hiddenGuard_no_mac_work`)

**Global conclusions**:
- Index safety across the entire trace (`rtlTrace_preserves_indexInvariant`)
- Correctness over 76 cycles (`rtl_correct`)
- Temporal correctness of the full transaction (`acceptedStart_eventually_done`)

This assembly process is not literally a proved sheaf condition on a chosen site, but it is a sheaf-like local-to-global pattern: if local data (proofs at each transition) are compatible (each transition connects), they glue into a global proof.

```mermaid
graph LR
    subgraph "Local-to-global: sheaf-like assembly of proofs"
        direction LR
        subgraph local["Local proofs (per-transition)"]
            L1["step preserves<br/>invariant"]
            L2["guard: no<br/>spurious MAC"]
            L3["neuron k:<br/>no overflow"]
        end
        subgraph glue["Gluing (induction)"]
            G1["all transitions<br/>connect"]
        end
        subgraph global["Global theorems"]
            G2["rtlTrace preserves<br/>invariant ∀ n"]
            G3["rtl_correct<br/>(76 cycles)"]
            G4["acceptedStart<br/>eventually done"]
        end

        L1 --> G1
        L2 --> G1
        L3 --> G1
        G1 --> G2
        G1 --> G3
        G1 --> G4
    end

    style G2 fill:#d4edda
    style G3 fill:#d4edda
    style G4 fill:#d4edda
```

### 14.3 Relationship Between the Grothendieck Construction and Sheaves

The Grothendieck construction ∫F of a presheaf F : **C**ᵒᵖ → **Set** is the total category. In genuine sheaf theory, the sheaf condition is a gluing statement for compatible local sections over a chosen site. In this repository, the comparison is heuristic: guard-cycle compatibility and induction play the role of gluing data.

In the context of this repository:
- Base category **C** = phase category (FSM transition graph)
- Fiber F(p) = legal index space for phase p
- Gluing condition = boundary conditions of adjacent phases are compatible (guard cycle proofs)

---

## 15. The Bridge Theorem and Partial Natural Isomorphism

### 15.1 Two Functors

One of the key structures in this repository is the existence of two state evolutions:

```
R : ℕ → State       R(n) = run n (initialState input)
T : ℕ → State       T(n) = rtlTrace samples n
```

R is the **operational** model — self-contained, ignoring the environment.
T is the **reactive** model — accepting environment input at every cycle.

### 15.2 Partial Natural Isomorphism

The bridge theorem says R and T agree on the interval [2, 76]:

```lean
theorem rtlTrace_matches_run_after_loadInput (samples : Nat → CtrlSample)
    (hstart : (samples 0).start = true) :
    ∀ n, n + 2 ≤ totalCycles →
      rtlTrace samples (n + 2) = run (n + 2) (initialState (capturedInput samples))
```

This is a **partial natural isomorphism**. R and T:
- Differ at n ∈ {0, 1} (different handling of start/loadInput)
- Agree at n ∈ [2, 76] (active computation window)
- Differ at n > 76 (hold/release vs. fixed point)

The enabling condition is the **active window lemma**: at n ∈ [2, 75], the phase is active (neither idle nor done), so `timedStep` degenerates to `step` and the natural transformation becomes the identity.

Categorically, this is a natural transformation η between two functors R, T : **ℕ** → **State** that is a natural isomorphism on a partial interval. This partial isomorphism is the bridge connecting functional correctness to temporal correctness.

```mermaid
graph LR
    subgraph "Two models: R (operational) vs T (reactive)"
        direction LR
        subgraph diverge1["Diverge: cycles 0-1"]
            R0["R: step from<br/>initial state"]
            T0["T: handle start<br/>+ capture input"]
        end
        subgraph agree["AGREE: cycles 2-76"]
            RT["R(n) = T(n)<br/>timedStep = step<br/>(env ignored)"]
        end
        subgraph diverge2["Diverge: cycle 77+"]
            R77["R: step is<br/>fixed point"]
            T77["T: handle<br/>hold/release"]
        end

        diverge1 --> agree --> diverge2
    end

    agree -.- BRIDGE["Bridge theorem:<br/>partial natural isomorphism<br/>on [2, 76]"]

    style agree fill:#d4edda
    style BRIDGE fill:#fff3cd
```

---

## 16. Lean's Calculus of Inductive Constructions and Category Theory

### 16.1 CIC and Topoi

The logical foundation of Lean 4 is the **Calculus of Inductive Constructions (CIC)**. CIC is a form of dependent type theory featuring:

- Dependent products Π(x : A), B(x) — universal quantification / function types
- Dependent sums Σ(x : A), B(x) — existential quantification / pair types
- Inductive types — definitions of natural numbers, lists, trees, etc.
- Universes — Type, Prop

The semantics of CIC is given in **locally Cartesian closed categories (LCCCs)**. Every Grothendieck topos is an LCCC, so it can provide a model of CIC.

### 16.2 The Grothendieck Construction in Lean

In Lean, the Grothendieck construction appears directly in the form of dependent types:

```lean
-- Functor F : Phase → Set
def IndexSpace : Phase → Type
  | .macHidden  => { p : Nat × Nat // p.1 < 8 ∧ p.2 ≤ 4 }
  | .biasHidden => { p : Nat × Nat // p.1 < 8 ∧ p.2 = 4 }
  -- ...

-- Grothendieck construction ∫F = Σ(p : Phase), IndexSpace p
def LegalControlConfig := Σ (p : Phase), IndexSpace p
```

`IndexInvariant` is the characteristic function of this dependent sum, and `step_preserves_indexInvariant` proves that `step` is an endomorphism of this dependent sum.

### 16.3 Comparison with Coq and Isabelle

| System | Logical foundation | Grothendieck construction representation | Automation |
|--------|-------------------|------------------------------------------|-----------|
| Lean 4 | CIC (Inductive Constructions) | Σ-types + match | `omega`, `native_decide`, `simp` |
| Coq | CIC (Calculus of Constructions) | Σ-types + dependent pattern matching | `omega`, `lia`, `auto` |
| Isabelle/HOL | HOL (Higher-Order Logic) | Records + locales | `auto`, `sledgehammer` |

One reason this repository chose Lean is that dependent types naturally express the phase-dependent invariants of the Grothendieck construction. In HOL, which lacks dependent types, these must be encoded as predicates.

---

## 17. SMT and Decidable Fragments

### 17.1 SAT and SMT

**SAT**: satisfiability of propositional logic formulas — NP-complete but practically solvable

**SMT (Satisfiability Modulo Theories)**: satisfiability of first-order formulas with background theories (linear arithmetic, bitvectors, arrays, etc.)

### 17.2 QF_BV and Presburger Arithmetic

The contract proofs in this repository use **QF_BV (quantifier-free bitvector)** logic. QF_BV is quantifier-free arithmetic over finite-width bitvectors.

Multiplication by a fixed constant `w * x` (w constant, x variable) reduces to repeated addition `x + x + ... + x`. Therefore, the MLP forward pass with frozen weights yields a decidable **QF_BV** problem built from fixed-width additions and constant multiplications. Z3's bit-blasting decision procedure is complete for the resulting QF_BV formulas.

### 17.3 Bounded Model Checking and Category Theory

Bounded model checking (BMC) unrolls the transition relation to depth k and checks all reachable states. Categorically:

```
BMC_k = ∀ (trace : Fin k → State),
          valid_trace(trace) → ∀ i, property(trace i)
```

Here `Fin k` is {0, 1, ..., k-1}. This is universal quantification over the finite category **Fin k**.

The SMT bounded model checking in this repository (depth 82) is universal quantification over **Fin 82**. Lean's temporal theorems are universal quantification over **ℕ** (infinite, by induction). Both are assertions about sections of presheaves, but over base categories of different size.

---

## 18. Fibrations, Stacks, and Descent

### 18.1 Fibrations

A functor π : **E** → **B** is a **fibration** if, for every morphism f : b → b' and every object e' over the codomain of f, a Cartesian lift exists.

The Grothendieck construction ∫F → **C** naturally yields a split fibration. Conversely, a split fibration determines a functor F : **C** → **Cat**, and this correspondence is the **Grothendieck correspondence**.

### 18.2 Fibration Interpretation in Hardware

Three fibrations in this repository:

**1. Control-data fibration** (§7)

```
State → ControlState
```

Base: FSM control state (phase, indices)
Fiber: datapath values (registers, accumulator, hidden activations)

**2. Index invariant fibration** (§6.4)

```
∫F → Phase
```

Base: FSM phase
Fiber: legal index space per phase

**3. Arithmetic fibration** (§12.4)

```
ℤ → ℤ/2ⁿℤ
```

Base: finite bitvector representation
Fiber: equivalence classes of integers with the same bit representation

```mermaid
graph TB
    subgraph "Three fibrations in this repository"
        direction TB
        subgraph fib1["1. Control-data fibration"]
            STATE1["State<br/>(phase + idx + acc + regs + hidden)"]
            CTRL1["ControlState<br/>(phase + idx)"]
            STATE1 -->|"controlOf<br/>(forget data)"| CTRL1
        end
        subgraph fib2["2. Index invariant fibration"]
            TOTAL1["∫F<br/>(phase, legal indices)"]
            PHASE1["Phase"]
            TOTAL1 -->|"π<br/>(forget indices)"| PHASE1
        end
        subgraph fib3["3. Arithmetic fibration"]
            INTEGERS["ℤ<br/>(unbounded)"]
            BITVEC["ℤ/2ⁿℤ<br/>(bitvectors)"]
            INTEGERS -->|"quotient map q<br/>(mod 2ⁿ)"| BITVEC
        end
    end
```

### 18.3 Relationship to Stacks

A stack is "fibration + descent condition." Descent is the categorified version of the sheaf condition: locally defined objects glue into a global object, uniquely up to isomorphism.

In this repository, the three RTL implementations (hand-written, reactive synthesis, Sparkle) meeting at the same `mlp_core` boundary are better understood as a descent-flavored analogy: they have different internal structures but are compared on a shared observable interface.

```mermaid
graph TB
    subgraph "Descent: three implementations, one boundary"
        direction TB
        subgraph hw["Hand-written (rtl)"]
            HW_INT["Layered modules<br/>controller + mac + relu + rom"]
        end
        subgraph syn["Reactive synthesis (rtl-synthesis)"]
            SYN_INT["Synthesized controller<br/>+ symlinked datapath"]
        end
        subgraph spk["Sparkle (rtl-formalize-synthesis)"]
            SPK_INT["Monolithic 5585-line<br/>generated core + wrapper"]
        end

        BOUNDARY["mlp_core port interface<br/>(shared boundary)"]

        HW_INT --> BOUNDARY
        SYN_INT --> BOUNDARY
        SPK_INT --> BOUNDARY
    end

    BOUNDARY --> EQUIV["All three produce<br/>same observable behavior"]

    style BOUNDARY fill:#fff3cd,stroke:#d4a843
    style EQUIV fill:#d4edda
```

Internally different, externally the same — like three open sets that look different locally but agree on their overlaps. That agreement is descent-flavored rather than a literal descent theorem. See [`generated-rtl.md` §16–§22](generated-rtl.md) for the structural comparison and trust analysis of the three implementations.

---

## 19. HDL Semantics and Category Theory

### 19.1 Two Levels of HDL

HDL (Hardware Description Language) is a language for describing hardware. The core distinction in SystemVerilog:

- `always_comb`: combinational logic — pure functions (§4)
- `always_ff @(posedge clk)`: sequential logic — state transitions (§5)

### 19.2 Categorical Semantics of the Sparkle Signal DSL

```mermaid
graph LR
    subgraph "HDL two-level structure"
        direction TB
        subgraph comb["always_comb — combinational"]
            COMB_IN["inputs"] --> COMB_F["pure function f"] --> COMB_OUT["outputs"]
        end
        subgraph seq["always_ff @(posedge clk) — sequential"]
            SEQ_STATE["state(t)"]
            SEQ_IN["input(t)"]
            SEQ_NEXT["state(t+1) = δ(state(t), input(t))"]
            SEQ_STATE --> SEQ_NEXT
            SEQ_IN --> SEQ_NEXT
        end
    end

    comb -.->|"no memory<br/>= morphism"| CAT1["CCC morphism"]
    seq -.->|"state over time<br/>= stream / presheaf-style semantics"| CAT2["Time-indexed semantics"]
```

Sparkle's `Signal dom α` is a time-indexed stream:

```lean
-- Signal.atTime t: extract value at cycle t
-- Signal.register init next: register — initial value + next-state function
-- Signal.loop: recursive signal definition (feedback loops)
-- hw_cond: multiplexer (synthesizable conditional)
```

Categorically:
- `Signal dom α` = time-indexed signal, with a presheaf-style reading after reversing time
- `Signal.register` = explicit one-cycle state delay / register
- `Signal.loop` = explicit feedback operator on signals
- `hw_cond` = case split / mux, suggestive of coproduct structure

A further state/observation lens from §5.5 can also be applied to Sparkle. `Signal.register` and `Signal.loop` make state evolution and feedback explicit, while observable views (`done`, `busy`, `out_bit`, packed outputs) are read-only projections of the signal state.

This is semantic intuition rather than a proved monad/comonad interface for Sparkle. The repository does not formalize Sparkle registers as monad algebras or prove coKleisli laws for these observations.

```
Signal.register  ↔  explicit register / state update
Signal.loop      ↔  explicit feedback
hw_cond          ↔  case split on a condition
view extraction  ↔  read-only projection of signal state
```

The synth-path refinement theorem `sparkleMlpCoreStateSynth_refines_rtlTrace` says something more concrete and weaker than a monad-algebra statement: at each time index, the actual Sparkle `Signal.loop` state agrees with `encodeState (rtlTrace ...)`. That pointwise state correspondence is the formal content used by the repository.

### 19.3 Synthesis and Place & Route

Yosys synthesis transforms HDL into a gate netlist. This is categorically a **functor** Synth : **HDL** → **Gate**, where:

- **HDL** = category of HDL descriptions (objects: modules, morphisms: instantiations)
- **Gate** = category of gate netlists (objects: netlists, morphisms: subcircuit inclusions)

Yosys's SMT formalization operates on the image of this functor:

```
HDL →^{Synth} Gate →^{SMT2} SMT-LIB →^{Z3} {sat, unsat}
```

The `yosys-smtbmc` in this repository performs bounded model checking on the result of Synth. See [`solver-backed-verification.md` §3](solver-backed-verification.md) for the full semantics of bounded model checking and the four RTL property families.

```mermaid
graph LR
    subgraph "BMC (bounded) vs Lean (unbounded)"
        direction TB
        subgraph bmc["SMT bounded model checking"]
            FIN["Fin 82<br/>(finite unrolling)"]
            FIN --> PROP1["∀ inputs at each cycle,<br/>property holds"]
            PROP1 --> CAVEAT["⚠ Cannot see<br/>beyond depth 82"]
        end
        subgraph lean["Lean induction proofs"]
            NAT["ℕ<br/>(infinite, by induction)"]
            NAT --> PROP2["∀ n : ℕ,<br/>property holds"]
            PROP2 --> CAVEAT2["⚠ Over model,<br/>not real Verilog"]
        end
    end

    bmc -.->|"real Verilog<br/>bounded depth"| IMPL["Implementation<br/>fidelity"]
    lean -.->|"model<br/>unbounded depth"| SEMANTIC["Semantic<br/>depth"]

    style IMPL fill:#cce5ff
    style SEMANTIC fill:#cce5ff
```

---

## 20. Synthesis: A Mathematical Map of Hardware Verification

### 20.1 The Full Picture

```mermaid
graph TB
    subgraph "Grothendieck Construction ∫F"
        direction TB
        PHASE["Base: Phase (FSM phases)"]
        FIBER["Fiber: F(p) (legal indices per phase)"]
        TOTAL["Total: ∫F = Σ(p : Phase), F(p)"]
        PHASE --> FIBER --> TOTAL
    end

    subgraph "Cartesian Fibration"
        direction TB
        STATE["Full state: State"]
        CTRL["Control state: ControlState"]
        PROJ["Projection π = controlOf"]
        STATE --> PROJ --> CTRL
    end

    subgraph "Presheaf / Temporal Semantics"
        direction TB
        TIME["Base: ℕ (cycles)"]
        TRACE["Presheaf: rtlTrace (state trace)"]
        TEMPORAL["Temporal theorems: G, F, U properties"]
        TIME --> TRACE --> TEMPORAL
    end

    subgraph "Quotient Geometry"
        direction TB
        UNBOUNDED["ℤ (unbounded integers)"]
        BOUNDED["ℤ/2ⁿℤ (bitvectors)"]
        QUOTIENT["Quotient map q : ℤ → ℤ/2ⁿℤ"]
        UNBOUNDED --> QUOTIENT --> BOUNDED
    end

    TOTAL -.-> STATE
    TRACE -.-> STATE
    BOUNDED -.-> FIBER
```

### 20.2 Correspondence Table

| Hardware concept | Categorical counterpart | Realization in this repository |
|-----------------|------------------------|-------------------------------|
| Combinational logic | Morphisms in a CCC | Weight ROM, combinational MAC parts |
| Sequential logic | Time-indexed stream / presheaf-style semantics | `rtlTrace`, `Signal dom α` |
| FSM phase | Object of the base category | `Phase` inductive type |
| Phase transition | Morphism of the base category | `AllowedPhaseTransition` |
| Index invariant | Σ-shaped legal space plus characteristic predicate | `IndexInvariant` |
| Guard cycle | Cross-fiber transition morphism | `hiddenGuard_no_mac_work` |
| Control projection | Fibrational / Cartesian-like reduction | `controlOf` / `controlStep` |
| Moore output | Function on the base | `busyOf`, `doneOf` |
| Mealy output | Function on the total space | `doMacHidden` |
| Synchronous clock | Successor morphism in ℕ | Application of `timedStep` |
| Asynchronous reset | Forced projection to the base | Reset bridging logic |
| Fixed-point arithmetic | Quotient ring ℤ/2ⁿℤ | `mlpFixed`, `wrap16`, `wrap32` |
| Overflow safety | Injectivity of the quotient map | `mlpFixed_eq_mlpSpec` |
| Temporal properties | Presheaf-style / internal-logic reading | `busy_during_active_window`, etc. |
| BMC (bounded model checking) | Universal quantification over Fin k | yosys-smtbmc depth 82 |
| Reactive synthesis | Construction of a winning strategy | ltlsynt / TLSF |
| Predicate abstraction | Fibrational abstraction pattern | Boolean predicates in TLSF |
| Three RTL implementations | Descent-flavored shared-boundary analogy | `mlp_core` port interface |
| Lean CIC | Internal language of an LCCC | Dependent types + inductive types |
| QF_BV decision | Finite-width Presburger decision | Z3 bit-blasting |
| State updates (registers) | State-transforming computation lens | `Signal.register`, `step` |
| Output observations | Read-only state observation lens | `busyOf`, `doneOf`, view extraction |
| Feedback loops | Explicit feedback / fixed-point intuition | `Signal.loop` |
| Control projection + lifting | Projection plus optional chosen representative | `controlOf` / zero-fill section if chosen |
| ∀/∃ over datapath | General adjoint-triple background `Σ_f ⊣ f* ⊣ Π_f` | Dependent-type semantics |
| Winning strategy | Game-semantic lens on synthesis | ltlsynt controller construction |
| Realizability | Existence of a controller satisfying the spec | ltlsynt `--realizability` check |
| Refinement | Pointwise state correspondence | `sparkleMlpCoreStateSynth_refines_rtlTrace` |

### 20.3 How Everything Connects

```mermaid
graph TB
    subgraph "The big picture: one hardware design, many mathematical lenses"
        direction TB

        HW["Hardware Design<br/>(MLP inference accelerator)"]

        HW --> COMB["§4 Combinational Logic<br/>= CCC morphisms<br/>(ROM, MAC, ReLU)"]
        HW --> SEQ["§5 Sequential Logic<br/>= time-indexed semantics<br/>(rtlTrace)"]
        HW --> FSM_BOX["§6 FSM<br/>= transition category<br/>(Moore + Mealy)"]

        FSM_BOX --> GROTH["§6.4 Grothendieck Construction<br/>∫F = phase-dependent invariant<br/>(IndexInvariant)"]
        FSM_BOX --> CART["§7 Cartesian Fibration<br/>controlOf projection<br/>(finite decidability)"]

        SEQ --> TEMP["§10 Temporal Logic<br/>= presheaf-style internal logic<br/>(G, F, U properties)"]
        SEQ --> BRIDGE["§15 Bridge Theorem<br/>= partial natural iso<br/>(run ↔ rtlTrace)"]

        GROTH --> DEP["§9 Dependent Types<br/>Σ-type = ∫F<br/>(Lean encoding)"]
        GROTH --> SHEAF["§14 Sheaf / Gluing<br/>local proofs → global<br/>(induction)"]
        GROTH --> GUARD["§6.5 Guard Cycles<br/>= cross-fiber transitions"]

        HW --> ARITH["§12 Quotient Geometry<br/>ℤ → ℤ/2ⁿℤ<br/>(mlpFixed = mlpSpec)"]
        ARITH --> SMT["§17 SMT / QF_BV<br/>= finite Presburger<br/>(bit-blasting)"]

        HW --> SYNTH["§13 Reactive Synthesis<br/>= game-theoretic<br/>(∀ env, system wins)"]

        SHEAF --> DESCENT["§18 Descent<br/>three RTL impls<br/>same boundary"]
    end

    style GROTH fill:#f5d6a8,stroke:#c9963a
    style CART fill:#f5d6a8,stroke:#c9963a
    style GUARD fill:#f5d6a8,stroke:#c9963a
    style DEP fill:#f5d6a8,stroke:#c9963a
```

### 20.3.1 Key Relationships in One Sentence Each

1. The **Grothendieck construction** assembles the phase-dependent index spaces of the FSM into a single category.
2. A **fibrational / Cartesian-like reading** captures why control logic is independent of data and why decision on a finite base is possible.
3. **Presheaf-style semantics** provide one categorical reading of state traces over time and temporal logic.
4. **Quotient ring geometry** describes the conditions under which finite-width arithmetic agrees with unbounded arithmetic.
5. A **sheaf-like local-to-global principle** helps explain how the global proof (full trace) is assembled from local proofs (individual transitions).
6. **Dependent types** are the type-theoretic realization of the Grothendieck construction and are expressed naturally in Lean.
7. A **state/observation lens** can be applied to registers and outputs, though the repository does not formalize monad/comonad laws for that lens.
8. The **adjoint triple** `Σ_f ⊣ f* ⊣ Π_f` is useful background for dependent types and quantification, while `native_decide` here relies more directly on control-only properties factoring through `controlOf`.
9. **Game semantics** provides an interpretive perspective on reactive synthesis, but the repository currently uses it as semantic background rather than as a formal strategy category.

---

## 21. Open Questions

The preceding sections organize mathematical structure that is already visible in this repository. They also point toward several open directions that are still better understood as open questions than as established results. A longer companion note is available at [`research/hardware-mathematics-open-questions.md`](research/hardware-mathematics-open-questions.md).

### 21.1 Smaller Topics

- make the current sheaf/descent language literal rather than heuristic
- extend the single-transaction `run` / `rtlTrace` bridge to multi-transaction semantics
- formalize abstraction/concretization between `controlOf` and TLSF predicate abstraction
- understand the boundary where control becomes data-dependent
- generalize quotient geometry beyond the injective-safe overflow regime

### 21.2 Larger Topics

- recast the machine and branch equivalence story coalgebraically
- move from closed-system semantics to open-system composition laws
- enrich the semantics of time beyond plain discrete traces over `ℕ`
- compare synthesis artifacts and proof objects more directly

The first three smaller topics are the ones most directly tied to the repository's current proof artifacts. The companion note above gives the detailed mathematical framing and literature map.

---

## Appendix A. Symbol Reference

| Symbol | Name | Meaning |
|--------|------|---------|
| ∫F | Grothendieck construction | Total category of functor F |
| π : ∫F → **C** | Projection functor | Forgetful functor from total to base |
| F(c) | Fiber | Category/set over base point c |
| Σ(a : A), B(a) | Dependent sum | Type-theoretic counterpart of the Grothendieck construction |
| Π(a : A), B(a) | Dependent product | Universal quantification / function space |
| Ω | Subobject classifier | Internal truth-value object of a topos |
| **Set**^(**C**ᵒᵖ) | Presheaf topos | All presheaves on **C** |
| Sh(**C**, J) | Sheaf topos | Sheaves for Grothendieck topology J |
| ℤ/2ⁿℤ | Quotient ring | n-bit modular arithmetic |
| G φ | Globally | LTL: φ at all future times |
| F φ | Eventually | LTL: φ at some future time |
| X φ | Next | LTL: φ at the next time point |
| {P} C {Q} | Hoare triple | Precondition – program – postcondition |
| □ φ | Necessity | Modal logic: φ in all accessible worlds |
| ◇ φ | Possibility | Modal logic: φ in some accessible world |
| ⊢ | Provable | Derivable in a formal system |
| ⊨ | Satisfies | True in a model |

## Appendix B. Reference Context

| Area | Key figures/results | Role in this document |
|------|--------------------|-----------------------|
| Temporal logic | Pnueli (1977) | Specification language for reactive systems |
| Reactive synthesis | Pnueli–Rosner (1989) | Temporal spec → automatic implementation |
| GR(1) synthesis | Piterman–Pnueli–Sa'ar (2006) | Practical synthesis subclass |
| Grothendieck topos | Grothendieck (SGA 4, 1963–69) | Sheaf categories, internal logic |
| Grothendieck construction | Grothendieck | Totalization of indexed categories |
| Dependent types | Martin-Löf (1971) | Foundation of Lean's CIC |
| Curry–Howard correspondence | Curry (1934), Howard (1969) | Proofs = programs |
| Cartesian fibrations | Grothendieck (SGA 1) | Data-independent control reasoning |
| Presburger arithmetic | Presburger (1929) | Decidable linear arithmetic |
| Gödel incompleteness | Gödel (1931) | Limits of arithmetic with multiplication |
| Monads | Moggi (1991) | Computational effects as monads |
| Store comonad | Uustalu–Vene (2008) | Comonadic models of context-dependent computation |
| Game semantics | Abramsky–Jagadeesan (1994) | Categorical game semantics for linear logic |
| Traced monoidal categories | Joyal–Street–Verity (1996) | Feedback as trace operator |
| BMC | Biere et al. (1999) | Bounded-depth model checking |
| Kripke semantics | Kripke (1959) | Models for modal/temporal logic |
