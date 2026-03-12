namespace TinyMLP

def inputCount : Nat := 4
def hiddenCount : Nat := 8

structure Input where
  x0 : Int
  x1 : Int
  x2 : Int
  x3 : Int
deriving Repr, DecidableEq

abbrev MathInput := Input

structure Input8 where
  x0 : Int8
  x1 : Int8
  x2 : Int8
  x3 : Int8
deriving Repr, DecidableEq

def toMathInput (input : Input8) : MathInput :=
  { x0 := input.x0.toInt
  , x1 := input.x1.toInt
  , x2 := input.x2.toInt
  , x3 := input.x3.toInt
  }

structure Hidden where
  h0 : Int
  h1 : Int
  h2 : Int
  h3 : Int
  h4 : Int
  h5 : Int
  h6 : Int
  h7 : Int
deriving Repr, DecidableEq

def wrap16 (x : Int) : Int :=
  (Int16.ofInt x).toInt

def wrap32 (x : Int) : Int :=
  (Int32.ofInt x).toInt

@[simp] theorem Int16.ofInt_wrap16 (x : Int) : Int16.ofInt (wrap16 x) = Int16.ofInt x := by
  apply Int16.toInt_inj.mp
  simp [wrap16]

@[simp] theorem Int32.ofInt_wrap32 (x : Int) : Int32.ofInt (wrap32 x) = Int32.ofInt x := by
  apply Int32.toInt_inj.mp
  simp [wrap32]

@[simp] theorem wrap16_wrap16 (x : Int) : wrap16 (wrap16 x) = wrap16 x := by
  simp [wrap16]

@[simp] theorem wrap32_wrap32 (x : Int) : wrap32 (wrap32 x) = wrap32 x := by
  simp [wrap32]

@[simp] theorem wrap16_add_wrap16 (x y : Int) : wrap16 (wrap16 x + y) = wrap16 (x + y) := by
  unfold wrap16
  change (Int16.ofInt (wrap16 x + y)).toInt = (Int16.ofInt (x + y)).toInt
  rw [Int16.ofInt_add, Int16.ofInt_wrap16, ← Int16.ofInt_add]

@[simp] theorem wrap32_add_wrap32 (x y : Int) : wrap32 (wrap32 x + y) = wrap32 (x + y) := by
  unfold wrap32
  change (Int32.ofInt (wrap32 x + y)).toInt = (Int32.ofInt (x + y)).toInt
  rw [Int32.ofInt_add, Int32.ofInt_wrap32, ← Int32.ofInt_add]

structure Hidden16 where
  h0 : Int
  h1 : Int
  h2 : Int
  h3 : Int
  h4 : Int
  h5 : Int
  h6 : Int
  h7 : Int
deriving Repr, DecidableEq

structure Acc32 where
  toInt : Int
deriving Repr, DecidableEq

def Input.getNat (input : Input) : Nat → Int
  | 0 => input.x0
  | 1 => input.x1
  | 2 => input.x2
  | 3 => input.x3
  | _ => 0

def Input.get (input : Input) (idx : Fin inputCount) : Int :=
  input.getNat idx.1

def Input8.getNat (input : Input8) : Nat → Int
  | 0 => input.x0.toInt
  | 1 => input.x1.toInt
  | 2 => input.x2.toInt
  | 3 => input.x3.toInt
  | _ => 0

def Input8.get (input : Input8) (idx : Fin inputCount) : Int :=
  input.getNat idx.1

def Hidden.zero : Hidden :=
  { h0 := 0, h1 := 0, h2 := 0, h3 := 0, h4 := 0, h5 := 0, h6 := 0, h7 := 0 }

def Hidden16.zero : Hidden16 :=
  { h0 := 0, h1 := 0, h2 := 0, h3 := 0, h4 := 0, h5 := 0, h6 := 0, h7 := 0 }

def Acc32.ofInt (x : Int) : Acc32 :=
  { toInt := wrap32 x }

def Acc32.zero : Acc32 :=
  Acc32.ofInt 0

def Hidden.getNat (hidden : Hidden) : Nat → Int
  | 0 => hidden.h0
  | 1 => hidden.h1
  | 2 => hidden.h2
  | 3 => hidden.h3
  | 4 => hidden.h4
  | 5 => hidden.h5
  | 6 => hidden.h6
  | 7 => hidden.h7
  | _ => 0

def Hidden.get (hidden : Hidden) (idx : Fin hiddenCount) : Int :=
  hidden.getNat idx.1

def Hidden16.getNat (hidden : Hidden16) : Nat → Int
  | 0 => hidden.h0
  | 1 => hidden.h1
  | 2 => hidden.h2
  | 3 => hidden.h3
  | 4 => hidden.h4
  | 5 => hidden.h5
  | 6 => hidden.h6
  | 7 => hidden.h7
  | _ => 0

def Hidden16.get (hidden : Hidden16) (idx : Fin hiddenCount) : Int :=
  hidden.getNat idx.1

def Hidden16.toIntAt (hidden : Hidden16) (idx : Nat) : Int :=
  hidden.getNat idx

def Hidden.setNat (hidden : Hidden) (idx : Nat) (value : Int) : Hidden :=
  match idx with
  | 0 => { hidden with h0 := value }
  | 1 => { hidden with h1 := value }
  | 2 => { hidden with h2 := value }
  | 3 => { hidden with h3 := value }
  | 4 => { hidden with h4 := value }
  | 5 => { hidden with h5 := value }
  | 6 => { hidden with h6 := value }
  | 7 => { hidden with h7 := value }
  | _ => hidden

def Hidden16.setNat (hidden : Hidden16) (idx : Nat) (value : Int) : Hidden16 :=
  match idx with
  | 0 => { hidden with h0 := wrap16 value }
  | 1 => { hidden with h1 := wrap16 value }
  | 2 => { hidden with h2 := wrap16 value }
  | 3 => { hidden with h3 := wrap16 value }
  | 4 => { hidden with h4 := wrap16 value }
  | 5 => { hidden with h5 := wrap16 value }
  | 6 => { hidden with h6 := wrap16 value }
  | 7 => { hidden with h7 := wrap16 value }
  | _ => hidden

def Hidden16.toHidden (hidden : Hidden16) : Hidden :=
  { h0 := hidden.h0
  , h1 := hidden.h1
  , h2 := hidden.h2
  , h3 := hidden.h3
  , h4 := hidden.h4
  , h5 := hidden.h5
  , h6 := hidden.h6
  , h7 := hidden.h7
  }

def Hidden16.ofHidden (hidden : Hidden) : Hidden16 :=
  { h0 := wrap16 hidden.h0
  , h1 := wrap16 hidden.h1
  , h2 := wrap16 hidden.h2
  , h3 := wrap16 hidden.h3
  , h4 := wrap16 hidden.h4
  , h5 := wrap16 hidden.h5
  , h6 := wrap16 hidden.h6
  , h7 := wrap16 hidden.h7
  }

@[simp] theorem Acc32.toInt_zero : Acc32.zero.toInt = 0 := by
  simp [Acc32.zero, Acc32.ofInt, wrap32]

@[simp] theorem Acc32.toInt_ofInt (x : Int) :
    (Acc32.ofInt x).toInt = wrap32 x := by
  rfl

@[simp] theorem Hidden16.getNat_zero (idx : Nat) :
    Hidden16.zero.getNat idx = 0 := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 ∨ 8 ≤ idx := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    have hout : ∀ k : Nat, Hidden16.zero.getNat (8 + k) = 0 := by
      intro k
      induction k with
      | zero =>
          rfl
      | succ k ih =>
          simp [Nat.add_comm, Nat.add_assoc, Hidden16.getNat] at ih ⊢
    simpa using hout k

@[simp] theorem Hidden16.getNat_ofHidden (hidden : Hidden) (idx : Nat) :
    (Hidden16.ofHidden hidden).getNat idx = wrap16 (hidden.getNat idx) := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 ∨ 8 ≤ idx := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    have hout : ∀ k : Nat,
        (Hidden16.ofHidden hidden).getNat (8 + k) = wrap16 (hidden.getNat (8 + k)) := by
      intro k
      induction k with
      | zero =>
          rfl
      | succ k ih =>
          simp [Nat.add_comm, Nat.add_assoc, Hidden16.getNat, Hidden.getNat, wrap16] at ih ⊢
    simpa using hout k

@[simp] theorem Hidden16.toHidden_ofHidden (hidden : Hidden) :
    (Hidden16.ofHidden hidden).toHidden =
      { h0 := wrap16 hidden.h0
      , h1 := wrap16 hidden.h1
      , h2 := wrap16 hidden.h2
      , h3 := wrap16 hidden.h3
      , h4 := wrap16 hidden.h4
      , h5 := wrap16 hidden.h5
      , h6 := wrap16 hidden.h6
      , h7 := wrap16 hidden.h7
      } := by
  rfl

@[simp] theorem Hidden16.ofHidden_zero :
    Hidden16.ofHidden Hidden.zero = Hidden16.zero := by
  simp [Hidden16.ofHidden, Hidden.zero, Hidden16.zero, wrap16]

theorem wrap16_eq_self_of_bounds {x : Int} (hlo : 0 ≤ x) (hhi : x ≤ 32767) :
    wrap16 x = x := by
  unfold wrap16
  rw [Int16.toInt_ofInt_of_le]
  · omega
  · omega

theorem wrap32_eq_self_of_bounds {x : Int} (hlo : -2147483648 ≤ x) (hhi : x ≤ 2147483647) :
    wrap32 x = x := by
  unfold wrap32
  rw [Int32.toInt_ofInt_of_le]
  · exact hlo
  · omega

def relu (x : Int) : Int :=
  if x < 0 then 0 else x

/- BEGIN AUTO-GENERATED WEIGHTS -/
def w1At : Nat → Nat → Int
  | 0, 0 => 0
  | 0, 1 => 0
  | 0, 2 => 0
  | 0, 3 => 0
  | 1, 0 => 0
  | 1, 1 => 0
  | 1, 2 => 0
  | 1, 3 => -1
  | 2, 0 => 2
  | 2, 1 => 1
  | 2, 2 => 1
  | 2, 3 => -1
  | 3, 0 => 0
  | 3, 1 => 0
  | 3, 2 => 0
  | 3, 3 => -1
  | 4, 0 => -1
  | 4, 1 => 0
  | 4, 2 => 0
  | 4, 3 => 0
  | 5, 0 => -1
  | 5, 1 => 1
  | 5, 2 => -1
  | 5, 3 => 1
  | 6, 0 => 0
  | 6, 1 => -1
  | 6, 2 => 1
  | 6, 3 => -1
  | 7, 0 => 1
  | 7, 1 => 2
  | 7, 2 => 0
  | 7, 3 => 0
  | _, _ => 0

def b1At : Nat → Int
  | 0 => 0
  | 1 => 0
  | 2 => 1
  | 3 => 1
  | 4 => 0
  | 5 => 2
  | 6 => 1
  | 7 => -1
  | _ => 0

def w2At : Nat → Int
  | 0 => 0
  | 1 => 0
  | 2 => 1
  | 3 => 0
  | 4 => -1
  | 5 => -1
  | 6 => 1
  | 7 => -1
  | _ => 0

def b2 : Int := -1
/- END AUTO-GENERATED WEIGHTS -/

def w1 (i : Fin hiddenCount) (j : Fin inputCount) : Int :=
  w1At i.1 j.1

def b1 (i : Fin hiddenCount) : Int :=
  b1At i.1

def w2 (i : Fin hiddenCount) : Int :=
  w2At i.1

private def hiddenDotFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  w1At idx 0 * get 0 +
  w1At idx 1 * get 1 +
  w1At idx 2 * get 2 +
  w1At idx 3 * get 3

private def hiddenPreFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  hiddenDotFromGetter get idx + b1At idx

private def hiddenSpecAtFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  relu (hiddenPreFromGetter get idx)

private def hiddenSpecFromGetter (get : Nat → Int) : Hidden :=
  { h0 := hiddenSpecAtFromGetter get 0
  , h1 := hiddenSpecAtFromGetter get 1
  , h2 := hiddenSpecAtFromGetter get 2
  , h3 := hiddenSpecAtFromGetter get 3
  , h4 := hiddenSpecAtFromGetter get 4
  , h5 := hiddenSpecAtFromGetter get 5
  , h6 := hiddenSpecAtFromGetter get 6
  , h7 := hiddenSpecAtFromGetter get 7
  }

def hiddenDotAt (input : MathInput) (idx : Nat) : Int :=
  hiddenDotFromGetter input.getNat idx

def hiddenDotAt8 (input : Input8) (idx : Nat) : Int :=
  hiddenDotFromGetter input.getNat idx

def hiddenPreAt (input : MathInput) (idx : Nat) : Int :=
  hiddenPreFromGetter input.getNat idx

def hiddenPreAt8 (input : Input8) (idx : Nat) : Int :=
  hiddenPreFromGetter input.getNat idx

def hiddenPre (input : MathInput) (idx : Fin hiddenCount) : Int :=
  hiddenPreAt input idx.1

def hiddenPre8 (input : Input8) (idx : Fin hiddenCount) : Int :=
  hiddenPreAt8 input idx.1

def hiddenSpecAt (input : MathInput) (idx : Nat) : Int :=
  hiddenSpecAtFromGetter input.getNat idx

def hiddenSpecAt8 (input : Input8) (idx : Nat) : Int :=
  hiddenSpecAtFromGetter input.getNat idx

def hiddenSpec (input : MathInput) : Hidden :=
  hiddenSpecFromGetter input.getNat

def hiddenSpec8 (input : Input8) : Hidden :=
  hiddenSpecFromGetter input.getNat

@[simp] theorem hiddenSpec_eq_fields (input : MathInput) :
    hiddenSpec input =
      { h0 := hiddenSpecAt input 0
      , h1 := hiddenSpecAt input 1
      , h2 := hiddenSpecAt input 2
      , h3 := hiddenSpecAt input 3
      , h4 := hiddenSpecAt input 4
      , h5 := hiddenSpecAt input 5
      , h6 := hiddenSpecAt input 6
      , h7 := hiddenSpecAt input 7
      } := by
  rfl

@[simp] theorem hiddenSpec8_eq_fields (input : Input8) :
    hiddenSpec8 input =
      { h0 := hiddenSpecAt8 input 0
      , h1 := hiddenSpecAt8 input 1
      , h2 := hiddenSpecAt8 input 2
      , h3 := hiddenSpecAt8 input 3
      , h4 := hiddenSpecAt8 input 4
      , h5 := hiddenSpecAt8 input 5
      , h6 := hiddenSpecAt8 input 6
      , h7 := hiddenSpecAt8 input 7
      } := by
  rfl

def outputScoreSpecFromHidden (hidden : Hidden) : Int :=
  w2At 0 * hidden.h0 +
  w2At 1 * hidden.h1 +
  w2At 2 * hidden.h2 +
  w2At 3 * hidden.h3 +
  w2At 4 * hidden.h4 +
  w2At 5 * hidden.h5 +
  w2At 6 * hidden.h6 +
  w2At 7 * hidden.h7 +
  b2

def outputScoreSpecFromHidden16 (hidden : Hidden16) : Int :=
  w2At 0 * hidden.h0 +
  w2At 1 * hidden.h1 +
  w2At 2 * hidden.h2 +
  w2At 3 * hidden.h3 +
  w2At 4 * hidden.h4 +
  w2At 5 * hidden.h5 +
  w2At 6 * hidden.h6 +
  w2At 7 * hidden.h7 +
  b2

def outputScoreSpec (input : MathInput) : Int :=
  outputScoreSpecFromHidden (hiddenSpec input)

def outputScoreSpec8 (input : Input8) : Int :=
  outputScoreSpecFromHidden (hiddenSpec8 input)

def mlpSpec (input : MathInput) : Bool :=
  outputScoreSpec input > 0

@[simp] theorem toMathInput_getNat (input : Input8) (idx : Nat) :
    (toMathInput input).getNat idx = input.getNat idx := by
  cases idx <;> rfl

@[simp] theorem hiddenDotAt8_eq_hiddenDotAt_toMathInput (input : Input8) (idx : Nat) :
    hiddenDotAt8 input idx = hiddenDotAt (toMathInput input) idx := by
  have hget : (toMathInput input).getNat = input.getNat := by
    funext i
    exact toMathInput_getNat input i
  simp [hiddenDotAt, hiddenDotAt8, hget]

@[simp] theorem hiddenPreAt8_eq_hiddenPreAt_toMathInput (input : Input8) (idx : Nat) :
    hiddenPreAt8 input idx = hiddenPreAt (toMathInput input) idx := by
  have hget : (toMathInput input).getNat = input.getNat := by
    funext i
    exact toMathInput_getNat input i
  simp [hiddenPreAt, hiddenPreAt8, hget]

@[simp] theorem hiddenSpecAt8_eq_hiddenSpecAt_toMathInput (input : Input8) (idx : Nat) :
    hiddenSpecAt8 input idx = hiddenSpecAt (toMathInput input) idx := by
  have hget : (toMathInput input).getNat = input.getNat := by
    funext i
    exact toMathInput_getNat input i
  simp [hiddenSpecAt, hiddenSpecAt8, hget]

@[simp] theorem hiddenSpec8_eq_hiddenSpec_toMathInput (input : Input8) :
    hiddenSpec8 input = hiddenSpec (toMathInput input) := by
  cases input <;>
    simp [hiddenSpec, hiddenSpec8, hiddenSpecFromGetter, hiddenSpecAtFromGetter,
      hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat, Input8.getNat]

@[simp] theorem outputScoreSpec8_eq_outputScoreSpec_toMathInput (input : Input8) :
    outputScoreSpec8 input = outputScoreSpec (toMathInput input) := by
  simp [outputScoreSpec8, outputScoreSpec]

theorem hiddenSpecAt8_0_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 0 ∧ hiddenSpecAt8 input 0 ≤ 0 := by
  simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter, relu,
    Input8.getNat, w1At, b1At]

theorem hiddenSpecAt8_1_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 1 ∧ hiddenSpecAt8 input 1 ≤ 128 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : 0 < x3.toInt
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_2_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 2 ∧ hiddenSpecAt8 input 2 ≤ 637 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : 2 * x0.toInt + x1.toInt + x2.toInt + -x3.toInt + 1 < 0
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_3_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 3 ∧ hiddenSpecAt8 input 3 ≤ 129 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : -x3.toInt + 1 < 0
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_4_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 4 ∧ hiddenSpecAt8 input 4 ≤ 128 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      by_cases h : 0 < x0.toInt
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_5_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 5 ∧ hiddenSpecAt8 input 5 ≤ 512 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : -x0.toInt + x1.toInt + -x2.toInt + x3.toInt + 2 < 0
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_6_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 6 ∧ hiddenSpecAt8 input 6 ≤ 384 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : -x1.toInt + x2.toInt + -x3.toInt + 1 < 0
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_7_bounds (input : Input8) :
    0 ≤ hiddenSpecAt8 input 7 ∧ hiddenSpecAt8 input 7 ≤ 380 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      by_cases h : x0.toInt + 2 * x1.toInt + -1 < 0
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt8, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, Input8.getNat, w1At, b1At, h]
        omega

@[simp] theorem wrap32_hiddenPreAt8_0 (input : Input8) :
    wrap32 (hiddenPreAt8 input 0) = hiddenPreAt8 input 0 := by
  simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At, wrap32]

@[simp] theorem wrap32_hiddenPreAt8_1 (input : Input8) :
    wrap32 (hiddenPreAt8 input 1) = hiddenPreAt8 input 1 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_2 (input : Input8) :
    wrap32 (hiddenPreAt8 input 2) = hiddenPreAt8 input 2 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_3 (input : Input8) :
    wrap32 (hiddenPreAt8 input 3) = hiddenPreAt8 input 3 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_4 (input : Input8) :
    wrap32 (hiddenPreAt8 input 4) = hiddenPreAt8 input 4 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_5 (input : Input8) :
    wrap32 (hiddenPreAt8 input 5) = hiddenPreAt8 input 5 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_6 (input : Input8) :
    wrap32 (hiddenPreAt8 input 6) = hiddenPreAt8 input 6 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_7 (input : Input8) :
    wrap32 (hiddenPreAt8 input 7) = hiddenPreAt8 input 7 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt8, hiddenPreFromGetter, hiddenDotFromGetter, Input8.getNat, w1At, b1At] <;> omega

@[simp] theorem wrap16_hiddenSpecAt8_0 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 0) = hiddenSpecAt8 input 0 := by
  have h := hiddenSpecAt8_0_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_1 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 1) = hiddenSpecAt8 input 1 := by
  have h := hiddenSpecAt8_1_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_2 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 2) = hiddenSpecAt8 input 2 := by
  have h := hiddenSpecAt8_2_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_3 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 3) = hiddenSpecAt8 input 3 := by
  have h := hiddenSpecAt8_3_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_4 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 4) = hiddenSpecAt8 input 4 := by
  have h := hiddenSpecAt8_4_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_5 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 5) = hiddenSpecAt8 input 5 := by
  have h := hiddenSpecAt8_5_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_6 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 6) = hiddenSpecAt8 input 6 := by
  have h := hiddenSpecAt8_6_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_7 (input : Input8) :
    wrap16 (hiddenSpecAt8 input 7) = hiddenSpecAt8 input 7 := by
  have h := hiddenSpecAt8_7_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

theorem outputScoreSpec8_bounds (input : Input8) :
    -1021 ≤ outputScoreSpec8 input ∧ outputScoreSpec8 input ≤ 1020 := by
  have h2 := hiddenSpecAt8_2_bounds input
  have h4 := hiddenSpecAt8_4_bounds input
  have h5 := hiddenSpecAt8_5_bounds input
  have h6 := hiddenSpecAt8_6_bounds input
  have h7 := hiddenSpecAt8_7_bounds input
  have h :
      -1021 ≤ hiddenSpecAt8 input 2 - hiddenSpecAt8 input 4 - hiddenSpecAt8 input 5 +
        hiddenSpecAt8 input 6 - hiddenSpecAt8 input 7 - 1 ∧
      hiddenSpecAt8 input 2 - hiddenSpecAt8 input 4 - hiddenSpecAt8 input 5 +
        hiddenSpecAt8 input 6 - hiddenSpecAt8 input 7 - 1 ≤ 1020 := by
    omega
  simpa [outputScoreSpec8, outputScoreSpecFromHidden, hiddenSpec8, hiddenSpecFromGetter,
    hiddenSpecAt8, hiddenSpecAtFromGetter, w2At, b2] using h

@[simp] theorem wrap32_outputScoreSpec8 (input : Input8) :
    wrap32 (outputScoreSpec8 input) = outputScoreSpec8 input := by
  have h := outputScoreSpec8_bounds input
  exact wrap32_eq_self_of_bounds (by omega) (by omega)

@[simp] theorem outputScoreSpecFromHidden16_ofHidden_hiddenSpec8 (input : Input8) :
    outputScoreSpecFromHidden16 (Hidden16.ofHidden (hiddenSpec8 input)) = outputScoreSpec8 input := by
  have h2 :
      wrap16 (relu (hiddenPreFromGetter input.getNat 2)) =
        relu (hiddenPreFromGetter input.getNat 2) := by
    simpa [hiddenSpecAt8, hiddenSpecAtFromGetter] using wrap16_hiddenSpecAt8_2 input
  have h4 :
      wrap16 (relu (hiddenPreFromGetter input.getNat 4)) =
        relu (hiddenPreFromGetter input.getNat 4) := by
    simpa [hiddenSpecAt8, hiddenSpecAtFromGetter] using wrap16_hiddenSpecAt8_4 input
  have h5 :
      wrap16 (relu (hiddenPreFromGetter input.getNat 5)) =
        relu (hiddenPreFromGetter input.getNat 5) := by
    simpa [hiddenSpecAt8, hiddenSpecAtFromGetter] using wrap16_hiddenSpecAt8_5 input
  have h6 :
      wrap16 (relu (hiddenPreFromGetter input.getNat 6)) =
        relu (hiddenPreFromGetter input.getNat 6) := by
    simpa [hiddenSpecAt8, hiddenSpecAtFromGetter] using wrap16_hiddenSpecAt8_6 input
  have h7 :
      wrap16 (relu (hiddenPreFromGetter input.getNat 7)) =
        relu (hiddenPreFromGetter input.getNat 7) := by
    simpa [hiddenSpecAt8, hiddenSpecAtFromGetter] using wrap16_hiddenSpecAt8_7 input
  simp [outputScoreSpecFromHidden16, outputScoreSpec8, outputScoreSpecFromHidden, Hidden16.ofHidden,
    hiddenSpec8, hiddenSpecFromGetter, hiddenSpecAtFromGetter, w2At, b2, h2, h4, h5, h6, h7]

end TinyMLP
