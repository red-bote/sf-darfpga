# Default target: build the whole scripted Basys3 port tree.
TOOLS        := contrib/tools
BASYS3_TOOLS := contrib/basys3/tools
VIVADO       := contrib/basys3/vivado

IO_SUMMARY   := USB HID keyboard (C17/B17); JA joystick; PmodAMP2 audio (JC); 4 pushbuttons
DISPLAY_HINT := sw(13) toggles 31 kHz VGA (scan-doubled) / 15 kHz TV (composite)

DISPLAY_REMINDER := @echo "REMINDER: if nothing appears on the display, first try toggling the display mode: $(DISPLAY_HINT)."

define display_reminder
	$(if $(DISPLAY_HINT),$(DISPLAY_REMINDER))
endef

.PHONY: all setup create_prj clk_wiz patch synth bitstream load rebuild-load clean help

all: setup clk_wiz patch
	$(display_reminder)

setup:
	$(TOOLS)/setup_traverse_usa.sh

create_prj:
	$(VIVADO)/create_project.sh

clk_wiz: setup create_prj
	$(VIVADO)/make_clk_wiz_0.sh

# Regenerate traverse_usa_de10_lite_to_basys3.patch and traverse_usa_basys3.vhd top level.
patch: setup
	$(BASYS3_TOOLS)/make_de10_lite_to_basys3_patch.sh

# Run synthesis only (resets synth_1 first).
synth: setup clk_wiz patch
	$(BASYS3_TOOLS)/make_traverse_usa_basys3_bitstream.sh synth

# Implementation + write_bitstream (depends on synthesis).
bitstream: synth
	$(BASYS3_TOOLS)/make_traverse_usa_basys3_bitstream.sh bitstream
	$(display_reminder)

# Program the bitstream into the Basys3 SRAM with openFPGALoader.
# Fast: this does NOT rebuild — it programs the existing bit only. Fails
# clearly if no bitstream has been built yet.
# Volatile: the FPGA loses the configuration on power cycle - re-run `make load`.
BIT := vhdl_traverse_usa_rev_0_0_2019_03_16/basys3/traverse_usa_basys3.runs/impl_1/traverse_usa_basys3.bit

load:
	@test -f $(BIT) || { echo "No bitstream at $(BIT) - run 'make bitstream' first." >&2; exit 1; }
	openFPGALoader -b basys3 $(BIT)

# Fresh build then program (previous `make load` behavior).
rebuild-load: bitstream
	openFPGALoader -b basys3 $(BIT)

clean:
	rm -rf vhdl_traverse_usa_rev_0_0_2019_03_16

help:
	@echo "Traverse USA Basys 3 port. External IO used: $(IO_SUMMARY)"
	@echo "Steps: setup create_prj clk_wiz patch synth bitstream load (program existing bit) rebuild-load clean (default: all)"
	$(display_reminder)
