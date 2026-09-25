# Kick-Midway-MCR-by-Dar (Basys 3 port)

Kick (Midway MCR, 1981) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/kick_basys3.xpr` (top entity
  `kick_basys3`)
- Core clock: 40 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 40.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=1`,
  `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`.

## Features supported

- **Video**: 31 kHz progressive VGA (scan doubling built into the core);
  **F8** toggles 31 kHz VGA / 15 kHz TV.
- **Sound**: stereo L/R PWM audio path in the core; PmodAMP2 `AIN` is driven
  from the left channel. **F5** toggles separate (stereo) audio mode, **F7**
  toggles service mode.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (OR-merged),
  btnC = reset. Hardware-confirmed 2026-09-25: USB-HID keyboard, btn, and JA
  inputs all working (F8 needed to switch to VGA mode).
  The keyboard runs on its own independent `clock_div_kbd` divider
  (`clock_40` / 6 = 6.667 MHz), added 2026-09-25 to move onto the onboard
  USB-HID convention -- the pre-existing `clock_div` counter (still used,
  unchanged, to gate the PWM accumulator) was too slow (~2 MHz) for the
  onboard host, and retargeting it directly would also have changed the
  audio rate.

| Input | Keyboard |
|-------|----------|
| Kick | Up arrow |
| Spin left / right | Left / Right arrow |
| Speed up | Space |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |
| Separate audio (stereo/mono) | F5 |
| Service | F7 |

JA joystick (active-low, switch to GND):
- JA1 = Spin right, JA2 = Spin left, JA3 = Down, JA4 = Up (kick), JA7 = Fire (speed up)
- Coin / Start come from the default buttons (btnU/btnL/btnR) or keyboard F1/F2/F3.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU | `btnU` | coin-in (coin1), OR-merged with keyboard F1 |
| btnD | `btnD` | second coin-in (coin2), sole source (no keyboard/JA path) |
| btnL | `btnL` | P1 start, OR-merged with keyboard F2 |
| btnR | `btnR` | P2 start, OR-merged with keyboard F3 |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (left channel; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz |
| LEDs | — | unused/reserved (no `led` port on `kick_basys3`) |

## Scripted setup

`contrib/tools/setup_kick.sh` automates the manual steps below: it fetches the
Dar archive into the gitignored `dloads/` cache (reused when its SHA-256 matches
the hash embedded in the script; re-downloaded when missing or tampered),
extracts it as `vhdl_kick_rev_0_2_2019_11_22/`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_kick_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/kick.zip`) and generate the PROM VHDL. Run it via `make setup`.

## ROM set required

MAME ROM set `kick.zip`, unzipped into `tools/kick_unzip/`:

```
~/roms/kick.zip   ->   tools/kick_unzip/
```

Then run `./make_kick_proms.sh` from that directory to generate the PROM VHDL
(`kick_cpu.vhd`, `kick_sound_cpu.vhd`, `kick_bg_bits_1/2.vhd`,
`kick_sp_bits.vhd`, `midssio_82s123.vhd`). Note the script concatenates the
individual chip ROMs (`1200a`-`1900h`, etc.) into `kick_cpu.bin` /
`kick_sound_cpu.bin` / `kick_sp_bits.bin` before conversion. The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25). Same pattern reported on Solar-Fox-by-Dar,
  Galaga-Midway-by-Dar, and Tron-by-Dar. Not yet investigated; deferred at
  the user's request. See root `KNOWN_ISSUES.md`.
