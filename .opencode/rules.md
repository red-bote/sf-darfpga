# Operational rules (meta, not functional)

## Terminology (source of truth — use this wording everywhere)

- hardware = a particular hardware platform being built in FPGA (one `<Machine>-by-Dar/` directory).
- machine  = a hardware platform combined with a particular romset (some hardware support multiple romsets).
- Say "roms"/"romset", never "MAME roms"; describe machines/hardware, never "games"/"arcade" (upstream filenames keep their names, e.g. `make_pooyan_proms.sh`).

## Git

- Do not look at git unless specifically requested to do so, only once. Never run git commands (status, log, diff, checkout, …) unprompted. When explicitly requested, inspect once — a single read — and don't keep re-checking.

## Filesystem scope

- Do not read anything outside this repository directory without explicit
  permission (no sibling or backup checkouts,
  nothing under `$HOME`, no symlinked locations). Diagnose and reason only from
  files inside the repo.
- Exceptions (documented elsewhere in these rules): `/tmp` (scratch, and the
  Vivado build scripts that run from `/tmp`), `~/roms/` (`ROMZIP`), and the
  `ENV_VAR` paths from the tool resolution rule (`VIVADO`). Anything
  else outside the repo requires the user's explicit permission.

## Documentation scope (AGENTS.md)

- AGENTS.md must not carry design information about the support scripts
  (`make_*_proms.sh`,
  `contrib/basys3/*.sh`, `Makefile`) unless explicitly instructed otherwise
  in these Operational Rules. Script design lives in the scripts themselves
  and in the root `README.md`; keep AGENTS.md to operational conditions.

- Explicitly instructed (AGENTS.md may carry these):
  - Vivado build scripts run from `/tmp` so `vivado.log`/`vivado.jou` land
    outside the repo.
  - Tools/paths resolve as `ENV_VAR → project default → interactive prompt`:
    - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
    - roms: `ROMZIP` → `~/roms/`
   - Imported third-party scandoublers (MiST `scandoubler.v`; DECA `vga_scandoubler.v` in the
     trees that still use it) are cleanroom imports — never modify the tracked copy; Vivado
     fixes go in a separate patch applied to the project copy (e.g. `scandoubler_fix.patch`).

## Documentation scope (PORTING_SPEC.md)

- `PORTING_SPEC.md` is scoped to **design intent** for implementing the port: it
  is authored before (or alongside) the implementation and informs how to
  implement it. Keep it to design-intent detail only.
- It carries no port status and no build/verification report — those have no
  place in the PORTING_SPEC.
- Concrete implementation and wiring details live in the machine `README.md`,
  not the PORTING_SPEC.
- The root `PORTING_SPEC.md` is the generic bring-up procedure; each
  `<Machine>-by-Dar/.../PORTING_SPEC.md` is that machine's design-intent spec.

## Vivado execution

- Do not run `make synth`, `make bitstream`, or the underlying
  `make_*_basys3_bitstream.sh` scripts (or invoke `vivado` directly for
  synthesis/implementation) unless the user very explicitly asks for a
  synthesis or bitstream build in that message. Scripted steps that only
  stage sources (`setup`, `create_prj`, `clk_wiz`, `patch`) are not covered
  by this rule.

## Clocking (Basys3 ports)

- Use one clock domain where practical: a single `clk_wiz_0` output from the
  100 MHz oscillator. Derive the CPU, pixel, sound and keyboard rates as clock
  enables, not as extra MMCM outputs or clocks toggled in logic.
- Pick the MMCM frequency from the original hardware's crystal
  (`CLOCK_CRYSTAL_CATALOG.md`, MAME `XTAL` values), so the main CPU rate is
  exact or as close as practical.
- Keep VGA output within H 31.0-32.0 kHz and V 56-61 Hz. Acceptance is sync on
  the Sylvania SF150 and the LG Flatron L2000CP. Rates outside the window are
  recorded exceptions: machine-native Phoenix 61.04 Hz and Computer-Space 61.6
  Hz.
- Record the requested and achieved MMCM solve (DIVCLK / MULT_F /
  CLKOUT_DIVIDE) in the machine README. Force a solve in `make_clk_wiz_0.sh`
  only when Vivado's own solve misses the window.
- Pass asynchronous inputs (PS/2, JA, buttons) through 2-FF synchronizers on
  the clock the consuming core logic uses. Add debounce only for observed
  button problems.
- Builds must meet timing: no negative WNS or WHS in the routed timing summary.
- Where one clock can't meet both CPU accuracy and the VGA window, record the
  trade-off in the machine's `PORTING_SPEC.md`.

## Documentation scope (machine README.md)

- Each `<Machine>-by-Dar/README.md` is the single source of truth for that
  machine's design and build, but report **minimal status** in it — at most a
  brief verified/complete statement.
- Port status (scripted / synthesized / bitstream built / hardware-verified) is
  tracked in the root `README.md` Status section; keep the machine README lean
  and point there rather than repeating a status narrative.
