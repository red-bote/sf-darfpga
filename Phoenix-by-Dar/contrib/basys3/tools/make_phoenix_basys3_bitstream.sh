#!/bin/bash
# Bitstream wrapper for the Phoenix Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_phoenix_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_phoenix_DE10_lite \
  --top-entity phoenix_basys3 \
  -- "${1:-}"
