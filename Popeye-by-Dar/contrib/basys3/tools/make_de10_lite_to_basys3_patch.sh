#!/bin/bash
# Patch wrapper for the Popeye Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/popeye_basys3.vhd
# (a real, tracked file -- edit it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_popeye_rev_0_3_2020_01_27 \
  --de10-top   popeye_de10_lite.vhd \
  --top-entity popeye_basys3
