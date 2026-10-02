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
# 4. Copy vga_scandoubler.v into sources_1/imports/deca/.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_time_pilot_rev_0_0_2017_11_05"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/time_pilot_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/time_pilot_basys3.srcs/sources_1/imports/deca"

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
# (sources_1/imports/deca/vga_scandoubler.v) directly (2026-10-02; formerly
# an external ../../../Arcade_Pooyan path re-pointed here by sed).
cp -f "$CONTRIB/vivado/time_pilot_basys3.xpr" "$PROJ_DIR/time_pilot_basys3.xpr"

step "3/4 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

step "4/4 Copying vga_scandoubler.v"
cp -f "$CONTRIB/code/vga_scandoubler.v" "$SOURCES_IMPORT/vga_scandoubler.v"

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/time_pilot_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/vga_scandoubler.v"