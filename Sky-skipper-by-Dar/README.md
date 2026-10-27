# Sky-skipper-by-Dar

Sky Skipper (Nintendo, 1981) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), rev 01 (2020-01-28):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/sky_skipper/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz interlaced RGB for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function                 | Keyboard  | Joystick      | Button     |
|--------------------------|-----------|---------------|------------|
| up / down / left / right | arrows    | stick         |            |
| speed up                 | Left Ctrl | any direction |            |
| bomb                     | Left Alt  | fire          |            |
| coin 1 / 2               | 5, 6      |               | btnU, btnD |
| start 1 / 2              | 1, 2      |               | btnL, btnR |
| service                  | 9 (held)  |               |            |
| reset                    |           |               | btnC       |

Player 2 uses the same controls.

## Switches

| Switch | Function                      | Down             | Up           |
|--------|-------------------------------|------------------|--------------|
| sw15   | audio                         | on               | off          |
| sw14   | amplifier gain                | low              | high         |
| sw13   | display                       | 31 kHz VGA       | 15 kHz RGB   |
| sw11-8 | DIP 1 coinage DCBA (bits 3-0) | original default | bit inverted |
| sw7-0  | DIP 2 (note 1)                | bit = 0          | bit = 1      |

Notes:

1. DIP 2 settings:
   - cocktail
   - service 2
   - bonus
   - difficulty (3 bits)
   - lives (2 bits)

## Clocks

| Clock             | Original           | Basys 3               | Difference          |
|-------------------|--------------------|-----------------------|---------------------|
| Main CPU (Z80)    | 4.000 MHz          | 4.032 MHz             | +0.8%               |
| Sound (AY-3-8910) | 2.000 MHz          | 2.016 MHz             | +0.8%               |
| Video             | unknown / 59.94 Hz | 31.500 kHz / 59.89 Hz | -0.09% (frame rate) |

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `nintendo/popeye.cpp` (same board as Popeye, 8.000 MHz crystal).

## ROMs

`skyskipr.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- `contrib/code/sky_skipper_clock_cnt2_width.patch`
  - Origin: Dar archive
  - Change: CPU and AY clock divider widened to 5 bits (rates were 25% fast)
  - Files:
    - `rtl_dar/sky_skipper.vhd`

