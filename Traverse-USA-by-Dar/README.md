# Traverse-USA-by-Dar

Basys 3 port of Traverse USA / Zippy Race (Irem M-52, 1983), original core by Dar
(darfpga@aol.fr), <http://darfpga.blogspot.fr>. Source:
`vhdl_traverse_usa_rev_0_0_2019_03_16.zip` (2019-03-16), `dloads/`. Basys 3 port by
Red~Bote. Dar's release notes: `README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA), sound, keyboard (MAME keys), JXADC
joystick, buttons. Keyboard on `clock_36`, JXADC up unbound and DIP switches
hardware-verified 2026-10-21. Synthesizes with 0 errors, 0 critical warnings.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, composite
  sync on HS). The pristine core drives only composite sync;
  `traverse_usa_expose_video_timing.patch` enables its dormant `video_hs`/`video_vs`
  (PORTING_SPEC §5).
- Keyboard: onboard USB-HID port (plug into the board's USB-A port; JB and external PS/2
  are not used), MAME default keys, decoded in the wrapper (2026-10-20, replaces
  `kbd_joystick`; F0 = release, E0 ignored; `../PORTING_SPEC.md` §3.1).
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/7 = right/left/brake/accelerate, active
  low, pull-ups in the XDC. The core has no fire input; fire drives accelerate.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono (left channel).
- DIP switches on sw7-0 and sw11-8 (2026-10-20).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| steer left / right | Left / Right arrows | pin 2 / pin 1 | |
| accelerate | Left Ctrl | pin 7 (fire) | |
| brake | Left Alt | pin 3 (down) | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1 (the core has only cocktail-mode duplicates). JXADC pin 4 (up)
is unused (accelerate removed from it 2026-10-20). Down+fire asserts brake and accelerate.
No coin/start combos.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw11-8 | `dip_switch_1` bits 3-0: Cont. play(3) / Fuel consumption(2) / Fuel lost when collision(1-0) | Dar `x"FF"` | bit inverted |
| sw7-0 | `dip_switch_2`: Diag(7) / Demo(6) / Zippy(5) / Freeze(4) / M-Km(3) / Coin mode(2) / Cocktail(1) / Flip(0) | Dar `x"FE"` | bit inverted |

Coinage_B (`dip_switch_1` bits 7-4) fixed; sw12 spare.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` ... `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `_GAIN` / `_SHUTD` | audio |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: `clk_out1` 36.842105 MHz (`clock_36`, core) and `clk_out2` 7.159091 MHz,
divided by 2 in fabric to 3.5795454 MHz (`clock_3p58`, sound board and PWM); D 1 / M 7.875
/ O0 21.375 / O1 110. Video 31.98 kHz / 56.70 Hz. Original 18.432 MHz main crystal.
Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`travrusa.zip` (MAME romset; `ROMZIP`, default `~/roms/travrusa.zip`). Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
clk_wiz, patch), `make check` (parse-only), `make bitstream`, `make load`.

## Known issues

- Sound clocks and the scandoubler `clk_sys` are separate, partly register-derived
  domains (`../KNOWN_ISSUES.md`); no hardware symptom.

## Issues addressed for Basys 3

- `rtl_dar/traverse_usa.vhd`: `video_hs`/`video_vs` drivers commented out; enabled by
  `contrib/code/traverse_usa_expose_video_timing.patch` (`video_hs <= hsync0`, `video_vs`
  from `vsync_cnt`).
- USB-HID keyboard read nothing with the pristine ~3 MHz keyboard clock; fixed with a
  ~6.14 MHz `clock_kbd`, moved to the core clock `clock_36` on 2026-10-20.
- MiST `scandoubler.v`: unpacked array declared with a full range; Vivado rejects the
  single-value size (`contrib/code/scandoubler_fix.patch`, applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v> | `contrib/code/` |
