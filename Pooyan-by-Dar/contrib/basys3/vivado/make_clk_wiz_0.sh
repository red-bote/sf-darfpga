#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 24.576 MHz, single output) for the
# Basys3 port and place its Verilog wrappers where pooyan_basys3.xpr expects them.
#
# Single clock domain (2026-10-05, contrib/basys3/PORTING_SPEC.md section 2):
# clk_out1 = clk_core = 2 x 12.288 MHz clocks the core, sound board, scandoubler,
# keyboard and PWM; 12/6 MHz and the 14.318 MHz sound rate are clock enables in
# the wrapper. Replaces the former 12.288 + 14.318 MHz two-output set.
#
# The main project's .xpr references two imported files (pooyan_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_12m_14m and
# only those two .v files are copied into the repo. Per project rules this script
# runs from /tmp so vivado.log / vivado.jou stay outside the repository.

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_pooyan_rev_0_2_2020_04_26/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/pooyan_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/mmcm_12m_14m
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_12m_14m "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {24.576} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
EOF

"$VIVADO" -mode batch -nolog -nojournal -source "$TCL"

GEN_DIR="$WORK/clk_wiz_0"
mkdir -p "$CLK_WIZ_IMPORT_DIR"
cp "$GEN_DIR/clk_wiz_0.v"            "$CLK_WIZ_IMPORT_DIR/"
cp "$GEN_DIR/clk_wiz_0_clk_wiz.v"    "$CLK_WIZ_IMPORT_DIR/"

MMCM="$CLK_WIZ_IMPORT_DIR/clk_wiz_0_clk_wiz.v"
echo "MMCM solve (target 24.576 MHz):"
grep -n "DIVCLK_DIVIDE\|CLKFBOUT_MULT_F\|CLKOUT0_DIVIDE_F" "$MMCM" | sed 's/^/  /'

rm -rf "$WORK"

echo "Generated clk_wiz_0 IP files:"
ls -l "$CLK_WIZ_IMPORT_DIR"