# Computer-Space-by-Dar

Basys 3 port of Computer Space (Nutting Associates, 1971), original core by Dar
(darfpga@aol.fr), <http://darfpga.blogspot.fr>. Source:
`vhdl_computer_space_rev_1_1_2017_11_22.zip` (v1.1, 2017-11-22), `dloads/`. Basys 3 port by
Red~Bote. Dar's release notes: `README.txt` in the extracted archive. Discrete-logic game:
no MAME driver and no romset.

## Status

Hardware-verified 2026-10-20: picture (31 kHz VGA, white on black), sound, keyboard,
JXADC joystick, buttons, rocket-missile fire and refire.

## Features (Basys 3)

- Video: 31 kHz VGA via the MiST scandoubler; sw13 up = 15 kHz TV (native RGB, composite
  sync on HS).
- Keyboard: onboard USB-HID port, MAME-style keys (no MAME driver), decoded in the wrapper
  (2026-10-20, replaces `kbd_joystick`; F0 = release, E0 ignored; `../PORTING_SPEC.md` §3.1).
- Joystick: Atari-style on Pmod JXADC, pins 1/2/4/7 = CW/CCW/thrust/fire, active low,
  pull-ups in the XDC.
- Audio: PmodAMP2 on Pmod JA pins 1/2/4, mono.
- Single 48 MHz clock domain (2026-10-02).

## Controls

| Action | Keyboard | JXADC | Basys 3 |
|---|---|---|---|
| rotate CCW / CW | Left / Right arrow | pin 2 / pin 1 | |
| thrust | Up arrow | pin 4 | |
| fire | Left Ctrl | pin 7 | |
| start | 1 / 2 | | btnU / btnD / btnL / btnR (any) |
| reset | | | btnC |

No coin input (the wrapper drives `signal_start` directly). JXADC pin 3 is spare (the core
has no down/reverse input). No joystick combos.

## Switches

| Switch | Function | Down | Up |
|---|---|---|---|
| sw15 | audio | on | off |
| sw14 | amp gain | low | high |
| sw13 | display | 31 kHz VGA | 15 kHz TV |

The core has no DIP or option inputs; sw0-12 unused.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|---|---|---|
| clk (W5, 100 MHz) | `clk` | into `clk_wiz_0` |
| btnC / btnU / btnD / btnL / btnR | `btnC` ... `btnR` | reset / start (U, D, L, R) |
| sw(15:13) | `sw` | see Switches |
| USB-HID C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard |
| JXADC1-4, JXADC7 | `JXADC(0..4)` | joystick |
| JA1 / JA2 / JA4 | `O_PMODAMP2_AIN` / `_GAIN` / `_SHUTD` | audio |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB (monochrome) |

## Clocking

`clk_wiz_0`: 48.000 MHz (5 / 49.5 / 20.625), single domain; 6 MHz pixel and 12 MHz
scandoubler rates are clock enables; the core's 50 MHz-sized timer and sound constants are
rescaled x0.96 (`contrib/code/computer_space_single_domain.patch`,
`computer_space_motion_single_domain.patch`). Pixel 6.000 MHz is 2.7% above Dar's
5.842 MHz. Details: `contrib/basys3/PORTING_SPEC.md` §2, `../CLOCK_CRYSTAL_CATALOG.md`.

## Required ROMs

None. `make setup` generates the six `rom_*.vhd` sound roms from the archive's Intel-HEX
files (`contrib/tools/gen_sound_roms.py`).

## Building

Requires python3, unzip, Vivado 2020.2, openFPGALoader. `make help`; `make` (setup,
project, clk_wiz, patch), `make check` (parse-only), `make bitstream`, `make load`.
`motion_board.vhd` is imported into the project and patched there (PORTING_SPEC §4, §9);
the pristine file is never modified.

## Known issues

- The missile spawns offset from the ship's nose: original 1971 behaviour (PORTING_SPEC
  §9.1), not a port defect.

## Issues addressed for Basys 3

- Rocket-missile fire dead after the first launch: unreachable clear branch in
  `rtl/motion_board.vhd`; fixed in `contrib/code/computer_space_rocket_timer_synth_fix.patch`
  (also the synthesis fix; PORTING_SPEC §9.1).
- Three-clock scheme failed setup and hold on its crossings; single 48 MHz domain
  (2026-10-02; PORTING_SPEC §2.1).
- `motion_board.vhd` association fix (`computer_space_motion_q_assoc.patch`).
- MiST `scandoubler.v`: unpacked array declared with a full range; Vivado rejects the
  single-value size (`contrib/code/scandoubler_fix.patch`, applied to the project copy).

## Third-party sources

| Resource | Source | Notes |
|---|---|---|
| Basys-3-Master.xdc | <https://github.com/Digilent/digilent-xdc> | `contrib/basys3/vivado/` |
| scandoubler.v (MiST, Till Harbaum, GPL-3.0) | <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v> | `contrib/code/` |
