import MlpCore.Generated.Contract

namespace MlpCore

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

def Int16Bounds (x : Int) : Prop :=
  -2 ^ 15 ≤ x ∧ x < 2 ^ 15

def Int24Bounds (x : Int) : Prop :=
  -2 ^ 23 ≤ x ∧ x < 2 ^ 23

def Int32Bounds (x : Int) : Prop :=
  -2 ^ 31 ≤ x ∧ x < 2 ^ 31

abbrev Int16Val := { x : Int // Int16Bounds x }
abbrev Int24Val := { x : Int // Int24Bounds x }
abbrev Int32Val := { x : Int // Int32Bounds x }

theorem wrap16_in_bounds (x : Int) : Int16Bounds (wrap16 x) := by
  unfold Int16Bounds wrap16
  exact ⟨(Int16.ofInt x).le_toInt, (Int16.ofInt x).toInt_lt⟩

theorem wrap32_in_bounds (x : Int) : Int32Bounds (wrap32 x) := by
  unfold Int32Bounds wrap32
  exact ⟨(Int32.ofInt x).le_toInt, (Int32.ofInt x).toInt_lt⟩

def Int16Val.ofInt (x : Int) : Int16Val :=
  ⟨wrap16 x, wrap16_in_bounds x⟩

def Int32Val.ofInt (x : Int) : Int32Val :=
  ⟨wrap32 x, wrap32_in_bounds x⟩

def Int16Val.toInt (x : Int16Val) : Int :=
  x.1

def Int24Val.toInt (x : Int24Val) : Int :=
  x.1

def Int32Val.toInt (x : Int32Val) : Int :=
  x.1

theorem Int16Val.le_toInt (x : Int16Val) : -2 ^ 15 ≤ x.toInt :=
  x.2.1

theorem Int16Val.toInt_lt (x : Int16Val) : x.toInt < 2 ^ 15 :=
  x.2.2

theorem Int24Val.le_toInt (x : Int24Val) : -2 ^ 23 ≤ x.toInt :=
  x.2.1

theorem Int24Val.toInt_lt (x : Int24Val) : x.toInt < 2 ^ 23 :=
  x.2.2

theorem Int32Val.le_toInt (x : Int32Val) : -2 ^ 31 ≤ x.toInt :=
  x.2.1

theorem Int32Val.toInt_lt (x : Int32Val) : x.toInt < 2 ^ 31 :=
  x.2.2

@[simp] theorem Int16Val.toInt_ofInt (x : Int) :
    (Int16Val.ofInt x).toInt = wrap16 x := by
  rfl

@[simp] theorem Int32Val.toInt_ofInt (x : Int) :
    (Int32Val.ofInt x).toInt = wrap32 x := by
  rfl

@[simp] theorem Int32Val.ofInt_add_wrapped (x y : Int) :
    Int32Val.ofInt (wrap32 x + wrap32 y) = Int32Val.ofInt (x + y) := by
  apply Subtype.ext
  change wrap32 (wrap32 x + wrap32 y) = wrap32 (x + y)
  rw [wrap32_add_wrap32]
  rw [Int.add_comm x (wrap32 y), wrap32_add_wrap32, Int.add_comm y x]

structure Hidden16 where
  h0 : Int16Val
  h1 : Int16Val
  h2 : Int16Val
  h3 : Int16Val
  h4 : Int16Val
  h5 : Int16Val
  h6 : Int16Val
  h7 : Int16Val
deriving Repr, DecidableEq

structure Acc32 where
  raw : Int32Val
deriving Repr, DecidableEq

def Input.getNat (input : Input) : Nat → Int
  | 0 => input.x0
  | 1 => input.x1
  | 2 => input.x2
  | 3 => input.x3
  | _ => 0

def Input.get (input : Input) (idx : Fin inputCount) : Int :=
  input.getNat idx.1

def Input8.getNat (input : Input8) : Nat → Int8
  | 0 => input.x0
  | 1 => input.x1
  | 2 => input.x2
  | 3 => input.x3
  | _ => Int8.ofInt 0

def Input8.getInt8Nat (input : Input8) : Nat → Int8 :=
  input.getNat

def Input8.get (input : Input8) (idx : Fin inputCount) : Int8 :=
  input.getNat idx.1

def Hidden.zero : Hidden :=
  { h0 := 0, h1 := 0, h2 := 0, h3 := 0, h4 := 0, h5 := 0, h6 := 0, h7 := 0 }

def Hidden16.zero : Hidden16 :=
  { h0 := Int16Val.ofInt 0
  , h1 := Int16Val.ofInt 0
  , h2 := Int16Val.ofInt 0
  , h3 := Int16Val.ofInt 0
  , h4 := Int16Val.ofInt 0
  , h5 := Int16Val.ofInt 0
  , h6 := Int16Val.ofInt 0
  , h7 := Int16Val.ofInt 0
  }

def Acc32.ofInt (x : Int) : Acc32 :=
  { raw := Int32Val.ofInt x }

def Acc32.zero : Acc32 :=
  Acc32.ofInt 0

def Acc32.toInt (acc : Acc32) : Int :=
  acc.raw.toInt

@[simp] theorem Acc32.toInt_mk (raw : Int32Val) :
    ({ raw := raw } : Acc32).toInt = raw.toInt := by
  rfl

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

def Hidden16.getNat (hidden : Hidden16) : Nat → Int16Val
  | 0 => hidden.h0
  | 1 => hidden.h1
  | 2 => hidden.h2
  | 3 => hidden.h3
  | 4 => hidden.h4
  | 5 => hidden.h5
  | 6 => hidden.h6
  | 7 => hidden.h7
  | _ => Int16Val.ofInt 0

def Hidden16.getCellNat (hidden : Hidden16) : Nat → Int16Val :=
  hidden.getNat

def Hidden16.get (hidden : Hidden16) (idx : Fin hiddenCount) : Int16Val :=
  hidden.getNat idx.1

@[simp] theorem Input8.getInt8Nat_toInt (input : Input8) (idx : Nat) :
    (input.getInt8Nat idx).toInt = (toMathInput input).getNat idx := by
  cases idx with
  | zero => rfl
  | succ idx =>
      cases idx with
      | zero => rfl
      | succ idx =>
          cases idx with
          | zero => rfl
          | succ idx =>
              cases idx with
                  | zero => rfl
                  | succ idx => rfl

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

def Hidden16.setCellNat (hidden : Hidden16) (idx : Nat) (value : Int16Val) : Hidden16 :=
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

@[simp] theorem Hidden16.getNat_toInt (hidden : Hidden16) (idx : Nat) :
    (hidden.getNat idx).toInt = hidden.toHidden.getNat idx := by
  cases idx with
  | zero => rfl
  | succ idx =>
      cases idx with
      | zero => rfl
      | succ idx =>
          cases idx with
          | zero => rfl
          | succ idx =>
              cases idx with
              | zero => rfl
              | succ idx =>
                  cases idx with
                  | zero => rfl
                  | succ idx =>
                      cases idx with
                      | zero => rfl
                      | succ idx =>
                          cases idx with
                          | zero => rfl
                          | succ idx =>
                              cases idx with
                              | zero => rfl
                              | succ idx => rfl

@[simp] theorem Hidden16.getCellNat_toInt (hidden : Hidden16) (idx : Nat) :
    (hidden.getCellNat idx).toInt = hidden.toHidden.getNat idx := by
  exact Hidden16.getNat_toInt hidden idx

def Hidden16.ofHidden (hidden : Hidden) : Hidden16 :=
  { h0 := Int16Val.ofInt hidden.h0
  , h1 := Int16Val.ofInt hidden.h1
  , h2 := Int16Val.ofInt hidden.h2
  , h3 := Int16Val.ofInt hidden.h3
  , h4 := Int16Val.ofInt hidden.h4
  , h5 := Int16Val.ofInt hidden.h5
  , h6 := Int16Val.ofInt hidden.h6
  , h7 := Int16Val.ofInt hidden.h7
  }

@[simp] theorem Acc32.toInt_zero : Acc32.zero.toInt = 0 := by
  simp [Acc32.zero, Acc32.ofInt, Acc32.toInt, Int32Val.ofInt, Int32Val.toInt, wrap32]

@[simp] theorem Acc32.toInt_ofInt (x : Int) :
    (Acc32.ofInt x).toInt = wrap32 x := by
  rfl

@[simp] theorem Hidden16.getNat_zero (idx : Nat) :
    Hidden16.zero.getNat idx = Int16Val.ofInt 0 := by
  cases idx with
  | zero => rfl
  | succ idx =>
      cases idx with
      | zero => rfl
      | succ idx =>
          cases idx with
          | zero => rfl
          | succ idx =>
              cases idx with
              | zero => rfl
              | succ idx =>
                  cases idx with
                  | zero => rfl
                  | succ idx =>
                      cases idx with
                      | zero => rfl
                      | succ idx =>
                          cases idx with
                          | zero => rfl
                          | succ idx =>
                              cases idx with
                              | zero => rfl
                              | succ idx => rfl

@[simp] theorem Hidden16.getNat_ofHidden (hidden : Hidden) (idx : Nat) :
    (Hidden16.ofHidden hidden).getNat idx = Int16Val.ofInt (hidden.getNat idx) := by
  cases idx with
  | zero => rfl
  | succ idx =>
      cases idx with
      | zero => rfl
      | succ idx =>
          cases idx with
          | zero => rfl
          | succ idx =>
              cases idx with
              | zero => rfl
              | succ idx =>
                  cases idx with
                  | zero => rfl
                  | succ idx =>
                      cases idx with
                      | zero => rfl
                      | succ idx =>
                          cases idx with
                          | zero => rfl
                          | succ idx =>
                              cases idx with
                              | zero => rfl
                              | succ idx => rfl

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
  simp [Hidden16.ofHidden, Hidden.zero, Hidden16.zero, Int16Val.ofInt]

def relu (x : Int) : Int :=
  if x < 0 then 0 else x

def w1 (i : Fin hiddenCount) (j : Fin inputCount) : Int :=
  w1At i.1 j.1

def b1 (i : Fin hiddenCount) : Int :=
  b1At i.1

def w2 (i : Fin hiddenCount) : Int :=
  w2At i.1

def hiddenDotFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  w1At idx 0 * get 0 +
  w1At idx 1 * get 1 +
  w1At idx 2 * get 2 +
  w1At idx 3 * get 3

def hiddenPreFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  hiddenDotFromGetter get idx + b1At idx

def hiddenSpecAtFromGetter (get : Nat → Int) (idx : Nat) : Int :=
  relu (hiddenPreFromGetter get idx)

def hiddenSpecFromGetter (get : Nat → Int) : Hidden :=
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

def hiddenPreAt (input : MathInput) (idx : Nat) : Int :=
  hiddenPreFromGetter input.getNat idx

def hiddenPre (input : MathInput) (idx : Fin hiddenCount) : Int :=
  hiddenPreAt input idx.1

def hiddenSpecAt (input : MathInput) (idx : Nat) : Int :=
  hiddenSpecAtFromGetter input.getNat idx

def hiddenSpec (input : MathInput) : Hidden :=
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

def outputScoreSpec (input : MathInput) : Int :=
  outputScoreSpecFromHidden (hiddenSpec input)

def mlpSpec (input : MathInput) : Bool :=
  outputScoreSpec input > 0

end MlpCore
