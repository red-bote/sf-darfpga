#!/bin/bash
# Bitstream wrapper for the Zaxxon Basys3 port. Delegates to the shared
# darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_zaxxon_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_zaxxon_rev_0_0_2019_11_29 \
  --top-entity zaxxon_basys3 \
  -- "${1:-}"
