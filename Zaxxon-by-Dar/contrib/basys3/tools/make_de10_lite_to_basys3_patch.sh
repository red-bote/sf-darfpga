#!/bin/bash
# Patch wrapper for the Zaxxon Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at contrib/basys3/code/zaxxon_basys3.vhd
# (a real, tracked file -- edit it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_zaxxon_rev_0_0_2019_11_29 \
  --de10-top   zaxxon_de10_lite.vhd \
  --top-entity zaxxon_basys3
