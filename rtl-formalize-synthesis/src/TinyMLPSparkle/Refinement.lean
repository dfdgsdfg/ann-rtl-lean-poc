import TinyMLP.Invariants
import TinyMLP.Temporal
import TinyMLPSparkle.ControllerSignal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

abbrev inputCount4b : BitVec stateWidth := BitVec.ofNat stateWidth inputCount
abbrev hiddenCount4b : BitVec stateWidth := BitVec.ofNat stateWidth hiddenCount
abbrev lastHiddenIdx4b : BitVec stateWidth := BitVec.ofNat stateWidth (hiddenCount - 1)

attribute [simp] stIdle stLoadInput stMacHidden stBiasHidden stActHidden
  stNextHidden stMacOutput stBiasOutput stDone

structure ControllerOutputs where
  state : BitVec stateWidth
  load_input : Bool
  clear_acc : Bool
  do_mac_hidden : Bool
  do_bias_hidden : Bool
  do_act_hidden : Bool
  advance_hidden : Bool
  do_mac_output : Bool
  do_bias_output : Bool
  done : Bool
  busy : Bool
deriving Repr, DecidableEq

def ControllerView.sample {dom : DomainConfig} (view : ControllerView dom) (t : Nat) : ControllerOutputs :=
  { state := view.state.atTime t
  , load_input := view.load_input.atTime t
  , clear_acc := view.clear_acc.atTime t
  , do_mac_hidden := view.do_mac_hidden.atTime t
  , do_bias_hidden := view.do_bias_hidden.atTime t
  , do_act_hidden := view.do_act_hidden.atTime t
  , advance_hidden := view.advance_hidden.atTime t
  , do_mac_output := view.do_mac_output.atTime t
  , do_bias_output := view.do_bias_output.atTime t
  , done := view.done.atTime t
  , busy := view.busy.atTime t
  }

def encodePhase : Phase → BitVec stateWidth
  | .idle => stIdle
  | .loadInput => stLoadInput
  | .macHidden => stMacHidden
  | .biasHidden => stBiasHidden
  | .actHidden => stActHidden
  | .nextHidden => stNextHidden
  | .macOutput => stMacOutput
  | .biasOutput => stBiasOutput
  | .done => stDone

def ControlInvariant (cs : ControlState) : Prop :=
  match cs.phase with
  | .idle => cs.hiddenIdx ≤ hiddenCount ∧ cs.inputIdx ≤ hiddenCount
  | .loadInput => cs.hiddenIdx ≤ hiddenCount ∧ cs.inputIdx ≤ hiddenCount
  | .macHidden => cs.hiddenIdx < hiddenCount ∧ cs.inputIdx ≤ inputCount
  | .biasHidden => cs.hiddenIdx < hiddenCount ∧ cs.inputIdx = inputCount
  | .actHidden => cs.hiddenIdx < hiddenCount ∧ cs.inputIdx = inputCount
  | .nextHidden => cs.hiddenIdx < hiddenCount ∧ cs.inputIdx = 0
  | .macOutput => cs.hiddenIdx = 0 ∧ cs.inputIdx ≤ hiddenCount
  | .biasOutput => cs.hiddenIdx = 0 ∧ cs.inputIdx = hiddenCount
  | .done => cs.hiddenIdx = 0 ∧ cs.inputIdx = hiddenCount

def controlOutputsOf (cs : ControlState) : ControllerOutputs :=
  { state := encodePhase cs.phase
  , load_input := decide (cs.phase = .loadInput)
  , clear_acc := decide (cs.phase = .loadInput)
  , do_mac_hidden := decide (cs.phase = .macHidden ∧ cs.inputIdx < inputCount)
  , do_bias_hidden := decide (cs.phase = .biasHidden)
  , do_act_hidden := decide (cs.phase = .actHidden)
  , advance_hidden := decide (cs.phase = .nextHidden)
  , do_mac_output := decide (cs.phase = .macOutput ∧ cs.inputIdx < hiddenCount)
  , do_bias_output := decide (cs.phase = .biasOutput)
  , done := decide (cs.phase = .done)
  , busy := decide (cs.phase ≠ .idle ∧ cs.phase ≠ .done)
  }

def startSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom Bool :=
  ⟨fun t => (samples t).start⟩

def hiddenIdxSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => BitVec.ofNat stateWidth (timedControlTrace samples t).hiddenIdx⟩

def inputIdxSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => BitVec.ofNat stateWidth (timedControlTrace samples t).inputIdx⟩

def phaseSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => encodePhase (timedControlTrace samples t).phase⟩

def canonicalControllerView {dom : DomainConfig} (samples : Nat → CtrlSample) : ControllerView dom :=
  controllerViewOfState
    (phaseSignal samples)
    (inputIdxSignal samples)
    (Signal.pure inputCount4b)
    (Signal.pure hiddenCount4b)

private theorem controlInvariant_of_controlOf {s : State} (hs : IndexInvariant s) :
    ControlInvariant (controlOf s) := by
  cases s with
  | mk regs hidden accumulator hiddenIdx inputIdx phase output =>
      cases phase <;> simpa [ControlInvariant, controlOf, IndexInvariant] using hs

private theorem timedControlTrace_preserves_controlInvariant (samples : Nat → CtrlSample) (n : Nat) :
    ControlInvariant (timedControlTrace samples n) := by
  have hs : IndexInvariant (rtlTrace samples n) := rtlTrace_preserves_indexInvariant samples n
  have hcontrol : controlOf (rtlTrace samples n) = timedControlTrace samples n := controlOf_rtlTrace samples n
  simpa [hcontrol] using controlInvariant_of_controlOf hs

private theorem controlInvariant_macHidden {cs : ControlState}
    (hs : ControlInvariant cs) (hphase : cs.phase = .macHidden) :
    cs.hiddenIdx < hiddenCount ∧ cs.inputIdx ≤ inputCount := by
  simpa [ControlInvariant, hphase] using hs

private theorem controlInvariant_nextHidden {cs : ControlState}
    (hs : ControlInvariant cs) (hphase : cs.phase = .nextHidden) :
    cs.hiddenIdx < hiddenCount ∧ cs.inputIdx = 0 := by
  simpa [ControlInvariant, hphase] using hs

private theorem controlInvariant_macOutput {cs : ControlState}
    (hs : ControlInvariant cs) (hphase : cs.phase = .macOutput) :
    cs.hiddenIdx = 0 ∧ cs.inputIdx ≤ hiddenCount := by
  simpa [ControlInvariant, hphase] using hs

private theorem inputIdx_lt_modulus {cs : ControlState} (hs : ControlInvariant cs) :
    cs.inputIdx < 2 ^ stateWidth := by
  cases hphase : cs.phase <;> simp [ControlInvariant, hphase, inputCount, hiddenCount, stateWidth] at hs ⊢ <;> omega

private theorem hiddenIdx_lt_modulus {cs : ControlState} (hs : ControlInvariant cs) :
    cs.hiddenIdx < 2 ^ stateWidth := by
  cases hphase : cs.phase <;> simp [ControlInvariant, hphase, inputCount, hiddenCount, stateWidth] at hs ⊢ <;> omega

private theorem bitvec4_eq_ofNat_iff {x y : Nat} (hx : x < 2 ^ stateWidth) (hy : y < 2 ^ stateWidth) :
    BitVec.ofNat stateWidth x = BitVec.ofNat stateWidth y ↔ x = y := by
  constructor
  · intro hEq
    have hToNat := congrArg BitVec.toNat hEq
    simpa [BitVec.toNat_ofNat, Nat.mod_eq_of_lt hx, Nat.mod_eq_of_lt hy] using hToNat
  · intro hEq
    simp [hEq]

private theorem bitvec4_beq_true_iff {x y : Nat} (hx : x < 2 ^ stateWidth) (hy : y < 2 ^ stateWidth) :
    ((BitVec.ofNat stateWidth x) == (BitVec.ofNat stateWidth y)) = true ↔ x = y := by
  rw [beq_iff_eq, bitvec4_eq_ofNat_iff hx hy]

private theorem bitvec4_ult_true_iff {x y : Nat} (hx : x < 2 ^ stateWidth) (hy : y < 2 ^ stateWidth) :
    BitVec.ult (BitVec.ofNat stateWidth x) (BitVec.ofNat stateWidth y) = true ↔ x < y := by
  simp [BitVec.ult, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hx, Nat.mod_eq_of_lt hy]

private theorem inputIdx_eq_inputCount_beq {cs : ControlState} (hs : ControlInvariant cs) :
    ((BitVec.ofNat stateWidth cs.inputIdx) == inputCount4b) = decide (cs.inputIdx = inputCount) := by
  have hx := inputIdx_lt_modulus hs
  have hy : inputCount < 2 ^ stateWidth := by decide
  by_cases hEq : cs.inputIdx = inputCount
  · simp [inputCount4b, hEq]
  · have hFalse : ((BitVec.ofNat stateWidth cs.inputIdx) == inputCount4b) = false := by
      cases hBeq : ((BitVec.ofNat stateWidth cs.inputIdx) == inputCount4b) with
      | false => rfl
      | true => exact False.elim (hEq ((bitvec4_beq_true_iff hx hy).1 hBeq))
    simp [hEq, hFalse]

private theorem hiddenIdx_eq_lastHiddenIdx_beq {cs : ControlState} (hs : ControlInvariant cs) :
    ((BitVec.ofNat stateWidth cs.hiddenIdx) == lastHiddenIdx4b) = decide (cs.hiddenIdx = hiddenCount - 1) := by
  have hx := hiddenIdx_lt_modulus hs
  have hy : hiddenCount - 1 < 2 ^ stateWidth := by decide
  by_cases hEq : cs.hiddenIdx = hiddenCount - 1
  · simp [lastHiddenIdx4b, hEq]
  · have hFalse : ((BitVec.ofNat stateWidth cs.hiddenIdx) == lastHiddenIdx4b) = false := by
      cases hBeq : ((BitVec.ofNat stateWidth cs.hiddenIdx) == lastHiddenIdx4b) with
      | false => rfl
      | true => exact False.elim (hEq ((bitvec4_beq_true_iff hx hy).1 hBeq))
    simp [hEq, hFalse]

private theorem inputIdx_lt_inputCount_bool {cs : ControlState} (hs : ControlInvariant cs) :
    BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) inputCount4b = decide (cs.inputIdx < inputCount) := by
  have hx := inputIdx_lt_modulus hs
  have hy : inputCount < 2 ^ stateWidth := by decide
  by_cases hLt : cs.inputIdx < inputCount
  · simpa [hLt] using (bitvec4_ult_true_iff hx hy).2 hLt
  · have hFalse : BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) inputCount4b = false := by
      cases hUlt : BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) inputCount4b with
      | false => rfl
      | true => exact False.elim (hLt ((bitvec4_ult_true_iff hx hy).1 hUlt))
    simp [hLt, hFalse]

private theorem inputIdx_lt_hiddenCount_bool {cs : ControlState} (hs : ControlInvariant cs) :
    BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) hiddenCount4b = decide (cs.inputIdx < hiddenCount) := by
  have hx := inputIdx_lt_modulus hs
  have hy : hiddenCount < 2 ^ stateWidth := by decide
  by_cases hLt : cs.inputIdx < hiddenCount
  · simpa [hLt] using (bitvec4_ult_true_iff hx hy).2 hLt
  · have hFalse : BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) hiddenCount4b = false := by
      cases hUlt : BitVec.ult (BitVec.ofNat stateWidth cs.inputIdx) hiddenCount4b with
      | false => rfl
      | true => exact False.elim (hLt ((bitvec4_ult_true_iff hx hy).1 hUlt))
    simp [hLt, hFalse]

private theorem inputIdx_eq_hiddenCount_beq {cs : ControlState} (hs : ControlInvariant cs) :
    ((BitVec.ofNat stateWidth cs.inputIdx) == hiddenCount4b) = decide (cs.inputIdx = hiddenCount) := by
  have hx := inputIdx_lt_modulus hs
  have hy : hiddenCount < 2 ^ stateWidth := by decide
  by_cases hEq : cs.inputIdx = hiddenCount
  · simp [hiddenCount4b, hEq]
  · have hFalse : ((BitVec.ofNat stateWidth cs.inputIdx) == hiddenCount4b) = false := by
      cases hBeq : ((BitVec.ofNat stateWidth cs.inputIdx) == hiddenCount4b) with
      | false => rfl
      | true => exact False.elim (hEq ((bitvec4_beq_true_iff hx hy).1 hBeq))
    simp [hEq, hFalse]

theorem controllerPhaseNextComb_refines_timedControlStep (sample : CtrlSample) (cs : ControlState)
    (hs : ControlInvariant cs) :
    controllerPhaseNextComb
        sample.start
        (BitVec.ofNat stateWidth cs.hiddenIdx)
        (BitVec.ofNat stateWidth cs.inputIdx)
        inputCount4b
        hiddenCount4b
        lastHiddenIdx4b
        (encodePhase cs.phase)
      = encodePhase (timedControlStep sample cs).phase := by
  cases hphase : cs.phase with
  | idle =>
      cases hstart : sample.start <;>
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hstart]
  | loadInput =>
      simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase]
  | macHidden =>
      by_cases hLt : cs.inputIdx < inputCount
      · have hGuard : ((BitVec.ofNat stateWidth cs.inputIdx) == inputCount4b) = false := by
          rw [inputIdx_eq_inputCount_beq hs]
          simp [Nat.ne_of_lt hLt]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hLt, hGuard]
      · have hEq : cs.inputIdx = inputCount := by
          have hInv := controlInvariant_macHidden hs hphase
          omega
        have hGuard : ((BitVec.ofNat stateWidth cs.inputIdx) == inputCount4b) = true := by
          rw [inputIdx_eq_inputCount_beq hs]
          simp [hEq]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hEq]
  | biasHidden =>
      simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase]
  | actHidden =>
      simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase]
  | nextHidden =>
      by_cases hLastStep : cs.hiddenIdx + 1 < hiddenCount
      · have hLastEq : cs.hiddenIdx ≠ hiddenCount - 1 := by omega
        have hGuard : ((BitVec.ofNat stateWidth cs.hiddenIdx) == lastHiddenIdx4b) = false := by
          rw [hiddenIdx_eq_lastHiddenIdx_beq hs]
          simp [hLastEq]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hLastStep, hGuard]
      · have hEq : cs.hiddenIdx = hiddenCount - 1 := by
          have hInv := controlInvariant_nextHidden hs hphase
          omega
        have hGuard : ((BitVec.ofNat stateWidth cs.hiddenIdx) == lastHiddenIdx4b) = true := by
          rw [hiddenIdx_eq_lastHiddenIdx_beq hs]
          simp [hEq]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hEq, hiddenCount, lastHiddenIdx4b]
  | macOutput =>
      by_cases hLt : cs.inputIdx < hiddenCount
      · have hGuard : ((BitVec.ofNat stateWidth cs.inputIdx) == hiddenCount4b) = false := by
          rw [inputIdx_eq_hiddenCount_beq hs]
          simp [Nat.ne_of_lt hLt]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hLt, hGuard]
      · have hEq : cs.inputIdx = hiddenCount := by
          have hInv := controlInvariant_macOutput hs hphase
          omega
        have hGuard : ((BitVec.ofNat stateWidth cs.inputIdx) == hiddenCount4b) = true := by
          rw [inputIdx_eq_hiddenCount_beq hs]
          simp [hEq]
        simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase, hEq]
  | biasOutput =>
      simp [controllerPhaseNextComb, timedControlStep, controlStep, encodePhase, hphase]
  | done =>
      cases hstart : sample.start <;>
        simp [controllerPhaseNextComb, timedControlStep, encodePhase, hphase, hstart]

private theorem controllerPhaseNext_atTime {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec stateWidth))
    (input_idx : Signal dom (BitVec stateWidth))
    (inputNeurons4b : Signal dom (BitVec stateWidth))
    (hiddenNeurons4b : Signal dom (BitVec stateWidth))
    (lastHiddenIdx : Signal dom (BitVec stateWidth))
    (state : Signal dom (BitVec stateWidth))
    (t : Nat) :
    (controllerPhaseNext start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx state).atTime t =
      controllerPhaseNextComb
        (start.atTime t)
        (hidden_idx.atTime t)
        (input_idx.atTime t)
        (inputNeurons4b.atTime t)
        (hiddenNeurons4b.atTime t)
        (lastHiddenIdx.atTime t)
        (state.atTime t) := by
  have hAnd (a b : Signal dom Bool) :
      (a &&& b).val t = (a.val t && b.val t) := by rfl
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hNot (a : Signal dom Bool) :
      ((fun value => !value) <$> a).val t = !a.val t := by rfl
  simp [controllerPhaseNext, Signal.atTime, Signal.mux, Signal.pure, hAnd, hEq, hNot]
  by_cases hIdle : state.val t = stIdle
  · simp [controllerPhaseNextComb, hIdle]
  · by_cases hLoad : state.val t = stLoadInput
    · simp [controllerPhaseNextComb, hLoad]
    · by_cases hMacHidden : state.val t = stMacHidden
      · by_cases hInput : input_idx.val t = inputNeurons4b.val t
        · simp [controllerPhaseNextComb, hMacHidden, hInput]
        · simp [controllerPhaseNextComb, hMacHidden, hInput]
      · by_cases hBiasHidden : state.val t = stBiasHidden
        · simp [controllerPhaseNextComb, hBiasHidden]
        · by_cases hActHidden : state.val t = stActHidden
          · simp [controllerPhaseNextComb, hActHidden]
          · by_cases hNextHidden : state.val t = stNextHidden
            · by_cases hLast : hidden_idx.val t = lastHiddenIdx.val t
              · simp [controllerPhaseNextComb, hNextHidden, hLast]
              · simp [controllerPhaseNextComb, hNextHidden, hLast]
            · by_cases hMacOutput : state.val t = stMacOutput
              · by_cases hOutput : input_idx.val t = hiddenNeurons4b.val t
                · simp [controllerPhaseNextComb, hMacOutput, hOutput]
                · simp [controllerPhaseNextComb, hMacOutput, hOutput]
              · by_cases hBiasOutput : state.val t = stBiasOutput
                · simp [controllerPhaseNextComb, hBiasOutput]
                · by_cases hDone : state.val t = stDone
                  · by_cases hStart : start.val t = true
                    · simp [controllerPhaseNextComb, hDone, hStart]
                    · simp [controllerPhaseNextComb, hDone, hStart]
                  · simp [controllerPhaseNextComb, hIdle, hLoad, hMacHidden, hBiasHidden, hActHidden, hNextHidden, hMacOutput, hBiasOutput, hDone]

theorem phaseSignal_satisfies_controller_equation_at {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (phaseSignal (dom := dom) samples).atTime t =
      (Signal.register stIdle
        (controllerPhaseNext
          (startSignal (dom := dom) samples)
          (hiddenIdxSignal (dom := dom) samples)
          (inputIdxSignal (dom := dom) samples)
          (Signal.pure inputCount4b)
          (Signal.pure hiddenCount4b)
          (Signal.pure lastHiddenIdx4b)
          (phaseSignal (dom := dom) samples))).atTime t := by
  cases t with
  | zero =>
      simp [phaseSignal, Signal.register, Signal.atTime, timedControlTrace, encodePhase, initialControl]
  | succ n =>
      have hs : ControlInvariant (timedControlTrace samples n) := timedControlTrace_preserves_controlInvariant samples n
      simp [Signal.register, phaseSignal, Signal.atTime]
      change encodePhase (timedControlTrace samples (n + 1)).phase =
        (controllerPhaseNext
          (startSignal (dom := dom) samples)
          (hiddenIdxSignal (dom := dom) samples)
          (inputIdxSignal (dom := dom) samples)
          (Signal.pure inputCount4b)
          (Signal.pure hiddenCount4b)
          (Signal.pure lastHiddenIdx4b)
          (phaseSignal (dom := dom) samples)).atTime n
      rw [controllerPhaseNext_atTime]
      simpa [phaseSignal, startSignal, hiddenIdxSignal, inputIdxSignal]
        using (controllerPhaseNextComb_refines_timedControlStep (samples n) (timedControlTrace samples n) hs).symm

private def controllerOutputsAt
    (state : BitVec stateWidth)
    (input_idx : BitVec stateWidth)
    (inputNeurons4b : BitVec stateWidth)
    (hiddenNeurons4b : BitVec stateWidth) : ControllerOutputs :=
  { state := state
  , load_input := loadInputComb state
  , clear_acc := clearAccComb state
  , do_mac_hidden := doMacHiddenComb state input_idx inputNeurons4b
  , do_bias_hidden := doBiasHiddenComb state
  , do_act_hidden := doActHiddenComb state
  , advance_hidden := advanceHiddenComb state
  , do_mac_output := doMacOutputComb state input_idx hiddenNeurons4b
  , do_bias_output := doBiasOutputComb state
  , done := doneComb state
  , busy := busyComb state
  }

private theorem controllerViewOfState_sample {dom : DomainConfig}
    (state : Signal dom (BitVec stateWidth))
    (input_idx : Signal dom (BitVec stateWidth))
    (inputNeurons4b : Signal dom (BitVec stateWidth))
    (hiddenNeurons4b : Signal dom (BitVec stateWidth))
    (t : Nat) :
    (controllerViewOfState state input_idx inputNeurons4b hiddenNeurons4b).sample t =
      controllerOutputsAt
        (state.atTime t)
        (input_idx.atTime t)
        (inputNeurons4b.atTime t)
        (hiddenNeurons4b.atTime t) := by
  have hAnd (a b : Signal dom Bool) :
      (a &&& b).val t = (a.val t && b.val t) := by rfl
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hNot (a : Signal dom Bool) :
      ((fun value => !value) <$> a).val t = !a.val t := by rfl
  have hUlt (a b : Signal dom (BitVec stateWidth)) :
      (((BitVec.ult · ·) <$> a <*> b).val t) = BitVec.ult (a.val t) (b.val t) := by rfl
  have hNe (x y : BitVec stateWidth) : (!(x == y)) = (x != y) := by rfl
  simp [controllerViewOfState, ControllerView.sample, controllerOutputsAt, loadInputComb,
    clearAccComb, doMacHiddenComb, doBiasHiddenComb, doActHiddenComb, advanceHiddenComb,
    doMacOutputComb, doBiasOutputComb, doneComb, busyComb, Signal.atTime, Signal.pure,
    hAnd, hEq, hNot, hUlt, hNe]

private theorem controllerOutputsAt_refines_controlOutputs (cs : ControlState) (hs : ControlInvariant cs) :
    controllerOutputsAt
        (encodePhase cs.phase)
        (BitVec.ofNat stateWidth cs.inputIdx)
        inputCount4b
        hiddenCount4b
      = controlOutputsOf cs := by
  cases hphase : cs.phase <;>
    simp [controllerOutputsAt, controlOutputsOf, encodePhase, loadInputComb, clearAccComb,
      doMacHiddenComb, doBiasHiddenComb, doActHiddenComb, advanceHiddenComb,
      doMacOutputComb, doBiasOutputComb, doneComb, busyComb, hphase,
      inputIdx_lt_inputCount_bool hs, inputIdx_lt_hiddenCount_bool hs]

theorem canonicalControllerView_refines_timedControlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (canonicalControllerView (dom := dom) samples).sample t = controlOutputsOf (timedControlTrace samples t) := by
  have hs : ControlInvariant (timedControlTrace samples t) := timedControlTrace_preserves_controlInvariant samples t
  calc
    (canonicalControllerView (dom := dom) samples).sample t =
        controllerOutputsAt
          ((phaseSignal (dom := dom) samples).atTime t)
          ((inputIdxSignal (dom := dom) samples).atTime t)
          inputCount4b
          hiddenCount4b := by
            simpa [canonicalControllerView] using
              controllerViewOfState_sample
                (phaseSignal (dom := dom) samples)
                (inputIdxSignal (dom := dom) samples)
                (Signal.pure inputCount4b)
                (Signal.pure hiddenCount4b)
                t
    _ = controlOutputsOf (timedControlTrace samples t) := by
      simpa [phaseSignal, inputIdxSignal] using
        controllerOutputsAt_refines_controlOutputs (timedControlTrace samples t) hs

end TinyMLP.Sparkle
