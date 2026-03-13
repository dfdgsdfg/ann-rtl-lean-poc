import TinyMLP.Defs.FixedPointCore
import TinyMLP.ProofsVanilla.SpecArithmetic

namespace TinyMLP

@[simp] theorem w1Int8At_toInt (hiddenIdx inputIdx : Nat) (hinput : inputIdx < inputCount) :
    (w1Int8At hiddenIdx inputIdx).toInt = w1At hiddenIdx inputIdx := by
  have hi :
      hiddenIdx = 0 ∨ hiddenIdx = 1 ∨ hiddenIdx = 2 ∨ hiddenIdx = 3 ∨
        hiddenIdx = 4 ∨ hiddenIdx = 5 ∨ hiddenIdx = 6 ∨ hiddenIdx = 7 ∨ 8 ≤ hiddenIdx := by
    omega
  have hj : inputIdx = 0 ∨ inputIdx = 1 ∨ inputIdx = 2 ∨ inputIdx = 3 := by
    unfold inputCount at hinput
    omega
  rcases hi with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases hj with rfl | rfl | rfl | rfl <;> native_decide
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    rcases hj with rfl | rfl | rfl | rfl
    · have hw : w1At (8 + k) 0 = 0 := by
        have h1 : 8 + k ≠ 1 := by omega
        have h2 : 8 + k ≠ 2 := by omega
        have h3 : 8 + k ≠ 3 := by omega
        have h4 : 8 + k ≠ 4 := by omega
        have h5 : 8 + k ≠ 5 := by omega
        have h6 : 8 + k ≠ 6 := by omega
        have h7 : 8 + k ≠ 7 := by omega
        simp [w1At, h1, h2, h3, h4, h5, h6, h7]
      simp [w1Int8At, hw]
    · have hw : w1At (8 + k) 1 = 0 := by
        have h1 : 8 + k ≠ 1 := by omega
        have h2 : 8 + k ≠ 2 := by omega
        have h3 : 8 + k ≠ 3 := by omega
        have h4 : 8 + k ≠ 4 := by omega
        have h5 : 8 + k ≠ 5 := by omega
        have h6 : 8 + k ≠ 6 := by omega
        have h7 : 8 + k ≠ 7 := by omega
        simp [w1At, h1, h2, h3, h4, h5, h6, h7]
      simp [w1Int8At, hw]
    · have hw : w1At (8 + k) 2 = 0 := by
        have h1 : 8 + k ≠ 1 := by omega
        have h2 : 8 + k ≠ 2 := by omega
        have h3 : 8 + k ≠ 3 := by omega
        have h4 : 8 + k ≠ 4 := by omega
        have h5 : 8 + k ≠ 5 := by omega
        have h6 : 8 + k ≠ 6 := by omega
        have h7 : 8 + k ≠ 7 := by omega
        simp [w1At, h1, h2, h3, h4, h5, h6, h7]
      simp [w1Int8At, hw]
    · have hw : w1At (8 + k) 3 = 0 := by
        have h1 : 8 + k ≠ 1 := by omega
        have h2 : 8 + k ≠ 2 := by omega
        have h3 : 8 + k ≠ 3 := by omega
        have h4 : 8 + k ≠ 4 := by omega
        have h5 : 8 + k ≠ 5 := by omega
        have h6 : 8 + k ≠ 6 := by omega
        have h7 : 8 + k ≠ 7 := by omega
        simp [w1At, h1, h2, h3, h4, h5, h6, h7]
      simp [w1Int8At, hw]

@[simp] theorem w2Int8At_toInt (idx : Nat) (hidx : idx < hiddenCount) :
    (w2Int8At idx).toInt = w2At idx := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 := by
    unfold hiddenCount at hidx
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> native_decide

@[simp] theorem mul8x8To16_toInt (lhs rhs : Int8) :
    (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl

@[simp] theorem mul16x8To24_toInt (lhs : Int16Val) (rhs : Int8) :
    (mul16x8To24 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl

@[simp] theorem lift16To32_toInt (x : Int16Val) :
    (lift16To32 x).toInt = x.toInt := by
  rw [show lift16To32 x = Acc32.ofInt x.toInt from rfl, Acc32.toInt_ofInt]
  have hbounds : Int32Bounds x.toInt := int16_to_int32_bounds x
  have hlt : x.toInt < 2147483648 := by
    simpa using hbounds.2
  have hhi : x.toInt ≤ 2147483647 := by
    omega
  exact wrap32_eq_self_of_bounds hbounds.1 hhi

@[simp] theorem lift24To32_toInt (x : Int24Val) :
    (lift24To32 x).toInt = x.toInt := by
  rw [show lift24To32 x = Acc32.ofInt x.toInt from rfl, Acc32.toInt_ofInt]
  have hbounds : Int32Bounds x.toInt := int24_to_int32_bounds x
  have hlt : x.toInt < 2147483648 := by
    simpa using hbounds.2
  have hhi : x.toInt ≤ 2147483647 := by
    omega
  exact wrap32_eq_self_of_bounds hbounds.1 hhi

@[simp] theorem bias1Term_toInt (idx : Nat) :
    (bias1Term idx).toInt = wrap32 (b1At idx) := by
  rfl

@[simp] theorem bias2Term_toInt :
    bias2Term.toInt = wrap32 b2 := by
  rfl

@[simp] theorem wrap32_b1At (idx : Nat) :
    wrap32 (b1At idx) = b1At idx := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 ∨ 8 ≤ idx := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | hge
  · decide
  · decide
  · decide
  · decide
  · decide
  · decide
  · decide
  · decide
  · rcases Nat.exists_eq_add_of_le hge with ⟨k, rfl⟩
    have hb : b1At (8 + k) = 0 := by
      have h1 : 8 + k ≠ 1 := by omega
      have h2 : 8 + k ≠ 2 := by omega
      have h3 : 8 + k ≠ 3 := by omega
      have h4 : 8 + k ≠ 4 := by omega
      have h5 : 8 + k ≠ 5 := by omega
      have h6 : 8 + k ≠ 6 := by omega
      have h7 : 8 + k ≠ 7 := by omega
      set_option linter.unusedSimpArgs false in
        simp [b1At, h1, h2, h3, h4, h5, h6, h7]
    rw [hb]
    exact wrap32_eq_self_of_bounds (by omega) (by omega)

@[simp] theorem wrap32_b2 :
    wrap32 b2 = b2 := by
  simpa [b2] using
    (wrap32_eq_self_of_bounds (x := (-1 : Int)) (by omega) (by omega))

theorem hiddenMacTermAt_toInt (input : Input8) (hiddenIdx inputIdx : Nat) :
    (hinput : inputIdx < inputCount) →
    (hiddenMacTermAt input hiddenIdx inputIdx).toInt =
      w1At hiddenIdx inputIdx * (toMathInput input).getNat inputIdx := by
  intro hinput
  simp [hiddenMacTermAt, w1Int8At_toInt hiddenIdx inputIdx hinput, Int.mul_comm]

@[simp] theorem hiddenMacAccAt_toInt (input : Input8) (idx : Nat) :
    (hiddenMacAccAt input idx).toInt = wrap32 (hiddenDotAt (toMathInput input) idx) := by
  have hdot :
      hiddenDotAt (toMathInput input) idx =
        w1At idx 0 * (toMathInput input).getNat 0 +
          w1At idx 1 * (toMathInput input).getNat 1 +
          w1At idx 2 * (toMathInput input).getNat 2 +
          w1At idx 3 * (toMathInput input).getNat 3 := by
    rfl
  rw [hdot]
  have h0 := hiddenMacTermAt_toInt input idx 0 (by decide)
  have h1 := hiddenMacTermAt_toInt input idx 1 (by decide)
  have h2 := hiddenMacTermAt_toInt input idx 2 (by decide)
  have h3 := hiddenMacTermAt_toInt input idx 3 (by decide)
  simp [hiddenMacAccAt, acc32, Acc32.toInt_ofInt, h0, h1, h2, h3, wrap32_add_wrap32, Int.add_assoc]

theorem outputMacTermAt_toInt (hidden : Hidden16) (idx : Nat) (hidx : idx < hiddenCount) :
    (outputMacTermAt hidden idx).toInt = hidden.toHidden.getNat idx * w2At idx := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 := by
    unfold hiddenCount at hidx
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [outputMacTermAt, Hidden16.getCellNat, Hidden16.getNat, Hidden16.toHidden,
      Hidden.getNat, Int16Val.toInt, w2Int8At, w2At]

@[simp] theorem outputMacAccFromHidden_toInt (hidden : Hidden16) :
    (outputMacAccFromHidden hidden).toInt =
      wrap32 (hidden.toHidden.getNat 0 * w2At 0 + hidden.toHidden.getNat 1 * w2At 1 +
        hidden.toHidden.getNat 2 * w2At 2 + hidden.toHidden.getNat 3 * w2At 3 +
        hidden.toHidden.getNat 4 * w2At 4 + hidden.toHidden.getNat 5 * w2At 5 +
        hidden.toHidden.getNat 6 * w2At 6 + hidden.toHidden.getNat 7 * w2At 7) := by
  have h0 := outputMacTermAt_toInt hidden 0 (by decide)
  have h1 := outputMacTermAt_toInt hidden 1 (by decide)
  have h2 := outputMacTermAt_toInt hidden 2 (by decide)
  have h3 := outputMacTermAt_toInt hidden 3 (by decide)
  have h4 := outputMacTermAt_toInt hidden 4 (by decide)
  have h5 := outputMacTermAt_toInt hidden 5 (by decide)
  have h6 := outputMacTermAt_toInt hidden 6 (by decide)
  have h7 := outputMacTermAt_toInt hidden 7 (by decide)
  simp [outputMacAccFromHidden, acc32, Acc32.toInt_ofInt, h0, h1, h2, h3, h4, h5, h6, h7,
    wrap32_add_wrap32, Int.add_assoc]

@[simp] theorem acc32_toInt (acc term : Acc32) :
    (acc32 acc term).toInt = wrap32 (acc.toInt + term.toInt) := by
  rfl

@[simp] theorem relu16_toInt (x : Acc32) :
    (relu16 x).toInt = wrap16 (relu x.toInt) := by
  rfl

@[simp] theorem hiddenPreFixedAt_toInt (input : Input8) (idx : Nat) :
    (hiddenPreFixedAt input idx).toInt = wrap32 (hiddenPreAt (toMathInput input) idx) := by
  have hpre :
      hiddenPreAt (toMathInput input) idx =
        w1At idx 0 * (toMathInput input).getNat 0 +
          w1At idx 1 * (toMathInput input).getNat 1 +
          w1At idx 2 * (toMathInput input).getNat 2 +
          w1At idx 3 * (toMathInput input).getNat 3 +
          b1At idx := by
    rfl
  rw [hpre]
  have h0 := hiddenMacTermAt_toInt input idx 0 (by decide)
  have h1 := hiddenMacTermAt_toInt input idx 1 (by decide)
  have h2 := hiddenMacTermAt_toInt input idx 2 (by decide)
  have h3 := hiddenMacTermAt_toInt input idx 3 (by decide)
  simp [hiddenPreFixedAt, hiddenMacAccAt, acc32, Acc32.toInt_ofInt, h0, h1, h2, h3,
    wrap32_add_wrap32, Int.add_assoc, wrap32_b1At]

private theorem wrap32_hiddenPreAt8 (input : Input8) (idx : Nat) (hidx : idx < hiddenCount) :
    wrap32 (hiddenPreAt (toMathInput input) idx) = hiddenPreAt (toMathInput input) idx := by
  have hcases :
      idx = 0 ∨ idx = 1 ∨ idx = 2 ∨ idx = 3 ∨ idx = 4 ∨ idx = 5 ∨ idx = 6 ∨ idx = 7 := by
    unfold hiddenCount at hidx
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact wrap32_hiddenPreAt8_0 input
  · exact wrap32_hiddenPreAt8_1 input
  · exact wrap32_hiddenPreAt8_2 input
  · exact wrap32_hiddenPreAt8_3 input
  · exact wrap32_hiddenPreAt8_4 input
  · exact wrap32_hiddenPreAt8_5 input
  · exact wrap32_hiddenPreAt8_6 input
  · exact wrap32_hiddenPreAt8_7 input

theorem hiddenFixedAt_eq_ofInt_hiddenSpecAt8 (input : Input8) (idx : Nat) (hidx : idx < hiddenCount) :
    hiddenFixedAt input idx = Int16Val.ofInt (hiddenSpecAt (toMathInput input) idx) := by
  apply Subtype.ext
  change (hiddenFixedAt input idx).toInt = wrap16 (hiddenSpecAt (toMathInput input) idx)
  simp [hiddenFixedAt, hiddenPreFixedAt_toInt]
  rw [wrap32_hiddenPreAt8 input idx hidx]
  have hspec : hiddenSpecAt (toMathInput input) idx = relu (hiddenPreAt (toMathInput input) idx) := by
    rfl
  rw [hspec]

@[simp] theorem hiddenFixed_eq_hiddenSpec8 (input : Input8) :
    hiddenFixed input = Hidden16.ofHidden (hiddenSpec (toMathInput input)) := by
  simp [hiddenFixed, Hidden16.ofHidden, hiddenSpec_eq_fields,
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 0 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 1 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 2 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 3 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 4 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 5 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 6 (by decide),
    hiddenFixedAt_eq_ofInt_hiddenSpecAt8 input 7 (by decide)]

@[simp] theorem hiddenFixed_toHidden_eq_hiddenSpec8 (input : Input8) :
    (hiddenFixed input).toHidden = hiddenSpec (toMathInput input) := by
  rw [hiddenFixed_eq_hiddenSpec8, Hidden16.toHidden_ofHidden, hiddenSpec_eq_fields]
  rw [wrap16_hiddenSpecAt8_0, wrap16_hiddenSpecAt8_1, wrap16_hiddenSpecAt8_2,
    wrap16_hiddenSpecAt8_3, wrap16_hiddenSpecAt8_4, wrap16_hiddenSpecAt8_5,
    wrap16_hiddenSpecAt8_6, wrap16_hiddenSpecAt8_7]

@[simp] theorem hiddenFixed_eq_hiddenSpec (input : Input8) :
    (hiddenFixed input).toHidden = hiddenSpec (toMathInput input) := by
  exact hiddenFixed_toHidden_eq_hiddenSpec8 input

@[simp] theorem outputScoreFixedFromHidden_toInt (hidden : Hidden16) :
    (outputScoreFixedFromHidden hidden).toInt = wrap32 (outputScoreSpecFromHidden hidden.toHidden) := by
  rw [show outputScoreFixedFromHidden hidden = acc32 (outputMacAccFromHidden hidden) bias2Term from rfl]
  rw [acc32_toInt, outputMacAccFromHidden_toInt, bias2Term_toInt]
  rw [wrap32_add_wrap32, wrap32_b2]
  simp [outputScoreSpecFromHidden, Hidden.getNat, Hidden16.toHidden, b2,
    Int.add_assoc, Int.mul_comm]

@[simp] theorem outputScoreFixed_eq_outputScoreSpec8 (input : Input8) :
    (outputScoreFixed input).toInt = outputScoreSpec (toMathInput input) := by
  rw [show outputScoreFixed input = outputScoreFixedFromHidden (hiddenFixed input) from rfl]
  rw [outputScoreFixedFromHidden_toInt, hiddenFixed_toHidden_eq_hiddenSpec8,
    outputScoreSpecFromHidden_hiddenSpec_eq_outputScoreSpec, wrap32_outputScoreSpec8]

@[simp] theorem outputScoreFixed_eq_outputScoreSpec (input : Input8) :
    (outputScoreFixed input).toInt = outputScoreSpec (toMathInput input) := by
  exact outputScoreFixed_eq_outputScoreSpec8 input

@[simp] theorem mlpFixed_eq_mlpSpec (input : Input8) :
    mlpFixed input = mlpSpec (toMathInput input) := by
  simp [mlpFixed, mlpSpec]

end TinyMLP
