# ==============================================================================
# Makefile: Sky130 Synthesis & Implementation Flow for 32-bit ALU Top Level
# ==============================================================================

# Target Design Configuration
TOP_MODULE    := top_32b
PDK           := sky130A
STD_CELL_LIBRARY := sky130_fd_sc_hd

# Directory Layout
RTL_DIR       := .
BUILD_DIR     := build
REPORTS_DIR   := reports
MACRO_DIR     := macros
MACRO_SRCS   := ./sramHD_64x64.v

# Include the header file in the sources list
RTL_SRCS     := $(RTL_DIR)/alu32_pkg.vh \
                $(RTL_DIR)/top_32b.v \
                $(RTL_DIR)/addsub_32b.v \
                $(RTL_DIR)/mult_32b.v \
                $(RTL_DIR)/top_scheduler.v

# Included Header Files / Packages
RTL_INCLUDES  := -I$(RTL_DIR)


# Microarchitecture & Synthesis Parameters
CLOCK_PORT    := clk
CLOCK_PERIOD  := 10.0# Target period in ns (100 MHz)

# Tools
YOSYS         := yosys
VERILATOR     := verilator
OPENROAD      := openroad

.PHONY: all clean lint synth openlane_config

all: lint synth

# ------------------------------------------------------------------------------
# 1. Linting & Static Verification
# ------------------------------------------------------------------------------
lint:
	@echo "==> Running Verilator Lint..."
	@mkdir -p $(REPORTS_DIR)
	$(VERILATOR) --lint-only -Wall $(RTL_INCLUDES) $(RTL_SRCS) --top-module $(TOP_MODULE) \
		2>&1 | tee $(REPORTS_DIR)/lint.log || true

# ------------------------------------------------------------------------------
# 2. Automated Yosys Synthesis Script Generation & Execution
# ------------------------------------------------------------------------------

synth: $(BUILD_DIR)/$(TOP_MODULE).gate.v

# Sky130 Liberty file path definition
SKY130_LIB ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Top-level synthesis target
synth: $(BUILD_DIR)/$(TOP_MODULE).gate.v

# Step 1: Generate the build/synth.ys script file
$(BUILD_DIR)/synth.ys: $(RTL_SRCS) $(MACRO_SRCS)
	@mkdir -p $(BUILD_DIR) $(REPORTS_DIR)
	@echo "==> Generating Yosys Elaboration and Synthesis Script..."
	@echo "read_verilog -lib $(MACRO_SRCS)" > $@
	@echo "read_verilog $(RTL_INCLUDES) $(RTL_SRCS)" >> $@
	@echo "hierarchy -check -top $(TOP_MODULE)" >> $@
	@echo "proc; opt; fsm; opt; memory; opt" >> $@
	@echo "synth -top $(TOP_MODULE)" >> $@
	@echo "write_verilog $(BUILD_DIR)/$(TOP_MODULE).gate.v" >> $@

# Step 2: Execute Yosys using the generated synth.ys script
$(BUILD_DIR)/$(TOP_MODULE).gate.v: $(BUILD_DIR)/synth.ys
	@echo "==> Executing Yosys Elaboration and Synthesis..."
	unset LD_LIBRARY_PATH && yosys -s $(BUILD_DIR)/synth.ys | tee $(REPORTS_DIR)/synthesis.log	

# ==============================================================================
# Target & PDK Parameters
# ==============================================================================
TOP_MODULE       := top_32b
PDK              := sky130A
STD_CELL_LIBRARY := sky130_fd_sc_hd
CLOCK_PORT       := clk
CLOCK_PERIOD     := 10.0

# Declare the JSON string in a define block (No tabs required inside define)
define OPENLANE_CONFIG_BODY
{
  "DESIGN_NAME": "$(TOP_MODULE)",
  "VERILOG_FILES": [
    "dir::addsub_32b.v",
    "dir::mult_32b.v",
    "dir::top_scheduler.v",
    "dir::top_32b.v"
  ],
  "CLOCK_PORT": "$(CLOCK_PORT)",
  "CLOCK_PERIOD": $(CLOCK_PERIOD),
  "PDK": "$(PDK)",
  "STD_CELL_LIBRARY": "$(STD_CELL_LIBRARY)",
  "SYNTH_STRATEGY": "DELAY 3",
  "SYNTH_ELABORATE_ONLY": 0,
  "MACROS": {
    "sramHD_64x64": {
      "gds": ["macros/sramHD_64x64.gds"],
      "lef": ["macros/sramHD_64x64.lef"],
      "instances": {
        "MEM0": {"location": [50, 50], "orientation": "N"},
        "MEM1": {"location": [50, 450], "orientation": "N"},
        "MEM2": {"location": [600, 250], "orientation": "FN"}
      }
    }
  },
  "FP_SIZING": "absolute",
  "DIE_AREA": [0, 0, 1200, 1000],
  "PL_TARGET_DENSITY": 0.45
}
endef

export OPENLANE_CONFIG_BODY

.PHONY: openlane_config

openlane_config:
	@echo "==> Generating OpenLane config.json..."
	@echo "$$OPENLANE_CONFIG_BODY" > config.json
	@echo "config.json successfully generated."
# ------------------------------------------------------------------------------
# 4. Cleanup
# ------------------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR) $(REPORTS_DIR) config.json
	@echo "Cleaned generated files."
