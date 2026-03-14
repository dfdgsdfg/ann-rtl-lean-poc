import Lake
open Lake DSL

package rtlFormalizeSynthesis where
  leanOptions := #[⟨`autoImplicit, false⟩]

require tinymlp from "../formalize"

require Sparkle from git
  "https://github.com/Verilean/sparkle" @ "2d3dda875b0aa12d850322f26a2c42a9379931c8"

@[default_target]
lean_lib TinyMLPSparkle where
  srcDir := "src"
