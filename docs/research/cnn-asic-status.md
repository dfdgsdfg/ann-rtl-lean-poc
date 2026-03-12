# CNN ASIC Status

Date: 2026-03-12

## Scope

This note covers custom ASICs centered on convolution-dominant vision inference, especially:

- object detection
- image classification
- camera analytics
- robotics perception
- industrial and automotive edge vision

## Short Answer

`CNN` ASICs are still commercially important, especially at the edge, but the category is no longer CNN-only in practice.

The most successful vendors now position their chips as:

- edge vision accelerators
- edge AI processors
- AI vision processors
- low-power inference engines that can also run vision transformers or compact generative models

So the current story is:

- the deployment market is real
- the architecture is mature
- the product messaging is broadening beyond classical CNNs

## Technology Status

### What is mature

- convolution acceleration dataflows
- quantized edge inference
- low-power on-device vision
- compact edge modules in M.2, PCIe, and embedded board formats
- integration with camera pipelines and edge servers

### What still matters technically

- feature-map movement and DRAM pressure
- sparse or compressed execution
- batch-1 latency
- thermal envelope
- support for multiple model families, not just CNNs

### Main technology trend

The strongest pattern is not "bigger CNN chips." It is "more flexible edge vision ASICs."

- Hailo markets both deep learning inference and newer edge GenAI support.
- Kneron explicitly positions its newer silicon as strong on both CNNs and transformer applications.
- Axelera markets computer vision and generative AI on the same edge hardware family.
- Google Coral has moved beyond the old Edge TPU story into an open Coral NPU core for silicon integration.

Inference from the sources: vendors still need CNN performance, but they no longer want a chip that only looks like a CNN accelerator.

## Academic Status

### Current academic position

CNN accelerator research is mature, but not dead.

The active work is now concentrated in:

1. memory-traffic reduction
2. sparse and compressed execution
3. TinyML deployment
4. fusing or restructuring layers to avoid intermediate buffers
5. migrating edge vision hardware toward transformer-capable designs

### What the literature suggests

- `Eyeriss v2` remains a useful reference point because it captures the long-lived hardware truths: irregular layer shapes, sparsity, and on-chip-network adaptability matter.
- `TCN-CUTIE` shows that highly efficient silicon-proven edge accelerators still matter when the deployment target is tens of milliwatts.
- `DEX` shows that small-memory edge accelerators still lose accuracy because of memory limits, which means memory capacity and movement remain core constraints.
- `Toward Attention-based TinyML` suggests that even edge academic work is crossing over from CNN-only accelerators toward hybrid CNN/attention hardware.

### My assessment

Academically, CNN ASICs are now a "mature-plus-adaptation" field.

- The basic accelerator playbook is established.
- The current research value comes from better memory behavior, broader model support, and tighter deployment flows.
- CNN-only hardware is less future-proof than edge hardware that can also absorb ViTs and other compact transformer-like workloads.

## Actual Market Players

### 1. Hailo

Why it matters:

- Hailo is one of the clearest real market players in edge vision ASICs.
- Its public site positions `Hailo-8`, `Hailo-10H`, and `Hailo-15` across accelerators and AI vision processors.
- Hailo explicitly markets DRAM-free or small-DRAM edge execution, real customer deployments, and support for neural networks, vision transformers, and LLM-adjacent edge workloads.

Status:

- actual deployed market player
- strongest in edge vision and embedded AI

### 2. Google Coral / Edge TPU / Coral NPU

Why it matters:

- The older Coral Edge TPU remains one of the best-known edge inference ASIC lines.
- Google now also positions `Coral NPU` as validated open-source IP for commercial silicon integration, which shifts Coral from just a device line to a core-level ecosystem play.

Status:

- real market and ecosystem player
- influential at the edge even when not dominant in raw performance

### 3. Kneron

Why it matters:

- Kneron is an actual edge AI chip vendor with public product positioning around `KL730`.
- Its messaging still fits the CNN market, but it now explicitly includes transformer-capable positioning and DDR-bandwidth reduction.

Status:

- actual player in edge vision SoC / accelerator market
- relevant in surveillance, automotive-adjacent, and embedded vision

### 4. Axelera AI

Why it matters:

- Axelera is one of the more visible newer edge inference players.
- Public product materials show real cards, boards, and partner integrations.
- The public positioning is clearly edge vision first, but already extends into edge generative AI.

Status:

- real commercial player
- newer than Hailo or Coral
- strongest in industrial and embedded edge deployments

## Bottom Line

`CNN` ASICs are still real and commercially useful, especially where:

- vision is local
- power is constrained
- latency matters
- bandwidth to the cloud is expensive or impossible

But the category is evolving from "CNN accelerator" into "edge visual AI accelerator."

That is the main current-state conclusion.

## Sources

- Hailo: <https://hailo.ai/>
- Google Coral: <https://www.coral.ai/>
- Coral NPU introduction: <https://developers.google.com/coral/guides/intro>
- Kneron KL730: <https://www.kneron.com/en/page/soc/>
- Axelera Metis product brief: <https://axelera.ai/hubfs/Axelera_February2025/pdfs/axelera-metis-compute-board-product-brief.pdf>
- Axelera and Advantech partnership: <https://axelera.ai/news/axelera-ai-and-advantech-deepen-partnership-to-accelerate-edge-ai-adoption-across-industrial-and-embedded-markets>
- Eyeriss v2: A Flexible Accelerator for Emerging Deep Neural Networks on Mobile Devices: <https://arxiv.org/abs/1807.07928>
- DEX: Data Channel Extension for Efficient CNN Inference on Tiny AI Accelerators: <https://arxiv.org/abs/2412.06566>
- Toward Attention-based TinyML: A Heterogeneous Accelerated Architecture and Automated Deployment Flow: <https://arxiv.org/abs/2408.02473>
- TCN-CUTIE: A 1036 TOp/s/W, 2.72 uJ/Inference, 12.2 mW All-Digital Ternary Accelerator in 22 nm FDX Technology: <https://arxiv.org/abs/2212.00688>
