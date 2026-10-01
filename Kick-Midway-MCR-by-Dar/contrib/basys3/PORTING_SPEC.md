# Kick-Midway-MCR-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_kick_rev_0_2_2019_11_22.zip` (SourceForge folder `Kick_kickman`, per the
  repo-root `downloads.md`) → `vhdl_kick_rev_0_2_2019_11_22/` at the machine root.
- Top entity: `kick_basys3` (target file `sources_1/new/kick_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.

## 2. Clocking

- Single core clock: **40 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`,
  `CLKOUT0_DIVIDE_F=25.0`. Reset active-high (`btnC`).

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` with MMCM reset = btnC (standard pattern,
  2026-10-01, `../../CLOCKING_SPEC.md` section 6); previously `locked => open` (Tron pattern).

## 4. Video (31 kHz VGA / 15 kHz TV)

- No external scandoubler: the core doubles scanlines internally. Mode toggled by keyboard
  **F8** (31 kHz VGA / 15 kHz TV), not a Basys 3 switch — unlike Bagman/Popeye's `sw(13)`
  convention, this port's mode select stays keyboard-only per the pristine core's own toggle.

## 5. Audio (stereo L/R PWM, mono out on PmodAMP2)

- The core carries a stereo L/R PWM path; only the left channel drives PmodAMP2 `O_PMODAMP2_AIN`
  (mono out). Keyboard **F5** toggles separate/stereo audio mode in the core; **F7** toggles
  service mode. `sw(15)`/`sw(14)` → AMP gain/shutdown (standard convention).

## 6. Inputs

- PS/2 keyboard + `kbd_joystick`, OR-merged with the JA joystick (active-low, invert to
  active-high): `JA1=Spin right, JA2=Spin left, JA3=Down, JA4=Up(kick), JA7=Fire(speed up)`.
- Coin1 = keyboard F1 or `btnU`; Start 1 = keyboard F2 or `btnL`; Start 2 = keyboard F3 or
  `btnR` — per root `PORTING_SPEC.md` §3's default button mapping. No fire+direction combos.
- Coin2 = `btnD` only (the core's second coin input; no keyboard or JA path maps to it).

## 7. LEDs

- Unused/reserved — the authored `kick_basys3` top level declares no `led` port, matching the
  Bagman/Berzerk/Pooyan/Time-Pilot/Tron convention.

## 8. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` will live directly in `basys3/` as
  `basys3/kick_basys3.xpr`, with the sources tree at `basys3/kick_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.

## 9. Open items

- Physical Basys 3 hardware bring-up (the build chain through bitstream is scripted and
  verified; no software/build items remain).
