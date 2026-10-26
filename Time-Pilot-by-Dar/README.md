# Time-Pilot-by-Dar

Basys 3 port of Time Pilot (Konami, 1982), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_time_pilot_rev_0_0_2017_11_05.zip`
(2017-11-05), `dloads/`. Basys 3 port by Red~Bote. Dar's release notes: `README.txt` in the
extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA), sound, keyboard (MAME keys), JXADC
joystick, buttons, DIP switches (sw7-0 confirmed 2026-10-02; sw11-8 Coinage A 2026-10-21).
15 kHz TV (sw13) hardware-confirmed 2026-10-02.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler (as Pooyan); sw13 up = 15 kHz TV (native
  RGB, composite sync on HS).
- Keyboard: onboard USB-HID port, MAME default keys, decoded in the wrapper (2026-10-20,
  replaces `kbd_joystick`; F0 = release, E0 ignored; `../PORTING_SPEC.md` §3.1).
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Single clock domain (2026-10-05); 264-line frame, 60.61 Hz (2026-10-06).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| fire | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1 movement/fire. No joystick combos (coin/start combos removed
2026-10-02).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw11-8 | `dip_switch_1` bits 3-0, Coinage A | Dar `X"FF"` | bit inverted |
| sw7-0 | `dip_switch_2`: Sound(8) / Difficulty(7-5) / Bonus(4) / Cocktail(3) / Lives(2-1) | `0` | `1` (direct, not inverted; Dar's DE10 constant was `X"4F"`) |

Coinage B (`dip_switch_1` bits 7-4) fixed at Dar's value.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` ... `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `_GAIN` / `_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 24.573991 MHz (5 / 34.25 / 27.875), single domain `clk_core`; the former
12.288 / 6.144 MHz and 14.318 MHz sound clocks are clock enables
(`contrib/code/time_pilot_single_domain.patch`). Pixel 6.1435 MHz; 264 lines
(`contrib/code/time_pilot_vcnt_264_lines.patch`, reload `0x0F8`, per MAME `konami/pooyan.cpp`
`set_raw`; pristine 260 lines / 61.54 Hz) → VGA 31.997 kHz / 60.61 Hz. Details:
`contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`, `../CLOCKING_SPEC.md`
5.7.

## Required ROMs

`timeplt.zip` (MAME romset; `ROMZIP`, default `~/roms/timeplt.zip`). Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
clk_wiz, patch), `make check` (parse-only), `make bitstream`, `make load`.

## Known issues

None open.

## Issues addressed for Basys 3

- VGA failed to sync on about half of the btnC resets: register-derived clocks left the
  core-to-scandoubler path untimed. Single clock domain with enables
  (`contrib/code/time_pilot_single_domain.patch`, 2026-10-05; `../KNOWN_ISSUES.md`).
- 260-line frame (61.54 Hz) → 264 lines, 60.61 Hz
  (`contrib/code/time_pilot_vcnt_264_lines.patch`, 2026-10-06).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).
- Raw PS/2 at 24.57 MHz misbehaved (2026-10-05); 2-FF synchronizer on `ps2_clk`/`ps2_dat`.

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
