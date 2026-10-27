#!/bin/bash
# Setup wrapper for the Defender Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_defender_rev_0_0_2017_10_15 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/defender/vhdl_defender_rev_0_0_2017_10_15.zip/download" \
  --sha256  1d7a376e719ba6653250bd855dcd6c767a5f5e0cd4f6cbe14feedc56871657fa
