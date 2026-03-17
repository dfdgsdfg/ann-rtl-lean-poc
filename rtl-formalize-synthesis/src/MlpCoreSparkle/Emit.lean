import Lean
import Sparkle.Backend.Verilog
import Sparkle.Compiler.Elab
import Sparkle.Core.Domain
import MlpCoreSparkle.MlpCoreSignal

set_option maxRecDepth 65536
set_option maxHeartbeats 64000000

open Sparkle.Core.Domain

namespace MlpCore

abbrev sparkleMlpCorePacked {dom : DomainConfig}
    (start : Sparkle.Core.Signal.Signal dom Bool)
    (in0 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in1 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in2 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in3 : Sparkle.Core.Signal.Signal dom (BitVec 8)) :=
  _root_.MlpCore.Sparkle.sparkleMlpCorePacked start in0 in1 in2 in3

#writeVerilogDesign sparkleMlpCorePacked "../rtl-formalize-synthesis/results/canonical/sv/sparkle_mlp_core.sv"

end MlpCore
