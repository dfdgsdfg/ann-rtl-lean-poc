import MlpCore.Defs.TemporalCore
import MlpCoreSmt.Proofs.Invariants
import MlpCoreSmt.Proofs.FixedPoint

namespace MlpCoreSmt

open MlpCore

local instance : ArithmeticProofProvider := smtArithmeticProofProvider

-- ============================================================
-- Phase 1: run composition lemmas
-- ============================================================

theorem step_run_comm (n : Nat) (s : State) :
    run n (step s) = step (run n s) := by
  induction n generalizing s with
  | zero => simp [run]
  | succ n ih => simp only [run]; exact ih (step s)

theorem run_add (m n : Nat) (s : State) :
    run (m + n) s = run n (run m s) := by
  induction m generalizing s with
  | zero =>
      simp [run]
  | succ m ih =>
      simp [Nat.succ_add, run, ih]

-- ============================================================
-- Phase 2: Termination via control projection
-- ============================================================

theorem control_step_agrees (s : State) :
    controlOf (step s) = controlStep (controlOf s) := by
  cases hphase : s.phase <;> simp [controlOf, controlStep, step, hphase, inputCount, hiddenCount]
  · split <;> simp_all
  · split <;> simp_all
  · split <;> simp_all

theorem control_run_agrees (n : Nat) (s : State) :
    controlRun n (controlOf s) = controlOf (run n s) := by
  induction n generalizing s with
  | zero => simp [controlRun, run]
  | succ n ih =>
    simp only [controlRun, run]
    rw [← control_step_agrees s]
    exact ih (step s)

theorem controlRun_76_idle_phase :
    (controlRun 76 { phase := .idle, hiddenIdx := 0, inputIdx := 0 }).phase
    = .done := by native_decide

theorem rtl_terminates (input : Input8) :
    (run totalCycles (initialState input)).phase = .done := by
  unfold totalCycles
  have h2 := controlRun_76_idle_phase
  have h3 :
      (controlRun 76 { phase := .idle, hiddenIdx := 0, inputIdx := 0 }).phase =
        (run 76 (initialState input)).phase := by
    simpa [controlOf, initialState] using
      congrArg ControlState.phase (control_run_agrees 76 (initialState input))
  exact h3.symm.trans h2

-- ============================================================
-- Phase 3: Correctness via symbolic simulation
-- ============================================================

-- Startup: 2 cycles (idle → loadInput → macHidden)
theorem run2_initialState (input : Input8) :
    run 2 (initialState input) =
    { regs := input, hidden := Hidden16.zero, accumulator := Acc32.zero,
      hiddenIdx := 0, inputIdx := 0, phase := .macHidden, output := false } := by
  simp [run, step, initialState, Hidden16.zero, Acc32.zero, Acc32.ofInt]

-- Helper: state at start of macHidden for neuron j
private def macHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := Acc32.zero,
    hiddenIdx := j, inputIdx := 0, phase := .macHidden, output := false }

private def hiddenMacAcc (input : Input8) (j : Nat) : Acc32 :=
  hiddenMacAccAt input j

private def biasHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := hiddenMacAcc input j,
    hiddenIdx := j, inputIdx := inputCount, phase := .biasHidden, output := false }

private def hiddenPreAcc (input : Input8) (j : Nat) : Acc32 :=
  hiddenPreFixedAt input j

private def actHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := hiddenPreAcc input j,
    hiddenIdx := j, inputIdx := inputCount, phase := .actHidden, output := false }

private def nextHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := Acc32.zero,
    hiddenIdx := j, inputIdx := 0, phase := .nextHidden, output := false }

private def macOutputAcc (hidden : Hidden16) : Acc32 :=
  outputMacAccFromHidden hidden

private def macOutputEntry (input : Input8) (hidden : Hidden16) : State :=
  { regs := input, hidden := hidden, accumulator := Acc32.zero,
    hiddenIdx := 0, inputIdx := 0, phase := .macOutput, output := false }

private def biasOutputEntry (input : Input8) (hidden : Hidden16) (acc : Acc32) : State :=
  { regs := input, hidden := hidden, accumulator := acc,
    hiddenIdx := 0, inputIdx := hiddenCount, phase := .biasOutput, output := false }

private def finalOutputAcc (hidden : Hidden16) : Acc32 :=
  outputScoreFixedFromHidden hidden

private def doneEntry (input : Input8) (hidden : Hidden16) (acc : Acc32) : State :=
  { regs := input, hidden := hidden, accumulator := acc,
    hiddenIdx := 0, inputIdx := hiddenCount,
    phase := .done, output := decide (acc.toInt > 0) }

@[simp] private theorem hiddenMacAcc_toInt (input : Input8) (j : Nat) :
    (hiddenMacAcc input j).toInt = wrap32 (hiddenDotAt (toMathInput input) j) := by
  exact hiddenMacAccAt_toInt input j

@[simp] private theorem hiddenPreAcc_toInt (input : Input8) (j : Nat) :
    (hiddenPreAcc input j).toInt = wrap32 (hiddenPreAt (toMathInput input) j) := by
  exact hiddenPreFixedAt_toInt input j

@[simp] private theorem finalOutputAcc_toInt (hidden : Hidden16) :
    (finalOutputAcc hidden).toInt = wrap32 (outputScoreSpecFromHidden hidden.toHidden) := by
  exact outputScoreFixedFromHidden_toInt hidden

-- MAC inner loop: 5 steps from macHidden entry to biasHidden
theorem macHidden_5steps (input : Input8) (hidden : Hidden16) (j : Nat) :
    run 5 (macHiddenEntry input hidden j) = biasHiddenEntry input hidden j := by
  simp [macHiddenEntry, biasHiddenEntry, run, step, inputCount, hiddenMacAcc, hiddenMacAccAt,
    acc32, Acc32.zero]

private theorem step_biasHidden_observe (input : Input8) (hidden : Hidden16) (j : Nat) :
    step (biasHiddenEntry input hidden j) = actHiddenEntry input hidden j := by
  simp [biasHiddenEntry, actHiddenEntry, step, hiddenMacAcc, hiddenPreAcc, hiddenPreFixedAt]

private theorem step_actHidden_observe (input : Input8) (hidden : Hidden16) (j : Nat) :
    step (actHiddenEntry input hidden j) =
      nextHiddenEntry input (hidden.setCellNat j (hiddenFixedAt input j)) j := by
  simp [actHiddenEntry, nextHiddenEntry, step, hiddenPreAcc, hiddenFixedAt]

private theorem step_nextHidden_continue (input : Input8) (hidden : Hidden16) (j : Nat)
    (hj : j + 1 < hiddenCount) :
    step (nextHiddenEntry input hidden j) = macHiddenEntry input hidden (j + 1) := by
  simp [nextHiddenEntry, macHiddenEntry, step, hj]

private theorem step_nextHidden_finish (input : Input8) (hidden : Hidden16) :
    step (nextHiddenEntry input hidden 7) = macOutputEntry input hidden := by
  simp [nextHiddenEntry, macOutputEntry, step, hiddenCount]

-- Bias + Act + Next for j < 7: 3 steps, advances to neuron j+1
theorem bias_act_next_3steps (input : Input8) (hidden : Hidden16) (j : Nat)
    (hj : j + 1 < hiddenCount) :
    run 3 (biasHiddenEntry input hidden j) =
    macHiddenEntry input (hidden.setCellNat j (hiddenFixedAt input j)) (j + 1) := by
  have hjcases : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3 ∨ j = 4 ∨ j = 5 ∨ j = 6 := by
    unfold hiddenCount at hj
    omega
  rcases hjcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 0 (hiddenFixedAt input 0)) 0 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 1 (hiddenFixedAt input 1)) 1 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 2 (hiddenFixedAt input 2)) 2 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 3 (hiddenFixedAt input 3)) 3 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 4 (hiddenFixedAt input 4)) 4 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 5 (hiddenFixedAt input 5)) 5 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe]
    simpa using step_nextHidden_continue input (hidden.setCellNat 6 (hiddenFixedAt input 6)) 6 hj

-- Bias + Act + Next for j = 7: 3 steps, transitions to macOutput
theorem bias_act_next_last_3steps (input : Input8) (hidden : Hidden16) :
    run 3 (biasHiddenEntry input hidden 7) =
    macOutputEntry input (hidden.setCellNat 7 (hiddenFixedAt input 7)) := by
  simp [run, step_biasHidden_observe, step_nextHidden_finish, step_actHidden_observe]

-- One full neuron (8 cycles), j < 7
theorem one_hidden_neuron_8steps (input : Input8) (hidden : Hidden16) (j : Nat)
    (hj : j + 1 < hiddenCount) :
    run 8 (macHiddenEntry input hidden j) =
    macHiddenEntry input (hidden.setCellNat j (hiddenFixedAt input j)) (j + 1) := by
  rw [show (8 : Nat) = 5 + 3 from rfl, run_add]
  rw [macHidden_5steps]
  exact bias_act_next_3steps input hidden j hj

-- Last neuron (8 cycles), j = 7
theorem last_hidden_neuron_8steps (input : Input8) (hidden : Hidden16) :
    run 8 (macHiddenEntry input hidden 7) =
    { regs := input, hidden := hidden.setCellNat 7 (hiddenFixedAt input 7),
      accumulator := Acc32.zero, hiddenIdx := 0, inputIdx := 0,
      phase := .macOutput, output := false } := by
  rw [show (8 : Nat) = 5 + 3 from rfl, run_add]
  rw [macHidden_5steps]
  exact bias_act_next_last_3steps input hidden

-- Chain of setCellNat builds hiddenFixed
theorem progressive_hidden_build (input : Input8) :
    ((((((((Hidden16.zero).setCellNat 0 (hiddenFixedAt input 0)).setCellNat
      1 (hiddenFixedAt input 1)).setCellNat
      2 (hiddenFixedAt input 2)).setCellNat
      3 (hiddenFixedAt input 3)).setCellNat
      4 (hiddenFixedAt input 4)).setCellNat
      5 (hiddenFixedAt input 5)).setCellNat
      6 (hiddenFixedAt input 6)).setCellNat
      7 (hiddenFixedAt input 7)
    = hiddenFixed input := by
  rfl

-- Full hidden layer: 64 cycles
-- Compose 8 neuron lemmas via run_add

private theorem hidden_neurons_0_to_1 (input : Input8) :
    run 8 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)) 1 :=
  one_hidden_neuron_8steps input Hidden16.zero 0 (by decide)

private theorem hidden_neurons_0_to_2 (input : Input8) :
    run 16 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)) 2 := by
  rw [show (16 : Nat) = 8 + 8 from rfl, run_add, hidden_neurons_0_to_1]
  exact one_hidden_neuron_8steps input _ 1 (by decide)

private theorem hidden_neurons_0_to_3 (input : Input8) :
    run 24 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)).setCellNat
        2 (hiddenFixedAt input 2)) 3 := by
  rw [show (24 : Nat) = 16 + 8 from rfl, run_add, hidden_neurons_0_to_2]
  exact one_hidden_neuron_8steps input _ 2 (by decide)

private theorem hidden_neurons_0_to_4 (input : Input8) :
    run 32 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)).setCellNat
        2 (hiddenFixedAt input 2)).setCellNat
        3 (hiddenFixedAt input 3)) 4 := by
  rw [show (32 : Nat) = 24 + 8 from rfl, run_add, hidden_neurons_0_to_3]
  exact one_hidden_neuron_8steps input _ 3 (by decide)

private theorem hidden_neurons_0_to_5 (input : Input8) :
    run 40 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)).setCellNat
        2 (hiddenFixedAt input 2)).setCellNat
        3 (hiddenFixedAt input 3)).setCellNat
        4 (hiddenFixedAt input 4)) 5 := by
  rw [show (40 : Nat) = 32 + 8 from rfl, run_add, hidden_neurons_0_to_4]
  exact one_hidden_neuron_8steps input _ 4 (by decide)

private theorem hidden_neurons_0_to_6 (input : Input8) :
    run 48 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((((((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)).setCellNat
        2 (hiddenFixedAt input 2)).setCellNat
        3 (hiddenFixedAt input 3)).setCellNat
        4 (hiddenFixedAt input 4)).setCellNat
        5 (hiddenFixedAt input 5)) 6 := by
  rw [show (48 : Nat) = 40 + 8 from rfl, run_add, hidden_neurons_0_to_5]
  exact one_hidden_neuron_8steps input _ 5 (by decide)

private theorem hidden_neurons_0_to_7 (input : Input8) :
    run 56 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((((((Hidden16.zero.setCellNat 0 (hiddenFixedAt input 0)).setCellNat
        1 (hiddenFixedAt input 1)).setCellNat
        2 (hiddenFixedAt input 2)).setCellNat
        3 (hiddenFixedAt input 3)).setCellNat
        4 (hiddenFixedAt input 4)).setCellNat
        5 (hiddenFixedAt input 5)).setCellNat
        6 (hiddenFixedAt input 6)) 7 := by
  rw [show (56 : Nat) = 48 + 8 from rfl, run_add, hidden_neurons_0_to_6]
  exact one_hidden_neuron_8steps input _ 6 (by decide)

theorem hidden_layer_64steps (input : Input8) :
    run 64 (macHiddenEntry input Hidden16.zero 0) =
    macOutputEntry input (hiddenFixed input) := by
  rw [show (64 : Nat) = 56 + 8 from rfl, run_add, hidden_neurons_0_to_7]
  rw [last_hidden_neuron_8steps]
  rw [progressive_hidden_build]
  rfl

-- Output MAC: 9 cycles (8 MAC iterations + 1 exit to biasOutput)
theorem macOutput_9steps (input : Input8) (hidden : Hidden16) :
    run 9 (macOutputEntry input hidden) =
    biasOutputEntry input hidden (macOutputAcc hidden) := by
  simp [macOutputEntry, biasOutputEntry, run, step, hiddenCount, macOutputAcc, outputMacAccFromHidden,
    acc32, Acc32.zero]

-- Final step: biasOutput → done (1 cycle)
theorem biasOutput_1step (input : Input8) (hidden : Hidden16) (acc : Acc32) :
    step (biasOutputEntry input hidden acc) =
    doneEntry input hidden (acc32 acc bias2Term) := by
  simp [biasOutputEntry, doneEntry, step, acc32, bias2Term, Acc32.ofInt]

private theorem biasOutput_outputMac_1step (input : Input8) (hidden : Hidden16) :
    step (biasOutputEntry input hidden (macOutputAcc hidden)) =
    doneEntry input hidden (finalOutputAcc hidden) := by
  rw [biasOutput_1step]
  rfl

-- Main correctness assembly
theorem rtl_correct (input : Input8) :
    (run totalCycles (initialState input)).output = mlpFixed input := by
  rw [show totalCycles = 2 + 64 + 9 + 1 from rfl]
  rw [run_add, run_add, run_add]
  rw [run2_initialState]
  change (run 1 (run 9 (run 64 (macHiddenEntry input Hidden16.zero 0)))).output = mlpFixed input
  rw [hidden_layer_64steps]
  rw [macOutput_9steps]
  change (step (biasOutputEntry input (hiddenFixed input) (macOutputAcc (hiddenFixed input)))).output =
    mlpFixed input
  rw [biasOutput_outputMac_1step]
  simp [doneEntry, mlpFixed, finalOutputAcc, outputScoreFixed]

end MlpCoreSmt
