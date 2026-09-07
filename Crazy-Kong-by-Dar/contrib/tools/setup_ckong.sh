#!/bin/bash
# Download, extract, and patch the Crazy Kong Dar source archive, then chain
# into the rom-prep script.
#
# 1. Fetch vhdl_ckong_rev_0_1_2018_06_06.zip from SourceForge into the
#    cache dloads/ dir (gitignored). Reuses the cached copy if its SHA-256
#    matches the embedded hash; re-downloads if missing, tampered, or
#    compromised.
# 2. Extract it into the repo root as vhdl_ckong_rev_0_1_2018_06_06/.
# 3. Apply any fix patches idempotently. Glob covers both
#    contrib/<dir>/code/*.patch and contrib/code/*.patch.
#    Excludes *_de10_lite_to_basys3.patch: that file is a record of the
#    top-level rewrite (authored by make_de10_lite_to_basys3_patch.sh, applied
#    to a different target file), not a fix to apply to the pristine tree.
#    Each patch is guarded by a reverse dry-run so an already-applied patch is
#    skipped instead of aborting the script (patch -p1 --forward is NOT
#    idempotent).
# 4. Run contrib/tools/prep_roms.sh (compile make_vhdl_prom, convert .bat,
#    unzip romset, generate PROM VHDL).
#
# The synthesis-time fix to pristine sources is contrib/code/ckong_xor_width.patch:
# ckong.vhd:405-408 XORs the 13-bit tile_graph_rom_addr expression with a 5-bit
# constant; `&` precedence binds the whole 13-bit vector, and Vivado rejects
# the length mismatch (bagman_xor_width.patch is the same pattern). The fix
# zero-pads each constant to 13 bits, preserving the exact parsed semantics.
#
# No video-path fix is needed: the core is native progressive 31 kHz (internal
# line_doubler, real video_hs/video_vs) and already clocks io_ps2_keyboard at
# 12 MHz -- both >= 6 MHz for the Basys3 onboard USB-HID host and without an
# external scandoubler (see ckong_basys3.vhd / PORTING_SPEC).
#
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_ckong_rev_0_1_2018_06_06"

URL="https://sourceforge.net/projects/darfpga/files/Software%20VHDL/crazy_kong/vhdl_ckong_rev_0_1_2018_06_06.zip/download"
EXPECTED_SHA256="953bd4fdfaaad1cfcb1b9c5adee41636056b2353910664321e7422ae515a0700"

DLOAD_DIR="$ROOT/dloads"
ZIP="$DLOAD_DIR/vhdl_ckong_rev_0_1_2018_06_06.zip"

step() { printf '\n==> %s\n' "$1"; }

fetch_zip() {
    mkdir -p "$DLOAD_DIR"
    if [ -f "$ZIP" ]; then
        actual=$(sha256sum "$ZIP" | cut -d' ' -f1)
        if [ "$actual" = "$EXPECTED_SHA256" ]; then
            step "Using cached source archive (SHA-256 verified)"
            return
        fi
        echo "WARNING: cached archive hash mismatch; re-downloading" >&2
        rm -f "$ZIP"
    fi
    wget -O "$ZIP" "$URL"
    actual=$(sha256sum "$ZIP" | cut -d' ' -f1)
    if [ "$actual" != "$EXPECTED_SHA256" ]; then
        echo "ERROR: downloaded archive failed SHA-256 integrity check" >&2
        rm -f "$ZIP"
        exit 1
    fi
}

step "1/4 Fetching source archive (cached or verified)"
fetch_zip

step "2/4 Extracting vhdl_ckong_rev_0_1_2018_06_06/ into repo root"
mkdir -p "$SRC_DIR"
unzip -o "$ZIP" -d "$ROOT"

step "3/4 Applying fix patches (contrib/*/code/*.patch and contrib/code/*.patch)"
for p in "$ROOT"/contrib/*/code/*.patch "$ROOT"/contrib/code/*.patch; do
    [ -e "$p" ] || continue
    case "$p" in
        *_de10_lite_to_basys3.patch) continue ;;
        *scandoubler_fix.patch) continue ;;
    esac
    if (cd "$ROOT" && patch -p1 -R --dry-run --forward < "$p" > /dev/null 2>&1); then
        echo "==> already applied, skipping $p"
    else
        echo "==> applying $p"
        (cd "$ROOT" && patch -p1 --forward < "$p")
    fi
done

step "4/4 Running rom-prep"
"$ROOT/contrib/tools/prep_roms.sh"

echo
echo "Setup complete. Source tree in:"
echo "  $SRC_DIR"