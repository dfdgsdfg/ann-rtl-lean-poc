import Sparkle.Core.Domain
import Sparkle.Core.Signal
import Sparkle.Core.StateMacro
import TinyMLP.Temporal
import TinyMLPSparkle.Types
import TinyMLPSparkle.ControllerSignal
import TinyMLPSparkle.ContractData
import TinyMLPSparkle.DatapathSignal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

declare_signal_state MlpCoreState
  | phase : BitVec 4 := 0#4
  | hidden_idx : BitVec 4 := 0#4
  | input_idx  : BitVec 4 := 0#4
  | input_reg0 : BitVec 8 := 0#8
  | input_reg1 : BitVec 8 := 0#8
  | input_reg2 : BitVec 8 := 0#8
  | input_reg3 : BitVec 8 := 0#8
  | hidden_reg0 : BitVec 16 := 0#16
  | hidden_reg1 : BitVec 16 := 0#16
  | hidden_reg2 : BitVec 16 := 0#16
  | hidden_reg3 : BitVec 16 := 0#16
  | hidden_reg4 : BitVec 16 := 0#16
  | hidden_reg5 : BitVec 16 := 0#16
  | hidden_reg6 : BitVec 16 := 0#16
  | hidden_reg7 : BitVec 16 := 0#16
  | acc_reg : BitVec 32 := 0#32
  | out_reg : Bool := false

private def inputCount4b : BitVec 4 := BitVec.ofNat 4 4
private def hiddenCount4b : BitVec 4 := BitVec.ofNat 4 8
private def lastHiddenIdx4b : BitVec 4 := BitVec.ofNat 4 7

private def falseS {dom : DomainConfig} : Signal dom Bool := Signal.pure false
private def zero4S {dom : DomainConfig} : Signal dom (BitVec 4) := Signal.pure 0#4
private def four4S {dom : DomainConfig} : Signal dom (BitVec 4) := Signal.pure inputCount4b
private def eight4S {dom : DomainConfig} : Signal dom (BitVec 4) := Signal.pure hiddenCount4b
private def one4S {dom : DomainConfig} : Signal dom (BitVec 4) := Signal.pure 1#4
private def zero16S {dom : DomainConfig} : Signal dom (BitVec 16) := Signal.pure 0#16
private def zero32S {dom : DomainConfig} : Signal dom (BitVec 32) := Signal.pure 0#32

private def encodeInputReg (input : Input8) (idx : Nat) : BitVec 8 :=
  BitVec.ofInt 8 (input.getInt8Nat idx).toInt

private def encodeHiddenReg (hidden : Hidden16) (idx : Nat) : BitVec 16 :=
  BitVec.ofInt 16 (hidden.getCellNat idx).toInt

private def encodeAccReg (acc : Acc32) : BitVec 32 :=
  BitVec.ofInt 32 acc.toInt

def decodeInput (x : BitVec 8) : Int8 :=
  Int8.ofInt x.toInt

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

private def encodeState (s : State) : MlpCoreState :=
  (encodePhase s.phase,
    (BitVec.ofNat stateWidth s.hiddenIdx,
      (BitVec.ofNat stateWidth s.inputIdx,
        (encodeInputReg s.regs 0,
          (encodeInputReg s.regs 1,
            (encodeInputReg s.regs 2,
              (encodeInputReg s.regs 3,
                (encodeHiddenReg s.hidden 0,
                  (encodeHiddenReg s.hidden 1,
                    (encodeHiddenReg s.hidden 2,
                      (encodeHiddenReg s.hidden 3,
                        (encodeHiddenReg s.hidden 4,
                          (encodeHiddenReg s.hidden 5,
                            (encodeHiddenReg s.hidden 6,
                              (encodeHiddenReg s.hidden 7,
                                (encodeAccReg s.accumulator, s.output))))))))))))))))

namespace MlpCore

def sampleAt {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (t : Nat) : CtrlSample :=
  { start := start.atTime t
  , inputs :=
      { x0 := decodeInput (in0.atTime t)
      , x1 := decodeInput (in1.atTime t)
      , x2 := decodeInput (in2.atTime t)
      , x3 := decodeInput (in3.atTime t)
      }
  }

def trace {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8)) : Nat → State :=
  rtlTrace (sampleAt start in0 in1 in2 in3)

def loop {dom : DomainConfig}
    (_start : Signal dom Bool)
    (_in0 : Signal dom (BitVec 8))
    (_in1 : Signal dom (BitVec 8))
    (_in2 : Signal dom (BitVec 8))
    (_in3 : Signal dom (BitVec 8))
    (_body : Signal dom MlpCoreState → Signal dom MlpCoreState) : Signal dom MlpCoreState :=
  Signal.loop _body

def body {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8))
    (state : Signal dom MlpCoreState) : Signal dom MlpCoreState :=
  let phase := MlpCoreState.phase state
  let hidden_idx := MlpCoreState.hidden_idx state
  let input_idx := MlpCoreState.input_idx state
  let input_reg0 := MlpCoreState.input_reg0 state
  let input_reg1 := MlpCoreState.input_reg1 state
  let input_reg2 := MlpCoreState.input_reg2 state
  let input_reg3 := MlpCoreState.input_reg3 state
  let hidden_reg0 := MlpCoreState.hidden_reg0 state
  let hidden_reg1 := MlpCoreState.hidden_reg1 state
  let hidden_reg2 := MlpCoreState.hidden_reg2 state
  let hidden_reg3 := MlpCoreState.hidden_reg3 state
  let hidden_reg4 := MlpCoreState.hidden_reg4 state
  let hidden_reg5 := MlpCoreState.hidden_reg5 state
  let hidden_reg6 := MlpCoreState.hidden_reg6 state
  let hidden_reg7 := MlpCoreState.hidden_reg7 state
  let acc_reg := MlpCoreState.acc_reg state
  let out_reg := MlpCoreState.out_reg state

  let zero4 : Signal dom (BitVec 4) := zero4S
  let eight4 : Signal dom (BitVec 4) := eight4S
  let one4 : Signal dom (BitVec 4) := one4S
  let zero16 : Signal dom (BitVec 16) := zero16S
  let zero32 : Signal dom (BitVec 32) := zero32S
  let falseSig : Signal dom Bool := falseS

  let isIdle := phase === (stIdle : Signal dom _)
  let load_input := phase === (stLoadInput : Signal dom _)
  let do_mac_hidden := (phase === (stMacHidden : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let do_bias_hidden := phase === (stBiasHidden : Signal dom _)
  let do_act_hidden := phase === (stActHidden : Signal dom _)
  let advance_hidden := phase === (stNextHidden : Signal dom _)
  let do_mac_output := (phase === (stMacOutput : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
  let do_bias_output := phase === (stBiasOutput : Signal dom _)
  let notStart := (fun value => !value) <$> start
  let idleCleanup := isIdle &&& notStart
  let hiddenIsLast := hidden_idx === (Signal.pure lastHiddenIdx4b)
  let anyMac := (· || ·) <$> do_mac_hidden <*> do_mac_output

  let selectedInput := selectInputReg input_idx input_reg0 input_reg1 input_reg2 input_reg3
  let selectedHidden := selectHiddenReg
    input_idx
    hidden_reg0 hidden_reg1 hidden_reg2 hidden_reg3
    hidden_reg4 hidden_reg5 hidden_reg6 hidden_reg7

  let hiddenMacAccOut := acc_reg + hiddenMacTerm32 selectedInput (w1Data hidden_idx input_idx)
  let outputMacAccOut := acc_reg + outputMacTerm32 selectedHidden (w2Data input_idx)
  let biasHiddenAccOut := acc_reg + b1Data hidden_idx
  let biasOutputAccOut := acc_reg + (b2Data (dom := dom))
  let reluHidden := relu16 acc_reg

  let nextPhase := controllerPhaseNext
    start
    hidden_idx
    input_idx
    (Signal.pure inputCount4b)
    (Signal.pure hiddenCount4b)
    (Signal.pure lastHiddenIdx4b)
    phase

  let nextHiddenIdx := hw_cond hidden_idx
    | load_input => zero4
    | advance_hidden &&& hiddenIsLast => zero4
    | advance_hidden => hidden_idx + one4
    | do_bias_output => zero4
    | idleCleanup => zero4

  let nextInputIdx := hw_cond input_idx
    | load_input => zero4
    | anyMac => input_idx + one4
    | do_act_hidden => zero4
    | advance_hidden &&& hiddenIsLast => zero4
    | do_bias_output => eight4
    | idleCleanup => zero4

  let nextInputReg0 := hw_cond input_reg0
    | load_input => in0

  let nextInputReg1 := hw_cond input_reg1
    | load_input => in1

  let nextInputReg2 := hw_cond input_reg2
    | load_input => in2

  let nextInputReg3 := hw_cond input_reg3
    | load_input => in3

  let nextHiddenReg0 := hw_cond hidden_reg0
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 0#4 hidden_idx reluHidden hidden_reg0

  let nextHiddenReg1 := hw_cond hidden_reg1
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 1#4 hidden_idx reluHidden hidden_reg1

  let nextHiddenReg2 := hw_cond hidden_reg2
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 2#4 hidden_idx reluHidden hidden_reg2

  let nextHiddenReg3 := hw_cond hidden_reg3
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 3#4 hidden_idx reluHidden hidden_reg3

  let nextHiddenReg4 := hw_cond hidden_reg4
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 4#4 hidden_idx reluHidden hidden_reg4

  let nextHiddenReg5 := hw_cond hidden_reg5
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 5#4 hidden_idx reluHidden hidden_reg5

  let nextHiddenReg6 := hw_cond hidden_reg6
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 6#4 hidden_idx reluHidden hidden_reg6

  let nextHiddenReg7 := hw_cond hidden_reg7
    | load_input => zero16
    | do_act_hidden => updateHiddenReg 7#4 hidden_idx reluHidden hidden_reg7

  let nextAccReg := hw_cond acc_reg
    | load_input => zero32
    | do_mac_hidden => hiddenMacAccOut
    | do_mac_output => outputMacAccOut
    | do_bias_hidden => biasHiddenAccOut
    | do_act_hidden => zero32
    | do_bias_output => biasOutputAccOut

  let nextOutReg := hw_cond out_reg
    | load_input => falseSig
    | do_bias_output => gtZero32 biasOutputAccOut

  bundleAll! [
    Signal.register stIdle nextPhase,
    Signal.register 0#4 nextHiddenIdx,
    Signal.register 0#4 nextInputIdx,
    Signal.register 0#8 nextInputReg0,
    Signal.register 0#8 nextInputReg1,
    Signal.register 0#8 nextInputReg2,
    Signal.register 0#8 nextInputReg3,
    Signal.register 0#16 nextHiddenReg0,
    Signal.register 0#16 nextHiddenReg1,
    Signal.register 0#16 nextHiddenReg2,
    Signal.register 0#16 nextHiddenReg3,
    Signal.register 0#16 nextHiddenReg4,
    Signal.register 0#16 nextHiddenReg5,
    Signal.register 0#16 nextHiddenReg6,
    Signal.register 0#16 nextHiddenReg7,
    Signal.register 0#32 nextAccReg,
    Signal.register false nextOutReg
  ]

end MlpCore

structure MlpCoreView (dom : DomainConfig) where
  state : Signal dom (BitVec stateWidth)
  load_input : Signal dom Bool
  clear_acc : Signal dom Bool
  do_mac_hidden : Signal dom Bool
  do_bias_hidden : Signal dom Bool
  do_act_hidden : Signal dom Bool
  advance_hidden : Signal dom Bool
  do_mac_output : Signal dom Bool
  do_bias_output : Signal dom Bool
  done : Signal dom Bool
  busy : Signal dom Bool
  out_bit : Signal dom Bool
  hidden_idx : Signal dom (BitVec stateWidth)
  input_idx : Signal dom (BitVec stateWidth)
  acc_reg : Signal dom (BitVec 32)
  mac_acc_out : Signal dom (BitVec 32)
  mac_a : Signal dom (BitVec 16)
  b2_data : Signal dom (BitVec 32)
  input_reg0 : Signal dom (BitVec 8)
  input_reg1 : Signal dom (BitVec 8)
  input_reg2 : Signal dom (BitVec 8)
  input_reg3 : Signal dom (BitVec 8)
  hidden_reg0 : Signal dom (BitVec 16)
  hidden_reg1 : Signal dom (BitVec 16)
  hidden_reg2 : Signal dom (BitVec 16)
  hidden_reg3 : Signal dom (BitVec 16)
  hidden_reg4 : Signal dom (BitVec 16)
  hidden_reg5 : Signal dom (BitVec 16)
  hidden_reg6 : Signal dom (BitVec 16)
  hidden_reg7 : Signal dom (BitVec 16)
  hidden_input_case_hit : Signal dom Bool
  output_hidden_case_hit : Signal dom Bool
  hidden_weight_case_hit : Signal dom Bool
  output_weight_case_hit : Signal dom Bool

def mlpCoreViewOfState {dom : DomainConfig}
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
    (out_reg : Signal dom Bool) : MlpCoreView dom :=
  let controller := controllerViewOfState
    state
    input_idx
    (Signal.pure inputCount4b)
    (Signal.pure hiddenCount4b)
  let isMacOutput := state === (stMacOutput : Signal dom _)
  let hidden_input_case_hit := ((fun value => !value) <$> isMacOutput) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let output_hidden_case_hit := isMacOutput &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
  let hidden_weight_case_hit := ((BitVec.ult · ·) <$> hidden_idx <*> (Signal.pure hiddenCount4b)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let output_weight_case_hit := (BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b)
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
  let hiddenMacAccOut := acc_reg + hiddenMacTerm32 selectedInput (w1Data hidden_idx input_idx)
  let outputMacAccOut := acc_reg + outputMacTerm32 selectedHidden (w2Data input_idx)
  let mac_acc_out := Signal.mux isMacOutput outputMacAccOut hiddenMacAccOut
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
  , mac_acc_out
  , mac_a
  , b2_data := b2Data (dom := dom)
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

def packMlpCoreView {dom : DomainConfig} (view : MlpCoreView dom) :=
  bundleAll! [
    view.state,
    view.load_input,
    view.clear_acc,
    view.do_mac_hidden,
    view.do_bias_hidden,
    view.do_act_hidden,
    view.advance_hidden,
    view.do_mac_output,
    view.do_bias_output,
    view.done,
    view.busy,
    view.out_bit,
    view.hidden_idx,
    view.input_idx,
    view.acc_reg,
    view.mac_acc_out,
    view.mac_a,
    view.b2_data,
    view.input_reg0,
    view.input_reg1,
    view.input_reg2,
    view.input_reg3,
    view.hidden_reg0,
    view.hidden_reg1,
    view.hidden_reg2,
    view.hidden_reg3,
    view.hidden_reg4,
    view.hidden_reg5,
    view.hidden_reg6,
    view.hidden_reg7,
    view.hidden_input_case_hit,
    view.output_hidden_case_hit,
    view.hidden_weight_case_hit,
    view.output_weight_case_hit
  ]

private def packMlpCoreState {dom : DomainConfig}
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
    (out_reg : Signal dom Bool) :=
  let isIdle := state === (stIdle : Signal dom _)
  let load_input := state === (stLoadInput : Signal dom _)
  let clear_acc := load_input
  let do_mac_hidden := (state === (stMacHidden : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let do_bias_hidden := state === (stBiasHidden : Signal dom _)
  let do_act_hidden := state === (stActHidden : Signal dom _)
  let advance_hidden := state === (stNextHidden : Signal dom _)
  let do_mac_output := (state === (stMacOutput : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
  let do_bias_output := state === (stBiasOutput : Signal dom _)
  let done := state === (stDone : Signal dom _)
  let busy := ((fun value => !value) <$> isIdle) &&& ((fun value => !value) <$> done)
  let isMacOutput := state === (stMacOutput : Signal dom _)
  let hidden_input_case_hit := ((fun value => !value) <$> isMacOutput) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let output_hidden_case_hit := isMacOutput &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
  let hidden_weight_case_hit := ((BitVec.ult · ·) <$> hidden_idx <*> (Signal.pure hiddenCount4b)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let output_weight_case_hit := (BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b)
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
  let hiddenMacAccOut := acc_reg + hiddenMacTerm32 selectedInput (w1Data hidden_idx input_idx)
  let outputMacAccOut := acc_reg + outputMacTerm32 selectedHidden (w2Data input_idx)
  let mac_acc_out := Signal.mux isMacOutput outputMacAccOut hiddenMacAccOut
  bundleAll! [
    state,
    load_input,
    clear_acc,
    do_mac_hidden,
    do_bias_hidden,
    do_act_hidden,
    advance_hidden,
    do_mac_output,
    do_bias_output,
    done,
    busy,
    out_reg,
    hidden_idx,
    input_idx,
    acc_reg,
    mac_acc_out,
    mac_a,
    b2Data (dom := dom),
    input_reg0,
    input_reg1,
    input_reg2,
    input_reg3,
    hidden_reg0,
    hidden_reg1,
    hidden_reg2,
    hidden_reg3,
    hidden_reg4,
    hidden_reg5,
    hidden_reg6,
    hidden_reg7,
    hidden_input_case_hit,
    output_hidden_case_hit,
    hidden_weight_case_hit,
    output_weight_case_hit
  ]

def sparkleMlpCoreView {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8)) : MlpCoreView dom :=
  let core := MlpCore.loop start in0 in1 in2 in3 (MlpCore.body start in0 in1 in2 in3)
  let phase := MlpCoreState.phase core
  let hidden_idx := MlpCoreState.hidden_idx core
  let input_idx := MlpCoreState.input_idx core
  let input_reg0 := MlpCoreState.input_reg0 core
  let input_reg1 := MlpCoreState.input_reg1 core
  let input_reg2 := MlpCoreState.input_reg2 core
  let input_reg3 := MlpCoreState.input_reg3 core
  let hidden_reg0 := MlpCoreState.hidden_reg0 core
  let hidden_reg1 := MlpCoreState.hidden_reg1 core
  let hidden_reg2 := MlpCoreState.hidden_reg2 core
  let hidden_reg3 := MlpCoreState.hidden_reg3 core
  let hidden_reg4 := MlpCoreState.hidden_reg4 core
  let hidden_reg5 := MlpCoreState.hidden_reg5 core
  let hidden_reg6 := MlpCoreState.hidden_reg6 core
  let hidden_reg7 := MlpCoreState.hidden_reg7 core
  let acc_reg := MlpCoreState.acc_reg core
  let out_reg := MlpCoreState.out_reg core
  mlpCoreViewOfState
    phase
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
    out_reg

def sparkleMlpCorePacked {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8)) :=
  let core := MlpCore.loop start in0 in1 in2 in3 (MlpCore.body start in0 in1 in2 in3)
  let phase := MlpCoreState.phase core
  let hidden_idx := MlpCoreState.hidden_idx core
  let input_idx := MlpCoreState.input_idx core
  let input_reg0 := MlpCoreState.input_reg0 core
  let input_reg1 := MlpCoreState.input_reg1 core
  let input_reg2 := MlpCoreState.input_reg2 core
  let input_reg3 := MlpCoreState.input_reg3 core
  let hidden_reg0 := MlpCoreState.hidden_reg0 core
  let hidden_reg1 := MlpCoreState.hidden_reg1 core
  let hidden_reg2 := MlpCoreState.hidden_reg2 core
  let hidden_reg3 := MlpCoreState.hidden_reg3 core
  let hidden_reg4 := MlpCoreState.hidden_reg4 core
  let hidden_reg5 := MlpCoreState.hidden_reg5 core
  let hidden_reg6 := MlpCoreState.hidden_reg6 core
  let hidden_reg7 := MlpCoreState.hidden_reg7 core
  let acc_reg := MlpCoreState.acc_reg core
  let out_reg := MlpCoreState.out_reg core
  packMlpCoreState
    phase
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
    out_reg

end TinyMLP.Sparkle
