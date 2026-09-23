#!/bin/bash
# Bitstream wrapper for the Tron Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_tron_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_tron_rev_0_3_2019_11_22 \
  --top-entity tron_basys3 \
  -- "${1:-}"
