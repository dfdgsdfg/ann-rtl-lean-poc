# Custom AI ASIC Research Overview

Date: 2026-03-12

## Scope

This document set tracks the current state of custom AI ASICs only.

It intentionally excludes:

- GPUs
- FPGAs
- general-purpose CPUs
- purely software-only optimization work

The notes are separated by practical design center, not strict taxonomy:

- `ANN` here means classical or small-footprint neural-network ASICs, especially dense/sensor/audio/always-on designs
- `CNN` means convolution-dominant vision ASICs for edge inference
- `DL` means broader deep-learning ASICs that target multiple workload families
- `LLM` means transformer-centric generative AI ASICs

Because `CNN` is a subset of `DL`, and `LLM` is also a `DL` workload, some overlap is unavoidable. The split is meant to reduce duplication while keeping each market and technology story readable.

## Document Map

- [ann-asic-status.md](./ann-asic-status.md)
- [cnn-asic-status.md](./cnn-asic-status.md)
- [dl-asic-status.md](./dl-asic-status.md)
- [llm-asic-status.md](./llm-asic-status.md)

## Executive Summary

The center of gravity in custom AI ASICs has moved hard toward memory-centric designs.

- In edge ASICs, the key problem is still avoiding DRAM traffic and fitting useful models into tight on-chip memory and power envelopes.
- In cloud ASICs, the key problem is no longer raw multiply-accumulate density by itself; it is HBM capacity, HBM bandwidth, chip-to-chip fabric, software stack quality, and model-serving latency.
- `ANN`-specific standalone ASICs still exist, but they are now a niche market compared with broader `DL` and `LLM` accelerators.
- `CNN` ASICs are still commercially relevant at the edge, but vendors now increasingly advertise support for vision transformers and small on-device GenAI workloads, which means the market is drifting from single-workload chips toward more flexible NPUs and dataflow engines.
- `LLM` ASIC work is now the fastest-moving part of the market, and public product messaging increasingly revolves around token economics, time-to-first-token, long-context handling, memory hierarchy, and interconnect scale.

## Snapshot Table

| Domain | Current technology center | Academic status | Market reality |
| --- | --- | --- | --- |
| ANN | ultra-low-power dense inference, always-on sensing, compact local memory, mixed-signal or in-memory ideas | mature but still active in TinyML and CiM niches | small and specialized market |
| CNN | edge vision inference, DRAM avoidance, compact/sparse execution, camera and robotics deployment | mature, with active work around memory movement and ViT migration | still healthy in edge and embedded vision |
| DL | general-purpose tensor engines, HBM, scale-up/scale-out fabrics, software/compiler integration | active and broad | dominated by hyperscalers plus a few strong alternatives |
| LLM | transformer decode latency, KV-cache pressure, FP8/INT4, MoE, long-context serving | hottest current research area | fastest-moving product segment |

## Cross-Domain Conclusions

### 1. Memory movement is the first-order problem

This is the most stable conclusion across the whole stack.

- Edge papers still focus on minimizing feature-map traffic and data movement.
- Compute-in-memory papers still focus on reducing ADC overhead, on-chip capacity pressure, and off-chip bandwidth loss.
- Datacenter products now advertise HBM capacity, bandwidth, and interconnect scale almost as aggressively as arithmetic throughput.

### 2. Software maturity is now part of the hardware moat

Market winners are not just shipping silicon.

- AWS ties Trainium and Inferentia to Neuron and framework integrations.
- Google ties TPU adoption to Cloud TPU, GKE, and AI Hypercomputer operations.
- Intel, SambaNova, Cerebras, d-Matrix, Axelera, and Hailo all emphasize compilers, SDKs, model zoos, or cloud access in their public positioning.

Inference from the sources: custom ASIC success now depends on the full hardware-software system, not just the die.

### 3. Edge and cloud ASICs are diverging

The design constraints are different enough that "AI ASIC" is no longer a single category.

- Edge chips optimize for power, thermals, DRAM avoidance, packaging, and deployability in cameras, robots, sensors, and gateways.
- Cloud chips optimize for HBM, interconnect, rack-scale communication, multi-chip programming, and predictable serving or training economics.

### 4. The market is consolidating around a few credible patterns

The current public market patterns are:

- hyperscaler in-house ASICs for cloud scale
- edge inference ASICs for vision and always-on sensing
- latency-first LLM inference ASICs
- memory-centric or in-memory ASIC startups trying to break the memory wall

## Reading Guide

- Start with [ann-asic-status.md](./ann-asic-status.md) if you care about low-power or TinyML-style hardware.
- Start with [cnn-asic-status.md](./cnn-asic-status.md) if you care about edge vision and embedded deployment.
- Start with [dl-asic-status.md](./dl-asic-status.md) if you care about the broad accelerator landscape.
- Start with [llm-asic-status.md](./llm-asic-status.md) if you care about current frontier datacenter AI hardware.

## Sources

- Google Cloud TPU v6e docs: <https://cloud.google.com/tpu/docs/v6e>
- Google Cloud TPU release notes: <https://cloud.google.com/tpu/docs/release-notes>
- AWS Inferentia: <https://aws.amazon.com/ai/machine-learning/inferentia/>
- AWS Trainium: <https://aws.amazon.com/ai/machine-learning/trainium/>
- Amazon EC2 Trn2 instances: <https://aws.amazon.com/ec2/instance-types/trn2/>
- Cerebras WSE-3 announcement: <https://www.cerebras.ai/press-release/cerebras-announces-third-generation-wafer-scale-engine>
- Groq GroqChip product brief: <https://www.groq.com/GroqDocs/Product%20Spec%20Sheet%20-%20GroqChip%E2%84%A2%20Processor.pdf>
- d-Matrix Corsair: <https://www.d-matrix.ai/product/>
- A Survey on Deep Learning Hardware Accelerators for Heterogeneous HPC Platforms: <https://arxiv.org/abs/2306.15552>
- Hardware Acceleration of LLMs: A comprehensive survey and comparison: <https://arxiv.org/abs/2409.03384>
