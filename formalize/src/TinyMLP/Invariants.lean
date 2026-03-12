import TinyMLP.Machine

namespace TinyMLP

def IndexInvariant (s : State) : Prop :=
  s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount

theorem initialState_indexInvariant (input : Input8) :
    IndexInvariant (initialState input) := by
  simp [initialState, IndexInvariant]

theorem step_preserves_indexInvariant {s : State} :
    IndexInvariant s → IndexInvariant (step s) := by
  intro hs
  rcases hs with ⟨hHidden, hInput⟩
  cases hphase : s.phase with
  | idle =>
    simpa [IndexInvariant, step, hphase] using (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)
  | loadInput =>
    simp [IndexInvariant, step, hphase, hiddenCount]
  | macHidden =>
    by_cases h : s.inputIdx < inputCount
    · simpa [IndexInvariant, step, hphase, h] using
        (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx + 1 ≤ hiddenCount from
          ⟨hHidden, Nat.le_trans (Nat.succ_le_of_lt h) (by decide : inputCount ≤ hiddenCount)⟩)
    · simpa [IndexInvariant, step, hphase, h] using
        (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)
  | biasHidden =>
    simpa [IndexInvariant, step, hphase] using (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)
  | actHidden =>
    simpa [IndexInvariant, step, hphase, hiddenCount] using
      (show s.hiddenIdx ≤ hiddenCount ∧ 0 ≤ hiddenCount from ⟨hHidden, by simp [hiddenCount]⟩)
  | nextHidden =>
    by_cases h : s.hiddenIdx + 1 < 8
    · simpa [IndexInvariant, step, hphase, h, hiddenCount] using
        (show s.hiddenIdx + 1 ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from
          ⟨Nat.le_of_lt h, hInput⟩)
    · simp [IndexInvariant, step, hphase, h, hiddenCount]
  | macOutput =>
    by_cases h : s.inputIdx < hiddenCount
    · simpa [IndexInvariant, step, hphase, h] using
        (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx + 1 ≤ hiddenCount from
          ⟨hHidden, Nat.succ_le_of_lt h⟩)
    · simpa [IndexInvariant, step, hphase, h] using
        (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)
  | biasOutput =>
    simpa [IndexInvariant, step, hphase] using (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)
  | done =>
    simpa [IndexInvariant, step, hphase] using (show s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount from ⟨hHidden, hInput⟩)

theorem run_preserves_indexInvariant (n : Nat) {s : State} :
    IndexInvariant s → IndexInvariant (run n s) := by
  intro hs
  induction n generalizing s with
  | zero =>
      simpa [run] using hs
  | succ n ih =>
      have hstep : IndexInvariant (step s) := step_preserves_indexInvariant hs
      simpa [run] using ih hstep

theorem initial_run_preserves_indexInvariant (n : Nat) (input : Input8) :
    IndexInvariant (run n (initialState input)) := by
  exact run_preserves_indexInvariant n (initialState_indexInvariant input)

end TinyMLP
