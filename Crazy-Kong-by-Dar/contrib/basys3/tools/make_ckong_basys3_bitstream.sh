#!/bin/bash
# Bitstream wrapper for the Crazy Kong Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_ckong_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_ckong_rev_0_1_2018_06_06 \
  --top-entity ckong_basys3 \
  -- "${1:-}"
