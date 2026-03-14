import Sparkle.Core.Domain
import Sparkle.Core.Signal
import TinyMLPSparkle.Types

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

structure ControllerView (dom : DomainConfig) where
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

def controllerPhaseNextComb
    (start : Bool)
    (hidden_idx : BitVec stateWidth)
    (input_idx : BitVec stateWidth)
    (inputNeurons4b : BitVec stateWidth)
    (hiddenNeurons4b : BitVec stateWidth)
    (lastHiddenIdx : BitVec stateWidth)
    (state : BitVec stateWidth) : BitVec stateWidth :=
  let inputGuardReached := input_idx == inputNeurons4b
  let outputGuardReached := input_idx == hiddenNeurons4b
  let hiddenLast := hidden_idx == lastHiddenIdx
  if state == stIdle then
    if start then stLoadInput else stIdle
  else if state == stLoadInput then
    stMacHidden
  else if state == stMacHidden then
    if inputGuardReached then stBiasHidden else stMacHidden
  else if state == stBiasHidden then
    stActHidden
  else if state == stActHidden then
    stNextHidden
  else if state == stNextHidden then
    if hiddenLast then stMacOutput else stMacHidden
  else if state == stMacOutput then
    if outputGuardReached then stBiasOutput else stMacOutput
  else if state == stBiasOutput then
    stDone
  else if state == stDone then
    if start then stDone else stIdle
  else
    stIdle

def controllerPhaseNext {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4))
    (state : Signal dom (BitVec 4)) : Signal dom (BitVec 4) :=
  let isIdle := state === (stIdle : Signal dom _)
  let isLoadInput := state === (stLoadInput : Signal dom _)
  let isMacHidden := state === (stMacHidden : Signal dom _)
  let isBiasHidden := state === (stBiasHidden : Signal dom _)
  let isActHidden := state === (stActHidden : Signal dom _)
  let isNextHidden := state === (stNextHidden : Signal dom _)
  let isMacOutput := state === (stMacOutput : Signal dom _)
  let isBiasOutput := state === (stBiasOutput : Signal dom _)
  let isDone := state === (stDone : Signal dom _)

  let inputGuardReached := input_idx === inputNeurons4b
  let outputGuardReached := input_idx === hiddenNeurons4b
  let hiddenLast := hidden_idx === lastHiddenIdx
  let notStart := (fun value => !value) <$> start

  hw_cond (stIdle : Signal dom _)
    | isIdle &&& start => (stLoadInput : Signal dom _)
    | isIdle => (stIdle : Signal dom _)
    | isLoadInput => (stMacHidden : Signal dom _)
    | isMacHidden &&& inputGuardReached => (stBiasHidden : Signal dom _)
    | isMacHidden => (stMacHidden : Signal dom _)
    | isBiasHidden => (stActHidden : Signal dom _)
    | isActHidden => (stNextHidden : Signal dom _)
    | isNextHidden &&& hiddenLast => (stMacOutput : Signal dom _)
    | isNextHidden => (stMacHidden : Signal dom _)
    | isMacOutput &&& outputGuardReached => (stBiasOutput : Signal dom _)
    | isMacOutput => (stMacOutput : Signal dom _)
    | isBiasOutput => (stDone : Signal dom _)
    | isDone &&& notStart => (stIdle : Signal dom _)
    | isDone => (stDone : Signal dom _)

def loadInputComb (state : BitVec stateWidth) : Bool :=
  state == stLoadInput

def clearAccComb (state : BitVec stateWidth) : Bool :=
  loadInputComb state

def doMacHiddenComb
    (state : BitVec stateWidth)
    (input_idx : BitVec stateWidth)
    (inputNeurons4b : BitVec stateWidth) : Bool :=
  (state == stMacHidden) && BitVec.ult input_idx inputNeurons4b

def doBiasHiddenComb (state : BitVec stateWidth) : Bool :=
  state == stBiasHidden

def doActHiddenComb (state : BitVec stateWidth) : Bool :=
  state == stActHidden

def advanceHiddenComb (state : BitVec stateWidth) : Bool :=
  state == stNextHidden

def doMacOutputComb
    (state : BitVec stateWidth)
    (input_idx : BitVec stateWidth)
    (hiddenNeurons4b : BitVec stateWidth) : Bool :=
  (state == stMacOutput) && BitVec.ult input_idx hiddenNeurons4b

def doBiasOutputComb (state : BitVec stateWidth) : Bool :=
  state == stBiasOutput

def doneComb (state : BitVec stateWidth) : Bool :=
  state == stDone

def busyComb (state : BitVec stateWidth) : Bool :=
  (state != stIdle) && (state != stDone)

def controllerViewOfState {dom : DomainConfig}
    (state : Signal dom (BitVec stateWidth))
    (input_idx : Signal dom (BitVec stateWidth))
    (inputNeurons4b : Signal dom (BitVec stateWidth))
    (hiddenNeurons4b : Signal dom (BitVec stateWidth)) : ControllerView dom :=
  let isIdle := state === (stIdle : Signal dom _)
  let load_input := state === (stLoadInput : Signal dom _)
  let clear_acc := load_input
  let do_mac_hidden := (state === (stMacHidden : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> inputNeurons4b)
  let do_bias_hidden := state === (stBiasHidden : Signal dom _)
  let do_act_hidden := state === (stActHidden : Signal dom _)
  let advance_hidden := state === (stNextHidden : Signal dom _)
  let do_mac_output := (state === (stMacOutput : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> hiddenNeurons4b)
  let do_bias_output := state === (stBiasOutput : Signal dom _)
  let done := state === (stDone : Signal dom _)
  let busy := ((fun value => !value) <$> isIdle) &&& ((fun value => !value) <$> done)
  { state
  , load_input
  , clear_acc
  , do_mac_hidden
  , do_bias_hidden
  , do_act_hidden
  , advance_hidden
  , do_mac_output
  , do_bias_output
  , done
  , busy
  }

def sparkleControllerState {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4)) : Signal dom (BitVec 4) :=
  Signal.loop fun state =>
    let nextState := controllerPhaseNext
      start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx state
    Signal.register stIdle nextState

def sparkleControllerView {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4)) : ControllerView dom :=
  let state := sparkleControllerState start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx
  controllerViewOfState state input_idx inputNeurons4b hiddenNeurons4b

def sparkleControllerPackedFlat {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4)) :=
  let state := sparkleControllerState start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx
  let isIdle := state === (stIdle : Signal dom _)
  let load_input := state === (stLoadInput : Signal dom _)
  let clear_acc := load_input
  let do_mac_hidden := (state === (stMacHidden : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> inputNeurons4b)
  let do_bias_hidden := state === (stBiasHidden : Signal dom _)
  let do_act_hidden := state === (stActHidden : Signal dom _)
  let advance_hidden := state === (stNextHidden : Signal dom _)
  let do_mac_output := (state === (stMacOutput : Signal dom _)) &&&
    ((BitVec.ult · ·) <$> input_idx <*> hiddenNeurons4b)
  let do_bias_output := state === (stBiasOutput : Signal dom _)
  let done := state === (stDone : Signal dom _)
  let busy := ((fun value => !value) <$> isIdle) &&& ((fun value => !value) <$> done)
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
    busy
  ]

def sparkleControllerPacked {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4)) :=
  sparkleControllerPackedFlat
    start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx

end TinyMLP.Sparkle
