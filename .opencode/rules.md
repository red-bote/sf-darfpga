# Operational rules (meta, not functional)

This file and `.opencode/skills/` in this tree are the authoritative rule and skill set for
Dar (darfpga) Basys 3 work in `sf-darfpga/` (revised 2026-10-22). The procedure itself is
`PORTING_SPEC.md`; these rules do not restate it.

## Terminology (source of truth — use this wording everywhere)

- hardware = a particular hardware platform being built in FPGA (one `<Machine>-by-Dar/` directory).
- machine  = a hardware platform combined with a particular romset (some hardware support multiple romsets).
- Say "roms"/"romset", never "MAME roms"; describe machines/hardware, never "games"/"arcade" (upstream filenames keep their names, e.g. `make_pooyan_proms.sh`).

## Git

- Do not look at git unless specifically requested to do so, only once. Never run git commands (status, log, diff, checkout, …) unprompted. When explicitly requested, inspect once — a single read — and don't keep re-checking.
- Do not stage or commit; the user commits.

## Filesystem scope

- Do not read anything outside this repository directory without explicit
  permission (no sibling or backup checkouts,
  nothing under `$HOME`, no symlinked locations). Diagnose and reason only from
  files inside the repo.
- Exceptions (documented elsewhere in these rules): `/tmp` (scratch, and the
  Vivado scripts that run from `/tmp`), `~/roms/` (`ROMZIP`), and the
  `ENV_VAR` paths from the tool resolution rule (`VIVADO`). Anything
  else outside the repo requires the user's explicit permission.

## Documentation scope (AGENTS.md)

- AGENTS.md must not carry design information about the support scripts
  (`make_*_proms.sh`,
  `contrib/basys3/*.sh`, `Makefile`) unless explicitly instructed otherwise
  in these Operational Rules. Script design lives in the scripts themselves
  and in `PORTING_SPEC.md`; keep AGENTS.md to operational conditions.

- Explicitly instructed (AGENTS.md may carry these):
  - Vivado scripts run from `/tmp` so `vivado.log`/`vivado.jou` land
    outside the repo.
  - Tools/paths resolve as `ENV_VAR → project default → interactive prompt`:
    - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
    - roms: `ROMZIP` → `~/roms/`
  - Imported third-party scandoublers (MiST `scandoubler.v`) are cleanroom imports;
    handling per §"Source modification".

## Documentation scope (PORTING_SPEC.md)

- The root `PORTING_SPEC.md` is the generic porting procedure for Dar cores. Each
  `<Machine>-by-Dar/contrib/basys3/PORTING_SPEC.md` (template
  `wip/machine/contrib/basys3/PORTING_SPEC.md.template`) carries that machine's design
  intent and implementation detail: clocking, video path, input analysis, DIPs, patches
  and the reason for each.
- A machine PORTING_SPEC carries no port status and no build report.

## Documentation scope (machine README.md)

- Each `<Machine>-by-Dar/README.md` (template `wip/machine/README.md.template`) is the
  outward-facing summary: identity and provenance, connections, controls, switches, a
  clocks table (original vs Basys 3), ROMs, build steps, open known issues, and a table
  of the third-party sources the port changes (source, origin, patch, change); the
  Basys 3 top level and the XDC are not listed. No status section: verification results
  go in the commit message.
- Implementation detail belongs in the machine PORTING_SPEC; the README points to it.
- The root `README.md` carries the machine index and the overall status.
- Attribution per borrowed file: origin URL, true author(s), license where known.

## Source modification (wrapper vs patch, third-party imports)

- Board-level adaptation (IO mapping, input conditioning, key mapping, input polarity,
  clocking, video/audio output stages) goes in the Basys3 wrapper
  (`contrib/basys3/code/<top>.vhd`, tracked, edited directly).
- Patch Dar's sources only when the wrapper cannot do the job (synthesis fixes, signals
  not exposed at the core boundary, clock-enable conversion). Each patch is recorded in
  the machine PORTING_SPEC with the reason the wrapper was insufficient.
- No Basys3-only modified copies of upstream or third-party sources. A change to such a
  file is a `.patch` applied in place to the file.
- Third-party sources not in the upstream tree (MiST `scandoubler.v`): the pristine
  original is tracked unmodified in `contrib/code/`, copied into the Vivado project under
  `sources_1/imports/<third-party name>/`, and patched there
  (`contrib/code/scandoubler_fix.patch`). The original and its patch are tracked; the
  project copy is generated.
- No here-doc generated sources: static `.tcl` with `-tclargs`, tracked `.vhd`.

## Vivado execution

- Do not run `make synth`, `make bitstream`, `make rebuild-load`, the underlying
  `make_*_basys3_bitstream.sh` scripts, or `vivado` for synthesis/implementation unless
  the user very explicitly asks for a synthesis or bitstream build in that message.
  Steps that only stage sources or parse them (`setup`, `create_prj`, `clk_wiz`, `patch`,
  `check`) are not covered by this rule.

## Clocking (Basys3 ports)

- Use one clock domain: a single `clk_wiz_0` output from the 100 MHz oscillator. Derive
  the CPU, pixel, sound, keyboard and PWM rates as clock enables, not as extra MMCM
  outputs or clocks toggled in logic.
- Track the original hardware's system oscillator: research the PCB crystal from MAME
  driver source (`XTAL(...)`, machine config) and `CLOCK_CRYSTAL_CATALOG.md`, then pick
  the MMCM so the single domain reproduces the CPU rate and the sound rate as closely as
  practical. Dar's DE10 PLL value is a starting point, not the reference.
- Sound fidelity is a reason to match the clock, not only CPU accuracy: fixed-point sound
  engines (decay envelopes, IIR filters, delta-sigma DACs, sample dividers) are tuned for
  the original clock.
- Keep VGA output within H 31.0-32.0 kHz and V 56-61 Hz. Acceptance is sync on
  the Sylvania SF150 and the LG Flatron L2000CP. Rates outside the window are
  recorded exceptions: machine-native Phoenix 61.04 Hz and Computer-Space 61.6 Hz.
  Time-Pilot and Pooyan run 264 lines (60.61 Hz, MAME `pooyan.cpp`), not Dar's 260.
- Record the requested and achieved MMCM solve (DIVCLK / MULT_F /
  CLKOUT_DIVIDE) in the machine README and PORTING_SPEC. Force a solve in
  `make_clk_wiz_0.sh` only when Vivado's own solve misses the window.
- Pass asynchronous inputs (PS/2, JXADC, buttons) through 2-FF synchronizers on
  the clock the consuming core logic uses. Add debounce only for an observed fault or a
  core that edge-detects the input at full clock rate (`PORTING_SPEC.md` §4.4).
- Builds must meet timing: no negative WNS or WHS in the routed timing summary.
- Where one clock can't meet both CPU accuracy and the VGA window, record the
  trade-off in the machine's PORTING_SPEC.

## Inputs and switches

- Keyboard keys follow the MAME defaults (`PORTING_SPEC.md` §3.1); the wrapper ignores the
  PS/2 E0 prefix.
- Joystick direction+fire combos only with the user's approval per machine.
- Spare switches drive the core's DIP inputs where no core patch is needed; switch down =
  Dar's DE10 default (`PORTING_SPEC.md` §3.2).

