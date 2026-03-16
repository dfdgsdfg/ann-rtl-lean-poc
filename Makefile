.PHONY: train evaluate quantize export freeze freeze-check contract-preflight \
       formalize formalize-check-tools verify \
       vendor-tools-prepare vendor-synthesis-tools-prepare vendor-openlane-prepare \
       sim sim-internal sim-check-tools sim-iverilog sim-verilator sim-internal-iverilog sim-internal-verilator clean-sim sim-vectors \
       smt smt-check-tools smt-rtl-control smt-rtl-formalize-synthesis \
       smt-contract-assumptions smt-contract-overflow smt-contract-equivalence clean-smt \
       experiments experiments-artifact-consistency experiments-semantic-closure \
       experiments-branch-compare experiments-qor experiments-post-synth clean-experiments \
       rtl-synthesis rtl-synthesis-check-tools rtl-synthesis-smoke rtl-synthesis-sim rtl-synthesis-sim-internal rtl-synthesis-iverilog \
       rtl-synthesis-canonical rtl-synthesis-blueprint \
       rtl-synthesis-verilator rtl-synthesis-internal-iverilog rtl-synthesis-internal-verilator clean-rtl-synthesis \
       rtl-formalize-synthesis-prepare rtl-formalize-synthesis-emit rtl-formalize-synthesis-emit-full-core \
       rtl-formalize-synthesis-build rtl-formalize-synthesis-blueprint rtl-formalize-synthesis-canonical rtl-formalize-synthesis-sim rtl-formalize-synthesis-iverilog \
       rtl-formalize-synthesis-verilator rtl-formalize-synthesis-sim-check-tools clean-rtl-formalize-synthesis \
       show show-check-tools clean-show

ANN_CLI := python3 -m ann.cli
FORMALIZE_PKG_DIR := formalize
RTL_CANONICAL_DIR := rtl/results/canonical
RTL_SV_DIR := $(RTL_CANONICAL_DIR)/sv
RTL_BLUEPRINT_DIR := $(RTL_CANONICAL_DIR)/blueprint
RTL_SYNTHESIS_CANONICAL_DIR := rtl-synthesis/results/canonical
RTL_SYNTHESIS_CANONICAL_SV_DIR := $(RTL_SYNTHESIS_CANONICAL_DIR)/sv
RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR := $(RTL_SYNTHESIS_CANONICAL_DIR)/blueprint
RTL_FORMALIZE_CANONICAL_DIR := rtl-formalize-synthesis/results/canonical
RTL_FORMALIZE_CANONICAL_SV_DIR := $(RTL_FORMALIZE_CANONICAL_DIR)/sv
RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR := $(RTL_FORMALIZE_CANONICAL_DIR)/blueprint

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

contract-preflight: freeze-check

# --- Lean proof targets ---

formalize-check-tools:
	@command -v lake >/dev/null 2>&1 || { echo "missing required tool: lake"; exit 1; }

formalize: formalize-check-tools
	cd $(FORMALIZE_PKG_DIR) && lake build

verify: formalize sim smt

# --- Simulation targets ---

SIM_RTL := $(RTL_SV_DIR)/mac_unit.sv \
	$(RTL_SV_DIR)/relu_unit.sv \
	$(RTL_SV_DIR)/controller.sv \
	$(RTL_SV_DIR)/weight_rom.sv \
	$(RTL_SV_DIR)/mlp_core.sv
SIM_RTL_NO_CONTROLLER := $(RTL_SV_DIR)/mac_unit.sv \
	$(RTL_SV_DIR)/relu_unit.sv \
	$(RTL_SV_DIR)/weight_rom.sv \
	$(RTL_SV_DIR)/mlp_core.sv
SIM_TB := simulations/rtl/testbench.sv
SIM_INTERNAL_TB := simulations/rtl/testbench_internal.sv
SIM_VECTORS := simulations/shared/test_vectors.mem
SIM_VECTOR_META := simulations/shared/test_vectors_meta.svh
SIM_BUILD_DIR := build/sim
SIM_INTERNAL_BUILD_DIR := build/sim-internal
SIM_INCLUDE_DIRS := -Isimulations/shared
IVERILOG_BIN := $(SIM_BUILD_DIR)/iverilog/testbench.out
VERILATOR_DIR := $(SIM_BUILD_DIR)/verilator
VERILATOR_BIN := $(VERILATOR_DIR)/Vtestbench
SIM_INTERNAL_IVERILOG_BIN := $(SIM_INTERNAL_BUILD_DIR)/iverilog/testbench_internal.out
SIM_INTERNAL_VERILATOR_DIR := $(SIM_INTERNAL_BUILD_DIR)/verilator
SIM_INTERNAL_VERILATOR_BIN := $(SIM_INTERNAL_VERILATOR_DIR)/Vtestbench_internal
SPARKLE_GENERATED_DIR := $(RTL_FORMALIZE_CANONICAL_SV_DIR)
SPARKLE_FULL_CORE_ARTIFACT := $(SPARKLE_GENERATED_DIR)/sparkle_mlp_core.sv
SPARKLE_FULL_CORE_WRAPPER := $(SPARKLE_GENERATED_DIR)/mlp_core.sv
SPARKLE_FULL_CORE_SIM_BUILD_DIR := build/rtl-formalize-synthesis
SPARKLE_FULL_CORE_IVERILOG_BIN := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/iverilog/testbench.out
SPARKLE_FULL_CORE_VERILATOR_DIR := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/verilator
SPARKLE_FULL_CORE_VERILATOR_BIN := $(SPARKLE_FULL_CORE_VERILATOR_DIR)/Vtestbench
SPARKLE_PKG_DIR := rtl-formalize-synthesis
SPARKLE_WRAPPER_GENERATOR := $(SPARKLE_PKG_DIR)/scripts/generate_wrapper.py
SPARKLE_VERIFICATION_MANIFEST := $(SPARKLE_PKG_DIR)/results/canonical/verification_manifest.json
SPARKLE_VENDOR_DIR := $(SPARKLE_PKG_DIR)/vendor/Sparkle
SPARKLE_PREPARE_SCRIPT := $(SPARKLE_PKG_DIR)/scripts/prepare_sparkle.sh
SPARKLE_PATCH_FILE := $(SPARKLE_PKG_DIR)/patches/sparkle-local.patch
SPARKLE_PREPARE_STAMP := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/sparkle_prepare.stamp
VENDOR_PREPARE_SCRIPT := scripts/prepare_vendor_tools.sh
VENDOR_DIR := vendor
VENDOR_SPOT_INSTALL_DIR := $(abspath $(VENDOR_DIR)/spot-install)
VENDOR_SYFCO_INSTALL_DIR := $(abspath $(VENDOR_DIR)/syfco-install)
VENDOR_OPENLANE_DIR := $(abspath $(VENDOR_DIR)/OpenLane)
VENDOR_LTLSYNT_BIN := $(VENDOR_SPOT_INSTALL_DIR)/bin/ltlsynt
VENDOR_SYFCO_BIN := $(VENDOR_SYFCO_INSTALL_DIR)/bin/syfco
VENDOR_OPENLANE_FLOW := $(VENDOR_OPENLANE_DIR)/flow.tcl
SPARKLE_EMIT_SOURCES := $(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/Emit.lean \
	$(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/Types.lean \
	$(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/ControllerSignal.lean \
	$(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/ContractData.lean \
	$(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/DatapathSignal.lean \
	$(SPARKLE_PKG_DIR)/src/TinyMLPSparkle/MlpCoreSignal.lean \
	$(SPARKLE_PREPARE_SCRIPT) \
	$(SPARKLE_PKG_DIR)/patches/sparkle-local.patch \
	$(SPARKLE_PKG_DIR)/lakefile.lean \
	$(SPARKLE_PKG_DIR)/lean-toolchain \
	$(SPARKLE_PKG_DIR)/lake-manifest.json
RTL_SYNTHESIS_BUILD_DIR := build/rtl-synthesis/spot
RTL_SYNTHESIS_GENERATED_DIR := $(RTL_SYNTHESIS_BUILD_DIR)/generated
RTL_SYNTHESIS_SUMMARY := $(RTL_SYNTHESIS_BUILD_DIR)/rtl_synthesis_summary.json
RTL_SYNTHESIS_COMPAT := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/controller_spot_compat.sv
RTL_SYNTHESIS_CORE := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/controller_spot_core.sv
RTL_SYNTHESIS_ALIAS := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/controller.sv
RTL_SYNTHESIS_SIM_RTL := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/mac_unit.sv \
	$(RTL_SYNTHESIS_CANONICAL_SV_DIR)/relu_unit.sv \
	$(RTL_SYNTHESIS_ALIAS) \
	$(RTL_SYNTHESIS_COMPAT) \
	$(RTL_SYNTHESIS_CORE) \
	$(RTL_SYNTHESIS_CANONICAL_SV_DIR)/weight_rom.sv \
	$(RTL_SYNTHESIS_CANONICAL_SV_DIR)/mlp_core.sv
RTL_SYNTHESIS_NOTE := experiments/implementation-branch-comparison.md
RTL_SYNTHESIS_FLOW_DEPS := $(RTL_SV_DIR)/controller.sv \
	$(RTL_SV_DIR)/mac_unit.sv \
	$(RTL_SV_DIR)/relu_unit.sv \
	$(RTL_SV_DIR)/weight_rom.sv \
	$(RTL_SV_DIR)/mlp_core.sv \
	$(RTL_SYNTHESIS_COMPAT) \
	rtl-synthesis/controller/run_flow.py \
	rtl-synthesis/controller/controller.tlsf \
	rtl-synthesis/controller/formal/formal_controller_spot_equivalence.sv \
	rtl-synthesis/controller/formal/formal_closed_loop_mlp_core_equivalence.sv \
	specs/rtl-synthesis/requirement.md \
	specs/rtl-synthesis/design.md \
	$(RTL_SYNTHESIS_NOTE)
RTL_SYNTHESIS_IVERILOG_BIN := $(RTL_SYNTHESIS_BUILD_DIR)/sim/iverilog/testbench.out
RTL_SYNTHESIS_VERILATOR_DIR := $(RTL_SYNTHESIS_BUILD_DIR)/sim/verilator
RTL_SYNTHESIS_VERILATOR_BIN := $(RTL_SYNTHESIS_VERILATOR_DIR)/Vtestbench
RTL_SYNTHESIS_INTERNAL_IVERILOG_BIN := $(RTL_SYNTHESIS_BUILD_DIR)/sim-internal/iverilog/testbench_internal.out
RTL_SYNTHESIS_INTERNAL_VERILATOR_DIR := $(RTL_SYNTHESIS_BUILD_DIR)/sim-internal/verilator
RTL_SYNTHESIS_INTERNAL_VERILATOR_BIN := $(RTL_SYNTHESIS_INTERNAL_VERILATOR_DIR)/Vtestbench_internal
RTL_SYNTHESIS_CANONICAL_CONTROLLER := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/controller.sv
RTL_SYNTHESIS_CANONICAL_CORE := $(RTL_SYNTHESIS_CANONICAL_SV_DIR)/controller_spot_core.sv
RTL_SYNTHESIS_BLUEPRINT := $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)/mlp_core.svg
RTL_SYNTHESIS_CONTROLLER_BLUEPRINT := $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)/controller.svg
RTL_SYNTHESIS_CONTROLLER_CORE_BLUEPRINT := $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)/controller_spot_core.svg
RTL_SYNTHESIS_REUSED_BLUEPRINTS := mac_unit relu_unit weight_rom
RTL_SYNTHESIS_REUSED_BLUEPRINT_TARGETS := $(addprefix $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)/,$(addsuffix .svg,$(RTL_SYNTHESIS_REUSED_BLUEPRINTS)))
RTL_FORMALIZE_WRAPPER_BLUEPRINT := $(RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR)/mlp_core.svg
RTL_FORMALIZE_RAW_BLUEPRINT := $(RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR)/sparkle_mlp_core.svg
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
	$(VENDOR_PREPARE_SCRIPT) --tool ltlsynt

vendor-openlane-prepare:
	@command -v bash >/dev/null 2>&1 || { echo "missing required tool: bash"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "missing required tool: curl"; exit 1; }
	$(VENDOR_PREPARE_SCRIPT) --tool openlane

sim: contract-preflight sim-check-tools sim-iverilog sim-verilator

sim-internal: contract-preflight sim-check-tools sim-internal-iverilog sim-internal-verilator

sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "missing required tool: verilator"; exit 1; }

sim-vectors: contract-preflight

sim-iverilog: contract-preflight $(IVERILOG_BIN)
	vvp $(IVERILOG_BIN)

$(IVERILOG_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(SIM_RTL)

sim-verilator: contract-preflight $(VERILATOR_BIN)
	$(VERILATOR_BIN)

$(VERILATOR_BIN): $(SIM_RTL) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(VERILATOR_DIR) $(SIM_TB) $(SIM_RTL)

sim-internal-iverilog: contract-preflight $(SIM_INTERNAL_IVERILOG_BIN)
	vvp $(SIM_INTERNAL_IVERILOG_BIN)

$(SIM_INTERNAL_IVERILOG_BIN): $(SIM_RTL) $(SIM_INTERNAL_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench_internal -o $@ $(SIM_INTERNAL_TB) $(SIM_RTL)

sim-internal-verilator: contract-preflight $(SIM_INTERNAL_VERILATOR_BIN)
	$(SIM_INTERNAL_VERILATOR_BIN)

$(SIM_INTERNAL_VERILATOR_BIN): $(SIM_RTL) $(SIM_INTERNAL_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(SIM_INTERNAL_VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --top-module testbench_internal --prefix Vtestbench_internal --Mdir $(SIM_INTERNAL_VERILATOR_DIR) $(SIM_INTERNAL_TB) $(SIM_RTL)

clean-sim:
	rm -rf $(SIM_BUILD_DIR) $(SIM_INTERNAL_BUILD_DIR)

rtl-formalize-synthesis-prepare: $(SPARKLE_PREPARE_STAMP)

$(SPARKLE_PREPARE_STAMP): $(SPARKLE_PREPARE_SCRIPT) $(SPARKLE_PATCH_FILE)
	@command -v git >/dev/null 2>&1 || { echo "missing required tool: git"; exit 1; }
	@mkdir -p $(dir $@)
	$(SPARKLE_PREPARE_SCRIPT)
	@touch $@

rtl-formalize-synthesis-build: $(SPARKLE_PREPARE_STAMP)
	@command -v lake >/dev/null 2>&1 || { echo "missing required tool: lake"; exit 1; }
	cd $(SPARKLE_PKG_DIR) && lake build TinyMLPSparkle

$(SPARKLE_FULL_CORE_ARTIFACT): $(SPARKLE_EMIT_SOURCES) | rtl-formalize-synthesis-prepare
	@mkdir -p $(SPARKLE_GENERATED_DIR)
	cd $(SPARKLE_PKG_DIR) && lake build TinyMLPSparkle.Emit

$(SPARKLE_FULL_CORE_WRAPPER): $(SPARKLE_FULL_CORE_ARTIFACT) $(SPARKLE_WRAPPER_GENERATOR) $(SPARKLE_VERIFICATION_MANIFEST)
	@mkdir -p $(SPARKLE_GENERATED_DIR)
	python3 $(SPARKLE_WRAPPER_GENERATOR) --raw $(SPARKLE_FULL_CORE_ARTIFACT) --wrapper $@ --subset-manifest $(SPARKLE_VERIFICATION_MANIFEST)

rtl-formalize-synthesis-emit: $(SPARKLE_FULL_CORE_ARTIFACT) $(SPARKLE_FULL_CORE_WRAPPER)

rtl-formalize-synthesis-emit-full-core: $(SPARKLE_FULL_CORE_ARTIFACT) $(SPARKLE_FULL_CORE_WRAPPER)

rtl-formalize-synthesis-blueprint: $(RTL_FORMALIZE_WRAPPER_BLUEPRINT) $(RTL_FORMALIZE_RAW_BLUEPRINT)

rtl-formalize-synthesis-canonical: rtl-formalize-synthesis-emit rtl-formalize-synthesis-blueprint

rtl-formalize-synthesis-sim-check-tools: sim-check-tools

rtl-formalize-synthesis-sim: contract-preflight rtl-formalize-synthesis-sim-check-tools rtl-formalize-synthesis-iverilog rtl-formalize-synthesis-verilator

rtl-formalize-synthesis-iverilog: contract-preflight $(SPARKLE_FULL_CORE_IVERILOG_BIN)
	vvp $(SPARKLE_FULL_CORE_IVERILOG_BIN)

$(SPARKLE_FULL_CORE_IVERILOG_BIN): $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT)

rtl-formalize-synthesis-verilator: contract-preflight $(SPARKLE_FULL_CORE_VERILATOR_BIN)
	$(SPARKLE_FULL_CORE_VERILATOR_BIN)

$(SPARKLE_FULL_CORE_VERILATOR_BIN): $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(SPARKLE_FULL_CORE_VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(SPARKLE_FULL_CORE_VERILATOR_DIR) $(SIM_TB) $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT)

clean-rtl-formalize-synthesis:
	rm -rf $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)

rtl-synthesis-check-tools:
	@if ! command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1; then $(MAKE) vendor-synthesis-tools-prepare; fi
	@command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_LTLSYNT)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_YOSYS)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_SMTBMC)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_Z3)"; exit 1; }

$(RTL_SYNTHESIS_SUMMARY): $(RTL_SYNTHESIS_FLOW_DEPS) | rtl-synthesis-check-tools
	python3 rtl-synthesis/controller/run_flow.py --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --yosys $(RTL_SYNTHESIS_YOSYS) --smtbmc $(RTL_SYNTHESIS_SMTBMC) --solver $(RTL_SYNTHESIS_Z3) --summary $(RTL_SYNTHESIS_SUMMARY)

rtl-synthesis: $(RTL_SYNTHESIS_SUMMARY)

rtl-synthesis-canonical: $(RTL_SYNTHESIS_SUMMARY)
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_SV_DIR)
	cp $(RTL_SYNTHESIS_GENERATED_DIR)/controller.sv $(RTL_SYNTHESIS_CANONICAL_CONTROLLER)
	cp $(RTL_SYNTHESIS_GENERATED_DIR)/controller_spot_core.sv $(RTL_SYNTHESIS_CANONICAL_CORE)
	$(MAKE) rtl-synthesis-blueprint

rtl-synthesis-blueprint: $(RTL_SYNTHESIS_BLUEPRINT) $(RTL_SYNTHESIS_CONTROLLER_BLUEPRINT) $(RTL_SYNTHESIS_CONTROLLER_CORE_BLUEPRINT) $(RTL_SYNTHESIS_REUSED_BLUEPRINT_TARGETS)

rtl-synthesis-smoke:
	python3 rtl-synthesis/test/test_rtl_synthesis.py

rtl-synthesis-sim: contract-preflight sim-check-tools rtl-synthesis-iverilog rtl-synthesis-verilator

rtl-synthesis-sim-internal: contract-preflight sim-check-tools rtl-synthesis-internal-iverilog rtl-synthesis-internal-verilator

rtl-synthesis-iverilog: contract-preflight $(RTL_SYNTHESIS_IVERILOG_BIN)
	vvp $(RTL_SYNTHESIS_IVERILOG_BIN)

$(RTL_SYNTHESIS_IVERILOG_BIN): $(RTL_SYNTHESIS_SIM_RTL) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench -o $@ $(SIM_TB) $(RTL_SYNTHESIS_SIM_RTL)

rtl-synthesis-verilator: contract-preflight $(RTL_SYNTHESIS_VERILATOR_BIN)
	$(RTL_SYNTHESIS_VERILATOR_BIN)

$(RTL_SYNTHESIS_VERILATOR_BIN): $(RTL_SYNTHESIS_SIM_RTL) $(SIM_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(RTL_SYNTHESIS_VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --Mdir $(RTL_SYNTHESIS_VERILATOR_DIR) $(SIM_TB) $(RTL_SYNTHESIS_SIM_RTL)

rtl-synthesis-internal-iverilog: contract-preflight $(RTL_SYNTHESIS_INTERNAL_IVERILOG_BIN)
	vvp $(RTL_SYNTHESIS_INTERNAL_IVERILOG_BIN)

$(RTL_SYNTHESIS_INTERNAL_IVERILOG_BIN): $(RTL_SYNTHESIS_SIM_RTL) $(SIM_INTERNAL_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(dir $@)
	iverilog -g2012 $(SIM_INCLUDE_DIRS) -s testbench_internal -o $@ $(SIM_INTERNAL_TB) $(RTL_SYNTHESIS_SIM_RTL)

rtl-synthesis-internal-verilator: contract-preflight $(RTL_SYNTHESIS_INTERNAL_VERILATOR_BIN)
	$(RTL_SYNTHESIS_INTERNAL_VERILATOR_BIN)

$(RTL_SYNTHESIS_INTERNAL_VERILATOR_BIN): $(RTL_SYNTHESIS_SIM_RTL) $(SIM_INTERNAL_TB) $(SIM_VECTORS) $(SIM_VECTOR_META)
	@mkdir -p $(RTL_SYNTHESIS_INTERNAL_VERILATOR_DIR)
	verilator --binary --timing $(SIM_INCLUDE_DIRS) --top-module testbench_internal --prefix Vtestbench_internal --Mdir $(RTL_SYNTHESIS_INTERNAL_VERILATOR_DIR) $(SIM_INTERNAL_TB) $(RTL_SYNTHESIS_SIM_RTL)

clean-rtl-synthesis:
	rm -rf build/rtl-synthesis

# --- SMT targets ---

SMT_BUILD_DIR := build/smt
SMT_Z3 ?= z3
SMT_YOSYS ?= yosys
SMT_SMTBMC ?= yosys-smtbmc
SMT_RTL_SUMMARY := $(SMT_BUILD_DIR)/rtl_control_summary.json
SMT_SPARKLE_SUMMARY := $(SMT_BUILD_DIR)/rtl_formalize_synthesis_summary.json
SMT_CONTRACT_SUMMARY := $(SMT_BUILD_DIR)/contract_assumptions.json
SMT_CONTRACT_OVERFLOW_SUMMARY := $(SMT_BUILD_DIR)/contract_overflow_summary.json
SMT_CONTRACT_EQUIV_SUMMARY := $(SMT_BUILD_DIR)/contract_equivalence_summary.json
EXPERIMENTS_BUILD_DIR := build/experiments
EXPERIMENTS_RUNNER := python3 experiments/run.py

smt: smt-check-tools smt-contract-assumptions smt-rtl-control smt-rtl-formalize-synthesis smt-contract-overflow smt-contract-equivalence

smt-check-tools:
	@command -v $(SMT_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_Z3)"; exit 1; }
	@command -v $(SMT_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_YOSYS)"; exit 1; }
	@command -v $(SMT_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_SMTBMC)"; exit 1; }

smt-contract-assumptions:
	python3 smt/contract/export_assumptions.py --output $(SMT_CONTRACT_SUMMARY)

smt-rtl-control:
	python3 smt/rtl/check_control.py --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --summary $(SMT_RTL_SUMMARY)

smt-rtl-formalize-synthesis: rtl-formalize-synthesis-emit
	python3 smt/rtl/check_control.py --branch rtl-formalize-synthesis --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --summary $(SMT_SPARKLE_SUMMARY)

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
SHOW_BLUEPRINT_DIR := $(RTL_BLUEPRINT_DIR)
SHOW_DOCS_ASSETS_DIR := docs/assets
SHOW_MODULES := mlp_core controller mac_unit relu_unit weight_rom

show: show-check-tools $(addprefix $(SHOW_BLUEPRINT_DIR)/,$(addsuffix .svg,$(SHOW_MODULES))) $(addprefix $(SHOW_DOCS_ASSETS_DIR)/,$(addsuffix .svg,$(SHOW_MODULES)))
	@echo "---"
	@echo "SVGs written to $(SHOW_BLUEPRINT_DIR)/ and $(SHOW_DOCS_ASSETS_DIR)/"
	@ls -1 $(SHOW_BLUEPRINT_DIR)/*.svg

show-check-tools:
	@command -v yosys >/dev/null 2>&1 || { echo "missing required tool: yosys (brew install yosys)"; exit 1; }
	@command -v netlistsvg >/dev/null 2>&1 || { echo "missing required tool: netlistsvg (npm install -g netlistsvg)"; exit 1; }

$(SHOW_BUILD_DIR)/%.json: $(SIM_RTL)
	@mkdir -p $(SHOW_BUILD_DIR)
	yosys -q -p "read_verilog -sv $(SIM_RTL); hierarchy -check -top $*; proc; opt; write_json $@"

$(SHOW_BUILD_DIR)/%.svg: $(SHOW_BUILD_DIR)/%.json
	netlistsvg $< -o $@

$(SHOW_BLUEPRINT_DIR)/%.svg: $(SHOW_BUILD_DIR)/%.svg
	@mkdir -p $(SHOW_BLUEPRINT_DIR)
	cp $< $@

$(SHOW_DOCS_ASSETS_DIR)/%.svg: $(SHOW_BLUEPRINT_DIR)/%.svg
	@mkdir -p $(SHOW_DOCS_ASSETS_DIR)
	cp $< $@

$(RTL_SYNTHESIS_BLUEPRINT): $(RTL_SYNTHESIS_SIM_RTL)
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR) $(SHOW_BUILD_DIR)/rtl-synthesis
	yosys -q -p "read_verilog -sv $(RTL_SYNTHESIS_SIM_RTL); hierarchy -check -top mlp_core; proc; opt; write_json $(SHOW_BUILD_DIR)/rtl-synthesis/mlp_core.json"
	netlistsvg $(SHOW_BUILD_DIR)/rtl-synthesis/mlp_core.json -o $@

$(RTL_SYNTHESIS_CONTROLLER_BLUEPRINT): $(RTL_SYNTHESIS_ALIAS) $(RTL_SYNTHESIS_COMPAT) $(RTL_SYNTHESIS_CORE)
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR) $(SHOW_BUILD_DIR)/rtl-synthesis
	yosys -q -p "read_verilog -sv $(RTL_SYNTHESIS_ALIAS) $(RTL_SYNTHESIS_COMPAT) $(RTL_SYNTHESIS_CORE); hierarchy -check -top controller; proc; opt; write_json $(SHOW_BUILD_DIR)/rtl-synthesis/controller.json"
	netlistsvg $(SHOW_BUILD_DIR)/rtl-synthesis/controller.json -o $@

$(RTL_SYNTHESIS_CONTROLLER_CORE_BLUEPRINT): $(RTL_SYNTHESIS_CORE)
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR) $(SHOW_BUILD_DIR)/rtl-synthesis
	yosys -q -p "read_verilog -sv $(RTL_SYNTHESIS_CORE); hierarchy -check -top controller_spot_core; proc; opt; write_json $(SHOW_BUILD_DIR)/rtl-synthesis/controller_spot_core.json"
	netlistsvg $(SHOW_BUILD_DIR)/rtl-synthesis/controller_spot_core.json -o $@

$(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)/%.svg: $(RTL_BLUEPRINT_DIR)/%.svg
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR)
	ln -sfn ../../../../rtl/results/canonical/blueprint/$*.svg $@

$(RTL_FORMALIZE_WRAPPER_BLUEPRINT): $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT)
	@mkdir -p $(RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR) $(SHOW_BUILD_DIR)/rtl-formalize-synthesis
	yosys -q -p "read_verilog -sv $(SPARKLE_FULL_CORE_WRAPPER) $(SPARKLE_FULL_CORE_ARTIFACT); hierarchy -check -top mlp_core; proc; opt; write_json $(SHOW_BUILD_DIR)/rtl-formalize-synthesis/mlp_core.json"
	netlistsvg $(SHOW_BUILD_DIR)/rtl-formalize-synthesis/mlp_core.json -o $@

$(RTL_FORMALIZE_RAW_BLUEPRINT): $(SPARKLE_FULL_CORE_ARTIFACT)
	@mkdir -p $(RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR) $(SHOW_BUILD_DIR)/rtl-formalize-synthesis
	yosys -q -p "read_verilog -sv $(SPARKLE_FULL_CORE_ARTIFACT); hierarchy -check -top TinyMLP_sparkleMlpCorePacked; proc; opt; write_json $(SHOW_BUILD_DIR)/rtl-formalize-synthesis/sparkle_mlp_core.json"
	netlistsvg $(SHOW_BUILD_DIR)/rtl-formalize-synthesis/sparkle_mlp_core.json -o $@

clean-show:
	rm -rf $(SHOW_BUILD_DIR)
	rm -f $(addprefix $(SHOW_BLUEPRINT_DIR)/,$(addsuffix .svg,$(SHOW_MODULES)))
	rm -f $(addprefix $(SHOW_DOCS_ASSETS_DIR)/,$(addsuffix .svg,$(SHOW_MODULES)))
