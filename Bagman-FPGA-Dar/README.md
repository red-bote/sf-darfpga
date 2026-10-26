# Bagman-FPGA-Dar

Basys 3 port of Bagman (Valadon Automation / Stern, 1982), original core by Dar
(darfpga@aol.fr), <http://darfpga.blogspot.fr>. Source:
`vhdl_bagman_rev_0_1_2018_06_05.zip` (rev 0.1, 05/06/2018), `dloads/`. Basys 3 port by
Red~Bote; Dar's release notes: `README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20 (IO scheme of 2026-10-20, MAME keys): picture (31 kHz VGA),
sound, keyboard, JXADC joystick, buttons. USB-HID keyboard first confirmed 2026-09-25.
Open items: none.

## Features (Basys 3)

- Video: 31 kHz progressive VGA, scan doubling built into the core
  (`rtl_dar/line_doubler.vhd`); sw13 up = 15 kHz TV (native rate, composite sync on HS,
  VS high; needs a 15 kHz monitor or RGB-to-composite converter).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/jump, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono; AY-3-8910 and TMS5110-style speech.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| jump | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. No joystick combos (coin/start combos removed 2026-10-02). No
debounce. Keyboard decoded in the wrapper (F0 = release, E0 ignored, keypad 8/2/4/6 alias
the arrows).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |

The DIP switches are a constant inside the core (`bagman.vhd:288`, `not("00110001")`);
not on board switches (would need a core patch).

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` / `btnU` / `btnD` / `btnL` / `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:13) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 12.288 MHz (5 / 48 / 78.125, VCO 960 MHz), single domain; original 18.432 MHz
crystal (CPU 3.072 MHz, pixel 6.144 MHz, AY 1.536 MHz). Video H 32.000 kHz / V 60.61 Hz.
Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`bagman.zip` (MAME romset; `ROMZIP`, default `~/roms/bagman.zip`), unzipped by
`prep_roms.sh` into `<SRC_DIR>/tools/bagman_unzip/`; generates `bagman_program.vhd`,
`bagman_tile_bit0/1.vhd`, `bagman_palette.vhd`, `bagman_speech1/2.vhd`. Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
patch), `make check` (parse-only), `make bitstream`, `make load`. `make setup` verifies and
extracts `dloads/vhdl_bagman_rev_0_1_2018_06_05.zip`, applies
`contrib/code/bagman_xor_width.patch` and runs `contrib/tools/prep_roms.sh`.

## Known issues

None open. `make check` shows a pre-existing HDL 9-3240 CRITICAL WARNING inside Dar's core
(`bagman.vhd`, `bagman_speech.vhd`); left as is.

## Issues addressed for Basys 3

- `rtl_dar/bagman.vhd`: four `tile_graph_rom_addr` XOR literals are narrower than the left
  operand; Vivado rejects the width mismatch. `contrib/code/bagman_xor_width.patch`
  left-pads them to 13 bits (`xor "0000000000000"`, `"0000000001000"`, `"0000000010111"`,
  `"0000000011111"`). Verify: `grep -n 'xor "0000000000000"'
  vhdl_bagman_rev_0_1_2018_06_05/rtl_dar/bagman.vhd`.

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
