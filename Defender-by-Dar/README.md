# Defender-by-Dar

Basys 3 port of Defender (Williams, 1981), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_defender_rev_0_0_2017_10_15.zip` (rev 0.0,
2017-10-15), `dloads/`. Upstream release notes: `README.txt` in the extracted archive.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA via MiST scandoubler), sound, keyboard
(MAME keys), JXADC joystick, buttons. JXADC smart bomb (down + fire) and hyperspace
(up + fire) hardware-verified 2026-10-21; sw12 cocktail 2026-10-21. Open items: none.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, csync on
  HS, VS high).
- Keyboard: onboard USB-HID port, MAME default keys.
- Joystick: Atari-style on Pmod JXADC, pins 1/2/3/4/7 = right/left/down/up/fire, active
  low, pull-ups in the XDC. Right = thrust, left = reverse.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono (8-bit core `audio_out`).
- Main CPU at the original 1 MHz E clock (`contrib/code/defender_cpu_1mhz.patch`; Dar's
  core runs 2 MHz).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| up / down | up / down arrows | pin 4 / pin 3 | |
| thrust | Left Alt | pin 1 (right) | |
| reverse | Z | pin 2 (left) | |
| fire | Left Ctrl | pin 7 | |
| smart bomb | Space | pin 3 + pin 7 (down + fire) | |
| hyperspace | Left Shift | pin 4 + pin 7 (up + fire) | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| auto-up (toggle) | 9 | | |
| advance (held) | F2 | | |
| high-score reset (held) | F1 | | |
| reset | | | btnC |

Player 2 mirrors player 1. In a JXADC combo the direction passes through and fire does
not: no shot while up or down is held (2026-10-21; with fire passed through the game
dropped the combo). JXADC fire is debounced (10.9 ms). Toggles flip on key press and
ignore typematic repeat. No joystick combos for coin/start.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw12 | `sw_coktail_table` | Dar default `'1'` (upright) | cocktail |

No DIP bank: game settings are stored in CMOS and changed with advance (F2), auto-up (9)
and high-score reset (F1).

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

## Clocking

`clk_wiz_0` (D 1 / M 7.875 / O0 65.625 / O1 110, VCO 787.5 MHz): `clk_out1` = 12.000 MHz
(`clock_12`, core and scandoubler) and `clk_out2` = 7.159091 MHz (`clock_7p16`), divided
by 2 in fabric to 3.5795454 MHz (`clock_3p58`) for the sound board and PWM (an MMCM output
cannot go below VCO / 128). Pixel 6 MHz, line 64 us (384 × 260). Details:
`contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`defender.zip` (MAME romset; `ROMZIP`, default `~/roms/defender.zip`). Not included.
`prep_roms.sh` unzips it into `tools/defender_unzip/` and generates `defender_prog.vhd`
(11 program ROMs concatenated; `copy /B a + b ...` becomes `cat a b ...`),
`defender_decoder_2.vhd`, `defender_decoder_3.vhd`, `defender_sound.vhd`.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2 (`VIVADO` overrides the path), openFPGALoader.
`make help`; `make` (setup, create_prj, clk_wiz, patch), `make check` (parse-only),
`make bitstream`, `make load`. Project
`vhdl_defender_rev_0_0_2017_10_15/basys3/defender_basys3.xpr` (top `defender_basys3`).

## Known issues

None open.

## Issues addressed for Basys 3

- `rtl_dar/defender.vhd`: main CPU E clock 2 MHz → 1 MHz, the original rate
  (`contrib/code/defender_cpu_1mhz.patch`, 2026-10-02, hardware-confirmed).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
