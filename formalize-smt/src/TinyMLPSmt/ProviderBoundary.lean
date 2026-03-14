import TinyMLP.ProofsVanilla.SpecArithmetic
import TinyMLPSmt.Arithmetic

namespace TinyMLPSmt

open TinyMLP

example : True := by
  fail_if_success
    let _ : ArithmeticProofProvider := inferInstance
  trivial

section VanillaLane

local instance : ArithmeticProofProvider := vanillaArithmeticProofProvider

example (lhs rhs : Int8) :
    (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl

end VanillaLane

section SmtLane

local instance : ArithmeticProofProvider := smtArithmeticProofProvider

example (lhs rhs : Int8) :
    (mul8x8To16 lhs rhs).toInt = lhs.toInt * rhs.toInt := by
  rfl

end SmtLane

end TinyMLPSmt
