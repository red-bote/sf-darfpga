#!/bin/bash
# Setup wrapper for the Xevious Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_xevious_de2_de10_lite_2017_05_01 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/xevious/vhdl_xevious_de2_de10_lite_2017_05_01.zip/download" \
  --sha256  5277ba44cf828d63b903116b090b4b38f039fb0e212a5b86f6498f30f3d592c3
