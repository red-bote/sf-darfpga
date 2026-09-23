#!/bin/bash
# Setup wrapper for the Burnin' Rubber Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_burnin_rubber_rev_0_0_2017_12_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/burnin_rubber/vhdl_burnin_rubber_rev_0_0_2017_12_22.zip/download" \
  --sha256  fed43686919a56ae1b8b595af174d9dc4cd3807aa5d8c7698a62d54b151727dc
