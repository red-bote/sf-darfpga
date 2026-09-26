# Burger-Time-by-Dar (Basys 3 port)

Burger Time (Data East, 1982) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/burger_time_basys3.xpr` (top entity
  `burger_time_basys3`)
- Core clock: 12 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 12.000 MHz +
  `clk_out2` = 6.000 MHz; reset active-high (btnC), `locked` used. Solved
  MMCM: `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=7.5`, `CLKOUT0_DIVIDE_F=62.5`,
  `CLKOUT1_DIVIDE=125`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`, tracked under `contrib/code/scandoubler.v`).
  sw(13) switches to 15 kHz TV mode (native RGB + composite sync on HS).
- **Scan doubler wiring**: see `contrib/basys3/PORTING_SPEC.md` (same core
  family and wiring as Burnin-Rubber).
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (OR-merged); buttons
  btnU = coin-in, btnL/btnR = start 1/2, btnC = reset. **No fire+direction combos**
  for coin/start (root `PORTING_SPEC.md` policy). Hardware-confirmed 2026-09-25:
  USB-HID keyboard working, display OK (no video defects observed).

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Pepper (fire) | Space |
| Coin | F3 |
| Start 1 | F1 |
| Start 2 | F2 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire (pepper)
- Player 2 mirrors player 1 inputs.

Buttons (active-high):
- btnU = coin-in, btnL = start 1, btnR = start 2, btnC = reset

Coin/start come only from the keyboard (F3/F1/F2) or the dedicated buttons
(btnU/btnL/btnR) — no joystick fire+direction combos.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU | `btnU` | coin-in, OR-merged with keyboard F3 |
| btnL / btnR | `btnL` / `btnR` | start 1 / start 2, OR-merged with F1 / F2 |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | `sw(13)` | display mode: 0 = VGA, 1 = 15 kHz TV |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`contrib/tools/setup_burger_time.sh` automates the manual steps below: it
fetches the Dar archive into the gitignored `dloads/` cache (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_burger_time_rev_0_0_2017_12_27/`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_burger_time_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/btime.zip`) and generate the PROM VHDL. Run it via `make setup`. Note:
the source archive was already downloaded and extracted in this repo; the
setup script uses the cached copy in `dloads/`.

## ROM set required

MAME ROM set `btime.zip`, unzipped into `tools/burger_time_unzip/`:

```
~/roms/btime.zip   ->   tools/burger_time_unzip/
```

Then run `./make_burger_time_proms.sh` from that directory to generate the
PROM VHDL (`burger_time_prog.vhd`, `bg_map.vhd`, `bg_graphx_1/2/3.vhd`,
`fg_sp_graphx_1/2/3.vhd`, `burger_time_sound_prog.vhd`). The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Build status

The port is fully scripted (`make setup create_prj clk_wiz patch`; `make
synth` / `make bitstream` for a Vivado run). Port assets are authored end to
end from the Burnin-Rubber reference (same core family). Hardware bring-up
(Vivado synthesis/bitstream) has not yet been run.
