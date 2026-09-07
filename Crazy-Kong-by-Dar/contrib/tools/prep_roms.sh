#!/bin/bash
# Linux rom-prep for the Crazy Kong Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_ckong_proms.bat -> make_ckong_proms.sh.
# 3. Unzip the romset ($ROMZIP, default ~/roms/ckong.zip) into tools/ckong_unzip/.
# 4. Run make_ckong_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree
# (vhdl_ckong_rev_0_1_2018_06_06/) to be already extracted; this
# script does not download or extract it.
#
# Romset: the Dar .bat references all 17 files of the ckong (Crazy Kong)
# MAME set by their exact canonical names, so no relabeling is needed -- the
# unzipped rom directory is used as-is. Dar's README notes the core plays
# Crazy Kong Part II (Falcon) and suggests ckongpt2.zip content, but the
# files named by the .bat (prog/tile/sprite/palette/sample) are present in
# ckong.zip; the pre/post-flight checks below catch a wrong/incomplete romset
# loudly instead of silently producing empty PROMs.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_ckong_rev_0_1_2018_06_06"
PROM_DIR="$SRC_DIR/tools/ckong_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/ckong.zip}"

INPUT_ROMS=(
    d05-07.bin f05-08.bin h05-09.bin k05-10.bin l05-11.bin n05-12.bin
    prom.v6 prom.u6
    n11-06.bin l11-05.bin
    k11-04.bin h11-03.bin
    cc13j.bin cc12j.bin
    c11-02.bin a11-01.bin
    prom.t6
)

OUTPUT_PROMS=(
    ckong_program.vhd
    ckong_tile_bit0.vhd ckong_tile_bit1.vhd
    ckong_big_sprite_tile_bit0.vhd ckong_big_sprite_tile_bit1.vhd
    ckong_palette.vhd ckong_big_sprite_palette.vhd
    ckong_samples.vhd
)

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_ckong.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_ckong_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_ckong_proms.bat" ]; then
    echo "error: $PROM_DIR/make_ckong_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_ckong_proms.bat" > "$PROM_DIR/make_ckong_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_ckong_proms.sh"
chmod +x "$PROM_DIR/make_ckong_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romset"
unzip -o "$ROMZIP" -d "$PROM_DIR"

step "Pre-flight: verifying all required ROMs are present"
missing=""
for f in "${INPUT_ROMS[@]}"; do
    if [ ! -s "$PROM_DIR/$f" ]; then
        missing="$missing $f"
    fi
done
if [ -n "$missing" ]; then
    echo "error: romset incomplete ($ROMZIP). Missing required ROMs:" >&2
    for f in $missing; do echo "  $f" >&2; done
    echo "Crazy Kong needs the ckong (parent) MAME set:" >&2
    echo "  darfpga .bat -> canonical name mapping." >&2
    exit 1
fi

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_ckong_proms.sh )

step "Post-flight: verifying all expected PROM VHDL files were generated"
missing=""
for f in "${OUTPUT_PROMS[@]}"; do
    if [ ! -s "$PROM_DIR/$f" ]; then
        missing="$missing $f"
    fi
done
if [ -n "$missing" ]; then
    echo "error: generation incomplete. Missing output PROM VHDL:" >&2
    for f in $missing; do echo "  $f" >&2; done
    exit 1
fi

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd