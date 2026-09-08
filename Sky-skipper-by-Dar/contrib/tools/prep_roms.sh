#!/bin/bash
# Linux rom-prep for the Sky Skipper Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_sky_skipper_proms.bat -> make_sky_skipper_proms.sh.
# 3. Unzip the romset ($ROMZIP, default ~/roms/skyskipr.zip) into
#    tools/sky_skipper_unzip/.
# 4. Run make_sky_skipper_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_sky_skipper_rev_01_2020_01_28/)
# to be already extracted; this script does not download or extract it.
#
# Romset: Dar's README says to use skyskipr.zip, and the .bat references all
# 15 of its files by their exact canonical names (tnx1-c.2a..2g, tnx1-t.*,
# tnx1-v.3h), so no relabeling is needed -- the unzipped rom directory is
# used as-is. tnx1-t.3j is only mentioned in a .bat comment ("n.u.", not
# used) but is still expected to be present in the set. The pre/post-flight
# checks below catch a wrong/incomplete romset loudly instead of silently
# producing empty or missing PROMs.
#
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_sky_skipper_rev_01_2020_01_28"
PROM_DIR="$SRC_DIR/tools/sky_skipper_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/skyskipr.zip}"

INPUT_ROMS=(
    tnx1-c.2a tnx1-c.2b tnx1-c.2c tnx1-c.2d tnx1-c.2e tnx1-c.2f tnx1-c.2g
    tnx1-t.1a tnx1-t.1e tnx1-t.2a tnx1-t.2e tnx1-t.3a tnx1-t.3e tnx1-t.3j tnx1-t.4a tnx1-t.5e
    tnx1-v.3h
)

OUTPUT_PROMS=(
    sky_skipper_cpu.vhd
    sky_skipper_ch_bits.vhd
    sky_skipper_ch_palette_rgb.vhd
    sky_skipper_bg_palette_rgb.vhd
    sky_skipper_sp_bits_1.vhd
    sky_skipper_sp_bits_2.vhd
    sky_skipper_sp_bits_3.vhd
    sky_skipper_sp_bits_4.vhd
    sky_skipper_sp_palette_rg.vhd
    sky_skipper_sp_palette_gb.vhd
)

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_sky_skipper.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_sky_skipper_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_sky_skipper_proms.bat" ]; then
    echo "error: $PROM_DIR/make_sky_skipper_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_sky_skipper_proms.bat" > "$PROM_DIR/make_sky_skipper_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_sky_skipper_proms.sh"
chmod +x "$PROM_DIR/make_sky_skipper_proms.sh" "$PROM_DIR/make_vhdl_prom"

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
    echo "Sky Skipper needs the skyskipr.zip (Sky Skipper / Namco) set:" >&2
    echo "  the .bat references tnx1-c.2a..2g, tnx1-t.* and tnx1-v.3h." >&2
    exit 1
fi

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_sky_skipper_proms.sh )

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