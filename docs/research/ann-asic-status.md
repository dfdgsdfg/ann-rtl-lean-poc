# ANN ASIC Status

Date: 2026-03-12

## Scope

This note covers custom ASICs centered on classical or compact neural-network workloads:

- dense and fully connected networks
- audio and sensor inference
- always-on edge AI
- TinyML-class accelerators
- analog or compute-in-memory ASICs when they target general neural-network inference rather than only one domain

This is not the right note for:

- large cloud training chips
- transformer-first datacenter silicon
- vision-heavy CNN accelerators

## Short Answer

Pure `ANN`-centric ASICs are now a niche rather than the center of the market.

The field is still technically active, but most commercial momentum has shifted toward:

- edge vision ASICs
- general-purpose deep-learning ASICs
- LLM-serving ASICs

Where `ANN` ASICs still matter, they win on:

- extremely low power
- always-on operation
- keeping inference local
- minimizing external memory traffic
- supporting compact quantized models

## Technology Status

### What is mature

- Quantized inference is standard.
- Tight local-memory scheduling is standard.
- Always-on sensing and battery-first design are standard for successful products.
- Compiler and deployment tooling matter almost as much as MAC efficiency.

### What still differentiates products

- whether the chip can run without external DRAM
- how much mixed workload support it has across audio, sensor, and small vision models
- whether it uses classical digital MAC arrays or more aggressive compute-in-memory / analog methods
- how much software friction is required to compile and deploy a model

### Current design pattern

The common pattern is a small or moderate programmable accelerator wrapped in:

- local SRAM or tightly managed on-chip memory
- aggressive quantization
- simple host integration
- enough programmability to avoid being trapped by a single network family

Inference from the sources: the commercial market no longer rewards ultra-specialized ANN silicon unless it is dramatically better on power or memory footprint than a broader NPU alternative.

## Academic Status

### Current academic position

Academic work is still active, but it is concentrated in a few themes:

1. TinyML energy efficiency
2. compute-in-memory
3. compiler/runtime support for heterogeneous small SoCs
4. low-bit and ternary execution
5. extending tiny accelerators beyond CNNs toward attention-based models

### What the papers suggest

- `TCN-CUTIE` shows that silicon-proven TinyML accelerators still compete on uJ per inference and mW-scale operation, which confirms that ultra-low-power inference is still an active hardware research niche.
- `HTVM` shows the deployment problem is now part of the research problem: heterogeneous tiny platforms are hard enough that compiler support can create order-of-magnitude gains.
- `Toward Attention-based TinyML` shows the research frontier is already moving from CNN-only tiny accelerators toward attention-capable hardware in the same power envelope.
- `HCiM`, `Generalized Ping-Pong`, and `CIMPool` show that compute-in-memory remains promising, but capacity limits and off-chip bandwidth still constrain scaling.

### My assessment

The `ANN` ASIC research area is academically alive, but it is not where the highest market heat is.

- The work is credible and practical.
- The problems are concrete and hardware-real.
- The biggest open issue is turning promising low-power or in-memory ideas into robust, tool-supported commercial products.

## Actual Market Players

### 1. Syntiant

Why it matters:

- Syntiant remains one of the clearest examples of a real commercial niche for compact ANN ASICs.
- The `NDP200` is positioned for always-on imaging, speech, and sensor processing.
- Syntiant publicly states support for CNN, RNN, and fully connected networks, and claims sub-milliwatt vision processing for the `NDP200`.
- The `NDP120` continues to show up in low-power benchmark positioning, including a 2025 MLPerf Tiny result.

Status:

- actual commercial player
- edge and always-on niche
- strongest fit for audio, sensor, and small local inference

### 2. Mythic

Why it matters:

- Mythic remains one of the most visible commercial attempts to push analog / in-memory inference into practical silicon.
- The `M1076` stores up to 80M weight parameters on-chip and executes matrix operations without external DRAM, which directly targets the memory wall.

Status:

- actual product family with public product material
- differentiated architecture
- stronger as a memory-centric inference story than as a mainstream volume platform

### 3. Boundary of the category

This is the main market reality: the category is thinning out.

- Vendors that once would have been described as `ANN` ASIC companies are increasingly framed as broader edge AI or NPU companies.
- In practice, many buyers now prefer chips that can cover small CNNs, compact transformers, and sensor workloads together.

Inference from the sources: the market is rewarding breadth and deployment convenience more than purity of `ANN` specialization.

## Bottom Line

`ANN`-specific custom ASICs are still relevant, but mostly in low-power embedded niches.

If the question is "where is the frontier market going?", the answer is not toward standalone dense-network ASICs.

If the question is "where can custom ASIC still beat larger platforms decisively?", the answer is:

- always-on audio
- local sensor fusion
- ultra-low-power edge inference
- memory-constrained deployments where DRAM avoidance is a product requirement

## Sources

- Syntiant NDP200: <https://www.syntiant.com/ndp200>
- Syntiant NDP120 MLPerf Tiny result: <https://www.syntiant.com/news/syntiant-ndp120-sets-new-standard-for-energy-efficiency-in-latest-mlperf-tiny-v13-benchmark-suite>
- Mythic M1076: <https://mythic.ai/products/m1076-analog-matrix-processor/>
- HTVM: Efficient Neural Network Deployment On Heterogeneous TinyML Platforms: <https://arxiv.org/abs/2406.07453>
- Toward Attention-based TinyML: A Heterogeneous Accelerated Architecture and Automated Deployment Flow: <https://arxiv.org/abs/2408.02473>
- TCN-CUTIE: A 1036 TOp/s/W, 2.72 uJ/Inference, 12.2 mW All-Digital Ternary Accelerator in 22 nm FDX Technology: <https://arxiv.org/abs/2212.00688>
- HCiM: ADC-Less Hybrid Analog-Digital Compute in Memory Accelerator for Deep Learning Workloads: <https://arxiv.org/abs/2403.13577>
- Generalized Ping-Pong: Off-Chip Memory Bandwidth Centric Pipelining Strategy for Processing-In-Memory Accelerators: <https://arxiv.org/abs/2411.13054>
- CIMPool: Scalable Neural Network Acceleration for Compute-In-Memory using Weight Pools: <https://arxiv.org/abs/2503.22044>
