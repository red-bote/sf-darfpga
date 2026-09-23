#!/bin/bash
# Patch wrapper for the Traverse USA Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at
# contrib/basys3/code/traverse_usa_basys3.vhd (a real, tracked file -- edit
# it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_traverse_usa_rev_0_0_2019_03_16 \
  --de10-top   traverse_usa_de10_lite.vhd \
  --top-entity traverse_usa_basys3
