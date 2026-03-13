import TinyMLP.Simulation

namespace TinyMLP

/-!
The public temporal theorem surface for this milestone is:

- `acceptedStart_eventually_done`
- `busy_during_active_window`
- `done_implies_outputValid`
- `output_stable_while_done`
- `done_hold_while_start_high`
- `done_to_idle_when_start_low`
- `phase_ordering_ok`
- `hiddenGuard_before_biasHidden`
- `hiddenGuard_no_mac_work`
- `hiddenGuard_no_out_of_range_reads`
- `lastHiddenMac_to_biasHidden`
- `lastHiddenNeuron_handoff_no_duplicate_or_skip_work`
- `lastHiddenNeuron_to_macOutput`
- `hiddenBoundary_no_duplicate_or_skip_work`
- `outputGuard_before_biasOutput`
- `outputGuard_no_mac_work`
- `outputGuard_no_out_of_range_reads`
- `lastOutputMac_to_biasOutput`
- `outputBoundary_no_duplicate_or_skip_work`
- `biasOutput_registers_result`
-/

structure CtrlSample where
  start : Bool
deriving Repr, DecidableEq

def acceptedStart (sample : CtrlSample) (s : State) : Prop :=
  s.phase = .idle ∧ sample.start = true

def busyOf (s : State) : Prop :=
  s.phase ≠ .idle ∧ s.phase ≠ .done

def doneOf (s : State) : Prop :=
  s.phase = .done

def outputValidOf (s : State) : Prop :=
  doneOf s

def SameDataFields (before after : State) : Prop :=
  after.regs = before.regs ∧
    after.hidden = before.hidden ∧
    after.accumulator = before.accumulator ∧
    after.hiddenIdx = before.hiddenIdx ∧
    after.inputIdx = before.inputIdx ∧
    after.output = before.output

def stableOutputOn (t : Nat) (trace : Nat → State) : Prop :=
  ∀ n, (∀ m, t ≤ m → m ≤ t + n → doneOf (trace m)) →
    (trace (t + n)).output = (trace t).output

def timedStep (sample : CtrlSample) (s : State) : State :=
  match s.phase with
  | .idle =>
      if sample.start then
        step s
      else
        s
  | .done =>
      if sample.start then
        s
      else
        { s with phase := .idle }
  | _ =>
      step s

def timedRun : Nat → (Nat → CtrlSample) → State → State
  | 0, _, s => s
  | n + 1, samples, s =>
      timedRun n (fun k => samples (k + 1)) (timedStep (samples 0) s)

def rtlTrace (input : Input8) (samples : Nat → CtrlSample) : Nat → State
  | 0 => initialState input
  | n + 1 => timedStep (samples n) (rtlTrace input samples n)

def initialControl : ControlState :=
  { phase := .idle, hiddenIdx := 0, inputIdx := 0 }

def timedControlStep (sample : CtrlSample) (cs : ControlState) : ControlState :=
  match cs.phase with
  | .idle =>
      if sample.start then
        controlStep cs
      else
        cs
  | .done =>
      if sample.start then
        cs
      else
        { cs with phase := .idle }
  | _ =>
      controlStep cs

def timedControlRun : Nat → (Nat → CtrlSample) → ControlState → ControlState
  | 0, _, cs => cs
  | n + 1, samples, cs =>
      timedControlRun n (fun k => samples (k + 1)) (timedControlStep (samples 0) cs)

def timedControlTrace (samples : Nat → CtrlSample) : Nat → ControlState
  | 0 => initialControl
  | n + 1 => timedControlStep (samples n) (timedControlTrace samples n)

def holdHigh : Nat → CtrlSample :=
  fun _ => { start := true }

theorem timedStep_idle_wait (sample : CtrlSample) (s : State)
    (hidle : s.phase = .idle) (hstart : sample.start = false) :
    timedStep sample s = s := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp [timedStep, hstart] at hidle ⊢

theorem timedStep_idle_start (sample : CtrlSample) (s : State)
    (hidle : s.phase = .idle) (hstart : sample.start = true) :
    timedStep sample s = step s := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp [timedStep, hstart] at hidle ⊢

theorem timedStep_done_hold (sample : CtrlSample) (s : State)
    (hdone : s.phase = .done) (hstart : sample.start = true) :
    timedStep sample s = s := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp [timedStep, hstart] at hdone ⊢

theorem timedStep_done_restart (sample : CtrlSample) (s : State)
    (hdone : s.phase = .done) (hstart : sample.start = false) :
    timedStep sample s = { s with phase := .idle } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp [timedStep, hstart] at hdone ⊢

theorem done_hold_while_start_high (sample : CtrlSample) (s : State)
    (hdone : doneOf s) (hstart : sample.start = true) :
    timedStep sample s = s :=
  timedStep_done_hold sample s hdone hstart

theorem done_to_idle_when_start_low (sample : CtrlSample) (s : State)
    (hdone : doneOf s) (hstart : sample.start = false) :
    timedStep sample s = { s with phase := .idle } :=
  timedStep_done_restart sample s hdone hstart

theorem sameDataFields_of_phaseUpdate (s : State) (phase : Phase) :
    SameDataFields s { s with phase := phase } := by
  cases s <;> simp [SameDataFields]

theorem timedStep_eq_step_of_active {sample : CtrlSample} {s : State}
    (hidle : s.phase ≠ .idle) (hdone : s.phase ≠ .done) :
    timedStep sample s = step s := by
  cases hphase : s.phase <;> simp [timedStep, hphase] at hidle hdone ⊢

theorem timedStep_preserves_indexInvariant {sample : CtrlSample} {s : State} :
    IndexInvariant s → IndexInvariant (timedStep sample s) := by
  intro hs
  cases hphase : s.phase with
  | idle =>
      cases hstart : sample.start with
      | false =>
          simpa [timedStep, hphase, hstart] using hs
      | true =>
          simpa [timedStep, hphase, hstart] using step_preserves_indexInvariant hs
  | loadInput =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | macHidden =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | biasHidden =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | actHidden =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | nextHidden =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | macOutput =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | biasOutput =>
      simpa [timedStep, hphase] using step_preserves_indexInvariant hs
  | done =>
      cases hstart : sample.start <;>
        simp [timedStep, hphase, hstart, IndexInvariant, hiddenCount] at hs ⊢ <;> omega

theorem controlOf_timedStep (sample : CtrlSample) (s : State) :
    controlOf (timedStep sample s) = timedControlStep sample (controlOf s) := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase with
      | idle =>
          cases hstart : sample.start <;>
            simp [timedStep, timedControlStep, controlOf, controlStep, step, hstart]
      | loadInput =>
          simp [timedStep, timedControlStep, controlOf, controlStep, step]
      | macHidden =>
          by_cases h : inputIdx < inputCount
          · have h4 : inputIdx < 4 := by simpa [inputCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h4, inputCount]
          · have h4 : ¬ inputIdx < 4 := by simpa [inputCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h4, inputCount]
      | biasHidden =>
          simp [timedStep, timedControlStep, controlOf, controlStep, step]
      | actHidden =>
          simp [timedStep, timedControlStep, controlOf, controlStep, step]
      | nextHidden =>
          by_cases h : hiddenIdx + 1 < hiddenCount
          · have h8 : hiddenIdx + 1 < 8 := by simpa [hiddenCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h8, hiddenCount]
          · have h8 : ¬ hiddenIdx + 1 < 8 := by simpa [hiddenCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h8, hiddenCount]
      | macOutput =>
          by_cases h : inputIdx < hiddenCount
          · have h8 : inputIdx < 8 := by simpa [hiddenCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h8, hiddenCount]
          · have h8 : ¬ inputIdx < 8 := by simpa [hiddenCount] using h
            simp [timedStep, timedControlStep, controlOf, controlStep, step, h8, hiddenCount]
      | biasOutput =>
          simp [timedStep, timedControlStep, controlOf, controlStep, step]
      | done =>
          cases hstart : sample.start <;>
            simp [timedStep, timedControlStep, controlOf, hstart]

theorem controlOf_rtlTrace (input : Input8) (samples : Nat → CtrlSample) (n : Nat) :
    controlOf (rtlTrace input samples n) = timedControlTrace samples n := by
  induction n with
  | zero =>
      simp [rtlTrace, timedControlTrace, controlOf, initialState, initialControl]
  | succ n ih =>
      simp [rtlTrace, timedControlTrace, controlOf_timedStep, ih]

theorem rtlTrace_preserves_indexInvariant (input : Input8) (samples : Nat → CtrlSample) (n : Nat) :
    IndexInvariant (rtlTrace input samples n) := by
  induction n with
  | zero =>
      simp [rtlTrace, initialState_indexInvariant]
  | succ n ih =>
      simp [rtlTrace]
      exact timedStep_preserves_indexInvariant ih

private theorem controlRun_active_window (k : Fin totalCycles) (hpos : 0 < k.1) :
    let ph := (controlRun k.1 initialControl).phase
    ph ≠ .idle ∧ ph ≠ .done := by
  native_decide +revert

private theorem run_active_window (input : Input8) (k : Fin totalCycles) (hpos : 0 < k.1) :
    busyOf (run k.1 (initialState input)) := by
  have hphase :
      (controlRun k.1 initialControl).phase = (run k.1 (initialState input)).phase := by
    simpa [initialControl, controlOf, initialState] using
      congrArg ControlState.phase (control_run_agrees k.1 (initialState input))
  have hactive := controlRun_active_window k hpos
  unfold busyOf
  rw [← hphase]
  exact hactive

theorem rtlTrace_matches_run_prefix (input : Input8) (samples : Nat → CtrlSample)
    (hstart : (samples 0).start = true) :
    ∀ n, n ≤ totalCycles → rtlTrace input samples n = run n (initialState input) := by
  intro n hle
  induction n with
  | zero =>
      simp [rtlTrace, run]
  | succ n ih =>
      rw [rtlTrace, run, ih (Nat.le_of_succ_le hle), step_run_comm n (initialState input)]
      cases n with
      | zero =>
          simp [run, initialState, timedStep, hstart]
      | succ m =>
          have hlt : Nat.succ m < totalCycles := by
            exact Nat.lt_of_lt_of_le (Nat.lt_succ_self (Nat.succ m)) hle
          let k : Fin totalCycles := ⟨Nat.succ m, hlt⟩
          have hkpos : 0 < k.1 := by
            simp [k]
          have hbusy : busyOf (run (Nat.succ m) (initialState input)) :=
            run_active_window input k hkpos
          exact timedStep_eq_step_of_active hbusy.1 hbusy.2

theorem acceptedStart_eventually_done (input : Input8) (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) (initialState input)) :
    doneOf (rtlTrace input samples totalCycles) := by
  rcases haccept with ⟨_, hstart⟩
  rw [rtlTrace_matches_run_prefix input samples hstart totalCycles (Nat.le_refl _)]
  exact rtl_terminates input

theorem busy_during_active_window (input : Input8) (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) (initialState input))
    (k : Fin totalCycles) (hpos : 0 < k.1) :
    busyOf (rtlTrace input samples k.1) := by
  rcases haccept with ⟨_, hstart⟩
  rw [rtlTrace_matches_run_prefix input samples hstart k.1 (Nat.le_of_lt k.2)]
  exact run_active_window input k hpos

theorem done_implies_outputValid (s : State) :
    doneOf s → outputValidOf s := by
  intro hdone
  exact hdone

theorem timedStep_done_preserves_output {sample : CtrlSample} {s : State}
    (hdone : doneOf s) (hnext : doneOf (timedStep sample s)) :
    (timedStep sample s).output = s.output := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> cases hstart : sample.start <;>
        simp [doneOf, timedStep, hstart] at hdone hnext ⊢

theorem output_stable_while_done (input : Input8) (samples : Nat → CtrlSample) (t : Nat) :
    stableOutputOn t (rtlTrace input samples) := by
  intro n hdoneWindow
  induction n with
  | zero =>
      rfl
  | succ n ih =>
      have hprefix : ∀ m, t ≤ m → m ≤ t + n → doneOf (rtlTrace input samples m) := by
        intro m htm hmn
        exact hdoneWindow m htm (Nat.le_trans hmn (Nat.le_succ _))
      have hcurrDone : doneOf (rtlTrace input samples (t + n)) :=
        hdoneWindow (t + n) (Nat.le_add_right _ _) (Nat.le_succ _)
      have hnextDone : doneOf (rtlTrace input samples (t + n + 1)) := by
        exact hdoneWindow (t + n + 1) (Nat.le_add_right t (n + 1)) (Nat.le_refl _)
      have hstepOut :
          (rtlTrace input samples (t + n + 1)).output =
            (rtlTrace input samples (t + n)).output := by
        simpa [rtlTrace] using
          timedStep_done_preserves_output (sample := samples (t + n))
            (s := rtlTrace input samples (t + n)) hcurrDone hnextDone
      calc
        (rtlTrace input samples (t + n + 1)).output =
            (rtlTrace input samples (t + n)).output := hstepOut
        _ = (rtlTrace input samples t).output := ih hprefix

def AllowedPhaseTransition : Phase → Phase → Prop
  | .idle, .idle => True
  | .idle, .loadInput => True
  | .loadInput, .macHidden => True
  | .macHidden, .macHidden => True
  | .macHidden, .biasHidden => True
  | .biasHidden, .actHidden => True
  | .actHidden, .nextHidden => True
  | .nextHidden, .macHidden => True
  | .nextHidden, .macOutput => True
  | .macOutput, .macOutput => True
  | .macOutput, .biasOutput => True
  | .biasOutput, .done => True
  | .done, .done => True
  | .done, .idle => True
  | _, _ => False

theorem phase_ordering_ok (sample : CtrlSample) (s : State) :
    AllowedPhaseTransition s.phase (timedStep sample s).phase := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase with
      | idle =>
          cases hstart : sample.start <;>
            simp [AllowedPhaseTransition, timedStep, step, hstart]
      | loadInput =>
          simp [AllowedPhaseTransition, timedStep, step]
      | macHidden =>
          by_cases h : inputIdx < inputCount
          · have h4 : inputIdx < 4 := by simpa [inputCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h4, inputCount]
          · have h4 : ¬ inputIdx < 4 := by simpa [inputCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h4, inputCount]
      | biasHidden =>
          simp [AllowedPhaseTransition, timedStep, step]
      | actHidden =>
          simp [AllowedPhaseTransition, timedStep, step]
      | nextHidden =>
          by_cases h : hiddenIdx + 1 < hiddenCount
          · have h8 : hiddenIdx + 1 < 8 := by simpa [hiddenCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h8, hiddenCount]
          · have h8 : ¬ hiddenIdx + 1 < 8 := by simpa [hiddenCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h8, hiddenCount]
      | macOutput =>
          by_cases h : inputIdx < hiddenCount
          · have h8 : inputIdx < 8 := by simpa [hiddenCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h8, hiddenCount]
          · have h8 : ¬ inputIdx < 8 := by simpa [hiddenCount] using h
            simp [AllowedPhaseTransition, timedStep, step, h8, hiddenCount]
      | biasOutput =>
          simp [AllowedPhaseTransition, timedStep, step]
      | done =>
          cases hstart : sample.start <;>
            simp [AllowedPhaseTransition, timedStep, hstart]

theorem hiddenGuard_before_biasHidden (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    timedStep sample s = { s with phase := .biasHidden } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      have hinput : inputIdx = inputCount := by
        simpa using hidx
      subst inputIdx
      simp [timedStep, step, inputCount]

theorem hiddenGuard_no_mac_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    SameDataFields s (timedStep sample s) := by
  rw [hiddenGuard_before_biasHidden sample s hphase hidx]
  exact sameDataFields_of_phaseUpdate s .biasHidden

theorem hiddenGuard_no_out_of_range_reads (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    SameDataFields s (timedStep sample s) ∧
      (timedStep sample s).phase = .biasHidden := by
  rw [hiddenGuard_before_biasHidden sample s hphase hidx]
  exact ⟨sameDataFields_of_phaseUpdate s .biasHidden, by simp⟩

theorem lastHiddenMac_to_biasHidden (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    (timedStep sample s).phase = .biasHidden := by
  simpa [hphase, hidx] using congrArg State.phase
    (hiddenGuard_before_biasHidden sample s hphase hidx)

theorem finalHiddenMac_updates_accumulator (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx + 1 = inputCount) :
    timedStep sample s =
      { s with
          accumulator := acc32 s.accumulator (hiddenMacTermAt s.regs s.hiddenIdx s.inputIdx)
          inputIdx := inputCount } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      have hlast : inputIdx + 1 = inputCount := by
        simpa using hidx
      have hthree : inputIdx = 3 := by
        unfold inputCount at hlast
        omega
      subst inputIdx
      simp [timedStep, step, inputCount]

theorem lastHiddenNeuron_handoff_no_duplicate_or_skip_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .nextHidden) (hidx : s.hiddenIdx + 1 = hiddenCount) :
    timedStep sample s = { s with hiddenIdx := 0, inputIdx := 0, phase := .macOutput } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      have hhiddenStep : hiddenIdx + 1 = hiddenCount := by
        simpa using hidx
      have hseven : hiddenIdx = 7 := by
        unfold hiddenCount at hhiddenStep
        omega
      subst hiddenIdx
      simp [timedStep, step, hiddenCount]

theorem lastHiddenNeuron_to_macOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .nextHidden) (hidx : s.hiddenIdx + 1 = hiddenCount) :
    (timedStep sample s).phase = .macOutput := by
  simpa using congrArg State.phase
    (lastHiddenNeuron_handoff_no_duplicate_or_skip_work sample s hphase hidx)

theorem hiddenBoundary_no_duplicate_or_skip_work (sample₀ sample₁ : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx + 1 = inputCount) :
    timedStep sample₀ s =
      { s with
          accumulator := acc32 s.accumulator (hiddenMacTermAt s.regs s.hiddenIdx s.inputIdx)
          inputIdx := inputCount } ∧
    SameDataFields (timedStep sample₀ s) (timedStep sample₁ (timedStep sample₀ s)) ∧
    (timedStep sample₁ (timedStep sample₀ s)).phase = .biasHidden := by
  have hstep₀ := finalHiddenMac_updates_accumulator sample₀ s hphase hidx
  refine ⟨hstep₀, ?_, ?_⟩
  · have hphase₁ : (timedStep sample₀ s).phase = .macHidden := by
      rw [hstep₀]
      simp [hphase]
    have hidx₁ : (timedStep sample₀ s).inputIdx = inputCount := by
      simp [hstep₀]
    rw [hiddenGuard_before_biasHidden sample₁ (timedStep sample₀ s) hphase₁ hidx₁]
    exact sameDataFields_of_phaseUpdate (timedStep sample₀ s) .biasHidden
  · have hphase₁ : (timedStep sample₀ s).phase = .macHidden := by
      rw [hstep₀]
      simp [hphase]
    have hidx₁ : (timedStep sample₀ s).inputIdx = inputCount := by
      simp [hstep₀]
    rw [hiddenGuard_before_biasHidden sample₁ (timedStep sample₀ s) hphase₁ hidx₁]

theorem outputGuard_before_biasOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    timedStep sample s = { s with phase := .biasOutput } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      have hinput : inputIdx = hiddenCount := by
        simpa using hidx
      subst inputIdx
      simp [timedStep, step, hiddenCount]

theorem outputGuard_no_mac_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    SameDataFields s (timedStep sample s) := by
  rw [outputGuard_before_biasOutput sample s hphase hidx]
  exact sameDataFields_of_phaseUpdate s .biasOutput

theorem outputGuard_no_out_of_range_reads (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    SameDataFields s (timedStep sample s) ∧
      (timedStep sample s).phase = .biasOutput := by
  rw [outputGuard_before_biasOutput sample s hphase hidx]
  exact ⟨sameDataFields_of_phaseUpdate s .biasOutput, by simp⟩

theorem lastOutputMac_to_biasOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    (timedStep sample s).phase = .biasOutput := by
  simpa [hphase, hidx] using congrArg State.phase
    (outputGuard_before_biasOutput sample s hphase hidx)

theorem finalOutputMac_updates_accumulator (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx + 1 = hiddenCount) :
    timedStep sample s =
      { s with
          accumulator := acc32 s.accumulator (outputMacTermAt s.hidden s.inputIdx)
          inputIdx := hiddenCount } := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      have hlast : inputIdx + 1 = hiddenCount := by
        simpa using hidx
      have hseven : inputIdx = 7 := by
        unfold hiddenCount at hlast
        omega
      subst inputIdx
      simp [timedStep, step, hiddenCount]

theorem outputBoundary_no_duplicate_or_skip_work (sample₀ sample₁ : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx + 1 = hiddenCount) :
    timedStep sample₀ s =
      { s with
          accumulator := acc32 s.accumulator (outputMacTermAt s.hidden s.inputIdx)
          inputIdx := hiddenCount } ∧
    SameDataFields (timedStep sample₀ s) (timedStep sample₁ (timedStep sample₀ s)) ∧
    (timedStep sample₁ (timedStep sample₀ s)).phase = .biasOutput := by
  have hstep₀ := finalOutputMac_updates_accumulator sample₀ s hphase hidx
  refine ⟨hstep₀, ?_, ?_⟩
  · have hphase₁ : (timedStep sample₀ s).phase = .macOutput := by
      rw [hstep₀]
      simp [hphase]
    have hidx₁ : (timedStep sample₀ s).inputIdx = hiddenCount := by
      simp [hstep₀]
    rw [outputGuard_before_biasOutput sample₁ (timedStep sample₀ s) hphase₁ hidx₁]
    exact sameDataFields_of_phaseUpdate (timedStep sample₀ s) .biasOutput
  · have hphase₁ : (timedStep sample₀ s).phase = .macOutput := by
      rw [hstep₀]
      simp [hphase]
    have hidx₁ : (timedStep sample₀ s).inputIdx = hiddenCount := by
      simp [hstep₀]
    rw [outputGuard_before_biasOutput sample₁ (timedStep sample₀ s) hphase₁ hidx₁]

theorem biasOutput_registers_result (sample : CtrlSample) (s : State)
    (hphase : s.phase = .biasOutput) :
    timedStep sample s =
      { s with
          accumulator := acc32 s.accumulator bias2Term
          output := (acc32 s.accumulator bias2Term).toInt > 0
          phase := .done } ∧
    ¬ outputValidOf s ∧
    outputValidOf (timedStep sample s) := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simp at hphase
      simp [timedStep, step, outputValidOf, doneOf, acc32, bias2Term]

theorem holdHigh_accepts (input : Input8) :
    acceptedStart (holdHigh 0) (initialState input) := by
  simp [acceptedStart, holdHigh, initialState]

end TinyMLP
