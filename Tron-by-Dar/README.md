# Tron-by-Dar

Tron (Midway MCR, 1982) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.3 (2019-11-22):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/tron/>, copy in `dloads/`.
Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz interlaced RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                 | Keyboard    | Joystick | Button     |
|--------------------------|-------------|----------|------------|
| up / down / left / right | arrows      | stick    |            |
| fire                     | Left Ctrl   | fire     |            |
| spin left / right        | Z / X       |          |            |
| spin faster              | Left Alt    |          |            |
| coin 1                   | 5           |          | btnU       |
| coin 2                   | 6           |          | btnD       |
| start 1 / 2              | 1, 2        |          | btnL, btnR |
| service                  | F2 (toggle) |          |            |
| continue                 | F6 (toggle) |          |            |
| reset                    |             |          | btnC       |

## Switches

| Switch | Function       | Down                       | Up                    |
|--------|----------------|----------------------------|-----------------------|
| sw15   | audio          | on                         | off                   |
| sw14   | amplifier gain | low                        | high                  |
| sw13   | display        | 31 kHz VGA                 | 15 kHz interlaced RGB |
| sw12   | cocktail       | upright (original default) | cocktail (note 1)     |
| sw11   | coin meters    | original default           | inverted              |

Notes:

1. The core does not support the cocktail mode.

Game settings are in the service menu (F2).

## Clocks

| Clock                | Original          | Basys 3              | Difference    |
|----------------------|-------------------|----------------------|---------------|
| Main CPU (Z80)       | 2.496 MHz         | 2.500 MHz            | +0.16%        |
| Sound board (note 2) | 2.000 MHz         | 2.000 MHz            | 0             |
| Video (notes 1, 3)   | 15.75 kHz / 60 Hz | 31.55 kHz / 60.09 Hz | lines doubled |

Notes:

1. 15 kHz mode (sw13 up): 15.77 kHz / 59.75 Hz.
2. Sound board: Z80 CPU and 2x AY-3-8910.
3. Nominal values from a secondary source: interlaced 512 x 480, 30 Hz frames. MAME
   names no video crystal.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `bally/mcr.cpp`, `bally/midway_sound.h` (19.968 MHz main and
16 MHz sound board crystals).

## ROMs

`tron.zip` and `midssio.zip` (MAME romsets) in `~/roms/` or `$ROMZIP` / `$ROMZIP2`;
`midssio.zip` supplies the sound board PROM missing from `tron.zip`. Not included. Do not
redistribute roms or anything generated from them.

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

- The spinner is keyboard-only, as in Dar's DE10 build; the joystick has no analog
  equivalent.
- One CRITICAL WARNING (HDL 9-3240) inside Dar's core (`rtl_dar/tron.vhd:945`); builds are
  unaffected.

## Changes to third-party sources

None: Dar's sources are used unchanged.

