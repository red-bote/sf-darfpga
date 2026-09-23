#!/bin/bash
# Patch wrapper for the Xevious Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/xevious_basys3.vhd
# (a real, tracked file -- edit it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_xevious_de2_de10_lite_2017_05_01 \
  --de10-top   xevious_de10_lite.vhd \
  --top-entity xevious_basys3
