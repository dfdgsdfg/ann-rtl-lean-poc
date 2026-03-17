import Sparkle.Core.Signal

namespace MlpCore.Sparkle

abbrev stateWidth : Nat := 4
abbrev controllerPackedWidth : Nat := 14
abbrev mlpCorePackedWidth : Nat := 299
abbrev MlpCorePackedPayload :=
  BitVec stateWidth ×
    Bool ×
      Bool ×
        Bool ×
          Bool ×
            Bool ×
              Bool ×
                Bool ×
                  Bool ×
                    Bool ×
                      Bool ×
                        Bool ×
                          BitVec stateWidth ×
                            BitVec stateWidth ×
                              BitVec 32 ×
                                BitVec 32 ×
                                  BitVec 16 ×
                                    BitVec 32 ×
                                      BitVec 8 ×
                                        BitVec 8 ×
                                          BitVec 8 ×
                                            BitVec 8 ×
                                              BitVec 16 ×
                                                BitVec 16 ×
                                                  BitVec 16 ×
                                                    BitVec 16 ×
                                                      BitVec 16 ×
                                                        BitVec 16 ×
                                                          BitVec 16 × BitVec 16 × Bool × Bool × Bool × Bool

abbrev stIdle : BitVec stateWidth := 0#4
abbrev stLoadInput : BitVec stateWidth := 1#4
abbrev stMacHidden : BitVec stateWidth := 2#4
abbrev stBiasHidden : BitVec stateWidth := 3#4
abbrev stActHidden : BitVec stateWidth := 4#4
abbrev stNextHidden : BitVec stateWidth := 5#4
abbrev stMacOutput : BitVec stateWidth := 6#4
abbrev stBiasOutput : BitVec stateWidth := 7#4
abbrev stDone : BitVec stateWidth := 8#4

def packBoolBit (b : Bool) : BitVec 1 :=
  if b then 1#1 else 0#1

def packMlpCorePackedBits (payload : MlpCorePackedPayload) : BitVec mlpCorePackedWidth :=
  match payload with
  | (state, (load_input, (clear_acc, (do_mac_hidden, (do_bias_hidden, (do_act_hidden, (advance_hidden,
      (do_mac_output, (do_bias_output, (done, (busy, (out_bit, (hidden_idx, (input_idx, (acc_reg,
      (mac_acc_out, (mac_a, (b2_data, (input_reg0, (input_reg1, (input_reg2, (input_reg3,
      (hidden_reg0, (hidden_reg1, (hidden_reg2, (hidden_reg3, (hidden_reg4, (hidden_reg5,
      (hidden_reg6, (hidden_reg7, (hidden_input_case_hit, (output_hidden_case_hit,
      (hidden_weight_case_hit, output_weight_case_hit))))))))))))))))))))))))))))))))) =>
      state ++
        packBoolBit load_input ++
        packBoolBit clear_acc ++
        packBoolBit do_mac_hidden ++
        packBoolBit do_bias_hidden ++
        packBoolBit do_act_hidden ++
        packBoolBit advance_hidden ++
        packBoolBit do_mac_output ++
        packBoolBit do_bias_output ++
        packBoolBit done ++
        packBoolBit busy ++
        packBoolBit out_bit ++
        hidden_idx ++
        input_idx ++
        acc_reg ++
        mac_acc_out ++
        mac_a ++
        b2_data ++
        input_reg0 ++
        input_reg1 ++
        input_reg2 ++
        input_reg3 ++
        hidden_reg0 ++
        hidden_reg1 ++
        hidden_reg2 ++
        hidden_reg3 ++
        hidden_reg4 ++
        hidden_reg5 ++
        hidden_reg6 ++
        hidden_reg7 ++
        packBoolBit hidden_input_case_hit ++
        packBoolBit output_hidden_case_hit ++
        packBoolBit hidden_weight_case_hit ++
        packBoolBit output_weight_case_hit

end MlpCore.Sparkle
