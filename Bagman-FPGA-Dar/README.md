# Bagman-FPGA-Dar (Basys 3 port)

Bagman (Stern, 1982) by Dar (`darfpga@aol.fr`, http://darfpga.blogspot.fr).
Basys 3 (Artix-7) port by Red~Bote. See `README.txt` in the extracted source
archive for the original Dar release notes.

- Vivado 2020.2 project: `basys3/bagman_basys3.xpr` (top entity `bagman_basys3`)
- Core clock: 12 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 12.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=49.875`, `CLKOUT0_DIVIDE_F=83.125`.

## Features supported

- **Video**: display mode selected by sw(13): 0 = 31 kHz progressive VGA
  (scan doubling built into the core), 1 = 15 kHz TV mode (native rate,
  composite sync on HS — needs a 15 kHz monitor or RGB→composite converter).
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (OR-merged), btnC =
  reset. Hardware-confirmed 2026-09-25: USB-HID keyboard working.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Jump | Space |
| Coin | F3 |
| Start 1 | F1 |
| Start 2 | F2 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Jump
- Coin = Fire + Up together; Start 1 = Fire + Left together
- Player 2 mirrors player 1 inputs.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | — | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV (csync on HS) |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz |

## Scripted setup

`contrib/tools/setup_bagman.sh` automates the manual steps below: it fetches the
Dar archive into the gitignored `dloads/` cache (reused when its SHA-256 matches
the hash embedded in the script; re-downloaded when missing or tampered),
extracts it as `vhdl_bagman_rev_0_1_2018_06_05/`, applies
`contrib/code/bagman_xor_width.patch`, then runs `contrib/tools/prep_roms.sh` to
compile `make_vhdl_prom`, convert `make_bagman_proms.bat`, stage the romset from
`$ROMZIP` (default `~/roms/bagman.zip`) and generate the PROM VHDL. Run it via
`make setup`.

The remaining steps are wrapped by the machine `Makefile`: `make create_prj`
(copies `bagman_basys3.xpr` and `Basys-3-Master.xdc` into the extracted tree),
`make clk_wiz` (generates the `clk_wiz_0` MMCM IP wrappers),
`make patch` (regenerates `bagman_de10_lite_to_basys3.patch` and places
`bagman_basys3.vhd`), then `make synth` / `make bitstream` (Vivado batch runs;
logs stay outside the repo).

## ROM set required

MAME ROM set `bagman.zip`, unzipped into `tools/bagman_unzip/`:

```
~/roms/bagman.zip   ->   tools/bagman_unzip/
```

Then run `./make_bagman_proms.sh` from that directory to generate the PROM VHDL
(`bagman_program.vhd`, `bagman_tile_bit0/1.vhd`, `bagman_palette.vhd`,
`bagman_speech1/2.vhd`). The Vivado project references these generated files in
place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Applying the XOR-width fix

The pristine Dar core (`vhdl_bagman_rev_0_1_2018_06_05/rtl_dar/bagman.vhd`)
fails Vivado synthesis on the `tile_graph_rom_addr` XORs because the
`"00000"`/`"01000"`/`"10111"`/`"11111"` literals are narrower than the left
operand. The fix left-pads them to 13 bits:

```vhdl
when "00" => tile_graph_rom_addr <= ... xor "0000000000000"; --TBA
when "01" => tile_graph_rom_addr <= ... xor "0000000001000"; --TBA
when "10" => tile_graph_rom_addr <= ... xor "0000000010111"; --TBA
when "11" => tile_graph_rom_addr <= ... xor "0000000011111"; --TBA
```

`bagman_xor_width.patch` in this directory applies that change to the
unmodified Dar source. From the `Bagman-FPGA-Dar/` directory (containing
`vhdl_bagman_rev_0_1_2018_06_05/`):

```
patch -p1 < bagman_xor_width.patch
```

Verify it took:

```
grep -n 'xor "0000000000000"' vhdl_bagman_rev_0_1_2018_06_05/rtl_dar/bagman.vhd
```

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25, on the hardware-confirmed USB-HID build). Same
  pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar,
  Kick-Midway-MCR-by-Dar, Tron-by-Dar, Zaxxon-by-Dar, Popeye-by-Dar, and
  Berzerk-FPGA-by-Dar. Not yet investigated; deferred at the user's request.
  See root `KNOWN_ISSUES.md`.

