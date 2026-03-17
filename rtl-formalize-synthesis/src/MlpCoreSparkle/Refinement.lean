import MlpCore.Defs.TemporalCore
import MlpCoreSparkle.ProofConfig
import MlpCoreSparkle.ControllerSignal
import MlpCoreSparkle.MlpCoreSignal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace MlpCore.Sparkle

open MlpCoreSparkle.ProofConfig

local instance : ArithmeticProofProvider := selectedArithmeticProofProvider

set_option maxRecDepth 65536
set_option maxHeartbeats 64000000

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

structure MlpCoreOutputs where
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
  out_bit : Bool
  hidden_idx : BitVec stateWidth
  input_idx : BitVec stateWidth
  acc_reg : BitVec 32
  mac_acc_out : BitVec 32
  mac_a : BitVec 16
  b2_data : BitVec 32
  input_reg0 : BitVec 8
  input_reg1 : BitVec 8
  input_reg2 : BitVec 8
  input_reg3 : BitVec 8
  hidden_reg0 : BitVec 16
  hidden_reg1 : BitVec 16
  hidden_reg2 : BitVec 16
  hidden_reg3 : BitVec 16
  hidden_reg4 : BitVec 16
  hidden_reg5 : BitVec 16
  hidden_reg6 : BitVec 16
  hidden_reg7 : BitVec 16
  hidden_input_case_hit : Bool
  output_hidden_case_hit : Bool
  hidden_weight_case_hit : Bool
  output_weight_case_hit : Bool
deriving Repr, DecidableEq

def MlpCoreView.sample {dom : DomainConfig} (view : MlpCoreView dom) (t : Nat) : MlpCoreOutputs :=
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
  , out_bit := view.out_bit.atTime t
  , hidden_idx := view.hidden_idx.atTime t
  , input_idx := view.input_idx.atTime t
  , acc_reg := view.acc_reg.atTime t
  , mac_acc_out := view.mac_acc_out.atTime t
  , mac_a := view.mac_a.atTime t
  , b2_data := view.b2_data.atTime t
  , input_reg0 := view.input_reg0.atTime t
  , input_reg1 := view.input_reg1.atTime t
  , input_reg2 := view.input_reg2.atTime t
  , input_reg3 := view.input_reg3.atTime t
  , hidden_reg0 := view.hidden_reg0.atTime t
  , hidden_reg1 := view.hidden_reg1.atTime t
  , hidden_reg2 := view.hidden_reg2.atTime t
  , hidden_reg3 := view.hidden_reg3.atTime t
  , hidden_reg4 := view.hidden_reg4.atTime t
  , hidden_reg5 := view.hidden_reg5.atTime t
  , hidden_reg6 := view.hidden_reg6.atTime t
  , hidden_reg7 := view.hidden_reg7.atTime t
  , hidden_input_case_hit := view.hidden_input_case_hit.atTime t
  , output_hidden_case_hit := view.output_hidden_case_hit.atTime t
  , hidden_weight_case_hit := view.hidden_weight_case_hit.atTime t
  , output_weight_case_hit := view.output_weight_case_hit.atTime t
  }

def packMlpCoreOutputsBundle (outputs : MlpCoreOutputs) :=
  let packed : Signal defaultDomain _ :=
    bundleAll! [
      Signal.pure outputs.state,
      Signal.pure outputs.load_input,
      Signal.pure outputs.clear_acc,
      Signal.pure outputs.do_mac_hidden,
      Signal.pure outputs.do_bias_hidden,
      Signal.pure outputs.do_act_hidden,
      Signal.pure outputs.advance_hidden,
      Signal.pure outputs.do_mac_output,
      Signal.pure outputs.do_bias_output,
      Signal.pure outputs.done,
      Signal.pure outputs.busy,
      Signal.pure outputs.out_bit,
      Signal.pure outputs.hidden_idx,
      Signal.pure outputs.input_idx,
      Signal.pure outputs.acc_reg,
      Signal.pure outputs.mac_acc_out,
      Signal.pure outputs.mac_a,
      Signal.pure outputs.b2_data,
      Signal.pure outputs.input_reg0,
      Signal.pure outputs.input_reg1,
      Signal.pure outputs.input_reg2,
      Signal.pure outputs.input_reg3,
      Signal.pure outputs.hidden_reg0,
      Signal.pure outputs.hidden_reg1,
      Signal.pure outputs.hidden_reg2,
      Signal.pure outputs.hidden_reg3,
      Signal.pure outputs.hidden_reg4,
      Signal.pure outputs.hidden_reg5,
      Signal.pure outputs.hidden_reg6,
      Signal.pure outputs.hidden_reg7,
      Signal.pure outputs.hidden_input_case_hit,
      Signal.pure outputs.output_hidden_case_hit,
      Signal.pure outputs.hidden_weight_case_hit,
      Signal.pure outputs.output_weight_case_hit
    ]
  packed.atTime 0

def packMlpCoreOutputsBits (outputs : MlpCoreOutputs) : BitVec mlpCorePackedWidth :=
  packMlpCorePackedBits (packMlpCoreOutputsBundle outputs)

theorem packMlpCoreView_sample_bundle {dom : DomainConfig} (view : MlpCoreView dom) (t : Nat) :
    (packMlpCoreView view).atTime t = packMlpCoreOutputsBundle (view.sample t) := by
  cases view
  rfl

private theorem mlpCoreOutputs_ext
    {a b : MlpCoreOutputs}
    (hState : a.state = b.state)
    (hLoadInput : a.load_input = b.load_input)
    (hClearAcc : a.clear_acc = b.clear_acc)
    (hDoMacHidden : a.do_mac_hidden = b.do_mac_hidden)
    (hDoBiasHidden : a.do_bias_hidden = b.do_bias_hidden)
    (hDoActHidden : a.do_act_hidden = b.do_act_hidden)
    (hAdvanceHidden : a.advance_hidden = b.advance_hidden)
    (hDoMacOutput : a.do_mac_output = b.do_mac_output)
    (hDoBiasOutput : a.do_bias_output = b.do_bias_output)
    (hDone : a.done = b.done)
    (hBusy : a.busy = b.busy)
    (hOutBit : a.out_bit = b.out_bit)
    (hHiddenIdx : a.hidden_idx = b.hidden_idx)
    (hInputIdx : a.input_idx = b.input_idx)
    (hAccReg : a.acc_reg = b.acc_reg)
    (hMacAccOut : a.mac_acc_out = b.mac_acc_out)
    (hMacA : a.mac_a = b.mac_a)
    (hB2Data : a.b2_data = b.b2_data)
    (hInputReg0 : a.input_reg0 = b.input_reg0)
    (hInputReg1 : a.input_reg1 = b.input_reg1)
    (hInputReg2 : a.input_reg2 = b.input_reg2)
    (hInputReg3 : a.input_reg3 = b.input_reg3)
    (hHiddenReg0 : a.hidden_reg0 = b.hidden_reg0)
    (hHiddenReg1 : a.hidden_reg1 = b.hidden_reg1)
    (hHiddenReg2 : a.hidden_reg2 = b.hidden_reg2)
    (hHiddenReg3 : a.hidden_reg3 = b.hidden_reg3)
    (hHiddenReg4 : a.hidden_reg4 = b.hidden_reg4)
    (hHiddenReg5 : a.hidden_reg5 = b.hidden_reg5)
    (hHiddenReg6 : a.hidden_reg6 = b.hidden_reg6)
    (hHiddenReg7 : a.hidden_reg7 = b.hidden_reg7)
    (hHiddenInputCaseHit : a.hidden_input_case_hit = b.hidden_input_case_hit)
    (hOutputHiddenCaseHit : a.output_hidden_case_hit = b.output_hidden_case_hit)
    (hHiddenWeightCaseHit : a.hidden_weight_case_hit = b.hidden_weight_case_hit)
    (hOutputWeightCaseHit : a.output_weight_case_hit = b.output_weight_case_hit) :
    a = b := by
  cases a
  cases b
  cases hState
  cases hLoadInput
  cases hClearAcc
  cases hDoMacHidden
  cases hDoBiasHidden
  cases hDoActHidden
  cases hAdvanceHidden
  cases hDoMacOutput
  cases hDoBiasOutput
  cases hDone
  cases hBusy
  cases hOutBit
  cases hHiddenIdx
  cases hInputIdx
  cases hAccReg
  cases hMacAccOut
  cases hMacA
  cases hB2Data
  cases hInputReg0
  cases hInputReg1
  cases hInputReg2
  cases hInputReg3
  cases hHiddenReg0
  cases hHiddenReg1
  cases hHiddenReg2
  cases hHiddenReg3
  cases hHiddenReg4
  cases hHiddenReg5
  cases hHiddenReg6
  cases hHiddenReg7
  cases hHiddenInputCaseHit
  cases hOutputHiddenCaseHit
  cases hHiddenWeightCaseHit
  cases hOutputWeightCaseHit
  rfl

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

def input0Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => BitVec.ofInt 8 (samples t).inputs.x0.toInt⟩

def input1Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => BitVec.ofInt 8 (samples t).inputs.x1.toInt⟩

def input2Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => BitVec.ofInt 8 (samples t).inputs.x2.toInt⟩

def input3Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => BitVec.ofInt 8 (samples t).inputs.x3.toInt⟩

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

private def encodeInputReg (input : Input8) (idx : Nat) : BitVec 8 :=
  BitVec.ofInt 8 (input.getInt8Nat idx).toInt

private def encodeHiddenReg (hidden : Hidden16) (idx : Nat) : BitVec 16 :=
  BitVec.ofInt 16 (hidden.getCellNat idx).toInt

private def encodeAccReg (acc : Acc32) : BitVec 32 :=
  BitVec.ofInt 32 acc.toInt

private def phaseOf : MlpCoreState → BitVec stateWidth
  | (phase, _) => phase

private def hiddenIdxOf : MlpCoreState → BitVec stateWidth
  | (_, (hidden_idx, _)) => hidden_idx

private def inputIdxOf : MlpCoreState → BitVec stateWidth
  | (_, (_, (input_idx, _))) => input_idx

private def inputReg0Of : MlpCoreState → BitVec 8
  | (_, (_, (_, (input_reg0, _)))) => input_reg0

private def inputReg1Of : MlpCoreState → BitVec 8
  | (_, (_, (_, (_, (input_reg1, _))))) => input_reg1

private def inputReg2Of : MlpCoreState → BitVec 8
  | (_, (_, (_, (_, (_, (input_reg2, _)))))) => input_reg2

private def inputReg3Of : MlpCoreState → BitVec 8
  | (_, (_, (_, (_, (_, (_, (input_reg3, _))))))) => input_reg3

private def hiddenReg0Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (hidden_reg0, _)))))))) => hidden_reg0

private def hiddenReg1Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg1, _))))))))) => hidden_reg1

private def hiddenReg2Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg2, _)))))))))) => hidden_reg2

private def hiddenReg3Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg3, _))))))))))) => hidden_reg3

private def hiddenReg4Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg4, _)))))))))))) => hidden_reg4

private def hiddenReg5Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg5, _))))))))))))) => hidden_reg5

private def hiddenReg6Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg6, _)))))))))))))) => hidden_reg6

private def hiddenReg7Of : MlpCoreState → BitVec 16
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (hidden_reg7, _))))))))))))))) => hidden_reg7

private def accRegOf : MlpCoreState → BitVec 32
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (acc_reg, _)))))))))))))))) => acc_reg

private def outRegOf : MlpCoreState → Bool
  | (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, (_, out_reg)))))))))))))))) => out_reg

@[simp] private theorem phase_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.phase state).atTime t = phaseOf (state.atTime t) := by
  rfl

@[simp] private theorem hiddenIdx_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_idx state).atTime t = hiddenIdxOf (state.atTime t) := by
  rfl

@[simp] private theorem inputIdx_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.input_idx state).atTime t = inputIdxOf (state.atTime t) := by
  rfl

@[simp] private theorem inputReg0_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.input_reg0 state).atTime t = inputReg0Of (state.atTime t) := by
  rfl

@[simp] private theorem inputReg1_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.input_reg1 state).atTime t = inputReg1Of (state.atTime t) := by
  rfl

@[simp] private theorem inputReg2_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.input_reg2 state).atTime t = inputReg2Of (state.atTime t) := by
  rfl

@[simp] private theorem inputReg3_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.input_reg3 state).atTime t = inputReg3Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg0_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg0 state).atTime t = hiddenReg0Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg1_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg1 state).atTime t = hiddenReg1Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg2_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg2 state).atTime t = hiddenReg2Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg3_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg3 state).atTime t = hiddenReg3Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg4_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg4 state).atTime t = hiddenReg4Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg5_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg5 state).atTime t = hiddenReg5Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg6_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg6 state).atTime t = hiddenReg6Of (state.atTime t) := by
  rfl

@[simp] private theorem hiddenReg7_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.hidden_reg7 state).atTime t = hiddenReg7Of (state.atTime t) := by
  rfl

@[simp] private theorem accReg_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.acc_reg state).atTime t = accRegOf (state.atTime t) := by
  rfl

@[simp] private theorem outReg_of_atTime {dom : DomainConfig} (state : Signal dom MlpCoreState) (t : Nat) :
    (MlpCoreState.out_reg state).atTime t = outRegOf (state.atTime t) := by
  rfl

private def w1DataComb (hidden_idx input_idx : BitVec stateWidth) : BitVec 8 :=
  (w1Data (dom := defaultDomain) (Signal.pure hidden_idx) (Signal.pure input_idx)).atTime 0

private def b1DataComb (hidden_idx : BitVec stateWidth) : BitVec 32 :=
  (b1Data (dom := defaultDomain) (Signal.pure hidden_idx)).atTime 0

private def w2DataComb (input_idx : BitVec stateWidth) : BitVec 8 :=
  (w2Data (dom := defaultDomain) (Signal.pure input_idx)).atTime 0

private def b2DataComb : BitVec 32 :=
  (b2Data (dom := defaultDomain)).atTime 0

def rtlHiddenIdxSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => BitVec.ofNat stateWidth (rtlTrace samples t).hiddenIdx⟩

def rtlInputIdxSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => BitVec.ofNat stateWidth (rtlTrace samples t).inputIdx⟩

def rtlPhaseSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec stateWidth) :=
  ⟨fun t => encodePhase (rtlTrace samples t).phase⟩

def rtlInputReg0Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => encodeInputReg (rtlTrace samples t).regs 0⟩

def rtlInputReg1Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => encodeInputReg (rtlTrace samples t).regs 1⟩

def rtlInputReg2Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => encodeInputReg (rtlTrace samples t).regs 2⟩

def rtlInputReg3Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 8) :=
  ⟨fun t => encodeInputReg (rtlTrace samples t).regs 3⟩

def rtlHiddenReg0Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 0⟩

def rtlHiddenReg1Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 1⟩

def rtlHiddenReg2Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 2⟩

def rtlHiddenReg3Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 3⟩

def rtlHiddenReg4Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 4⟩

def rtlHiddenReg5Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 5⟩

def rtlHiddenReg6Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 6⟩

def rtlHiddenReg7Signal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 16) :=
  ⟨fun t => encodeHiddenReg (rtlTrace samples t).hidden 7⟩

def rtlAccRegSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom (BitVec 32) :=
  ⟨fun t => encodeAccReg (rtlTrace samples t).accumulator⟩

def rtlOutRegSignal {dom : DomainConfig} (samples : Nat → CtrlSample) : Signal dom Bool :=
  ⟨fun t => (rtlTrace samples t).output⟩

def canonicalMlpCoreView {dom : DomainConfig} (samples : Nat → CtrlSample) : MlpCoreView dom :=
  mlpCoreViewOfState
    (rtlPhaseSignal samples)
    (rtlHiddenIdxSignal samples)
    (rtlInputIdxSignal samples)
    (rtlInputReg0Signal samples)
    (rtlInputReg1Signal samples)
    (rtlInputReg2Signal samples)
    (rtlInputReg3Signal samples)
    (rtlHiddenReg0Signal samples)
    (rtlHiddenReg1Signal samples)
    (rtlHiddenReg2Signal samples)
    (rtlHiddenReg3Signal samples)
    (rtlHiddenReg4Signal samples)
    (rtlHiddenReg5Signal samples)
    (rtlHiddenReg6Signal samples)
    (rtlHiddenReg7Signal samples)
    (rtlAccRegSignal samples)
    (rtlOutRegSignal samples)

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

private theorem controllerPhaseNext_val {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec stateWidth))
    (input_idx : Signal dom (BitVec stateWidth))
    (inputNeurons4b : Signal dom (BitVec stateWidth))
    (hiddenNeurons4b : Signal dom (BitVec stateWidth))
    (lastHiddenIdx : Signal dom (BitVec stateWidth))
    (state : Signal dom (BitVec stateWidth))
    (t : Nat) :
    (controllerPhaseNext start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx state).val t =
      controllerPhaseNextComb
        (start.val t)
        (hidden_idx.val t)
        (input_idx.val t)
        (inputNeurons4b.val t)
        (hiddenNeurons4b.val t)
        (lastHiddenIdx.val t)
        (state.val t) := by
  simpa [Signal.atTime] using
    controllerPhaseNext_atTime
      start
      hidden_idx
      input_idx
      inputNeurons4b
      hiddenNeurons4b
      lastHiddenIdx
      state
      t

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

private def mlpCoreOutputsAt
    (state : BitVec stateWidth)
    (hidden_idx : BitVec stateWidth)
    (input_idx : BitVec stateWidth)
    (input_reg0 : BitVec 8)
    (input_reg1 : BitVec 8)
    (input_reg2 : BitVec 8)
    (input_reg3 : BitVec 8)
    (hidden_reg0 : BitVec 16)
    (hidden_reg1 : BitVec 16)
    (hidden_reg2 : BitVec 16)
    (hidden_reg3 : BitVec 16)
    (hidden_reg4 : BitVec 16)
    (hidden_reg5 : BitVec 16)
    (hidden_reg6 : BitVec 16)
    (hidden_reg7 : BitVec 16)
    (acc_reg : BitVec 32)
    (out_reg : Bool) : MlpCoreOutputs :=
  let hiddenMacTerm32At (inputVal weightVal : BitVec 8) : BitVec 32 :=
    let inputUpper : BitVec 16 :=
      if BitVec.extractLsb' 7 1 inputVal == 1#1 then BitVec.ofInt 16 (-1) else 0#16
    let weightUpper : BitVec 16 :=
      if BitVec.extractLsb' 7 1 weightVal == 1#1 then BitVec.ofInt 16 (-1) else 0#16
    let input24 : BitVec 24 := BitVec.append inputUpper inputVal
    let weight24 : BitVec 24 := BitVec.append weightUpper weightVal
    let product24 : BitVec 24 := input24 * weight24
    let productUpper : BitVec 8 :=
      if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
    BitVec.append productUpper product24
  let outputMacTerm32At (hiddenVal : BitVec 16) (weightVal : BitVec 8) : BitVec 32 :=
    let hiddenUpper : BitVec 8 :=
      if BitVec.extractLsb' 15 1 hiddenVal == 1#1 then BitVec.ofInt 8 (-1) else 0#8
    let hidden24 : BitVec 24 := BitVec.append hiddenUpper hiddenVal
    let weightUpper : BitVec 16 :=
      if BitVec.extractLsb' 7 1 weightVal == 1#1 then BitVec.ofInt 16 (-1) else 0#16
    let weight24 : BitVec 24 := BitVec.append weightUpper weightVal
    let product24 : BitVec 24 := hidden24 * weight24
    let productUpper : BitVec 8 :=
      if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
    BitVec.append productUpper product24
  let controller := controllerOutputsAt state input_idx inputCount4b hiddenCount4b
  let isMacOutput := state == stMacOutput
  let hidden_input_case_hit := (!isMacOutput) && BitVec.ult input_idx inputCount4b
  let output_hidden_case_hit := isMacOutput && BitVec.ult input_idx hiddenCount4b
  let hidden_weight_case_hit := BitVec.ult hidden_idx hiddenCount4b && BitVec.ult input_idx inputCount4b
  let output_weight_case_hit := BitVec.ult input_idx hiddenCount4b
  let selectedInput := selectInputRegComb input_idx input_reg0 input_reg1 input_reg2 input_reg3
  let selectedHidden := selectHiddenRegComb
    input_idx
    hidden_reg0 hidden_reg1 hidden_reg2 hidden_reg3
    hidden_reg4 hidden_reg5 hidden_reg6 hidden_reg7
  let selectedInputUpper : BitVec 8 :=
    if BitVec.extractLsb' 7 1 selectedInput == 1#1 then BitVec.ofInt 8 (-1) else 0#8
  let mac_a_hidden : BitVec 16 := BitVec.append selectedInputUpper selectedInput
  let hiddenMacAccOut := acc_reg + hiddenMacTerm32At selectedInput (w1DataComb hidden_idx input_idx)
  let outputMacAccOut := acc_reg + outputMacTerm32At selectedHidden (w2DataComb input_idx)
  { state := controller.state
  , load_input := controller.load_input
  , clear_acc := controller.clear_acc
  , do_mac_hidden := controller.do_mac_hidden
  , do_bias_hidden := controller.do_bias_hidden
  , do_act_hidden := controller.do_act_hidden
  , advance_hidden := controller.advance_hidden
  , do_mac_output := controller.do_mac_output
  , do_bias_output := controller.do_bias_output
  , done := controller.done
  , busy := controller.busy
  , out_bit := out_reg
  , hidden_idx
  , input_idx
  , acc_reg
  , mac_acc_out := if isMacOutput then outputMacAccOut else hiddenMacAccOut
  , mac_a := if isMacOutput then selectedHidden else mac_a_hidden
  , b2_data := b2DataComb
  , input_reg0
  , input_reg1
  , input_reg2
  , input_reg3
  , hidden_reg0
  , hidden_reg1
  , hidden_reg2
  , hidden_reg3
  , hidden_reg4
  , hidden_reg5
  , hidden_reg6
  , hidden_reg7
  , hidden_input_case_hit
  , output_hidden_case_hit
  , hidden_weight_case_hit
  , output_weight_case_hit
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

private theorem selectInputReg_sample {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (r0 r1 r2 r3 : Signal dom (BitVec 8))
    (t : Nat) :
    (selectInputReg idx r0 r1 r2 r3).atTime t =
      selectInputRegComb
        (idx.atTime t)
        (r0.atTime t)
        (r1.atTime t)
        (r2.atTime t)
        (r3.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  simp [selectInputReg, selectInputRegComb, Signal.atTime, Signal.pure, Signal.mux, hEq]

private theorem selectInputReg_val {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (r0 r1 r2 r3 : Signal dom (BitVec 8))
    (t : Nat) :
    (selectInputReg idx r0 r1 r2 r3).val t =
      selectInputRegComb (idx.val t) (r0.val t) (r1.val t) (r2.val t) (r3.val t) := by
  simpa [Signal.atTime] using selectInputReg_sample idx r0 r1 r2 r3 t

private theorem selectInputReg_eq_comb_signal {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (r0 r1 r2 r3 : Signal dom (BitVec 8)) :
    selectInputReg idx r0 r1 r2 r3 =
      ⟨fun t => selectInputRegComb (idx.val t) (r0.val t) (r1.val t) (r2.val t) (r3.val t)⟩ := by
  cases idx with
  | mk idxVal =>
      cases r0 with
      | mk r0Val =>
          cases r1 with
          | mk r1Val =>
              cases r2 with
              | mk r2Val =>
                  cases r3 with
                  | mk r3Val =>
                      apply congrArg Signal.mk
                      funext t
                      have hEq {α : Type} [BEq α] (a b : Signal dom α) :
                          (a === b).val t = (a.val t == b.val t) := by rfl
                      simp [selectInputRegComb, Signal.pure, Signal.mux, hEq]

private theorem selectHiddenReg_sample {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (h0 h1 h2 h3 h4 h5 h6 h7 : Signal dom (BitVec 16))
    (t : Nat) :
    (selectHiddenReg idx h0 h1 h2 h3 h4 h5 h6 h7).atTime t =
      selectHiddenRegComb
        (idx.atTime t)
        (h0.atTime t)
        (h1.atTime t)
        (h2.atTime t)
        (h3.atTime t)
        (h4.atTime t)
        (h5.atTime t)
        (h6.atTime t)
        (h7.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  simp [selectHiddenReg, selectHiddenRegComb, Signal.atTime, Signal.pure, Signal.mux, hEq]

private theorem selectHiddenReg_val {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (h0 h1 h2 h3 h4 h5 h6 h7 : Signal dom (BitVec 16))
    (t : Nat) :
    (selectHiddenReg idx h0 h1 h2 h3 h4 h5 h6 h7).val t =
      selectHiddenRegComb
        (idx.val t)
        (h0.val t) (h1.val t) (h2.val t) (h3.val t)
        (h4.val t) (h5.val t) (h6.val t) (h7.val t) := by
  simpa [Signal.atTime] using selectHiddenReg_sample idx h0 h1 h2 h3 h4 h5 h6 h7 t

private theorem selectHiddenReg_eq_comb_signal {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (h0 h1 h2 h3 h4 h5 h6 h7 : Signal dom (BitVec 16)) :
    selectHiddenReg idx h0 h1 h2 h3 h4 h5 h6 h7 =
      ⟨fun t =>
        selectHiddenRegComb
          (idx.val t)
          (h0.val t) (h1.val t) (h2.val t) (h3.val t)
          (h4.val t) (h5.val t) (h6.val t) (h7.val t)⟩ := by
  cases idx with
  | mk idxVal =>
      cases h0 with
      | mk h0Val =>
          cases h1 with
          | mk h1Val =>
              cases h2 with
              | mk h2Val =>
                  cases h3 with
                  | mk h3Val =>
                      cases h4 with
                      | mk h4Val =>
                          cases h5 with
                          | mk h5Val =>
                              cases h6 with
                              | mk h6Val =>
                                  cases h7 with
                                  | mk h7Val =>
                                      apply congrArg Signal.mk
                                      funext t
                                      have hEq {α : Type} [BEq α] (a b : Signal dom α) :
                                          (a === b).val t = (a.val t == b.val t) := by rfl
                                      simp [selectHiddenRegComb, Signal.pure, Signal.mux, hEq]

private theorem updateHiddenReg_sample {dom : DomainConfig}
    (target : BitVec 4)
    (hiddenIdx : Signal dom (BitVec 4))
    (newValue current : Signal dom (BitVec 16))
    (t : Nat) :
    (updateHiddenReg target hiddenIdx newValue current).atTime t =
      updateHiddenRegComb target (hiddenIdx.atTime t) (newValue.atTime t) (current.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  simp [updateHiddenReg, updateHiddenRegComb, Signal.atTime, Signal.pure, Signal.mux, hEq]

private theorem updateHiddenReg_val {dom : DomainConfig}
    (target : BitVec 4)
    (hiddenIdx : Signal dom (BitVec 4))
    (newValue current : Signal dom (BitVec 16))
    (t : Nat) :
    (updateHiddenReg target hiddenIdx newValue current).val t =
      updateHiddenRegComb target (hiddenIdx.val t) (newValue.val t) (current.val t) := by
  simpa [Signal.atTime] using updateHiddenReg_sample target hiddenIdx newValue current t

private theorem w1Data_sample {dom : DomainConfig}
    (hidden_idx input_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (w1Data hidden_idx input_idx).atTime t =
      w1DataComb (hidden_idx.atTime t) (input_idx.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hAnd (a b : Signal dom Bool) :
      (a &&& b).val t = (a.val t && b.val t) := by rfl
  have hEq0 {α : Type} [BEq α] (a b : Signal defaultDomain α) :
      (a === b).val 0 = (a.val 0 == b.val 0) := by rfl
  have hAnd0 (a b : Signal defaultDomain Bool) :
      (a &&& b).val 0 = (a.val 0 && b.val 0) := by rfl
  simp [w1Data, w1DataComb, Signal.atTime, Signal.pure, Signal.mux, hEq, hAnd, hEq0, hAnd0]

private theorem w1Data_val {dom : DomainConfig}
    (hidden_idx input_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (w1Data hidden_idx input_idx).val t =
      w1DataComb (hidden_idx.val t) (input_idx.val t) := by
  simpa [Signal.atTime] using w1Data_sample hidden_idx input_idx t

private theorem b1Data_sample {dom : DomainConfig}
    (hidden_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (b1Data hidden_idx).atTime t =
      b1DataComb (hidden_idx.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hEq0 {α : Type} [BEq α] (a b : Signal defaultDomain α) :
      (a === b).val 0 = (a.val 0 == b.val 0) := by rfl
  simp [b1Data, b1DataComb, Signal.atTime, Signal.pure, Signal.mux, hEq, hEq0]

private theorem b1Data_val {dom : DomainConfig}
    (hidden_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (b1Data hidden_idx).val t =
      b1DataComb (hidden_idx.val t) := by
  simpa [Signal.atTime] using b1Data_sample hidden_idx t

private theorem w2Data_sample {dom : DomainConfig}
    (input_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (w2Data input_idx).atTime t =
      w2DataComb (input_idx.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hEq0 {α : Type} [BEq α] (a b : Signal defaultDomain α) :
      (a === b).val 0 = (a.val 0 == b.val 0) := by rfl
  simp [w2Data, w2DataComb, Signal.atTime, Signal.pure, Signal.mux, hEq, hEq0]

private theorem w2Data_val {dom : DomainConfig}
    (input_idx : Signal dom (BitVec 4))
    (t : Nat) :
    (w2Data input_idx).val t =
      w2DataComb (input_idx.val t) := by
  simpa [Signal.atTime] using w2Data_sample input_idx t

private theorem b2Data_sample {dom : DomainConfig}
    (t : Nat) :
    (b2Data (dom := dom)).atTime t = b2DataComb := by
  simp [b2Data, b2DataComb, Signal.atTime, Signal.pure]

private theorem b2Data_val {dom : DomainConfig}
    (t : Nat) :
    (b2Data (dom := dom)).val t = b2DataComb := by
  simpa [Signal.atTime] using b2Data_sample (dom := dom) t

private theorem hiddenMacTerm32_sample {dom : DomainConfig}
    (inputVal weightVal : Signal dom (BitVec 8))
    (t : Nat) :
    (hiddenMacTerm32 inputVal weightVal).atTime t =
      let inputUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (inputVal.atTime t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let weightUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (weightVal.atTime t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let input24 : BitVec 24 := BitVec.append inputUpper (inputVal.atTime t)
      let weight24 : BitVec 24 := BitVec.append weightUpper (weightVal.atTime t)
      let product24 : BitVec 24 := input24 * weight24
      let productUpper : BitVec 8 :=
        if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      BitVec.append productUpper product24 := by
  have hMapAt {α β : Type} (f : α → β) (s : Signal dom α) :
      (Signal.map f s).val t = f (s.val t) := by rfl
  have hMuxAt {α : Type} (c : Signal dom Bool) (a b : Signal dom α) :
      (Signal.mux c a b).val t = if c.val t then a.val t else b.val t := by rfl
  have hBeqAt {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hAppendAt {m n : Nat} (a : Signal dom (BitVec m)) (b : Signal dom (BitVec n)) :
      (((fun x1 x2 => x1 ++ x2) <$> a <*> b).val t) = BitVec.append (a.val t) (b.val t) := by rfl
  have hMulAt {n : Nat} (a b : Signal dom (BitVec n)) :
      (a * b).val t = a.val t * b.val t := by rfl
  simp [hiddenMacTerm32, Signal.atTime, Signal.pure, hMapAt, hMuxAt, hBeqAt, hAppendAt, hMulAt]

private theorem hiddenMacTerm32_val {dom : DomainConfig}
    (inputVal weightVal : Signal dom (BitVec 8))
    (t : Nat) :
    (hiddenMacTerm32 inputVal weightVal).val t =
      let inputUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (inputVal.val t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let weightUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (weightVal.val t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let input24 : BitVec 24 := BitVec.append inputUpper (inputVal.val t)
      let weight24 : BitVec 24 := BitVec.append weightUpper (weightVal.val t)
      let product24 : BitVec 24 := input24 * weight24
      let productUpper : BitVec 8 :=
        if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      BitVec.append productUpper product24 := by
  simpa [Signal.atTime] using hiddenMacTerm32_sample inputVal weightVal t

private theorem outputMacTerm32_sample {dom : DomainConfig}
    (hiddenVal : Signal dom (BitVec 16))
    (weightVal : Signal dom (BitVec 8))
    (t : Nat) :
    (outputMacTerm32 hiddenVal weightVal).atTime t =
      let hiddenUpper : BitVec 8 :=
        if BitVec.extractLsb' 15 1 (hiddenVal.atTime t) == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      let hidden24 : BitVec 24 := BitVec.append hiddenUpper (hiddenVal.atTime t)
      let weightUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (weightVal.atTime t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let weight24 : BitVec 24 := BitVec.append weightUpper (weightVal.atTime t)
      let product24 : BitVec 24 := hidden24 * weight24
      let productUpper : BitVec 8 :=
        if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      BitVec.append productUpper product24 := by
  have hMapAt {α β : Type} (f : α → β) (s : Signal dom α) :
      (Signal.map f s).val t = f (s.val t) := by rfl
  have hMuxAt {α : Type} (c : Signal dom Bool) (a b : Signal dom α) :
      (Signal.mux c a b).val t = if c.val t then a.val t else b.val t := by rfl
  have hBeqAt {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hAppendAt {m n : Nat} (a : Signal dom (BitVec m)) (b : Signal dom (BitVec n)) :
      (((fun x1 x2 => x1 ++ x2) <$> a <*> b).val t) = BitVec.append (a.val t) (b.val t) := by rfl
  have hMulAt {n : Nat} (a b : Signal dom (BitVec n)) :
      (a * b).val t = a.val t * b.val t := by rfl
  simp [outputMacTerm32, Signal.atTime, Signal.pure, hMapAt, hMuxAt, hBeqAt, hAppendAt, hMulAt]

private theorem outputMacTerm32_val {dom : DomainConfig}
    (hiddenVal : Signal dom (BitVec 16))
    (weightVal : Signal dom (BitVec 8))
    (t : Nat) :
    (outputMacTerm32 hiddenVal weightVal).val t =
      let hiddenUpper : BitVec 8 :=
        if BitVec.extractLsb' 15 1 (hiddenVal.val t) == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      let hidden24 : BitVec 24 := BitVec.append hiddenUpper (hiddenVal.val t)
      let weightUpper : BitVec 16 :=
        if BitVec.extractLsb' 7 1 (weightVal.val t) == 1#1 then BitVec.ofInt 16 (-1) else 0#16
      let weight24 : BitVec 24 := BitVec.append weightUpper (weightVal.val t)
      let product24 : BitVec 24 := hidden24 * weight24
      let productUpper : BitVec 8 :=
        if BitVec.extractLsb' 23 1 product24 == 1#1 then BitVec.ofInt 8 (-1) else 0#8
      BitVec.append productUpper product24 := by
  simpa [Signal.atTime] using outputMacTerm32_sample hiddenVal weightVal t

private theorem relu16_sample {dom : DomainConfig}
    (x : Signal dom (BitVec 32))
    (t : Nat) :
    (relu16 x).atTime t = relu16Comb (x.atTime t) := by
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  change
    (if BitVec.extractLsb' 31 1 (x.val t) == 1#1 then 0#16 else BitVec.extractLsb' 0 16 (x.val t)) =
      (if BitVec.extractLsb' 31 1 (x.val t) == 1#1 then 0#16 else BitVec.extractLsb' 0 16 (x.val t))
  rfl

private theorem relu16_val {dom : DomainConfig}
    (x : Signal dom (BitVec 32))
    (t : Nat) :
    (relu16 x).val t = relu16Comb (x.val t) := by
  simpa [Signal.atTime] using relu16_sample x t

private theorem gtZero32_sample {dom : DomainConfig}
    (x : Signal dom (BitVec 32))
    (t : Nat) :
    (gtZero32 x).atTime t = gtZero32Comb (x.atTime t) := by
  rfl

private theorem gtZero32_val {dom : DomainConfig}
    (x : Signal dom (BitVec 32))
    (t : Nat) :
    (gtZero32 x).val t = gtZero32Comb (x.val t) := by
  simpa [Signal.atTime] using gtZero32_sample x t

private theorem mlpCoreViewOfState_sample {dom : DomainConfig}
    (state : Signal dom (BitVec stateWidth))
    (hidden_idx : Signal dom (BitVec stateWidth))
    (input_idx : Signal dom (BitVec stateWidth))
    (input_reg0 : Signal dom (BitVec 8))
    (input_reg1 : Signal dom (BitVec 8))
    (input_reg2 : Signal dom (BitVec 8))
    (input_reg3 : Signal dom (BitVec 8))
    (hidden_reg0 : Signal dom (BitVec 16))
    (hidden_reg1 : Signal dom (BitVec 16))
    (hidden_reg2 : Signal dom (BitVec 16))
    (hidden_reg3 : Signal dom (BitVec 16))
    (hidden_reg4 : Signal dom (BitVec 16))
    (hidden_reg5 : Signal dom (BitVec 16))
    (hidden_reg6 : Signal dom (BitVec 16))
    (hidden_reg7 : Signal dom (BitVec 16))
    (acc_reg : Signal dom (BitVec 32))
    (out_reg : Signal dom Bool)
    (t : Nat) :
    (mlpCoreViewOfState
      state
      hidden_idx
      input_idx
      input_reg0
      input_reg1
      input_reg2
      input_reg3
      hidden_reg0
      hidden_reg1
      hidden_reg2
      hidden_reg3
      hidden_reg4
      hidden_reg5
      hidden_reg6
      hidden_reg7
      acc_reg
      out_reg).sample t =
        mlpCoreOutputsAt
          (state.atTime t)
          (hidden_idx.atTime t)
          (input_idx.atTime t)
          (input_reg0.atTime t)
          (input_reg1.atTime t)
          (input_reg2.atTime t)
          (input_reg3.atTime t)
          (hidden_reg0.atTime t)
          (hidden_reg1.atTime t)
          (hidden_reg2.atTime t)
          (hidden_reg3.atTime t)
          (hidden_reg4.atTime t)
          (hidden_reg5.atTime t)
          (hidden_reg6.atTime t)
          (hidden_reg7.atTime t)
          (acc_reg.atTime t)
          (out_reg.atTime t) := by
  have hController := controllerViewOfState_sample state input_idx (Signal.pure inputCount4b) (Signal.pure hiddenCount4b) t
  have hState := congrArg ControllerOutputs.state hController
  have hLoad := congrArg ControllerOutputs.load_input hController
  have hClear := congrArg ControllerOutputs.clear_acc hController
  have hMacHidden := congrArg ControllerOutputs.do_mac_hidden hController
  have hBiasHidden := congrArg ControllerOutputs.do_bias_hidden hController
  have hActHidden := congrArg ControllerOutputs.do_act_hidden hController
  have hAdvance := congrArg ControllerOutputs.advance_hidden hController
  have hMacOutput := congrArg ControllerOutputs.do_mac_output hController
  have hBiasOutput := congrArg ControllerOutputs.do_bias_output hController
  have hDone := congrArg ControllerOutputs.done hController
  have hBusy := congrArg ControllerOutputs.busy hController
  have hEq {α : Type} [BEq α] (a b : Signal dom α) :
      (a === b).val t = (a.val t == b.val t) := by rfl
  have hAnd (a b : Signal dom Bool) :
      (a &&& b).val t = (a.val t && b.val t) := by rfl
  have hNot (a : Signal dom Bool) :
      ((fun value => !value) <$> a).val t = !a.val t := by rfl
  have hUlt (a b : Signal dom (BitVec stateWidth)) :
      (((BitVec.ult · ·) <$> a <*> b).val t) = BitVec.ult (a.val t) (b.val t) := by rfl
  have hAdd {n : Nat} (a b : Signal dom (BitVec n)) :
      (a + b).val t = a.val t + b.val t := by rfl
  have hAppend {m n : Nat} (a : Signal dom (BitVec m)) (b : Signal dom (BitVec n)) :
      (((BitVec.append · ·) <$> a <*> b).val t) = BitVec.append (a.val t) (b.val t) := by rfl
  have hConcat {m n : Nat} (a : Signal dom (BitVec m)) (b : Signal dom (BitVec n)) :
      (((fun x1 x2 => x1 ++ x2) <$> a <*> b).val t) = BitVec.append (a.val t) (b.val t) := by rfl
  refine mlpCoreOutputs_ext
    hState
    hLoad
    hClear
    hMacHidden
    hBiasHidden
    hActHidden
    hAdvance
    hMacOutput
    hBiasOutput
    hDone
    hBusy
    rfl
    rfl
    rfl
    rfl
    ?_
    ?_
    ?_
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    rfl
    ?_
    ?_
    ?_
    ?_
  · simp [MlpCoreView.sample, mlpCoreViewOfState, mlpCoreOutputsAt, Signal.atTime, Signal.pure, Signal.mux,
      selectInputReg_val, selectHiddenReg_val, w1Data_val, w2Data_val, hiddenMacTerm32_val,
      outputMacTerm32_val, hEq, hAnd, hNot, hUlt, hAdd]
  · change
      (let isMacOutput := state === (stMacOutput : Signal dom _)
       let selectedInput := selectInputReg input_idx input_reg0 input_reg1 input_reg2 input_reg3
       let selectedHidden := selectHiddenReg
         input_idx
         hidden_reg0 hidden_reg1 hidden_reg2 hidden_reg3
         hidden_reg4 hidden_reg5 hidden_reg6 hidden_reg7
       let selectedInputSign := selectedInput.map (BitVec.extractLsb' 7 1 ·)
       let selectedInputUpper := Signal.mux
         (selectedInputSign === Signal.pure 1#1)
         (Signal.pure (BitVec.ofInt 8 (-1)))
         (Signal.pure 0#8)
       let mac_a_hidden : Signal dom (BitVec 16) := (BitVec.append · ·) <$> selectedInputUpper <*> selectedInput
       let mac_a : Signal dom (BitVec 16) := Signal.mux isMacOutput selectedHidden mac_a_hidden
       mac_a.atTime t)
      =
      (if state.atTime t == stMacOutput then
        selectHiddenRegComb
          (input_idx.atTime t)
          (hidden_reg0.atTime t) (hidden_reg1.atTime t) (hidden_reg2.atTime t) (hidden_reg3.atTime t)
          (hidden_reg4.atTime t) (hidden_reg5.atTime t) (hidden_reg6.atTime t) (hidden_reg7.atTime t)
      else
        BitVec.append
          (if
              BitVec.extractLsb' 7 1
                  (selectInputRegComb
                    (input_idx.atTime t)
                    (input_reg0.atTime t) (input_reg1.atTime t) (input_reg2.atTime t) (input_reg3.atTime t)) == 1#1
            then BitVec.ofInt 8 (-1)
            else 0#8)
          (selectInputRegComb
            (input_idx.atTime t)
            (input_reg0.atTime t) (input_reg1.atTime t) (input_reg2.atTime t) (input_reg3.atTime t)))
    simp [selectInputReg_eq_comb_signal, selectHiddenReg_eq_comb_signal, Signal.atTime, Signal.pure,
      Signal.mux, Signal.map, hEq, hConcat]
  · simp [MlpCoreView.sample, mlpCoreViewOfState, mlpCoreOutputsAt, Signal.atTime, Signal.pure, b2DataComb, b2Data]
  · change
      (! (state.val t = 6#4) && BitVec.ult (input_idx.val t) inputCount4b) =
        (! (state.val t = 6#4) && BitVec.ult (input_idx.val t) (BitVec.ofNat stateWidth inputCount))
    simp [inputCount4b]
  · change
      ((state.val t = 6#4) && BitVec.ult (input_idx.val t) hiddenCount4b) =
        ((state.val t = 6#4) && BitVec.ult (input_idx.val t) (BitVec.ofNat stateWidth hiddenCount))
    simp [hiddenCount4b]
  · change
      (BitVec.ult (hidden_idx.val t) hiddenCount4b && BitVec.ult (input_idx.val t) inputCount4b) =
        (BitVec.ult (hidden_idx.val t) (BitVec.ofNat stateWidth hiddenCount) &&
          BitVec.ult (input_idx.val t) (BitVec.ofNat stateWidth inputCount))
    simp [inputCount4b, hiddenCount4b]
  · change BitVec.ult (input_idx.val t) hiddenCount4b =
      BitVec.ult (input_idx.val t) (BitVec.ofNat stateWidth hiddenCount)
    simp [hiddenCount4b]

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

def mlpCoreOutputsOfState (s : State) : MlpCoreOutputs :=
  mlpCoreOutputsAt
    (encodePhase s.phase)
    (BitVec.ofNat stateWidth s.hiddenIdx)
    (BitVec.ofNat stateWidth s.inputIdx)
    (encodeInputReg s.regs 0)
    (encodeInputReg s.regs 1)
    (encodeInputReg s.regs 2)
    (encodeInputReg s.regs 3)
    (encodeHiddenReg s.hidden 0)
    (encodeHiddenReg s.hidden 1)
    (encodeHiddenReg s.hidden 2)
    (encodeHiddenReg s.hidden 3)
    (encodeHiddenReg s.hidden 4)
    (encodeHiddenReg s.hidden 5)
    (encodeHiddenReg s.hidden 6)
    (encodeHiddenReg s.hidden 7)
    (encodeAccReg s.accumulator)
    s.output

private theorem inputSignal_decodes_sample {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    MlpCore.sampleAt
        (startSignal (dom := dom) samples)
        (input0Signal (dom := dom) samples)
        (input1Signal (dom := dom) samples)
        (input2Signal (dom := dom) samples)
        (input3Signal (dom := dom) samples)
        t
      = samples t := by
  cases hs : samples t with
  | mk start inputs =>
      cases inputs with
      | mk x0 x1 x2 x3 =>
          simp [Signal.atTime, MlpCore.sampleAt, startSignal, input0Signal, input1Signal, input2Signal, input3Signal,
            decodeInput]
          constructor
          · simp [hs]
          constructor
          · simp [hs]
          constructor
          · simp [hs]
          constructor
          · simp [hs]
          · simp [hs]

private theorem sparkleMlpCoreTrace_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    MlpCore.trace
        (startSignal (dom := dom) samples)
        (input0Signal (dom := dom) samples)
        (input1Signal (dom := dom) samples)
        (input2Signal (dom := dom) samples)
        (input3Signal (dom := dom) samples)
        t =
      rtlTrace samples t := by
  induction t with
  | zero =>
      rfl
  | succ n ih =>
      calc
        MlpCore.trace
            (startSignal (dom := dom) samples)
            (input0Signal (dom := dom) samples)
            (input1Signal (dom := dom) samples)
            (input2Signal (dom := dom) samples)
            (input3Signal (dom := dom) samples)
            (n + 1) =
          timedStep
            (MlpCore.sampleAt
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples)
              n)
            (MlpCore.trace
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples)
              n) := by
                simp [MlpCore.trace, rtlTrace]
        _ = timedStep (samples n) (rtlTrace samples n) := by
              simpa [MlpCore.trace, inputSignal_decodes_sample] using
                congrArg (timedStep (samples n)) ih
        _ = rtlTrace samples (n + 1) := by
              simp [rtlTrace]

private theorem encodeInputReg_sampleAt0 {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (t : Nat) :
    encodeInputReg (MlpCore.sampleAt start in0 in1 in2 in3 t).inputs 0 = in0.atTime t := by
  simp [encodeInputReg, MlpCore.sampleAt, decodeInput, Input8.getInt8Nat, Input8.getNat]

private theorem encodeInputReg_sampleAt1 {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (t : Nat) :
    encodeInputReg (MlpCore.sampleAt start in0 in1 in2 in3 t).inputs 1 = in1.atTime t := by
  simp [encodeInputReg, MlpCore.sampleAt, decodeInput, Input8.getInt8Nat, Input8.getNat]

private theorem encodeInputReg_sampleAt2 {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (t : Nat) :
    encodeInputReg (MlpCore.sampleAt start in0 in1 in2 in3 t).inputs 2 = in2.atTime t := by
  simp [encodeInputReg, MlpCore.sampleAt, decodeInput, Input8.getInt8Nat, Input8.getNat]

private theorem encodeInputReg_sampleAt3 {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (t : Nat) :
    encodeInputReg (MlpCore.sampleAt start in0 in1 in2 in3 t).inputs 3 = in3.atTime t := by
  simp [encodeInputReg, MlpCore.sampleAt, decodeInput, Input8.getInt8Nat, Input8.getNat]

@[simp] private theorem encodeSampleInput_decodeInput (x : BitVec 8) :
    encodeSampleInput (decodeInput x) = x := by
  simp [encodeSampleInput, decodeInput]

private def mlpCoreOutputsOfEncodedState (state : MlpCoreState) : MlpCoreOutputs :=
  mlpCoreOutputsAt
    (phaseOf state)
    (hiddenIdxOf state)
    (inputIdxOf state)
    (inputReg0Of state)
    (inputReg1Of state)
    (inputReg2Of state)
    (inputReg3Of state)
    (hiddenReg0Of state)
    (hiddenReg1Of state)
    (hiddenReg2Of state)
    (hiddenReg3Of state)
    (hiddenReg4Of state)
    (hiddenReg5Of state)
    (hiddenReg6Of state)
    (hiddenReg7Of state)
    (accRegOf state)
    (outRegOf state)

@[simp] private theorem mlpCoreOutputsOfEncodedState_encodeState (s : State) :
    mlpCoreOutputsOfEncodedState (encodeState s) = mlpCoreOutputsOfState s := by
  cases s
  unfold mlpCoreOutputsOfEncodedState mlpCoreOutputsOfState phaseOf hiddenIdxOf inputIdxOf inputReg0Of inputReg1Of
    inputReg2Of inputReg3Of hiddenReg0Of hiddenReg1Of hiddenReg2Of hiddenReg3Of hiddenReg4Of hiddenReg5Of
    hiddenReg6Of hiddenReg7Of accRegOf outRegOf encodeState
  rfl

private theorem mlpCoreView_sample_of_core {dom : DomainConfig} (core : Signal dom MlpCoreState) (t : Nat) :
    (mlpCoreViewOfState
      (MlpCoreState.phase core)
      (MlpCoreState.hidden_idx core)
      (MlpCoreState.input_idx core)
      (MlpCoreState.input_reg0 core)
      (MlpCoreState.input_reg1 core)
      (MlpCoreState.input_reg2 core)
      (MlpCoreState.input_reg3 core)
      (MlpCoreState.hidden_reg0 core)
      (MlpCoreState.hidden_reg1 core)
      (MlpCoreState.hidden_reg2 core)
      (MlpCoreState.hidden_reg3 core)
      (MlpCoreState.hidden_reg4 core)
      (MlpCoreState.hidden_reg5 core)
      (MlpCoreState.hidden_reg6 core)
      (MlpCoreState.hidden_reg7 core)
      (MlpCoreState.acc_reg core)
      (MlpCoreState.out_reg core)).sample t =
        mlpCoreOutputsOfEncodedState (core.atTime t) := by
  simpa [mlpCoreOutputsOfEncodedState] using
    mlpCoreViewOfState_sample
      (MlpCoreState.phase core)
      (MlpCoreState.hidden_idx core)
      (MlpCoreState.input_idx core)
      (MlpCoreState.input_reg0 core)
      (MlpCoreState.input_reg1 core)
      (MlpCoreState.input_reg2 core)
      (MlpCoreState.input_reg3 core)
      (MlpCoreState.hidden_reg0 core)
      (MlpCoreState.hidden_reg1 core)
      (MlpCoreState.hidden_reg2 core)
      (MlpCoreState.hidden_reg3 core)
      (MlpCoreState.hidden_reg4 core)
      (MlpCoreState.hidden_reg5 core)
      (MlpCoreState.hidden_reg6 core)
      (MlpCoreState.hidden_reg7 core)
      (MlpCoreState.acc_reg core)
      (MlpCoreState.out_reg core)
      t

theorem packMlpCoreStateSignal_refines_state {dom : DomainConfig}
    (core : Signal dom MlpCoreState) (s : State) (t : Nat)
    (hcore : core.atTime t = encodeState s) :
    (packMlpCoreStateSignal core).atTime t =
      packMlpCoreOutputsBundle (mlpCoreOutputsOfState s) := by
  calc
    (packMlpCoreStateSignal core).atTime t =
      packMlpCoreOutputsBundle (mlpCoreOutputsOfEncodedState (core.atTime t)) := by
        calc
          (packMlpCoreStateSignal core).atTime t =
            (packMlpCoreView
              (mlpCoreViewOfState
                (MlpCoreState.phase core)
                (MlpCoreState.hidden_idx core)
                (MlpCoreState.input_idx core)
                (MlpCoreState.input_reg0 core)
                (MlpCoreState.input_reg1 core)
                (MlpCoreState.input_reg2 core)
                (MlpCoreState.input_reg3 core)
                (MlpCoreState.hidden_reg0 core)
                (MlpCoreState.hidden_reg1 core)
                (MlpCoreState.hidden_reg2 core)
                (MlpCoreState.hidden_reg3 core)
                (MlpCoreState.hidden_reg4 core)
                (MlpCoreState.hidden_reg5 core)
                (MlpCoreState.hidden_reg6 core)
                (MlpCoreState.hidden_reg7 core)
                (MlpCoreState.acc_reg core)
                (MlpCoreState.out_reg core))).atTime t := by
                  simp [packMlpCoreStateSignal, packMlpCoreState_eq_packMlpCoreView]
          _ =
            packMlpCoreOutputsBundle
              ((mlpCoreViewOfState
                (MlpCoreState.phase core)
                (MlpCoreState.hidden_idx core)
                (MlpCoreState.input_idx core)
                (MlpCoreState.input_reg0 core)
                (MlpCoreState.input_reg1 core)
                (MlpCoreState.input_reg2 core)
                (MlpCoreState.input_reg3 core)
                (MlpCoreState.hidden_reg0 core)
                (MlpCoreState.hidden_reg1 core)
                (MlpCoreState.hidden_reg2 core)
                (MlpCoreState.hidden_reg3 core)
                (MlpCoreState.hidden_reg4 core)
                (MlpCoreState.hidden_reg5 core)
                (MlpCoreState.hidden_reg6 core)
                (MlpCoreState.hidden_reg7 core)
                (MlpCoreState.acc_reg core)
                (MlpCoreState.out_reg core)).sample t) := by
                  simpa using
                    packMlpCoreView_sample_bundle
                      (view :=
                        mlpCoreViewOfState
                          (MlpCoreState.phase core)
                          (MlpCoreState.hidden_idx core)
                          (MlpCoreState.input_idx core)
                          (MlpCoreState.input_reg0 core)
                          (MlpCoreState.input_reg1 core)
                          (MlpCoreState.input_reg2 core)
                          (MlpCoreState.input_reg3 core)
                          (MlpCoreState.hidden_reg0 core)
                          (MlpCoreState.hidden_reg1 core)
                          (MlpCoreState.hidden_reg2 core)
                          (MlpCoreState.hidden_reg3 core)
                          (MlpCoreState.hidden_reg4 core)
                          (MlpCoreState.hidden_reg5 core)
                          (MlpCoreState.hidden_reg6 core)
                          (MlpCoreState.hidden_reg7 core)
                          (MlpCoreState.acc_reg core)
                          (MlpCoreState.out_reg core))
                      t
          _ = packMlpCoreOutputsBundle (mlpCoreOutputsOfEncodedState (core.atTime t)) := by
                rw [mlpCoreView_sample_of_core]
    _ = packMlpCoreOutputsBundle (mlpCoreOutputsOfEncodedState (encodeState s)) := by
      rw [hcore]
    _ = packMlpCoreOutputsBundle (mlpCoreOutputsOfState s) := by
      simp

theorem packEncodedMlpCoreState_refines_state (s : State) :
    packEncodedMlpCoreState (encodeState s) =
      packMlpCoreOutputsBundle (mlpCoreOutputsOfState s) := by
  calc
    packEncodedMlpCoreState (encodeState s) =
      (packMlpCoreStateSignal (Signal.pure (dom := defaultDomain) (encodeState s))).atTime 0 := by
        rfl
    _ = packMlpCoreOutputsBundle (mlpCoreOutputsOfState s) := by
      simpa using
        packMlpCoreStateSignal_refines_state
          (core := Signal.pure (dom := defaultDomain) (encodeState s))
          (s := s)
          (t := 0)
          rfl

theorem packMlpCoreStateBitsSignal_refines_state {dom : DomainConfig}
    (core : Signal dom MlpCoreState) (s : State) (t : Nat)
    (hcore : core.atTime t = encodeState s) :
    (packMlpCoreStateBitsSignal core).atTime t =
      packMlpCoreOutputsBits (mlpCoreOutputsOfState s) := by
  calc
    (packMlpCoreStateBitsSignal core).atTime t =
      packMlpCorePackedBits ((packMlpCoreStateSignal core).atTime t) := by
        rfl
    _ = packMlpCorePackedBits (packMlpCoreOutputsBundle (mlpCoreOutputsOfState s)) := by
      rw [packMlpCoreStateSignal_refines_state (core := core) (s := s) (t := t) hcore]
    _ = packMlpCoreOutputsBits (mlpCoreOutputsOfState s) := by
      rfl

theorem packEncodedMlpCoreStateBits_refines_state (s : State) :
    packMlpCorePackedBits (packEncodedMlpCoreState (encodeState s)) =
      packMlpCoreOutputsBits (mlpCoreOutputsOfState s) := by
  rw [packEncodedMlpCoreState_refines_state (s := s)]
  rfl

@[simp] private theorem bundle2_atTime_fst {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    ((bundle2 a b).atTime t).fst = a.atTime t := by
  rfl

@[simp] private theorem bundle2_atTime {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    (bundle2 a b).atTime t = (a.atTime t, b.atTime t) := by
  rfl

@[simp] private theorem bundle2_atTime_snd {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    ((bundle2 a b).atTime t).snd = b.atTime t := by
  rfl

@[simp] private theorem pairSignal_atTime_fst {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    ((((fun x1 x2 => (x1, x2)) <$> a <*> b).atTime t).fst) = a.atTime t := by
  rfl

@[simp] private theorem pairSignal_atTime {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    (((fun x1 x2 => (x1, x2)) <$> a <*> b).atTime t) = (a.atTime t, b.atTime t) := by
  rfl

@[simp] private theorem pairSignal_atTime_snd {dom : DomainConfig} {α β : Type}
    (a : Signal dom α) (b : Signal dom β) (t : Nat) :
    ((((fun x1 x2 => (x1, x2)) <$> a <*> b).atTime t).snd) = b.atTime t := by
  rfl

private theorem signal_ext {dom : DomainConfig} {α : Type}
    {a b : Signal dom α} (h : ∀ t : Nat, a.atTime t = b.atTime t) :
    a = b := by
  cases a with
  | mk aval =>
      cases b with
      | mk bval =>
          have hfun : aval = bval := by
            funext t
            exact h t
          cases hfun
          rfl

private theorem nextState_atTime_eq_pure {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (state : Signal dom MlpCoreState)
    (t : Nat) :
    (MlpCore.nextState start in0 in1 in2 in3 state).atTime t =
      (MlpCore.nextState
        (Signal.pure (dom := dom) (start.atTime t))
        (Signal.pure (dom := dom) (in0.atTime t))
        (Signal.pure (dom := dom) (in1.atTime t))
        (Signal.pure (dom := dom) (in2.atTime t))
        (Signal.pure (dom := dom) (in3.atTime t))
        (Signal.pure (dom := dom) (state.atTime t))).atTime 0 := by
  cases start
  cases in0
  cases in1
  cases in2
  cases in3
  cases state
  rfl

private theorem packMlpCoreStateSignal_atTime {dom : DomainConfig}
    (core : Signal dom MlpCoreState)
    (t : Nat) :
    (packMlpCoreStateSignal core).atTime t =
      packEncodedMlpCoreState (core.atTime t) := by
  cases core
  rfl

private theorem body_at_zero {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (state : Signal dom MlpCoreState) :
    (MlpCore.body start in0 in1 in2 in3 state).atTime 0 = encodeState idleState := by
  rfl

private theorem sparkleMlpCoreStateSynth_unfold {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8)) :
    sparkleMlpCoreStateSynth start in0 in1 in2 in3 =
      MlpCore.body start in0 in1 in2 in3
        (sparkleMlpCoreStateSynth start in0 in1 in2 in3) := by
  simpa [sparkleMlpCoreStateSynth] using
    (Signal.loop_unfold (MlpCore.body start in0 in1 in2 in3))

/--
Remaining local trust bridge: the pure next-state network over encoded Sparkle
state matches the checked-in `timedStep` semantics on invariant states.
-/
private axiom nextState_pure_eq_timedStep {dom : DomainConfig}
    (sample : CtrlSample) (s : State) :
    (MlpCore.nextState
      (Signal.pure (dom := dom) sample.start)
      (Signal.pure (dom := dom) (encodeSampleInput sample.inputs.x0))
      (Signal.pure (dom := dom) (encodeSampleInput sample.inputs.x1))
      (Signal.pure (dom := dom) (encodeSampleInput sample.inputs.x2))
      (Signal.pure (dom := dom) (encodeSampleInput sample.inputs.x3))
      (Signal.pure (dom := dom) (encodeState s))).atTime 0 =
        encodeState (timedStep sample s)

theorem packMlpCoreStateBitsSynth_atTime {dom : DomainConfig}
    (core : Signal dom MlpCoreState)
    (t : Nat) :
    (packMlpCoreStateBitsSynth core).atTime t =
      (packMlpCoreStateBitsSignal core).atTime t := by
  cases core
  rfl

theorem sparkleMlpCoreState_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (sparkleMlpCoreState
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).atTime t =
        encodeState (rtlTrace samples t) := by
  simpa [sparkleMlpCoreState] using
    congrArg encodeState (sparkleMlpCoreTrace_refines_rtlTrace (dom := dom) samples t)

theorem sparkleMlpCoreStateSynth_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (sparkleMlpCoreStateSynth
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).atTime t =
        encodeState (rtlTrace samples t) := by
  induction t with
  | zero =>
      calc
        (sparkleMlpCoreStateSynth
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples)).atTime 0 =
            (MlpCore.body
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples)
              (sparkleMlpCoreStateSynth
                (startSignal (dom := dom) samples)
                (input0Signal (dom := dom) samples)
                (input1Signal (dom := dom) samples)
                (input2Signal (dom := dom) samples)
                (input3Signal (dom := dom) samples))).atTime 0 := by
                  simpa using congrArg
                    (fun s => s.atTime 0)
                    (sparkleMlpCoreStateSynth_unfold
                      (dom := dom)
                      (startSignal (dom := dom) samples)
                      (input0Signal (dom := dom) samples)
                      (input1Signal (dom := dom) samples)
                      (input2Signal (dom := dom) samples)
                      (input3Signal (dom := dom) samples))
        _ = encodeState idleState := by
          simpa using body_at_zero
            (startSignal (dom := dom) samples)
            (input0Signal (dom := dom) samples)
            (input1Signal (dom := dom) samples)
            (input2Signal (dom := dom) samples)
            (input3Signal (dom := dom) samples)
            (sparkleMlpCoreStateSynth
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples))
        _ = encodeState (rtlTrace samples 0) := by
          simp [rtlTrace]
  | succ n ih =>
      calc
        (sparkleMlpCoreStateSynth
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples)).atTime (n + 1) =
            (MlpCore.body
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples)
              (sparkleMlpCoreStateSynth
                (startSignal (dom := dom) samples)
                (input0Signal (dom := dom) samples)
                (input1Signal (dom := dom) samples)
                (input2Signal (dom := dom) samples)
                (input3Signal (dom := dom) samples))).atTime (n + 1) := by
                  simpa using congrArg
                    (fun s => s.atTime (n + 1))
                    (sparkleMlpCoreStateSynth_unfold
                      (dom := dom)
                      (startSignal (dom := dom) samples)
                      (input0Signal (dom := dom) samples)
                      (input1Signal (dom := dom) samples)
                      (input2Signal (dom := dom) samples)
                      (input3Signal (dom := dom) samples))
        _ =
            (MlpCore.nextState
              (Signal.pure (dom := dom) (samples n).start)
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x0))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x1))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x2))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x3))
              (Signal.pure (dom := dom)
                ((sparkleMlpCoreStateSynth
                  (startSignal (dom := dom) samples)
                  (input0Signal (dom := dom) samples)
                  (input1Signal (dom := dom) samples)
                  (input2Signal (dom := dom) samples)
                  (input3Signal (dom := dom) samples)).atTime n))).atTime 0 := by
                    simpa [MlpCore.body, MlpCore.registerState] using
                      nextState_atTime_eq_pure
                        (startSignal (dom := dom) samples)
                        (input0Signal (dom := dom) samples)
                        (input1Signal (dom := dom) samples)
                        (input2Signal (dom := dom) samples)
                        (input3Signal (dom := dom) samples)
                        (sparkleMlpCoreStateSynth
                          (startSignal (dom := dom) samples)
                          (input0Signal (dom := dom) samples)
                          (input1Signal (dom := dom) samples)
                          (input2Signal (dom := dom) samples)
                          (input3Signal (dom := dom) samples))
                        n
        _ =
            (MlpCore.nextState
              (Signal.pure (dom := dom) (samples n).start)
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x0))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x1))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x2))
              (Signal.pure (dom := dom) (encodeSampleInput (samples n).inputs.x3))
              (Signal.pure (dom := dom) (encodeState (rtlTrace samples n)))).atTime 0 := by
                rw [ih]
        _ = encodeState (timedStep (samples n) (rtlTrace samples n)) := by
          simpa using nextState_pure_eq_timedStep (dom := dom) (samples n) (rtlTrace samples n)
        _ = encodeState (rtlTrace samples (n + 1)) := by
          simp [rtlTrace]

theorem sparkleMlpCoreNextStateSynth_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (MlpCore.nextState
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)
      (sparkleMlpCoreStateSynth
        (startSignal (dom := dom) samples)
        (input0Signal (dom := dom) samples)
        (input1Signal (dom := dom) samples)
        (input2Signal (dom := dom) samples)
        (input3Signal (dom := dom) samples))).atTime t =
        encodeState (rtlTrace samples (t + 1)) := by
  calc
    (MlpCore.nextState
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)
      (sparkleMlpCoreStateSynth
        (startSignal (dom := dom) samples)
        (input0Signal (dom := dom) samples)
        (input1Signal (dom := dom) samples)
        (input2Signal (dom := dom) samples)
        (input3Signal (dom := dom) samples))).atTime t =
        (MlpCore.nextState
          (Signal.pure (dom := dom) (samples t).start)
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x0))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x1))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x2))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x3))
          (Signal.pure (dom := dom)
            ((sparkleMlpCoreStateSynth
              (startSignal (dom := dom) samples)
              (input0Signal (dom := dom) samples)
              (input1Signal (dom := dom) samples)
              (input2Signal (dom := dom) samples)
              (input3Signal (dom := dom) samples)).atTime t))).atTime 0 := by
                simpa using
                  nextState_atTime_eq_pure
                    (startSignal (dom := dom) samples)
                    (input0Signal (dom := dom) samples)
                    (input1Signal (dom := dom) samples)
                    (input2Signal (dom := dom) samples)
                    (input3Signal (dom := dom) samples)
                    (sparkleMlpCoreStateSynth
                      (startSignal (dom := dom) samples)
                      (input0Signal (dom := dom) samples)
                      (input1Signal (dom := dom) samples)
                      (input2Signal (dom := dom) samples)
                      (input3Signal (dom := dom) samples))
                    t
    _ =
        (MlpCore.nextState
          (Signal.pure (dom := dom) (samples t).start)
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x0))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x1))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x2))
          (Signal.pure (dom := dom) (encodeSampleInput (samples t).inputs.x3))
          (Signal.pure (dom := dom) (encodeState (rtlTrace samples t)))).atTime 0 := by
            rw [sparkleMlpCoreStateSynth_refines_rtlTrace (dom := dom) samples t]
    _ = encodeState (timedStep (samples t) (rtlTrace samples t)) := by
      simpa using nextState_pure_eq_timedStep (dom := dom) (samples t) (rtlTrace samples t)
    _ = encodeState (rtlTrace samples (t + 1)) := by
      simp [rtlTrace]

theorem sparkleMlpCoreView_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (sparkleMlpCoreView
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).sample t =
        mlpCoreOutputsOfState (rtlTrace samples t) := by
  let core := sparkleMlpCoreState
    (startSignal (dom := dom) samples)
    (input0Signal (dom := dom) samples)
    (input1Signal (dom := dom) samples)
    (input2Signal (dom := dom) samples)
    (input3Signal (dom := dom) samples)
  have hcore : core.atTime t = encodeState (rtlTrace samples t) := by
    simpa [core] using sparkleMlpCoreState_refines_rtlTrace (dom := dom) samples t
  calc
    (sparkleMlpCoreView
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).sample t =
        mlpCoreOutputsOfEncodedState (core.atTime t) := by
          simpa [sparkleMlpCoreView, core] using mlpCoreView_sample_of_core (dom := dom) core t
    _ = mlpCoreOutputsOfEncodedState (encodeState (rtlTrace samples t)) := by
      rw [hcore]
    _ = mlpCoreOutputsOfState (rtlTrace samples t) := by
      simp

theorem sparkleMlpCoreViewSynth_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (sparkleMlpCoreViewSynth
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).sample t =
        mlpCoreOutputsOfState (rtlTrace samples t) := by
  let core := sparkleMlpCoreStateSynth
    (startSignal (dom := dom) samples)
    (input0Signal (dom := dom) samples)
    (input1Signal (dom := dom) samples)
    (input2Signal (dom := dom) samples)
    (input3Signal (dom := dom) samples)
  have hcore : core.atTime t = encodeState (rtlTrace samples t) := by
    simpa [core] using sparkleMlpCoreStateSynth_refines_rtlTrace (dom := dom) samples t
  calc
    (sparkleMlpCoreViewSynth
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).sample t =
        mlpCoreOutputsOfEncodedState (core.atTime t) := by
          simpa [sparkleMlpCoreViewSynth, core] using mlpCoreView_sample_of_core (dom := dom) core t
    _ = mlpCoreOutputsOfEncodedState (encodeState (rtlTrace samples t)) := by
      rw [hcore]
    _ = mlpCoreOutputsOfState (rtlTrace samples t) := by
      simp

theorem canonicalMlpCoreView_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (canonicalMlpCoreView (dom := dom) samples).sample t =
      mlpCoreOutputsOfState (rtlTrace samples t) := by
  calc
    (canonicalMlpCoreView (dom := dom) samples).sample t =
        mlpCoreOutputsAt
          ((rtlPhaseSignal (dom := dom) samples).atTime t)
          ((rtlHiddenIdxSignal (dom := dom) samples).atTime t)
          ((rtlInputIdxSignal (dom := dom) samples).atTime t)
          ((rtlInputReg0Signal (dom := dom) samples).atTime t)
          ((rtlInputReg1Signal (dom := dom) samples).atTime t)
          ((rtlInputReg2Signal (dom := dom) samples).atTime t)
          ((rtlInputReg3Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg0Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg1Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg2Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg3Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg4Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg5Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg6Signal (dom := dom) samples).atTime t)
          ((rtlHiddenReg7Signal (dom := dom) samples).atTime t)
          ((rtlAccRegSignal (dom := dom) samples).atTime t)
          ((rtlOutRegSignal (dom := dom) samples).atTime t) := by
      simpa [canonicalMlpCoreView] using
        mlpCoreViewOfState_sample
          (rtlPhaseSignal (dom := dom) samples)
          (rtlHiddenIdxSignal (dom := dom) samples)
          (rtlInputIdxSignal (dom := dom) samples)
          (rtlInputReg0Signal (dom := dom) samples)
          (rtlInputReg1Signal (dom := dom) samples)
          (rtlInputReg2Signal (dom := dom) samples)
          (rtlInputReg3Signal (dom := dom) samples)
          (rtlHiddenReg0Signal (dom := dom) samples)
          (rtlHiddenReg1Signal (dom := dom) samples)
          (rtlHiddenReg2Signal (dom := dom) samples)
          (rtlHiddenReg3Signal (dom := dom) samples)
          (rtlHiddenReg4Signal (dom := dom) samples)
          (rtlHiddenReg5Signal (dom := dom) samples)
          (rtlHiddenReg6Signal (dom := dom) samples)
          (rtlHiddenReg7Signal (dom := dom) samples)
          (rtlAccRegSignal (dom := dom) samples)
          (rtlOutRegSignal (dom := dom) samples)
          t
    _ = mlpCoreOutputsOfState (rtlTrace samples t) := by
      simp [mlpCoreOutputsOfState, rtlPhaseSignal, rtlHiddenIdxSignal, rtlInputIdxSignal,
        rtlInputReg0Signal, rtlInputReg1Signal, rtlInputReg2Signal, rtlInputReg3Signal,
        rtlHiddenReg0Signal, rtlHiddenReg1Signal, rtlHiddenReg2Signal, rtlHiddenReg3Signal,
        rtlHiddenReg4Signal, rtlHiddenReg5Signal, rtlHiddenReg6Signal, rtlHiddenReg7Signal,
        rtlAccRegSignal, rtlOutRegSignal, Signal.atTime]

end MlpCore.Sparkle
