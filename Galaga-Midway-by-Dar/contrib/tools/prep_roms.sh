#!/bin/bash
# Linux rom-prep for the Galaga Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_galaga_proms.bat -> make_galaga_proms.sh.
# 3. Unzip the two romsets (~/roms/galaga.zip + ~/roms/galagamw.zip) into
#    tools/galaga_unzip/.
# 4. Run make_galaga_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_galaga_rev_0_3_2018_05_06/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_galaga_rev_0_3_2018_05_06"
PROM_DIR="$SRC_DIR/tools/galaga_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP1="${ROMZIP1:-$HOME/roms/galaga.zip}"
ROMZIP2="${ROMZIP2:-$HOME/roms/galagamw.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Extract vhdl_galaga_rev_0_3_2018_05_06/ first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_galaga_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_galaga_proms.bat" ]; then
    echo "error: $PROM_DIR/make_galaga_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_galaga_proms.bat" > "$PROM_DIR/make_galaga_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_galaga_proms.sh"
chmod +x "$PROM_DIR/make_galaga_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romsets"
unzip -o "$ROMZIP1" -d "$PROM_DIR"
unzip -o "$ROMZIP2" -d "$PROM_DIR"

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_galaga_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
