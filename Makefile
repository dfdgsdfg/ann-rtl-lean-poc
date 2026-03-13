.PHONY: sim sim-check-tools sim-iverilog sim-verilator clean-sim

SIM_RTL := rtl/src/mac_unit.sv \
	rtl/src/relu_unit.sv \
	rtl/src/controller.sv \
	rtl/src/weight_rom.sv \
	rtl/src/mlp_core.sv
SIM_TB := simulations/rtl/testbench.sv
SIM_VECTORS := simulations/rtl/test_vectors.mem
SIM_BUILD_DIR := build/sim
IVERILOG_BIN := $(SIM_BUILD_DIR)/iverilog/testbench.out
VERILATOR_DIR := $(SIM_BUILD_DIR)/verilator
VERILATOR_BIN := $(VERILATOR_DIR)/Vtestbench

sim: sim-check-tools sim-iverilog sim-verilator

sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "missing required tool: verilator"; exit 1; }

sim-iverilog: $(IVERILOG_BIN)
	vvp $(IVERILOG_BIN)

$(IVERILOG_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTORS)
	@mkdir -p $(dir $@)
	iverilog -g2012 -s testbench -o $@ $(SIM_TB) $(SIM_RTL)

sim-verilator: $(VERILATOR_BIN)
	$(VERILATOR_BIN)

$(VERILATOR_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTORS)
	@mkdir -p $(VERILATOR_DIR)
	verilator --binary --timing --Mdir $(VERILATOR_DIR) $(SIM_TB) $(SIM_RTL)

clean-sim:
	rm -rf $(SIM_BUILD_DIR)
