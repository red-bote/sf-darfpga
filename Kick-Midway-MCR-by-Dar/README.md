# Kick-Midway-MCR-by-Dar

Kick (Midway MCR, 1981) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.2 (2019-11-22):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Kick_kickman/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz interlaced RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/4/7 = right/left/up/fire; down unused).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function          | Keyboard  | Joystick     | Button     |
|-------------------|-----------|--------------|------------|
| spin left / right | arrows    | left / right |            |
| spin faster       | Left Alt  | up           |            |
| kick              | Left Ctrl | fire         |            |
| coin 1 / 2        | 5, 6      |              | btnU, btnD |
| start 1 / 2       | 1, 2      |              | btnL, btnR |
| service (toggle)  | F2        |              |            |
| reset             |           |              | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |

Game settings are in the service menu (F2).

## Clocks

| Clock                     | Original             | Basys 3              | Difference |
|---------------------------|----------------------|----------------------|------------|
| Main CPU (Z80)            | 2.496 MHz            | 2.500 MHz            | +0.16%     |
| Pixel (15 kHz mode)       | 9.984 MHz            | 10.000 MHz           | +0.16%     |
| Sound (Z80, 2x AY-3-8910) | 2.000 MHz            | 2.000 MHz            | 0          |
| Video                     | 15.75 kHz / 59.65 Hz | 31.55 kHz / 60.09 Hz | note 1     |

Notes:

1. The core generates the VGA frame. 15 kHz mode (sw13 up): 15.77 kHz / 59.75 Hz.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `bally/mcr.cpp` (19.968 MHz main and 16 MHz sound board crystals).
The original pixel and video values are derived from the 19.968 MHz crystal (pixel =
crystal / 2). MAME names no video crystal.

## ROMs

`kick.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

None: Dar's sources are used unchanged.

