#!/bin/bash
# Download, extract, and patch the Pooyan Dar source archive, then chain
# into the rom-prep script.
#
# 1. Fetch vhdl_pooyan_rev_0_2_2020_04_26.zip from SourceForge into the cache
#    dloads/ dir (gitignored). Reuses the cached copy if its SHA-256 matches the
#    embedded hash; re-downloads if missing, tampered, or compromised.
# 2. Extract it into the repo root as vhdl_pooyan_rev_0_2_2020_04_26/.
# 3. Apply any fix patches idempotently (patch -p1 --forward).
#    Glob covers both contrib/<dir>/code/*.patch and contrib/code/*.patch.
#    Excludes *_de10_lite_to_basys3.patch: that file is a record of the
#    top-level rewrite (authored by make_de10_lite_to_basys3_patch.sh), not a
#    fix to apply to the pristine tree.
# 4. Run contrib/tools/prep_roms.sh (compile make_vhdl_prom, convert .bat,
#    unzip romset, generate PROM VHDL).
#
# create_prj (copy ported assets), clk_wiz_0 IP generation, and the
# pooyan_basys3.vhd top level are separate steps. Roms and the generated PROM
# VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="$ROOT/vhdl_pooyan_rev_0_2_2020_04_26"

URL="https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/vhdl_pooyan_rev_0_2_2020_04_26.zip/download"
EXPECTED_SHA256="cfa8408a878589f080ff3cd75b53d8e5271896d368cdc3ace1cbfb621f2f3169"

DLOAD_DIR="$ROOT/dloads"
ZIP="$DLOAD_DIR/vhdl_pooyan_rev_0_2_2020_04_26.zip"

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

step "2/4 Extracting vhdl_pooyan_rev_0_2_2020_04_26/ into repo root"
mkdir -p "$SRC_DIR"
unzip -o "$ZIP" -d "$ROOT"

step "3/4 Applying fix patches (contrib/*/code/*.patch and contrib/code/*.patch)"
for p in "$ROOT"/contrib/*/code/*.patch "$ROOT"/contrib/code/*.patch; do
    [ -e "$p" ] || continue
    case "$p" in
        *_de10_lite_to_basys3.patch) continue ;;
    esac
    echo "==> applying $p"
    patch -p1 --forward < "$p"
done

step "4/4 Running rom-prep"
"$ROOT/contrib/tools/prep_roms.sh"

echo
echo "Setup complete. Sources and romsets staged."
echo
echo "Remaining steps (separate): make create_prj, make clk_wiz, and make patch (pooyan_basys3.vhd top level)."