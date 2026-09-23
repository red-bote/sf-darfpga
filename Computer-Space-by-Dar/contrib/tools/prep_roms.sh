#!/bin/bash
# Rom-prep for the Computer Space Basys3 port.
#
# Computer Space is fundamentally different from other Dar ports: it has no
# ROMs, no tools/ directory, no make_vhdl_prom, and no .bat files. The sound
# waveform data is stored in .hex files already present in the rtl/ directory.
# The original Altera altsyncram blocks initialized from these Intel-HEX files.
# Rather than reading them with textio at synthesis time (which fails: the
# paths are CWD-relative and the .hex are Intel-HEX records, not plain bytes),
# the generator parses the .hex and emits regular VHDL with inline ROM content,
# so synthesis infers BRAM without touching any .hex file.
#
# Requires the pristine Dar source tree (vhdl_computer_space_rev_1_1_2017_11_22/)
# to be already extracted; this script does not download or extract it.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_computer_space_rev_1_1_2017_11_22"

step() { printf '\n==> %s\n' "$1"; }

step "Verifying hex files in rtl/"
HEX_FILES="bakamb_8_11.hex explosion_8_11.hex rotate_8_11.hex rocket_shooting_8_11.hex thrust_8_11.hex saucer_shooting_8_11.hex"
missing=0
for h in $HEX_FILES; do
    if [ ! -f "$SRC_DIR/rtl/$h" ]; then
        echo "ERROR: missing hex file: $SRC_DIR/rtl/$h" >&2
        missing=$((missing + 1))
    fi
done
if [ "$missing" -gt 0 ]; then
    echo "ERROR: $missing hex file(s) missing" >&2
    exit 1
fi

step "Generating rom_*.vhd sound ROMs from the .hex files"
GEN_DIR="$SRC_DIR/basys3/generated_sound_roms"
python3 "$ROOT/contrib/tools/gen_sound_roms.py" "$SRC_DIR/rtl" "$GEN_DIR"

echo
echo "Rom-prep complete. Sound ROM replacements in (gitignored):"
echo "  $GEN_DIR"
