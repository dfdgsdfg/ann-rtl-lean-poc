import TinyMLP.Spec

namespace TinyMLP

def mul8x8To16 (lhs rhs : Int) : Int :=
  lhs * rhs

def mul16x8To24 (lhs rhs : Int) : Int :=
  lhs * rhs

def acc32 (acc term : Int) : Int :=
  acc + term

def relu16 (x : Int) : Int :=
  relu x

def hiddenFixedAt (input : Input8) (idx : Nat) : Int :=
  relu16 (hiddenPreAt8 input idx)

def hiddenFixed (input : Input8) : Hidden :=
  { h0 := hiddenFixedAt input 0
  , h1 := hiddenFixedAt input 1
  , h2 := hiddenFixedAt input 2
  , h3 := hiddenFixedAt input 3
  , h4 := hiddenFixedAt input 4
  , h5 := hiddenFixedAt input 5
  , h6 := hiddenFixedAt input 6
  , h7 := hiddenFixedAt input 7
  }

def outputScoreFixed (input : Input8) : Int :=
  outputScoreSpecFromHidden (hiddenFixed input)

def mlpFixed (input : Input8) : Bool :=
  outputScoreFixed input > 0

@[simp] theorem hiddenFixedAt_eq_hiddenSpecAt8 (input : Input8) (idx : Nat) :
    hiddenFixedAt input idx = hiddenSpecAt8 input idx := by
  rfl

@[simp] theorem hiddenFixedAt_eq_hiddenSpecAt (input : Input8) (idx : Nat) :
    hiddenFixedAt input idx = hiddenSpecAt (toMathInput input) idx := by
  rw [hiddenFixedAt_eq_hiddenSpecAt8, hiddenSpecAt8_eq_hiddenSpecAt_toMathInput]

@[simp] theorem hiddenFixed_eq_hiddenSpec8 (input : Input8) :
    hiddenFixed input = hiddenSpec8 input := by
  cases input <;> rfl

@[simp] theorem hiddenFixed_eq_hiddenSpec (input : Input8) :
    hiddenFixed input = hiddenSpec (toMathInput input) := by
  simp [hiddenFixed_eq_hiddenSpec8]

@[simp] theorem outputScoreFixed_eq_outputScoreSpec8 (input : Input8) :
    outputScoreFixed input = outputScoreSpec8 input := by
  simp [outputScoreFixed, outputScoreSpec8]

@[simp] theorem outputScoreFixed_eq_outputScoreSpec (input : Input8) :
    outputScoreFixed input = outputScoreSpec (toMathInput input) := by
  simp [outputScoreFixed, outputScoreSpec]

@[simp] theorem mlpFixed_eq_mlpSpec (input : Input8) :
    mlpFixed input = mlpSpec (toMathInput input) := by
  simp [mlpFixed, mlpSpec]

end TinyMLP
