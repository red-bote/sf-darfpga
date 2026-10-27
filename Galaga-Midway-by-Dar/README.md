# Galaga-Midway-by-Dar

Galaga (Namco / Midway, 1981) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.3 (2018-05-06):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/galaga/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/7 = right/left/fire; up/down unused).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function     | Keyboard  | Joystick     | Button     |
|--------------|-----------|--------------|------------|
| left / right | arrows    | left / right |            |
| fire         | Left Ctrl | fire         |            |
| coin         | 5, 6      |              | btnU, btnD |
| start 1 / 2  | 1, 2      |              | btnL, btnR |
| reset        |           |              | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function       | Down       | Up                  |
|--------|----------------|------------|---------------------|
| sw15   | audio          | on         | off                 |
| sw14   | amplifier gain | low        | high                |
| sw13   | display        | 31 kHz VGA | 15 kHz RGB          |
| sw12   | test mode      | off        | test / service mode |

## Clocks

| Clock         | Original            | Basys 3             | Difference    |
|---------------|---------------------|---------------------|---------------|
| CPUs (3x Z80) | 3.072 MHz           | 3.072 MHz           | -0.0008%      |
| Pixel         | 6.144 MHz           | 6.144 MHz           | -0.0008%      |
| Video         | 16.0 kHz / 60.61 Hz | 32.0 kHz / 60.61 Hz | lines doubled |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `namco/galaga.cpp` (18.432 MHz crystal).

## ROMs

`galaga.zip` and `galagamw.zip` (MAME romsets) in `~/roms/` or `$ROMZIP1` / `$ROMZIP2`.
Not included. Do not redistribute roms or anything generated from them.

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

- After a reset, the status tiles are sometimes distorted or missing pixels; under
  investigation.

## Changes to third-party sources

- `contrib/code/galaga_bgpalette_xor_length_fix.patch`
  - Origin: Dar archive
  - Change: background palette address: `xor` operand widths made equal (Vivado)
  - Files:
    - `rtl_dar/galaga.vhd`

- `contrib/code/galaga_credit_mode_fix.patch`
  - Origin: Dar archive
  - Change: start accepted after a coin (51xx credit mode re-enabled on each coin)
  - Files:
    - `rtl_dar/galaga.vhd`

- `contrib/code/galaga_vga_sync.patch`
  - Origin: Dar archive
  - Change: core outputs `video_hs` / `video_vs` for the scandoubler
  - Files:
    - `rtl_dar/galaga.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

