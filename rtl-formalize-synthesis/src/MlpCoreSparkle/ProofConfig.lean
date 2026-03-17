import MlpCore
import MlpCore.Interfaces.ArithmeticProofProvider

namespace MlpCoreSparkle.ProofConfig

export MlpCore (IndexInvariant rtlTrace_preserves_indexInvariant controlOf_rtlTrace)

def selectedProofLane : String := "vanilla"

def selectedProofNamespace : String := "MlpCore"

def selectedProofPackage : String := "formalize"

def selectedArithmeticProviderDecl : String := "MlpCore.vanillaArithmeticProofProvider"

def selectedTrustProfile : String := "baseline"

def selectedTrustNote : String := "Baseline Lean proof lane backed by the checked-in formalize package."

abbrev selectedArithmeticProofProvider : MlpCore.ArithmeticProofProvider :=
  MlpCore.vanillaArithmeticProofProvider

end MlpCoreSparkle.ProofConfig
