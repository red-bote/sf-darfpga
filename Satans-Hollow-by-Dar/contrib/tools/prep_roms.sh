#!/bin/bash
# Linux rom-prep for the Satan's Hollow Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_satans_hollow_proms.bat -> make_satans_hollow_proms.sh.
# 3. Unzip the romset ($ROMZIP, default ~/roms/shollow.zip) into
#    tools/satan_hollow_unzip/ (note: the dir is lowercase 'satan_hollow', the
#    unzip scratch bequeathed by Dar's own "satan_hollow_unzip" step - the
#    .bat is make_satans_hollow_proms.bat but the zip target dir is
#    satan_hollow_unzip, matching how make_satans_hollow_proms.bat is
#    referenced from the tree's de10_lite build).
# 4. Rename 82s123.12d -> midssio_82s123.12d (the .bat names the midssio
#    sound-board PROM absolute to that filename; MAME's shollow.zip ships it
#    as 82s123.12d, same as the Tron port's kick set).
# 5. Run make_satans_hollow_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_satans_hollow_rev_0_2_2019_11_22/)
# to be already extracted; this script does not download or extract it.
#
# Romset: a single set, MAME shollow.zip. All 15 of its ROM files
# (sh-pro.00..05, sh-snd.01..03, sh-bg.00..01, sh-fg.00..03) are referenced by
# exact canonical name in the .bat, plus midssio_82s123.12d (= 82s123.12d
# inside the zip). The pre/post-flight checks below catch a wrong/incomplete
# romset loudly instead of silently producing empty or missing PROMs.
#
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_satans_hollow_rev_0_2_2019_11_22"
PROM_DIR="$SRC_DIR/tools/satan_hollow_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/shollow.zip}"

INPUT_ROMS=(
    sh-pro.00 sh-pro.01 sh-pro.02 sh-pro.03 sh-pro.04 sh-pro.05
    sh-snd.01 sh-snd.02 sh-snd.03
    sh-bg.00 sh-bg.01
    sh-fg.00 sh-fg.01 sh-fg.02 sh-fg.03
    82s123.12d
)

OUTPUT_PROMS=(
    satans_hollow_cpu.vhd
    satans_hollow_sound_cpu.vhd
    satans_hollow_bg_bits_1.vhd
    satans_hollow_bg_bits_2.vhd
    satans_hollow_sp_bits.vhd
    midssio_82s123.vhd
)

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_satans_hollow.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/5 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/5 Converting make_satans_hollow_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_satans_hollow_proms.bat" ]; then
    echo "error: $PROM_DIR/make_satans_hollow_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/[[:space:]]+/ /g' \
    -e 's/ *\+ */ /g' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_satans_hollow_proms.bat" > "$PROM_DIR/make_satans_hollow_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_satans_hollow_proms.sh"
chmod +x "$PROM_DIR/make_satans_hollow_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/5 Unzipping romset"
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
    echo "Satan's Hollow needs the shollow.zip (Bally Midway MCR) set:" >&2
    echo "  sh-pro.00..05, sh-snd.01..03, sh-bg.00..01, sh-fg.00..03, 82s123.12d." >&2
    exit 1
fi

step "4/5 Renaming midssio PROM (82s123.12d -> midssio_82s123.12d)"
mv -f "$PROM_DIR/82s123.12d" "$PROM_DIR/midssio_82s123.12d"

step "5/5 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_satans_hollow_proms.sh )

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