import Smt
import MlpCore.Defs.SpecCore
import MlpCore.Interfaces.ArithmeticProofProvider

namespace MlpCoreSmt

open MlpCore

private theorem int8_mul_int8_interval_bounds_smt
    (x y : Int)
    (hxlo : (-128 : Int) ≤ x) (hxhi : x ≤ 127)
    (hylo : (-128 : Int) ≤ y) (hyhi : y ≤ 127) :
    (-16384 : Int) ≤ x * y ∧ x * y ≤ 16384 := by
  constructor
  · by_cases hnonneg : 0 ≤ y
    · have hmul : (-128 : Int) * y ≤ x * y := by
        smt [hxlo, hnonneg]
      have hbase : (-16384 : Int) ≤ (-128 : Int) * y := by
        omega
      omega
    · have hnonpos : y ≤ 0 := by
        omega
      have hmul : (127 : Int) * y ≤ x * y := by
        smt [hxhi, hnonpos]
      have hbase : (-16384 : Int) ≤ (127 : Int) * y := by
        omega
      omega
  · by_cases hnonneg : 0 ≤ y
    · have hmul : x * y ≤ (127 : Int) * y := by
        smt [hxhi, hnonneg]
      have hbase : (127 : Int) * y ≤ (16384 : Int) := by
        omega
      omega
    · have hnonpos : y ≤ 0 := by
        omega
      have hmul : x * y ≤ (-128 : Int) * y := by
        smt [hxlo, hnonpos]
      have hbase : (-128 : Int) * y ≤ (16384 : Int) := by
        omega
      omega

private theorem int16_mul_int8_interval_bounds_smt
    (x y : Int)
    (hxlo : (-32768 : Int) ≤ x) (hxhi : x ≤ 32767)
    (hylo : (-128 : Int) ≤ y) (hyhi : y ≤ 127) :
    (-4194304 : Int) ≤ x * y ∧ x * y ≤ 4194304 := by
  constructor
  · by_cases hnonneg : 0 ≤ y
    · have hmul : (-32768 : Int) * y ≤ x * y := by
        smt [hxlo, hnonneg]
      have hbase : (-4194304 : Int) ≤ (-32768 : Int) * y := by
        omega
      omega
    · have hnonpos : y ≤ 0 := by
        omega
      have hmul : (32767 : Int) * y ≤ x * y := by
        smt [hxhi, hnonpos]
      have hbase : (-4194304 : Int) ≤ (32767 : Int) * y := by
        omega
      omega
  · by_cases hnonneg : 0 ≤ y
    · have hmul : x * y ≤ (32767 : Int) * y := by
        smt [hxhi, hnonneg]
      have hbase : (32767 : Int) * y ≤ (4194304 : Int) := by
        omega
      omega
    · have hnonpos : y ≤ 0 := by
        omega
      have hmul : x * y ≤ (-32768 : Int) * y := by
        smt [hxlo, hnonpos]
      have hbase : (-32768 : Int) * y ≤ (4194304 : Int) := by
        omega
      omega

private theorem int8_toInt_le_max (x : Int8) : x.toInt ≤ (127 : Int) := by
  have hx : x.toInt < 2 ^ 7 := x.toInt_lt
  omega

private theorem int16_toInt_le_max (x : Int16Val) : x.toInt ≤ (32767 : Int) := by
  have hx : x.toInt < 2 ^ 15 := x.toInt_lt
  omega

theorem int8_mul_int8_bounds (lhs rhs : Int8) :
    Int16Bounds (lhs.toInt * rhs.toInt) := by
  have hxlo : (-128 : Int) ≤ lhs.toInt := by
    simpa using lhs.le_toInt
  have hxhi : lhs.toInt ≤ (127 : Int) := int8_toInt_le_max lhs
  have hylo : (-128 : Int) ≤ rhs.toInt := by
    simpa using rhs.le_toInt
  have hyhi : rhs.toInt ≤ (127 : Int) := int8_toInt_le_max rhs
  have h :=
      int8_mul_int8_interval_bounds_smt lhs.toInt rhs.toInt hxlo hxhi hylo hyhi
  constructor
  · omega
  · omega

theorem int16_mul_int8_bounds (lhs : Int16Val) (rhs : Int8) :
    Int24Bounds (lhs.toInt * rhs.toInt) := by
  have hxlo : (-32768 : Int) ≤ lhs.toInt := by
    simpa using lhs.le_toInt
  have hxhi : lhs.toInt ≤ (32767 : Int) := int16_toInt_le_max lhs
  have hylo : (-128 : Int) ≤ rhs.toInt := by
    simpa using rhs.le_toInt
  have hyhi : rhs.toInt ≤ (127 : Int) := int8_toInt_le_max rhs
  have h :=
      int16_mul_int8_interval_bounds_smt lhs.toInt rhs.toInt hxlo hxhi hylo hyhi
  constructor
  · omega
  · omega

def smtArithmeticProofProvider : ArithmeticProofProvider where
  int8MulInt8Bounds := int8_mul_int8_bounds
  int16MulInt8Bounds := int16_mul_int8_bounds

theorem int8_mul_int8_bounds_smt (lhs rhs : Int8) :
    Int16Bounds (lhs.toInt * rhs.toInt) :=
  int8_mul_int8_bounds lhs rhs

theorem int16_mul_int8_bounds_smt (lhs : Int16Val) (rhs : Int8) :
    Int24Bounds (lhs.toInt * rhs.toInt) :=
  int16_mul_int8_bounds lhs rhs

theorem int16_to_int32_bounds (x : Int16Val) : Int32Bounds x.toInt := by
  have hlo : -2 ^ 15 ≤ x.toInt := x.le_toInt
  have hhi : x.toInt < 2 ^ 15 := x.toInt_lt
  constructor <;> omega

theorem int24_to_int32_bounds (x : Int24Val) : Int32Bounds x.toInt := by
  have hlo : -2 ^ 23 ≤ x.toInt := x.le_toInt
  have hhi : x.toInt < 2 ^ 23 := x.toInt_lt
  constructor <;> omega

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

end MlpCoreSmt
