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

theorem int8_mul_int8_bounds (lhs rhs : Int8) :
    Int16Bounds (lhs.toInt * rhs.toInt) := by
  have hxlo : -(2 ^ 7 : Int) ≤ lhs.toInt := lhs.le_toInt
  have hxhi : lhs.toInt < 2 ^ 7 := lhs.toInt_lt
  have hylo : -(2 ^ 7 : Int) ≤ rhs.toInt := rhs.le_toInt
  have hyhi : rhs.toInt < 2 ^ 7 := rhs.toInt_lt
  have hxle : lhs.toInt ≤ 2 ^ 7 - 1 := by omega
  have hyle : rhs.toInt ≤ 2 ^ 7 - 1 := by omega
  constructor
  · by_cases hnonneg : 0 ≤ rhs.toInt
    · have hmul : -(2 ^ 7 : Int) * rhs.toInt ≤ lhs.toInt * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_right hxlo hnonneg
      have hbase : -(2 ^ 7 : Int) * (2 ^ 7 - 1 : Int) ≤ -(2 ^ 7 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_left (by omega) hyle
      omega
    · have hnonpos : rhs.toInt ≤ 0 := by omega
      have hmul : (2 ^ 7 - 1 : Int) * rhs.toInt ≤ lhs.toInt * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_right hxle hnonpos
      have hbase : (2 ^ 7 - 1 : Int) * (-(2 ^ 7 : Int)) ≤ (2 ^ 7 - 1 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_left hylo (by omega)
      omega
  · by_cases hnonneg : 0 ≤ rhs.toInt
    · have hmul : lhs.toInt * rhs.toInt ≤ (2 ^ 7 - 1 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_right hxle hnonneg
      have hbase : (2 ^ 7 - 1 : Int) * rhs.toInt ≤ (2 ^ 7 - 1 : Int) * (2 ^ 7 - 1 : Int) :=
        Int.mul_le_mul_of_nonneg_left hyle (by omega)
      omega
    · have hnonpos : rhs.toInt ≤ 0 := by omega
      have hmul : lhs.toInt * rhs.toInt ≤ -(2 ^ 7 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_right hxlo hnonpos
      have hbase : -(2 ^ 7 : Int) * rhs.toInt ≤ -(2 ^ 7 : Int) * (-(2 ^ 7 : Int)) :=
        Int.mul_le_mul_of_nonpos_left (by omega) hylo
      omega

theorem int16_mul_int8_bounds (lhs : Int16Val) (rhs : Int8) :
    Int24Bounds (lhs.toInt * rhs.toInt) := by
  have hxlo : -(2 ^ 15 : Int) ≤ lhs.toInt := lhs.le_toInt
  have hxhi : lhs.toInt < 2 ^ 15 := lhs.toInt_lt
  have hylo : -(2 ^ 7 : Int) ≤ rhs.toInt := rhs.le_toInt
  have hyhi : rhs.toInt < 2 ^ 7 := rhs.toInt_lt
  have hxle : lhs.toInt ≤ 2 ^ 15 - 1 := by omega
  have hyle : rhs.toInt ≤ 2 ^ 7 - 1 := by omega
  constructor
  · by_cases hnonneg : 0 ≤ rhs.toInt
    · have hmul : -(2 ^ 15 : Int) * rhs.toInt ≤ lhs.toInt * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_right hxlo hnonneg
      have hbase : -(2 ^ 15 : Int) * (2 ^ 7 - 1 : Int) ≤ -(2 ^ 15 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_left (by omega) hyle
      omega
    · have hnonpos : rhs.toInt ≤ 0 := by omega
      have hmul : (2 ^ 15 - 1 : Int) * rhs.toInt ≤ lhs.toInt * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_right hxle hnonpos
      have hbase : (2 ^ 15 - 1 : Int) * (-(2 ^ 7 : Int)) ≤ (2 ^ 15 - 1 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_left hylo (by omega)
      omega
  · by_cases hnonneg : 0 ≤ rhs.toInt
    · have hmul : lhs.toInt * rhs.toInt ≤ (2 ^ 15 - 1 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonneg_right hxle hnonneg
      have hbase : (2 ^ 15 - 1 : Int) * rhs.toInt ≤ (2 ^ 15 - 1 : Int) * (2 ^ 7 - 1 : Int) :=
        Int.mul_le_mul_of_nonneg_left hyle (by omega)
      omega
    · have hnonpos : rhs.toInt ≤ 0 := by omega
      have hmul : lhs.toInt * rhs.toInt ≤ -(2 ^ 15 : Int) * rhs.toInt :=
        Int.mul_le_mul_of_nonpos_right hxlo hnonpos
      have hbase : -(2 ^ 15 : Int) * rhs.toInt ≤ -(2 ^ 15 : Int) * (-(2 ^ 7 : Int)) :=
        Int.mul_le_mul_of_nonpos_left (by omega) hylo
      omega

theorem int16_to_int32_bounds (x : Int16Val) : Int32Bounds x.toInt := by
  have hlo : -2 ^ 15 ≤ x.toInt := x.le_toInt
  have hhi : x.toInt < 2 ^ 15 := x.toInt_lt
  constructor <;> omega

theorem int24_to_int32_bounds (x : Int24Val) : Int32Bounds x.toInt := by
  have hlo : -2 ^ 23 ≤ x.toInt := x.le_toInt
  have hhi : x.toInt < 2 ^ 23 := x.toInt_lt
  constructor <;> omega

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
  simpa [Hidden16.getCellNat] using Hidden16.getNat_toInt hidden idx

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
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 ∨ 8 ≤ idx := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt]
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    have h0 : 8 + k ≠ 0 := by omega
    have h1 : 8 + k ≠ 1 := by omega
    have h2 : 8 + k ≠ 2 := by omega
    have h3 : 8 + k ≠ 3 := by omega
    have h4 : 8 + k ≠ 4 := by omega
    have h5 : 8 + k ≠ 5 := by omega
    have h6 : 8 + k ≠ 6 := by omega
    have h7 : 8 + k ≠ 7 := by omega
    simp [Hidden16.zero, Hidden16.getNat, Int16Val.ofInt, h0, h1, h2, h3, h4, h5, h6, h7]

@[simp] theorem Hidden16.getNat_ofHidden (hidden : Hidden) (idx : Nat) :
    (Hidden16.ofHidden hidden).getNat idx = Int16Val.ofInt (hidden.getNat idx) := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 ∨ 8 ≤ idx := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat]
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    have h0 : 8 + k ≠ 0 := by omega
    have h1 : 8 + k ≠ 1 := by omega
    have h2 : 8 + k ≠ 2 := by omega
    have h3 : 8 + k ≠ 3 := by omega
    have h4 : 8 + k ≠ 4 := by omega
    have h5 : 8 + k ≠ 5 := by omega
    have h6 : 8 + k ≠ 6 := by omega
    have h7 : 8 + k ≠ 7 := by omega
    simp [Hidden16.ofHidden, Hidden16.getNat, Int16Val.ofInt, Hidden.getNat, h0, h1, h2, h3, h4,
      h5, h6, h7]

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

theorem toMathInput_getNat (input : Input8) (idx : Nat) :
    (toMathInput input).getNat idx = (input.getInt8Nat idx).toInt := by
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

theorem hiddenSpecAt8_0_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 0 ∧ hiddenSpecAt (toMathInput input) 0 ≤ 0 := by
  simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter, relu,
    toMathInput, Input.getNat, w1At, b1At]

theorem hiddenSpecAt8_1_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 1 ∧ hiddenSpecAt (toMathInput input) 1 ≤ 128 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : 0 < x3.toInt
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_2_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 2 ∧ hiddenSpecAt (toMathInput input) 2 ≤ 637 := by
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
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_3_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 3 ∧ hiddenSpecAt (toMathInput input) 3 ≤ 129 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : -x3.toInt + 1 < 0
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_4_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 4 ∧ hiddenSpecAt (toMathInput input) 4 ≤ 128 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      by_cases h : 0 < x0.toInt
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_5_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 5 ∧ hiddenSpecAt (toMathInput input) 5 ≤ 512 := by
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
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_6_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 6 ∧ hiddenSpecAt (toMathInput input) 6 ≤ 384 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      by_cases h : -x1.toInt + x2.toInt + -x3.toInt + 1 < 0
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

theorem hiddenSpecAt8_7_bounds (input : Input8) :
    0 ≤ hiddenSpecAt (toMathInput input) 7 ∧ hiddenSpecAt (toMathInput input) 7 ≤ 380 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      by_cases h : x0.toInt + 2 * x1.toInt + -1 < 0
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
      · simp [hiddenSpecAt, hiddenSpecAtFromGetter, hiddenPreFromGetter, hiddenDotFromGetter,
          relu, toMathInput, Input.getNat, w1At, b1At, h]
        omega

@[simp] theorem wrap32_hiddenPreAt8_0 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 0) = hiddenPreAt (toMathInput input) 0 := by
  simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat, w1At,
    b1At, wrap32]

@[simp] theorem wrap32_hiddenPreAt8_1 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 1) = hiddenPreAt (toMathInput input) 1 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_2 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 2) = hiddenPreAt (toMathInput input) 2 := by
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
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_3 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 3) = hiddenPreAt (toMathInput input) 3 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_4 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 4) = hiddenPreAt (toMathInput input) 4 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_5 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 5) = hiddenPreAt (toMathInput input) 5 := by
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
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_6 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 6) = hiddenPreAt (toMathInput input) 6 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      have hx2lo : -2 ^ 7 ≤ x2.toInt := x2.le_toInt
      have hx2hi : x2.toInt < 2 ^ 7 := x2.toInt_lt
      have hx3lo : -2 ^ 7 ≤ x3.toInt := x3.le_toInt
      have hx3hi : x3.toInt < 2 ^ 7 := x3.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap32_hiddenPreAt8_7 (input : Input8) :
    wrap32 (hiddenPreAt (toMathInput input) 7) = hiddenPreAt (toMathInput input) 7 := by
  cases input with
  | mk x0 x1 x2 x3 =>
      have hx0lo : -2 ^ 7 ≤ x0.toInt := x0.le_toInt
      have hx0hi : x0.toInt < 2 ^ 7 := x0.toInt_lt
      have hx1lo : -2 ^ 7 ≤ x1.toInt := x1.le_toInt
      have hx1hi : x1.toInt < 2 ^ 7 := x1.toInt_lt
      apply wrap32_eq_self_of_bounds <;>
        simp [hiddenPreAt, hiddenPreFromGetter, hiddenDotFromGetter, toMathInput, Input.getNat,
          w1At, b1At] <;> omega

@[simp] theorem wrap16_hiddenSpecAt8_0 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 0) = hiddenSpecAt (toMathInput input) 0 := by
  have h := hiddenSpecAt8_0_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_1 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 1) = hiddenSpecAt (toMathInput input) 1 := by
  have h := hiddenSpecAt8_1_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_2 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 2) = hiddenSpecAt (toMathInput input) 2 := by
  have h := hiddenSpecAt8_2_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_3 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 3) = hiddenSpecAt (toMathInput input) 3 := by
  have h := hiddenSpecAt8_3_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_4 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 4) = hiddenSpecAt (toMathInput input) 4 := by
  have h := hiddenSpecAt8_4_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_5 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 5) = hiddenSpecAt (toMathInput input) 5 := by
  have h := hiddenSpecAt8_5_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_6 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 6) = hiddenSpecAt (toMathInput input) 6 := by
  have h := hiddenSpecAt8_6_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

@[simp] theorem wrap16_hiddenSpecAt8_7 (input : Input8) :
    wrap16 (hiddenSpecAt (toMathInput input) 7) = hiddenSpecAt (toMathInput input) 7 := by
  have h := hiddenSpecAt8_7_bounds input
  exact wrap16_eq_self_of_bounds h.1 (by omega)

theorem outputScoreSpec8_bounds (input : Input8) :
    -1021 ≤ outputScoreSpec (toMathInput input) ∧ outputScoreSpec (toMathInput input) ≤ 1020 := by
  have h2 := hiddenSpecAt8_2_bounds input
  have h4 := hiddenSpecAt8_4_bounds input
  have h5 := hiddenSpecAt8_5_bounds input
  have h6 := hiddenSpecAt8_6_bounds input
  have h7 := hiddenSpecAt8_7_bounds input
  have h :
      -1021 ≤ hiddenSpecAt (toMathInput input) 2 - hiddenSpecAt (toMathInput input) 4 -
        hiddenSpecAt (toMathInput input) 5 + hiddenSpecAt (toMathInput input) 6 -
        hiddenSpecAt (toMathInput input) 7 - 1 ∧
      hiddenSpecAt (toMathInput input) 2 - hiddenSpecAt (toMathInput input) 4 -
        hiddenSpecAt (toMathInput input) 5 + hiddenSpecAt (toMathInput input) 6 -
        hiddenSpecAt (toMathInput input) 7 - 1 ≤ 1020 := by
    omega
  simpa [outputScoreSpec, outputScoreSpecFromHidden, hiddenSpec, hiddenSpecFromGetter,
    hiddenSpecAt, hiddenSpecAtFromGetter, toMathInput, Input.getNat, w2At, b2] using h

@[simp] theorem wrap32_outputScoreSpec8 (input : Input8) :
    wrap32 (outputScoreSpec (toMathInput input)) = outputScoreSpec (toMathInput input) := by
  have h := outputScoreSpec8_bounds input
  exact wrap32_eq_self_of_bounds (by omega) (by omega)

@[simp] theorem outputScoreSpecFromHidden_hiddenSpec_eq_outputScoreSpec (input : Input8) :
    outputScoreSpecFromHidden (hiddenSpec (toMathInput input)) = outputScoreSpec (toMathInput input) := by
  rfl

end TinyMLP
