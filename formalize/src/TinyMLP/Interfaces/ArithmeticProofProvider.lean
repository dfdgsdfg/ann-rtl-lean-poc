import TinyMLP.Defs.SpecCore

namespace TinyMLP

def Int8MulInt8BoundsGoal : Prop :=
  ∀ lhs rhs : Int8, Int16Bounds (lhs.toInt * rhs.toInt)

def Int16MulInt8BoundsGoal : Prop :=
  ∀ lhs : Int16Val, ∀ rhs : Int8, Int24Bounds (lhs.toInt * rhs.toInt)

class ArithmeticProofProvider where
  int8MulInt8Bounds : Int8MulInt8BoundsGoal
  int16MulInt8Bounds : Int16MulInt8BoundsGoal

end TinyMLP
