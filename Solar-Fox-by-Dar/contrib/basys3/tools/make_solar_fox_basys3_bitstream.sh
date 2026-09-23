#!/bin/bash
# Bitstream wrapper for the Solar Fox Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_solar_fox_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_solar_fox_rev_0_1_2019_11_22 \
  --top-entity solar_fox_basys3 \
  -- "${1:-}"
