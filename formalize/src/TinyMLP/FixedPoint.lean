import TinyMLP.Spec

namespace TinyMLP

def mul8x8To16 (lhs rhs : Int8) : Int16Val :=
  Int16Val.ofInt (lhs.toInt * rhs.toInt)

def mul16x8To24 (lhs : Int16Val) (rhs : Int8) : Acc32 :=
  Acc32.ofInt (lhs.toInt * rhs.toInt)

def acc32 (acc term : Acc32) : Acc32 :=
  Acc32.ofInt (acc.toInt + term.toInt)

def relu16 (x : Acc32) : Int16Val :=
  Int16Val.ofInt (relu x.toInt)

def bias1Term (idx : Nat) : Acc32 :=
  Acc32.ofInt (b1At idx)

def bias2Term : Acc32 :=
  Acc32.ofInt b2

def hiddenMacTermAt (input : Input8) (hiddenIdx inputIdx : Nat) : Acc32 :=
  Acc32.ofInt (w1At hiddenIdx inputIdx * input.getNat inputIdx)

def outputMacTermAt (hidden : Hidden16) (idx : Nat) : Acc32 :=
  Acc32.ofInt (hidden.getNat idx * w2At idx)

@[simp] theorem bias1Term_toInt (idx : Nat) :
    (bias1Term idx).toInt = wrap32 (b1At idx) := by
  rfl

@[simp] theorem bias2Term_toInt :
    bias2Term.toInt = wrap32 b2 := by
  rfl

@[simp] theorem hiddenMacTermAt_toInt (input : Input8) (hiddenIdx inputIdx : Nat) :
    (hiddenMacTermAt input hiddenIdx inputIdx).toInt =
      wrap32 (w1At hiddenIdx inputIdx * input.getNat inputIdx) := by
  rfl

@[simp] theorem outputMacTermAt_toInt (hidden : Hidden16) (idx : Nat) :
    (outputMacTermAt hidden idx).toInt = wrap32 (hidden.getNat idx * w2At idx) := by
  rfl

@[simp] theorem acc32_toInt (acc term : Acc32) :
    (acc32 acc term).toInt = wrap32 (acc.toInt + term.toInt) := by
  rfl

@[simp] theorem relu16_toInt (x : Acc32) :
    (relu16 x).toInt = wrap16 (relu x.toInt) := by
  rfl

def hiddenFixedAt (input : Input8) (idx : Nat) : Int16Val :=
  Int16Val.ofInt (hiddenSpecAt8 input idx)

def hiddenFixed (input : Input8) : Hidden16 :=
  Hidden16.ofHidden (hiddenSpec8 input)

@[simp] theorem hiddenFixed_eq_hiddenSpec8 (input : Input8) :
    hiddenFixed input = Hidden16.ofHidden (hiddenSpec8 input) := by
  rfl

@[simp] theorem hiddenFixed_toHidden_eq_hiddenSpec8 (input : Input8) :
    (hiddenFixed input).toHidden = hiddenSpec8 input := by
  simpa only [hiddenFixed, Hidden16.toHidden_ofHidden, hiddenSpec8_eq_fields,
    wrap16_hiddenSpecAt8_0, wrap16_hiddenSpecAt8_1, wrap16_hiddenSpecAt8_2,
    wrap16_hiddenSpecAt8_3, wrap16_hiddenSpecAt8_4, wrap16_hiddenSpecAt8_5,
    wrap16_hiddenSpecAt8_6, wrap16_hiddenSpecAt8_7] using
      (Hidden16.toHidden_ofHidden (hiddenSpec8 input))

@[simp] theorem hiddenFixed_eq_hiddenSpec (input : Input8) :
    (hiddenFixed input).toHidden = hiddenSpec (toMathInput input) := by
  rw [hiddenFixed_toHidden_eq_hiddenSpec8, hiddenSpec8_eq_hiddenSpec_toMathInput]

def outputScoreFixed (input : Input8) : Acc32 :=
  Acc32.ofInt (outputScoreSpecFromHidden16 (hiddenFixed input))

@[simp] theorem outputScoreFixed_eq_outputScoreSpec8 (input : Input8) :
    (outputScoreFixed input).toInt = outputScoreSpec8 input := by
  unfold outputScoreFixed
  rw [Acc32.toInt_ofInt, hiddenFixed_eq_hiddenSpec8, outputScoreSpecFromHidden16_ofHidden_hiddenSpec8]
  exact wrap32_outputScoreSpec8 input

@[simp] theorem outputScoreFixed_eq_outputScoreSpec (input : Input8) :
    (outputScoreFixed input).toInt = outputScoreSpec (toMathInput input) := by
  rw [outputScoreFixed_eq_outputScoreSpec8, outputScoreSpec8_eq_outputScoreSpec_toMathInput]

def mlpFixed (input : Input8) : Bool :=
  (outputScoreFixed input).toInt > 0

@[simp] theorem mlpFixed_eq_mlpSpec (input : Input8) :
    mlpFixed input = mlpSpec (toMathInput input) := by
  simp [mlpFixed, mlpSpec]

end TinyMLP
