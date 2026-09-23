#!/bin/bash
# Setup wrapper for the Kick Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_kick_rev_0_2_2019_11_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Kick_kickman/vhdl_kick_rev_0_2_2019_11_22.zip/download" \
  --sha256  a4b62007e76b9198f3c794c18f8aea58b33accaa09906c14a60fededb30f6961
