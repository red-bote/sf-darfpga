# Solar-Fox-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_solar_fox_rev_0_1_2019_11_22.zip` (SourceForge folder `Solarfox`, per
  the repo-root `downloads.md`) → `vhdl_solar_fox_rev_0_1_2019_11_22/` at the machine root.
- Top entity: `solar_fox_basys3` (target file `sources_1/new/solar_fox_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.

## 2. Clocking

- Single core clock: **40 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`,
  `CLKOUT0_DIVIDE_F=25.0`. Reset active-high (`btnC`), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Berzerk/Bagman/Pooyan pattern), implemented 2026-10-01 (MMCM reset = btnC).

## 4. Video (31 kHz VGA / 15 kHz TV)

- No external scandoubler: the core doubles scanlines internally. Mode toggled by keyboard
  **F8** (31 kHz VGA / 15 kHz TV), not a Basys 3 switch — same keyboard-only convention as
  Kick/Sky-skipper.

## 5. Audio (stereo L/R PWM, mono out on PmodAMP2)

- The core carries a stereo L/R PWM path; only the left channel drives PmodAMP2 `O_PMODAMP2_AIN`
  (mono out) — same convention as Kick. Keyboard **F5** toggles separate/stereo audio mode;
  **F7** toggles service mode. `sw(15)`/`sw(14)` → AMP gain/shutdown (standard convention).

## 6. Inputs

- PS/2 keyboard + `kbd_joystick`, OR-merged with the JA joystick (active-low, invert to
  active-high, "verified working" per machine `README.md`): `JA1=Right, JA2=Left, JA3=Down,
  JA4=Up, JA7=Fire`.
- Coin = JA fire+up combo, OR keyboard F1, OR `btnU`; Fast = JA fire+left combo, OR keyboard F2,
  OR `btnL` — the root `PORTING_SPEC.md`'s generic default IO mapping (coin-in = `btnU`, 1P
  start = `btnL`) applies since the core has real `coin1`/`fast1` inputs for them to drive.
- `btnD`/`btnR` declared but unconnected (reserved): the core ties `coin2`/`fast2` (and all P2
  inputs) to `'0'` with no genuine second-coin or second-start facility (DE10-lite header:
  "Cocktail mode : NO"), so the generic default's carve-out ("second coin-in: only if the core
  has 2 coin inputs") means there is nothing for them to drive.

## 7. LEDs

- No `led` port: the pristine top's `ledr` assignment is dead code (commented out, references
  an undefined signal, never actually driven) — confirmed by reading `solarfox_de10_lite.vhd`.
  Matches Bagman/Berzerk/Pooyan/Time-Pilot/Burnin-Rubber/Zaxxon's convention of leaving `led`
  unconstrained when the core doesn't drive it. (The machine `README.md`'s earlier claim of
  `led(15:0)` present was stale/inaccurate and has been corrected.)

## 8. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` will live directly in `basys3/` as
  `basys3/solar_fox_basys3.xpr`, with the sources tree at `basys3/solar_fox_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.
- Note: the color PROM `82s123.12d` is shared with Kick's romset (per machine `README.md`
  §"ROM set required").
