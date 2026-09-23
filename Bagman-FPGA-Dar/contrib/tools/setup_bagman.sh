#!/bin/bash
# Setup wrapper for the Bagman Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_bagman_rev_0_1_2018_06_05 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/bagman/vhdl_bagman_rev_0_1_2018_06_05.zip/download" \
  --sha256  d44bff75dbbca44b1309dc40c1dd61e8150291036a43a2f43694bc7e2621f6cf
