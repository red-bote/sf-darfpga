# Popeye-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_popeye_rev_0_3_2020_01_27.zip` (SourceForge folder `popeye`, per the
  repo-root `downloads.md`) → `vhdl_popeye_rev_0_3_2020_01_27/` at the machine root.
- Top entity: `popeye_basys3` (target file `sources_1/new/popeye_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.
- Status: built and hardware-verified (root `README.md` Status section). Sections below were
  first written as design intent before the top level existed; where they differ,
  `contrib/basys3/code/popeye_basys3.vhd` is authoritative.

## 2. Clocking

- Single core clock: **40.32 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=31.5`,
  `CLKOUT0_DIVIDE_F=15.625`. Reset active-high (`btnC`), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Berzerk/Bagman/Pooyan pattern), implemented.
- Core patch `contrib/code/popeye_clock_cnt2_width.patch` (2026-10-01): widens the 4-bit `clock_cnt2` to 5 bits so the `"10011"` reload fires (CPU f/10 = 4.032 MHz, AY f/20); the pristine counter ran mod 16 (CPU f/8, +26%). `../../CLOCKING_SPEC.md` 5.6.

## 4. Video (31 kHz VGA / 15 kHz TV, switch-selectable)

- No external scandoubler: the core doubles scanlines internally. `sw(13)` → core's
  `tv15Khz_mode` input, selecting 31 kHz VGA (`'0'`) / 15 kHz TV (`'1'`) — same runtime-switch
  convention as Bagman, unlike Kick/Sky-skipper/Solar-Fox's keyboard-only (F8) toggle.

## 5. Audio (mono PWM on PmodAMP2)

- Mono PWM accumulator pattern (Berzerk/Burnin'-Rubber convention); `sw(15)` → AMP gain,
  `sw(14)` → AMP shutdown.

## 6. Inputs

- PS/2 keyboard + `kbd_joystick`, OR-merged with the JA joystick (active-low, invert to
  active-high, "verified working" per machine `README.md`): `JA1=Right, JA2=Left, JA3=Down,
  JA4=Up, JA7=Punch`.
- Coin = keyboard F1 OR `btnU`; Start 1 = keyboard F2 OR `btnL`; Start 2 = keyboard F3 OR
  `btnR`; Service = keyboard F7. No JA fire+direction combos (removed 2026-10-02). Player 2
  mirrors player 1.

## 7. LEDs

- No LEDs: the implemented `popeye_basys3` entity has no `led` port and the XDC constrains
  none (the earlier design intent to wire `led(15:0)` was not implemented).

## 8. Synthesis-fix patch

- `popeye_linmix_sensitivity.patch` (flat `contrib/code/`): adds `ioa_inreg` to the pristine
  YM2149 mixer's (`rtl_mikej/ym_2149_linmix.vhd`) `p_rdata` process sensitivity list. Applied
  automatically by `setup_popeye.sh`. Full mechanics and verify-grep documented in machine
  `README.md` §"Applying the linmix sensitivity fix" — not duplicated here.

## 9. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` will live directly in `basys3/` as
  `basys3/popeye_basys3.xpr`, with the sources tree at `basys3/popeye_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP`/`ROMZIP2` → `~/roms/popeye.zip` / `~/roms/popeyeu.zip` (two romsets; the
    `popeyeu` set provides the `7a`/`7b`/`7c`/`7e` speech ROMs absent from the plain set).
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.

## 10. Open items

- `.xdc`/`.xpr` (contrib/basys3/vivado/), `make_clk_wiz_0.sh`, the top-level wrapper
  (`make_de10_lite_to_basys3_patch.sh`), and the synth/bitstream driver script all remain to be
  authored before `make create_prj`/`clk_wiz`/`patch`/`synth`/`bitstream` can run.
