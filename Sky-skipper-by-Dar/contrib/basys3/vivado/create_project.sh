#!/bin/bash
# Create the initial Vivado Basys3 project for the Sky Skipper port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is non-nested (unlike Pooyan): the .xpr lives directly in basys3/ and
# the project sources tree is basys3/sky_skipper_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr into place.
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
#
# The core generates progressive 31 kHz video natively (tv15Khz_mode = '0'
# drives pixels on a 20 MHz clock with real video_hs/video_vs; '1' selects the
# 15 kHz interlaced timing), so no external scandoubler is imported.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_sky_skipper_rev_01_2020_01_28"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/sky_skipper_basys3.srcs/constrs_1/imports/digilent-xdc-master"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_sky_skipper.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/3 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT"

step "2/3 Copying sky_skipper_basys3.xpr"
cp -f "$CONTRIB/vivado/sky_skipper_basys3.xpr" "$PROJ_DIR/sky_skipper_basys3.xpr"

step "3/3 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/sky_skipper_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"