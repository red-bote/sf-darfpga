# Solar-Fox-by-Dar

Solar Fox (Bally Midway, 1981) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.1 (2019-11-22):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Solarfox/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz interlaced RGB for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono (left channel of the core's stereo output).

## Controls

| Function                 | Keyboard    | Joystick         | Button     |
|--------------------------|-------------|------------------|------------|
| up / down / left / right | arrows      | stick            |            |
| fire                     | Left Ctrl   | fire             |            |
| fast / start             | Left Alt    | direction + fire | btnL       |
| coin 1 / 2               | 5, 6        |                  | btnU, btnD |
| service                  | F2 (toggle) |                  |            |
| reset                    |             |                  | btnC       |

Single player; fast also starts a game. Game settings are in the service menu (F2).

## Switches

| Switch | Function       | Down       | Up         |
|--------|----------------|------------|------------|
| sw15   | audio          | on         | off        |
| sw14   | amplifier gain | low        | high       |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB |

## Clocks

| Clock                  | Original          | Basys 3               | Difference  |
|------------------------|-------------------|-----------------------|-------------|
| Main CPU (Z80)         | 2.496 MHz         | 2.500 MHz             | +0.16%      |
| Sound (Z80, AY-3-8910) | 2.000 MHz         | 2.000 MHz             | 0           |
| Video                  | 15 kHz interlaced | 31.546 kHz / 60.09 Hz | progressive |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `bally/mcr.cpp` (19.968 MHz main and 16 MHz sound board crystals).

## ROMs

`solarfox.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

