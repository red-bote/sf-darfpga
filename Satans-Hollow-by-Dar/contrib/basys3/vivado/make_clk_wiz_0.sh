#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 40.000 MHz core/sound clock) for
# the Basys3 port and place its Verilog wrappers where satans_hollow_basys3.xpr
# expects them.
#
# The main project's .xpr references two imported files
# (satans_hollow_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_40m and
# only those two .v files are copied into the repo. Per project rules this
# script runs from /tmp so vivado.log / vivado.jou stay outside the
# repository.
#
# Requires the basys3/ project tree to already exist (run `make create_prj`
# first).

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_satans_hollow_rev_0_2_2019_11_22/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/satans_hollow_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/satans_mmcm_40m
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_40m "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {40.000} \
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