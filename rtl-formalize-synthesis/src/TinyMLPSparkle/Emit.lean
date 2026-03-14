import Lean
import Sparkle.Backend.Verilog
import Sparkle.Compiler.Elab
import Sparkle.Core.Domain
import TinyMLPSparkle.ControllerSignal
import TinyMLPSparkle.MlpCoreSignal

set_option maxRecDepth 65536
set_option maxHeartbeats 64000000

open Sparkle.Core.Domain
open Lean
open Lean.Elab.Command

namespace TinyMLP

/--
  The controller-only experiment intentionally exposes combinational handshake
  outputs to match the baseline `rtl/src/controller.sv` boundary. Sparkle's
  registered-output DRC is therefore bypassed only for this emit entrypoint.
-/
elab "#writeVerilogDesignNoDRC" id:ident str:str : command => do
  let declName ← liftCoreM do
    resolveGlobalConstNoOverload id
  liftTermElabM do
    let design ← Sparkle.Compiler.Elab.synthesizeHierarchical declName
    let verilog := Sparkle.Backend.Verilog.toVerilogDesign design
    let path := str.getString
    IO.FS.writeFile path verilog
    IO.println s!"Written {design.modules.length} modules to {path}"

abbrev sparkleControllerPacked {dom : DomainConfig}
    (start : Sparkle.Core.Signal.Signal dom Bool)
    (hidden_idx : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (input_idx : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (inputNeurons4b : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (hiddenNeurons4b : Sparkle.Core.Signal.Signal dom (BitVec 4))
    (lastHiddenIdx : Sparkle.Core.Signal.Signal dom (BitVec 4)) :=
  _root_.TinyMLP.Sparkle.sparkleControllerPackedFlat
    start hidden_idx input_idx inputNeurons4b hiddenNeurons4b lastHiddenIdx

abbrev sparkleMlpCorePacked {dom : DomainConfig}
    (start : Sparkle.Core.Signal.Signal dom Bool)
    (in0 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in1 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in2 : Sparkle.Core.Signal.Signal dom (BitVec 8))
    (in3 : Sparkle.Core.Signal.Signal dom (BitVec 8)) :=
  _root_.TinyMLP.Sparkle.sparkleMlpCorePacked start in0 in1 in2 in3

#writeVerilogDesignNoDRC sparkleControllerPacked "../experiments/rtl-formalize-synthesis/sparkle/sparkle_controller.sv"
#writeVerilogDesignNoDRC sparkleMlpCorePacked "../experiments/rtl-formalize-synthesis/sparkle/sparkle_mlp_core.sv"

end TinyMLP
