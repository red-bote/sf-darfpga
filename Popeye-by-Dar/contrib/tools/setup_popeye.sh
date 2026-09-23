#!/bin/bash
# Setup wrapper for the Popeye Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_popeye_rev_0_3_2020_01_27 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/popeye/vhdl_popeye_rev_0_3_2020_01_27.zip/download" \
  --sha256  da1b20025dd535caa9040c936e7c01a1fd74b03125eb67a91643a45cd005c837
