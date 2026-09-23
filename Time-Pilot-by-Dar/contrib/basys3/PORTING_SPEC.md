# Time-Pilot DE10-lite → Basys3 porting spec

This spec documents the completed porting process of Dar's Time Pilot hardware to the
Digilent Basys 3, mirroring the reference Pooyan port (`PORTING_SPEC.md`).

Time-Pilot is fully scripted (`contrib/tools/`, `contrib/basys3/vivado/`, `Makefile`:
`setup`/`clk_wiz`/`patch`/`synth`/`bitstream`).

- Top entity: `time_pilot_basys3` (target file `sources_1/new/time_pilot_basys3.vhd`)
- Part: `xc7a35tcpg236-1`, VHDL target language
- Sources (per `time_pilot_basys3.xpr`):
  - `rtl_dar/` — `time_pilot.vhd`, `time_pilot_sound_board.vhd`, `gen_ram.vhd`,
    `io_ps2_keyboard.vhd`, `kbd_joystick.vhd`
  - `rtl_T80/` — `T80.vhd`, `T80_Pack.vhd`, `T80_ALU.vhd`, `T80_MCode.vhd`, `T80_RegX.vhd`,
    `T80se.vhd`
  - `rtl_mikej/` — `YM2149_linmix_sep.vhd`
  - `clk_wiz_0` MMCM IP, `vga_scandoubler.v`, generated PROM VHDL from
    `tools/time_pilot_unzip/`

## 1. Port list (DE10-lite → Basys3)

Confirmed against `time_pilot_de10_lite.vhd` and the built `time_pilot_basys3.vhd`
(`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`):

| Basys 3 port | Function |
|---|---|
| `clk` (W5) | 100 MHz into `clk_wiz_0` MMCM |
| `btnC` | reset (active-high) |
| `btnU/L/R/D` | declared, unused (reserved) |
| `sw(15:0)` | see §6 (audio) and §7 (dip switches) |
| `ps2_dat` / `ps2_clk` (JB1/JB3) | PS/2 keyboard |
| `JA(4:0)` (JA1-4, JA7) | joystick (active-low) |
| `O_PMODAMP2_AIN/GAIN/SHUTD` (JC1/2/4) | PWM audio (PmodAMP2) |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz VGA |

## 2. Clocking

- The core uses **12.288 MHz** (machine core) and **14.318 MHz** (sound), derived from the
  100 MHz Basys 3 oscillator by the `clk_wiz_0` MMCM.
- Solved MMCM constants (verified, machine README):
  `DIVCLK_DIVIDE=7`, `CLKFBOUT_MULT_F=56.125`, `CLKOUT0_DIVIDE_F=65.25`,
  `CLKOUT1_DIVIDE=56`; `clk_out1` = 12.288 MHz, `clk_out2` = 14.318 MHz; reset active-high
  (btnC), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC` (active-high button), mirroring Pooyan.
- **DE10-lite (confirmed):** `reset_n` aliases the active-low `key(0)`; `reset <= not reset_n`.

## 4. Core instantiation

- Keep the `time_pilot` core port map (video r/g/b, csync, blankn, hs, vs, audio) unchanged.
- Signal names/widths confirmed against `rtl_dar/time_pilot.vhd`: `video_r/g/b` are
  **5 bits/color** (unlike Pooyan's 3+3+2); all other ports match the Pooyan-pattern names.
- **T80:** Time-Pilot uses a different T80 variant than Pooyan (`rtl_T80/T80.vhd` +
  `T80se.vhd`, entity `T80_Reg` directly, vs. Pooyan's `rtl_t80_350`/`T80pa`). Confirmed via an
  actual Vivado synthesis run: **no equivalent to Pooyan's xor-width fix is needed** — this T80
  variant synthesizes clean with 0 errors. No synthesis-fix patch is tracked for Time-Pilot.

## 5. Video / scan doubler (31 kHz VGA)

- Use the DECA `vga_scandoubler.v` (canonical cleanroom import, never
  modified, sourced from
  <https://github.com/DECAfpga/Arcade_Pooyan/blob/main/deca/vga_scandoubler.v>) with
  `enable_scandoubling` and `disable_scaneffect` both `1` (verified, machine README).
- The DE10-lite top leaves the core's `video_hs`/`video_vs` outputs unconnected (`open`,
  labeled "not tested"), even though `time_pilot.vhd` does drive them. The Basys3 top wires
  them to the scandoubler's `hsync_ext_n`/`vsync_ext_n` (Pooyan pattern) instead of leaving them
  open; confirmed correct on hardware.
- Time Pilot's core outputs 5 bits/color; the top pads each with 1 bit (`r & "0"`, etc.) to
  reach the scandoubler's 6-bit `ri`/`gi`/`bi`, then narrows the doubled 6-bit output back to
  4 bits/color (`vga_ro(5 downto 2)`, etc.) — same narrowing convention as Pooyan.
- `clkvideo => clock_6` (halved core clock), `clkvga => clock_12`, giving the ~2x read/write
  ratio for real horizontal doubling (Pooyan pattern).
- `create_project.sh` re-points the `.xpr`'s scandoubler reference from the external
  `$PPRDIR/../../../Arcade_Pooyan/deca/vga_scandoubler.v` path to the local
  `contrib/basys3/code/vga_scandoubler.v` import; confirmed in place and working.

## 6. Audio (mono PWM on PmodAMP2)

- Mono PWM audio on PmodAMP2 (verified, machine README and hardware).
- Documented switch semantics (verified, machine README and hardware):
  - `sw(15)` → `O_PMODAMP2_GAIN`: gain 0 = 12 dB, 1 = 6 dB
  - `sw(14)` → `O_PMODAMP2_SHUTD`: shutdown 0 = off, 1 = on
  - Note these differ from Pooyan's `sw14 = sound enable` / `sw15 = gain` semantics; both are a
    direct passthrough of the switch to the port (no inversion).

## 7. Inputs and dip switches

- PS/2 keyboard on JB (`ps2_dat`/`ps2_clk`) OR-merged with the JA joystick (verified, machine
  README and hardware). Key map: arrows = move, Space = fire, F1 = coin, F2 = start 1P, F3 =
  start 2P.
- JA joystick, active-low (switch to GND): `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`.
  Invert (`not JA`) to active-high to match the core boundary (Pooyan pattern).
- Coin/start from joystick via fire+direction combos: `coin = fire+up`, `start1 = fire+left`,
  `start2 = fire+right`.
- P2 mirrors P1 movement/fire inputs (verified, machine README and hardware).
- `btnC` = reset.
- **Dip switches:** unlike Pooyan, Time-Pilot's DE10-lite top hardcoded both dip registers
  (`dip_switch_1 => X"FF"`, `dip_switch_2 => X"4F"`) with no switch-driven mapping. Decision:
  mirror Pooyan — `dip_switch_1 => X"FF"` (still hardcoded, Coinage_B/Coinage_A), `dip_switch_2
  => sw(7 downto 0)` (Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)).

## 8. PROM VHDL generation (required; never distributed)

- Romset `timeplt.zip` unzipped into `tools/time_pilot_unzip/`, then
  `contrib/tools/prep_roms.sh` compiles `make_vhdl_prom`, converts
  `make_time_pilot_proms.bat` → `.sh`, and runs it to generate the PROM VHDL:
  `time_pilot_prog.vhd`, `time_pilot_sound_prog.vhd`, `time_pilot_char_grphx.vhd`,
  `time_pilot_sprite_grphx.vhd`, `time_pilot_palette_blue_green.vhd`,
  `time_pilot_palette_green_red.vhd`, `time_pilot_char_color_lut.vhd`,
  `time_pilot_sprite_color_lut.vhd`.
- The `.xpr` references these in place. `make setup` runs this automatically.
- Roms and the generated PROM VHDL are copyrighted MAME-derived content — never commit or
  distribute them.

## 9. Build / project setup

- Fully scripted, mirroring Pooyan: `make setup` (`contrib/tools/setup_time_pilot.sh` —
  download/extract, apply synthesis-fix patches, rom-prep), `make clk_wiz`
  (`contrib/basys3/vivado/make_clk_wiz_0.sh`), `make patch`
  (`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh` — authors `time_pilot_basys3.vhd`
  and its record patch), `make synth` / `make bitstream`
  (`contrib/basys3/tools/make_time_pilot_basys3_bitstream.sh`).
- `contrib/basys3/vivado/create_project.sh` lays down the Vivado project tree (non-nested:
  `.xpr` directly in `basys3/`, unlike Pooyan's nested `pooyan_basys3/` layout) and re-points the
  scandoubler import; run once after `make setup`.
- `setup_time_pilot.sh`'s synthesis-fix-patch loop excludes `*_de10_lite_to_basys3.patch` by
  name — that file is a record of the top-level rewrite, not a patch to apply to the pristine
  tree (unlike Pooyan's setup script, which hardcodes its one specific fix filename and never
  globs, this script globs `code/*.patch` but must skip the record-diff file).
- Constraints: `Basys-3-Master.xdc` (the stock Digilent master, not a machine-specific `.xdc`
  like Pooyan's); `btnC` and `JA[0:4]` are uncommented and given `PULLUP true` (matching
  Pooyan's convention), along with the already-active `sw`, `O_PMODAMP2_*`, and VGA pins.
- Run synthesis/implementation from `/tmp` so `vivado.log` / `vivado.jou` stay outside the repo.
- Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`; roms: `ROMZIP` → `~/roms/`.

## 10. Known limitation

Dip switches 1–8 confirmed working on hardware.

TODO: The 15 kHz bypass mode is wired into the scandoubler (`enable_scandoubling`) but hardcoded to
`'1'` (VGA output only) — no switch is wired to toggle it at runtime.
