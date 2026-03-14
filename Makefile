.PHONY: train evaluate quantize export freeze freeze-check \
       vendor-tools-prepare vendor-synthesis-tools-prepare vendor-openlane-prepare \
       sim sim-check-tools sim-iverilog sim-verilator clean-sim sim-vectors \
       smt smt-check-tools smt-rtl-control smt-contract-assumptions clean-smt \
       experiments experiments-artifact-consistency experiments-semantic-closure \
       experiments-branch-compare experiments-qor experiments-post-synth clean-experiments \
       rtl-synthesis rtl-synthesis-check-tools rtl-synthesis-smoke rtl-synthesis-sim rtl-synthesis-iverilog \
       rtl-synthesis-verilator clean-rtl-synthesis \
       rtl-formalize-synthesis-prepare rtl-formalize-synthesis-emit rtl-formalize-synthesis-emit-full-core \
       rtl-formalize-synthesis-build rtl-formalize-synthesis-sim rtl-formalize-synthesis-sim-check-tools clean-rtl-formalize-synthesis \
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
SIM_RTL_NO_CONTROLLER := rtl/src/mac_unit.sv \
	rtl/src/relu_unit.sv \
	rtl/src/weight_rom.sv \
	rtl/src/mlp_core.sv
SIM_TB := simulations/rtl/testbench.sv
SIM_VECTORS := simulations/shared/test_vectors.mem
SIM_VECTOR_META := simulations/shared/test_vectors_meta.svh
SIM_VECTOR_DEPS := contract/result/weights.json $(wildcard contract/src/*.py)
SIM_BUILD_DIR := build/sim
SIM_VECTOR_STAMP := $(SIM_BUILD_DIR)/vectors.stamp
SIM_INCLUDE_DIRS := -Isimulations/shared
IVERILOG_BIN := $(SIM_BUILD_DIR)/iverilog/testbench.out
VERILATOR_DIR := $(SIM_BUILD_DIR)/verilator
VERILATOR_BIN := $(VERILATOR_DIR)/Vtestbench
SPARKLE_GENERATED_DIR := experiments/rtl-formalize-synthesis/sparkle
SPARKLE_FULL_CORE_ARTIFACT := $(SPARKLE_GENERATED_DIR)/sparkle_mlp_core.sv
SPARKLE_FULL_CORE_WRAPPER := $(SPARKLE_GENERATED_DIR)/sparkle_mlp_core_wrapper.sv
SPARKLE_FULL_CORE_SIM_BUILD_DIR := build/rtl-formalize-synthesis
SPARKLE_FULL_CORE_IVERILOG_BIN := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/iverilog/testbench.out
SPARKLE_PKG_DIR := rtl-formalize-synthesis
SPARKLE_VENDOR_DIR := $(SPARKLE_PKG_DIR)/vendor/Sparkle
SPARKLE_PREPARE_SCRIPT := $(SPARKLE_PKG_DIR)/scripts/prepare_sparkle.sh
VENDOR_PREPARE_SCRIPT := scripts/prepare_vendor_tools.sh
VENDOR_DIR := vendor
VENDOR_SPOT_INSTALL_DIR := $(abspath $(VENDOR_DIR)/spot-install)
VENDOR_SYFCO_INSTALL_DIR := $(abspath $(VENDOR_DIR)/syfco-install)
VENDOR_OPENLANE_DIR := $(abspath $(VENDOR_DIR)/OpenLane)
VENDOR_LTLSYNT_BIN := $(VENDOR_SPOT_INSTALL_DIR)/bin/ltlsynt
VENDOR_SYFCO_BIN := $(VENDOR_SYFCO_INSTALL_DIR)/bin/syfco
VENDOR_OPENLANE_FLOW := $(VENDOR_OPENLANE_DIR)/flow.tcl
SPARKLE_SOURCES := $(SPARKLE_PKG_DIR)/src/TinyMLPSparkle.lean \
	$(wildcard $(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/*.lean) \
	$(SPARKLE_PREPARE_SCRIPT) \
	$(SPARKLE_PKG_DIR)/patches/sparkle-local.patch \
	$(SPARKLE_PKG_DIR)/lakefile.lean \
	$(SPARKLE_PKG_DIR)/lean-toolchain \
	$(SPARKLE_PKG_DIR)/lake-manifest.json
RTL_SYNTHESIS_BUILD_DIR := build/rtl-synthesis/spot
RTL_SYNTHESIS_GENERATED_DIR := $(RTL_SYNTHESIS_BUILD_DIR)/generated
RTL_SYNTHESIS_SUMMARY := $(RTL_SYNTHESIS_BUILD_DIR)/rtl_synthesis_summary.json
RTL_SYNTHESIS_COMPAT := experiments/rtl-synthesis/spot/controller_spot_compat.sv
RTL_SYNTHESIS_CORE := $(RTL_SYNTHESIS_GENERATED_DIR)/controller_spot_core.sv
RTL_SYNTHESIS_ALIAS := $(RTL_SYNTHESIS_GENERATED_DIR)/controller.sv
RTL_SYNTHESIS_SIM_RTL := $(RTL_SYNTHESIS_ALIAS) $(RTL_SYNTHESIS_COMPAT) $(RTL_SYNTHESIS_CORE) $(SIM_RTL_NO_CONTROLLER)
RTL_SYNTHESIS_NOTE := experiments/implementation-branch-comparison.md
RTL_SYNTHESIS_FLOW_DEPS := rtl/src/controller.sv \
	$(RTL_SYNTHESIS_COMPAT) \
	rtl-synthesis/controller/run_flow.py \
	rtl-synthesis/controller/controller.tlsf \
	rtl-synthesis/controller/formal/formal_controller_spot_equivalence.sv \
	specs/rtl-synthesis/requirement.md \
	specs/rtl-synthesis/design.md \
	$(RTL_SYNTHESIS_NOTE)
RTL_SYNTHESIS_IVERILOG_BIN := $(RTL_SYNTHESIS_BUILD_DIR)/sim/iverilog/testbench.out
RTL_SYNTHESIS_VERILATOR_DIR := $(RTL_SYNTHESIS_BUILD_DIR)/sim/verilator
RTL_SYNTHESIS_VERILATOR_BIN := $(RTL_SYNTHESIS_VERILATOR_DIR)/Vtestbench
RTL_SYNTHESIS_LTLSYNT ?= $(if $(wildcard $(VENDOR_LTLSYNT_BIN)),$(VENDOR_LTLSYNT_BIN),ltlsynt)
RTL_SYNTHESIS_SYFCO ?= $(if $(wildcard $(VENDOR_SYFCO_BIN)),$(VENDOR_SYFCO_BIN),syfco)
RTL_SYNTHESIS_YOSYS ?= yosys
RTL_SYNTHESIS_SMTBMC ?= yosys-smtbmc
RTL_SYNTHESIS_Z3 ?= z3
EXPERIMENTS_OPENLANE_FLOW ?= $(if $(wildcard $(VENDOR_OPENLANE_FLOW)),$(VENDOR_OPENLANE_FLOW),flow.tcl)

vendor-tools-prepare:
	@command -v bash >/dev/null 2>&1 || { echo "missing required tool: bash"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "missing required tool: curl"; exit 1; }
	$(VENDOR_PREPARE_SCRIPT)

vendor-synthesis-tools-prepare:
	@command -v bash >/dev/null 2>&1 || { echo "missing required tool: bash"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "missing required tool: curl"; exit 1; }
	$(VENDOR_PREPARE_SCRIPT) --tool ltlsynt --tool syfco

vendor-openlane-prepare:
	@command -v bash >/dev/null 2>&1 || { echo "missing required tool: bash"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "missing required tool: curl"; exit 1; }
	$(VENDOR_PREPARE_SCRIPT) --tool openlane

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

rtl-formalize-synthesis-prepare:
	@command -v git >/dev/null 2>&1 || { echo "missing required tool: git"; exit 1; }
	$(SPARKLE_PREPARE_SCRIPT)

rtl-formalize-synthesis-build:
	@command -v lake >/dev/null 2>&1 || { echo "missing required tool: lake"; exit 1; }
	@if [ ! -d "$(SPARKLE_VENDOR_DIR)" ]; then $(MAKE) rtl-formalize-synthesis-prepare; fi
	cd $(SPARKLE_PKG_DIR) && lake build

$(SPARKLE_FULL_CORE_ARTIFACT): $(SPARKLE_SOURCES) | rtl-formalize-synthesis-build
	@mkdir -p $(SPARKLE_GENERATED_DIR)
	cd $(SPARKLE_PKG_DIR) && lake build TinyMLPSparkle.Emit

rtl-formalize-synthesis-emit: $(SPARKLE_FULL_CORE_ARTIFACT)

rtl-formalize-synthesis-emit-full-core: $(SPARKLE_FULL_CORE_ARTIFACT)

rtl-formalize-synthesis-sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }

rtl-formalize-synthesis-sim: rtl-formalize-synthesis-sim-check-tools sim-vectors $(SPARKLE_FULL_CORE_IVERILOG_BIN)
	vvp $(SPARKLE_FULL_CORE_IVERILOG_BIN)

$(SPARKLE_FULL_CORE_IVERILOG_BIN): $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT) $(SIM_TB) $(SIM_VECTOR_STAMP)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT)

clean-rtl-formalize-synthesis:
	rm -rf $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)

rtl-synthesis-check-tools:
	@if ! command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1 || ! command -v $(RTL_SYNTHESIS_SYFCO) >/dev/null 2>&1; then $(MAKE) vendor-synthesis-tools-prepare; fi
	@command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_LTLSYNT)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_SYFCO) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_SYFCO)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_YOSYS)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_SMTBMC)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_Z3)"; exit 1; }

$(RTL_SYNTHESIS_SUMMARY): $(RTL_SYNTHESIS_FLOW_DEPS) | rtl-synthesis-check-tools
	python3 rtl-synthesis/controller/run_flow.py --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --yosys $(RTL_SYNTHESIS_YOSYS) --smtbmc $(RTL_SYNTHESIS_SMTBMC) --solver $(RTL_SYNTHESIS_Z3) --summary $(RTL_SYNTHESIS_SUMMARY)

rtl-synthesis: $(RTL_SYNTHESIS_SUMMARY)

rtl-synthesis-smoke:
	python3 rtl-synthesis/test/test_rtl_synthesis.py

rtl-synthesis-sim: sim-check-tools sim-vectors rtl-synthesis-iverilog rtl-synthesis-verilator

rtl-synthesis-iverilog: sim-vectors $(RTL_SYNTHESIS_IVERILOG_BIN)
	vvp $(RTL_SYNTHESIS_IVERILOG_BIN)

$(RTL_SYNTHESIS_IVERILOG_BIN): $(SIM_RTL_NO_CONTROLLER) $(SIM_TB) $(SIM_VECTOR_STAMP) $(RTL_SYNTHESIS_SUMMARY)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(RTL_SYNTHESIS_SIM_RTL)

rtl-synthesis-verilator: sim-vectors $(RTL_SYNTHESIS_VERILATOR_BIN)
	$(RTL_SYNTHESIS_VERILATOR_BIN)

$(RTL_SYNTHESIS_VERILATOR_BIN): $(SIM_RTL_NO_CONTROLLER) $(SIM_TB) $(SIM_VECTOR_STAMP) $(RTL_SYNTHESIS_SUMMARY)
	@mkdir -p $(RTL_SYNTHESIS_VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(RTL_SYNTHESIS_VERILATOR_DIR) $(SIM_TB) $(RTL_SYNTHESIS_SIM_RTL)

clean-rtl-synthesis:
	rm -rf build/rtl-synthesis

# --- SMT targets ---

SMT_BUILD_DIR := build/smt
SMT_Z3 ?= z3
SMT_YOSYS ?= yosys
SMT_SMTBMC ?= yosys-smtbmc
SMT_RTL_SUMMARY := $(SMT_BUILD_DIR)/rtl_control_summary.json
SMT_CONTRACT_SUMMARY := $(SMT_BUILD_DIR)/contract_assumptions.json
SMT_CONTRACT_OVERFLOW_SUMMARY := $(SMT_BUILD_DIR)/contract_overflow_summary.json
SMT_CONTRACT_EQUIV_SUMMARY := $(SMT_BUILD_DIR)/contract_equivalence_summary.json
EXPERIMENTS_BUILD_DIR := build/experiments
EXPERIMENTS_RUNNER := python3 experiments/run.py

smt: smt-check-tools smt-contract-assumptions smt-rtl-control smt-contract-overflow smt-contract-equivalence

smt-check-tools:
	@command -v $(SMT_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_Z3)"; exit 1; }
	@command -v $(SMT_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_YOSYS)"; exit 1; }
	@command -v $(SMT_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_SMTBMC)"; exit 1; }

smt-contract-assumptions:
	python3 smt/contract/export_assumptions.py --output $(SMT_CONTRACT_SUMMARY)

smt-rtl-control:
	python3 smt/rtl/check_control.py --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --summary $(SMT_RTL_SUMMARY)

smt-contract-overflow:
	python3 smt/contract/overflow/check_bounds.py --z3 $(SMT_Z3) --summary $(SMT_CONTRACT_OVERFLOW_SUMMARY)

smt-contract-equivalence:
	python3 smt/contract/equivalence/check_equivalence.py --z3 $(SMT_Z3) --summary $(SMT_CONTRACT_EQUIV_SUMMARY)

clean-smt:
	rm -rf $(SMT_BUILD_DIR)

# --- Experiment targets ---

experiments:
	$(EXPERIMENTS_RUNNER) --family all --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-artifact-consistency:
	$(EXPERIMENTS_RUNNER) --family artifact-consistency --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-semantic-closure:
	$(EXPERIMENTS_RUNNER) --family semantic-closure --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-branch-compare:
	$(EXPERIMENTS_RUNNER) --family branch-compare --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-qor:
	$(EXPERIMENTS_RUNNER) --family qor --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-post-synth:
	@if ! command -v $(EXPERIMENTS_OPENLANE_FLOW) >/dev/null 2>&1; then $(MAKE) vendor-openlane-prepare; fi
	$(EXPERIMENTS_RUNNER) --family post-synth --build-root $(EXPERIMENTS_BUILD_DIR) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

clean-experiments:
	rm -rf $(EXPERIMENTS_BUILD_DIR)

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
