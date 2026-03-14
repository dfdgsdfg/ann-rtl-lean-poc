import Sparkle.Core.Domain
import Sparkle.Core.Signal

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

private def signBit8 (x : BitVec 8) : BitVec 1 :=
  BitVec.extractLsb' 7 1 x

private def signBit16 (x : BitVec 16) : BitVec 1 :=
  BitVec.extractLsb' 15 1 x

private def signBit24 (x : BitVec 24) : BitVec 1 :=
  BitVec.extractLsb' 23 1 x

private def signBit32 (x : BitVec 32) : BitVec 1 :=
  BitVec.extractLsb' 31 1 x

def sext8To16 (x : BitVec 8) : BitVec 16 :=
  let upper : BitVec 8 := if signBit8 x == 1#1 then BitVec.ofInt 8 (-1) else 0#8
  BitVec.append upper x

def sext16To24 (x : BitVec 16) : BitVec 24 :=
  let upper : BitVec 8 := if signBit16 x == 1#1 then BitVec.ofInt 8 (-1) else 0#8
  BitVec.append upper x

def sext16To32 (x : BitVec 16) : BitVec 32 :=
  let upper : BitVec 16 := if signBit16 x == 1#1 then BitVec.ofInt 16 (-1) else 0#16
  BitVec.append upper x

def sext24To32 (x : BitVec 24) : BitVec 32 :=
  let upper : BitVec 8 := if signBit24 x == 1#1 then BitVec.ofInt 8 (-1) else 0#8
  BitVec.append upper x

def relu16Comb (x : BitVec 32) : BitVec 16 :=
  if signBit32 x == 1#1 then
    0#16
  else
    BitVec.extractLsb' 0 16 x

def gtZero32Comb (x : BitVec 32) : Bool :=
  BitVec.slt 0#32 x

def selectInputRegComb
    (idx : BitVec 4)
    (r0 r1 r2 r3 : BitVec 8) : BitVec 8 :=
  if idx == 0#4 then
    r0
  else if idx == 1#4 then
    r1
  else if idx == 2#4 then
    r2
  else if idx == 3#4 then
    r3
  else
    0#8

def selectHiddenRegComb
    (idx : BitVec 4)
    (h0 h1 h2 h3 h4 h5 h6 h7 : BitVec 16) : BitVec 16 :=
  if idx == 0#4 then
    h0
  else if idx == 1#4 then
    h1
  else if idx == 2#4 then
    h2
  else if idx == 3#4 then
    h3
  else if idx == 4#4 then
    h4
  else if idx == 5#4 then
    h5
  else if idx == 6#4 then
    h6
  else if idx == 7#4 then
    h7
  else
    0#16

def updateHiddenRegComb
    (target hiddenIdx : BitVec 4)
    (newValue current : BitVec 16) : BitVec 16 :=
  if hiddenIdx == target then newValue else current

def hiddenMacTerm32Comb (inputVal weightVal : BitVec 8) : BitVec 32 :=
  let a24 := sext16To24 (sext8To16 inputVal)
  let b24 := sext16To24 (sext8To16 weightVal)
  let product24 : BitVec 24 := a24 * b24
  sext24To32 product24

def outputMacTerm32Comb (hiddenVal : BitVec 16) (weightVal : BitVec 8) : BitVec 32 :=
  let a24 := sext16To24 hiddenVal
  let b24 := sext16To24 (sext8To16 weightVal)
  let product24 : BitVec 24 := a24 * b24
  sext24To32 product24

def selectInputReg {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (r0 r1 r2 r3 : Signal dom (BitVec 8)) : Signal dom (BitVec 8) :=
  hw_cond (Signal.pure 0#8)
    | idx === Signal.pure 0#4 => r0
    | idx === Signal.pure 1#4 => r1
    | idx === Signal.pure 2#4 => r2
    | idx === Signal.pure 3#4 => r3

def selectHiddenReg {dom : DomainConfig}
    (idx : Signal dom (BitVec 4))
    (h0 h1 h2 h3 h4 h5 h6 h7 : Signal dom (BitVec 16)) : Signal dom (BitVec 16) :=
  hw_cond (Signal.pure 0#16)
    | idx === Signal.pure 0#4 => h0
    | idx === Signal.pure 1#4 => h1
    | idx === Signal.pure 2#4 => h2
    | idx === Signal.pure 3#4 => h3
    | idx === Signal.pure 4#4 => h4
    | idx === Signal.pure 5#4 => h5
    | idx === Signal.pure 6#4 => h6
    | idx === Signal.pure 7#4 => h7

def updateHiddenReg {dom : DomainConfig}
    (target : BitVec 4)
    (hiddenIdx : Signal dom (BitVec 4))
    (newValue current : Signal dom (BitVec 16)) : Signal dom (BitVec 16) :=
  Signal.mux (hiddenIdx === Signal.pure target) newValue current

def hiddenMacTerm32 {dom : DomainConfig}
    (inputVal weightVal : Signal dom (BitVec 8)) : Signal dom (BitVec 32) :=
  let inputSign := inputVal.map (BitVec.extractLsb' 7 1 ·)
  let weightSign := weightVal.map (BitVec.extractLsb' 7 1 ·)
  let inputUpper := Signal.mux
    (inputSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 16 (-1)))
    (Signal.pure 0#16)
  let weightUpper := Signal.mux
    (weightSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 16 (-1)))
    (Signal.pure 0#16)
  let input24 : Signal dom (BitVec 24) := (BitVec.append · ·) <$> inputUpper <*> inputVal
  let weight24 : Signal dom (BitVec 24) := (BitVec.append · ·) <$> weightUpper <*> weightVal
  let product24 : Signal dom (BitVec 24) := input24 * weight24
  let productSign := product24.map (BitVec.extractLsb' 23 1 ·)
  let productUpper := Signal.mux
    (productSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 8 (-1)))
    (Signal.pure 0#8)
  (BitVec.append · ·) <$> productUpper <*> product24

def outputMacTerm32 {dom : DomainConfig}
    (hiddenVal : Signal dom (BitVec 16))
    (weightVal : Signal dom (BitVec 8)) : Signal dom (BitVec 32) :=
  let hiddenSign := hiddenVal.map (BitVec.extractLsb' 15 1 ·)
  let hiddenUpper := Signal.mux
    (hiddenSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 8 (-1)))
    (Signal.pure 0#8)
  let hidden24 : Signal dom (BitVec 24) := (BitVec.append · ·) <$> hiddenUpper <*> hiddenVal
  let weightSign := weightVal.map (BitVec.extractLsb' 7 1 ·)
  let weightUpper16 := Signal.mux
    (weightSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 16 (-1)))
    (Signal.pure 0#16)
  let weight24 : Signal dom (BitVec 24) := (BitVec.append · ·) <$> weightUpper16 <*> weightVal
  let product24 : Signal dom (BitVec 24) := hidden24 * weight24
  let productSign := product24.map (BitVec.extractLsb' 23 1 ·)
  let productUpper := Signal.mux
    (productSign === Signal.pure 1#1)
    (Signal.pure (BitVec.ofInt 8 (-1)))
    (Signal.pure 0#8)
  (BitVec.append · ·) <$> productUpper <*> product24

def relu16 {dom : DomainConfig}
    (x : Signal dom (BitVec 32)) : Signal dom (BitVec 16) :=
  let sign := x.map (BitVec.extractLsb' 31 1 ·)
  let narrowed := x.map (BitVec.extractLsb' 0 16 ·)
  Signal.mux (sign === Signal.pure 1#1) (Signal.pure 0#16) narrowed

def gtZero32 {dom : DomainConfig}
    (x : Signal dom (BitVec 32)) : Signal dom Bool :=
  (BitVec.slt · ·) <$> Signal.pure (0#32 : BitVec 32) <*> x

end TinyMLP.Sparkle
