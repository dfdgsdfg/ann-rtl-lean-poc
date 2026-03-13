# Beginner's Guide to Reactive State Systems and Logical Verification

Date: 2026-03-12

## What This Guide Is

This guide is for readers who are new to:

- reactive systems
- state machines
- temporal reasoning
- formal verification with logic

It explains the basic ideas using this repository's tiny neural inference RTL as the running example.

If you want the deeper theory and tool survey after this guide, read:

- [reactive-state-systems-temporal-logic-ecosystem.md](research/reactive-state-systems-temporal-logic-ecosystem.md)
- [specs/formalize/requirement.md](../specs/formalize/requirement.md)
- [specs/formalize/design.md](../specs/formalize/design.md)

## 1. What Is a Reactive State System?

A reactive state system is a system that:

- receives inputs over time
- keeps internal state
- changes that state step by step
- produces outputs that depend on both current inputs and past history

That is different from a pure mathematical function.

A pure function looks like:

```text
output = f(input)
```

A reactive system looks more like:

```text
next_state, output = step(current_state, input)
```

Examples:

- a traffic-light controller
- a network protocol state machine
- a CPU pipeline controller
- this repository's tiny neural-network RTL controller

## 2. The Running Example in This Repository

The RTL controller in [controller.sv](../rtl/src/controller.sv) moves through these states:

- `IDLE`
- `LOAD_INPUT`
- `MAC_HIDDEN`
- `BIAS_HIDDEN`
- `ACT_HIDDEN`
- `NEXT_HIDDEN`
- `MAC_OUTPUT`
- `BIAS_OUTPUT`
- `DONE`

It also exposes control-style signals:

- `start`
- `busy`
- `done`

This already tells you why ordinary input/output testing is not enough.

The question is not only:

- "Is the final output bit correct?"

It is also:

- "Does the machine enter the right states in the right order?"
- "Does `busy` stay high during active computation?"
- "Does `done` become true only after the output is ready?"
- "Once the machine reaches `DONE`, does the result stay stable?"

Those are time-dependent questions. That is where logic and verification enter.

## 3. The Core Concepts

### 3.1 State

State is all the information the system remembers between steps.

In the Lean model at [Machine.lean](../formalize/src/TinyMLP/Machine.lean), the state includes:

- input registers
- hidden registers
- accumulator
- current hidden index
- current input index
- current FSM phase
- output bit

So the machine is not just "doing math." It is walking through a stored computation.

### 3.2 Transition

A transition is one step from one state to the next.

In Lean, that is:

```lean
def step (s : State) : State := ...
```

If you apply `step` repeatedly, you get an execution.

### 3.3 Trace

A trace is the sequence of states produced over time.

For example:

```text
s0, s1, s2, s3, ...
```

where:

- `s1 = step s0`
- `s2 = step s1`
- and so on

This matters because most interesting properties are really properties of traces, not isolated states.

### 3.4 Invariant

An invariant is something that stays true in every reachable state.

Example:

- indexes never go out of range

This is one of the easiest useful formal properties to understand.

If it fails, the machine may read or write the wrong register slot.

### 3.5 Safety

Safety means:

- something bad never happens

Examples:

- the machine never enters an impossible phase transition
- `done` is never asserted before output computation is complete
- array indexes never leave their valid bounds

### 3.6 Liveness

Liveness means:

- something good eventually happens

Example:

- once a transaction starts, the machine eventually reaches `DONE`

For this repository, the more useful form is bounded liveness:

- once computation starts, `DONE` is reached within a known number of cycles

That is stronger and easier to use than a vague "eventually."

### 3.7 Refinement

Refinement means:

- a lower-level implementation behaves like a higher-level model

In this repository, the rough stack is:

1. mathematical MLP specification
2. fixed-point implementation model
3. RTL-like machine model

The formal goal is not only to prove each layer is internally consistent, but also that the lower layer still matches the intent of the higher one.

## 4. The Simple Math Under the Words

You do not need a large amount of abstract mathematics to start reasoning about reactive systems.

The useful starting objects are very simple.

### 4.1 A set of states

A system has some set of possible states, usually called `S`.

A toy example is:

```text
S = {idle, work, done}
```

A more realistic state is a tuple.

For this repository, you can think of a state roughly as:

```text
s = (phase, hiddenIdx, inputIdx, accumulator, output, ...)
```

where:

- `phase` is one of `idle`, `loadInput`, `macHidden`, ..., `done`
- `hiddenIdx` is a natural number
- `inputIdx` is a natural number
- `accumulator` is an integer
- `output` is a Boolean

So a reactive system is often just a function on tuples.

### 4.2 A transition function

Once you have a state set, the next object is a transition rule.

In the simplest case:

```text
T : S -> S
```

meaning:

```text
next_state = T(current_state)
```

In this repository, the Lean function:

```lean
step : State -> State
```

is exactly this kind of object.

If inputs matter explicitly, then the shape becomes:

```text
T : Input × S -> S
```

or:

```text
R ⊆ S × Input × S
```

if you want a relation instead of a function.

### 4.3 A trace

Once you have `T`, you get a trace by repeated application:

```text
x0, x1, x2, ...
```

with:

```text
x1 = T(x0)
x2 = T(x1)
x3 = T(x2)
```

This is already enough to talk about time.

### 4.4 Predicates as sets of good states

A property of states can be seen as:

- a predicate `P : S -> Bool`, or
- a subset `P ⊆ S`

Example:

```text
Done(s) := phase(s) = done
```

Another example:

```text
IndexSafe(s) := inputIdx(s) and hiddenIdx(s) stay in their valid ranges
```

So when we say "the machine is safe," we are often just saying:

- every reachable state belongs to some good subset of states

### 4.5 Very simple temporal statements

Once you have a trace `x0, x1, x2, ...`, temporal logic becomes much less mysterious.

It is just logic about positions on that trace.

Examples:

```text
AlwaysUpTo(N, P)      := for every t <= N, P(xt)
EventuallyWithin(N,P) := there exists t <= N such that P(xt)
```

Concrete examples:

```text
EventuallyWithin(76, Done)
AlwaysUpTo(76, IndexSafe)
```

These are already real verification statements.

### 4.6 Fixed points and stable states

A fixed point is a state `s*` such that:

```text
T(s*) = s*
```

That means one more step does not change the state.

In the current Lean model, `done` is an absorbing phase:

```text
step(done-state) = done-state
```

This is a simple form of stability.

In engineering language, this often corresponds to:

- settled behavior
- quiescent behavior
- a result that no longer changes unless a new transaction begins

### 4.7 Reachability

A state is reachable if you can get to it by applying the transition rule enough times starting from an initial state.

This is important because verification usually does not care about all mathematically possible tuples.

It cares about the tuples the machine can actually enter.

That is why invariants are usually stated over reachable states.

## 5. Why Ordinary Testing Is Not Enough

Testing is useful, but it has limits.

If you test only final outputs, you can still miss:

- off-by-one errors in FSM transitions
- output becoming valid one cycle too early or too late
- `busy` dropping too soon
- `done` sticking high incorrectly
- hidden state corruption that only appears on rare paths

Reactive systems fail over time, not only at the end.

That is why you need logic that can talk about time and traces.

## 6. Temporal Logic Without the Intimidation

Temporal logic is a way to say things like:

- always
- eventually
- next
- until

over an execution trace.

### 6.1 Common operators

The usual `LTL` operators are:

- `G P`: always `P`
- `F P`: eventually `P`
- `X P`: `P` holds at the next step
- `P U Q`: `P` holds until `Q` holds

You can read them in plain English first.

Examples:

- `G not_error`
- `F done`
- `G (busy -> F done)`

### 6.2 What these mean in this repository

Informally:

- `F done` means the machine eventually finishes
- `G (done -> output_valid)` means whenever the machine says it is done, the result is valid
- `busy U done` means the machine stays busy until it finishes

### 6.3 Why finite-trace operators are enough here

This repository's current proof targets are transaction-sized and bounded.

That means we often do not need a full industrial temporal-logic library.

Instead, a few small operators over bounded runs are enough, such as:

- `AlwaysUpTo N P`
- `EventuallyWithin N P`
- `StableAfter N P`

These are easier for beginners because they match the engineering question directly.

Informal examples:

- "within 76 steps, the machine reaches `done`"
- "for the first 76 steps, indexes stay in range"
- "after `done`, the output bit stays stable"

## 7. Stable Reactive Behavior as Math and Logic

This section is optional, but it gives a clean mathematical meaning to the word "stable."

### 7.1 Stable state as a fixed point

The simplest mathematical meaning of stability is:

- one more step does not change the state

That is the fixed-point equation:

```text
T(s*) = s*
```

If a machine reaches such a state, it has settled.

In the current Lean abstraction, the `done` phase behaves this way:

```text
step(done-state) = done-state
```

This is the clearest beginner definition of a stable state.

### 7.2 Stable region as an absorbing set

Sometimes stability is not about one exact state, but about a whole set of states `A`.

An absorbing set means:

```text
if s is in A, then T(s) is also in A
```

Once the system enters that region, it stays there.

This is useful when:

- internal bookkeeping may still exist
- but the system has already entered its "finished" or "safe" mode

### 7.3 Settling behavior

Another useful idea is that the system settles after some number of steps.

That means:

- after enough transitions, the machine reaches a stable state or stable region

In simple logical form:

```text
there exists N such that xN is stable
```

or more concretely:

```text
within N steps, the machine reaches done
```

This is exactly the kind of property this repository already cares about.

### 7.4 Stable output versus stable internal state

These are not always the same.

Sometimes:

- the internal state may still change
- but the observable output no longer changes

That is also a meaningful form of stability.

Mathematically, you can write it as:

```text
for all t >= N, output(xt) = output(xN)
```

This is an output-stability property over a trace.

For hardware, this is often the most important practical notion:

- the result is stable and safe to observe

even if some internal machine details still move.

### 7.5 What stability means in this repository

For this repository, the most useful mathematical and logical meanings of stability are:

- fixed point: `done` does not change under another `step`
- bounded settling: the machine reaches `done` within a known cycle bound
- output stability: once the result is ready, the output stays the same
- invariant preservation: legal state conditions remain true throughout execution

So the cleanest way to talk about a "stable reactive circuit" here is:

- it evolves through legal states
- it settles into a completed mode
- and its completed result remains stable until a new transaction starts

## 8. A Subtle But Important Repo Detail

The real RTL controller in [controller.sv](../rtl/src/controller.sv) waits for `start`:

```text
IDLE: next_state = start ? LOAD_INPUT : IDLE;
```

The core machine step function in [Machine.lean](../formalize/src/TinyMLP/Machine.lean) still abstracts away external control sampling.

Its `idle` phase moves directly into `loadInput` on the next `step`.

The repository now also has a timing-faithful trace layer in [Temporal.lean](../formalize/src/TinyMLP/Temporal.lean) that models sampled control inputs explicitly through `CtrlSample`, `timedStep`, `acceptedStart`, and `rtlTrace`.

That means:

- the raw machine model is still best understood as "internal computation after acceptance"
- the temporal layer now handles sampled `start`, `done` hold behavior, and return-to-`idle` behavior
- timing-faithful handshake proofs now live in the temporal layer instead of being missing from the repository

This distinction matters. Good verification work is precise about what is modeled and what is abstracted away.

## 9. Three Main Verification Styles

### 9.1 Simulation

Simulation asks:

- "What happens on these example inputs?"

Strengths:

- fast
- concrete
- easy to debug

Weakness:

- it cannot prove all cases

### 9.2 Model checking

Model checking asks:

- "Does this property hold over all reachable executions of this model?"

Strengths:

- can automatically find counterexamples
- very good for control logic and finite-state bugs

Weaknesses:

- state explosion
- sometimes awkward for complex arithmetic or large data paths

### 9.3 Theorem proving

Theorem proving asks:

- "Can we construct a machine-checked proof that the property always holds?"

Strengths:

- strongest kind of assurance
- can express exactly what you mean
- good for connecting high-level math to low-level implementation models

Weakness:

- more manual work

### 9.4 Why these methods complement each other

The normal engineering answer is not "pick one forever."

It is:

- use simulation for examples and regression
- use model checking for fast bug-finding
- use theorem proving for trusted end-to-end claims

That is also the right mental model for this repository.

## 10. What Is Already Being Verified Here

At [Correctness.lean](../formalize/src/TinyMLP/Correctness.lean), the main goals are:

- final output matches the fixed-point model
- the machine reaches `done` within the known total cycle count
- index safety is preserved
- accepted `start` reaches `done` at the required bounded time
- `busy`, `done`, and output validity behave correctly across the active and completed phases

The corresponding shapes are:

```lean
def rtlCorrectnessGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).output = mlpFixed input

def rtlTerminationGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).phase = .done
```

The repository also already includes a temporal layer in [Temporal.lean](../formalize/src/TinyMLP/Temporal.lean) with claims like:

- once execution starts, `done` appears within `N` cycles
- while execution is active, `busy` is true
- once `done` is reached, output stays stable
- the phase sequence cannot skip required stages

## 11. A Simple Way To Think About Proofs

When beginners hear "formal verification," they often imagine proving one giant theorem in one jump.

That is usually the wrong picture.

A more realistic proof structure is:

1. define the state clearly
2. define one-step behavior
3. define repeated execution
4. prove small invariants
5. prove progress or termination
6. prove the final output matches the intended model
7. add timing and stability properties

This is exactly why the repository splits the formalization into:

- spec
- fixed-point model
- machine model
- invariants
- correctness

## 12. Beginner Workflow for This Repository

If you want to learn this repository in a sensible order:

1. Read [README.md](../README.md) for the project overview.
2. Read [controller.sv](../rtl/src/controller.sv) and identify the FSM states.
3. Read [Machine.lean](../formalize/src/TinyMLP/Machine.lean) and map each Lean `Phase` to the RTL state.
4. Read [Temporal.lean](../formalize/src/TinyMLP/Temporal.lean) to see how sampled `start` and bounded traces are modeled.
5. Read [Correctness.lean](../formalize/src/TinyMLP/Correctness.lean) to see the top-level theorems.
6. Read [specs/formalize/requirement.md](../specs/formalize/requirement.md) to see the intended verification scope.
7. Read [reactive-state-systems-temporal-logic-ecosystem.md](research/reactive-state-systems-temporal-logic-ecosystem.md) if you want the broader theory and tool map.

## 13. Common Beginner Mistakes

### Mistake 1: confusing state with output

Output is only one part of the state story.

In reactive systems, hidden registers, counters, and phase variables often matter more than the final output bit.

### Mistake 2: proving only end-state equality

Final correctness matters, but it does not automatically prove:

- proper timing
- legal phase order
- output stability
- handshake correctness

### Mistake 3: using stronger logic than the problem needs

Not every small RTL machine needs a full temporal-logic framework.

Sometimes a few bounded trace operators are the cleanest solution.

### Mistake 4: ignoring modeling assumptions

A proof only proves what the model actually says.

If `start` is abstracted away, then handshake claims still need additional modeling work.

## 14. Minimal Glossary

- `state`: everything the system remembers at one step
- `transition`: one move from one state to the next
- `trace`: a sequence of states over time
- `invariant`: something true in every reachable state
- `safety`: something bad never happens
- `liveness`: something good eventually happens
- `bounded liveness`: something good happens within a known bound
- `refinement`: lower-level behavior matches a higher-level model
- `temporal logic`: logic for talking about how properties evolve over time

## Bottom Line

Reactive systems are about behavior over time, not just input/output equations.

That is why verification of RTL controllers needs:

- state models
- traces
- invariants
- progress properties
- timing-aware reasoning

For this repository, the simplest correct beginner mental model is:

1. the ANN math defines what result should exist
2. the RTL controller defines how that result is produced over time
3. the Lean model connects those two worlds
4. temporal reasoning is what lets us talk about `busy`, `done`, ordering, and stability instead of only the final bit
