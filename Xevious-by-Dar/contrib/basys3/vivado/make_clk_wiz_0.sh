#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 18.432 MHz core) for the Basys3
# port and place its Verilog wrappers where xevious_basys3.xpr expects them.
#
# Single output: 18.432 MHz = the original 18.432 MHz crystal, so pixel
# (f/3) = 6.144 MHz and the three CPUs (f/6) = 3.072 MHz. The PS/2 keyboard
# also runs on this clock (former 11 MHz CLKOUT2 removed; single clock
# domain, sf-darfpga/CLOCKING_SPEC.md sections 4 and 5.2). Vivado solve
# (2026-10-01): DIVCLK 7 / MULT_F 61.125 / CLKOUT0_DIVIDE_F 47.375
# (18.43196 MHz, -1 ppm).
#
# The main project's .xpr references two imported files (xevious_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_18m_11m and
# only those two .v files are copied into the repo. Per project rules this script
# runs from /tmp so vivado.log / vivado.jou stay outside the repository.

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_xevious_de2_de10_lite_2017_05_01/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/xevious_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/mmcm_18m_11m
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_18m_11m "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {18.432} \
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
