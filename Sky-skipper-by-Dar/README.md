# Sky-skipper-by-Dar (Basys 3 port)

Sky Skipper (Nintendo, 1981) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/sky_skipper_basys3.xpr` (top entity
  `sky_skipper_basys3`)
- Core clock: 40 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 40.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=1`,
  `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`.

## Features supported

- **Video**: native progressive 31 kHz (no scandoubler — the core drives the
  real `video_hs`/`video_vs` itself); display mode is selected by **sw(13)**
  (0 = 31 kHz VGA, 1 = 15 kHz TV) and toggled by **F8** (USB-HID keyboard), so a
  switch gives an out-of-the-box 31 kHz VGA image with no keyboard needed.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: USB-HID keyboard + JA joystick (OR-merged), 4 pushbuttons.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire A | Space |
| Fire B | F |
| Coin 1 | F1 |
| Coin 2 | F2 |
| Start 1 | F3 |
| Start 2 | F4 |
| Service | F7 |
| Display mode (31 kHz / 15 kHz) | F8 |

Pushbuttons (convenience for coin/start): btnU = Coin 1, btnD = Coin 2,
btnL = Start 1, btnR = Start 2.

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire (drives both Fire
  A and Fire B)

> **Keyboard is always on the Basys3 onboard USB-HID connector** (`ps2_clk` =
> C17, `ps2_dat` = B17) — plug the keyboard into the board's onboard USB-A
> port. This port does **not** use the JB PMOD. The onboard USB-HID host needs
> a ≥ 6 MHz keyboard sampling clock; here `io_ps2_keyboard`/`kbd_joystick` run
> directly on `clock_40` = 40 MHz (no divider), and the pristine 2 MHz
> `clock_kbd` divider is kept only to gate the PWM audio accumulator.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnD | `btnU` / `btnD` | coin1 / coin2 |
| btnL / btnR | `btnL` / `btnR` | start1 / start2 |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | — | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV (XOR F8 toggle) |
| Onboard USB HID host C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard — always on the onboard USB-HID connector (not JB) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz |
| LEDs | — | not used (no LED output in the core; the DE10 top's `ledr` is commented out) |

DIP switches (`sw1`/`sw2`) are hard-coded constants in the wrapper
(`sw1 = "0000000"` coinage, `sw2 = "00000010"` lives/difficulty), matching the
pristine DE10 top; the board switches are not wired to them.

## Scripted setup

`contrib/tools/setup_sky_skipper.sh` automates the manual steps below: it
fetches the Dar archive into the gitignored `dloads/` cache (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_sky_skipper_rev_01_2020_01_28/`, applies any
fix patches idempotently (none are needed for this core), then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_sky_skipper_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/skyskipr.zip`, pre/post-flight verified) and generate the PROM VHDL.
Run it via `make setup`.

Build steps (in order): `make setup create_prj clk_wiz patch synth bitstream`,
program with `make load` (existing bit) or `make rebuild-load` (fresh build
then program), remove the extracted/build tree with `make clean`.

## ROM set required

MAME ROM set `skyskipr.zip`, unzipped into `tools/sky_skipper_unzip/`:

```
~/roms/skyskipr.zip   ->   tools/sky_skipper_unzip/
```

Then run `./make_sky_skipper_proms.sh` from that directory to generate the PROM
VHDL (`sky_skipper_cpu.vhd`, `sky_skipper_ch_bits.vhd`,
`sky_skipper_sp_bits_1..4.vhd`, `sky_skipper_ch_palette_rgb.vhd`,
`sky_skipper_sp_palette_gb.vhd`, `sky_skipper_sp_palette_rg.vhd`,
`sky_skipper_bg_palette_rgb.vhd`). The Vivado project references these
generated files in place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.