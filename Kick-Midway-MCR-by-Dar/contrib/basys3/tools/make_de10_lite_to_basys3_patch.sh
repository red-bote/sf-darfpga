#!/bin/bash
# Patch wrapper for the Kick Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/kick_basys3.vhd
# (a real, tracked file -- edit it directly).
#
# The core (rtl_dar/kick.vhd) generates its own progressive 31 kHz timing
# natively -- no external scandoubler is imported, mirroring the sibling
# Tron-by-Dar port (same Midway MCR SSIO hardware).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_kick_rev_0_2_2019_11_22 \
  --de10-top   kick_de10_lite.vhd \
  --top-entity kick_basys3
