#!/bin/bash
# Patch wrapper for the Computer Space Basys3 port. Delegates to the shared
# darfpga_place_top_level() in sf-darfpga/tools/lib/darfpga-patch.sh.
#
# The top-level VHDL itself lives at
# contrib/basys3/code/computer_space_basys3.vhd (a real, tracked file --
# edit it directly). Computer Space's pristine upstream top level lives in
# rtl/ (not rtl_dar/ like every other machine) -- hence --de10-dir.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-patch.sh"

darfpga_place_top_level \
  --root       "$ROOT" \
  --src-dir    vhdl_computer_space_rev_1_1_2017_11_22 \
  --de10-dir   rtl \
  --de10-top   computer_space_de10_lite.vhd \
  --top-entity computer_space_basys3
