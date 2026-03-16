# ANN How-To

This folder owns the parameter-generation flow for the tiny `4 -> 8 -> 1` MLP.

## What This Domain Produces

The ANN flow now has two result surfaces:

- local immutable runs under `ann/results/runs/<run_id>/`
- the checked-in canonical snapshot under `ann/results/canonical/`

Main local run outputs:

- `ann/results/runs/<run_id>/weights_quantized.json`
- `ann/results/runs/<run_id>/weights_float_selected.json`
- `ann/results/runs/<run_id>/weights_float.json`
- `ann/results/runs/<run_id>/metrics.json`
- `ann/results/runs/<run_id>/training_summary.md`
- `ann/results/runs/<run_id>/dataset_snapshot.jsonl`

Main canonical outputs:

- `ann/results/canonical/manifest.json`
- `ann/results/canonical/weights_quantized.json`
- `ann/results/canonical/weights_float_selected.json`
- `ann/results/canonical/weights_float.json`
- `ann/results/canonical/metrics.json`
- `ann/results/canonical/training_summary.md`
- `ann/results/canonical/dataset_snapshot.jsonl`
- `contract/results/canonical/weights.json`

`contract/results/canonical/weights.json` is the canonical downstream export.

## Most Common Commands

Train and refresh canonical downstream artifacts:

```bash
make train
```

Train into a separate local run directory without touching canonical snapshots:

```bash
make train ARGS="--out-dir ann/results/tmp/run_001 --skip-export"
```

Evaluate the canonical quantized result:

```bash
make evaluate ARGS="--artifact quantized"
```

Evaluate the canonical float-shadow checkpoint:

```bash
make evaluate ARGS="--artifact selected-float"
```

Print machine-readable metrics:

```bash
make evaluate ARGS="--artifact quantized --json"
```

Re-derive quantized weights from the canonical float-shadow artifact:

```bash
make quantize ARGS="--artifact selected-float"
```

Promote a local run into `ann/results/canonical/` and refresh the canonical contract:

```bash
make export ARGS="--run-dir ann/results/runs/relu_teacher_v2-seed20260312-epoch51"
```

## Typical Human Workflow

1. Run `make train`
2. Check `ann/results/canonical/manifest.json` and `ann/results/canonical/training_summary.md`
3. Run `make evaluate ARGS="--artifact quantized"`
4. If you trained into a custom run directory, promote it with `make export ARGS="--run-dir ..."`

## Artifact Meanings

- `weights_quantized.json`: integer weights used by hardware-facing flows
- `weights_float_selected.json`: full-precision shadow of the checkpoint chosen by quantized validation
- `weights_float.json`: best float checkpoint by float validation metrics
- `metrics.json`: dataset metadata, training config, selected checkpoint data, and full epoch history
- `training_summary.md`: short human-readable summary
- `manifest.json`: canonical provenance and default artifact paths

## Defaults

Repository defaults:

- dataset seed: `20260312`
- input range: `[-16, 15]`
- train / validation size: `512 / 128`
- optimizer: `Adam`
- batch size: `64`
- epoch budget: `300`
- canonical checked-in ANN snapshot: `ann/results/canonical/`
- early stopping patience: `20`
- quantization: round half away from zero, then signed clipping

## Notes

- `evaluate` and `quantize` use `ann/results/canonical/manifest.json` when you do not pass `--run-dir`.
- `train` writes a local run under `ann/results/runs/<run_id>/` and refreshes `ann/results/canonical/` plus `contract/results/canonical/` unless you pass `--skip-export`.
- `train --out-dir` may point outside the repository only when combined with `--skip-export`.
- The Makefile targets (`make train`, `make evaluate`, etc.) are the preferred entrypoint. The Python modules in `ann/src` are implementation details.
