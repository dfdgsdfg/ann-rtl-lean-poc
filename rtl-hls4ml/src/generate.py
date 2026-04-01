"""Generate Verilog for the 4->8->1 MLP using hls4ml from frozen contract weights."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_WEIGHTS = ROOT / "contract" / "results" / "canonical" / "weights.json"


def load_contract_weights(path: Path = CONTRACT_WEIGHTS) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_keras_model(weights: dict):
    """Build a Keras model matching the frozen contract architecture."""
    import tensorflow as tf

    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(4,)),
        tf.keras.layers.Dense(8, activation="relu", name="dense_hidden"),
        tf.keras.layers.Dense(1, activation="linear", name="dense_output"),
    ])

    w1 = np.array(weights["w1"], dtype=np.float32)
    b1 = np.array(weights["b1"], dtype=np.float32)
    w2 = np.array(weights["w2"], dtype=np.float32).reshape(8, 1)
    b2 = np.float32(weights["b2"])

    model.layers[0].set_weights([w1, b1])
    model.layers[1].set_weights([w2, np.array([b2])])
    return model


def generate_hls4ml_verilog(output_dir: Path, weights: dict | None = None) -> Path:
    """Generate Verilog from the frozen contract weights using hls4ml."""
    import hls4ml

    if weights is None:
        weights = load_contract_weights()

    model = build_keras_model(weights)

    hls_config = hls4ml.utils.config_from_keras_model(model, granularity="name")

    # Match contract arithmetic: int8 inputs/weights, int16 hidden, int32 accumulators
    hls_config["Model"]["Precision"] = "ap_fixed<8,8>"
    hls_config["Model"]["ReuseFactor"] = 1

    for layer_name in hls_config["LayerName"]:
        layer_cfg = hls_config["LayerName"][layer_name]
        if layer_name == "dense_hidden":
            layer_cfg["Precision"] = {
                "weight": "ap_fixed<8,8>",
                "bias": "ap_fixed<32,32>",
                "result": "ap_fixed<16,16>",
                "accum": "ap_fixed<32,32>",
            }
            layer_cfg["ReuseFactor"] = 1
        elif layer_name == "dense_output":
            layer_cfg["Precision"] = {
                "weight": "ap_fixed<8,8>",
                "bias": "ap_fixed<32,32>",
                "result": "ap_fixed<32,32>",
                "accum": "ap_fixed<32,32>",
            }
            layer_cfg["ReuseFactor"] = 1

    hls_model = hls4ml.converters.convert_from_keras_model(
        model,
        hls_config=hls_config,
        output_dir=str(output_dir / "hls4ml_project"),
        backend="Vivado",
        io_type="io_parallel",
    )

    hls_model.compile()
    hls_model.write()

    return output_dir / "hls4ml_project"


def copy_generated_artifacts(project_dir: Path, canonical_sv_dir: Path) -> list[Path]:
    """Copy the generated Verilog files to the canonical sv directory."""
    canonical_sv_dir.mkdir(parents=True, exist_ok=True)

    # hls4ml outputs firmware/ directory with HLS source
    firmware_dir = project_dir / "firmware"
    if not firmware_dir.exists():
        raise FileNotFoundError(f"hls4ml firmware directory not found: {firmware_dir}")

    copied: list[Path] = []
    # Copy the entire firmware source tree into canonical for reference
    dest_firmware = canonical_sv_dir / "firmware"
    if dest_firmware.exists():
        shutil.rmtree(dest_firmware)
    shutil.copytree(firmware_dir, dest_firmware)
    copied.append(dest_firmware)

    return copied
