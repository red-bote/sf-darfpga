#!/bin/bash
# Patch wrapper for the Berzerk Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/berzerk_basys3.vhd
# (a real, tracked file -- edit it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_berzerk_rev_0_1_2018_08_08 \
  --de10-top   berzerk_de10_lite.vhd \
  --top-entity berzerk_basys3
