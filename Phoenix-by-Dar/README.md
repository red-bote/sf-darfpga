# Phoenix-by-Dar

Phoenix (Amstar, 1980) on the Digilent Basys 3. FPGA core by Dar (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), DE10-lite release `vhdl_phoenix_DE10_lite.zip`:
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/phoenix/>, copy in
`dloads/`. Design detail: `contrib/basys3/PORTING_SPEC.md`.

## Connections

- VGA monitor; with sw13 up, 15 kHz RGB (csync on HS) for a 15 kHz monitor.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick on Pmod JXADC (pins 1/2/3/4/7 = right/left/down/up/fire).
- PmodAMP2 with speaker on Pmod JA. Mono.

## Controls

| Function     | Keyboard  | Joystick                   | Button     |
|--------------|-----------|----------------------------|------------|
| left / right | arrows    | left / right               |            |
| fire         | Left Ctrl | fire                       |            |
| shield       | Left Alt  | up; up + fire; down + fire |            |
| coin         | 5, 6      |                            | btnU, btnD |
| start 1 / 2  | 1, 2      |                            | btnL, btnR |
| reset        |           |                            | btnC       |

## Switches

| Switch | Function              | Down             | Up         |
|--------|-----------------------|------------------|------------|
| sw15   | audio                 | on               | off        |
| sw14   | amplifier gain        | low              | high       |
| sw13   | display               | 31 kHz VGA       | 15 kHz RGB |
| sw10-8 | audio select (note 1) | all sounds mixed | note 1     |
| sw7-0  | DIP (note 2)          | bit = 0          | bit = 1    |

Notes:

1. Audio select, sw10-8:
   - `000`: all sounds mixed
   - `100`: effect 1 only
   - `101`: effect 2 only
   - `110`: effect 3 only
   - `111`: melody only
2. DIP bits:
   - 7: cocktail
   - 6-5: unknown
   - 4: coinage
   - 3-2: bonus
   - 1-0: lives

## Clocks

| Clock            | Original              | Basys 3              | Difference    |
|------------------|-----------------------|----------------------|---------------|
| Main CPU (8085A) | 5.5 MHz               | 5.5 MHz              | 0             |
| Pixel            | 5.5 MHz               | 5.5 MHz              | 0             |
| Sound            | unknown (note 1)      | 10 MHz (note 1)      | n/a           |
| Video            | 15.625 kHz / 61.04 Hz | 31.25 kHz / 61.04 Hz | lines doubled |

Notes:

1. The original sound is analog circuitry. The core models it with a 10 MHz clock.

Basys 3 video values are for the VGA mode (sw13 down).

Original values: MAME `phoenix.cpp` (11 MHz crystal).

## ROMs

`phoenix.zip` (MAME romset) in `~/roms/` or `$ROMZIP`. Not included. Do not redistribute
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

- The scandoubler pixel enable is a register-derived clock from the core (untimed); no
  visible symptom (`../KNOWN_ISSUES.md`).

## Changes to third-party sources

- `contrib/code/phoenix_expose_hsync_vsync.patch`
  - Origin: Dar archive
  - Change: core outputs separate hsync / vsync for the scandoubler
  - Files:
    - `rtl_dar/phoenix_video.vhd`
    - `rtl_dar/phoenix.vhd`

- `contrib/code/phoenix_external_inputs.patch`
  - Origin: Dar archive
  - Change: `ext_joy` input for joystick and buttons (the core decodes PS/2 internally)
  - Files:
    - `rtl_dar/phoenix.vhd`

- `contrib/code/phoenix_sound_reset.patch`
  - Origin: Dar archive
  - Change: btnC resets the sound modules
  - Files:
    - `rtl_dar/phoenix.vhd`

- `contrib/code/scandoubler_fix.patch`
  - Origin: [mist-modules@147aa5c][mist-modules] (Till Harbaum, GPL-3.0)
  - Change: named blocks, full `sd_buffer` range (Vivado)
  - Files:
    - `scandoubler.v` (copy in `contrib/code/`)

[mist-modules]: https://github.com/mist-devel/mist-modules/blob/147aa5c11b117eaeda3fd9e81dbff2dc5f12cb14/scandoubler.v

