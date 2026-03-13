import TinyMLP.Defs.FixedPointCore
import TinyMLP.ProofsVanilla.SpecArithmetic

namespace TinyMLP

inductive Phase
  | idle
  | loadInput
  | macHidden
  | biasHidden
  | actHidden
  | nextHidden
  | macOutput
  | biasOutput
  | done
deriving Repr, DecidableEq

structure State where
  regs : Input8
  hidden : Hidden16
  accumulator : Acc32
  hiddenIdx : Nat
  inputIdx : Nat
  phase : Phase
  output : Bool
deriving Repr, DecidableEq

def initialState (input : Input8) : State :=
  { regs := input
  , hidden := Hidden16.zero
  , accumulator := Acc32.zero
  , hiddenIdx := 0
  , inputIdx := 0
  , phase := .idle
  , output := false
  }

def step (s : State) : State :=
  match s.phase with
  | .idle =>
      { s with phase := .loadInput }
  | .loadInput =>
      { s with
          hidden := Hidden16.zero
          accumulator := Acc32.zero
          hiddenIdx := 0
          inputIdx := 0
          output := false
          phase := .macHidden }
  | .macHidden =>
      if _h : s.inputIdx < inputCount then
        { s with
            accumulator := acc32 s.accumulator (hiddenMacTermAt s.regs s.hiddenIdx s.inputIdx)
            inputIdx := s.inputIdx + 1 }
      else
        { s with phase := .biasHidden }
  | .biasHidden =>
      { s with
          accumulator := acc32 s.accumulator (bias1Term s.hiddenIdx)
          phase := .actHidden }
  | .actHidden =>
      { s with
          hidden := s.hidden.setCellNat s.hiddenIdx (relu16 s.accumulator)
          accumulator := Acc32.zero
          inputIdx := 0
          phase := .nextHidden }
  | .nextHidden =>
      if _h : s.hiddenIdx + 1 < hiddenCount then
        { s with hiddenIdx := s.hiddenIdx + 1, phase := .macHidden }
      else
        { s with hiddenIdx := 0, inputIdx := 0, phase := .macOutput }
  | .macOutput =>
      if _h : s.inputIdx < hiddenCount then
        { s with
            accumulator := acc32 s.accumulator (outputMacTermAt s.hidden s.inputIdx)
            inputIdx := s.inputIdx + 1 }
      else
        { s with phase := .biasOutput }
  | .biasOutput =>
      let finalAcc := acc32 s.accumulator bias2Term
      { s with
          accumulator := finalAcc
          output := finalAcc.toInt > 0
          phase := .done }
  | .done => s

def run : Nat → State → State
  | 0, s => s
  | n + 1, s => run n (step s)

def totalCycles : Nat := 76

end TinyMLP
