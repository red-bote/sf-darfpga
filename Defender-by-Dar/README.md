# Defender-by-Dar

Defender (Williams, 1981) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.0 (2017-10-15):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/defender/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                | Keyboard         | Joystick    | Button     |
|-------------------------|------------------|-------------|------------|
| up / down               | up / down arrows | up / down   |            |
| thrust                  | Left Alt         | right       |            |
| reverse                 | Z                | left        |            |
| fire                    | Left Ctrl        | fire        |            |
| smart bomb              | Space            | down + fire |            |
| hyperspace              | Left Shift       | up + fire   |            |
| coin                    | 5, 6             |             | btnU, btnD |
| start 1 / 2             | 1, 2             |             | btnL, btnR |
| advance (held)          | F2               |             |            |
| high-score reset (held) | F1               |             |            |
| auto-up (toggle)        | 9                |             |            |
| reset                   |                  |             | btnC       |

Player 2 uses the same controls. Joystick fire does not shoot while up or down is held.

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |
| sw12   | cabinet        | upright    | cocktail   |

Game settings are stored in CMOS and changed with advance, auto-up and high-score reset.

## Clocks

| Clock                    | Original             | Basys 3             | Difference    |
|--------------------------|----------------------|---------------------|---------------|
| Main CPU (6809, E clock) | 1.000 MHz            | 1.000 MHz           | 0             |
| Pixel                    | 8.000 MHz            | 6.000 MHz           | note 1        |
| Sound board              | 3.579545 MHz         | 3.579545 MHz        | 0             |
| Video                    | 15.625 kHz / 60.1 Hz | 31.25 kHz / 60.1 Hz | lines doubled |

Notes:

1. The core uses a 6 MHz pixel clock, 384 pixels per 64 us line. Line and frame rate
   match the original (1 MHz video counter, 16640 counts per frame).

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `williams/williams.cpp` (12 MHz and 3.579545 MHz crystals).

## ROMs

`defender.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/defender_cpu_1mhz.patch`
  - Origin: Dar archive
  - Change: main CPU at the original 1 MHz (core runs 2 MHz)
  - Files:
    - `rtl_dar/defender.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

