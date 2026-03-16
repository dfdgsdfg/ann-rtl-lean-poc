#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPARKLE_PROJECT_DIR = ROOT / "rtl-formalize-synthesis"
DEFAULT_MANIFEST = SPARKLE_PROJECT_DIR / "results" / "canonical" / "verification_manifest.json"
EXPORT_SCRIPT = SPARKLE_PROJECT_DIR / "scripts" / "export_backend_metadata.lean"
PATCH_PATH = SPARKLE_PROJECT_DIR / "patches" / "sparkle-local.patch"
SPARKLE_VENDOR_DIR = SPARKLE_PROJECT_DIR / "vendor" / "Sparkle"
SPARKLE_RAW_RTL = SPARKLE_PROJECT_DIR / "results" / "canonical" / "sv" / "sparkle_mlp_core.sv"
FEATURE_SLICE_CONSTRUCTS = [
    "Signal.loop",
    "Signal.pure",
    "hw_cond",
    "BitVec.append",
    "BitVec.extractLsb'",
    "BitVec.ult",
    "declare_signal_state",
]


def sha256_text(text: str) -> str:
    return f"sha256:{hashlib.sha256(text.encode('utf-8')).hexdigest()}"


def sha256_file(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def git_head_revision(repo_dir: Path) -> str:
    if not (repo_dir / ".git").exists():
        return "unknown"
    proc = subprocess.run(
        ["git", "-C", str(repo_dir), "rev-parse", "HEAD"],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return "unknown"
    return proc.stdout.strip() or "unknown"


def export_backend_metadata() -> dict[str, object]:
    proc = subprocess.run(
        ["lake", "env", "lean", "--run", str(EXPORT_SCRIPT)],
        cwd=SPARKLE_PROJECT_DIR,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(proc.stdout + proc.stderr)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"failed to parse backend metadata export: {exc}\n{proc.stdout}") from exc


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh the Sparkle verification manifest proof metadata.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    payload = json.loads(args.manifest.read_text(encoding="utf-8"))
    export = export_backend_metadata()

    design_repr = str(export["design_repr"])
    verilog_text = str(export["verilog_text"])
    payload["schema_version"] = 2
    payload["proof_endpoint"] = {
        "kind": "packed_signal_payload",
        "typed_backend_ir": str(export["typed_backend_ir"]),
        "lean_theorem": "TinyMLP.Sparkle.sparkleMlpCoreBackendPayload_refines_rtlTrace",
        "decl_name": str(export["decl_name"]),
    }
    payload["sparkle_feature_slice"] = {
        "compiler_entrypoint": "Sparkle.Compiler.Elab.synthesizeHierarchical",
        "backend_renderer": "Sparkle.Backend.Verilog.toVerilogDesign",
        "typed_backend_ir": str(export["typed_backend_ir"]),
        "constructs": FEATURE_SLICE_CONSTRUCTS,
        "emit_payload_shape": (
            "bundleAll![state, load_input, clear_acc, do_mac_hidden, do_bias_hidden, do_act_hidden, "
            "advance_hidden, do_mac_output, do_bias_output, done, busy, out_bit, hidden_idx, input_idx, "
            "acc_reg, mac_acc_out, mac_a, b2_data, input_reg0..input_reg3, hidden_reg0..hidden_reg7, "
            "hidden_input_case_hit, output_hidden_case_hit, hidden_weight_case_hit, output_weight_case_hit]"
        ),
    }
    payload["exact_emit_path"] = {
        "decl_name": str(export["decl_name"]),
        "vendor_revision": git_head_revision(SPARKLE_VENDOR_DIR),
        "local_patch_id": sha256_file(PATCH_PATH),
        "top_module": str(export["top_module"]),
        "module_count": int(export["module_count"]),
        "elaborated_design_fingerprint": sha256_text(design_repr),
        "backend_ast_fingerprint": sha256_text(design_repr),
        "verilog_render_fingerprint": sha256_text(verilog_text),
        "raw_artifact_fingerprint": sha256_file(SPARKLE_RAW_RTL) if SPARKLE_RAW_RTL.exists() else "missing",
    }

    args.manifest.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
