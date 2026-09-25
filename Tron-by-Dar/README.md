# Tron-by-Dar (Basys 3 port)

Tron (Midway MCR, 1982) by Dar (`darfpga@aol.fr`, http://darfpga.blogspot.fr). Basys 3
(Artix-7) port. See `README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/tron_basys3.xpr` (top entity `tron_basys3`)
- Core clock: 40 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`) — a single clock
  driving both the core and sound board, unlike the dual-clock Pooyan/Time-Pilot cores.
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 40.000 MHz; solved MMCM:
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.000`, `CLKOUT0_DIVIDE_F=25.000`.

## Features supported

- **Video**: dual-mode — 31 kHz progressive VGA *or* 15 kHz TV, generated **natively by the
  core** (no external scandoubler, unlike Pooyan/Time-Pilot). **F8** toggles between them.
- **Sound**: stereo PWM audio in the core; PmodAMP2 is mono, so only the left channel is
  output (same choice as the sibling Kick port). **F5** toggles separate (stereo) audio mode.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (OR-merged) for
  movement/fire/coin/start, btnC = reset. Hardware-confirmed 2026-09-25: USB-HID
  keyboard working. The spinner (rotate) control is keyboard-only —
  see below. The keyboard runs on its own independent `clock_div_kbd` divider
  (`clock_40` / 6 = 6.667 MHz), added 2026-09-25 to move onto the onboard USB-HID
  convention — the pre-existing `clock_div` counter (still used, unchanged, to gate the
  PWM accumulator) was too slow (~2 MHz) for the onboard host, and retargeting it
  directly would also have changed the audio rate.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire | Space |
| Spin left / right | f / g |
| Spin fast | t (held) |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |
| Service mode | F5 |
| Continue after game over | F6 |
| Video mode (31 kHz VGA / 15 kHz TV) | F8 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Coin = Fire + Up; Start 1 = Fire + Left; Start 2 = Fire + Right
- No JA equivalent for the spinner (see `contrib/basys3/PORTING_SPEC.md` §7) — same limitation as the
  pristine DE10-lite top, not a porting regression.
- No player-2/cocktail support — the core has no genuine second control set, only unused
  cocktail-mode duplicates, matching upstream ("Cocktail mode: NO").

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13:0) | — | unused (the core exposes no dip switches) |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (left channel; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, dual-mode 31 kHz / 15 kHz |

## ROM set required

MAME ROM set `tron.zip`, plus `kick.zip` for the shared Midway color PROM (`tron.zip` does not
carry it), unzipped into `tools/tron_unzip/`:

```
~/roms/tron.zip   ->   tools/tron_unzip/
~/roms/kick.zip   ->   tools/tron_unzip/82s123.12d only (renamed to midssio_82s123.12d)
```

`contrib/tools/prep_roms.sh` handles the Linux rom-prep: it compiles `make_vhdl_prom`,
converts `make_tron_proms.bat` → `make_tron_proms.sh`, unzips `tron.zip`, pulls `82s123.12d`
out of `kick.zip` and renames it to `midssio_82s123.12d` (same color PROM the sibling Kick
port copies out of its own romset), and runs the generator to produce the PROM VHDL:
`tron_cpu.vhd`, `tron_sound_cpu.vhd`, `tron_bg_bits_1.vhd`, `tron_bg_bits_2.vhd`,
`tron_sp_bits.vhd`, `midssio_82s123.vhd`. The Vivado project references these generated files
in place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Build / setup

From the `Tron-by-Dar/` directory, `make` wraps the scripted setup:

- `make setup` — `contrib/tools/setup_tron.sh`: download + extract the Dar source archive,
  apply any synthesis-fix patches, then chain into the rom-prep.
- `make create_prj` — `contrib/basys3/vivado/create_project.sh`: lay down the initial project
  tree (flat, non-nested: `.xpr` directly in `basys3/`), copy `tron_basys3.xpr` and
  `Basys-3-Master.xdc` into place. No scandoubler import (the core generates video natively).
- `make clk_wiz` — `contrib/basys3/vivado/make_clk_wiz_0.sh`: generate the `clk_wiz_0` MMCM
  IP (40.000 MHz from 100 MHz).
- `make patch` — `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`: author
  `tron_basys3.vhd` and its record patch
  `contrib/basys3/code/tron_de10_lite_to_basys3.patch`.
- `make all` — setup + clk_wiz + patch.
- `make synth` — run synthesis (`contrib/basys3/tools/make_tron_basys3_bitstream.sh synth`).
- `make bitstream` — implementation + write_bitstream (depends on `synth`).
- `make clean` — remove the extracted `vhdl_tron_rev_0_3_2019_11_22/` tree.

The port is fully scripted and hardware-verified: the Vivado project opens cleanly (correct
top entity, part, and source list) end-to-end from the tracked assets alone, and `make synth` /
`make bitstream` complete with the generated bitstream confirmed working on a Basys 3.

## TODO

- Consider a JA-driven approximation for the spinner control (currently keyboard-only,
  matching upstream).

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25). Same pattern reported on Solar-Fox-by-Dar,
  Galaga-Midway-by-Dar, and Kick-Midway-MCR-by-Dar. Not yet investigated;
  deferred at the user's request. See root `KNOWN_ISSUES.md`.
