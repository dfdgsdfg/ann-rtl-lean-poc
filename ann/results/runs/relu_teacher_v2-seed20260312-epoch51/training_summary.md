# Training Summary

- dataset version: `relu_teacher_v2`
- dataset seed: `20260312`
- train / val size: `512` / `128`
- epochs run: `71`
- selected epoch: `51`
- selected source: `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_quantized.json`
- selected float shadow: `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_float_selected.json`
- best float source: `ann/results/runs/relu_teacher_v2-seed20260312-epoch51/weights_float.json`
- val quant accuracy: `0.9844`
- val quant loss: `0.035726`
- selected shadow float accuracy: `0.8672`
- best float accuracy: `0.8984`
- quantized L1: `30`

The selected checkpoint is chosen from quantized validation metrics first,
with quantized `L1` magnitude used as the final tie-breaker.
