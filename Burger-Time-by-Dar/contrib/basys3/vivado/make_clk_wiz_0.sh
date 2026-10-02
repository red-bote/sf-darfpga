#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 12 MHz, single output) for the
# Basys3 port and place its Verilog wrappers where
# burger_time_basys3.xpr expects them.
#
# The main project's .xpr references two imported files (burger_time_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_12m and
# only those two .v files are copied into the repo. Per project rules this script
# runs from /tmp so vivado.log / vivado.jou stay outside the repository.

# Single output (2026-10-02): the former 6 MHz CLKOUT2, used only as the
# scandoubler ce_x1 in the 12 MHz domain, failed hold timing (WHS -0.60 ns);
# ce_x1 is now a clock_12 toggle enable in the wrapper
# (sf-darfpga/CLOCKING_SPEC.md section 5.2).

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_burger_time_rev_0_0_2017_12_27/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/burger_time_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/mmcm_12m
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_12m "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {12} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
EOF

"$VIVADO" -mode batch -nolog -nojournal -source "$TCL"

GEN_DIR="$WORK/clk_wiz_0"
mkdir -p "$CLK_WIZ_IMPORT_DIR"
cp "$GEN_DIR/clk_wiz_0.v"            "$CLK_WIZ_IMPORT_DIR/"
cp "$GEN_DIR/clk_wiz_0_clk_wiz.v"    "$CLK_WIZ_IMPORT_DIR/"

rm -rf "$WORK"

echo "Generated clk_wiz_0 IP files:"
ls -l "$CLK_WIZ_IMPORT_DIR"
