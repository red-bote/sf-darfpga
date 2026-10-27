---
name: vivado-batch-build
description: Run Vivado synthesis/bitstream builds for these ports correctly - launch from /tmp so logs stay out of the repo, VIVADO env resolution, synth vs bitstream targets, reading WNS/timing results, expected warnings for placeholder projects. Use ONLY when actually running or debugging a Vivado run, not for doc or script questions.
---

# Running Vivado builds

Tool resolution: `$VIVADO` env var, else
`/tools/Xilinx/Vivado/2020.2/bin/vivado`.

## Log hygiene

Build scripts run from `/tmp` scratch dirs (`/tmp/<top>_bitstream` for
`darfpga-bitstream.sh`) so `vivado.log` / `vivado.jou` land outside the repo. When
invoking vivado manually, `cd` to a `/tmp` directory first. Never commit logs,
journals, or bitstreams.

## Invocation

Prefer the machine Makefile:

```
make synth-<machine>      # synthesis only (resets synth_1 first)
make bitstream-<machine>  # implementation + write_bitstream
```

or call the machine's
`contrib/basys3/tools/make_<game>_basys3_bitstream.sh synth|bitstream`
directly. Scripts drive `vivado -mode batch -source <script>.tcl`; logs and
journal land in the cwd, which is why the cwd must be /tmp scratch.

Typical flow: `make setup-<machine>` (sources + PROM VHDL), `clk_wiz`, `patch`,
`check` (parse-only `check_syntax`, `tools/check-syntax.sh`, not covered by the
synthesis rule), then synth / bitstream on the user's request. Successful runs append
to `build-metrics.csv` and copy logs to `build-logs/<game>/` (gitignored).

## Reading results

- Success: run completes with 0 ERRORs; bitstream written.
- Timing: find WNS in the log / timing summary (`grep -i "worst negative"`).
  A negative WNS means unmet timing - do not ship that bitstream.
- CRITICAL/WARNING noise: judge individually. Missing-file warnings for the
  not-yet-generated clk_wiz_0 wrappers are expected between create_prj and
  clk_wiz steps.

## Run-level logs and reports

The driver-level `vivado.log` / `vivado.jou` stay in the /tmp cwd, but
`launch_runs` writes per-run logs inside the extracted tree (build artifacts,
removed by `make clean`):

- Errors:           `.runs/impl_1/runme.log` (and `.runs/synth_1/runme.log`)
- Timing WNS/TNS:   `.runs/impl_1/<game>_basys3_timing_summary_routed.rpt`
                    ("Design Timing Summary" table)
- Placed IO/pins:   `.runs/impl_1/<game>_basys3_io_placed.rpt`

## GUI Vivado coexistence

A user GUI session may run alongside batch builds (`pgrep -af vivado`; its
cwd hints at what it holds). Before a batch build:

- Check for stale locks (`<game>_basys3.xpr.lck`); clear them only when no
  GUI has that project open.
- `make create_prj` does `cp -f` of the tracked `.xpr` and will clobber any
  GUI-saved project state.
- After an aborted build, clear stale `.lck` files before rerunning.

## Read-only smoke test (no run launched)

Before spending a `synth` run to find a bad `.xpr` source list or a missing generated
file, open the project read-only and check every source resolves. No run is launched,
so this is not covered by the synthesis rule. Write the Tcl as a file in `/tmp`:

```tcl
open_project /path/to/<top>.xpr
set missing 0
foreach f [get_files -quiet] {
    if { ![file exists $f] } { puts "MISSING: $f"; incr missing }
}
puts "MISSING_COUNT: $missing"
close_project
```

Run `vivado -mode batch -nolog -nojournal -source smoke.tcl` from `/tmp`. Benign:
`filemgmt 56-3` (missing `.gen` / `.ip_user_files` directories, created on the first
run) and `Project 1-509` (no run launched yet).

## Expected check_syntax messages

`make check` hides MiST `scandoubler.v` HDL 9-3527 and `clk_wiz` HDL 9-1672. Known
core-internal HDL 9-3240 (expression actuals in Dar's code): Bagman, Crazy-Kong,
Satans-Hollow, Tron, Xevious. `check_syntax` is parse-only: Synth 8-2398 (literal actual
on a Verilog port) and Synth 8-944 (`&` inside a type conversion) appear only at
synthesis.

