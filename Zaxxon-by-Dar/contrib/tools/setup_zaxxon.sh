#!/bin/bash
# Setup wrapper for the Zaxxon Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_zaxxon_rev_0_0_2019_11_29 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/zaxxon/vhdl_zaxxon_rev_0_0_2019_11_29.zip/download" \
  --sha256  cae40f154bc1fb6cf58cf8b804c495bb89bd5914583bd1bdf426fa8c52f5a4cf
