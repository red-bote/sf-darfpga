# Bagman-FPGA-Dar

Bagman (Valadon Automation / Stern, 1982) on the Digilent Basys 3. FPGA core by Dar
(darfpga@aol.fr, <http://darfpga.blogspot.fr>), rev 0.1 (2018-06-05):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/bagman/>,
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
| jump                     | Left Ctrl | fire     |            |
| coin                     | 5, 6      |          | btnU, btnD |
| start 1 / 2              | 1, 2      |          | btnL, btnR |
| reset                    |           |          | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |

The DIP settings are fixed inside the core (not on switches).

## Clocks

| Clock                     | Original            | Basys 3             | Difference    |
|---------------------------|---------------------|---------------------|---------------|
| Main CPU (Z80)            | 3.072 MHz           | 3.072 MHz           | 0             |
| Pixel                     | 6.144 MHz           | 6.144 MHz           | 0             |
| Sound (AY-3-8910)         | 1.536 MHz           | 1.536 MHz           | 0             |
| Speech (TMS5110 LPC rate) | 8 kHz               | 8.000 kHz           | 0             |
| Video                     | 16.0 kHz / 60.61 Hz | 32.0 kHz / 60.61 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `valadon/bagman.cpp` (18.432 MHz crystal).

## ROMs

`bagman.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/bagman_xor_width.patch`
  - Origin: Dar archive
  - Change: four tile ROM address XOR literals padded to 13 bits (Vivado width check)
  - Files:
    - `rtl_dar/bagman.vhd`

