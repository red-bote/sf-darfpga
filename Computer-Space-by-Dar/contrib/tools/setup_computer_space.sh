#!/bin/bash
# Setup wrapper for the Computer Space Basys3 port. Delegates to the shared
# darfpga_setup() in sf-darfpga/tools/lib/darfpga-setup.sh.
#
# Two quirks this machine needs beyond the default:
#   --extra-exclude: the Vivado project imports its own copy of
#     motion_board.vhd (sources_1/imports/rtl/motion_board.vhd, decoupled
#     from the pristine rtl/ copy once imported), so
#     computer_space_motion_q_assoc.patch and
#     computer_space_rocket_timer_synth_fix.patch are applied to that copy
#     by create_project.sh instead -- the pristine rtl/motion_board.vhd is
#     never modified.
#   --binary: the extracted Dar rtl files are CRLF; a plain `patch` run
#     (which strips trailing CRs from the patch) cannot match them.
#
# Rom-prep here (contrib/tools/prep_roms.sh) verifies the six sound-waveform
# .hex files and generates rom_*.vhd replacements -- no ROMs, no
# make_vhdl_prom (Computer Space is a discrete TTL game).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/../tools/lib/darfpga-setup.sh"

darfpga_setup \
  --root    "$ROOT" \
  --src-dir vhdl_computer_space_rev_1_1_2017_11_22 \
  --url     "https://sourceforge.net/projects/darfpga/files/Software%20VHDL/computer_space/vhdl_computer_space_rev_1_1_2017_11_22.zip/download" \
  --sha256  706ee25e84e22bbf115ad63fb4821feeb4f1c0d83971076b3be08070ac502a51 \
  --extra-exclude '*computer_space_motion_q_assoc.patch' \
  --extra-exclude '*computer_space_rocket_timer_synth_fix.patch' \
  --binary
