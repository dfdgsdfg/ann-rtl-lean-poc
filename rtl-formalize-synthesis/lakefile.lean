import Lake
open Lake DSL

package rtlFormalizeSynthesis where
  leanOptions := #[⟨`autoImplicit, false⟩]

require tinymlp from "../formalize"

require Sparkle from "vendor/Sparkle"

@[default_target]
lean_lib TinyMLPSparkle where
  srcDir := "src"
