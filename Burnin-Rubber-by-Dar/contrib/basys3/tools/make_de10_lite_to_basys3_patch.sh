#!/bin/bash
# Patch wrapper for the Burnin' Rubber Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at
# contrib/basys3/code/burnin_rubber_basys3.vhd (a real, tracked file -- edit
# it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_burnin_rubber_rev_0_0_2017_12_22 \
  --de10-top   burnin_rubber_de10_lite.vhd \
  --top-entity burnin_rubber_basys3
