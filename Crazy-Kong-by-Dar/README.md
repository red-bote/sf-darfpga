# Crazy-Kong-by-Dar

Basys 3 port of Crazy Kong (Crazy Climber hardware, Kyoei/Falcon, 1981; per MAME
`cclimber.cpp` and Dar's `README.txt` the core plays Crazy Kong Part II / Falcon),
FPGA core by Dar (darfpga@aol.fr), <http://darfpga.blogspot.fr>. Source:
`vhdl_ckong_rev_0_1_2018_06_06.zip` (rev 0.1, 06/06/2018), `dloads/`. Basys 3 port by
Red~Bote; Dar's release notes: `README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20 (IO scheme of 2026-10-20, MAME keys): picture (31 kHz VGA),
sound, keyboard, JXADC joystick, buttons. First bitstream 2026-09-07 (0 critical
warnings/errors through implementation, post-route WNS 36.461 ns). Open items: none.

## Features (Basys 3)

- Video: native 31 kHz progressive VGA from the core's own `line_doubler` (no external
  scandoubler); sw13 up = 15 kHz TV (native RGB, composite sync on HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/jump, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono (YM2149 and samples).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move (4-way) | arrows | pins 1-4 | |
| jump | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1 (the core has only cocktail-mode duplicates). No joystick combos.
No debounce. Keyboard decoded in the wrapper (F0 = release, E0 ignored). Dar's
`kbd_joystick` extra fire keys (Ctrl / W, bits 8/9) were never used by the merge and are
not decoded.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |

The DIP byte is a constant inside the core (`ckong.vhd:295`, `"10000000"`, upright
cabinet); not on board switches.

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

`clk_wiz_0`: 12.288 MHz (5 / 48 / 78.125, VCO 960 MHz), single domain; original
18.432 MHz crystal × 2/3 (CPU 3.072 MHz). Video H 32.000 kHz / V 60.61 Hz. Details:
`contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`ckong.zip` (MAME romset; `ROMZIP`, default `~/roms/ckong.zip`), unzipped by
`prep_roms.sh` into `<SRC_DIR>/tools/ckong_unzip/`; generates `ckong_program.vhd`,
`ckong_tile_bit0/1.vhd`, `ckong_big_sprite_tile_bit0/1.vhd`, `ckong_palette.vhd`,
`ckong_big_sprite_palette.vhd`, `ckong_samples.vhd`. Dar's `README.txt` suggests the
`ckongpt2` contents; all 17 files the `.bat` reads are in the `ckong` parent set. Not
included. **Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
patch), `make check` (parse-only), `make bitstream`, `make load`. `make setup` verifies and
extracts `dloads/vhdl_ckong_rev_0_1_2018_06_06.zip`, applies
`contrib/code/ckong_xor_width.patch` and runs `contrib/tools/prep_roms.sh`.

## Known issues

None open. `make check` shows a pre-existing HDL 9-3240 CRITICAL WARNING inside Dar's core
(`ckong_sound.vhd`); left as is.

## Issues addressed for Basys 3

- `rtl_dar/ckong.vhd:405-408`: four sprite-address XORs of the 13-bit
  `tile_graph_rom_addr` driver with 5-bit literals; Vivado rejects the length mismatch.
  `contrib/code/ckong_xor_width.patch` zero-pads them to 13 bits (same fix as
  `bagman_xor_width.patch`; no behaviour change).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
