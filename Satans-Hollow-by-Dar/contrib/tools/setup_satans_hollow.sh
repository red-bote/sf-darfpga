#!/bin/bash
# Setup wrapper for the Satan's Hollow Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_satans_hollow_rev_0_2_2019_11_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Satans_hollow/vhdl_satans_hollow_rev_0_2_2019_11_22.zip/download" \
  --sha256  5d7ccb0b1e54a76a36ac922e702bb6730ef8558db55c1b7c670aae296b7cd4f3
