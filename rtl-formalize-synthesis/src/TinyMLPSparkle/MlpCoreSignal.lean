import Sparkle.Core.Domain
import Sparkle.Core.Signal
import Sparkle.Core.StateMacro
import TinyMLPSparkle.Types
import TinyMLPSparkle.ControllerSignal
import TinyMLPSparkle.ContractData
import TinyMLPSparkle.DatapathSignal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

declare_signal_state MlpCoreState
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
private def zero8S {dom : DomainConfig} : Signal dom (BitVec 8) := Signal.pure 0#8
private def zero16S {dom : DomainConfig} : Signal dom (BitVec 16) := Signal.pure 0#16
private def zero32S {dom : DomainConfig} : Signal dom (BitVec 32) := Signal.pure 0#32

def sparkleMlpCorePacked {dom : DomainConfig}
    (start : Signal dom Bool)
    (in0 : Signal dom (BitVec 8))
    (in1 : Signal dom (BitVec 8))
    (in2 : Signal dom (BitVec 8))
    (in3 : Signal dom (BitVec 8)) :=
  let zero4 : Signal dom (BitVec 4) := zero4S
  let eight4 : Signal dom (BitVec 4) := eight4S
  let one4 : Signal dom (BitVec 4) := one4S
  let zero16 : Signal dom (BitVec 16) := zero16S
  let zero32 : Signal dom (BitVec 32) := zero32S
  let falseSig : Signal dom Bool := falseS
  let datapath := Signal.loop fun state =>
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

    let controllerState := sparkleControllerState
      start
      hidden_idx
      input_idx
      (Signal.pure inputCount4b)
      (Signal.pure hiddenCount4b)
      (Signal.pure lastHiddenIdx4b)

    let isIdle := controllerState === (stIdle : Signal dom _)
    let load_input := controllerState === (stLoadInput : Signal dom _)
    let do_mac_hidden := (controllerState === (stMacHidden : Signal dom _)) &&&
      ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
    let do_bias_hidden := controllerState === (stBiasHidden : Signal dom _)
    let do_act_hidden := controllerState === (stActHidden : Signal dom _)
    let advance_hidden := controllerState === (stNextHidden : Signal dom _)
    let do_mac_output := (controllerState === (stMacOutput : Signal dom _)) &&&
      ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
    let do_bias_output := controllerState === (stBiasOutput : Signal dom _)
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

  let hidden_idx := MlpCoreState.hidden_idx datapath
  let input_idx := MlpCoreState.input_idx datapath
  let input_reg0 := MlpCoreState.input_reg0 datapath
  let input_reg1 := MlpCoreState.input_reg1 datapath
  let input_reg2 := MlpCoreState.input_reg2 datapath
  let input_reg3 := MlpCoreState.input_reg3 datapath
  let hidden_reg0 := MlpCoreState.hidden_reg0 datapath
  let hidden_reg1 := MlpCoreState.hidden_reg1 datapath
  let hidden_reg2 := MlpCoreState.hidden_reg2 datapath
  let hidden_reg3 := MlpCoreState.hidden_reg3 datapath
  let hidden_reg4 := MlpCoreState.hidden_reg4 datapath
  let hidden_reg5 := MlpCoreState.hidden_reg5 datapath
  let hidden_reg6 := MlpCoreState.hidden_reg6 datapath
  let hidden_reg7 := MlpCoreState.hidden_reg7 datapath
  let acc_reg := MlpCoreState.acc_reg datapath
  let out_reg := MlpCoreState.out_reg datapath

  let controllerState := sparkleControllerState
    start
    hidden_idx
    input_idx
    (Signal.pure inputCount4b)
    (Signal.pure hiddenCount4b)
    (Signal.pure lastHiddenIdx4b)
  let isIdle := controllerState === (stIdle : Signal dom _)
  let load_input := controllerState === (stLoadInput : Signal dom _)
  let clear_acc := load_input
  let do_mac_hidden := (controllerState === (stMacHidden : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure inputCount4b))
  let do_bias_hidden := controllerState === (stBiasHidden : Signal dom _)
  let do_act_hidden := controllerState === (stActHidden : Signal dom _)
  let advance_hidden := controllerState === (stNextHidden : Signal dom _)
  let do_mac_output := (controllerState === (stMacOutput : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> (Signal.pure hiddenCount4b))
  let do_bias_output := controllerState === (stBiasOutput : Signal dom _)
  let done := controllerState === (stDone : Signal dom _)
  let busy := ((fun value => !value) <$> isIdle) &&& ((fun value => !value) <$> done)
  let isMacOutput := controllerState === (stMacOutput : Signal dom _)
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
    controllerState,
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
    b2Data,
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

end TinyMLP.Sparkle
