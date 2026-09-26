# Burnin-Rubber-by-Dar (Basys 3 port)

Burnin' Rubber (Data East, 1982) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/burnin_rubber_basys3.xpr` (top entity
  `burnin_rubber_basys3`)
- Core clock: 12 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 12.000 MHz +
  `clk_out2` = 6.000 MHz; reset active-high (btnC), `locked` used. Solved
  MMCM: `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=7.5`, `CLKOUT0_DIVIDE_F=62.5`,
  `CLKOUT1_DIVIDE=125`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`). sw(13) switches to 15 kHz TV mode (native RGB
  + composite sync on HS).
- **Scan doubler source**: downloaded the first build from
  https://raw.githubusercontent.com/DECAfpga/Arcade_Galaga/main/mist/scandoubler.v and
  stashed in `dloads/`; the stashed copy is reused for subsequent builds.
- **Scan doubler wiring**: see `contrib/basys3/PORTING_SPEC.md`.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (OR-merged); buttons
  btnU/btnD = coin-in, btnL/btnR = start 1/2, btnC = reset. Hardware-confirmed
  2026-09-25: USB-HID keyboard and controls working.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire | Space |
| Coin | F3 |
| Start 1 | F1 |
| Start 2 | F2 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Coin = Fire + Up together; Start 1 = Fire + Left together
- Player 2 mirrors player 1 inputs.

Buttons (active-low, switch to GND):
- btnU = coin-in, btnD = coin-in
- btnL = start 1, btnR = start 2, btnC = reset

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnU / btnD | `btnU` / `btnD` | coin-in |
| btnL / btnR | `btnL` / `btnR` | start 1 / start 2 |
| btnC | `btnC` | reset (active-high) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | `sw(13)` | display mode: 0 = VGA, 1 = 15 kHz TV |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Known issues

- **Missing bottom horizontal rows (regression, reopened 2026-09-25)**: previously
  fixed 2026-09-23 via `contrib/code/burnin_rubber_vsync_before_vblank.patch`
  (`video_vs` was asserting 8 lines before `vblank`, so the last 8 active-picture
  lines were lost to vsync on a real VGA monitor), applied alongside
  `contrib/code/burnin_rubber_vcnt_272_lines.patch` (vertical line count,
  261 -> 272 per the original Bump&Jump schematics -- an independently-correct
  but not load-bearing fix, kept for schematic accuracy). Both patches still apply
  automatically via `make setup` and remain in place, but the symptom has recurred
  on the 2026-09-25 USB-HID-converted hardware build. Not yet re-investigated; the
  USB-HID change itself was XDC-only (no video/clocking code touched), so the
  recurrence is currently unexplained. See root `KNOWN_ISSUES.md` for the full
  investigation history.

## Scripted setup

`contrib/tools/setup_burnin_rubber.sh` automates the manual steps below: it
fetches the Dar archive into the gitignored `dloads/` cache (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_burnin_rubber_rev_0_0_2017_12_22/`, applies
`contrib/code/burnin_rubber_vcnt_272_lines.patch` and
`contrib/code/burnin_rubber_vsync_before_vblank.patch` (see Known issues
above), then runs `contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_burnin_rubber_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/brubber.zip`) and generate the PROM VHDL. Run it via `make setup`. The
MiST `scandoubler.v` (see Features above) is likewise fetched on first build and
stashed in `dloads/` for reuse.

## ROM set required

MAME ROM set `brubber.zip`, unzipped into `tools/burnin_rubber_unzip/`:

```
~/roms/brubber.zip   ->   tools/burnin_rubber_unzip/
```

Then run `./make_burnin_rubber_proms.sh` from that directory to generate the
PROM VHDL (`burnin_rubber_prog.vhd`, `bg_graphx_1/2.vhd`,
`fg_sp_graphx_1/2/3.vhd`, `burnin_rubber_sound_prog.vhd`). The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Build status

The port is fully scripted and has been verified to reproduce a Vivado project that opens
cleanly (correct top entity, part, and source list; 21 sources + 1 constraints file) end-to-end
from the tracked assets alone. `check_syntax` (HDL parse only, no synthesis) passes with no
errors — only benign warnings in the untouched canonical `scandoubler.v` import and info-level
notes on the `clk_wiz_0` IP instantiation.

Hardware bring-up is complete: a bitstream has been built and the port runs correctly on the
Basys 3 board.

