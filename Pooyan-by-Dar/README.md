# Pooyan-by-Dar

Basys 3 port of Pooyan (Konami, 1982), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_pooyan_rev_0_2_2020_04_26.zip` (rev 0.2,
2020-04-26), <https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/>,
`dloads/`. Upstream release notes: `vhdl_pooyan_rev_0_2_2020_04_26/README.txt`.

Reference model for new ports (`../PORTING_SPEC.md`).

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA via MiST scandoubler, 15 kHz TV on sw13),
sound, keyboard (MAME keys), JXADC joystick, buttons. DIP switches (sw7-0 dip 2, sw11-8
Coinage A) hardware-verified 2026-10-21. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, csync on
  HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Single clock domain (24.574 MHz); all former clocks are clock enables.
- Frame 264 lines, 60.61 Hz, per MAME `konami/pooyan.cpp`.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| fire | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. No combos, no debounce (PS/2, JXADC and buttons pass 2-FF
synchronizers).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw11-8 | dip 1 Coinage A (bits 3-0) | Dar default `X"F"` (1 coin 1 credit) | inverts the bit |
| sw7-0 | dip 2: sound (7), difficulty (6-4), bonus (3), cocktail (2), lives (1-0) | bit = 0 | bit = 1 |

Dip 2 is wired directly (`sw(7 downto 0)`, all down = `x"00"`; Dar's DE10 constant is
`X"7F"`), hardware-verified. Coinage B (dip 1 bits 7-4) is fixed at `X"F"`.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC`, `btnU`, `btnD`, `btnL`, `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

XDC: `contrib/basys3/vivado/pooyan_basys3.xdc`.

## Clocking

`clk_wiz_0`: 24.573991 MHz (D 5 / M 34.25 / O 27.875), single domain, `clk_core` = 2 ×
12.288 MHz; original 18.432 MHz crystal (pixel 6.144 MHz). Pixel enable 6.1435 MHz, VGA H
31.997 kHz, V 60.61 Hz (264 lines). The 14.318 MHz sound rate is a phase-accumulator
enable. Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`pooyan.zip` (MAME romset; `ROMZIP`, default `~/roms/pooyan.zip`). Not included.
`prep_roms.sh` unzips it into `vhdl_pooyan_rev_0_2_2020_04_26/tools/pooyan_unzip/` and
generates the PROM VHDL (`pooyan_prog`, `pooyan_sound_prog`, `pooyan_char_grphx1/2`,
`pooyan_sprite_grphx1/2`, `pooyan_palette`, `pooyan_char_color_lut`,
`pooyan_sprite_color_lut`).
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2 (`VIVADO` overrides the path), openFPGALoader.
`make help`; `make` (setup, create_prj, clk_wiz, patch), `make check` (parse-only),
`make bitstream`, `make load`. The project is
`vhdl_pooyan_rev_0_2_2020_04_26/basys3/pooyan_basys3.xpr` (top `pooyan_basys3`, part
`xc7a35tcpg236-1`); the bitstream is
`vhdl_pooyan_rev_0_2_2020_04_26/basys3/pooyan_basys3.runs/impl_1/pooyan_basys3.bit`.
Vivado runs from `/tmp`.

## Known issues

None open. Intermittent VGA sync failure after reset (2026-09-25 / 2026-10-01) fixed by the
single-domain change, hardware-confirmed 2026-10-05 (`../KNOWN_ISSUES.md`).

## Issues addressed for Basys 3

- `rtl_t80_350/T80.vhd`: operand widths of a logical `&` differ, Vivado rejects it
  (`contrib/basys3/code/pooyan_t80_xor_width.patch`).
- `rtl_dar/pooyan.vhd`, `pooyan_sound_board.vhd`, `gen_ram.vhd`: single clock domain with
  clock enables (`contrib/basys3/code/pooyan_single_domain.patch`, CRLF, `--binary`).
- `rtl_dar/pooyan.vhd`: 264 lines per frame, V 60.61 Hz, per MAME
  (`contrib/basys3/code/pooyan_vcnt_264_lines.patch`).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/pooyan_basys3.xdc` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
