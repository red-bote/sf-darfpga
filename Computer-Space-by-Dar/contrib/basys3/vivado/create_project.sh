#!/bin/bash
# Create the initial Vivado Basys3 project for the Computer Space port in the
# extracted Dar source tree, and copy the tracked port assets into place.
#
# Layout is non-nested (unlike Pooyan): the .xpr lives directly in basys3/ and
# the project sources tree is basys3/computer_space_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy the .xpr into place.
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
# 4. Copy scandoubler.v into sources_1/imports/mist/ and apply the Vivado
#    2020.2 Verilog-2001 parser fix to the copied instance only.
# 5. Copy the six generated sound ROM replacements (rom_*.vhd) into
#    sources_1/imports/cs_roms/. These define the same entity names as the
#    Altera altsyncram ROMs (bakam/explosion/rocket_rotate/rocket_shooting/
#    rocket_thrust/saucer_shooting) but as generic VHDL that infers BRAM with
#    inline ROM content generated from the .hex files by gen_sound_roms.py at
#    `make setup` time. The Altera originals in rtl/ are deliberately absent
#    from the .xpr source list so there is no entity-name clash.
# 6. Copy motion_board.vhd into sources_1/imports/rtl/ and apply
#    computer_space_motion_q_assoc.patch + computer_space_rocket_timer_synth_fix.patch
#    + computer_space_motion_single_domain.patch (in that order)
#    to that copy only -- the pristine rtl/motion_board.vhd is never
#    modified. Matches the .xpr, which references this imported copy
#    (sources_1/imports/rtl/motion_board.vhd), not the pristine file in
#    place -- see the machine README.md.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level (patch script)
# are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC_DIR="$ROOT/vhdl_computer_space_rev_1_1_2017_11_22"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$SRC_DIR/basys3"
CONSTRS_IMPORT="$PROJ_DIR/computer_space_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/computer_space_basys3.srcs/sources_1/imports/mist"
ROM_IMPORT="$PROJ_DIR/computer_space_basys3.srcs/sources_1/imports/cs_roms"
RTL_IMPORT="$PROJ_DIR/computer_space_basys3.srcs/sources_1/imports/rtl"
GEN_DIR="$SRC_DIR/basys3/generated_sound_roms"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run contrib/tools/setup_computer_space.sh first." >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/6 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT" "$SOURCES_IMPORT" "$ROM_IMPORT" "$RTL_IMPORT"

step "2/6 Copying computer_space_basys3.xpr"
cp -f "$CONTRIB/vivado/computer_space_basys3.xpr" "$PROJ_DIR/computer_space_basys3.xpr"

step "3/6 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

step "4/6 Copying scandoubler.v (single-value array size -> full range)"
cp -f "$ROOT/contrib/code/scandoubler.v" "$SOURCES_IMPORT/scandoubler.v"
# Vivado 2020.2 Verilog-2001 parser rejects the single-value unpacked array
# size 'sd_buffer[2*2**HCNT_WIDTH]' (Synth 8-2671); the canonical import stays
# pristine, so apply the fix only to the copied instance.
(cd "$PROJ_DIR" && patch -p1 --forward < "$ROOT/contrib/code/scandoubler_fix.patch")

if [ ! -d "$GEN_DIR" ]; then
    echo "error: generated sound ROMs not found: $GEN_DIR" >&2
    echo "Run contrib/tools/setup_computer_space.sh first (generates rom_*.vhd)." >&2
    exit 1
fi

step "5/6 Copying generated sound ROM replacements (rom_*.vhd)"
cp -f "$GEN_DIR"/*.vhd "$ROM_IMPORT/"

step "6/6 Copying motion_board.vhd and applying its fix patches to the copy"
cp -f "$SRC_DIR/rtl/motion_board.vhd" "$RTL_IMPORT/motion_board.vhd"
# --binary: motion_board.vhd is CRLF (as extracted); a plain `patch` run
# strips trailing CRs from the patch and cannot match it. The pristine
# rtl/motion_board.vhd is never modified -- only this imported copy.
for p in "$ROOT/contrib/code/computer_space_motion_q_assoc.patch" \
         "$ROOT/contrib/code/computer_space_rocket_timer_synth_fix.patch" \
         "$ROOT/contrib/code/computer_space_motion_single_domain.patch"; do
    if (cd "$PROJ_DIR" && patch --binary -p1 -R --dry-run --forward < "$p" > /dev/null 2>&1); then
        echo "==> already applied, skipping $(basename "$p")"
    else
        echo "==> applying $(basename "$p")"
        (cd "$PROJ_DIR" && patch --binary -p1 --forward < "$p")
    fi
done

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/computer_space_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/scandoubler.v"
ls -l "$ROM_IMPORT/"
ls -l "$RTL_IMPORT/motion_board.vhd"
