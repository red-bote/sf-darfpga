#!/bin/bash
# Bitstream wrapper for the Burnin' Rubber Basys3 port. Delegates to the
# shared darfpga_build_bitstream() in sf-darfpga/tools/lib/darfpga-bitstream.sh.
#
# Usage: make_burnin_rubber_basys3_bitstream.sh {synth|bitstream}

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-bitstream.sh"

darfpga_build_bitstream \
  --root       "$ROOT" \
  --src-dir    vhdl_burnin_rubber_rev_0_0_2017_12_22 \
  --top-entity burnin_rubber_basys3 \
  -- "${1:-}"
