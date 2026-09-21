# Default target: build the whole scripted Basys3 port tree.
SCRIPTS := contrib/basys3/tools
TOOLS := contrib/tools
VIVADO := contrib/basys3/vivado

.PHONY: all setup create_prj clk_wiz clean patch synth bitstream

all: setup clk_wiz patch

setup:
	$(TOOLS)/setup_pooyan.sh

create_prj:
	$(VIVADO)/create_project.sh

# Regenerate pooyan_de10_lite_to_basys3.patch and pooyan_basys3.vhd top level.
patch: setup
	$(SCRIPTS)/make_de10_lite_to_basys3_patch.sh

clk_wiz: setup create_prj
	$(VIVADO)/make_clk_wiz_0.sh

# Run synthesis only (resets synth_1 first).
synth: setup clk_wiz patch
	$(SCRIPTS)/make_pooyan_basys3_bitstream.sh synth

# Implementation + write_bitstream (depends on synthesis).
bitstream: synth
	$(SCRIPTS)/make_pooyan_basys3_bitstream.sh bitstream

clean:
	rm -rf vhdl_pooyan_rev_0_2_2020_04_26
