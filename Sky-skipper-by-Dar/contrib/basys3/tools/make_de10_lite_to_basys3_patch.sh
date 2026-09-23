#!/bin/bash
# Patch wrapper for the Sky Skipper Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at
# contrib/basys3/code/sky_skipper_basys3.vhd (a real, tracked file -- edit
# it directly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_sky_skipper_rev_01_2020_01_28 \
  --de10-top   sky_skipper_de10_lite.vhd \
  --top-entity sky_skipper_basys3
