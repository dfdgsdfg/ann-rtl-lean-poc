import Sparkle
import TinyMLP.Types

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP

def sparkleControllerState {dom : DomainConfig}
    (start : Signal dom Bool)
    (hidden_idx : Signal dom (BitVec 4))
    (input_idx : Signal dom (BitVec 4))
    (inputNeurons4b : Signal dom (BitVec 4))
    (hiddenNeurons4b : Signal dom (BitVec 4))
    (lastHiddenIdx : Signal dom (BitVec 4)) : Signal dom (BitVec 4) :=
  Signal.loop fun state =>
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

    let nextState := hw_cond (stIdle : Signal dom _)
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

    Signal.register stIdle nextState

def sparkleControllerPacked {dom : DomainConfig}
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

end TinyMLP
