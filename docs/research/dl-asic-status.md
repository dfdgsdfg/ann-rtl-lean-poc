# Deep Learning ASIC Status

Date: 2026-03-12

## Scope

This note covers broader custom deep-learning ASICs that target multiple workload classes, such as:

- CNNs
- transformers
- diffusion models
- multimodal models
- training and large-scale inference

This is the right note for cloud and enterprise AI accelerators that are not only about LLM serving.

## Short Answer

The broad `DL` ASIC market is healthy and strategically important, but it is now dominated by full-stack platforms rather than isolated chips.

The core technical pattern is stable:

- tensor or systolic-style compute
- large HBM pools
- strong chip-to-chip or rack-scale interconnect
- software that keeps PyTorch and JAX migration friction low

The frontier competition is no longer just about peak TOPS or FLOPS.

It is about:

- memory bandwidth
- memory capacity
- scale-up and scale-out communication
- cost per training run
- energy efficiency
- software and framework integration

## Technology Status

### What is established

- matrix-dense tensor engines and systolic-array style compute
- HBM-backed accelerator design
- multi-chip scale-up fabrics
- cloud or rack-level deployment models
- native support for mainstream ML frameworks

### What is changing now

- more aggressive low-precision formats such as FP8 and vendor-specific variants
- stronger support for sparse and expert-parallel workloads
- tighter integration between compiler, runtime, and collective communication
- renewed interest in compute-in-memory and memory-centric alternatives for energy efficiency

### Current hardware direction

The strongest deployed architectures now advertise a balanced system:

- enough arithmetic to stay busy
- enough HBM to hold large models
- enough bandwidth to avoid starving the cores
- enough network fabric to scale distributed training and inference

Inference from the sources: broad DL ASIC design is converging on "memory-and-network balanced tensor systems" rather than simple MAC-array bragging rights.

## Academic Status

### Current academic position

This is still a very active academic area.

The active research themes are:

1. memory wall mitigation
2. processing-in-memory and compute-in-memory
3. chiplet and multi-chip packaging
4. sparse and low-precision execution
5. compiler and mapping co-design
6. fair benchmarking across process nodes and software stacks

### What the literature suggests

- The large 2025 revision of `A Survey on Deep Learning Hardware Accelerators for Heterogeneous HPC Platforms` shows the space is broad, still moving, and increasingly heterogeneous.
- `HCiM` highlights that even promising analog CiM designs still have to solve ADC and precision overheads.
- `Generalized Ping-Pong` shows that PIM gains are fragile if off-chip bandwidth is not scheduled well.
- `CIMPool` shows that compression, hardware, and dataflow now have to be co-designed if in-memory accelerators are to scale to larger models.

### My assessment

Academically, broad DL ASIC research is healthy and still strategically relevant.

The field is less about discovering that accelerators matter, and more about resolving the next-order bottlenecks:

- memory movement
- capacity pressure
- communication overhead
- programmability
- benchmark comparability

## Actual Market Players

### 1. Google TPU

Why it matters:

- `TPU v6e` is publicly documented as a current-generation accelerator for transformer, text-to-image, and CNN training, fine-tuning, and serving.
- Google states that `Trillium` reached general availability on December 16, 2024.
- Public release notes emphasize performance-per-dollar, energy efficiency, and scaling on Google's AI Hypercomputer fabric.

Status:

- hyperscaler-owned and deployed
- one of the strongest real-world custom ASIC platforms

### 2. AWS Trainium and Inferentia

Why it matters:

- AWS has a complete in-house ASIC line spanning training and inference.
- `Trn2` is public and available, with large HBM pools and UltraServer scale-up.
- AWS now publicly positions `Trainium3` as the next step, which shows an aggressive roadmap rather than a one-off chip effort.
- Inferentia remains the inference-side complement.

Status:

- hyperscaler-owned and deployed
- one of the strongest signals that custom ASIC is now strategic cloud infrastructure, not just a side project

### 3. Intel Gaudi

Why it matters:

- Gaudi 3 is clearly positioned for large-scale AI training and inference with standard Ethernet networking and OEM availability.
- Intel is using openness and Ethernet-based scaling as its differentiation story.

Status:

- actual enterprise market player
- strongest where buyers want a non-NVIDIA path without moving to a hyperscaler-owned stack

### 4. Cerebras

Why it matters:

- Cerebras remains the clearest alternative architecture in the broad DL ASIC market.
- `WSE-3` and `CS-3` are public, large-scale, and deployed.
- The company is using both training and inference use cases to validate wafer-scale design in practice.

Status:

- actual market player with distinct architecture
- strongest in frontier or specialized large-model environments

### 5. SambaNova

Why it matters:

- SambaNova continues to position its `RDU` and `SN40L` around large-model inference through `SambaCloud`.
- Its public story is less about selling a bare chip and more about selling an integrated AI system.

Status:

- actual market player
- more platform-centric than component-centric

## Bottom Line

Broad `DL` custom ASICs are not experimental anymore.

They are a real infrastructure tier, especially in:

- hyperscaler cloud
- enterprise AI systems
- specialized large-model training and inference clusters

The stable conclusion is that the winners are now full-stack system vendors, not just chip designers.

## Sources

- TPU v6e: <https://cloud.google.com/tpu/docs/v6e>
- Cloud TPU release notes: <https://cloud.google.com/tpu/docs/release-notes>
- AWS Trainium: <https://aws.amazon.com/ai/machine-learning/trainium/>
- AWS Inferentia: <https://aws.amazon.com/ai/machine-learning/inferentia/>
- Amazon EC2 Trn2 instances: <https://aws.amazon.com/ec2/instance-types/trn2/>
- Intel Gaudi 3 product page: <https://www.intel.com/content/www/us/en/products/details/processors/ai-accelerators/gaudi.html>
- Intel Gaudi 3 availability update: <https://newsroom.intel.com/artificial-intelligence/intel-gaudi-3-expands-availability-drive-ai-innovation-scale>
- Cerebras WSE-3 announcement: <https://www.cerebras.ai/press-release/cerebras-announces-third-generation-wafer-scale-engine>
- Cerebras CS-3 deployment at Sandia: <https://www.cerebras.ai/press-release/sandia-deploys-cutting-edge-cerebras-cs-3-testbed-for-ai-workloads>
- SambaCloud: <https://sambanova.ai/products/sambacloud>
- A Survey on Deep Learning Hardware Accelerators for Heterogeneous HPC Platforms: <https://arxiv.org/abs/2306.15552>
- HCiM: ADC-Less Hybrid Analog-Digital Compute in Memory Accelerator for Deep Learning Workloads: <https://arxiv.org/abs/2403.13577>
- Generalized Ping-Pong: Off-Chip Memory Bandwidth Centric Pipelining Strategy for Processing-In-Memory Accelerators: <https://arxiv.org/abs/2411.13054>
- CIMPool: Scalable Neural Network Acceleration for Compute-In-Memory using Weight Pools: <https://arxiv.org/abs/2503.22044>
