#!/bin/bash
# Parse-only Vivado check_syntax of a machine's project (no synthesis).
# Usage (from a machine directory, or via `make check`):
#   ../tools/check-syntax.sh <SRC_DIR> <TOP_ENTITY>
# Prints the messages between CHECK_SYNTAX_BEGIN/END, minus the two expected
# classes (MiST scandoubler.v HDL 9-3527 "used before its declaration", clk_wiz
# HDL 9-1672 "direction ... not explicitly declared"). Exit 1 on any ERROR or
# CRITICAL WARNING in the remaining output, except HDL 9-3240 inside rtl_dar/.
# Limits: parse-only; some errors appear only at synthesis (see
# sf-darfpga/PORTING_SPEC.md section 8).
set -euo pipefail
src_dir="${1:?SRC_DIR}"; top="${2:?TOP_ENTITY}"
here="$(pwd)"
xpr="$here/$src_dir/basys3/$top.xpr"
[ -f "$xpr" ] || { echo "error: no project $xpr (run 'make setup clk_wiz patch')" >&2; exit 1; }
# VIVADO: ENV_VAR -> project default (AGENTS.md "Tool / path resolution"). Inside make,
# VIVADO may hold machine.mk's directory value, so use it only if it is an executable.
vivado=/tools/Xilinx/Vivado/2020.2/bin/vivado
if [ -n "${VIVADO:-}" ] && [ -f "$VIVADO" ] && [ -x "$VIVADO" ]; then vivado="$VIVADO"; fi
tcl="$(cd "$(dirname "$0")" && pwd)/vivado/check_syntax.tcl"
out="$(cd /tmp && "$vivado" -mode batch -nojournal -nolog -source "$tcl" -tclargs "$xpr" 2>&1 \
      | sed -n '/^CHECK_SYNTAX_BEGIN/,/^CHECK_SYNTAX_END/p' \
      | grep -v 'HDL 9-3527.*scandoubler\.v\|HDL 9-1672' || true)"
echo "$out"
# Known: HDL 9-3240 (expression actual) inside Dar's pristine core (rtl_dar/) on Bagman,
# Crazy-Kong, Satans-Hollow, Tron, Xevious; printed, not failing. Wrappers must be clean.
if echo "$out" | grep '^ERROR\|^CRITICAL WARNING' | grep -vq 'HDL 9-3240.*/rtl_dar/'; then exit 1; fi
