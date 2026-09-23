#!/bin/bash
# Setup wrapper for the Burger Time Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_burger_time_rev_0_0_2017_12_27 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/burger_time/vhdl_burger_time_rev_0_0_2017_12_27.zip/download" \
  --sha256  2ee7567ae70ef4ca41b83f0b4525b9a08a0bc23beed5349699c0905e05e4f6f6
