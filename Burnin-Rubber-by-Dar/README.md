# Burnin-Rubber-by-Dar

Basys 3 port of Burnin' Rubber (Data East, 1982), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_burnin_rubber_rev_0_0_2017_12_22.zip` (rev 0.0,
22/12/2017), `dloads/`. Basys 3 port by Red~Bote; Dar's release notes: `README.txt` in the
extracted archive.

## Status

Hardware-verified 2026-10-20 (IO scheme of 2026-10-20, MAME keys): picture (31 kHz VGA),
sound, keyboard, JXADC joystick, buttons. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, composite
  sync on HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/jump, active
  low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| steer / accelerate / slow down | arrows | pins 1-4 | |
| jump | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. No joystick combos (coin/start combos removed 2026-10-02). No
debounce. Keyboard decoded in the wrapper (F0 = release, E0 ignored).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |

The DIP switches are constants inside the core (`burnin_rubber.vhd:295-296`); not on board
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
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 12.000 MHz (5 / 49.875 / 83.125), single domain; pixel 6 MHz. Video
H 31.25 kHz / V 59.87 Hz (261 lines). Details: `contrib/basys3/PORTING_SPEC.md` §2,
`../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`brubber.zip` (MAME romset; `ROMZIP`, default `~/roms/brubber.zip`), unzipped by
`prep_roms.sh` into `<SRC_DIR>/tools/burnin_rubber_unzip/`; generates
`burnin_rubber_prog.vhd`, `bg_graphx_1/2.vhd`, `fg_sp_graphx_1/2/3.vhd`,
`burnin_rubber_sound_prog.vhd`. Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
patch), `make check` (parse-only), `make bitstream`, `make load`. `make setup` verifies and
extracts `dloads/vhdl_burnin_rubber_rev_0_0_2017_12_22.zip`, applies
`contrib/code/burnin_rubber_vsync_before_vblank.patch` and runs `contrib/tools/prep_roms.sh`.

## Known issues

None open. Resolved 2026-09-28: missing bottom rows (see Issues addressed).

## Issues addressed for Basys 3

- `rtl_dar/burnin_rubber.vhd`: `video_vs` asserted 8 lines before `vblank`, so a VGA
  monitor discarded the last 8 active lines in its retrace.
  `contrib/code/burnin_rubber_vsync_before_vblank.patch` moves the `vsync_cnt` reset to
  `vcnt = 248` (no overlap; Defender/Time-Pilot/Pooyan pattern). Hardware-confirmed
  2026-09-28.
- `burnin_rubber_vcnt_272_lines.patch` (261 → 272 lines per the Bump 'n' Jump schematics,
  2026-09-23) caused the 2026-09-25 bottom-row clipping (544 lines at 57.44 Hz); retired
  2026-09-28 after hardware A/B testing. The pristine 261-line frame is used.
- Scandoubler `ce_x1` from a second MMCM output failed hold timing (WHS -0.60 ns); replaced
  by a `clock_12` toggle enable, single MMCM output (2026-10-02).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
