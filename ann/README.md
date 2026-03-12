# ANN How-To

This folder owns the parameter-generation flow for the tiny `4 -> 8 -> 1` MLP.

If you only need to use it, start with the wrapper:

```bash
./scripts/ann.sh --help
```

## What This Domain Produces

The ANN flow trains a toy model, selects one quantized checkpoint, and freezes that result for the rest of the repository.

Main outputs:

- `ann/results/latest/weights_quantized.json`
- `ann/results/latest/weights_float_selected.json`
- `ann/results/latest/weights_float.json`
- `ann/results/latest/metrics.json`
- `ann/results/latest/training_summary.md`
- `contract/result/weights.json`

`contract/result/weights.json` is the canonical downstream export.

## Most Common Commands

Train and refresh downstream artifacts:

```bash
./scripts/ann.sh train
```

Train into a separate run directory without touching the frozen contract:

```bash
./scripts/ann.sh train --out-dir ann/results/tmp/run_001 --skip-export
```

Evaluate the currently selected quantized result:

```bash
./scripts/ann.sh evaluate --artifact quantized
```

Evaluate the float-shadow checkpoint that produced the selected quantized result:

```bash
./scripts/ann.sh evaluate --artifact selected-float
```

Print machine-readable metrics:

```bash
./scripts/ann.sh evaluate --artifact quantized --json
```

Re-derive quantized weights from the selected float-shadow artifact:

```bash
./scripts/ann.sh quantize --artifact selected-float
```

Freeze a run into the canonical contract export:

```bash
./scripts/ann.sh export --run-dir ann/results/latest
```

## Typical Human Workflow

1. Run `./scripts/ann.sh train`
2. Check `ann/results/latest/training_summary.md`
3. Run `./scripts/ann.sh evaluate --artifact quantized`
4. If you trained into a custom run directory, freeze it with `./scripts/ann.sh export --run-dir ...`

## Artifact Meanings

- `weights_quantized.json`: integer weights used by hardware-facing flows
- `weights_float_selected.json`: full-precision shadow of the checkpoint chosen by quantized validation
- `weights_float.json`: best float checkpoint by float validation metrics
- `metrics.json`: dataset metadata, training config, selected checkpoint data, and full epoch history
- `training_summary.md`: short human-readable summary

## Defaults

Repository defaults:

- dataset seed: `20260312`
- input range: `[-16, 15]`
- train / validation size: `512 / 128`
- optimizer: `Adam`
- batch size: `64`
- epoch budget: `300`
- early stopping patience: `20`
- quantization: round half away from zero, then signed clipping

## Notes

- `evaluate` and `quantize` use `ann/results/selected_run.json` when you do not pass `--run-dir`.
- `train` updates `contract/result/weights.json` unless you pass `--skip-export`.
- `train --out-dir` may point outside the repository only when combined with `--skip-export`.
- `scripts/ann.sh` is the preferred entrypoint. The Python modules in `ann/src` are implementation details.
