import Sparkle.Core.Domain
import Sparkle.Core.Signal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

private def bv4 (value : Nat) : BitVec 4 :=
  BitVec.ofNat 4 value

private def bv8 (value : Int) : BitVec 8 :=
  BitVec.ofInt 8 value

private def bv32 (value : Int) : BitVec 32 :=
  BitVec.ofInt 32 value

def w1Data {dom : DomainConfig}
    (hidden_idx input_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 8) :=
  hw_cond (Signal.pure (bv8 0))
    | (hidden_idx === Signal.pure (bv4 0)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 0)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 0)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 0)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 1)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 1)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 1)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 1)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 2)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 2)
    | (hidden_idx === Signal.pure (bv4 2)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 2)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 2)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 3)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 3)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 3)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 3)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 4)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 4)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 4)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 4)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 5)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 5)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 5)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 5)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 6)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 6)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 6)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 6)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 (-1))
    | (hidden_idx === Signal.pure (bv4 7)) &&& (input_idx === Signal.pure (bv4 0)) => Signal.pure (bv8 1)
    | (hidden_idx === Signal.pure (bv4 7)) &&& (input_idx === Signal.pure (bv4 1)) => Signal.pure (bv8 2)
    | (hidden_idx === Signal.pure (bv4 7)) &&& (input_idx === Signal.pure (bv4 2)) => Signal.pure (bv8 0)
    | (hidden_idx === Signal.pure (bv4 7)) &&& (input_idx === Signal.pure (bv4 3)) => Signal.pure (bv8 0)

def b1Data {dom : DomainConfig}
    (hidden_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 32) :=
  hw_cond (Signal.pure (bv32 0))
    | hidden_idx === Signal.pure (bv4 0) => Signal.pure (bv32 0)
    | hidden_idx === Signal.pure (bv4 1) => Signal.pure (bv32 0)
    | hidden_idx === Signal.pure (bv4 2) => Signal.pure (bv32 1)
    | hidden_idx === Signal.pure (bv4 3) => Signal.pure (bv32 1)
    | hidden_idx === Signal.pure (bv4 4) => Signal.pure (bv32 0)
    | hidden_idx === Signal.pure (bv4 5) => Signal.pure (bv32 2)
    | hidden_idx === Signal.pure (bv4 6) => Signal.pure (bv32 1)
    | hidden_idx === Signal.pure (bv4 7) => Signal.pure (bv32 (-1))

def w2Data {dom : DomainConfig}
    (input_idx : Signal dom (BitVec 4)) : Signal dom (BitVec 8) :=
  hw_cond (Signal.pure (bv8 0))
    | input_idx === Signal.pure (bv4 0) => Signal.pure (bv8 0)
    | input_idx === Signal.pure (bv4 1) => Signal.pure (bv8 0)
    | input_idx === Signal.pure (bv4 2) => Signal.pure (bv8 1)
    | input_idx === Signal.pure (bv4 3) => Signal.pure (bv8 0)
    | input_idx === Signal.pure (bv4 4) => Signal.pure (bv8 (-1))
    | input_idx === Signal.pure (bv4 5) => Signal.pure (bv8 (-1))
    | input_idx === Signal.pure (bv4 6) => Signal.pure (bv8 1)
    | input_idx === Signal.pure (bv4 7) => Signal.pure (bv8 (-1))

def b2Data {dom : DomainConfig} : Signal dom (BitVec 32) :=
  Signal.pure (bv32 (-1))

end TinyMLP.Sparkle
