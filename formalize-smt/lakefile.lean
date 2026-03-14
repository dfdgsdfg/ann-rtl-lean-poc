import Lake

open Lake DSL System

package tinymlp_smt where
  leanOptions := #[⟨`autoImplicit, false⟩]

require tinymlp from "../formalize"

require smt from git
  "https://github.com/ufmg-smite/lean-smt.git" @ "e556db814854fbd2e69d10adb25abf3518376154"

@[default_target]
lean_lib TinyMLPSmt where
  srcDir := "src"

private def toolExists (tool : String) : IO Bool := do
  let finder := if Platform.isWindows then "where" else "which"
  let out ← IO.Process.output {
    cmd := finder
    args := #[tool]
  }
  pure (out.exitCode == 0)

private def cvc5PayloadDirs : IO (Array FilePath) := do
  let root := FilePath.mk ".lake/packages/cvc5"
  if !(← root.pathExists) then
    return #[]
  let entries ← root.readDir
  return entries.foldl (init := #[]) fun acc entry =>
    if entry.fileName.startsWith "cvc5-" && entry.fileName != "cvc5" then
      acc.push entry.path
    else
      acc

script doctor do
  let mut missing : Array String := #[]
  let archiveTool := if Platform.isOSX || Platform.isWindows then "tar" else "unzip"
  let hasClang ← toolExists "clang"
  let hasArchiveTool ← toolExists archiveTool
  if !hasClang then
    missing := missing.push "clang"
  if !hasArchiveTool then
    missing := missing.push archiveTool

  IO.println "formalize-smt doctor"
  IO.println s!"- clang: {if hasClang then "found" else "missing"}"
  IO.println s!"- archive tool ({archiveTool}): {if hasArchiveTool then "found" else "missing"}"

  let payloads ← cvc5PayloadDirs
  if payloads.isEmpty then
    IO.println "- cvc5 payload: not present; first SMT build will download the pinned release archive"
  else
    for payload in payloads do
      IO.println s!"- cvc5 payload: present at {payload}"

  if missing.isEmpty then
    IO.println "- result: ok"
    return 0
  else
    IO.eprintln s!"- result: missing required tools: {String.intercalate ", " missing.toList}"
    return 1
