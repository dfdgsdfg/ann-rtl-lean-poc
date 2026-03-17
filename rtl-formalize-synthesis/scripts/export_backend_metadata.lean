import Lean
import Sparkle.Backend.Verilog
import Sparkle.Compiler.Elab
import MlpCoreSparkle
import MlpCoreSparkle.ProofConfig

open Lean

private def jsonEscape (text : String) : String :=
  let escapedBackslash := text.replace "\\" "\\\\"
  let escapedQuote := escapedBackslash.replace "\"" "\\\""
  let escapedNewline := escapedQuote.replace "\n" "\\n"
  let escapedReturn := escapedNewline.replace "\r" "\\r"
  escapedReturn.replace "\t" "\\t"

private def exactEmitDecl : Name := ``MlpCore.Sparkle.sparkleMlpCorePacked

def main (_args : List String) : IO UInt32 := do
  let env ← Lean.importModules #[{ module := `MlpCoreSparkle }] {} (trustLevel := 1024)
  let coreCtx : Lean.Core.Context := { fileName := "<export_backend_metadata>", fileMap := default }
  let coreState : Lean.Core.State := { env := env }
  let (design, _, _) ← Lean.Meta.MetaM.toIO
    (Sparkle.Compiler.Elab.synthesizeHierarchical exactEmitDecl)
    coreCtx coreState
  let designRepr := reprStr design
  let verilog := Sparkle.Backend.Verilog.toVerilogDesign design
  let payload :=
    "{\n" ++
    s!"  \"decl_name\": \"{jsonEscape exactEmitDecl.toString}\",\n" ++
    s!"  \"typed_backend_ir\": \"Sparkle.IR.AST.Design\",\n" ++
    s!"  \"top_module\": \"{jsonEscape design.topModule}\",\n" ++
    s!"  \"module_count\": {design.modules.length},\n" ++
    s!"  \"proof_lane\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedProofLane}\",\n" ++
    s!"  \"proof_namespace\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedProofNamespace}\",\n" ++
    s!"  \"proof_package\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedProofPackage}\",\n" ++
    s!"  \"arithmetic_provider\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedArithmeticProviderDecl}\",\n" ++
    s!"  \"trust_profile\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedTrustProfile}\",\n" ++
    s!"  \"trust_note\": \"{jsonEscape MlpCoreSparkle.ProofConfig.selectedTrustNote}\",\n" ++
    s!"  \"design_repr\": \"{jsonEscape designRepr}\",\n" ++
    s!"  \"verilog_text\": \"{jsonEscape verilog}\"\n" ++
    "}"
  IO.println payload
  return 0
