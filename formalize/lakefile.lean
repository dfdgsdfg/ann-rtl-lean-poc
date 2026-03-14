import Lake
open Lake DSL

package tinymlp where
  leanOptions := #[⟨`autoImplicit, false⟩]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "v4.27.0"

@[default_target]
lean_lib TinyMLP where
  srcDir := "src"
