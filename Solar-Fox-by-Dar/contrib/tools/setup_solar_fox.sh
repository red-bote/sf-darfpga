#!/bin/bash
# Setup wrapper for the Solar Fox Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_solar_fox_rev_0_1_2019_11_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Solarfox/vhdl_solar_fox_rev_0_1_2019_11_22.zip/download" \
  --sha256  2c78e449c8906f08131f8a48e2f495373fd7855934ebae39d9ba8782b6c21d31
