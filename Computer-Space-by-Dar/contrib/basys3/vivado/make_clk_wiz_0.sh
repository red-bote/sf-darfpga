#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 48 MHz, single output) for the
# Basys3 port and place its Verilog wrappers where computer_space_basys3.xpr
# expects them.
#
# Single output (2026-10-02, contrib/basys3/PORTING_SPEC.md §Clocking):
#   clk_out1 = 48.000 MHz -> the whole design (core, scandoubler clk_sys,
#                            keyboard, PWM); 6 MHz pixel and 12 MHz scandoubler
#                            rates are clock enables in the wrapper.
# Replaces the former 50 / 6 / 12 MHz three-output set (VCO forced to 600 by a
# post-generation constant rewrite), whose crossings failed setup (WNS -4.785
# ns) and hold (WHS -0.497 ns). 48 MHz is an exact auto-solver result
# (D 5, M 49.5, O0 20.625: 100/5*49.5/20.625 = 48.000), so no
# constant rewrite is needed; the solve is printed below for the record.
#
# The main project's .xpr references three imported files
# (computer_space_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_computerspace
# and only those .v files are copied into the repo. Per project rules this script
# runs from /tmp so vivado.log / vivado.jou stay outside the repository.

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_computer_space_rev_1_1_2017_11_22/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/computer_space_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/mmcm_computerspace
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_computerspace "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {48} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
EOF

"$VIVADO" -mode batch -nolog -nojournal -source "$TCL"

GEN_DIR="$WORK/clk_wiz_0"
mkdir -p "$CLK_WIZ_IMPORT_DIR"
cp "$GEN_DIR/clk_wiz_0.v"            "$CLK_WIZ_IMPORT_DIR/"
cp "$GEN_DIR/clk_wiz_0_clk_wiz.v"    "$CLK_WIZ_IMPORT_DIR/"

MMCM="$CLK_WIZ_IMPORT_DIR/clk_wiz_0_clk_wiz.v"
echo "MMCM solve (expect 48.000 MHz):"
grep -n "DIVCLK_DIVIDE\|CLKFBOUT_MULT_F\|CLKOUT0_DIVIDE_F" "$MMCM" | sed 's/^/  /'

rm -rf "$WORK"

echo "Generated clk_wiz_0 IP files:"
ls -l "$CLK_WIZ_IMPORT_DIR"
