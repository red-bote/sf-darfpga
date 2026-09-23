#!/bin/bash
# Setup wrapper for the Traverse USA Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_traverse_usa_rev_0_0_2019_03_16 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/traverse_usa/vhdl_traverse_usa_rev_0_0_2019_03_16.zip/download" \
  --sha256  770a7dcf2de70f4b2bcb5a2fc66ec727dbfd102b3367c905ce2d61b7c827100c
