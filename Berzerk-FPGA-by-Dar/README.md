# Berzerk-FPGA-by-Dar

Berzerk (Stern, 1980) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.1 (2018-08-08):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/berzerk/>,
copy in `dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

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

| Switch | Function          | Down                     | Up         |
|--------|-------------------|--------------------------|------------|
| sw15   | audio             | on                       | off        |
| sw14   | amplifier gain    | low                      | high       |
| sw13   | display           | 31 kHz VGA               | 15 kHz RGB |
| sw12   | cocktail (note 1) | original default (`'1'`) | inverted   |

Notes:

1. sw12 sets the cabinet bit the game reads. The core has no screen flip and both
   players share the controls, so the switch has no visible effect.

The other DIP banks are fixed inside the core (not on switches).

## Clocks

| Clock                 | Original              | Basys 3              | Difference    |
|-----------------------|-----------------------|----------------------|---------------|
| Main CPU (Z80)        | 2.5 MHz               | 2.5 MHz              | 0             |
| Pixel                 | 5 MHz                 | 5 MHz                | 0             |
| Speech (S14001A base) | 2.5 MHz               | 2.5 MHz              | 0             |
| Video                 | 15.625 kHz / 59.64 Hz | 31.25 kHz / 59.64 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `stern/berzerk.cpp` (10.000 MHz crystal).

## ROMs

`berzerk.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/berzerk_reset_sensitivity.patch`
  - Origin: Dar archive
  - Change: `reset` added to a process sensitivity list
  - Files:
    - `rtl_dar/berzerk.vhd`

