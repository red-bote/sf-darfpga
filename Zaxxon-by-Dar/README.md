# Zaxxon-by-Dar

Zaxxon (Gremlin / Sega, 1980) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 0.0 (2019-11-29):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/zaxxon/>,
copy in `dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Dar's core has no sound yet.

## Controls

| Function                 | Keyboard    | Joystick | Button     |
|--------------------------|-------------|----------|------------|
| up / down / left / right | arrows      | stick    |            |
| fire                     | Left Ctrl   | fire     |            |
| coin 1                   | 5           |          | btnU, btnD |
| coin 2                   | 6           |          |            |
| start 1 / 2              | 1, 2        |          | btnL, btnR |
| service                  | F2 (toggle) |          |            |
| flip screen              | F4 (toggle) |          |            |
| cocktail / upright       | F7 (toggle) |          |            |
| reset                    |             |          | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function                           | Down       | Up         |
|--------|------------------------------------|------------|------------|
| sw15   | audio                              | on         | off        |
| sw14   | amplifier gain                     | low        | high       |
| sw13   | display                            | 31 kHz VGA | 15 kHz RGB |
| sw12   | flip screen (inverts the F4 state) | flipped    | as F4      |

The game DIP settings are fixed inside Dar's core (1 coin 1 credit).

## Clocks

| Clock          | Original             | Basys 3              | Difference             |
|----------------|----------------------|----------------------|------------------------|
| Main CPU (Z80) | 3.041 MHz            | 3.041 MHz            | -0.004%                |
| Pixel          | 6.0825 MHz           | 6.0823 MHz           | -0.004%                |
| Sound          | discrete analog      | none (note 1)        | n/a                    |
| Video          | 15.84 kHz / 60.00 Hz | 31.68 kHz / 60.00 Hz | -0.004%, lines doubled |

Notes:

1. Dar's core does not implement the sound.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `sega/zaxxon.cpp` (48.66 MHz crystal).

## ROMs

`zaxxon.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- The scandoubler clock is register-derived inside the core (untimed path,
  `../KNOWN_ISSUES.md`); no hardware symptom.

## Changes to third-party sources

- `contrib/code/zaxxon_hflip_xor_width.patch`
  - Origin: Dar archive
  - Change: core: `hflip` XOR literal padded to 9 bits (Vivado)
  - Files:
    - `rtl_dar/zaxxon.vhd`

- `contrib/code/zaxxon_expose_video_timing.patch`
  - Origin: Dar archive
  - Change: core: drives `video_hs`/`video_vs`, exports `pix_clk_div` for the scandoubler
  - Files:
    - `rtl_dar/zaxxon.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

