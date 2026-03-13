.PHONY: train evaluate quantize export freeze freeze-check \
       sim sim-check-tools sim-iverilog sim-verilator clean-sim sim-vectors

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
SIM_BUILD_DIR := build/sim
SIM_INCLUDE_DIRS := -I simulations/rtl
IVERILOG_BIN := $(SIM_BUILD_DIR)/iverilog/testbench.out
VERILATOR_DIR := $(SIM_BUILD_DIR)/verilator
VERILATOR_BIN := $(VERILATOR_DIR)/Vtestbench

sim: sim-check-tools sim-iverilog sim-verilator

sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "missing required tool: verilator"; exit 1; }

sim-vectors:
	python3 -m contract.src.gen_vectors

sim-iverilog: $(IVERILOG_BIN)
	vvp $(IVERILOG_BIN)

$(IVERILOG_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTOR_META) | sim-vectors
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(SIM_RTL)

sim-verilator: $(VERILATOR_BIN)
	$(VERILATOR_BIN)

$(VERILATOR_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTOR_META) | sim-vectors
	@mkdir -p $(VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(VERILATOR_DIR) $(SIM_TB) $(SIM_RTL)

clean-sim:
	rm -rf $(SIM_BUILD_DIR)
