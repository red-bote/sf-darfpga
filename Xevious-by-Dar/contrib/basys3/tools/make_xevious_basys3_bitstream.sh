#!/bin/bash
# Bitstream wrapper for the Xevious Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_xevious_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_xevious_de2_de10_lite_2017_05_01 \
  --top-entity xevious_basys3 \
  -- "${1:-}"
