# Berzerk-FPGA-by-Dar

Basys 3 port of Berzerk (Stern, 1980), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_berzerk_rev_0_1_2018_08_08.zip` (rev 0.1,
08/08/2018), `dloads/`. Basys 3 port by Red~Bote; Dar's release notes: `README.txt` in the
extracted archive.

## Status

Hardware-verified 2026-10-20 (IO scheme of 2026-10-20, MAME keys): picture (31 kHz VGA),
sound, keyboard, JXADC joystick, buttons. sw12 cocktail DIP added 2026-10-20 (hardware check
2026-10-21; which switch position means upright is not individually confirmed). USB-HID
keyboard first confirmed 2026-09-25.

## Features (Basys 3)

- Video: 31 kHz progressive VGA, scan doubling built into the core
  (`rtl_dar/line_doubler.vhd`); sw13 up = 15 kHz TV (native rate, composite sync on HS,
  VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono; sound effects and S14001A-style speech.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| fire | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. No joystick combos (coin/start not reachable from the
joystick). No debounce. Keyboard decoded in the wrapper (F0 = release, E0 ignored).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw12 | `cocktail` | Dar `'1'` | `'0'` (inverted inside the core; upright level not verified) |

Other DIP banks (F2-F6) are constants inside the core (`berzerk.vhd:391-399`); not on
board switches.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` / `btnU` / `btnD` / `btnL` / `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:12) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 10.000 MHz (2 / 15.625 / 78.125), single domain; original 10.000 MHz crystal
(Z80 2.5 MHz, pixel 5 MHz). Video H 31.25 kHz / V 59.64 Hz. Details:
`contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`berzerk.zip` (MAME romset; `ROMZIP`, default `~/roms/berzerk.zip`), unzipped by
`prep_roms.sh` into `<SRC_DIR>/tools/berzerk_unzip/` and renamed to the names Dar's
`make_berzerk_proms.bat` expects:

| `berzerk.zip` file | `.bat` name | role |
|---|---|---|
| `1c-0` | `berzerk_rc31_1c.rom0.1c` | program rom0 |
| `1d-1` | `berzerk_rc31_1d.rom1.1d` | program rom1 |
| `3d-2` | `berzerk_rc31_3d.rom2.3d` | program rom2 |
| `5d-3` | `berzerk_rc31_5d.rom3.5d` | program rom3 |
| `6d-4` | `berzerk_rc31_6d.rom4.6d` | program rom4 |
| `5c-5` | `berzerk_rc31_5c.rom5.5c` | program rom5 |
| `1c` | `berzerk_r_vo_1c.1c` | voice rom1 |
| `2c` | `berzerk_r_vo_2c.2c` | voice rom2 |

Generates `berzerk_program1/2.vhd`, `berzerk_speech_rom.vhd`. Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
patch), `make check` (parse-only), `make bitstream`, `make load`. `make setup` verifies and
extracts `dloads/vhdl_berzerk_rev_0_1_2018_08_08.zip`, applies
`contrib/code/berzerk_reset_sensitivity.patch` and runs `contrib/tools/prep_roms.sh`.

## Known issues

None open.

## Issues addressed for Basys 3

- `rtl_dar/berzerk.vhd`: a process sensitivity list omits `reset`.
  `contrib/code/berzerk_reset_sensitivity.patch` adds it
  (`process (clock_10, cpu_iorq_n, cpu_addr, reset)`). Verify:
  `grep -n "cpu_iorq_n, cpu_addr, reset" vhdl_berzerk_rev_0_1_2018_08_08/rtl_dar/berzerk.vhd`.

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
