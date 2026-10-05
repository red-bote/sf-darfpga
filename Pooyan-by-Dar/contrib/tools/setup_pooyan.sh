#!/bin/bash
# Setup wrapper for the Pooyan Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

# --binary: rtl_dar is CRLF; pooyan_single_domain.patch must keep its CR bytes
# (the LF pooyan_t80_xor_width.patch applies unchanged under --binary).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_pooyan_rev_0_2_2020_04_26 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/vhdl_pooyan_rev_0_2_2020_04_26.zip/download" \
  --sha256  cfa8408a878589f080ff3cd75b53d8e5271896d368cdc3ace1cbfb621f2f3169 \
  --binary
