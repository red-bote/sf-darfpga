#!/bin/bash
# Setup wrapper for the Phoenix Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.
#
# --flat-archive: unlike every other Dar archive, this zip has no internal
# top-level folder -- its members (rtl_dar/, rtl_T80/, de10_lite/, README.txt)
# sit at the zip root, so it must be extracted directly into
# vhdl_phoenix_DE10_lite/, not into the repo root.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_phoenix_DE10_lite \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/phoenix/vhdl_phoenix_DE10_lite.zip/download" \
  --sha256  74da205e98a79bfd3e50bb09d204684ee31511d23b55b195061a9c1af9901b46 \
  --flat-archive
