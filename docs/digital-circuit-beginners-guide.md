# Digital Circuit Workflow: A Beginner's Guide

This guide explains how a digital circuit goes from an idea to a physical chip. It uses this repository's tiny neural inference ASIC as the running example, but the workflow applies to any digital design.

## The Big Picture

```text
Idea
  → Design (SystemVerilog)
    → Simulate (Icarus Verilog, Verilator)
      → Synthesize (Yosys)
        → Place & Route (OpenLane / OpenROAD)
          → Fabrication (foundry)
            → Testing (production test)
```

Each step transforms the design into a more concrete representation. Each step also introduces new ways things can go wrong, which is why verification happens at every stage.

## 1. Design: Writing the Circuit in SystemVerilog

### What Happens

You describe the circuit's behavior in a hardware description language (HDL). The two main HDLs are Verilog/SystemVerilog and VHDL. This project uses SystemVerilog.

SystemVerilog is not a programming language in the software sense. It describes hardware that runs in parallel, reacts to clock edges, and holds state in registers. When you write:

```systemverilog
always_ff @(posedge clk) begin
  if (do_mac_hidden)
    acc_reg <= acc_reg + product;
end
```

you are describing a physical register (`acc_reg`) that updates its value on every rising clock edge when `do_mac_hidden` is high. This register will become actual flip-flops in silicon.

### Key Concepts

**Combinational logic**: outputs depend only on current inputs. No memory. Think of it as wires and gates.

```systemverilog
assign product = a * b;              // combinational: result changes immediately when inputs change
assign done = (state == DONE);        // combinational: just a comparator
```

**Sequential logic**: outputs depend on current inputs AND stored state. Has memory. Think of it as registers that update on clock edges.

```systemverilog
always_ff @(posedge clk)              // sequential: updates only on clock edge
  state <= next_state;                // state register holds its value between edges
```

**FSM (Finite State Machine)**: a controller that moves through named states. Most digital designs have at least one. This project's controller has 9 states:

```text
IDLE → LOAD_INPUT → MAC_HIDDEN → BIAS_HIDDEN → ACT_HIDDEN → NEXT_HIDDEN
                                                                    |
                    DONE ← BIAS_OUTPUT ← MAC_OUTPUT ←──────────────+
```

### The Files in This Project

```text
rtl/src/
  controller.sv     FSM: decides what happens each cycle
  mac_unit.sv       Datapath: multiplies and accumulates
  relu_unit.sv      Datapath: activation function
  weight_rom.sv     Memory: stores frozen weights as constants
  mlp_core.sv       Top module: wires everything together
```

### Common Beginner Mistakes at This Stage

- Thinking SystemVerilog executes top-to-bottom like Python. It doesn't. Everything inside a module runs in parallel.
- Confusing `=` (blocking, combinational) with `<=` (non-blocking, sequential). Using the wrong one causes simulation/synthesis mismatches.
- Forgetting that hardware has no "function calls" at runtime. A `module` is instantiated as physical hardware, not called.

## 2. Simulate: Testing the Design Before Building It

### What Happens

Simulation runs your HDL design on a computer. A testbench drives inputs into your design and checks that the outputs are correct.

```text
Testbench (stimulus + checks)
    │
    ▼
  ┌─────────┐
  │   DUT   │  ← Device Under Test (your design)
  │mlp_core │
  └─────────┘
    │
    ▼
Pass / Fail
```

The testbench is also written in SystemVerilog, but it uses constructs that only make sense in simulation (delays, file I/O, display statements). These constructs are not synthesizable — they cannot become hardware.

### Tools

**Icarus Verilog** (`iverilog`): open-source Verilog simulator. Interprets the HDL. Slower but more portable.

**Verilator**: open-source simulator that compiles SystemVerilog to C++, then runs the C++ model. Much faster for large designs. Stricter about language compliance.

**GTKWave**: waveform viewer. Opens VCD files dumped by simulators. Lets you visually inspect every signal at every clock cycle.

This project runs the same testbench through both iverilog and Verilator (`make sim`) because different simulators sometimes interpret edge cases differently.

### What Gets Checked

In this project, the testbench checks:

- **Functional correctness**: does the output bit match the expected classification?
- **Timing**: does the result appear at exactly cycle 76?
- **Handshake protocol**: do `busy` and `done` behave as specified?
- **Boundary transitions**: do the guard cycles and phase changes happen correctly?
- **Coverage**: are positive, zero, and negative score cases all represented?

### Simulation vs. Formal Verification

Simulation tests specific input vectors. It cannot prove correctness for all possible inputs.

Formal verification (this project uses Lean theorem proving) can prove properties for all inputs, but it works on a mathematical model, not the actual Verilog.

The two approaches complement each other:
- Simulation catches bugs in the actual HDL that the formal model might abstract away
- Formal proofs cover the full input space that simulation cannot exhaustively test

## 3. Synthesize: Turning HDL into Gates

### What Happens

Synthesis translates your behavioral HDL into a network of logic gates from a specific technology library. This is where your design stops being abstract and starts being physical.

```text
SystemVerilog          Gate-level netlist
┌──────────────┐      ┌──────────────────────┐
│ if (a && b)  │  →   │ AND gate → DFF → ... │
│   q <= 1;    │      │ connected with wires  │
└──────────────┘      └──────────────────────┘
```

The synthesis tool:

1. **Parses** the HDL
2. **Elaborates** the design hierarchy (resolves parameters, generates instances)
3. **Optimizes** the logic (removes redundancy, shares resources)
4. **Maps** to target library cells (specific AND gates, flip-flops, muxes from the foundry's cell library)
5. **Reports** area, timing estimates, and cell usage

### Tools

**Yosys**: the standard open-source synthesis tool. Reads Verilog/SystemVerilog, performs logic optimization, maps to a target cell library, writes a gate-level netlist.

This project's synthesis script (`asic/yosys.tcl`):

```tcl
read_verilog -sv {*}$rtl_files        # read the RTL
hierarchy -check -top mlp_core        # set the top module
synth -top mlp_core                   # synthesize
abc -liberty $liberty                 # map to standard cells
write_verilog asic/mlp_core.netlist.v # write the gate-level netlist
```

**Technology library**: a collection of pre-characterized logic cells (AND2, OR3, DFFSR, MUX2, etc.) provided by the foundry. Each cell has known area, delay, and power characteristics. This project targets **Sky130** — an open-source 130nm PDK from SkyWater/Google.

### What Can Go Wrong

- **Timing violations**: the critical path (longest combinational delay between registers) exceeds the clock period. The design won't run at the target frequency.
- **Unmapped constructs**: some SystemVerilog features don't have direct hardware equivalents. The synthesis tool may reject or misinterpret them.
- **Simulation/synthesis mismatch**: the gate-level netlist behaves differently from the RTL simulation. Usually caused by improper use of blocking vs. non-blocking assignments.

### Post-Synthesis Verification

After synthesis, you can simulate the gate-level netlist to verify it still matches the RTL behavior. This is called **gate-level simulation** (GLS). The testbench is the same; only the DUT changes from RTL to the synthesized netlist.

## 4. Place & Route: Turning Gates into Geometry

### What Happens

Place and route (P&R) takes the gate-level netlist and produces a physical layout: actual geometric shapes that will be printed onto silicon wafers.

```text
Gate netlist              Physical layout
┌─────────────┐          ┌─────────────────┐
│ AND → DFF → │    →     │ ▪▪▪ ─── ▪▪▪    │  ← rectangles on metal layers
│ OR  → MUX   │          │ │       │       │  ← connected by vias and wires
└─────────────┘          │ ▪▪▪ ─── ▪▪▪    │
                         └─────────────────┘
```

The steps within P&R:

1. **Floorplanning**: define the chip boundary, place I/O pins, reserve space for power grid
2. **Placement**: assign each gate a physical location on the chip
3. **Clock Tree Synthesis (CTS)**: build a balanced clock distribution network so all flip-flops see the clock edge at nearly the same time
4. **Routing**: draw metal wires to connect the gates according to the netlist
5. **Timing closure**: iterate on placement and routing until all timing constraints are met
6. **Design Rule Check (DRC)**: verify the layout follows the foundry's manufacturing rules (minimum wire width, spacing, etc.)
7. **Layout vs. Schematic (LVS)**: verify the layout matches the gate-level netlist
8. **GDSII export**: write the final layout in the format the foundry accepts

### Tools

**OpenLane**: an automated RTL-to-GDSII flow built on top of OpenROAD, Yosys, Magic, and other open-source tools. It wraps the entire P&R pipeline into a single configurable flow.

**OpenROAD**: the core open-source P&R engine. Handles placement, CTS, routing, and timing analysis.

**Magic**: open-source layout tool. Used for DRC and parasitic extraction.

**KLayout**: open-source layout viewer. Used to inspect the GDSII output visually.

This project's OpenLane configuration (`asic/openlane/config.json`):

```json
{
  "DESIGN_NAME": "mlp_core",
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 10,
  "DIE_AREA": "0 0 200 200",
  "PL_TARGET_DENSITY": 0.45
}
```

This says: the design is called `mlp_core`, the clock runs at 100MHz (10ns period), the chip is 200x200 microns, and we want 45% of the area filled with cells (the rest is routing channels and whitespace).

### What Can Go Wrong

- **Timing closure failure**: wires add delay. A path that met timing after synthesis may fail after routing because the wire is too long.
- **Routing congestion**: too many wires need to cross the same area. The router cannot find legal paths.
- **DRC violations**: the layout violates manufacturing rules. Must be fixed before tapeout.
- **Antenna violations**: long metal wires can accumulate charge during manufacturing and damage transistor gates.

## 5. The Full Verification Stack

Verification happens at every stage, not just once:

| Stage | What you verify | How |
|-------|----------------|-----|
| RTL design | Functional correctness, timing protocol | Simulation (iverilog, Verilator), formal proofs (Lean) |
| Post-synthesis | Gate-level netlist matches RTL behavior | Gate-level simulation with the same testbench |
| Post-P&R | Layout meets timing with real wire delays | Static timing analysis (STA) |
| Post-P&R | Layout matches netlist | LVS check |
| Post-P&R | Layout follows manufacturing rules | DRC check |
| Post-P&R | Signal integrity | Parasitic extraction + timing re-analysis |

Each stage can introduce new bugs that the previous stage couldn't catch. That is why "it simulates correctly" is necessary but not sufficient.

## 6. Design vs. Sample vs. Mass Production

### Design Phase

What you do in this repository. Write HDL, simulate, synthesize, place and route. The output is a GDSII file — a complete geometric description of the chip.

**Cost**: your time, compute resources. No manufacturing cost yet.

**Risk**: design bugs. If the design is wrong, everything downstream is wasted.

### Tapeout

Submitting the GDSII to a foundry for manufacturing. The name comes from the old practice of writing the design onto magnetic tape. Today it's a file transfer, but the name stuck.

Before tapeout, you run final sign-off checks:
- Timing is met at all process/voltage/temperature corners
- DRC is clean
- LVS is clean
- All I/O pads and power connections are correct

**Cost**: for a shuttle run (shared wafer with other designs), $1K–$10K for small academic designs on older nodes. For a full mask set on advanced nodes, $1M–$100M+.

**Risk**: if something is wrong in the GDSII, you've paid for broken chips. There is no "undo" in silicon.

### Samples (Engineering Samples)

The first chips back from the foundry. Usually 10–100 units. These are for testing, not for customers.

You verify:
- **Does the chip power up?** (basic connectivity)
- **Does the clock run?** (clock tree works)
- **Does it pass functional tests?** (the same test vectors, but now on real silicon)
- **Does it meet speed targets?** (test at target frequency)
- **Power consumption** (measure actual current draw)

Defects found at this stage require a **respin** — a new tapeout with the fixes. Each respin costs time and money.

### Mass Production

Once engineering samples pass all tests, the design is released for volume manufacturing.

Additional concerns at this stage:
- **Yield**: what fraction of chips on a wafer work? Defects in manufacturing kill some chips.
- **Production testing**: every chip must be tested. You write test programs that run on automated test equipment (ATE). The test program must be fast (seconds per chip) to keep cost per unit low.
- **Binning**: chips that pass at the highest frequency get sold as premium parts. Slower ones get sold as budget parts.
- **Packaging**: the bare die is put into a package with pins/balls for soldering to a circuit board.

### Cost Comparison

| Phase | Typical cost | Reversible? |
|-------|-------------|-------------|
| Design + simulation | Time only | Yes — edit and re-simulate |
| Synthesis + P&R | Compute time | Yes — re-run the tools |
| Tapeout (shuttle) | $1K–$10K | No — silicon is permanent |
| Tapeout (full mask, advanced node) | $1M–$100M+ | No |
| Engineering samples | $1K–$50K | No — respin required for fixes |
| Mass production | Per-unit cost | No — recall is extremely expensive |

The cost of fixing a bug increases by roughly 10x at each stage. That is the fundamental reason why verification at the design stage matters so much.

## 7. Open-Source vs. Commercial Tools

This project uses entirely open-source tools:

| Function | Open-source | Commercial equivalent |
|----------|------------|----------------------|
| HDL simulation | Icarus Verilog, Verilator | Synopsys VCS, Cadence Xcelium |
| Synthesis | Yosys | Synopsys Design Compiler, Cadence Genus |
| Place & Route | OpenLane / OpenROAD | Synopsys ICC2, Cadence Innovus |
| Timing analysis | OpenSTA (inside OpenROAD) | Synopsys PrimeTime |
| Layout viewer | KLayout, Magic | Cadence Virtuoso |
| DRC / LVS | Magic, netgen | Mentor Calibre |
| Formal verification | Lean (this project) | Synopsys VC Formal, Cadence JasperGold |

The open-source flow is usable for research and education. Commercial tools are faster, handle larger designs, and have better support for advanced manufacturing nodes.

For a tiny design like this one (a few hundred gates on 130nm), the open-source tools are more than sufficient.

## 8. Where This Project Sits

```text
                          ← you are here
Design          Simulate       Synthesize      Place & Route     Fabrication
  ✓                ✓              ✓                 ◐                ✗
  RTL exists    iverilog +     Yosys script    OpenLane config    not yet
  Lean proofs   Verilator      works           exists, not
  exist         pass                           fully exercised
```

The design and verification are the most developed parts. The ASIC backend exists as scripts and configuration but hasn't been pushed through to GDSII yet.

## 9. Glossary

- **HDL**: Hardware Description Language. SystemVerilog, VHDL.
- **RTL**: Register-Transfer Level. The abstraction where you describe registers and the logic between them.
- **Netlist**: a list of gates and their connections. The output of synthesis.
- **PDK**: Process Design Kit. The foundry's package of cell libraries, design rules, and device models for a specific manufacturing process.
- **Sky130**: SkyWater's open-source 130nm CMOS PDK.
- **STA**: Static Timing Analysis. Checks if all paths meet timing without running simulation.
- **DRC**: Design Rule Check. Verifies the layout follows manufacturing constraints.
- **LVS**: Layout vs. Schematic. Verifies the layout matches the intended circuit.
- **GDSII**: the standard file format for IC layout data. What the foundry receives.
- **Tapeout**: submitting the final design to the foundry for manufacturing.
- **Respin**: re-doing a tapeout to fix bugs found in silicon.
- **Yield**: the fraction of manufactured chips that work correctly.
- **ATE**: Automated Test Equipment. Machines that test chips in production.
