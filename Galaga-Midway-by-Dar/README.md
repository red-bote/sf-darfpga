# Galaga-Midway-by-Dar

Basys 3 port of Galaga (Namco / Midway, 1981), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_galaga_rev_0_3_2018_05_06.zip` (release 0.3,
2018-05-06), `dloads/`. Basys 3 port by Red~Bote. Dar's release notes: `README.txt` in the
extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA), sound, keyboard (MAME keys), JXADC
joystick, buttons. sw12 test mode wired 2026-10-20, hardware check 2026-10-21. JXADC fire
debounce restored and hardware-verified 2026-10-21.

## Features (Basys 3)

- Video: 31 kHz VGA via the imported MiST scandoubler; sw13 up = 15 kHz TV (native RGB,
  composite sync on HS).
- Keyboard: onboard USB-HID port, MAME default keys, decoded in the wrapper (2026-10-20,
  replaces `kbd_joystick`; F0 = release, E0 ignored; `../PORTING_SPEC.md` §3.1).
- Joystick: Atari-style on Pmod JXADC, pins 1/2/7 = right/left/fire (the core has no
  up/down), active low, pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Board buttons and JXADC fire debounced (14 ms); reason: `contrib/basys3/PORTING_SPEC.md`
  §7.1.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| left / right | Left / Right arrows (6B / 74) | pin 2 / pin 1 | |
| fire | Left Ctrl (14) | pin 7 | |
| start 1P / 2P | 1 / 2 (16 / 1E) | | btnL / btnR |
| coin | 5 / 6 (2E / 36) | | btnU / btnD |
| reset | | | btnC |

Player 2 mirrors player 1 left/right/fire. No joystick combos (coin/start combos removed
2026-10-02). JXADC pins 3/4 (down/up) are not used.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw12 | `b_test` | Dar `'1'` (off) | test / service mode |

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` ... `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick (bits 0, 1, 4 used) |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `_GAIN` / `_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 36.863711 MHz (6 / 56.125 / 25.375, forced by `make_clk_wiz_0.sh`; Vivado's own
solve gives VGA H 32.0017 kHz), single MMCM output; `clock_18` = 18.432 MHz (core, original
crystal), CPUs 3.072 MHz, pixel 6.144 MHz. Video 31.9998 kHz / 60.61 Hz (was 36.000 MHz,
-2.34%, until 2026-10-01). Details: `contrib/basys3/PORTING_SPEC.md` §2,
`../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`galaga.zip` + `galagamw.zip` (MAME romsets; `ROMZIP1` / `ROMZIP2`, default
`~/roms/galaga.zip` / `~/roms/galagamw.zip`). `galagamw` provides the `3200a`-`3700g` CPU
ROMs missing from `galaga`. Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
clk_wiz, patch), `make check` (parse-only), `make bitstream`, `make load`.

## Known issues

- The keyboard can randomly stick to the right (and maybe left); original core issue.

## Issues addressed for Basys 3

- `rtl_dar/galaga.vhd` `bgpalette_addr`: `xor` operand widths 3 vs 2 bits; fixed by
  parenthesizing (`contrib/code/galaga_bgpalette_xor_length_fix.patch`).
- `rtl_dar/galaga.vhd:848`: Start 1 / Start 2 ignored after a coin; the Namco 51XX
  credit-mode flag is re-enabled on every coin edge (`contrib/code/galaga_credit_mode_fix.patch`;
  open investigation: `contrib/code/51xx_credit_state_machine_investigation.md`).
- `rtl_dar/galaga.vhd`: `video_hs`/`video_vs` brought out for the scandoubler
  (`contrib/code/galaga_vga_sync.patch`).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).
- JXADC fire contact bounce double-fires through the core's full-rate fire edge detect;
  debounced in the wrapper (PORTING_SPEC §7.1).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
