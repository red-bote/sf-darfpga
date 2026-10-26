# Zaxxon-by-Dar

Basys 3 port of Zaxxon (Gremlin/Sega, 1980), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_zaxxon_rev_0_0_2019_11_29.zip` (rev 0.0,
2019-11-29, SourceForge folder `zaxxon`), `dloads/`. Upstream release notes:
`README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA via MiST scandoubler), sound, keyboard
(MAME keys, keyboard on `clock_24`), JXADC joystick including fire with a CX40-type
joystick (missed presses earlier were a faulty joystick), buttons. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; the core's hsync/vsync and pixel-clock bits
  are exposed by `contrib/code/zaxxon_expose_video_timing.patch`. sw13 up = 15 kHz TV
  (native RGB, csync on HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC. 8-way.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, left channel.
- Single clock domain (24.329 MHz = 48.66 MHz crystal / 2).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| move | arrows | pins 1-4 | |
| fire | Left Ctrl | pin 7 | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin 1 | 5 | | btnU / btnD |
| coin 2 | 6 | | |
| service (toggle) | F2 | | |
| flip screen (toggle) | F4 | | sw12 (XOR) |
| cocktail / upright (toggle) | F7 | | |
| reset | | | btnC |

Player 2 mirrors player 1 (the core's `*_c` cocktail inputs take the player 1 signals).
Toggles flip on key press and ignore typematic repeat. Buttons are debounced (10.8 ms);
JXADC fire is not (2-FF only; the core passes fire to the CPU as a level). No joystick
combos.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw12 | flip screen, XOR with the F4 toggle | `flip_sel = F4 toggle xor '1'` | `flip_sel = F4 toggle` |

The core's DIP values are set inside `rtl_dar/zaxxon.vhd:453-454`: `sw1_input =
cocktail & "111" & x"f"` (only cocktail is a port, the F7 toggle) and `sw2_input = x"33"`
(coin A/B 1 coin 1 credit); not wireable without a core patch.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC`, `btnU`, `btnD`, `btnL`, `btnR` | reset / coin 1 / coin 1 / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `O_PMODAMP2_GAIN` / `O_PMODAMP2_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: 24.32900 MHz (D 3 / M 35.125 / O 48.125), single domain, signal `clock_24`;
original 48.66 MHz crystal / 2 (CPU 3.041 MHz, pixel 6.082 MHz). VGA H 31.678 kHz, V
60.00 Hz. Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`zaxxon.zip` (MAME romset; `ROMZIP`, default `~/roms/zaxxon.zip`). Not included.
`prep_roms.sh` unzips it into `tools/zaxxon_unzip/` and generates `zaxxon_cpu.vhd`,
`zaxxon_char_bits_1/2.vhd`, `zaxxon_bg_bits_1/2/3.vhd`, `zaxxon_sp_bits_1/2/3.vhd`,
`zaxxon_map_1/2.vhd`, `zaxxon_palette.vhd`, `zaxxon_char_color.vhd`.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2 (`VIVADO` overrides the path), openFPGALoader.
`make help`; `make` (setup, create_prj, clk_wiz, patch), `make check` (parse-only),
`make bitstream`, `make load`. Project
`vhdl_zaxxon_rev_0_0_2019_11_29/basys3/zaxxon_basys3.xpr` (top `zaxxon_basys3`).

## Known issues

- Scandoubler `clk_sys` is the core's register-derived `clock_cnt(0)` (untimed path,
  `../KNOWN_ISSUES.md`); no hardware symptom.

## Issues addressed for Basys 3

- `rtl_dar/zaxxon.vhd`: 8-bit literal XORed with 9-bit `hflip`, Vivado rejects it; padded
  to 9 bits (`contrib/code/zaxxon_hflip_xor_width.patch`; check:
  `grep -n '"0" & not(hcnt(8))' .../rtl_dar/zaxxon.vhd`).
- `rtl_dar/zaxxon.vhd`: `video_hs`/`video_vs` declared but never driven; patch drives them
  and adds `pix_clk_div` (`contrib/code/zaxxon_expose_video_timing.patch`; check:
  `grep -n 'pix_clk_div' .../rtl_dar/zaxxon.vhd`).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
