import TinyMLP.Machine

namespace TinyMLP

def IndexInvariant (s : State) : Prop :=
  match s.phase with
  | .idle => s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount
  | .loadInput => s.hiddenIdx ≤ hiddenCount ∧ s.inputIdx ≤ hiddenCount
  | .macHidden => s.hiddenIdx < hiddenCount ∧ s.inputIdx ≤ inputCount
  | .biasHidden => s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount
  | .actHidden => s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount
  | .nextHidden => s.hiddenIdx < hiddenCount ∧ s.inputIdx = 0
  | .macOutput => s.hiddenIdx = 0 ∧ s.inputIdx ≤ hiddenCount
  | .biasOutput => s.hiddenIdx = 0 ∧ s.inputIdx = hiddenCount
  | .done => s.hiddenIdx = 0 ∧ s.inputIdx = hiddenCount

theorem initialState_indexInvariant (input : Input8) :
    IndexInvariant (initialState input) := by
  simp [initialState, IndexInvariant]

theorem indexInvariant_hiddenIdx_le {s : State} (hs : IndexInvariant s) :
    s.hiddenIdx ≤ hiddenCount := by
  cases hphase : s.phase <;> simp [IndexInvariant, hphase] at hs ⊢ <;> omega

theorem indexInvariant_inputIdx_le {s : State} (hs : IndexInvariant s) :
    s.inputIdx ≤ hiddenCount := by
  cases hphase : s.phase <;> simp [IndexInvariant, hphase, inputCount, hiddenCount] at hs ⊢ <;> omega

theorem indexInvariant_macHidden {s : State} (hs : IndexInvariant s) (hphase : s.phase = .macHidden) :
    s.hiddenIdx < hiddenCount ∧ s.inputIdx ≤ inputCount := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_biasHidden {s : State} (hs : IndexInvariant s) (hphase : s.phase = .biasHidden) :
    s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_actHidden {s : State} (hs : IndexInvariant s) (hphase : s.phase = .actHidden) :
    s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_nextHidden {s : State} (hs : IndexInvariant s) (hphase : s.phase = .nextHidden) :
    s.hiddenIdx < hiddenCount ∧ s.inputIdx = 0 := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_macOutput {s : State} (hs : IndexInvariant s) (hphase : s.phase = .macOutput) :
    s.hiddenIdx = 0 ∧ s.inputIdx ≤ hiddenCount := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_biasOutput {s : State} (hs : IndexInvariant s) (hphase : s.phase = .biasOutput) :
    s.hiddenIdx = 0 ∧ s.inputIdx = hiddenCount := by
  simpa [IndexInvariant, hphase] using hs

theorem indexInvariant_done {s : State} (hs : IndexInvariant s) (hphase : s.phase = .done) :
    s.hiddenIdx = 0 ∧ s.inputIdx = hiddenCount := by
  simpa [IndexInvariant, hphase] using hs

theorem not_indexInvariant_macHidden_hiddenIdx_eq_hiddenCount {s : State}
    (hs : IndexInvariant s) (hphase : s.phase = .macHidden) :
    s.hiddenIdx ≠ hiddenCount := by
  have hlegal := indexInvariant_macHidden hs hphase
  omega

theorem not_indexInvariant_biasHidden_hiddenIdx_eq_hiddenCount {s : State}
    (hs : IndexInvariant s) (hphase : s.phase = .biasHidden) :
    s.hiddenIdx ≠ hiddenCount := by
  have hlegal := indexInvariant_biasHidden hs hphase
  omega

theorem step_preserves_indexInvariant {s : State} :
    IndexInvariant s → IndexInvariant (step s) := by
  intro hs
  cases hphase : s.phase with
  | idle =>
      simpa [IndexInvariant, step, hphase] using hs
  | loadInput =>
      simp [IndexInvariant, step, hphase, hiddenCount, inputCount]
  | macHidden =>
      rcases indexInvariant_macHidden hs hphase with ⟨hHidden, hInput⟩
      by_cases h : s.inputIdx < inputCount
      · simpa [IndexInvariant, step, hphase, h] using
          (show s.hiddenIdx < hiddenCount ∧ s.inputIdx + 1 ≤ inputCount from
            ⟨hHidden, Nat.succ_le_of_lt h⟩)
      · have hEq : s.inputIdx = inputCount := by
          omega
        simpa [IndexInvariant, step, hphase, h, hEq]
  | biasHidden =>
      rcases indexInvariant_biasHidden hs hphase with ⟨hHidden, hInput⟩
      simpa [IndexInvariant, step, hphase, hInput] using
        (show s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount from ⟨hHidden, hInput⟩)
  | actHidden =>
      rcases indexInvariant_actHidden hs hphase with ⟨hHidden, hInput⟩
      simpa [IndexInvariant, step, hphase, hInput] using
        (show s.hiddenIdx < hiddenCount ∧ 0 = 0 from ⟨hHidden, rfl⟩)
  | nextHidden =>
      rcases indexInvariant_nextHidden hs hphase with ⟨hHidden, hInput⟩
      by_cases h : s.hiddenIdx + 1 < hiddenCount
      · simp [IndexInvariant, step, hphase, h, hInput]
      · simp [IndexInvariant, step, hphase, h]
  | macOutput =>
      rcases indexInvariant_macOutput hs hphase with ⟨hHidden, hInput⟩
      by_cases h : s.inputIdx < hiddenCount
      · simpa [IndexInvariant, step, hphase, h, hHidden] using
          (show s.hiddenIdx = 0 ∧ s.inputIdx + 1 ≤ hiddenCount from
            ⟨hHidden, Nat.succ_le_of_lt h⟩)
      · have hEq : s.inputIdx = hiddenCount := by
          omega
        simp [IndexInvariant, step, hphase, hHidden, hEq]
  | biasOutput =>
      rcases indexInvariant_biasOutput hs hphase with ⟨hHidden, hInput⟩
      simp [IndexInvariant, step, hphase, hHidden, hInput]
  | done =>
      simpa [step, hphase] using hs

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
