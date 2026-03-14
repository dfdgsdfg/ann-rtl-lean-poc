import Sparkle

open Sparkle.Core.Signal

namespace TinyMLP

abbrev stateWidth : Nat := 4
abbrev controllerPackedWidth : Nat := 14

abbrev stIdle : BitVec stateWidth := 0#4
abbrev stLoadInput : BitVec stateWidth := 1#4
abbrev stMacHidden : BitVec stateWidth := 2#4
abbrev stBiasHidden : BitVec stateWidth := 3#4
abbrev stActHidden : BitVec stateWidth := 4#4
abbrev stNextHidden : BitVec stateWidth := 5#4
abbrev stMacOutput : BitVec stateWidth := 6#4
abbrev stBiasOutput : BitVec stateWidth := 7#4
abbrev stDone : BitVec stateWidth := 8#4

abbrev inputNeurons4b : BitVec 4 := 4#4
abbrev hiddenNeurons4b : BitVec 4 := 8#4
abbrev lastHiddenIdx : BitVec 4 := 7#4

def isInputMacActive {dom : Sparkle.Core.Domain.DomainConfig}
    (inputIdx : Signal dom (BitVec 4)) : Signal dom Bool :=
  (inputIdx === (0#4 : Signal dom _)) |||
    (inputIdx === (1#4 : Signal dom _)) |||
    (inputIdx === (2#4 : Signal dom _)) |||
    (inputIdx === (3#4 : Signal dom _))

def isOutputMacActive {dom : Sparkle.Core.Domain.DomainConfig}
    (inputIdx : Signal dom (BitVec 4)) : Signal dom Bool :=
  (inputIdx === (0#4 : Signal dom _)) |||
    (inputIdx === (1#4 : Signal dom _)) |||
    (inputIdx === (2#4 : Signal dom _)) |||
    (inputIdx === (3#4 : Signal dom _)) |||
    (inputIdx === (4#4 : Signal dom _)) |||
    (inputIdx === (5#4 : Signal dom _)) |||
    (inputIdx === (6#4 : Signal dom _)) |||
    (inputIdx === (7#4 : Signal dom _))

end TinyMLP
