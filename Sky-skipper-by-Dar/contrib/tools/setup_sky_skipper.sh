#!/bin/bash
# Setup wrapper for the Sky Skipper Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_sky_skipper_rev_01_2020_01_28 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/sky_skipper/vhdl_sky_skipper_rev_01_2020_01_28.zip/download" \
  --sha256  77643a33ff81d7c8ceefda6f0d1512017945dfc257074bfd2be04ee137701c58
