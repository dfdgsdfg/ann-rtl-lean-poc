import MlpCore.Defs.FixedPointCore
import MlpCore.Defs.TemporalCore

namespace MlpCore

section

variable [ArithmeticProofProvider]

def rtlCorrectnessGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).output = mlpFixed input

def rtlTerminationGoal (input : Input8) : Prop :=
  (run totalCycles (initialState input)).phase = .done

end

end MlpCore
