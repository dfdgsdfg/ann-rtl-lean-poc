import Sparkle
import Sparkle.Compiler.Elab
import TinyMLP.ControllerSignal

set_option maxRecDepth 65536
set_option maxHeartbeats 64000000

open Sparkle.Core.Domain

namespace TinyMLP

#writeVerilogDesign sparkleControllerPacked "../experiments/generated-rtl/sparkle/sparkle_controller.sv"

end TinyMLP
