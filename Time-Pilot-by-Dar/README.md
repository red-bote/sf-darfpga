# Time-Pilot-by-Dar

Time Pilot (Konami, 1982) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.0 (2017-11-05):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/time_pilot/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                 | Keyboard  | Joystick | Button     |
|--------------------------|-----------|----------|------------|
| up / down / left / right | arrows    | stick    |            |
| fire                     | Left Ctrl | fire     |            |
| coin                     | 5, 6      |          | btnU, btnD |
| start 1 / 2              | 1, 2      |          | btnL, btnR |
| reset                    |           |          | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function                   | Down             | Up           |
|--------|----------------------------|------------------|--------------|
| sw15   | audio                      | on               | off          |
| sw14   | amplifier gain             | low              | high         |
| sw13   | display                    | 31 kHz VGA       | 15 kHz RGB   |
| sw11-8 | DIP 1 Coinage A (bits 3-0) | original default | bit inverted |
| sw7-0  | DIP 2 (note 1)             | bit = 0          | bit = 1      |

Notes:

1. DIP 2 bits:
   - 8: sound
   - 7-5: difficulty
   - 4: bonus
   - 3: cocktail
   - 2-1: lives

## Clocks

| Clock                     | Original         | Basys 3             | Difference    |
|---------------------------|------------------|---------------------|---------------|
| Main CPU (Z80)            | 3.072 MHz        | 3.0717 MHz          | -0.007%       |
| Pixel                     | 6.144 MHz        | 6.1435 MHz          | -0.007%       |
| Sound (Z80, 2x AY-3-8910) | 1.790 MHz        | 1.790 MHz           | 0             |
| Video (note 1)            | 16.0 kHz / 60 Hz | 32.0 kHz / 60.61 Hz | lines doubled |

Notes:

1. The original video values are nominal.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `konami/timeplt.cpp` (18.432 MHz and 14.31818 MHz crystals).

## ROMs

`timeplt.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/time_pilot_single_domain.patch`
  - Origin: Dar archive
  - Change: core and sound board on one clock with clock enables
  - Files:
    - `rtl_dar/gen_ram.vhd`
    - `rtl_dar/time_pilot.vhd`
    - `rtl_dar/time_pilot_sound_board.vhd`

- `contrib/code/time_pilot_vcnt_264_lines.patch`
  - Origin: Dar archive
  - Change: 264 lines per frame (60.61 Hz), as MAME
  - Files:
    - `rtl_dar/time_pilot.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

