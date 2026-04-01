.PHONY: train evaluate quantize export freeze freeze-check contract-preflight \
       formalize formalize-check-tools formalize-smt formalize-smt-check-tools verify \
       vendor-tools-prepare vendor-synthesis-tools-prepare vendor-openlane-prepare \
       sim sim-internal sim-check-tools sim-iverilog sim-verilator sim-internal-iverilog sim-internal-verilator clean-sim sim-vectors rtl-blueprint \
       smt smt-check-tools smt-rtl-control smt-rtl-synthesis smt-rtl-formalize-synthesis smt-rtl-hls4ml \
       smt-contract-assumptions smt-contract-overflow smt-contract-equivalence clean-smt \
       experiments experiments-artifact-consistency experiments-semantic-closure \
       experiments-branch-compare experiments-qor experiments-post-synth clean-experiments \
       rtl-synthesis rtl-synthesis-check-tools rtl-synthesis-smoke rtl-synthesis-sim rtl-synthesis-sim-internal rtl-synthesis-iverilog \
       rtl-synthesis-canonical rtl-synthesis-blueprint \
       rtl-synthesis-verilator rtl-synthesis-internal-iverilog rtl-synthesis-internal-verilator clean-rtl-synthesis \
       rtl-formalize-synthesis-prepare rtl-formalize-synthesis-emit rtl-formalize-synthesis-emit-full-core \
       rtl-formalize-synthesis-build rtl-formalize-synthesis-blueprint rtl-formalize-synthesis-canonical rtl-formalize-synthesis-sim rtl-formalize-synthesis-iverilog \
       rtl-formalize-synthesis-verilator rtl-formalize-synthesis-sim-check-tools clean-rtl-formalize-synthesis \
       rtl-hls4ml rtl-hls4ml-emit rtl-hls4ml-check rtl-hls4ml-blueprint rtl-hls4ml-canonical \
       rtl-hls4ml-sim rtl-hls4ml-iverilog rtl-hls4ml-verilator clean-rtl-hls4ml

ANN_CLI := python3 ann/runners/main.py
CONTRACT_FREEZE_RUNNER := python3 contract/runners/freeze.py
SIM_RUNNER := python3 simulations/runners/run.py
RTL_BLUEPRINT_RUNNER := python3 rtl/runners/blueprint.py
RTL_SYNTHESIS_RUNNER := python3 rtl-synthesis/runners/spot_flow.py
RTL_SYNTHESIS_BLUEPRINT_RUNNER := python3 rtl-synthesis/runners/blueprint.py
RTL_FORMALIZE_EMIT_RUNNER := python3 rtl-formalize-synthesis/runners/emit.py
RTL_FORMALIZE_BLUEPRINT_RUNNER := python3 rtl-formalize-synthesis/runners/blueprint.py
SMT_ALL_RUNNER := python3 smt/runners/all.py
SMT_RTL_RUNNER := python3 smt/runners/rtl.py
SMT_CONTRACT_ASSUMPTIONS_RUNNER := python3 smt/runners/contract_assumptions.py
SMT_CONTRACT_OVERFLOW_RUNNER := python3 smt/runners/contract_overflow.py
SMT_CONTRACT_EQUIV_RUNNER := python3 smt/runners/contract_equivalence.py
EXPERIMENTS_RUNNER := python3 experiments/runners/run.py
FORMALIZE_PKG_DIR := formalize
FORMALIZE_SMT_PKG_DIR := formalize-smt
BUILD_ROOT := build
REPORTS_ROOT := reports
RTL_BUILD_ROOT := $(BUILD_ROOT)/rtl
RTL_SYNTHESIS_BUILD_ROOT := $(BUILD_ROOT)/rtl-synthesis
RTL_FORMALIZE_BUILD_ROOT := $(BUILD_ROOT)/rtl-formalize-synthesis
SMT_BUILD_ROOT := $(BUILD_ROOT)/smt
EXPERIMENTS_BUILD_ROOT := $(BUILD_ROOT)/experiments
TESTS_BUILD_ROOT := $(BUILD_ROOT)/tests
RTL_REPORT_ROOT := $(REPORTS_ROOT)/rtl
RTL_SYNTHESIS_REPORT_ROOT := $(REPORTS_ROOT)/rtl-synthesis
RTL_FORMALIZE_REPORT_ROOT := $(REPORTS_ROOT)/rtl-formalize-synthesis
SMT_REPORT_ROOT := $(REPORTS_ROOT)/smt
EXPERIMENTS_REPORT_ROOT := $(REPORTS_ROOT)/experiments
RTL_CANONICAL_DIR := rtl/results/canonical
RTL_SV_DIR := $(RTL_CANONICAL_DIR)/sv
RTL_BLUEPRINT_DIR := $(RTL_CANONICAL_DIR)/blueprint
RTL_SYNTHESIS_CANONICAL_DIR := rtl-synthesis/results/canonical
RTL_SYNTHESIS_CANONICAL_SV_DIR := $(RTL_SYNTHESIS_CANONICAL_DIR)/sv
RTL_SYNTHESIS_CANONICAL_BLUEPRINT_DIR := $(RTL_SYNTHESIS_CANONICAL_DIR)/blueprint
RTL_FORMALIZE_CANONICAL_DIR := rtl-formalize-synthesis/results/canonical
RTL_FORMALIZE_CANONICAL_SV_DIR := $(RTL_FORMALIZE_CANONICAL_DIR)/sv
RTL_FORMALIZE_CANONICAL_BLUEPRINT_DIR := $(RTL_FORMALIZE_CANONICAL_DIR)/blueprint
RTL_HLS4ML_EMIT_RUNNER := python3 rtl-hls4ml/runners/emit.py
RTL_HLS4ML_BLUEPRINT_RUNNER := python3 rtl-hls4ml/runners/blueprint.py
RTL_HLS4ML_BUILD_ROOT := $(BUILD_ROOT)/rtl-hls4ml
RTL_HLS4ML_REPORT_ROOT := $(REPORTS_ROOT)/rtl-hls4ml
RTL_HLS4ML_CANONICAL_DIR := rtl-hls4ml/results/canonical
RTL_HLS4ML_CANONICAL_SV_DIR := $(RTL_HLS4ML_CANONICAL_DIR)/sv
RTL_HLS4ML_CANONICAL_BLUEPRINT_DIR := $(RTL_HLS4ML_CANONICAL_DIR)/blueprint

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
	$(CONTRACT_FREEZE_RUNNER) $(ARGS)

freeze-check:
	$(CONTRACT_FREEZE_RUNNER) --check

contract-preflight: freeze-check

# --- Lean proof targets ---

formalize-check-tools:
	@command -v lake >/dev/null 2>&1 || { echo "missing required tool: lake"; exit 1; }

formalize: formalize-check-tools
	cd $(FORMALIZE_PKG_DIR) && lake build

formalize-smt-check-tools:
	@command -v lake >/dev/null 2>&1 || { echo "missing required tool: lake"; exit 1; }

formalize-smt: formalize-smt-check-tools
	cd $(FORMALIZE_SMT_PKG_DIR) && lake build

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
SIM_BUILD_DIR := $(RTL_BUILD_ROOT)/canonical/simulations/shared
SIM_INTERNAL_BUILD_DIR := $(RTL_BUILD_ROOT)/canonical/simulations/internal
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
SPARKLE_FULL_CORE_SIM_BUILD_DIR := $(RTL_FORMALIZE_BUILD_ROOT)/canonical/simulations/shared
SPARKLE_FULL_CORE_IVERILOG_BIN := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/iverilog/testbench.out
SPARKLE_FULL_CORE_VERILATOR_DIR := $(SPARKLE_FULL_CORE_SIM_BUILD_DIR)/verilator
SPARKLE_FULL_CORE_VERILATOR_BIN := $(SPARKLE_FULL_CORE_VERILATOR_DIR)/Vtestbench
SPARKLE_PKG_DIR := rtl-formalize-synthesis
SPARKLE_WRAPPER_GENERATOR := $(SPARKLE_PKG_DIR)/scripts/generate_wrapper.py
SPARKLE_BACKEND_METADATA_EXPORT := $(SPARKLE_PKG_DIR)/scripts/export_backend_metadata.lean
SPARKLE_VERIFICATION_REFRESH := $(SPARKLE_PKG_DIR)/scripts/refresh_verification_manifest.py
SPARKLE_VERIFICATION_MANIFEST := $(SPARKLE_PKG_DIR)/results/canonical/verification_manifest.json
SPARKLE_VENDOR_DIR := $(SPARKLE_PKG_DIR)/vendor/Sparkle
SPARKLE_PREPARE_SCRIPT := $(SPARKLE_PKG_DIR)/scripts/prepare_sparkle.sh
SPARKLE_PATCH_FILE := $(SPARKLE_PKG_DIR)/patches/sparkle-local.patch
SPARKLE_PREPARE_STAMP := $(RTL_FORMALIZE_BUILD_ROOT)/canonical/flow/prepare/sparkle_prepare.stamp
VENDOR_PREPARE_SCRIPT := scripts/prepare_vendor_tools.sh
VENDOR_DIR := vendor
VENDOR_SPOT_INSTALL_DIR := $(abspath $(VENDOR_DIR)/spot-install)
VENDOR_SYFCO_INSTALL_DIR := $(abspath $(VENDOR_DIR)/syfco-install)
VENDOR_OPENLANE_DIR := $(abspath $(VENDOR_DIR)/OpenLane)
VENDOR_LTLSYNT_BIN := $(VENDOR_SPOT_INSTALL_DIR)/bin/ltlsynt
VENDOR_SYFCO_BIN := $(VENDOR_SYFCO_INSTALL_DIR)/bin/syfco
VENDOR_OPENLANE_FLOW := $(VENDOR_OPENLANE_DIR)/flow.tcl
SPARKLE_EMIT_SOURCES := $(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/Emit.lean \
	$(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/Types.lean \
	$(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/ControllerSignal.lean \
	$(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/ContractData.lean \
	$(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/DatapathSignal.lean \
	$(SPARKLE_PKG_DIR)/src/MlpCoreSparkle/MlpCoreSignal.lean \
	$(SPARKLE_PREPARE_SCRIPT) \
	$(SPARKLE_PKG_DIR)/patches/sparkle-local.patch \
	$(SPARKLE_PKG_DIR)/lakefile.lean \
	$(SPARKLE_PKG_DIR)/lean-toolchain \
	$(SPARKLE_PKG_DIR)/lake-manifest.json
RTL_SYNTHESIS_FLOW_BUILD_DIR := $(RTL_SYNTHESIS_BUILD_ROOT)/canonical/flow/spot
RTL_SYNTHESIS_GENERATED_DIR := $(RTL_SYNTHESIS_FLOW_BUILD_DIR)/generated
RTL_SYNTHESIS_SUMMARY := $(RTL_SYNTHESIS_REPORT_ROOT)/canonical/flow/spot/summary.json
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
RTL_SYNTHESIS_SIM_BUILD_DIR := $(RTL_SYNTHESIS_BUILD_ROOT)/canonical/simulations/shared
RTL_SYNTHESIS_INTERNAL_SIM_BUILD_DIR := $(RTL_SYNTHESIS_BUILD_ROOT)/canonical/simulations/internal
RTL_SYNTHESIS_IVERILOG_BIN := $(RTL_SYNTHESIS_SIM_BUILD_DIR)/iverilog/testbench.out
RTL_SYNTHESIS_VERILATOR_DIR := $(RTL_SYNTHESIS_SIM_BUILD_DIR)/verilator
RTL_SYNTHESIS_VERILATOR_BIN := $(RTL_SYNTHESIS_VERILATOR_DIR)/Vtestbench
RTL_SYNTHESIS_INTERNAL_IVERILOG_BIN := $(RTL_SYNTHESIS_INTERNAL_SIM_BUILD_DIR)/iverilog/testbench_internal.out
RTL_SYNTHESIS_INTERNAL_VERILATOR_DIR := $(RTL_SYNTHESIS_INTERNAL_SIM_BUILD_DIR)/verilator
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

sim: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile shared --simulator all --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

sim-internal: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile internal --simulator all --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

sim-check-tools:
	@command -v iverilog >/dev/null 2>&1 || { echo "missing required tool: iverilog"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "missing required tool: vvp"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "missing required tool: verilator"; exit 1; }

sim-vectors: contract-preflight

sim-iverilog: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile shared --simulator iverilog --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

sim-verilator: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile shared --simulator verilator --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

sim-internal-iverilog: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile internal --simulator iverilog --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

sim-internal-verilator: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl --profile internal --simulator verilator --build-root $(RTL_BUILD_ROOT) --report-root $(RTL_REPORT_ROOT)

rtl-blueprint:
	$(RTL_BLUEPRINT_RUNNER)

clean-sim:
	rm -rf $(RTL_BUILD_ROOT) $(RTL_REPORT_ROOT)

rtl-formalize-synthesis-prepare:
	$(RTL_FORMALIZE_EMIT_RUNNER) --prepare-only $(ARGS)

rtl-formalize-synthesis-build:
	$(RTL_FORMALIZE_EMIT_RUNNER) --build-only $(ARGS)

rtl-formalize-synthesis-emit:
	$(RTL_FORMALIZE_EMIT_RUNNER) --emit $(ARGS)

rtl-formalize-synthesis-emit-full-core:
	$(RTL_FORMALIZE_EMIT_RUNNER) --emit $(ARGS)

rtl-formalize-synthesis-blueprint:
	$(RTL_FORMALIZE_BLUEPRINT_RUNNER)

rtl-formalize-synthesis-canonical: rtl-formalize-synthesis-emit rtl-formalize-synthesis-blueprint

rtl-formalize-synthesis-sim-check-tools: sim-check-tools

rtl-formalize-synthesis-sim: contract-preflight rtl-formalize-synthesis-sim-check-tools
	$(SIM_RUNNER) --branch rtl-formalize-synthesis --profile shared --simulator all --build-root $(RTL_FORMALIZE_BUILD_ROOT) --report-root $(RTL_FORMALIZE_REPORT_ROOT)

rtl-formalize-synthesis-iverilog: contract-preflight rtl-formalize-synthesis-sim-check-tools
	$(SIM_RUNNER) --branch rtl-formalize-synthesis --profile shared --simulator iverilog --build-root $(RTL_FORMALIZE_BUILD_ROOT) --report-root $(RTL_FORMALIZE_REPORT_ROOT)

rtl-formalize-synthesis-verilator: contract-preflight rtl-formalize-synthesis-sim-check-tools
	$(SIM_RUNNER) --branch rtl-formalize-synthesis --profile shared --simulator verilator --build-root $(RTL_FORMALIZE_BUILD_ROOT) --report-root $(RTL_FORMALIZE_REPORT_ROOT)

clean-rtl-formalize-synthesis:
	rm -rf $(RTL_FORMALIZE_BUILD_ROOT) $(RTL_FORMALIZE_REPORT_ROOT)

# --- rtl-hls4ml targets ---

rtl-hls4ml: rtl-hls4ml-emit

rtl-hls4ml-emit:
	$(RTL_HLS4ML_EMIT_RUNNER) --emit

rtl-hls4ml-check:
	$(RTL_HLS4ML_EMIT_RUNNER) --check

rtl-hls4ml-blueprint:
	$(RTL_HLS4ML_BLUEPRINT_RUNNER)

rtl-hls4ml-canonical: rtl-hls4ml-emit rtl-hls4ml-blueprint

rtl-hls4ml-sim: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-hls4ml --profile shared --simulator all --build-root $(RTL_HLS4ML_BUILD_ROOT) --report-root $(RTL_HLS4ML_REPORT_ROOT)

rtl-hls4ml-iverilog: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-hls4ml --profile shared --simulator iverilog --build-root $(RTL_HLS4ML_BUILD_ROOT) --report-root $(RTL_HLS4ML_REPORT_ROOT)

rtl-hls4ml-verilator: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-hls4ml --profile shared --simulator verilator --build-root $(RTL_HLS4ML_BUILD_ROOT) --report-root $(RTL_HLS4ML_REPORT_ROOT)

clean-rtl-hls4ml:
	rm -rf $(RTL_HLS4ML_BUILD_ROOT) $(RTL_HLS4ML_REPORT_ROOT)

rtl-synthesis-check-tools:
	@if ! command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1; then $(MAKE) vendor-synthesis-tools-prepare; fi
	@command -v $(RTL_SYNTHESIS_LTLSYNT) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_LTLSYNT)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_YOSYS)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_SMTBMC)"; exit 1; }
	@command -v $(RTL_SYNTHESIS_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(RTL_SYNTHESIS_Z3)"; exit 1; }

rtl-synthesis: rtl-synthesis-check-tools
	$(RTL_SYNTHESIS_RUNNER) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --yosys $(RTL_SYNTHESIS_YOSYS) --smtbmc $(RTL_SYNTHESIS_SMTBMC) --solver $(RTL_SYNTHESIS_Z3) --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-canonical: rtl-synthesis
	@mkdir -p $(RTL_SYNTHESIS_CANONICAL_SV_DIR)
	cp $(RTL_SYNTHESIS_GENERATED_DIR)/controller.sv $(RTL_SYNTHESIS_CANONICAL_CONTROLLER)
	cp $(RTL_SYNTHESIS_GENERATED_DIR)/controller_spot_core.sv $(RTL_SYNTHESIS_CANONICAL_CORE)
	$(MAKE) rtl-synthesis-blueprint

rtl-synthesis-blueprint:
	$(RTL_SYNTHESIS_BLUEPRINT_RUNNER)

rtl-synthesis-smoke:
	python3 rtl-synthesis/test/test_rtl_synthesis.py

rtl-synthesis-sim: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile shared --simulator all --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-sim-internal: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile internal --simulator all --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-iverilog: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile shared --simulator iverilog --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-verilator: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile shared --simulator verilator --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-internal-iverilog: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile internal --simulator iverilog --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

rtl-synthesis-internal-verilator: contract-preflight sim-check-tools
	$(SIM_RUNNER) --branch rtl-synthesis --profile internal --simulator verilator --build-root $(RTL_SYNTHESIS_BUILD_ROOT) --report-root $(RTL_SYNTHESIS_REPORT_ROOT)

clean-rtl-synthesis:
	rm -rf $(RTL_SYNTHESIS_BUILD_ROOT) $(RTL_SYNTHESIS_REPORT_ROOT)

# --- SMT targets ---

SMT_Z3 ?= z3
SMT_YOSYS ?= yosys
SMT_SMTBMC ?= yosys-smtbmc
smt: smt-check-tools
	$(SMT_ALL_RUNNER) --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-check-tools:
	@command -v $(SMT_Z3) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_Z3)"; exit 1; }
	@command -v $(SMT_YOSYS) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_YOSYS)"; exit 1; }
	@command -v $(SMT_SMTBMC) >/dev/null 2>&1 || { echo "missing required tool: $(SMT_SMTBMC)"; exit 1; }

smt-contract-assumptions:
	$(SMT_CONTRACT_ASSUMPTIONS_RUNNER) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-rtl-control:
	$(SMT_RTL_RUNNER) --branch rtl --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-rtl-synthesis:
	$(SMT_RTL_RUNNER) --branch rtl-synthesis --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-rtl-formalize-synthesis: rtl-formalize-synthesis-emit
	$(SMT_RTL_RUNNER) --branch rtl-formalize-synthesis --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-rtl-hls4ml: smt-check-tools
	$(SMT_RTL_RUNNER) --branch rtl-hls4ml --yosys $(SMT_YOSYS) --smtbmc $(SMT_SMTBMC) --solver $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-contract-overflow:
	$(SMT_CONTRACT_OVERFLOW_RUNNER) --z3 $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

smt-contract-equivalence:
	$(SMT_CONTRACT_EQUIV_RUNNER) --z3 $(SMT_Z3) --build-root $(SMT_BUILD_ROOT) --report-root $(SMT_REPORT_ROOT)

clean-smt:
	rm -rf $(SMT_BUILD_ROOT) $(SMT_REPORT_ROOT)

# --- Experiment targets ---

experiments:
	$(EXPERIMENTS_RUNNER) --family all --build-root $(EXPERIMENTS_BUILD_ROOT) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-artifact-consistency:
	$(EXPERIMENTS_RUNNER) --family artifact-consistency --build-root $(EXPERIMENTS_BUILD_ROOT) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-semantic-closure:
	$(EXPERIMENTS_RUNNER) --family semantic-closure --build-root $(EXPERIMENTS_BUILD_ROOT) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-branch-compare:
	$(EXPERIMENTS_RUNNER) --family branch-compare --build-root $(EXPERIMENTS_BUILD_ROOT) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-qor:
	$(EXPERIMENTS_RUNNER) --family qor --build-root $(EXPERIMENTS_BUILD_ROOT) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

experiments-post-synth:
	@if ! command -v $(EXPERIMENTS_OPENLANE_FLOW) >/dev/null 2>&1; then $(MAKE) vendor-openlane-prepare; fi
	$(EXPERIMENTS_RUNNER) --family post-synth --build-root $(EXPERIMENTS_BUILD_DIR) --report-root $(EXPERIMENTS_REPORT_ROOT) --ltlsynt $(RTL_SYNTHESIS_LTLSYNT) --syfco $(RTL_SYNTHESIS_SYFCO) --openlane-flow $(EXPERIMENTS_OPENLANE_FLOW)

clean-experiments:
	rm -rf $(EXPERIMENTS_BUILD_DIR) $(EXPERIMENTS_REPORT_ROOT)
