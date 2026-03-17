#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROOF_CONFIG = ROOT / "rtl-formalize-synthesis" / "src" / "MlpCoreSparkle" / "ProofConfig.lean"

LANE_CONFIG = {
    "vanilla": {
        "imports": ["MlpCore"],
        "namespace": "MlpCore",
        "package": "formalize",
        "provider": "MlpCore.vanillaArithmeticProofProvider",
        "trust_profile": "vendor-loop-unfold-plus-nextstate-bridge",
        "trust_note": (
            "Actual Sparkle synth-path refinement relies on vendored Sparkle's local "
            "`Signal.loop_unfold` axiom plus one local axiom bridging the pure encoded "
            "next-state network to `timedStep`."
        ),
    },
    "smt": {
        "imports": ["MlpCore", "MlpCoreSmt"],
        "namespace": "MlpCoreSmt",
        "package": "formalize-smt",
        "provider": "MlpCoreSmt.smtArithmeticProofProvider",
        "trust_profile": "optional_solver_backed",
        "trust_note": (
            "Optional SMT-backed Lean proof lane backed by formalize-smt; upstream lean-smt currently builds "
            "with a sorry warning."
        ),
    },
}


def render_proof_config(proof_lane: str) -> str:
    config = LANE_CONFIG[proof_lane]
    import_block = "\n".join(f"import {module_name}" for module_name in config["imports"])
    export_namespace = config["namespace"]
    return f"""{import_block}
import MlpCore.Interfaces.ArithmeticProofProvider

namespace MlpCoreSparkle.ProofConfig

export {export_namespace} (IndexInvariant rtlTrace_preserves_indexInvariant controlOf_rtlTrace)

def selectedProofLane : String := "{proof_lane}"

def selectedProofNamespace : String := "{config["namespace"]}"

def selectedProofPackage : String := "{config["package"]}"

def selectedArithmeticProviderDecl : String := "{config["provider"]}"

def selectedTrustProfile : String := "{config["trust_profile"]}"

def selectedTrustNote : String := "{config["trust_note"]}"

abbrev selectedArithmeticProofProvider : MlpCore.ArithmeticProofProvider :=
  {config["provider"]}

end MlpCoreSparkle.ProofConfig
"""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Configure the rtl-formalize-synthesis Lean proof lane.")
    parser.add_argument("--proof-lane", choices=sorted(LANE_CONFIG), required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    PROOF_CONFIG.write_text(render_proof_config(args.proof_lane), encoding="utf-8")
    print(PROOF_CONFIG)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
