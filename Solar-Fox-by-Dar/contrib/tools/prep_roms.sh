#!/bin/bash
# Linux rom-prep for the Solar Fox Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_solar_fox_proms.bat -> make_solar_fox_proms.sh.
# 3. Unzip the romset (~/roms/solarfox.zip) into tools/solar_fox_unzip/ and
#    rename the shared Midway color PROM 82s123.12d -> midssio_82s123.12d (the
#    name make_solar_fox_proms.bat expects). The color PROM ships inside
#    solarfox.zip; no separate midssio.zip is needed.
# 4. Run make_solar_fox_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_solar_fox_rev_0_1_2019_11_22/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_solar_fox_rev_0_1_2019_11_22"
PROM_DIR="$SRC_DIR/tools/solar_fox_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/solarfox.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_solar_fox.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_solar_fox_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_solar_fox_proms.bat" ]; then
    echo "error: $PROM_DIR/make_solar_fox_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_solar_fox_proms.bat" > "$PROM_DIR/make_solar_fox_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_solar_fox_proms.sh"
chmod +x "$PROM_DIR/make_solar_fox_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romset and renaming the color PROM"
unzip -o "$ROMZIP" -d "$PROM_DIR"
[ -e "$PROM_DIR/82s123.12d" ] && [ ! -e "$PROM_DIR/midssio_82s123.12d" ] \
    && mv "$PROM_DIR/82s123.12d" "$PROM_DIR/midssio_82s123.12d"

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_solar_fox_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
