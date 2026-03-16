import TinyMLP.Defs.FixedPointCore
import TinyMLP.Defs.TemporalCore

namespace TinyMLP

section

variable [ArithmeticProofProvider]

def rtlCorrectnessGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).output = mlpFixed input

def rtlTerminationGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).phase = .done

end

end TinyMLP
