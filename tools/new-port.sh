#!/bin/bash
# Scaffold a new sf-darfpga Dar-convention Basys3 port from the wip/machine/
# templates, substituting the tokens a new port always needs instead of
# hand-copying 7 files and editing tokens by hand.
#
# Usage:
#   new-port.sh <game> --src-dir DIR --url URL --sha256 SHA
#               --de10-top FILE --top-entity NAME
#               [--io-summary TEXT] [--display-hint TEXT] [--dest DIR]
#
# <game> is the snake_case machine name (e.g. "galaga"). --dest defaults to
# <Game>-by-Dar/ (title-cased) under the repo root; pass --dest to override
# for names that don't fit that convention (e.g. "Bagman-FPGA-Dar").
#
# What this does NOT do (left for the porter, same as before this script
# existed): author contrib/basys3/code/<top-entity>.vhd (a stub is dropped;
# fill it in per PORTING_SPEC.md §4), fill in create_project.sh's
# <WITH_SCANDOUBLER> XDC pin uncommenting, or make_clk_wiz_0.sh's
# <clk_freq>/<mmcm_name>. Format the authored VHDL with
# sf-darfpga/tools/vhdl_formatter.py before committing.

set -euo pipefail

usage() {
    echo "usage: $0 <game> --src-dir DIR --url URL --sha256 SHA --de10-top FILE --top-entity NAME [--io-summary TEXT] [--display-hint TEXT] [--dest DIR]" >&2
    exit 2
}

[ $# -ge 1 ] || usage
GAME="$1"; shift

SRC_DIR="" URL="" SHA256="" DE10_TOP="" TOP_ENTITY="" IO_SUMMARY="" DISPLAY_HINT="" DEST=""
while [ $# -gt 0 ]; do
    case "$1" in
        --src-dir) SRC_DIR="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --sha256) SHA256="$2"; shift 2 ;;
        --de10-top) DE10_TOP="$2"; shift 2 ;;
        --top-entity) TOP_ENTITY="$2"; shift 2 ;;
        --io-summary) IO_SUMMARY="$2"; shift 2 ;;
        --display-hint) DISPLAY_HINT="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done
for req in SRC_DIR URL SHA256 DE10_TOP TOP_ENTITY; do
    [ -n "${!req}" ] || { echo "error: --${req,,} is required" | tr '_' '-' >&2; usage; }
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$REPO_ROOT/wip/machine"
if [ -z "$DEST" ]; then
    TITLE="$(tr '[:lower:]' '[:upper:]' <<< "${GAME:0:1}")${GAME:1}"
    DEST="$REPO_ROOT/${TITLE}-by-Dar"
fi

if [ -e "$DEST" ]; then
    echo "error: destination already exists: $DEST" >&2
    exit 1
fi

echo "==> Scaffolding $DEST"
mkdir -p "$DEST/contrib/tools" "$DEST/contrib/basys3/tools" "$DEST/contrib/basys3/code" "$DEST/contrib/basys3/vivado"

subst() {
    local in="$1" out="$2"
    # Token substitution, then drop the template's own authoring
    # instructions (the "Generic ... template" line and the
    # "Substitute: ..." / "Copy to ..." block) -- they describe how to fill
    # in the template by hand and don't belong in a generated file.
    sed \
        -e "s|<game>|$GAME|g" \
        -e "s|<src_dir>|$SRC_DIR|g" \
        -e "s|<url>|$URL|g" \
        -e "s|<sha256>|$SHA256|g" \
        -e "s|<DE10_TOP>|$DE10_TOP|g" \
        -e "s|<TOP_ENTITY>|$TOP_ENTITY|g" \
        -e "s|<io_summary>|$IO_SUMMARY|g" \
        -e "s|<display_hint>|$DISPLAY_HINT|g" \
        "$in" \
    | awk '
        /^# Generic .* template\.?$/ { next }
        /^# Substitute:/ { skip = 1 }
        skip { if (/^# Copy to /) skip = 0; next }
        { print }
    ' > "$out"
}

subst "$TEMPLATES/Makefile.template" "$DEST/Makefile"
subst "$TEMPLATES/contrib/tools/setup.sh.template" "$DEST/contrib/tools/setup_$GAME.sh"
subst "$TEMPLATES/contrib/tools/prep_roms.sh.template" "$DEST/contrib/tools/prep_roms.sh"
subst "$TEMPLATES/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh.template" "$DEST/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh"
subst "$TEMPLATES/contrib/basys3/tools/make_basys3_bitstream.sh.template" "$DEST/contrib/basys3/tools/make_${GAME}_basys3_bitstream.sh"
subst "$TEMPLATES/contrib/basys3/vivado/create_project.sh.template" "$DEST/contrib/basys3/vivado/create_project.sh"
subst "$TEMPLATES/contrib/basys3/vivado/make_clk_wiz_0.sh.template" "$DEST/contrib/basys3/vivado/make_clk_wiz_0.sh"

chmod +x \
    "$DEST/contrib/tools/setup_$GAME.sh" \
    "$DEST/contrib/tools/prep_roms.sh" \
    "$DEST/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh" \
    "$DEST/contrib/basys3/tools/make_${GAME}_basys3_bitstream.sh" \
    "$DEST/contrib/basys3/vivado/create_project.sh" \
    "$DEST/contrib/basys3/vivado/make_clk_wiz_0.sh"

cat > "$DEST/contrib/basys3/code/$TOP_ENTITY.vhd" <<EOF
-- TODO: author the Basys3 top level for $GAME here (see
-- contrib/basys3/PORTING_SPEC.md and the root PORTING_SPEC.md §3/§4).
-- Format with sf-darfpga/tools/vhdl_formatter.py before committing.
EOF

echo
echo "Scaffolded: $DEST"
echo "Still needed by hand:"
echo "  - author contrib/basys3/code/$TOP_ENTITY.vhd (stub dropped)"
echo "  - fill in contrib/tools/prep_roms.sh's <ROMZIPs> / romset-unzip step"
echo "  - fill in contrib/basys3/vivado/create_project.sh's scandoubler step (if any)"
echo "  - fill in contrib/basys3/vivado/make_clk_wiz_0.sh's <clk_freq>/<mmcm_name>"
echo "  - author $DEST/README.md and PORTING_SPEC.md"
