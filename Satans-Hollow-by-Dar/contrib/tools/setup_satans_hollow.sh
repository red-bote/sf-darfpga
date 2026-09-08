#!/bin/bash
# Download, extract, and patch the Satan's Hollow Dar source archive, then
# chain into the rom-prep script.
#
# 1. Fetch vhdl_satans_hollow_rev_0_2_2019_11_22.zip from SourceForge into the
#    cache dloads/ dir (gitignored). Reuses the cached copy if its SHA-256
#    matches the embedded hash; re-downloads if missing, tampered, or
#    compromised.
# 2. Extract it into the repo root as vhdl_satans_hollow_rev_0_2_2019_11_22/.
# 3. Apply any fix patches idempotently. Glob covers both
#    contrib/<dir>/code/*.patch and contrib/code/*.patch.
#    Excludes *_de10_lite_to_basys3.patch: that file is a record of the
#    top-level rewrite (authored by make_de10_lite_to_basys3_patch.sh, applied
#    to a different target file), not a fix to apply to the pristine tree.
#    Each patch is guarded by a reverse dry-run so an already-applied patch is
#    skipped instead of aborting the script (patch -p1 --forward is NOT
#    idempotent).
# 4. Run contrib/tools/prep_roms.sh (compile make_vhdl_prom, convert .bat,
#    unzip romset, rename the midssio PROM, generate PROM VHDL).
#
# No synthesis-fix patch is needed for Satan's Hollow (so far): the core is
# native progressive 31 kHz (tv15Khz_mode='0' drives pixels on the core's own
# video_hs/video_vs at 20 MHz effective; '1' selects 15 kHz interlaced), so no
# line_doubler and no external scandoubler are involved. The keyboard runs on
# the onboard USB-HID connector (C17/B17) clocked directly on clock_40
#    (>= 6 MHz host requirement), the standard convention - not Dar's 2 MHz
#    clock_kbd divider, which is kept only to gate the PWM audio accumulators.
#
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_satans_hollow_rev_0_2_2019_11_22"

URL="https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Satans_hollow/vhdl_satans_hollow_rev_0_2_2019_11_22.zip/download"
EXPECTED_SHA256="5d7ccb0b1e54a76a36ac922e702bb6730ef8558db55c1b7c670aae296b7cd4f3"

DLOAD_DIR="$ROOT/dloads"
ZIP="$DLOAD_DIR/vhdl_satans_hollow_rev_0_2_2019_11_22.zip"

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

step "2/4 Extracting vhdl_satans_hollow_rev_0_2_2019_11_22/ into repo root"
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