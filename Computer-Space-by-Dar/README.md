# Computer-Space-by-Dar

Computer Space (Nutting Associates, 1971) on the Digilent Basys 3. FPGA core by Dar
(darfpga@aol.fr, <http://darfpga.blogspot.fr>), v1.1 (2017-11-22):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/computer_space/>, copy in
`dloads/`. Discrete-logic game: no CPU, no MAME driver, no romset. Design detail:
`contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function   | Keyboard    | Joystick | Button                 |
|------------|-------------|----------|------------------------|
| rotate CCW | Left arrow  | left     |                        |
| rotate CW  | Right arrow | right    |                        |
| thrust     | Up arrow    | up       |                        |
| fire       | Left Ctrl   | fire     |                        |
| start      | 1, 2        |          | btnU, btnD, btnL, btnR |
| reset      |             |          | btnC                   |

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |

## Clocks

| Clock | Original                        | Basys 3             | Difference    |
|-------|---------------------------------|---------------------|---------------|
| Pixel | unknown (DE10 build: 5.842 MHz) | 6.000 MHz           | +2.7% vs DE10 |
| Video | unknown                         | 31.4 kHz / 61.60 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

The original master crystal frequency is not documented in any source found; game
timers and sound rates follow the core's 50 MHz design values.

## ROMs

None. `make setup` generates the six sound roms from the archive's Intel-HEX files.

## Building

Requirements:

- python3
- unzip
- Vivado 2020.2 (the `VIVADO` variable overrides the install path)
- openFPGALoader

Make targets, run from this directory:

- `make`: extract the sources, generate the sound roms from the archive's Intel-HEX
  files, create the Vivado project, generate the clock IP and install the Basys 3 top
  level.
- `make check`: parse-only syntax check, no synthesis.
- `make bitstream`: synthesis, implementation and bitstream.
- `make load`: program the Basys 3 with the built bitstream.
- `make clean`: remove the extracted sources and build output.
- `make help`: list all targets.

## Known issues

None open.

## Changes to third-party sources

- `contrib/code/computer_space_single_domain.patch`
  - Origin: Dar archive
  - Change: core on one 48 MHz clock with enables; 50 MHz constants rescaled
  - Files:
    - `rtl/computer_space_top.vhd`
    - `rtl/computer_space_logic.vhd`
    - `rtl/sync_star_board.vhd`
    - `rtl/scan_counter.vhd`
    - `rtl/v74161.vhd`
    - `rtl/v74161_16bit.vhd`
    - `rtl/composite_sync.vhd`
    - `rtl/clocks.vhd`
    - `rtl/sound.vhd`
    - `rtl/computer_space_sound.vhd`

- `contrib/code/computer_space_motion_single_domain.patch`
  - Origin: Dar archive
  - Change: motion board on the same clock enables
  - Files:
    - `rtl/motion_board.vhd`

- `contrib/code/computer_space_motion_q_assoc.patch`
  - Origin: Dar archive
  - Change: motion board port association fix (Vivado)
  - Files:
    - `rtl/motion_board.vhd`

- `contrib/code/computer_space_rocket_timer_synth_fix.patch`
  - Origin: Dar archive
  - Change: rocket missile refires after the first launch; synthesis fix
  - Files:
    - `rtl/motion_board.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

