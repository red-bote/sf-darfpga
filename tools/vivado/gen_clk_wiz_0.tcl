# Generate the clk_wiz_0 MMCM IP (100 MHz in, one output) in a throwaway project.
# Usage: vivado -mode batch -source gen_clk_wiz_0.tcl -tclargs <work_dir> <freq_mhz>
# Run from /tmp. Output: <work_dir>/clk_wiz_0/clk_wiz_0.v and clk_wiz_0_clk_wiz.v.
# Single output per .opencode/rules.md "Clocking (Basys3 ports)".
set work [lindex $argv 0]
set freq [lindex $argv 1]
create_project mmcm_gen $work -part xc7a35tcpg236-1 -force
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir $work
set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $freq \
] [get_ips clk_wiz_0]
generate_target all [get_ips clk_wiz_0]
close_project
