#!/bin/bash
# Setup wrapper for the Berzerk Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_berzerk_rev_0_1_2018_08_08 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/berzerk/vhdl_berzerk_rev_0_1_2018_08_08.zip/download" \
  --sha256  61952430231ebe2824f8e8bc5b5d3812cdc4e6e58ba3a5a3c1141d53afb3bf3e
