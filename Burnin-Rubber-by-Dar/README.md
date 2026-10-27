# Burnin-Rubber-by-Dar

Burnin' Rubber (Data East, 1982) on the Digilent Basys 3. FPGA core by Dar
(darfpga@aol.fr, <http://darfpga.blogspot.fr>), rev 0.0 (2017-12-22):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/burnin_rubber/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                       | Keyboard  | Joystick | Button     |
|--------------------------------|-----------|----------|------------|
| steer / accelerate / slow down | arrows    | stick    |            |
| jump                           | Left Ctrl | fire     |            |
| coin                           | 5, 6      |          | btnU, btnD |
| start 1 / 2                    | 1, 2      |          | btnL, btnR |
| reset                          |           |          | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |

The DIP settings are fixed inside the core (not on switches).

## Clocks

| Clock                  | Original              | Basys 3              | Difference    |
|------------------------|-----------------------|----------------------|---------------|
| Main CPU (DECO C10707) | 750 kHz               | 750 kHz              | 0             |
| Pixel                  | 6 MHz                 | 6 MHz                | 0             |
| Sound CPU (6502)       | 500 kHz               | 500 kHz              | 0             |
| Sound (2x AY-3-8910)   | 1.5 MHz               | 1.5 MHz              | 0             |
| Video                  | 15.625 kHz / 59.87 Hz | 31.25 kHz / 59.87 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `dataeast/btime.cpp` `bnj` (12.000 MHz crystal).

## ROMs

`brubber.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/burnin_rubber_vsync_before_vblank.patch`
  - Origin: Dar archive
  - Change: vsync starts at vblank, so a VGA monitor shows the last 8 active lines
  - Files:
    - `rtl_dar/burnin_rubber.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

