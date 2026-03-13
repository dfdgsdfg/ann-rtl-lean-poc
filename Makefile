.PHONY: train evaluate quantize export freeze freeze-check \
       sim sim-check-tools sim-iverilog sim-verilator clean-sim sim-vectors \
       show show-check-tools clean-show

ANN_CLI := python3 -m ann.cli

# --- ANN targets ---

train:
	$(ANN_CLI) train $(ARGS)

evaluate:
	$(ANN_CLI) evaluate $(ARGS)

quantize:
	$(ANN_CLI) quantize $(ARGS)

export:
	$(ANN_CLI) export $(ARGS)

freeze:
	python3 -m contract.src.freeze $(ARGS)

freeze-check:
	python3 -m contract.src.freeze --check

# --- Simulation targets ---

SIM_RTL := rtl/src/mac_unit.sv \
	rtl/src/relu_unit.sv \
	rtl/src/controller.sv \
	rtl/src/weight_rom.sv \
	rtl/src/mlp_core.sv
SIM_TB := simulations/rtl/testbench.sv
SIM_VECTORS := simulations/rtl/test_vectors.mem
SIM_VECTOR_META := simulations/rtl/test_vectors_meta.svh
SIM_VECTOR_DEPS := contract/result/weights.json $(wildcard contract/src/*.py)
SIM_BUILD_DIR := build/sim
SIM_VECTOR_STAMP := $(SIM_BUILD_DIR)/vectors.stamp
SIM_INCLUDE_DIRS := -Isimulations/rtl
IVERILOG_BIN := $(SIM_BUILD_DIR)/iverilog/testbench.out
VERILATOR_DIR := $(SIM_BUILD_DIR)/verilator
VERILATOR_BIN := $(VERILATOR_DIR)/Vtestbench

sim: sim-check-tools sim-iverilog sim-verilator

sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "missing required tool: verilator"; exit 1; }

sim-vectors: $(SIM_VECTORS) $(SIM_VECTOR_META)

$(SIM_VECTOR_STAMP): $(SIM_VECTOR_DEPS)
	@mkdir -p $(dir $@)
	python3 -m contract.src.gen_vectors
	@touch $@

$(SIM_VECTORS) $(SIM_VECTOR_META): %: $(SIM_VECTOR_STAMP)
	@if [ ! -f $@ ]; then rm -f $(SIM_VECTOR_STAMP); $(MAKE) $(SIM_VECTOR_STAMP); fi

sim-iverilog: sim-vectors $(IVERILOG_BIN)
	vvp $(IVERILOG_BIN)

$(IVERILOG_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTOR_STAMP)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(SIM_RTL)

sim-verilator: sim-vectors $(VERILATOR_BIN)
	$(VERILATOR_BIN)

$(VERILATOR_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTOR_STAMP)
	@mkdir -p $(VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(VERILATOR_DIR) $(SIM_TB) $(SIM_RTL)

clean-sim:
	rm -rf $(SIM_BUILD_DIR)

# --- Visualization targets ---

SHOW_BUILD_DIR := build/show
SHOW_ASSETS_DIR := docs/assets
SHOW_MODULES := mlp_core controller mac_unit relu_unit weight_rom

show: show-check-tools $(addprefix $(SHOW_ASSETS_DIR)/,$(addsuffix .svg,$(SHOW_MODULES)))
	@echo "---"
	@echo "SVGs written to $(SHOW_ASSETS_DIR)/"
	@ls -1 $(SHOW_ASSETS_DIR)/*.svg

show-check-tools:
	@command -v yosys >/dev/null 2>&1 || { echo "missing required tool: yosys (brew install yosys)"; exit 1; }
	@command -v netlistsvg >/dev/null 2>&1 || { echo "missing required tool: netlistsvg (npm install -g netlistsvg)"; exit 1; }

$(SHOW_BUILD_DIR)/%.json: $(SIM_RTL)
	@mkdir -p $(SHOW_BUILD_DIR)
	yosys -q -p "read_verilog -sv $(SIM_RTL); hierarchy -check -top $*; proc; opt; write_json $@"

$(SHOW_BUILD_DIR)/%.svg: $(SHOW_BUILD_DIR)/%.json
	netlistsvg $< -o $@

$(SHOW_ASSETS_DIR)/%.svg: $(SHOW_BUILD_DIR)/%.svg
	@mkdir -p $(SHOW_ASSETS_DIR)
	cp $< $@

clean-show:
	rm -rf $(SHOW_BUILD_DIR)
	rm -f $(addprefix $(SHOW_ASSETS_DIR)/,$(addsuffix .svg,$(SHOW_MODULES)))
