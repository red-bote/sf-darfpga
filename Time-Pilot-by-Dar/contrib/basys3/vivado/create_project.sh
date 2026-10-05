#!/bin/bash
# Create the initial Vivado Basys3 project for the Time Pilot port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is non-nested (unlike Pooyan): the .xpr lives directly in basys3/ and
# the project sources tree is basys3/time_pilot_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr (references the local scandoubler import directly).
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
# 4. Copy the MiST scandoubler.v (contrib/code/) into sources_1/imports/mist/ and
#    apply scandoubler_fix.patch to the copy (2026-10-05; replaces the DECA
#    vga_scandoubler.v, see contrib/basys3/PORTING_SPEC.md).
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_time_pilot_rev_0_0_2017_11_05"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/time_pilot_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/time_pilot_basys3.srcs/sources_1/imports/mist"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_time_pilot.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/4 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT" "$SOURCES_IMPORT"

step "2/4 Copying time_pilot_basys3.xpr"
# The tracked .xpr references the project-local import
# (sources_1/imports/mist/scandoubler.v) directly.
cp -f "$CONTRIB/vivado/time_pilot_basys3.xpr" "$PROJ_DIR/time_pilot_basys3.xpr"

step "3/4 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

step "4/4 Copying scandoubler.v (single-value array size -> full range)"
cp -f "$ROOT/contrib/code/scandoubler.v" "$SOURCES_IMPORT/scandoubler.v"
# Vivado 2020.2 Verilog-2001 parser rejects the single-value unpacked array
# size 'sd_buffer[2*2**HCNT_WIDTH]' (Synth 8-2671); the canonical import stays
# pristine, so apply the fix only to the copied instance.
(cd "$PROJ_DIR" && patch -p1 --forward < "$ROOT/contrib/code/scandoubler_fix.patch")

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/time_pilot_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/scandoubler.v"