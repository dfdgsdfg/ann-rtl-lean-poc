import MlpCore
import MlpCore.Interfaces.ArithmeticProofProvider

namespace MlpCoreSparkle.ProofConfig

export MlpCore (IndexInvariant rtlTrace_preserves_indexInvariant controlOf_rtlTrace)

def selectedProofLane : String := "vanilla"

def selectedProofNamespace : String := "MlpCore"

def selectedProofPackage : String := "formalize"

def selectedArithmeticProviderDecl : String := "MlpCore.vanillaArithmeticProofProvider"

def selectedTrustProfile : String := "vendor-loop-unfold-plus-nextstate-bridge"

def selectedTrustNote : String := "Actual Sparkle synth-path refinement relies on vendored Sparkle's local `Signal.loop_unfold` axiom plus one local axiom bridging the pure encoded next-state network to `timedStep`."

abbrev selectedArithmeticProofProvider : MlpCore.ArithmeticProofProvider :=
  MlpCore.vanillaArithmeticProofProvider

end MlpCoreSparkle.ProofConfig
