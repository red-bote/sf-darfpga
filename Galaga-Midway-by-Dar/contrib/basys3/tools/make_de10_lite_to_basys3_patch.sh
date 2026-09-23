#!/bin/bash
# Patch wrapper for the Galaga Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/galaga_basys3.vhd
# (a real, tracked file -- edit it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_galaga_rev_0_3_2018_05_06 \
  --de10-top   galaga_de10_lite.vhd \
  --top-entity galaga_basys3
