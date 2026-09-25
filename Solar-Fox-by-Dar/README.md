# Solar-Fox-by-Dar (Basys 3 port)

Solar Fox (Bally Midway, 1981) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/solar_fox_basys3.xpr` (top entity
  `solar_fox_basys3`)
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
  btnC = reset, btnU = coin-in, btnL = 1P start/fast (root `PORTING_SPEC.md`'s
  generic default IO mapping; `btnD`/`btnR` are reserved/unused — the core
  has no second-coin or second-start facility). Hardware-confirmed
  2026-09-25: USB-HID keyboard, `btnU`/`btnL`, and JA all working. The
  keyboard runs on its own independent `clock_div_kbd` divider (`clock_40` /
  6 = 6.667 MHz), added 2026-09-25 to move onto the onboard USB-HID
  convention — the pre-existing `clock_div` counter (still used, unchanged,
  to gate the PWM accumulator) was too slow (~2 MHz) for the onboard host,
  and retargeting it directly would also have changed the audio rate.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire | Space |
| Coin | F1 |
| Fast | F2 |
| Separate audio (stereo/mono) | F5 |
| Service | F7 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Coin = Fire + Up together, or btnU; Fast = Fire + Left together, or btnL

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU | `btnU` | coin-in (coin1), OR-merged with keyboard F1 / JA fire+up |
| btnL | `btnL` | start/fast (fast1), OR-merged with keyboard F2 / JA fire+left |
| btnD / btnR | `btnD` / `btnR` | declared, unused (reserved — core has no 2nd coin/start) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (left channel; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz |
| LEDs | — | no `led` port (core never drives `ledr`) |

## Scripted setup

`contrib/tools/setup_solar_fox.sh` automates the manual steps below: it fetches
the Dar archive into the gitignored `dloads/` cache (reused when its SHA-256
matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_solar_fox_rev_0_1_2019_11_22/`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_solar_fox_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/solarfox.zip`) and generate the PROM VHDL. Run it via `make setup`.

## ROM set required

MAME ROM set `solarfox.zip`, unzipped into `tools/solar_fox_unzip/`:

```
~/roms/solarfox.zip   ->   tools/solar_fox_unzip/
```

Then run `./make_solar_fox_proms.sh` from that directory to generate the PROM
VHDL (`solar_fox_cpu.vhd`, `solar_fox_sound_cpu.vhd`, `solar_fox_bg_bits_1/2.vhd`,
`solar_fox_sp_bits.vhd`, `midssio_82s123.vhd`). Note the script concatenates
the individual chip ROMs (`sfcpu.*`, `sfsnd.*`, `sfvid.*`) into
`solar_fox_cpu.bin` / `solar_fox_sound_cpu.bin` / `solar_fox_sp_bits.bin`
before conversion, and `82s123.12d` is the same color PROM as Kick's. The
Vivado project references these generated files in place, so the build needs
only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25). Same pattern reported on Galaga-Midway-by-Dar,
  Kick-Midway-MCR-by-Dar, and Tron-by-Dar. Not yet investigated; deferred at
  the user's request. See root `KNOWN_ISSUES.md`.
