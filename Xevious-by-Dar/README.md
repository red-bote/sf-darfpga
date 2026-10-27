# Xevious-by-Dar

Xevious (Namco, 1982) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), DE2/DE10-lite release (2017-05-01):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/xevious/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                 | Keyboard  | Joystick        | Button     |
|--------------------------|-----------|-----------------|------------|
| up / down / left / right | arrows    | stick           |            |
| fire                     | Left Ctrl | fire            |            |
| bomb                     | Left Alt  | down; up + fire |            |
| coin                     | 5, 6      |                 | btnU, btnD |
| start 1 / 2              | 1, 2      |                 | btnL, btnR |
| reset                    |           |                 | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function       | Down                   | Up                  |
|--------|----------------|------------------------|---------------------|
| sw15   | audio          | on                     | off                 |
| sw14   | amplifier gain | low                    | high                |
| sw13   | display        | 31 kHz VGA             | 15 kHz RGB          |
| sw12   | test mode      | off (original default) | test / service mode |

The game DIP banks are fixed inside Dar's core.

## Clocks

| Clock             | Original            | Basys 3             | Difference    |
|-------------------|---------------------|---------------------|---------------|
| CPUs (3x Z80)     | 3.072 MHz           | 3.072 MHz           | -0.0002%      |
| Pixel             | 6.144 MHz           | 6.144 MHz           | -0.0002%      |
| Sound (Namco WSG) | 96 kHz              | 96 kHz              | -0.0002%      |
| Video             | 16.0 kHz / 60.61 Hz | 32.0 kHz / 60.61 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `namco/xevious.cpp` (18.432 MHz crystal).

## ROMs

`xevious.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
roms or anything generated from them.

## Building

Requirements:

- gcc
- unzip
- Vivado 2020.2 (the `VIVADO` variable overrides the install path)
- openFPGALoader

Make targets, run from this directory:

- `make`: extract the sources, generate the PROM VHDL from the romset, create the
  Vivado project, generate the clock IP and install the Basys 3 top level.
- `make check`: parse-only syntax check, no synthesis.
- `make bitstream`: synthesis, implementation and bitstream.
- `make load`: program the Basys 3 with the built bitstream.
- `make clean`: remove the extracted sources and build output.
- `make help`: list all targets.

## Known issues

None open.

## Changes to third-party sources

- `contrib/code/xevious_expose_hsync_vsync.patch`
  - Origin: Dar archive
  - Change: core: separate hsync/vsync for the scandoubler
  - Files:
    - `rtl_dar/xevious.vhd`

- `contrib/code/xevious_synth_fix_xor_spflips.patch`
  - Origin: Dar archive
  - Change: core: `xor spflips` operand widths made equal (Vivado)
  - Files:
    - `rtl_dar/xevious.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

