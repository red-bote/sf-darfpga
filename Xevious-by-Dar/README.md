# Xevious-by-Dar

Basys 3 port of Xevious (Namco, 1982), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_xevious_de2_de10_lite_2017_05_01.zip`
(2017-05-01), `dloads/`. Upstream release notes: `README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA via MiST scandoubler), sound, keyboard
(MAME keys), JXADC joystick (no fire debounce needed; no double shots), buttons. sw12 test
mode hardware-verified 2026-10-21. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; the core's own hsync/vsync are exposed by
  `contrib/code/xevious_expose_hsync_vsync.patch`. sw13 up = 15 kHz TV (native RGB, csync
  on HS, VS high, as the DE10 top).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC. 8-way.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Single clock domain (18.432 MHz, the original crystal).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| fire | Left Ctrl | pin 7 | |
| bomb | Left Alt | pin 3 (with down); pin 4 + pin 7 (up + fire) | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1. JXADC3 drives down and bomb (2026-10-01). The up+fire combo
also passes up and fire through. Buttons are debounced (14.2 ms); JXADC fire is not (the
core passes fire to the CPU as a level).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw12 | `b_test` | Dar default `'1'` (off) | test/service mode |

The core's DIP banks `dip_a`/`dip_b` are constants inside `rtl_dar/xevious.vhd:410-411`
(not wireable without a core patch); `b_svce` is fixed `'1'`.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC`, `btnU`, `btnD`, `btnL`, `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | right, left, down + bomb, up, fire |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 18.43196 MHz (D 7 / M 61.125 / O 47.375), single domain, signal `clock_18`;
original 18.432 MHz crystal. Pixel 6.144 MHz (`ena_vidgen`), CPUs 3.072 MHz. VGA H 32.000
kHz, V 60.61 Hz. Details: `contrib/basys3/PORTING_SPEC.md` §2,
`../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`xevious.zip` (MAME romset; `ROMZIP`, default `~/roms/xevious.zip`). Not included.
`prep_roms.sh` unzips it into `tools/xevious_unzip/roms/` (distinct from the archive's
`tools/xevious_unzip_win64/`), renames the 9 color/sound PROMs to the names Dar's `.bat`
expects (e.g. `xvi-8*.6a` → `xvi_8bpr.6a`) and generates the PROM VHDL, including
`xevious_cpu_gfx_8bits.vhd` (CPU + graphics ROM).
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2 (`VIVADO` overrides the path), openFPGALoader.
`make help`; `make` (setup, create_prj, clk_wiz, patch), `make check` (parse-only),
`make bitstream`, `make load`. Project
`vhdl_xevious_de2_de10_lite_2017_05_01/basys3/xevious_basys3.xpr` (top `xevious_basys3`).
`make check` reports one CRITICAL WARNING (HDL 9-3240, `r2_port_in`) inside Dar's core
(`rtl_dar/xevious.vhd:1469`); it is pre-existing and does not stop synthesis.

## Known issues

None open.

## Issues addressed for Basys 3

- `rtl_dar/xevious.vhd`: `video_hs`/`video_vs` brought out from `gen_video` for the
  scandoubler (`contrib/code/xevious_expose_hsync_vsync.patch`; check:
  `grep -c video_hs .../rtl_dar/xevious.vhd` gives 2).
- `rtl_dar/xevious.vhd`: sprite address `xor spflips` width mismatch, Vivado rejects it
  (`contrib/code/xevious_synth_fix_xor_spflips.patch`).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
