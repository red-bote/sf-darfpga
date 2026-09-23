#!/bin/bash
# Setup wrapper for the Galaga Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_galaga_rev_0_3_2018_05_06 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/galaga/vhdl_galaga_rev_0_3_2018_05_06.zip/download" \
  --sha256  4d51c8ca31a7ee9ea9f475b818bef625e739f9faa07f66ed54888d05d25d611e
