import TinyMLP.Defs.FixedPointCore
import TinyMLP.Defs.MachineCore

open System

namespace TinyMLP

def joinComma (items : List String) : String :=
  String.intercalate ", " items

def jsonString (value : String) : String :=
  "\"" ++ value ++ "\""

def jsonIntList (items : List Int) : String :=
  "[" ++ joinComma (items.map toString) ++ "]"

def jsonIntMatrix (rows : List (List Int)) : String :=
  "[" ++ joinComma (rows.map jsonIntList) ++ "]"

def w1Rows : List (List Int) :=
  (List.range hiddenCount).map fun hiddenIdx =>
    (List.range inputCount).map fun inputIdx =>
      w1At hiddenIdx inputIdx

def b1Rows : List Int :=
  (List.range hiddenCount).map b1At

def w2Rows : List Int :=
  (List.range hiddenCount).map w2At

def semanticBridgeJson : String :=
  "{\n" ++
  "  \"artifact_kind\": " ++ jsonString "lean_fixed_point_bridge" ++ ",\n" ++
  "  \"source_module\": " ++ jsonString "TinyMLP" ++ ",\n" ++
  "  \"topology\": {\n" ++
  "    \"input_size\": " ++ toString inputCount ++ ",\n" ++
  "    \"hidden_size\": " ++ toString hiddenCount ++ ",\n" ++
  "    \"output_size\": 1\n" ++
  "  },\n" ++
  "  \"arithmetic\": {\n" ++
  "    \"input_bits\": 8,\n" ++
  "    \"hidden_product_bits\": 16,\n" ++
  "    \"hidden_activation_bits\": 16,\n" ++
  "    \"output_weight_bits\": 8,\n" ++
  "    \"output_product_bits\": 24,\n" ++
  "    \"accumulator_bits\": 32,\n" ++
  "    \"overflow\": " ++ jsonString "two_complement_wraparound" ++ ",\n" ++
  "    \"sign_extension\": " ++ jsonString "required_between_product_and_accumulator_stages" ++ ",\n" ++
  "    \"hidden_activation_semantics\": " ++ jsonString "relu_then_wrap16" ++ ",\n" ++
  "    \"decision_rule\": " ++ jsonString "score_gt_zero" ++ "\n" ++
  "  },\n" ++
  "  \"schedule\": {\n" ++
  "    \"total_cycles\": " ++ toString totalCycles ++ ",\n" ++
  "    \"start_to_load_input_cycles\": 1,\n" ++
  "    \"load_input_to_mac_hidden_cycles\": 1,\n" ++
  "    \"hidden_cycles_per_neuron\": 8,\n" ++
  "    \"output_cycles\": 10\n" ++
  "  },\n" ++
  "  \"weights\": {\n" ++
  "    \"w1\": " ++ jsonIntMatrix w1Rows ++ ",\n" ++
  "    \"b1\": " ++ jsonIntList b1Rows ++ ",\n" ++
  "    \"w2\": " ++ jsonIntList w2Rows ++ ",\n" ++
  "    \"b2\": " ++ toString b2 ++ "\n" ++
  "  }\n" ++
  "}\n"

def runMain (args : List String) : IO UInt32 := do
  let outputPath <- match args with
    | path :: _ => pure path
    | [] => throw <| IO.userError "expected output path argument"
  match (FilePath.mk outputPath).parent with
  | some parent => IO.FS.createDirAll parent
  | none => pure ()
  IO.FS.writeFile outputPath semanticBridgeJson
  pure 0

end TinyMLP

def main (args : List String) : IO UInt32 :=
  TinyMLP.runMain args
