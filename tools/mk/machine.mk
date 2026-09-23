# Shared target set for sf-darfpga Dar-convention Basys3 ports.
#
# A machine's own Makefile sets the variables below, then does:
#   include ../tools/mk/machine.mk
#
# Required:
#   GAME       snake_case name; selects contrib/tools/setup_$(GAME).sh and
#              contrib/basys3/tools/make_$(GAME)_basys3_bitstream.sh
#   SRC_DIR    extracted archive dir, removed by `clean`
#   TOP_ENTITY Basys3 top entity (usually $(GAME)_basys3)
# Optional (may be left empty):
#   DISPLAY_NAME human-readable name for `make help`'s title line (default:
#                $(GAME) verbatim, e.g. "burger_time" instead of "BurgerTime")
#   IO_SUMMARY   external IO summary, printed by `make help`
#   DISPLAY_HINT display-mode switching input, printed by `make help` and at
#                the end of `make all` / `make bitstream`

TOOLS        := contrib/tools
BASYS3_TOOLS := contrib/basys3/tools
VIVADO       := contrib/basys3/vivado
BIT          := $(SRC_DIR)/basys3/$(TOP_ENTITY).runs/impl_1/$(TOP_ENTITY).bit

DISPLAY_REMINDER := @echo "REMINDER: if nothing appears on the display, first try toggling the display mode: $(DISPLAY_HINT)."

define display_reminder
	$(if $(DISPLAY_HINT),$(DISPLAY_REMINDER))
endef

.PHONY: all setup create_prj clk_wiz patch synth bitstream load rebuild-load clean help

all: setup clk_wiz patch
	$(display_reminder)

setup:
	$(TOOLS)/setup_$(GAME).sh

create_prj:
	$(VIVADO)/create_project.sh

clk_wiz: setup create_prj
	$(VIVADO)/make_clk_wiz_0.sh

# Regenerate contrib/basys3/code/*_de10_lite_to_basys3.patch and place
# contrib/basys3/code/$(TOP_ENTITY).vhd into the Vivado project.
patch: setup
	$(BASYS3_TOOLS)/make_de10_lite_to_basys3_patch.sh

# Run synthesis only (resets synth_1 first).
synth: setup clk_wiz patch
	$(BASYS3_TOOLS)/make_$(GAME)_basys3_bitstream.sh synth

# Implementation + write_bitstream (depends on synthesis).
bitstream: synth
	$(BASYS3_TOOLS)/make_$(GAME)_basys3_bitstream.sh bitstream
	$(display_reminder)

# Program the bitstream into the Basys3 SRAM with openFPGALoader. Fast: does
# NOT rebuild -- programs the existing .bit only. Fails clearly if none
# exists. Volatile: the FPGA loses the configuration on power cycle.
load:
	@test -f $(BIT) || { echo "No bitstream at $(BIT) - run 'make bitstream' first." >&2; exit 1; }
	openFPGALoader -b basys3 $(BIT)

# Fresh build then program (previous `make load` behavior).
rebuild-load: bitstream
	openFPGALoader -b basys3 $(BIT)

clean:
	rm -rf $(SRC_DIR)

DISPLAY_NAME ?= $(GAME)

help:
	@echo "$(DISPLAY_NAME) Basys 3 port. External IO used: $(IO_SUMMARY)"
	@echo "Steps: setup create_prj clk_wiz patch synth bitstream load (program existing bit) rebuild-load clean (default: all)"
	$(display_reminder)
