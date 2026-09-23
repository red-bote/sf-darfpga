#!/bin/bash
# Shared Vivado synth/bitstream driver for sf-darfpga Dar-convention Basys3
# ports.
#
# Source (not exec'd) from a machine's
# contrib/basys3/tools/make_<game>_basys3_bitstream.sh, then call
# darfpga_build_bitstream with that machine's parameters.
#
# The project must already have its sources in place: run `make setup`,
# `make clk_wiz` and `make patch` first (all covered by `make synth`).
#
# Per project rules this runs from /tmp so vivado.log / vivado.jou stay
# outside the repository. VIVADO resolves ENV_VAR -> project default, per
# the root AGENTS.md "Tool / path resolution" convention.
#
# On a successful run, appends one row to sf-darfpga/build-metrics.csv
# (machine, mode, wall-clock duration, LUT/FF/BRAM/DSP utilization %, WNS/TNS)
# for cross-machine build-time/resource comparison. A failed run is not
# logged (its duration-to-failure isn't a useful data point for this).
darfpga_build_bitstream() {
    local root="" src_dir="" top_entity="" mode=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) root="$2"; shift 2 ;;
            --src-dir) src_dir="$2"; shift 2 ;;
            --top-entity) top_entity="$2"; shift 2 ;;
            --) shift ;;
            synth|bitstream) mode="$1"; shift ;;
            *) echo "darfpga_build_bitstream: unknown argument: $1" >&2; return 2 ;;
        esac
    done
    if [ -z "$root" ] || [ -z "$src_dir" ] || [ -z "$top_entity" ]; then
        echo "darfpga_build_bitstream: --root, --src-dir, --top-entity are all required" >&2
        return 2
    fi
    if [ "$mode" != "synth" ] && [ "$mode" != "bitstream" ]; then
        echo "darfpga_build_bitstream: mode must be 'synth' or 'bitstream'" >&2
        return 2
    fi

    local vivado="${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}"
    local xpr="$root/$src_dir/basys3/$top_entity.xpr"

    if [ ! -f "$xpr" ]; then
        echo "error: Vivado project not found: $xpr" >&2
        echo "Run 'make setup clk_wiz patch' first." >&2
        return 1
    fi

    local work="/tmp/${top_entity}_bitstream"
    mkdir -p "$work"
    local tcl="$work/run_${mode}.tcl"
    local util_rpt="$work/utilization.rpt"
    local stats_file="$work/stats.txt"
    local metrics_run
    if [ "$mode" = "synth" ]; then metrics_run="synth_1"; else metrics_run="impl_1"; fi

    cat > "$tcl" <<TCLEOF
open_project "$xpr"
if { "$mode" eq "synth" } {
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if { [get_property PROGRESS [get_runs synth_1]] ne "100%" } {
        puts "ERROR: synthesis failed (PROGRESS [get_property PROGRESS [get_runs synth_1]])"
        exit 1
    }
} else {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if { [get_property PROGRESS [get_runs impl_1]] ne "100%" } {
        puts "ERROR: implementation/bitstream failed"
        exit 1
    }
}

# Build metrics (see darfpga_build_bitstream in darfpga-bitstream.sh): open
# the run that just completed and dump utilization + timing stats for the
# shell to parse. Best-effort -- a reporting failure here must not fail the
# build, so each step is wrapped in catch.
catch {
    open_run $metrics_run
    report_utilization -file "$util_rpt"
    set wns [get_property STATS.WNS [get_runs $metrics_run]]
    set tns [get_property STATS.TNS [get_runs $metrics_run]]
    set fh [open "$stats_file" w]
    puts \$fh "wns=\$wns"
    puts \$fh "tns=\$tns"
    close \$fh
}

close_project
TCLEOF

    # Captured via `|| vivado_status=$?` (not a bare `$?` on the next line)
    # so a failed run doesn't trip `set -e` before cleanup/metrics-skip below
    # runs -- the failure is still propagated via the explicit `return`.
    local start_ts end_ts duration vivado_status=0
    start_ts=$(date +%s)
    (cd "$work" && "$vivado" -mode batch -nolog -nojournal -source "$tcl") || vivado_status=$?
    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))

    if [ "$vivado_status" -eq 0 ]; then
        _darfpga_log_build_metrics \
            --root "$root" --game "$(basename "$root")" --top-entity "$top_entity" \
            --mode "$mode" --run "$metrics_run" --duration "$duration" \
            --util-rpt "$util_rpt" --stats-file "$stats_file"
    fi

    rm -rf "$work"

    if [ "$vivado_status" -ne 0 ]; then
        return "$vivado_status"
    fi

    if [ "$mode" = "synth" ]; then
        echo "Synthesis complete: synth_1 (${duration}s)"
    else
        local bit="$root/$src_dir/basys3/$top_entity.runs/impl_1/$top_entity.bit"
        if [ -f "$bit" ]; then
            echo "Bitstream: $bit (${duration}s)"
        else
            echo "warning: bitstream not found at $bit" >&2
        fi
    fi
}

# Parse the utilization report + timing stats file from a completed run and
# append one row to sf-darfpga/build-metrics.csv. Best-effort: a missing or
# unparsable report degrades to blank fields rather than failing the build
# (report_utilization's exact table format is tied to Vivado 2020.2; a
# toolchain upgrade may need the awk patterns below adjusted).
_darfpga_log_build_metrics() {
    local root="" game="" top_entity="" mode="" run="" duration="" util_rpt="" stats_file=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) root="$2"; shift 2 ;;
            --game) game="$2"; shift 2 ;;
            --top-entity) top_entity="$2"; shift 2 ;;
            --mode) mode="$2"; shift 2 ;;
            --run) run="$2"; shift 2 ;;
            --duration) duration="$2"; shift 2 ;;
            --util-rpt) util_rpt="$2"; shift 2 ;;
            --stats-file) stats_file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # "Slice LUTs"/"Slice Registers" is the 7-series (this repo's part,
    # xc7a35tcpg236-1) label in Vivado 2020.2's report_utilization; "CLB
    # LUTs"/"CLB Registers" is the UltraScale+ equivalent, matched too in
    # case the toolchain/part ever changes.
    local lut_pct="" ff_pct="" bram_pct="" dsp_pct=""
    if [ -f "$util_rpt" ]; then
        lut_pct=$(awk -F'|' '/\| (Slice|CLB) LUTs\*? *\|/{gsub(/ /,"",$6); print $6; exit}' "$util_rpt")
        ff_pct=$(awk -F'|' '/\| (Slice|CLB) Registers\*? *\|/{gsub(/ /,"",$6); print $6; exit}' "$util_rpt")
        bram_pct=$(awk -F'|' '/\| Block RAM Tile *\|/{gsub(/ /,"",$6); print $6; exit}' "$util_rpt")
        dsp_pct=$(awk -F'|' '/\| DSPs *\|/{gsub(/ /,"",$6); print $6; exit}' "$util_rpt")
    fi

    local wns="" tns=""
    if [ -f "$stats_file" ]; then
        wns=$(sed -n 's/^wns=//p' "$stats_file")
        tns=$(sed -n 's/^tns=//p' "$stats_file")
    fi

    local csv="$root/../build-metrics.csv"
    if [ ! -f "$csv" ]; then
        echo "timestamp,game,top_entity,mode,run,duration_s,lut_pct,ff_pct,bram_pct,dsp_pct,wns_ns,tns_ns" > "$csv"
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$game" "$top_entity" "$mode" "$run" "$duration" \
        "$lut_pct" "$ff_pct" "$bram_pct" "$dsp_pct" "$wns" "$tns" >> "$csv"
    echo "Build metrics logged: $csv"
}
