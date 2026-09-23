#!/bin/bash
# Linux rom-prep for the Tron Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_tron_proms.bat -> make_tron_proms.sh.
# 3. Unzip the romset (~/roms/tron.zip) into tools/tron_unzip/. tron.zip does
#    not carry the shared Midway color PROM 82s123.12d, so it is pulled from
#    $ROMZIP2 (default ~/roms/midssio.zip -- the dedicated Midway SSIO board
#    romset, confirmed to contain exactly this file) and renamed to
#    midssio_82s123.12d (the name make_tron_proms.bat expects).
# 4. Run make_tron_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_tron_rev_0_3_2019_11_22/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_tron_rev_0_3_2019_11_22"
PROM_DIR="$SRC_DIR/tools/tron_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/tron.zip}"
ROMZIP2="${ROMZIP2:-$HOME/roms/midssio.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_tron.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_tron_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_tron_proms.bat" ]; then
    echo "error: $PROM_DIR/make_tron_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_tron_proms.bat" > "$PROM_DIR/make_tron_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_tron_proms.sh"
chmod +x "$PROM_DIR/make_tron_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romset and resolving the color PROM"
unzip -o "$ROMZIP" -d "$PROM_DIR"
if [ ! -e "$PROM_DIR/midssio_82s123.12d" ]; then
    if [ -e "$PROM_DIR/82s123.12d" ]; then
        # present in tron.zip itself (not expected, but harmless to check)
        mv "$PROM_DIR/82s123.12d" "$PROM_DIR/midssio_82s123.12d"
    elif [ -f "$ROMZIP2" ]; then
        # tron.zip does not carry the shared Midway color PROM; pull it from
        # the dedicated Midway SSIO board romset instead.
        unzip -o "$ROMZIP2" 82s123.12d -d "$PROM_DIR"
        mv "$PROM_DIR/82s123.12d" "$PROM_DIR/midssio_82s123.12d"
    fi
fi
if [ ! -e "$PROM_DIR/midssio_82s123.12d" ]; then
    echo "error: midssio_82s123.12d not found in \$ROMZIP ($ROMZIP) or \$ROMZIP2 ($ROMZIP2)" >&2
    exit 1
fi

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_tron_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
