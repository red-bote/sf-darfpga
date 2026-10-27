#!/bin/bash
# Linux rom-prep for the Popeye Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_popeye_proms.bat -> make_popeye_proms.sh.
# 3. Unzip the romsets (~/roms/popeye.zip + ~/roms/popeyeu.zip) into
#    tools/popeye_unzip/. popeyeu.zip provides the unprotected 7a/7b/7c/7e
#    speech ROMs (the US popeye.zip only carries the tpp2-* protected set).
# 4. Run make_popeye_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_popeye_rev_0_3_2020_01_27/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_popeye_rev_0_3_2020_01_27"
PROM_DIR="$SRC_DIR/tools/popeye_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP1="${ROMZIP1:-$HOME/roms/popeye.zip}"
ROMZIP2="${ROMZIP2:-$HOME/roms/popeyeu.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_popeye.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_popeye_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_popeye_proms.bat" ]; then
    echo "error: $PROM_DIR/make_popeye_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_popeye_proms.bat" > "$PROM_DIR/make_popeye_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_popeye_proms.sh"
chmod +x "$PROM_DIR/make_popeye_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romsets"
unzip -o "$ROMZIP1" -d "$PROM_DIR"
unzip -o "$ROMZIP2" -d "$PROM_DIR"

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_popeye_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
