import TinyMLP.Invariants

namespace TinyMLP

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

structure ControlState where
  phase : Phase
  hiddenIdx : Nat
  inputIdx : Nat
deriving Repr, DecidableEq

def controlStep (cs : ControlState) : ControlState :=
  match cs.phase with
  | .idle =>
      { cs with phase := .loadInput }
  | .loadInput =>
      { phase := .macHidden, hiddenIdx := 0, inputIdx := 0 }
  | .macHidden =>
      if cs.inputIdx < inputCount then
        { cs with inputIdx := cs.inputIdx + 1 }
      else
        { cs with phase := .biasHidden }
  | .biasHidden =>
      { cs with phase := .actHidden }
  | .actHidden =>
      { cs with inputIdx := 0, phase := .nextHidden }
  | .nextHidden =>
      if cs.hiddenIdx + 1 < hiddenCount then
        { cs with hiddenIdx := cs.hiddenIdx + 1, phase := .macHidden }
      else
        { phase := .macOutput, hiddenIdx := 0, inputIdx := 0 }
  | .macOutput =>
      if cs.inputIdx < hiddenCount then
        { cs with inputIdx := cs.inputIdx + 1 }
      else
        { cs with phase := .biasOutput }
  | .biasOutput =>
      { cs with phase := .done }
  | .done => cs

def controlRun : Nat → ControlState → ControlState
  | 0, cs => cs
  | n + 1, cs => controlRun n (controlStep cs)

def controlOf (s : State) : ControlState :=
  { phase := s.phase, hiddenIdx := s.hiddenIdx, inputIdx := s.inputIdx }

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
  Acc32.ofInt (hiddenDotAt8 input j)

private def biasHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := hiddenMacAcc input j,
    hiddenIdx := j, inputIdx := inputCount, phase := .biasHidden, output := false }

private def hiddenPreAcc (input : Input8) (j : Nat) : Acc32 :=
  Acc32.ofInt (hiddenPreAt8 input j)

private def actHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := hiddenPreAcc input j,
    hiddenIdx := j, inputIdx := inputCount, phase := .actHidden, output := false }

private def nextHiddenEntry (input : Input8) (hidden : Hidden16) (j : Nat) : State :=
  { regs := input, hidden := hidden, accumulator := Acc32.zero,
    hiddenIdx := j, inputIdx := 0, phase := .nextHidden, output := false }

private def macOutputSum (hidden : Hidden16) : Int :=
  hidden.h0 * w2At 0 + hidden.h1 * w2At 1 +
  hidden.h2 * w2At 2 + hidden.h3 * w2At 3 +
  hidden.h4 * w2At 4 + hidden.h5 * w2At 5 +
  hidden.h6 * w2At 6 + hidden.h7 * w2At 7

private def macOutputAcc (hidden : Hidden16) : Acc32 :=
  Acc32.ofInt (macOutputSum hidden)

private def macOutputEntry (input : Input8) (hidden : Hidden16) : State :=
  { regs := input, hidden := hidden, accumulator := Acc32.zero,
    hiddenIdx := 0, inputIdx := 0, phase := .macOutput, output := false }

private def biasOutputEntry (input : Input8) (hidden : Hidden16) (acc : Acc32) : State :=
  { regs := input, hidden := hidden, accumulator := acc,
    hiddenIdx := 0, inputIdx := hiddenCount, phase := .biasOutput, output := false }

private def finalOutputAcc (hidden : Hidden16) : Acc32 :=
  Acc32.ofInt (outputScoreSpecFromHidden16 hidden)

private def doneEntry (input : Input8) (hidden : Hidden16) (acc : Acc32) : State :=
  { regs := input, hidden := hidden, accumulator := acc,
    hiddenIdx := 0, inputIdx := hiddenCount,
    phase := .done, output := decide (acc.toInt > 0) }

@[simp] private theorem hiddenMacAcc_toInt (input : Input8) (j : Nat) :
    (hiddenMacAcc input j).toInt = wrap32 (hiddenDotAt8 input j) := by
  rfl

@[simp] private theorem hiddenPreAcc_toInt (input : Input8) (j : Nat) :
    (hiddenPreAcc input j).toInt = wrap32 (hiddenPreAt8 input j) := by
  rfl

@[simp] private theorem macOutputAcc_toInt (hidden : Hidden16) :
    (macOutputAcc hidden).toInt = wrap32 (macOutputSum hidden) := by
  rfl

@[simp] private theorem finalOutputAcc_toInt (hidden : Hidden16) :
    (finalOutputAcc hidden).toInt = wrap32 (outputScoreSpecFromHidden16 hidden) := by
  rfl

-- MAC inner loop: 5 steps from macHidden entry to biasHidden
theorem macHidden_5steps (input : Input8) (hidden : Hidden16) (j : Nat) :
    run 5 (macHiddenEntry input hidden j) = biasHiddenEntry input hidden j := by
  cases input with
  | mk x0 x1 x2 x3 =>
      let target : State :=
        { regs := { x0 := x0, x1 := x1, x2 := x2, x3 := x3 }, hidden := hidden,
          accumulator := Acc32.ofInt (w1At j 0 * x0.toInt + w1At j 1 * x1.toInt +
            w1At j 2 * x2.toInt + w1At j 3 * x3.toInt),
          hiddenIdx := j, inputIdx := inputCount,
          phase := .biasHidden, output := false }
      have hrun :
          run 5 (macHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j) = target := by
        simp [target, macHiddenEntry, run, step, inputCount, acc32, mul8x8To16, Input8.getNat,
          Acc32.zero, Acc32.ofInt]
      change
        run 5 (macHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j) =
          biasHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j
      exact hrun.trans (by rfl)

private theorem hiddenSet_from_wrap32_pre (input : Input8) (hidden : Hidden16) (j : Nat)
    (hpre : wrap32 (hiddenPreAt8 input j) = hiddenPreAt8 input j) :
    hidden.setNat j (if wrap32 (hiddenPreAt8 input j) < 0 then 0 else wrap32 (hiddenPreAt8 input j)) =
      hidden.setNat j (hiddenSpecAt8 input j) := by
  simpa [hiddenSpecAt8, hiddenPreAt8, relu] using
    congrArg (fun x => hidden.setNat j (if x < 0 then 0 else x)) hpre

private theorem step_biasHidden_observe (input : Input8) (hidden : Hidden16) (j : Nat) :
    step (biasHiddenEntry input hidden j) = actHiddenEntry input hidden j := by
  cases input with
  | mk x0 x1 x2 x3 =>
      let mid : State :=
        { regs := { x0 := x0, x1 := x1, x2 := x2, x3 := x3 }, hidden := hidden,
          accumulator := Acc32.ofInt (hiddenDotAt8 { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } j + b1At j),
          hiddenIdx := j, inputIdx := inputCount,
          phase := .actHidden, output := false }
      let target : State :=
        { regs := { x0 := x0, x1 := x1, x2 := x2, x3 := x3 }, hidden := hidden,
          accumulator := Acc32.ofInt (w1At j 0 * x0.toInt + w1At j 1 * x1.toInt +
            w1At j 2 * x2.toInt + w1At j 3 * x3.toInt + b1At j),
          hiddenIdx := j, inputIdx := inputCount,
          phase := .actHidden, output := false }
      have hstep :
          step (biasHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j) = mid := by
        simp [mid, biasHiddenEntry, step, hiddenMacAcc, inputCount, acc32, Acc32.ofInt]
      have hdot :
          hiddenDotAt8 { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } j =
            w1At j 0 * x0.toInt + w1At j 1 * x1.toInt +
            w1At j 2 * x2.toInt + w1At j 3 * x3.toInt := by
        rfl
      have hdotMath :
          hiddenDotAt (toMathInput { x0 := x0, x1 := x1, x2 := x2, x3 := x3 }) j =
            w1At j 0 * x0.toInt + w1At j 1 * x1.toInt +
            w1At j 2 * x2.toInt + w1At j 3 * x3.toInt := by
        rfl
      have hmid : mid = target := by
        simp [mid, target, hdotMath]
      change
        step (biasHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j) =
          actHiddenEntry { x0 := x0, x1 := x1, x2 := x2, x3 := x3 } hidden j
      exact hstep.trans (hmid.trans (by rfl))

private theorem step_actHidden_observe (input : Input8) (hidden : Hidden16) (j : Nat)
    (hpre : wrap32 (hiddenPreAt8 input j) = hiddenPreAt8 input j) :
    step (actHiddenEntry input hidden j) =
      nextHiddenEntry input (hidden.setNat j (hiddenSpecAt8 input j)) j := by
  simpa only [actHiddenEntry, nextHiddenEntry, step, relu16, hiddenPreAcc, Acc32.zero] using
    congrArg
      (fun h : Hidden16 =>
        ({ regs := input, hidden := h, accumulator := Acc32.zero,
           hiddenIdx := j, inputIdx := 0, phase := .nextHidden, output := false } : State))
      (hiddenSet_from_wrap32_pre input hidden j hpre)

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
    macHiddenEntry input (hidden.setNat j (hiddenSpecAt8 input j)) (j + 1) := by
  have hjcases : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3 ∨ j = 4 ∨ j = 5 ∨ j = 6 := by
    unfold hiddenCount at hj
    omega
  rcases hjcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 0
      (wrap32_hiddenPreAt8_0 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 0 (hiddenSpecAt8 input 0)) 0 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 1
      (wrap32_hiddenPreAt8_1 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 1 (hiddenSpecAt8 input 1)) 1 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 2
      (wrap32_hiddenPreAt8_2 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 2 (hiddenSpecAt8 input 2)) 2 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 3
      (wrap32_hiddenPreAt8_3 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 3 (hiddenSpecAt8 input 3)) 3 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 4
      (wrap32_hiddenPreAt8_4 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 4 (hiddenSpecAt8 input 4)) 4 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 5
      (wrap32_hiddenPreAt8_5 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 5 (hiddenSpecAt8 input 5)) 5 hj
  · simp [run, step_biasHidden_observe, step_actHidden_observe input hidden 6
      (wrap32_hiddenPreAt8_6 input)]
    simpa using step_nextHidden_continue input (hidden.setNat 6 (hiddenSpecAt8 input 6)) 6 hj

-- Bias + Act + Next for j = 7: 3 steps, transitions to macOutput
theorem bias_act_next_last_3steps (input : Input8) (hidden : Hidden16) :
    run 3 (biasHiddenEntry input hidden 7) =
    macOutputEntry input (hidden.setNat 7 (hiddenSpecAt8 input 7)) := by
  simp [run, step_biasHidden_observe, step_nextHidden_finish,
    step_actHidden_observe input hidden 7 (wrap32_hiddenPreAt8_7 input)]

-- One full neuron (8 cycles), j < 7
theorem one_hidden_neuron_8steps (input : Input8) (hidden : Hidden16) (j : Nat)
    (hj : j + 1 < hiddenCount) :
    run 8 (macHiddenEntry input hidden j) =
    macHiddenEntry input (hidden.setNat j (hiddenSpecAt8 input j)) (j + 1) := by
  rw [show (8 : Nat) = 5 + 3 from rfl, run_add]
  rw [macHidden_5steps]
  exact bias_act_next_3steps input hidden j hj

-- Last neuron (8 cycles), j = 7
theorem last_hidden_neuron_8steps (input : Input8) (hidden : Hidden16) :
    run 8 (macHiddenEntry input hidden 7) =
    { regs := input, hidden := hidden.setNat 7 (hiddenSpecAt8 input 7),
      accumulator := Acc32.zero, hiddenIdx := 0, inputIdx := 0,
      phase := .macOutput, output := false } := by
  rw [show (8 : Nat) = 5 + 3 from rfl, run_add]
  rw [macHidden_5steps]
  exact bias_act_next_last_3steps input hidden

-- Chain of setNat builds hiddenSpec
theorem progressive_hidden_build (input : Input8) :
    ((((((((Hidden16.zero).setNat 0 (hiddenSpecAt8 input 0)).setNat
      1 (hiddenSpecAt8 input 1)).setNat
      2 (hiddenSpecAt8 input 2)).setNat
      3 (hiddenSpecAt8 input 3)).setNat
      4 (hiddenSpecAt8 input 4)).setNat
      5 (hiddenSpecAt8 input 5)).setNat
      6 (hiddenSpecAt8 input 6)).setNat
      7 (hiddenSpecAt8 input 7)
    = Hidden16.ofHidden (hiddenSpec8 input) := by
  cases input <;> rfl

-- Full hidden layer: 64 cycles
-- Compose 8 neuron lemmas via run_add

private theorem hidden_neurons_0_to_1 (input : Input8) :
    run 8 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)) 1 :=
  one_hidden_neuron_8steps input Hidden16.zero 0 (by decide)

private theorem hidden_neurons_0_to_2 (input : Input8) :
    run 16 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)) 2 := by
  rw [show (16 : Nat) = 8 + 8 from rfl, run_add, hidden_neurons_0_to_1]
  exact one_hidden_neuron_8steps input _ 1 (by decide)

private theorem hidden_neurons_0_to_3 (input : Input8) :
    run 24 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)).setNat
        2 (hiddenSpecAt8 input 2)) 3 := by
  rw [show (24 : Nat) = 16 + 8 from rfl, run_add, hidden_neurons_0_to_2]
  exact one_hidden_neuron_8steps input _ 2 (by decide)

private theorem hidden_neurons_0_to_4 (input : Input8) :
    run 32 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)).setNat
        2 (hiddenSpecAt8 input 2)).setNat
        3 (hiddenSpecAt8 input 3)) 4 := by
  rw [show (32 : Nat) = 24 + 8 from rfl, run_add, hidden_neurons_0_to_3]
  exact one_hidden_neuron_8steps input _ 3 (by decide)

private theorem hidden_neurons_0_to_5 (input : Input8) :
    run 40 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)).setNat
        2 (hiddenSpecAt8 input 2)).setNat
        3 (hiddenSpecAt8 input 3)).setNat
        4 (hiddenSpecAt8 input 4)) 5 := by
  rw [show (40 : Nat) = 32 + 8 from rfl, run_add, hidden_neurons_0_to_4]
  exact one_hidden_neuron_8steps input _ 4 (by decide)

private theorem hidden_neurons_0_to_6 (input : Input8) :
    run 48 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      ((((((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)).setNat
        2 (hiddenSpecAt8 input 2)).setNat
        3 (hiddenSpecAt8 input 3)).setNat
        4 (hiddenSpecAt8 input 4)).setNat
        5 (hiddenSpecAt8 input 5)) 6 := by
  rw [show (48 : Nat) = 40 + 8 from rfl, run_add, hidden_neurons_0_to_5]
  exact one_hidden_neuron_8steps input _ 5 (by decide)

private theorem hidden_neurons_0_to_7 (input : Input8) :
    run 56 (macHiddenEntry input Hidden16.zero 0) =
    macHiddenEntry input
      (((((((Hidden16.zero.setNat 0 (hiddenSpecAt8 input 0)).setNat
        1 (hiddenSpecAt8 input 1)).setNat
        2 (hiddenSpecAt8 input 2)).setNat
        3 (hiddenSpecAt8 input 3)).setNat
        4 (hiddenSpecAt8 input 4)).setNat
        5 (hiddenSpecAt8 input 5)).setNat
        6 (hiddenSpecAt8 input 6)) 7 := by
  rw [show (56 : Nat) = 48 + 8 from rfl, run_add, hidden_neurons_0_to_6]
  exact one_hidden_neuron_8steps input _ 6 (by decide)

theorem hidden_layer_64steps (input : Input8) :
    run 64 (macHiddenEntry input Hidden16.zero 0) =
    macOutputEntry input (Hidden16.ofHidden (hiddenSpec8 input)) := by
  rw [show (64 : Nat) = 56 + 8 from rfl, run_add, hidden_neurons_0_to_7]
  rw [last_hidden_neuron_8steps]
  rw [progressive_hidden_build]
  rfl

-- Output MAC: 9 cycles (8 MAC iterations + 1 exit to biasOutput)
-- The accumulator naturally computes: hidden.hN * w2At N (note operand order)
theorem macOutput_9steps (input : Input8) (hidden : Hidden16) :
    run 9 (macOutputEntry input hidden) =
    biasOutputEntry input hidden (macOutputAcc hidden) := by
  simp [macOutputEntry, biasOutputEntry, run, step, hiddenCount, macOutputAcc, macOutputSum,
    acc32, mul16x8To24, Hidden16.getNat, Acc32.zero, Acc32.ofInt]

-- Connect the natural accumulation order to the spec.
private theorem macOutput_acc_eq_spec (hidden : Hidden16) :
    macOutputSum hidden + b2 =
    outputScoreSpecFromHidden16 hidden := by
  simp [macOutputSum, outputScoreSpecFromHidden16, b2]
  simp only [Int.mul_comm (w2At 0) hidden.h0, Int.mul_comm (w2At 1) hidden.h1,
             Int.mul_comm (w2At 2) hidden.h2, Int.mul_comm (w2At 3) hidden.h3,
             Int.mul_comm (w2At 4) hidden.h4, Int.mul_comm (w2At 5) hidden.h5,
             Int.mul_comm (w2At 6) hidden.h6, Int.mul_comm (w2At 7) hidden.h7]

-- Final step: biasOutput → done (1 cycle)
theorem biasOutput_1step (input : Input8) (hidden : Hidden16) (acc : Acc32) :
    step (biasOutputEntry input hidden acc) =
    doneEntry input hidden (Acc32.ofInt (acc.toInt + b2)) := by
  simp [biasOutputEntry, doneEntry, step, acc32, b2, Acc32.ofInt]

private theorem biasOutput_outputMac_1step (input : Input8) (hidden : Hidden16) :
    step (biasOutputEntry input hidden (macOutputAcc hidden)) =
    doneEntry input hidden (finalOutputAcc hidden) := by
  rw [biasOutput_1step]
  have hacc : Acc32.ofInt ((macOutputAcc hidden).toInt + b2) = finalOutputAcc hidden := by
    change ({ toInt := wrap32 (wrap32 (macOutputSum hidden) + b2) } : Acc32) =
      ({ toInt := wrap32 (outputScoreSpecFromHidden16 hidden) } : Acc32)
    rw [wrap32_add_wrap32, macOutput_acc_eq_spec]
  simpa [doneEntry] using congrArg (doneEntry input hidden) hacc

-- Main correctness assembly
theorem rtl_correct (input : Input8) :
    (run totalCycles (initialState input)).output = mlpFixed input := by
  rw [show totalCycles = 2 + 64 + 9 + 1 from rfl]
  rw [run_add, run_add, run_add]
  rw [run2_initialState]
  change (run 1 (run 9 (run 64 (macHiddenEntry input Hidden16.zero 0)))).output = mlpFixed input
  rw [hidden_layer_64steps]
  rw [macOutput_9steps]
  change (step (biasOutputEntry input (Hidden16.ofHidden (hiddenSpec8 input))
    (macOutputAcc (Hidden16.ofHidden (hiddenSpec8 input))))).output = mlpFixed input
  rw [biasOutput_outputMac_1step]
  change
    decide ((finalOutputAcc (Hidden16.ofHidden (hiddenSpec8 input))).toInt > 0) =
      decide (outputScoreSpecFromHidden (hiddenFixed input) > 0)
  rw [finalOutputAcc_toInt, outputScoreSpecFromHidden16_ofHidden_hiddenSpec8, wrap32_outputScoreSpec8]
  simp [outputScoreSpec]

end TinyMLP
