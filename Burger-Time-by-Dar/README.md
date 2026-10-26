# Burger-Time-by-Dar

Basys 3 port of BurgerTime (Data East, 1982), original core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_burger_time_rev_0_0_2017_12_27.zip` (rev 0.0,
27/12/2017), `dloads/`. Basys 3 port by Red~Bote; Dar's release notes: `README.txt` in the
extracted archive.

## Status

Hardware-verified 2026-10-20 (IO scheme of 2026-10-20, MAME keys): picture (31 kHz VGA),
sound, keyboard, JXADC joystick, buttons. Main CPU at 1.5 MHz hardware-confirmed
2026-10-02. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, composite
  sync on HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/pepper, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Main CPU at the MAME `btime` rate, 1.5 MHz (Dar's core: 750 kHz).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move (4-way) | arrows | pins 1-4 | |
| pepper | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. No joystick combos. No debounce. Keyboard decoded in the
wrapper (F0 = release, E0 ignored).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |

The DIP switches are constants inside the core (`burger_time.vhd:293-294`); not on board
switches.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` / `btnU` / `btnD` / `btnL` / `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:13) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 12.000 MHz (5 / 49.875 / 83.125), single domain; original 12.000 MHz crystal
(pixel 6 MHz, main CPU 1.5 MHz). Video H 31.25 kHz / V 59.87 Hz (261 lines). Details:
`contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`btime.zip` (MAME romset; `ROMZIP`, default `~/roms/btime.zip`), unzipped by
`prep_roms.sh` into `<SRC_DIR>/tools/burger_time_unzip/`; generates
`burger_time_prog.vhd`, `bg_map.vhd`, `bg_graphx_1/2/3.vhd`, `fg_sp_graphx_1/2/3.vhd`,
`burger_time_sound_prog.vhd`. Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
patch), `make check` (parse-only), `make bitstream`, `make load`. `make setup` verifies and
extracts `dloads/vhdl_burger_time_rev_0_0_2017_12_27.zip`, applies
`contrib/code/burger_time_cpu_1p5mhz.patch` and runs `contrib/tools/prep_roms.sh`.

## Known issues

None open.

## Issues addressed for Basys 3

- `rtl_dar/burger_time.vhd`: main CPU enable gives 750 kHz (`bnj` rate); MAME `btime` runs
  1.5 MHz. `contrib/code/burger_time_cpu_1p5mhz.patch` (2026-10-02, user decision).
- Scandoubler `ce_x1` from a second MMCM output failed hold timing (WHS -0.60 ns); replaced
  by a `clock_12` toggle enable, single MMCM output (2026-10-02).
- MiST `scandoubler.v`: unpacked array declared with a full range
  (`contrib/code/scandoubler_fix.patch`, applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v> | `contrib/code/` |
