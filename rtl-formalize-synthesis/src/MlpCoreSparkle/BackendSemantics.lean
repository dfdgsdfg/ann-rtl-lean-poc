import MlpCoreSparkle.Refinement
import MlpCoreSparkle.ProofConfig

open Sparkle.Core.Domain
open Sparkle.Core.Signal

namespace MlpCore.Sparkle

open MlpCoreSparkle.ProofConfig

local instance : ArithmeticProofProvider := selectedArithmeticProofProvider

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

theorem sparkleMlpCorePacked_refines_rtlTrace {dom : DomainConfig}
    (samples : Nat → CtrlSample) (t : Nat) :
    (sparkleMlpCorePacked
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).atTime t =
        packMlpCoreOutputsBits (mlpCoreOutputsOfState (rtlTrace samples t)) := by
  cases t with
  | zero =>
      calc
        (sparkleMlpCorePacked
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples)).atTime 0 = packedInitBits := by
            rfl
        _ = packMlpCoreOutputsBits (mlpCoreOutputsOfState idleState) := by
          simpa [packedInitBits, packedInitState] using packEncodedMlpCoreStateBits_refines_state idleState
        _ = packMlpCoreOutputsBits (mlpCoreOutputsOfState (rtlTrace samples 0)) := by
          simp [rtlTrace]
  | succ n =>
      calc
        (sparkleMlpCorePacked
          (startSignal (dom := dom) samples)
          (input0Signal (dom := dom) samples)
          (input1Signal (dom := dom) samples)
          (input2Signal (dom := dom) samples)
          (input3Signal (dom := dom) samples)).atTime (n + 1) =
            (packMlpCoreStateBitsSynth
              (MlpCore.nextState
                (startSignal (dom := dom) samples)
                (input0Signal (dom := dom) samples)
                (input1Signal (dom := dom) samples)
                (input2Signal (dom := dom) samples)
                (input3Signal (dom := dom) samples)
                (sparkleMlpCoreStateSynth
                  (startSignal (dom := dom) samples)
                  (input0Signal (dom := dom) samples)
                  (input1Signal (dom := dom) samples)
                  (input2Signal (dom := dom) samples)
                  (input3Signal (dom := dom) samples)))).atTime n := by
                    rfl
        _ =
            (packMlpCoreStateBitsSignal
              (MlpCore.nextState
                (startSignal (dom := dom) samples)
                (input0Signal (dom := dom) samples)
                (input1Signal (dom := dom) samples)
                (input2Signal (dom := dom) samples)
                (input3Signal (dom := dom) samples)
                (sparkleMlpCoreStateSynth
                  (startSignal (dom := dom) samples)
                  (input0Signal (dom := dom) samples)
                  (input1Signal (dom := dom) samples)
                  (input2Signal (dom := dom) samples)
                  (input3Signal (dom := dom) samples)))).atTime n := by
                    simpa using
                      packMlpCoreStateBitsSynth_atTime
                        (core :=
                          MlpCore.nextState
                            (startSignal (dom := dom) samples)
                            (input0Signal (dom := dom) samples)
                            (input1Signal (dom := dom) samples)
                            (input2Signal (dom := dom) samples)
                            (input3Signal (dom := dom) samples)
                            (sparkleMlpCoreStateSynth
                              (startSignal (dom := dom) samples)
                              (input0Signal (dom := dom) samples)
                              (input1Signal (dom := dom) samples)
                              (input2Signal (dom := dom) samples)
                              (input3Signal (dom := dom) samples)))
                        (t := n)
        _ = packMlpCoreOutputsBits (mlpCoreOutputsOfState (rtlTrace samples (n + 1))) := by
          exact packMlpCoreStateBitsSignal_refines_state
            (core :=
              MlpCore.nextState
                (startSignal (dom := dom) samples)
                (input0Signal (dom := dom) samples)
                (input1Signal (dom := dom) samples)
                (input2Signal (dom := dom) samples)
                (input3Signal (dom := dom) samples)
                (sparkleMlpCoreStateSynth
                  (startSignal (dom := dom) samples)
                  (input0Signal (dom := dom) samples)
                  (input1Signal (dom := dom) samples)
                  (input2Signal (dom := dom) samples)
                  (input3Signal (dom := dom) samples)))
            (s := rtlTrace samples (n + 1))
            (t := n)
            (hcore := sparkleMlpCoreNextStateSynth_refines_rtlTrace (dom := dom) samples n)

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
    (sparkleMlpCorePacked
      (startSignal (dom := dom) samples)
      (input0Signal (dom := dom) samples)
      (input1Signal (dom := dom) samples)
      (input2Signal (dom := dom) samples)
      (input3Signal (dom := dom) samples)).atTime t =
      packMlpCoreOutputsBits (mlpCoreOutputsOfState (rtlTrace samples t)) :=
  sparkleMlpCorePacked_refines_rtlTrace (dom := dom) samples t

end MlpCore.Sparkle
