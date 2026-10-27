#!/bin/bash
# Linux rom-prep for the Bagman Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_bagman_proms.bat -> make_bagman_proms.sh.
# 3. Unzip the romset (~/roms/bagman.zip) into tools/bagman_unzip/.
# 4. Run make_bagman_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_bagman_rev_0_1_2018_06_05/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_bagman_rev_0_1_2018_06_05"
PROM_DIR="$SRC_DIR/tools/bagman_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/bagman.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_bagman.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_bagman_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_bagman_proms.bat" ]; then
    echo "error: $PROM_DIR/make_bagman_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_bagman_proms.bat" > "$PROM_DIR/make_bagman_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_bagman_proms.sh"
chmod +x "$PROM_DIR/make_bagman_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romset"
unzip -o "$ROMZIP" -d "$PROM_DIR"

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_bagman_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
