#!/bin/bash
# Setup wrapper for the Time Pilot Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_time_pilot_rev_0_0_2017_11_05 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/time_pilot/vhdl_time_pilot_rev_0_0_2017_11_05.zip/download" \
  --sha256  c396a477cd7ca600c546785a0f792f8c04cd816a37386ba0587e0d8459c985d7
