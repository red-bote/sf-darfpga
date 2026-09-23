#!/bin/bash
# Patch wrapper for the Satan's Hollow Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at
# contrib/basys3/code/satans_hollow_basys3.vhd (a real, tracked file -- edit
# it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_satans_hollow_rev_0_2_2019_11_22 \
  --de10-top   satans_hollow_de10_lite.vhd \
  --top-entity satans_hollow_basys3
