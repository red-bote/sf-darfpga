#!/bin/bash
# Linux rom-prep for the Berzerk Basys3 port.
#
# 1. Compile make_vhdl_prom from the extracted Dar source tree on the host (gcc).
# 2. Convert make_berzerk_proms.bat -> make_berzerk_proms.sh.
# 3. Unzip the romset (~/roms/berzerk.zip) into tools/berzerk_unzip/ and rename
#    its files to the names make_berzerk_proms.bat expects. Dar's bat uses
#    descriptive names (berzerk_rc31_1c.rom0.1c, ...) while the MAME berzerk.zip
#    dump uses position names (1c-0, 1d-1, ...). The MAME program ROMs carry the
#    -0..-5 suffix in order; the two speech ROMs are named 1c and 2c.
# 4. Run make_berzerk_proms.sh to generate the PROM VHDL.
#
# Requires the pristine Dar source tree (vhdl_berzerk_rev_0_1_2018_08_08/)
# to be already extracted; this script does not download or extract it.
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_berzerk_rev_0_1_2018_08_08"
PROM_DIR="$SRC_DIR/tools/berzerk_unzip"
TOOLS_SRC="$SRC_DIR/tools/tools_prom_src/src"

ROMZIP="${ROMZIP:-$HOME/roms/berzerk.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: source tree not found: $SRC_DIR" >&2
    echo "Run setup_berzerk.sh first." >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_berzerk_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_berzerk_proms.bat" ]; then
    echo "error: $PROM_DIR/make_berzerk_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e '/^rem/d' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_berzerk_proms.bat" > "$PROM_DIR/make_berzerk_proms.sh"
sed -i '1i #!/bin/bash' "$PROM_DIR/make_berzerk_proms.sh"
chmod +x "$PROM_DIR/make_berzerk_proms.sh" "$PROM_DIR/make_vhdl_prom"

step "3/4 Unzipping romset and renaming to Dar's expected names"
unzip -o "$ROMZIP" -d "$PROM_DIR"
rename_rom() {
    local src="$1" dst="$2"
    if [ -e "$PROM_DIR/$src" ] && [ ! -e "$PROM_DIR/$dst" ]; then
        mv "$PROM_DIR/$src" "$PROM_DIR/$dst"
    fi
}
rename_rom 1c-0 berzerk_rc31_1c.rom0.1c
rename_rom 1d-1 berzerk_rc31_1d.rom1.1d
rename_rom 3d-2 berzerk_rc31_3d.rom2.3d
rename_rom 5d-3 berzerk_rc31_5d.rom3.5d
rename_rom 6d-4 berzerk_rc31_6d.rom4.6d
rename_rom 5c-5 berzerk_rc31_5c.rom5.5c
rename_rom 1c berzerk_r_vo_1c.1c
rename_rom 2c berzerk_r_vo_2c.2c

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_berzerk_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
