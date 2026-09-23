#!/bin/bash
# Bitstream wrapper for the Computer Space Basys3 port. Delegates to the
# shared darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_computer_space_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_computer_space_rev_1_1_2017_11_22 \
  --top-entity computer_space_basys3 \
  -- "${1:-}"
