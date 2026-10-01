# Bagman-FPGA-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_bagman_rev_0_1_2018_06_05.zip` (SourceForge folder `bagman`, per the
  repo-root `downloads.md`) → `vhdl_bagman_rev_0_1_2018_06_05/` at the machine root.
- Top entity: `bagman_basys3` (target file `sources_1/new/bagman_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.
- Status: complete, hardware-verified (see root `README.md` Status section).

## 2. Clocking

- Single core clock: **12 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
  - Clock revision 2026-10-01 (`../../CLOCKING_SPEC.md` section 4): retargeted to 12.288 MHz (DIVCLK 5 / MULT_F 48 / CLKOUT0_DIVIDE_F 78.125) so the CPU runs at the original 3.072 MHz (was -2.34%). Frequencies quoted elsewhere in this spec for derived clocks scale by the same ratio.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=49.875`,
  `CLKOUT0_DIVIDE_F=83.125`. Reset active-high (`btnC`), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Berzerk/Bagman/Pooyan pattern) — core held
  in reset while `btnC` is pressed or the MMCM has not locked. `clk_wiz_0`'s own `reset` port is
  driven directly by `btnC`.

## 4. Video (31 kHz VGA / 15 kHz TV, switch-selectable)

- No external scandoubler: the core doubles scanlines internally (matches Berzerk's pattern),
  muxed on `sw(13)` between 31 kHz progressive VGA and 15 kHz TV (native rate, composite sync
  on HS). See machine `README.md` Features/IO-mapping for the exact port-level wiring once the
  top-level wrapper is authored.

## 5. Audio (mono PWM on PmodAMP2)

- Mono PWM accumulator pattern (Berzerk/Burnin'-Rubber convention); `sw(15)` → AMP gain,
  `sw(14)` → AMP shutdown.

## 6. Inputs

- PS/2 keyboard + `kbd_joystick`, OR-merged with the JA joystick (active-low, invert to
  active-high): `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Jump`.
- Coin = JA fire+up combo (OR keyboard F3); Start 1 = JA fire+left combo (OR keyboard F1);
  Start 2 = keyboard F2. Player 2 mirrors player 1.
- No dedicated coin/start buttons (unlike Berzerk) — only `btnC` (reset) is wired.

## 7. LEDs

- No `led` port: matches Berzerk/Pooyan/Time-Pilot's convention of leaving `led` unconstrained
  when the core doesn't meaningfully drive it (machine `README.md`'s IO-mapping table has no
  LED row).

## 8. Synthesis-fix patch

- `bagman_xor_width.patch` (flat `contrib/code/`): left-pads four narrow XOR literals in
  `tile_graph_rom_addr` to 13 bits, fixing a Vivado synthesis width-mismatch. Applied
  automatically by `setup_bagman.sh`. Full mechanics and verify-grep documented in machine
  `README.md` §"Applying the XOR-width fix" — not duplicated here.

## 9. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/bagman_basys3.xpr`, with the sources tree at `basys3/bagman_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.
