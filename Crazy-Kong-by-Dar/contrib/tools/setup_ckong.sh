#!/bin/bash
# Setup wrapper for the Crazy Kong Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_ckong_rev_0_1_2018_06_06 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/crazy_kong/vhdl_ckong_rev_0_1_2018_06_06.zip/download" \
  --sha256  953bd4fdfaaad1cfcb1b9c5adee41636056b2353910664321e7422ae515a0700
