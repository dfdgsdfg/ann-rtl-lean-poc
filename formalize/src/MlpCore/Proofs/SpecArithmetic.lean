import MlpCore.Defs.SpecCore
import MlpCore.Interfaces.ArithmeticProofProvider

namespace MlpCore

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

def vanillaArithmeticProofProvider : ArithmeticProofProvider where
  int8MulInt8Bounds := int8_mul_int8_bounds
  int16MulInt8Bounds := int16_mul_int8_bounds

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

end MlpCore
