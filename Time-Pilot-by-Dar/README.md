# Time-Pilot-by-Dar (Basys 3 port)

Time Pilot (Konami, 1982) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/time_pilot_basys3.xpr` (top entity
  `time_pilot_basys3`)
- Clock: single domain (2026-10-05): `clk_wiz_0` single output `clk_core` =
  24.573991 MHz (`DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=34.25`,
  `CLKOUT0_DIVIDE_F=27.875`) from the 100 MHz oscillator; the former 12.288 /
  6.144 MHz and 14.318 MHz sound clocks are clock enables
  (`contrib/code/time_pilot_single_domain.patch`; design in
  `contrib/basys3/PORTING_SPEC.md` section 2). MMCM reset on btnC, core reset
  `btnC or not mmcm_locked`, released synchronously.
- Frame: 263 lines, 60.84 Hz (`contrib/code/time_pilot_vcnt_263_lines.patch`,
  2026-10-01): pristine reload `0x0FC` gave 260 lines / 61.54 Hz, outside the
  VGA window; 263 lines (`0x0F9`) is the choice Dar made in his later Pooyan
  core for the same hardware family. See `../CLOCKING_SPEC.md` 5.7.

## Features supported

- **Video**: 31 kHz progressive VGA via the MiST scandoubler (same as Pooyan,
  2026-10-05; replaces the DECA `vga_scandoubler`). sw(13) switches to 15 kHz
  TV mode (native RGB + composite sync on HS).
- **Scan doubler source**: MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>;
  tracked as `contrib/code/scandoubler.v`, copied into the project by
  `create_project.sh`.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard + JA joystick (OR-merged), btnC = reset.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire | Space |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Coin/start: keyboard and btnU/btnL/btnR (JA fire+direction combos removed 2026-10-02)
- Player 2 mirrors player 1 movement/fire inputs.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnL / btnR | `btnU`/`btnL`/`btnR` | coin / 1P start / 2P start (OR-merged with keyboard; added 2026-10-01) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | display mux | display: 0 = 31 kHz VGA, 1 = 15 kHz TV (csync on HS, VS high) |
| sw(7:0) | `dip_switch_2` | Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1) |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz |
| LEDs | `led(15:0)` | present |

## ROM set required

MAME ROM set `timeplt.zip`, unzipped into `tools/time_pilot_unzip/`:

```
~/roms/timeplt.zip   ->   tools/time_pilot_unzip/
```

`contrib/tools/prep_roms.sh` handles the Linux rom-prep: it compiles `make_vhdl_prom`,
converts `make_time_pilot_proms.bat` → `make_time_pilot_proms.sh`, unzips `timeplt.zip`, and
runs the generator to produce the PROM VHDL (`time_pilot_prog.vhd`,
`time_pilot_sound_prog.vhd`, `time_pilot_char_grphx.vhd`,
`time_pilot_sprite_grphx.vhd`, `time_pilot_palette_blue_green.vhd`,
`time_pilot_palette_green_red.vhd`, `time_pilot_char_color_lut.vhd`,
`time_pilot_sprite_color_lut.vhd`). The Vivado project references these generated files in
place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Build / setup

From the `Time-Pilot-by-Dar/` directory, `make` wraps the scripted setup:

- `make setup` — `contrib/tools/setup_time_pilot.sh`: download + extract the Dar source
  archive, apply any synthesis-fix patches, then chain into the rom-prep.
- `make clk_wiz` — `contrib/basys3/vivado/make_clk_wiz_0.sh`: generate the `clk_wiz_0` MMCM
  IP (single 24.576 MHz request, solve above).
- `make patch` — `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`: author
  `time_pilot_basys3.vhd` and its record patch `contrib/basys3/code/
  time_pilot_de10_lite_to_basys3.patch`.
- `make all` — setup + clk_wiz + patch.
- `make synth` — run synthesis (`contrib/basys3/tools/make_time_pilot_basys3_bitstream.sh synth`).
- `make bitstream` — implementation + write_bitstream (depends on `synth`).
- `make clean` — remove the extracted `vhdl_time_pilot_rev_0_0_2017_11_05/` tree.

`contrib/basys3/vivado/create_project.sh` lays down the initial project tree: it creates
`basys3/` in the extracted source, copies `time_pilot_basys3.xpr` (which references the local
scandoubler import directly), `Basys-3-Master.xdc`, and `scandoubler.v` (then applies
`contrib/code/scandoubler_fix.patch` to the copy). Run it once after
`make setup`, before `make synth`/`make bitstream`.

The port is complete and hardware-verified: video, audio, PS/2 keyboard, JA joystick, and
reset all confirmed working on a physical Basys 3. See `PORTING_SPEC.md`.

## Notes

- Dip switches 1–8 confirmed working on hardware.
- 15 kHz TV mode wired to `sw(13)` 2026-10-02 (hardware-confirmed).
