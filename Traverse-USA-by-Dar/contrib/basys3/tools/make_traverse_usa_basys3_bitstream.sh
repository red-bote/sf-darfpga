#!/bin/bash
# Bitstream wrapper for the Traverse USA Basys3 port. Delegates to the
# shared darfpga_build_bitstream() in
# sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_traverse_usa_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_traverse_usa_rev_0_0_2019_03_16 \
  --top-entity traverse_usa_basys3 \
  -- "${1:-}"
