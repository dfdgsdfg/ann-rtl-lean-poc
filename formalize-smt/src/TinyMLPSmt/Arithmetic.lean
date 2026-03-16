import Smt
import TinyMLP.Defs.SpecCore
import TinyMLP.Interfaces.ArithmeticProofProvider
import TinyMLP.Defs.FixedPointCore

namespace TinyMLPSmt

open TinyMLP

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

theorem int8_mul_int8_bounds_smt (lhs rhs : Int8) :
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

theorem int16_mul_int8_bounds_smt (lhs : Int16Val) (rhs : Int8) :
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
  int8MulInt8Bounds := int8_mul_int8_bounds_smt
  int16MulInt8Bounds := int16_mul_int8_bounds_smt

example : True := by
  fail_if_success
    let _ : ArithmeticProofProvider := inferInstance
  trivial

section Smoke

local instance : ArithmeticProofProvider := smtArithmeticProofProvider

theorem shared_fixed_point_overlay_smoke (lhs rhs : Int8) :
    (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl

end Smoke

end TinyMLPSmt
