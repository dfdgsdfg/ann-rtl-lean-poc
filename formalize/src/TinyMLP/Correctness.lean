import TinyMLP.Temporal

namespace TinyMLP

def rtlCorrectnessGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).output = mlpFixed input

def rtlTerminationGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).phase = .done

theorem fixedPoint_matchesSpec (input : Input8) :
    mlpFixed input = mlpSpec (toMathInput input) := by
  exact mlpFixed_eq_mlpSpec input

theorem rtl_index_safe (n : Nat) (input : Input8) :
    IndexInvariant (run n (initialState input)) := by
  exact initial_run_preserves_indexInvariant n input

theorem rtl_hidden_controller_legal (n : Nat) (input : Input8) :
    let s := run n (initialState input)
    (s.phase = .macHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx ≤ inputCount) ∧
    (s.phase = .biasHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount) ∧
    (s.phase = .actHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount) ∧
    (s.phase = .nextHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = 0) := by
  dsimp
  let s := run n (initialState input)
  have hs : IndexInvariant s := rtl_index_safe n input
  refine ⟨?_, ?_, ?_, ?_⟩ <;> intro hphase
  · exact indexInvariant_macHidden hs hphase
  · exact indexInvariant_biasHidden hs hphase
  · exact indexInvariant_actHidden hs hphase
  · exact indexInvariant_nextHidden hs hphase

theorem rtlTrace_index_safe (samples : Nat → CtrlSample) (n : Nat) :
    IndexInvariant (rtlTrace samples n) := by
  exact rtlTrace_preserves_indexInvariant samples n

theorem temporal_hidden_controller_legal (samples : Nat → CtrlSample) (n : Nat) :
    let s := rtlTrace samples n
    (s.phase = .macHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx ≤ inputCount) ∧
    (s.phase = .biasHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount) ∧
    (s.phase = .actHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = inputCount) ∧
    (s.phase = .nextHidden → s.hiddenIdx < hiddenCount ∧ s.inputIdx = 0) := by
  dsimp
  let s := rtlTrace samples n
  have hs : IndexInvariant s := rtlTrace_index_safe samples n
  refine ⟨?_, ?_, ?_, ?_⟩ <;> intro hphase
  · exact indexInvariant_macHidden hs hphase
  · exact indexInvariant_biasHidden hs hphase
  · exact indexInvariant_actHidden hs hphase
  · exact indexInvariant_nextHidden hs hphase

theorem rtl_terminates_goal (input : Input8) : rtlTerminationGoal input :=
  rtl_terminates input

theorem rtl_correctness_goal (input : Input8) : rtlCorrectnessGoal input :=
  rtl_correct input

theorem temporal_acceptedStart_eventually_done (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) idleState) :
    doneOf (rtlTrace samples totalCycles) :=
  acceptedStart_eventually_done samples haccept

theorem temporal_busy_during_active_window (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) idleState)
    (k : Fin totalCycles) (hpos : 0 < k.1) :
    busyOf (rtlTrace samples k.1) :=
  busy_during_active_window samples haccept k hpos

theorem temporal_acceptedStart_capturedInput_correct (samples : Nat → CtrlSample)
    (haccept : acceptedStart (samples 0) idleState) :
    (rtlTrace samples totalCycles).output = mlpFixed (capturedInput samples) :=
  acceptedStart_capturedInput_correct samples haccept

theorem temporal_done_implies_outputValid (s : State) :
    doneOf s → outputValidOf s :=
  done_implies_outputValid s

theorem temporal_output_stable_while_done (samples : Nat → CtrlSample) (t : Nat) :
    stableOutputOn t (rtlTrace samples) :=
  output_stable_while_done samples t

theorem temporal_done_hold_while_start_high (sample : CtrlSample) (s : State)
    (hdone : doneOf s) (hstart : sample.start = true) :
    timedStep sample s = s :=
  done_hold_while_start_high sample s hdone hstart

theorem temporal_done_to_idle_when_start_low (sample : CtrlSample) (s : State)
    (hdone : doneOf s) (hstart : sample.start = false) :
    timedStep sample s = { s with phase := .idle } :=
  done_to_idle_when_start_low sample s hdone hstart

theorem temporal_idle_wait_cleans_controller_indices (sample : CtrlSample) (s : State)
    (hidle : s.phase = .idle) (hstart : sample.start = false) :
    timedStep sample s = { s with hiddenIdx := 0, inputIdx := 0 } :=
  idle_wait_cleans_controller_indices sample s hidle hstart

theorem temporal_phase_ordering_ok (sample : CtrlSample) (s : State) :
    AllowedPhaseTransition s.phase (timedStep sample s).phase :=
  phase_ordering_ok sample s

theorem temporal_hiddenGuard_before_biasHidden (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    timedStep sample s = { s with phase := .biasHidden } :=
  hiddenGuard_before_biasHidden sample s hphase hidx

theorem temporal_hiddenGuard_no_mac_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    SameDataFields s (timedStep sample s) :=
  hiddenGuard_no_mac_work sample s hphase hidx

theorem temporal_hiddenGuard_no_out_of_range_reads (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    SameDataFields s (timedStep sample s) ∧
      (timedStep sample s).phase = .biasHidden :=
  hiddenGuard_no_out_of_range_reads sample s hphase hidx

theorem temporal_lastHiddenMac_to_biasHidden (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx = inputCount) :
    (timedStep sample s).phase = .biasHidden :=
  lastHiddenMac_to_biasHidden sample s hphase hidx

theorem temporal_lastHiddenNeuron_handoff_no_duplicate_or_skip_work
    (sample : CtrlSample) (s : State)
    (hphase : s.phase = .nextHidden) (hidx : s.hiddenIdx + 1 = hiddenCount) :
    timedStep sample s = { s with hiddenIdx := 0, inputIdx := 0, phase := .macOutput } :=
  lastHiddenNeuron_handoff_no_duplicate_or_skip_work sample s hphase hidx

theorem temporal_lastHiddenNeuron_to_macOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .nextHidden) (hidx : s.hiddenIdx + 1 = hiddenCount) :
    (timedStep sample s).phase = .macOutput :=
  lastHiddenNeuron_to_macOutput sample s hphase hidx

theorem temporal_hiddenBoundary_no_duplicate_or_skip_work (sample₀ sample₁ : CtrlSample) (s : State)
    (hphase : s.phase = .macHidden) (hidx : s.inputIdx + 1 = inputCount) :
    timedStep sample₀ s =
      { s with
          accumulator := acc32 s.accumulator (hiddenMacTermAt s.regs s.hiddenIdx s.inputIdx)
          inputIdx := inputCount } ∧
    SameDataFields (timedStep sample₀ s) (timedStep sample₁ (timedStep sample₀ s)) ∧
    (timedStep sample₁ (timedStep sample₀ s)).phase = .biasHidden :=
  hiddenBoundary_no_duplicate_or_skip_work sample₀ sample₁ s hphase hidx

theorem temporal_outputGuard_before_biasOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    timedStep sample s = { s with phase := .biasOutput } :=
  outputGuard_before_biasOutput sample s hphase hidx

theorem temporal_outputGuard_no_mac_work (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    SameDataFields s (timedStep sample s) :=
  outputGuard_no_mac_work sample s hphase hidx

theorem temporal_outputGuard_no_out_of_range_reads (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    SameDataFields s (timedStep sample s) ∧
      (timedStep sample s).phase = .biasOutput :=
  outputGuard_no_out_of_range_reads sample s hphase hidx

theorem temporal_lastOutputMac_to_biasOutput (sample : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx = hiddenCount) :
    (timedStep sample s).phase = .biasOutput :=
  lastOutputMac_to_biasOutput sample s hphase hidx

theorem temporal_outputBoundary_no_duplicate_or_skip_work (sample₀ sample₁ : CtrlSample) (s : State)
    (hphase : s.phase = .macOutput) (hidx : s.inputIdx + 1 = hiddenCount) :
    timedStep sample₀ s =
      { s with
          accumulator := acc32 s.accumulator (outputMacTermAt s.hidden s.inputIdx)
          inputIdx := hiddenCount } ∧
    SameDataFields (timedStep sample₀ s) (timedStep sample₁ (timedStep sample₀ s)) ∧
    (timedStep sample₁ (timedStep sample₀ s)).phase = .biasOutput :=
  outputBoundary_no_duplicate_or_skip_work sample₀ sample₁ s hphase hidx

theorem temporal_biasOutput_registers_result (sample : CtrlSample) (s : State)
    (hphase : s.phase = .biasOutput) :
    timedStep sample s =
      { s with
          accumulator := acc32 s.accumulator bias2Term
          output := (acc32 s.accumulator bias2Term).toInt > 0
          phase := .done } ∧
    ¬ outputValidOf s ∧
    outputValidOf (timedStep sample s) :=
  biasOutput_registers_result sample s hphase

end TinyMLP
