# LLM ASIC Status

Date: 2026-03-12

## Scope

This note covers custom ASICs for transformer and large-language-model training or inference, including:

- decoder-heavy serving
- long-context inference
- MoE and expert-parallel execution
- real-time token generation
- large-cluster training for frontier or near-frontier models

## Short Answer

`LLM` ASICs are the hottest part of the custom AI chip market.

The technical bottlenecks are now very clear:

- HBM capacity
- HBM bandwidth
- chip-to-chip fabric
- decode latency
- KV-cache pressure
- cost per generated token
- software support for large-model serving features

The market is also clearer than it was two years ago.

- Hyperscalers are committed.
- A few specialist vendors have real traction.
- Many startup stories now rise or fall on software and deployment reality, not architectural novelty alone.

## Technology Status

### What matters now

- batch-1 and low-batch decode latency
- token throughput under real serving conditions
- support for FP8, INT8, INT4, and vendor-specific low-precision formats
- memory hierarchy for large weights and KV-cache
- interconnect for multi-chip inference and training
- serving features such as prefix caching, speculative decoding, flash decoding, and long-context support

### Current architecture pattern

The deployed product families are splitting into three camps:

1. broad cloud AI ASICs adapted for LLMs
2. latency-first inference ASICs
3. memory-centric inference ASICs

Examples:

- Google TPU and AWS Trainium/Inferentia are broad AI ASICs now heavily optimized around LLM workloads.
- Groq is a latency-first inference story.
- d-Matrix is a memory-centric inference story.
- Cerebras and SambaNova position themselves as end-to-end large-model platforms.

### Strong current signal

Public vendor messaging now focuses on:

- tokens per second
- TTFT and per-token latency
- long-context and reasoning workloads
- MoE support
- real production integration

Inference from the sources: this is evidence that the market has moved from "can it run an LLM?" to "what are the token economics and deployment constraints?"

## Academic Status

### Current academic position

This is the most active ASIC research area right now.

The dominant academic themes are:

1. memory-bound decode optimization
2. KV-cache handling
3. low-precision arithmetic
4. sparse and MoE execution
5. fair comparison across hardware platforms
6. attention-specific acceleration
7. reducing total serving cost, not just improving peak compute

### What the literature suggests

- The 2024 `Hardware Acceleration of LLMs` survey confirms that the comparison problem is now difficult because process node, platform, and software stack can distort results.
- The broad 2025 neural-accelerator survey frames long-context inference, KV-cache management, dynamic and sparse workloads, and memory-system design as open challenges.
- Even when the arithmetic core is strong, end-to-end serving behavior is still limited by memory and communication.

### My assessment

Academic momentum is high because the bottlenecks are real and expensive.

The important shift is this:

- older accelerator work was often compute-centric
- current LLM accelerator work is increasingly memory- and system-centric

## Actual Market Players

### 1. Google TPU

Why it matters:

- `TPU v6e` is publicly documented as optimized for transformer training and serving.
- Google made `Trillium` generally available on December 16, 2024.
- Google public release notes explicitly frame Trillium around dense LLM training and inference economics.

Status:

- actual hyperscaler-scale platform
- strong in both training and serving

### 2. AWS Trainium and Inferentia

Why it matters:

- `Trn2` and `Inferentia2` are real current products with large HBM pools and broad framework support.
- AWS Neuron releases explicitly add LLM-centric features such as FP8 weight quantization, flash decoding, MoE support, and vLLM-integrated `NxD Inference`.
- AWS now also publicly positions `Trainium3` around agentic, reasoning, and multimodal workloads.

Status:

- actual hyperscaler-scale platform
- strongest signal that custom LLM silicon is now core cloud infrastructure

### 3. Groq

Why it matters:

- Groq is one of the clearest latency-first inference ASIC stories.
- Public product briefs say the chip is in production and highlight deterministic execution, large on-die SRAM, and very high on-die bandwidth.
- Groq's public LLM messaging is explicitly about fast real-time generation.

Status:

- actual inference market player
- strongest where low latency matters more than broadest training flexibility

### 4. Cerebras

Why it matters:

- Cerebras has moved from a training-only perception toward a training-plus-inference platform.
- Public 2025 materials show production inference offerings and high token-rate positioning.
- The wafer-scale approach is still unusual, but it is now clearly commercial rather than purely experimental.

Status:

- actual market player
- strongest in very large-model or speed-sensitive deployments

### 5. SambaNova

Why it matters:

- SambaNova continues to market `SN40L`-based inference through `SambaCloud`.
- The public story is integrated-service first, which is practical for customers that care more about usable model serving than buying a card.

Status:

- actual platform player
- more service-oriented than component-oriented

### 6. d-Matrix

Why it matters:

- d-Matrix is one of the clearest memory-centric LLM inference startups with public hardware and product detail.
- The public `Corsair` story is explicitly generative-AI inference, with integrated "Performance Memory" plus large external capacity memory.

Status:

- real product effort with public hardware details
- earlier commercial stage than hyperscaler ASICs, Groq, or Intel

### 7. Intel Gaudi 3

Why it matters:

- Intel explicitly positions Gaudi 3 for LLMs, multimodal models, and enterprise RAG.
- It is a serious actual-market alternative when buyers want open networking and OEM delivery paths.

Status:

- actual enterprise market player
- not the market leader, but clearly relevant

## Bottom Line

The current custom LLM ASIC market is real, fast-moving, and system-level.

The strongest conclusion is not that one architecture has already won.

It is that every credible player now has to solve the same real constraints:

- memory
- communication
- software
- latency
- token economics

That is the present state of the field.

## Sources

- TPU v6e: <https://cloud.google.com/tpu/docs/v6e>
- Cloud TPU release notes: <https://cloud.google.com/tpu/docs/release-notes>
- AWS Trainium: <https://aws.amazon.com/ai/machine-learning/trainium/>
- AWS Inferentia: <https://aws.amazon.com/ai/machine-learning/inferentia/>
- Amazon EC2 Trn2 instances: <https://aws.amazon.com/ec2/instance-types/trn2/>
- AWS Neuron 2.21: <https://aws.amazon.com/about-aws/whats-new/2024/12/aws-neuron-trainium2-nxd-inference/>
- Groq GroqCard: <https://groq.com/groqcard-accelerator/>
- Groq GroqChip product brief: <https://www.groq.com/GroqDocs/Product%20Spec%20Sheet%20-%20GroqChip%E2%84%A2%20Processor.pdf>
- Groq low-latency technical document: <https://www.groq.com/GroqDocs/GROQ%20LATENCY%20TECH%20DOC%20-%20Low%20Latency.pdf>
- Cerebras WSE-3 announcement: <https://www.cerebras.ai/press-release/cerebras-announces-third-generation-wafer-scale-engine>
- Cerebras inference cloud materials: <https://www.cerebras.ai/inference>
- d-Matrix Corsair product page: <https://www.d-matrix.ai/product/>
- d-Matrix Corsair announcement: <https://www.d-matrix.ai/announcements/d-matrix-unveils-corsair-the-worlds-most-efficient-ai-computing-platform-for-inference-in-datacenters/>
- SambaCloud: <https://sambanova.ai/products/sambacloud>
- Intel Gaudi 3 product page: <https://www.intel.com/content/www/us/en/products/details/processors/ai-accelerators/gaudi.html>
- Intel Gaudi 3 availability update: <https://newsroom.intel.com/artificial-intelligence/intel-gaudi-3-expands-availability-drive-ai-innovation-scale>
- Hardware Acceleration of LLMs: A comprehensive survey and comparison: <https://arxiv.org/abs/2409.03384>
- Hardware Acceleration for Neural Networks: A Comprehensive Survey: <https://arxiv.org/abs/2512.23914>
