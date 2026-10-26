# Phoenix-by-Dar

Basys 3 port of Phoenix (Amstar, 1980), FPGA core by Dar (darfpga@aol.fr),
<http://darfpga.blogspot.fr>. Source: `vhdl_phoenix_DE10_lite.zip`, `dloads/`. Basys 3 port
by Red~Bote. Dar's release notes: `README.txt` in the extracted archive (upstream: "TV mode
only RGB 15kHz").

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA), sound, keyboard (MAME keys), JXADC
joystick, buttons. Reset silences the sound since 2026-10-07. JXADC and
buttons through `ext_joy` hardware-confirmed 2026-10-02.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler, fed by real hsync/vsync exposed from the
  core (`phoenix_expose_hsync_vsync.patch`; the pristine core produces composite sync
  only); sw13 up = 15 kHz TV (native RGB, composite sync on HS, as the DE10 top).
- Keyboard: onboard USB-HID port, MAME default keys, decoded in the wrapper into the
  core's `ext_joy` (2026-10-20; the core's internal `kbd_joystick` is idle, its PS/2 pins
  tied `'1'`; F0 = release, E0 ignored; `../PORTING_SPEC.md` §3.1).
- Joystick: Atari-style on Pmod JXADC, pins 1/2/4/7 = right/left/shield/fire, active low,
  pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono; `audio_select` on sw10-8.

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| left / right | Left / Right arrows | pin 2 / pin 1 | |
| fire | Left Ctrl | pin 7 | |
| shield | Left Alt | pin 4 (up), up+fire, down+fire | |
| start 1P / 2P | 1 / 2 | | btnL / btnR |
| coin | 5 / 6 | | btnU / btnD |
| reset | | | btnC |

Shield combos pass fire through. Buttons debounced (11.9 ms).

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |
| sw10-8 | `audio_select` | `000` = mix all | `100`/`101`/`110`/`111` = effect1/effect2/effect3/melody solo |
| sw7-0 | `dip_switch`: Lives(1-0) / Bonus(3-2) / Coin(4) / unknown(6-5) / Cocktail(7) | `0` | `1` (direct, as the DE10 top) |

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` ... `btnR` | reset / coin / coin / start 1 / start 2 |
| sw(15:0) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `_GAIN` / `_SHUTD` | audio |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Clocking

`clk_wiz_0`: `clk_out1` 11.000 MHz (core; pixel 5.5 MHz inside the core) and `clk_out2`
50.000 MHz (audio effect/music blocks), DIVCLK 1 / MULT_F 11.000 / CLKOUT0 100.000 /
CLKOUT1 22. Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

`phoenix.zip` (MAME romset; `ROMZIP`, default `~/roms/phoenix.zip`). Not included.
**Do not redistribute roms or anything generated from them.**

## Building

Requires gcc, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup, project,
clk_wiz, patch), `make check` (parse-only), `make bitstream`, `make load`. The archive has
no top-level folder and no PROM `.bat`; `prep_roms.sh` runs a reconstructed
`make_phoenix_proms.sh`.

## Known issues

- Scandoubler `ce_x1` is the core's register-derived `video_clk` (untimed,
  `../KNOWN_ISSUES.md`); no hardware symptom.

## Issues addressed for Basys 3

- Composite sync only: `contrib/code/phoenix_expose_hsync_vsync.patch` exposes `pulse_a`
  (hsync) and `vblank_n` (vsync) from `phoenix_video` through `phoenix`.
- No discrete input ports (PS/2 decoded inside the core): `contrib/code/phoenix_external_inputs.patch`
  adds `ext_joy`, OR-merged before the CPU inversion (third attempt, 2026-10-02; two earlier
  attempts reverted, PORTING_SPEC §7).
- btnC did not reset the sound: `contrib/code/phoenix_sound_reset.patch` (2026-10-07).
- Keyboard moved from JB1/JB3 to the onboard USB-HID host (2026-09-23, XDC only).
- MiST `scandoubler.v`: Vivado reads it as Verilog-2001; blocks with local declarations
  named, `sd_buffer` declared with a full range (`contrib/code/scandoubler_fix.patch`,
  applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v> | `contrib/code/`; Vivado fixes in `scandoubler_fix.patch` |
