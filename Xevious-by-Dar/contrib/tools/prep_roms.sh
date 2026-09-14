#!/bin/bash
# Linux rom-prep for the Xevious Basys3 port.
#
# 1. Stage a local build dir (tools/xevious_unzip/), copying the Dar
#    make_xevious_proms.bat out of the archive-shipped win64 staging dir.
# 2. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 3. Convert make_xevious_proms.bat -> make_xevious_proms.sh.
# 4. Unzip the romset (~/roms/xevious.zip) into tools/xevious_unzip/roms/
#    and rename the 9 color/sound PROMs from their MAME names to the Dar .bat
#    names (the archive ships them hyphenated; the .bat expects *_bpr.*).
# 5. Run make_xevious_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_xevious_de2_de10_lite_2017_05_01/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).
#
# .bat -> .sh rename mapping (romset name -> .bat name):
#   xevious.zip ships the color/sound PROMs under MAME hyphenated names; the
#   Dar make_xevious_proms.bat expects them under xvi_*_bpr.* names. Byte
#   sizes match (256 or 512 bytes each). The rename is a pure N:M rename at
#   staging time:
#
# The .bat uses Windows backslash paths (roms\<file>) and a duplicate_byte
# call that only feeds the unused 16-bit gfx variant (excluded from the .xpr).
# The .sh conversion therefore converts the "roms\" prefix to "roms/"
# (the roms are unzipped into a roms/ subdir) and drops the duplicate_byte
# line.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_xevious_de2_de10_lite_2017_05_01"
WIN64_DIR="$SRC_DIR/tools/xevious_unzip_win64"
PROM_DIR="$SRC_DIR/tools/xevious_unzip"
ROMS_DIR="$PROM_DIR/roms"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/xevious.zip}"

# (zip name -> .bat name) pairs for the 9 color/sound PROMs.
RENAME_PAIRS=(
    "xvi-1.5n:xvi_1bpr.5n"
    "xvi-2.7n:xvi_2bpr.7n"
    "xvi-4.3l:xvi_4bpr.3l"
    "xvi-5.3m:xvi_5bpr.3m"
    "xvi-6.4f:xvi_6bpr.4f"
    "xvi-7.4h:xvi_7bpr.4h"
    "xvi-8.6a:xvi_8bpr.6a"
    "xvi-9.6d:xvi_9bpr.6d"
    "xvi-10.6e:xvi10bpr.6e"
)

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_xevious.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/6 Staging make_xevious_proms.bat into $PROM_DIR"
if [ ! -f "$WIN64_DIR/make_xevious_proms.bat" ]; then
    echo "error: $WIN64_DIR/make_xevious_proms.bat not found" >&2
    exit 1
fi
cp -f "$WIN64_DIR/make_xevious_proms.bat" "$PROM_DIR/make_xevious_proms.bat"

step "2/6 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "3/6 Converting make_xevious_proms.bat to .sh"
sed -E \
    -e 's/\r$//' \
    -e 's/[[:space:]]+$//' \
    -e '/^rem/d' \
    -e '/^duplicate_byte/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/roms\\/roms\//g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_xevious_proms.bat" > "$PROM_DIR/make_xevious_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_xevious_proms.sh"
chmod +x "$PROM_DIR/make_xevious_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "4/6 Unzipping romset into $ROMS_DIR"
mkdir -p "$ROMS_DIR"
unzip -o "$ROMZIP" -d "$ROMS_DIR"

step "5/6 Renaming color/sound PROMs (MAME -> Dar .bat names)"
n=0
for pair in "${RENAME_PAIRS[@]}"; do
    from="${pair%%:*}"
    to="${pair##*:}"
    if [ -f "$ROMS_DIR/$from" ]; then
        if [ "$from" != "$to" ]; then
            mv -f "$ROMS_DIR/$from" "$ROMS_DIR/$to"
        fi
        n=$((n+1))
    else
        echo "warning: romset file not found: $from" >&2
    fi
done
echo "renamed $n/9 color/sound PROMs"

step "6/6 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_xevious_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd