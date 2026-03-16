import MlpCore.Defs.MachineCore

namespace MlpCore

structure ControlState where
  phase : Phase
  hiddenIdx : Nat
  inputIdx : Nat
deriving Repr, DecidableEq

def controlStep (cs : ControlState) : ControlState :=
  match cs.phase with
  | .idle =>
      { cs with phase := .loadInput }
  | .loadInput =>
      { phase := .macHidden, hiddenIdx := 0, inputIdx := 0 }
  | .macHidden =>
      if cs.inputIdx < inputCount then
        { cs with inputIdx := cs.inputIdx + 1 }
      else
        { cs with phase := .biasHidden }
  | .biasHidden =>
      { cs with phase := .actHidden }
  | .actHidden =>
      { cs with inputIdx := 0, phase := .nextHidden }
  | .nextHidden =>
      if cs.hiddenIdx + 1 < hiddenCount then
        { cs with hiddenIdx := cs.hiddenIdx + 1, phase := .macHidden }
      else
        { phase := .macOutput, hiddenIdx := 0, inputIdx := 0 }
  | .macOutput =>
      if cs.inputIdx < hiddenCount then
        { cs with inputIdx := cs.inputIdx + 1 }
      else
        { cs with phase := .biasOutput }
  | .biasOutput =>
      { cs with phase := .done }
  | .done => cs

def controlRun : Nat → ControlState → ControlState
  | 0, cs => cs
  | n + 1, cs => controlRun n (controlStep cs)

def controlOf (s : State) : ControlState :=
  { phase := s.phase, hiddenIdx := s.hiddenIdx, inputIdx := s.inputIdx }

structure CtrlSample where
  start : Bool
  inputs : Input8
deriving Repr, DecidableEq

def zeroInput : Input8 :=
  { x0 := Int8.ofInt 0
  , x1 := Int8.ofInt 0
  , x2 := Int8.ofInt 0
  , x3 := Int8.ofInt 0
  }

def idleState : State :=
  { regs := zeroInput
  , hidden := Hidden16.zero
  , accumulator := Acc32.zero
  , hiddenIdx := 0
  , inputIdx := 0
  , phase := .idle
  , output := false
  }

def capturedInput (samples : Nat → CtrlSample) : Input8 :=
  (samples 1).inputs

def acceptedStart (sample : CtrlSample) (s : State) : Prop :=
  s.phase = .idle ∧ sample.start = true

def busyOf (s : State) : Prop :=
  s.phase ≠ .idle ∧ s.phase ≠ .done

def doneOf (s : State) : Prop :=
  s.phase = .done

def outputValidOf (s : State) : Prop :=
  doneOf s

def SameDataFields (before after : State) : Prop :=
  after.regs = before.regs ∧
    after.hidden = before.hidden ∧
    after.accumulator = before.accumulator ∧
    after.hiddenIdx = before.hiddenIdx ∧
    after.inputIdx = before.inputIdx ∧
    after.output = before.output

def stableOutputOn (t : Nat) (trace : Nat → State) : Prop :=
  ∀ n, (∀ m, t ≤ m → m ≤ t + n → doneOf (trace m)) →
    (trace (t + n)).output = (trace t).output

section

variable [ArithmeticProofProvider]

def timedStep (sample : CtrlSample) (s : State) : State :=
  match s.phase with
  | .idle =>
      if sample.start then
        { s with phase := .loadInput }
      else
        { s with hiddenIdx := 0, inputIdx := 0 }
  | .loadInput =>
      { s with
          regs := sample.inputs
          hidden := Hidden16.zero
          accumulator := Acc32.zero
          hiddenIdx := 0
          inputIdx := 0
          output := false
          phase := .macHidden }
  | .done =>
      if sample.start then
        s
      else
        { s with phase := .idle }
  | _ =>
      step s

def timedRun : Nat → (Nat → CtrlSample) → State → State
  | 0, _, s => s
  | n + 1, samples, s =>
      timedRun n (fun k => samples (k + 1)) (timedStep (samples 0) s)

def rtlTrace (samples : Nat → CtrlSample) : Nat → State
  | 0 => idleState
  | n + 1 => timedStep (samples n) (rtlTrace samples n)

end

def initialControl : ControlState :=
  { phase := .idle, hiddenIdx := 0, inputIdx := 0 }

def timedControlStep (sample : CtrlSample) (cs : ControlState) : ControlState :=
  match cs.phase with
  | .idle =>
      if sample.start then
        controlStep cs
      else
        { cs with hiddenIdx := 0, inputIdx := 0 }
  | .done =>
      if sample.start then
        cs
      else
        { cs with phase := .idle }
  | _ =>
      controlStep cs

def timedControlRun : Nat → (Nat → CtrlSample) → ControlState → ControlState
  | 0, _, cs => cs
  | n + 1, samples, cs =>
      timedControlRun n (fun k => samples (k + 1)) (timedControlStep (samples 0) cs)

def timedControlTrace (samples : Nat → CtrlSample) : Nat → ControlState
  | 0 => initialControl
  | n + 1 => timedControlStep (samples n) (timedControlTrace samples n)

def holdHigh : Nat → CtrlSample :=
  fun _ => { start := true, inputs := zeroInput }

end MlpCore
