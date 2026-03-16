import TinyMLPSparkle.Refinement
import TinyMLP.ProofsVanilla.SpecArithmetic

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace TinyMLP.Sparkle

local instance : ArithmeticProofProvider := vanillaArithmeticProofProvider

def packMlpCoreOutputsBundle (outputs : MlpCoreOutputs) :=
  let packed : Signal defaultDomain _ :=
    bundleAll! [
      Signal.pure outputs.state,
      Signal.pure outputs.load_input,
      Signal.pure outputs.clear_acc,
      Signal.pure outputs.do_mac_hidden,
      Signal.pure outputs.do_bias_hidden,
      Signal.pure outputs.do_act_hidden,
      Signal.pure outputs.advance_hidden,
      Signal.pure outputs.do_mac_output,
      Signal.pure outputs.do_bias_output,
      Signal.pure outputs.done,
      Signal.pure outputs.busy,
      Signal.pure outputs.out_bit,
      Signal.pure outputs.hidden_idx,
      Signal.pure outputs.input_idx,
      Signal.pure outputs.acc_reg,
      Signal.pure outputs.mac_acc_out,
      Signal.pure outputs.mac_a,
      Signal.pure outputs.b2_data,
      Signal.pure outputs.input_reg0,
      Signal.pure outputs.input_reg1,
      Signal.pure outputs.input_reg2,
      Signal.pure outputs.input_reg3,
      Signal.pure outputs.hidden_reg0,
      Signal.pure outputs.hidden_reg1,
      Signal.pure outputs.hidden_reg2,
      Signal.pure outputs.hidden_reg3,
      Signal.pure outputs.hidden_reg4,
      Signal.pure outputs.hidden_reg5,
      Signal.pure outputs.hidden_reg6,
      Signal.pure outputs.hidden_reg7,
      Signal.pure outputs.hidden_input_case_hit,
      Signal.pure outputs.output_hidden_case_hit,
      Signal.pure outputs.hidden_weight_case_hit,
      Signal.pure outputs.output_weight_case_hit
    ]
  packed.atTime 0

theorem packMlpCoreView_sample_bundle {dom : DomainConfig} (view : MlpCoreView dom) (t : Nat) :
    (packMlpCoreView view).atTime t = packMlpCoreOutputsBundle (view.sample t) := by
  cases view
  rfl

theorem sparkleMlpCorePackedView_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (packMlpCoreView
        (sparkleMlpCoreView
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples))).atTime t =
      packMlpCoreOutputsBundle (mlpCoreOutputsOfState (rtlTrace samples t)) := by
  calc
    (packMlpCoreView
        (sparkleMlpCoreView
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples))).atTime t =
      packMlpCoreOutputsBundle
        ((sparkleMlpCoreView
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples)).sample t) := by
            simpa using
              packMlpCoreView_sample_bundle
                (view :=
                  sparkleMlpCoreView
                    (startSignal (dom := dom) samples)
                    (input0Signal (dom := dom) samples)
                    (input1Signal (dom := dom) samples)
                    (input2Signal (dom := dom) samples)
                    (input3Signal (dom := dom) samples))
                t
    _ = packMlpCoreOutputsBundle (mlpCoreOutputsOfState (rtlTrace samples t)) := by
      rw [sparkleMlpCoreView_refines_rtlTrace (dom := dom) samples t]

/--
The exact Sparkle emit path for this branch lowers the already-packed Signal
payload into the typed `Sparkle.IR.AST.Design` consumed directly by
`Sparkle.Backend.Verilog.toVerilogDesign`. This theorem fixes the
machine-checked field ordering and per-cycle meaning of that payload, while
artifact-consistency separately pins the exact emitted typed IR and rendered
Verilog with fingerprints.
-/
theorem sparkleMlpCoreBackendPayload_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (packMlpCoreView
        (sparkleMlpCoreView
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples))).atTime t =
      packMlpCoreOutputsBundle (mlpCoreOutputsOfState (rtlTrace samples t)) :=
  sparkleMlpCorePackedView_refines_rtlTrace (dom := dom) samples t

end TinyMLP.Sparkle
