#!/bin/bash
# Create the initial Vivado Basys3 project for the Xevious port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is non-nested (like Defender/BurgerTime, Galaga and Phoenix): the .xpr
# lives directly in basys3/ and the project sources tree is basys3/xevious_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr.
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
# 4. Copy scandoubler.v into sources_1/imports/mist/ and apply its fix.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_xevious_de2_de10_lite_2017_05_01"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/xevious_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/xevious_basys3.srcs/sources_1/imports/mist"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_xevious.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/4 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT" "$SOURCES_IMPORT"

step "2/4 Copying xevious_basys3.xpr"
cp -f "$CONTRIB/vivado/xevious_basys3.xpr" "$PROJ_DIR/xevious_basys3.xpr"

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
ls -l "$PROJ_DIR/xevious_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/scandoubler.v"
