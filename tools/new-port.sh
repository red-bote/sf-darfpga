#!/bin/bash
# Scaffold a new sf-darfpga Dar-convention Basys3 port from the wip/machine/
# templates (procedure: sf-darfpga/PORTING_SPEC.md section 2).
#
# Usage:
#   new-port.sh <game> --src-dir DIR --url URL --sha256 SHA --de10-top FILE
#               [--top-entity NAME] [--romset NAME] [--clk-freq MHZ]
#               [--display-name TEXT] [--io-summary TEXT]
#               [--mist-from MACHINE_DIR | --native-video] [--dest DIR]
#
# <game>        snake_case machine name (e.g. "galaga")
# --top-entity  Basys3 top entity (default <game>_basys3). darfpga-patch.sh names the
#               provenance patch after it with "_basys3" removed:
#               <top minus _basys3>_de10_lite_to_basys3.patch.
# --romset      MAME romset zip basename in ~/roms (default <game>)
# --clk-freq    clk_wiz_0 output in MHz (default 24.576; choose per PORTING_SPEC.md section 5)
# --mist-from   copy contrib/code/scandoubler.v and scandoubler_fix.patch from an existing
#               MiST-path machine (default Pooyan-by-Dar); the fix patch path prefix is
#               rewritten to the new top entity
# --native-video  no scandoubler (core has progressive output / tv15Khz_mode)
# --dest        machine directory (default <Game>-by-Dar under sf-darfpga)
#
# Creates: Makefile, README.md, dloads/, contrib/tools/{setup_<game>.sh,prep_roms.sh},
# contrib/basys3/{PORTING_SPEC.md, code/<top>.vhd (skeleton), tools/*, vivado/*},
# contrib/code/scandoubler.* (MiST path), and the root Makefile PORTS entry.
# Then lists the remaining TODO / <token> placeholders.

set -euo pipefail

usage() {
    sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

[ $# -ge 1 ] || usage
GAME="$1"; shift

SRC_DIR="" URL="" SHA256="" DE10_TOP="" TOP_ENTITY="" ROMSET="" CLK_FREQ="24.576"
DISPLAY_NAME="" IO_SUMMARY="" MIST_FROM="Pooyan-by-Dar" NATIVE="" DEST=""
while [ $# -gt 0 ]; do
    case "$1" in
        --src-dir) SRC_DIR="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --sha256) SHA256="$2"; shift 2 ;;
        --de10-top) DE10_TOP="$2"; shift 2 ;;
        --top-entity) TOP_ENTITY="$2"; shift 2 ;;
        --romset) ROMSET="$2"; shift 2 ;;
        --clk-freq) CLK_FREQ="$2"; shift 2 ;;
        --display-name) DISPLAY_NAME="$2"; shift 2 ;;
        --io-summary) IO_SUMMARY="$2"; shift 2 ;;
        --mist-from) MIST_FROM="$2"; shift 2 ;;
        --native-video) NATIVE=1; shift ;;
        --dest) DEST="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done
for req in SRC_DIR URL SHA256 DE10_TOP; do
    [ -n "${!req}" ] || { echo "error: --$(tr '[:upper:]_' '[:lower:]-' <<< "$req") is required" >&2; usage; }
done
[[ "$GAME" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "error: <game> must be snake_case: $GAME" >&2; exit 2; }
TOP_ENTITY="${TOP_ENTITY:-${GAME}_basys3}"
ROMSET="${ROMSET:-$GAME}"
TITLE="$(tr '[:lower:]' '[:upper:]' <<< "${GAME:0:1}")${GAME:1}"
DISPLAY_NAME="${DISPLAY_NAME:-$TITLE}"
IO_SUMMARY="${IO_SUMMARY:-USB-HID keyboard (MAME keys) + JXADC joystick; btnU/btnD=coin, btnL/btnR=start, btnC=reset; JA PmodAMP2 audio; sw15 up = audio off, sw14 up = gain; sw(13)=15 kHz TV}"

TREE="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$TREE/wip/machine"
DEST="${DEST:-$TREE/${TITLE//_/-}-by-Dar}"
MACHINE_DIR="$(basename "$DEST")"
TOKEN="${GAME//_/-}"

if [ -e "$DEST" ]; then
    echo "error: destination already exists: $DEST" >&2
    exit 1
fi
if grep -q "^  $TOKEN:" "$TREE/Makefile"; then
    echo "error: root Makefile PORTS already has $TOKEN" >&2
    exit 1
fi
if [ -z "$NATIVE" ] && [ ! -f "$TREE/$MIST_FROM/contrib/code/scandoubler.v" ]; then
    echo "error: no contrib/code/scandoubler.v in $MIST_FROM (use --mist-from or --native-video)" >&2
    exit 1
fi

echo "==> Scaffolding $DEST"
mkdir -p "$DEST/dloads" "$DEST/contrib/tools" "$DEST/contrib/code" \
         "$DEST/contrib/basys3/tools" "$DEST/contrib/basys3/code" "$DEST/contrib/basys3/vivado"

# Token substitution, then drop the template's own authoring header
# ("Generic ... template" line and the "Substitute: ..." .. "Copy to ..." block).
subst() {
    local in="$1" out="$2"
    sed \
        -e "s|<game>|$GAME|g" \
        -e "s|<src_dir>|$SRC_DIR|g" \
        -e "s|<url>|$URL|g" \
        -e "s|<sha256>|$SHA256|g" \
        -e "s|<DE10_TOP>|$DE10_TOP|g" \
        -e "s|<TOP_ENTITY>|$TOP_ENTITY|g" \
        -e "s|<romset>|$ROMSET|g" \
        -e "s|<clk_freq>|$CLK_FREQ|g" \
        -e "s|<display_name>|$DISPLAY_NAME|g" \
        -e "s|<io_summary>|$IO_SUMMARY|g" \
        -e "s|<Machine>|${MACHINE_DIR%-by-Dar}|g" \
        "$in" \
    | awk '
        /^# Generic .* template/ { next }
        /^# Substitute:/ { skip = 1 }
        skip { if (/^# Copy to /) skip = 0; next }
        { print }
    ' > "$out"
}

T="$TEMPLATES"
subst "$T/Makefile.template"                                       "$DEST/Makefile"
subst "$T/README.md.template"                                      "$DEST/README.md"
subst "$T/contrib/tools/setup.sh.template"                         "$DEST/contrib/tools/setup_$GAME.sh"
subst "$T/contrib/tools/prep_roms.sh.template"                     "$DEST/contrib/tools/prep_roms.sh"
subst "$T/contrib/basys3/PORTING_SPEC.md.template"                 "$DEST/contrib/basys3/PORTING_SPEC.md"
subst "$T/contrib/basys3/code/TOP_ENTITY.vhd.template"             "$DEST/contrib/basys3/code/$TOP_ENTITY.vhd"
subst "$T/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh.template" \
                                                                   "$DEST/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh"
subst "$T/contrib/basys3/tools/make_basys3_bitstream.sh.template"  "$DEST/contrib/basys3/tools/make_${GAME}_basys3_bitstream.sh"
subst "$T/contrib/basys3/vivado/create_project.sh.template"        "$DEST/contrib/basys3/vivado/create_project.sh"
subst "$T/contrib/basys3/vivado/make_clk_wiz_0.sh.template"        "$DEST/contrib/basys3/vivado/make_clk_wiz_0.sh"
subst "$T/contrib/basys3/vivado/TOP_ENTITY.xpr.template"           "$DEST/contrib/basys3/vivado/$TOP_ENTITY.xpr"
cp "$T/contrib/basys3/vivado/Basys-3-Master.xdc"                   "$DEST/contrib/basys3/vivado/Basys-3-Master.xdc"

if [ -z "$NATIVE" ]; then
    cp "$TREE/$MIST_FROM/contrib/code/scandoubler.v" "$DEST/contrib/code/scandoubler.v"
    src_top="$(sed -n 's|^--- a/\([^/]*\)\.srcs/.*|\1|p' "$TREE/$MIST_FROM/contrib/code/scandoubler_fix.patch" | head -1)"
    sed "s|$src_top\.srcs/|$TOP_ENTITY.srcs/|g" "$TREE/$MIST_FROM/contrib/code/scandoubler_fix.patch" \
        > "$DEST/contrib/code/scandoubler_fix.patch"
else
    # Native video: drop the scandoubler entry from the .xpr.
    python3 - "$DEST/contrib/basys3/vivado/$TOP_ENTITY.xpr" <<'PYEOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'      <!-- MiST-path machines only.*?-->\n      <File Path="\$PSRCDIR/sources_1/imports/mist/scandoubler\.v">.*?</File>\n', '', s, flags=re.S)
open(p, 'w').write(s)
PYEOF
fi

chmod +x \
    "$DEST/contrib/tools/setup_$GAME.sh" \
    "$DEST/contrib/tools/prep_roms.sh" \
    "$DEST/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh" \
    "$DEST/contrib/basys3/tools/make_${GAME}_basys3_bitstream.sh" \
    "$DEST/contrib/basys3/vivado/create_project.sh" \
    "$DEST/contrib/basys3/vivado/make_clk_wiz_0.sh"

# Root Makefile PORTS: append "  <token>:<dir>" after the last entry.
python3 - "$TREE/Makefile" "$TOKEN" "$MACHINE_DIR" <<'PYEOF'
import sys
p, token, d = sys.argv[1:]
lines = open(p).read().split('\n')
i = lines.index('PORTS := \\')
j = i + 1
while lines[j].endswith('\\'):
    j += 1
lines[j] = lines[j] + ' \\'
lines.insert(j + 1, '  %s:%s' % (token, d))
open(p, 'w').write('\n'.join(lines))
PYEOF

echo
echo "Scaffolded: $DEST (root Makefile PORTS: $TOKEN)"
echo "Remaining placeholders (fill in per sf-darfpga/PORTING_SPEC.md):"
{
    grep -rn "TODO\|<[A-Za-z_][A-Za-z0-9_ ,./|-]*>" "$DEST" --exclude='*.xpr' --exclude-dir=code
    grep -n "TODO" "$DEST/contrib/basys3/vivado/$TOP_ENTITY.xpr" | sed "s|^|$DEST/contrib/basys3/vivado/$TOP_ENTITY.xpr:|"
    grep -n "TODO\|<[A-Za-z_]" "$DEST/contrib/basys3/code/$TOP_ENTITY.vhd" | sed "s|^|$DEST/contrib/basys3/code/$TOP_ENTITY.vhd:|"
} | sed "s|^$DEST/||" | cut -c1-120 || true
