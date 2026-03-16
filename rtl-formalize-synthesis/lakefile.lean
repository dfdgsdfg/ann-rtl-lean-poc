import Lake
open Lake DSL

package rtlFormalizeSynthesis where
  leanOptions := #[⟨`autoImplicit, false⟩]

require mlpcore from "../formalize"

require Sparkle from "vendor/Sparkle"

@[default_target]
lean_lib MlpCoreSparkle where
  srcDir := "src"
