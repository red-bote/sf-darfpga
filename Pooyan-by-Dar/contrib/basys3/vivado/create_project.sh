#!/bin/bash
# Create the initial Vivado Basys3 project for the Pooyan port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is flat, matching every other sf-darfpga machine: the .xpr lives at
# basys3/pooyan_basys3.xpr and the project sources tree is
# basys3/pooyan_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr (already references the local deca import, no sed needed).
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
# 4. Copy vga_scandoubler.v into sources_1/imports/deca/.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_pooyan_rev_0_2_2020_04_26"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/pooyan_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/pooyan_basys3.srcs/sources_1/imports/deca"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_pooyan.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/4 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT" "$SOURCES_IMPORT"

step "2/4 Copying pooyan_basys3.xpr"
cp -f "$CONTRIB/vivado/pooyan_basys3.xpr" "$PROJ_DIR/pooyan_basys3.xpr"

step "3/4 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/pooyan_basys3.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

step "4/4 Copying vga_scandoubler.v"
cp -f "$CONTRIB/code/vga_scandoubler.v" "$SOURCES_IMPORT/vga_scandoubler.v"

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/pooyan_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/vga_scandoubler.v"