#!/bin/bash
# Setup wrapper for the Tron Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_tron_rev_0_3_2019_11_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/tron/vhdl_tron_rev_0_3_2019_11_22.zip/download" \
  --sha256  62360d4423b8b43578e9b984da2319f21c9aa52edc5a59b7fb2b356314b49ba8
