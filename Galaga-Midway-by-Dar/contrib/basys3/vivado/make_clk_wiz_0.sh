#!/bin/bash
# Generate the clk_wiz_0 MMCM IP (100 MHz -> 36 MHz core) for the
# Basys3 port and place its Verilog wrappers where galaga_basys3.xpr expects them.
#
# The main project's .xpr references two imported files (galaga_basys3.xpr):
#   sources_1/imports/clk_wiz_0/clk_wiz_0.v
#   sources_1/imports/clk_wiz_0/clk_wiz_0_clk_wiz.v
# The IP is generated here in a throwaway Vivado project named mmcm_36m and
# only those two .v files are copied into the repo. Per project rules this script
# runs from /tmp so vivado.log / vivado.jou stay outside the repository.

# 36.864 MHz = 18.432 MHz crystal x 2: the wrapper's clock_18 becomes
# 18.432 MHz, pixel 6.144 MHz, CPUs 3.072 MHz, as the original board
# (sf-darfpga/CLOCKING_SPEC.md section 4). Vivado's own solve for this request
# is 6 / 50.875 / 23.0 = 36.86594 MHz (+57 ppm), which puts VGA H at
# 32.0017 kHz, above the 32.0 kHz design limit; the constants are therefore
# rewritten below to DIVCLK 6 / MULT_F 56.125 / CLKOUT0_DIVIDE_F 25.375
# (VCO 935.417 MHz, 36.863711 MHz, -8 ppm, VGA H 31.9998 kHz).

set -euo pipefail

VIVADO=/tools/Xilinx/Vivado/2020.2/bin/vivado
PART=xc7a35tcpg236-1

# Absolute path to this repo's basys3 port tree.
XPR_DIR="$(cd "$(dirname "$0")/../../../vhdl_galaga_rev_0_3_2018_05_06/basys3" && pwd)"
CLK_WIZ_IMPORT_DIR="$XPR_DIR/galaga_basys3.srcs/sources_1/imports/clk_wiz_0"

# Throwaway project location (logs stay outside the repo).
WORK=/tmp/mmcm_36m
TCL=$WORK/gen_clk_wiz_0.tcl

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TCL" <<EOF
create_project mmcm_36m "$WORK" -part $PART -force

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir "$WORK"

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {36.864} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
EOF

"$VIVADO" -mode batch -nolog -nojournal -source "$TCL"

GEN_DIR="$WORK/clk_wiz_0"
mkdir -p "$CLK_WIZ_IMPORT_DIR"
cp "$GEN_DIR/clk_wiz_0.v"            "$CLK_WIZ_IMPORT_DIR/"
cp "$GEN_DIR/clk_wiz_0_clk_wiz.v"    "$CLK_WIZ_IMPORT_DIR/"

# Force the 36.863711 MHz solve (see header). The generated .v is build output
# inside the gitignored project tree, so this rewrite lives only in this
# tracked script (same method as Computer-Space-by-Dar).
MMCM="$CLK_WIZ_IMPORT_DIR/clk_wiz_0_clk_wiz.v"
sed -i \
    -e 's/\.DIVCLK_DIVIDE *( *[0-9]* *)/.DIVCLK_DIVIDE        (6)/' \
    -e 's/\.CLKFBOUT_MULT_F *( *[0-9.]* *)/.CLKFBOUT_MULT_F      (56.125)/' \
    -e 's/\.CLKOUT0_DIVIDE_F *( *[0-9.]* *)/.CLKOUT0_DIVIDE_F     (25.375)/' \
    "$MMCM"
echo "Rewrote MMCM constants (36.863711 MHz):"
grep -n "DIVCLK_DIVIDE\|CLKFBOUT_MULT_F\|CLKOUT0_DIVIDE_F" "$MMCM" | sed 's/^/  /'

rm -rf "$WORK"

echo "Generated clk_wiz_0 IP files:"
ls -l "$CLK_WIZ_IMPORT_DIR"