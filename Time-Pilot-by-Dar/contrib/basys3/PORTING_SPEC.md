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
  - `clk_wiz_0` MMCM IP, MiST `scandoubler.v`, generated PROM VHDL from
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

- Single clock domain (2026-10-05; rule `.opencode/rules.md` §"Clocking (Basys3 ports)"):
  one MMCM output `clk_core` = 24.573991 MHz (D 5 / M 34.25 / O0 27.875; pixel 6.1435 MHz,
  VGA H 31.997 kHz). The former `clock_12`, `clock_6`, `clock_6n`, `clock_12n`, `clock_14`,
  `clock_14n`, sound `cpu_clock` and `ayx_clock` are clock enables; the same design as
  Pooyan, recorded in `../../Pooyan-by-Dar/contrib/basys3/PORTING_SPEC.md` section 2
  (enable table, ROM address-hold mux, `gen_ram` `ce` port, 20-bit 14.318181 MHz phase
  accumulator). Reason: VGA failed to sync on about half of the btnC resets; the
  register-derived clocks left the core-to-scandoubler path untimed (`../../KNOWN_ISSUES.md`).
- Time-Pilot differences: T80se (v247) `CLK_n = clk_core`, `CLKEN = cpu_ena and ce6` (main),
  `CLKEN = cpu_ce` (sound); all T80se state, including `T80_RegX` `RAM16X1D` WE and the NMI
  edge detect, is CLKEN-gated. Six PROMs on the former `clock_6` (char, char palette, sprite,
  sprite palette, two RGB palettes) use the address-hold mux.
- Patch `contrib/code/time_pilot_single_domain.patch` (`rtl_dar/time_pilot.vhd`,
  `time_pilot_sound_board.vhd`, `gen_ram.vhd`; CRLF, `setup_time_pilot.sh --binary`); it sorts
  and applies before the 263-line patch, both verified in that order.
- Reset: `btnC or not mmcm_locked`, released synchronously to `clk_core`; MMCM reset = btnC.
- Core patch `contrib/code/time_pilot_vcnt_263_lines.patch` (2026-10-01): `vcnt` reload `0x0FC` -> `0x0F9`, 263 lines, V 60.84 Hz (was 61.54 Hz); same as Dar's later Pooyan core. `../../CLOCKING_SPEC.md` 5.7.

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

- MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>, tracked as
  `contrib/code/scandoubler.v` with `contrib/code/scandoubler_fix.patch`; `clk_sys =
  clk_core`, `ce_x1 = ce6`, `ce_x2 = ce12`. Replaces the two-clock DECA `vga_scandoubler.v`
  (2026-10-05).
- The DE10-lite top leaves the core's `video_hs`/`video_vs` outputs unconnected (`open`,
  labeled "not tested"), even though `time_pilot.vhd` does drive them. The Basys3 top wires
  them to the scandoubler's `hs_in`/`vs_in` (Pooyan pattern) instead of leaving them
  open; confirmed correct on hardware.
- Time Pilot's core outputs 5 bits/color; the top pads each with 1 bit (`r & "0"`, etc.) to
  reach the scandoubler's 6-bit inputs, then narrows the doubled 6-bit output back to
  4 bits/color (`vga_ro(5 downto 2)`, etc.) — same narrowing convention as Pooyan.
- The tracked `.xpr` references the local import (`sources_1/imports/mist/scandoubler.v`)
  directly.

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
  start 2P. Keyboard on `clk_core`; JA and buttons pass a 2-FF synchronizer.
  PS/2 `ps2_clk`/`ps2_dat` also pass the 2-FF synchronizer. Evaluation 2026-10-05 (user):
  with raw PS/2 at 24.57 MHz the Time-Pilot keyboard misbehaved and Pooyan showed no fault;
  the synchronizer was re-instated on both.
- JA joystick, active-low (switch to GND): `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`.
  Invert (`not JA`) to active-high to match the core boundary (Pooyan pattern).
- Coin = keyboard OR `btnU`; Start 1 = keyboard OR `btnL`; Start 2 = keyboard OR `btnR`.
  No JA fire+direction combos (removed 2026-10-02).
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
  `.xpr` directly in `basys3/`, unlike Pooyan's nested `pooyan_basys3/` layout) and copies the
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

15 kHz TV mode: `sw(13)` = 1 selects native RGB (gated on `blankn`), `csync` on HS, VS high,
muxed in the wrapper (fleet convention; wired 2026-10-02 via the DECA bypass, moved to the
wrapper mux with the MiST scandoubler 2026-10-05).
