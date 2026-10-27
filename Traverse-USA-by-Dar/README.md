# Traverse-USA-by-Dar

Traverse USA / Zippy Race (Irem M-52, 1983) on the Digilent Basys 3. FPGA core by Dar
(darfpga@aol.fr, <http://darfpga.blogspot.fr>), rev 0.0 (2019-03-16):
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/traverse_usa/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function           | Keyboard            | Joystick     | Button     |
|--------------------|---------------------|--------------|------------|
| steer left / right | Left / Right arrows | left / right |            |
| accelerate         | Left Ctrl           | fire         |            |
| brake              | Left Alt            | down         |            |
| coin               | 5, 6                |              | btnU, btnD |
| start 1 / 2        | 1, 2                |              | btnL, btnR |
| reset              |                     |              | btnC       |

Player 2 uses the same controls. Down + fire brakes and accelerates.

## Switches

| Switch | Function       | Down             | Up           |
|--------|----------------|------------------|--------------|
| sw15   | audio          | on               | off          |
| sw14   | amplifier gain | low              | high         |
| sw13   | display        | 31 kHz VGA       | 15 kHz RGB   |
| sw11-8 | DIP 1 (note 1) | original default | bit inverted |
| sw7-0  | DIP 2 (note 2) | original default | bit inverted |

Notes:

1. DIP 1 bits:
   - 3: continue play
   - 2: fuel consumption
   - 1-0: fuel lost on collision
2. DIP 2 bits:
   - 7: diag
   - 6: demo
   - 5: Zippy
   - 4: freeze
   - 3: M/Km
   - 2: coin mode
   - 1: cocktail
   - 0: flip

## Clocks

| Clock          | Original            | Basys 3              | Difference            |
|----------------|---------------------|----------------------|-----------------------|
| Main CPU (Z80) | 3.072 MHz           | 3.0702 MHz           | -0.06%                |
| Pixel          | 6.144 MHz           | 6.1404 MHz           | -0.06%                |
| Sound (note 1) | 3.579545 MHz        | 3.579545 MHz         | 0                     |
| Video          | 16.0 kHz / 56.74 Hz | 31.98 kHz / 56.70 Hz | -0.06%, lines doubled |

Notes:

1. Sound board: M6803 CPU and 2x AY-3-8910.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `irem/travrusa.cpp`, `irem/irem.cpp` (18.432 MHz and 3.579545 MHz
crystals).

## ROMs

`travrusa.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- The sound board clock and the scandoubler clock are separate, partly register-derived
  clock domains (untimed paths, `../KNOWN_ISSUES.md`); no hardware symptom.

## Changes to third-party sources

- `contrib/code/traverse_usa_expose_video_timing.patch`
  - Origin: Dar archive
  - Change: core: enables the dormant `video_hs`/`video_vs` for the scandoubler
  - Files:
    - `rtl_dar/traverse_usa.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

