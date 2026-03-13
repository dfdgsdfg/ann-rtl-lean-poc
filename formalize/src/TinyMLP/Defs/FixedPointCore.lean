import TinyMLP.Defs.SpecCore
import TinyMLP.Interfaces.ArithmeticProofProvider

namespace TinyMLP

def w1Int8At (hiddenIdx inputIdx : Nat) : Int8 :=
  Int8.ofInt (w1At hiddenIdx inputIdx)

def w2Int8At (idx : Nat) : Int8 :=
  Int8.ofInt (w2At idx)

variable [ArithmeticProofProvider]

def mul8x8To16 (lhs rhs : Int8) : Int16Val :=
  ⟨lhs.toInt * rhs.toInt, ArithmeticProofProvider.int8MulInt8Bounds lhs rhs⟩

def mul16x8To24 (lhs : Int16Val) (rhs : Int8) : Int24Val :=
  ⟨lhs.toInt * rhs.toInt, ArithmeticProofProvider.int16MulInt8Bounds lhs rhs⟩

def lift16To32 (x : Int16Val) : Acc32 :=
  Acc32.ofInt x.toInt

def lift24To32 (x : Int24Val) : Acc32 :=
  Acc32.ofInt x.toInt

def acc32 (acc term : Acc32) : Acc32 :=
  Acc32.ofInt (acc.toInt + term.toInt)

def relu16 (x : Acc32) : Int16Val :=
  Int16Val.ofInt (relu x.toInt)

def bias1Term (idx : Nat) : Acc32 :=
  Acc32.ofInt (b1At idx)

def bias2Term : Acc32 :=
  Acc32.ofInt b2

def hiddenMacTermAt (input : Input8) (hiddenIdx inputIdx : Nat) : Acc32 :=
  lift16To32 (mul8x8To16 (input.getInt8Nat inputIdx) (w1Int8At hiddenIdx inputIdx))

def hiddenMacAccAt (input : Input8) (idx : Nat) : Acc32 :=
  acc32
    (acc32
      (acc32
        (acc32 Acc32.zero
          (hiddenMacTermAt input idx 0))
        (hiddenMacTermAt input idx 1))
      (hiddenMacTermAt input idx 2))
    (hiddenMacTermAt input idx 3)

def hiddenPreFixedAt (input : Input8) (idx : Nat) : Acc32 :=
  acc32 (hiddenMacAccAt input idx) (bias1Term idx)

def hiddenFixedAt (input : Input8) (idx : Nat) : Int16Val :=
  relu16 (hiddenPreFixedAt input idx)

def outputMacTermAt (hidden : Hidden16) (idx : Nat) : Acc32 :=
  lift24To32 (mul16x8To24 (hidden.getCellNat idx) (w2Int8At idx))

def outputMacAccFromHidden (hidden : Hidden16) : Acc32 :=
  acc32
    (acc32
      (acc32
        (acc32
          (acc32
            (acc32
              (acc32
                (acc32 Acc32.zero
                  (outputMacTermAt hidden 0))
                (outputMacTermAt hidden 1))
              (outputMacTermAt hidden 2))
            (outputMacTermAt hidden 3))
          (outputMacTermAt hidden 4))
        (outputMacTermAt hidden 5))
      (outputMacTermAt hidden 6))
    (outputMacTermAt hidden 7)

def outputScoreFixedFromHidden (hidden : Hidden16) : Acc32 :=
  acc32 (outputMacAccFromHidden hidden) bias2Term

def hiddenFixed (input : Input8) : Hidden16 :=
  { h0 := hiddenFixedAt input 0
  , h1 := hiddenFixedAt input 1
  , h2 := hiddenFixedAt input 2
  , h3 := hiddenFixedAt input 3
  , h4 := hiddenFixedAt input 4
  , h5 := hiddenFixedAt input 5
  , h6 := hiddenFixedAt input 6
  , h7 := hiddenFixedAt input 7
  }

def outputScoreFixed (input : Input8) : Acc32 :=
  outputScoreFixedFromHidden (hiddenFixed input)

def mlpFixed (input : Input8) : Bool :=
  (outputScoreFixed input).toInt > 0

end TinyMLP
