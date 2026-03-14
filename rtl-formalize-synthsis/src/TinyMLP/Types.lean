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

end TinyMLP
