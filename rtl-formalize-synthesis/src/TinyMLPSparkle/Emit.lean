import Sparkle
import Sparkle.Compiler.Elab
import TinyMLPSparkle.ControllerSignal

set_option maxRecDepth 65536
set_option maxHeartbeats 64000000

open Sparkle.Core.Domain

namespace TinyMLP

abbrev sparkleControllerPacked {dom : DomainConfig}
    (start : Sparkle.Core.Signal.Signal dom Bool)
    (hidden_idx : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (input_idx : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (inputNeurons4b : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (hiddenNeurons4b : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (lastHiddenIdx : Sparkle.Core.Signal.Signal dom (BitVec 4)) :=
  _root_.TinyMLP.Sparkle.sparkleControllerPackedFlat
    start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx

#writeVerilogDesign sparkleControllerPacked "../experiments/rtl-formalize-synthesis/sparkle/sparkle_controller.sv"

end TinyMLP
