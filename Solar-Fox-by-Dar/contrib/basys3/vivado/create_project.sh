#!/bin/bash
# Create the initial Vivado Basys3 project for the Solar Fox port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is non-nested (unlike Pooyan): the .xpr lives directly in basys3/ and
# the project sources tree is basys3/solar_fox_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr into place.
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
#
# The core generates progressive 31 kHz video natively (tv15Khz_mode = '0'), so
# no external scandoubler is imported.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_solar_fox_rev_0_1_2019_11_22"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/solar_fox_basys3.srcs/constrs_1/imports/digilent-xdc-master"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_solar_fox.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/3 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT"

step "2/3 Copying solar_fox_basys3.xpr"
cp -f "$CONTRIB/vivado/solar_fox_basys3.xpr" "$PROJ_DIR/solar_fox_basys3.xpr"

step "3/3 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/solar_fox_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
