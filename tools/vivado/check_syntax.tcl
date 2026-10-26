# Parse-only syntax check of a Vivado project (no synthesis).
# Usage: vivado -mode batch -source check_syntax.tcl -tclargs <project.xpr>
# Run from /tmp (tools/check-syntax.sh does) so vivado.log/.jou stay out of the repo.
# Output is bracketed by CHECK_SYNTAX_BEGIN / CHECK_SYNTAX_END.
open_project [lindex $argv 0]
set r [check_syntax -return_string]
puts "CHECK_SYNTAX_BEGIN\n$r\nCHECK_SYNTAX_END"
close_project
