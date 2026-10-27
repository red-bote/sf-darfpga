#!/bin/bash
# Setup wrapper for the Pooyan Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_pooyan_rev_0_2_2020_04_26 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/vhdl_pooyan_rev_0_2_2020_04_26.zip/download" \
  --sha256  cfa8408a878589f080ff3cd75b53d8e5271896d368cdc3ace1cbfb621f2f3169
