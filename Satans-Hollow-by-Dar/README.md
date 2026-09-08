# Satans-Hollow-by-Dar (Basys 3 port)

Satan's Hollow (Bally Midway MCR, 1981) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/satans_hollow_basys3.xpr` (top entity
  `satans_hollow_basys3`)
- Core clock: 40 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 40.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=1`,
  `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`.

## Features supported

- **Video**: native progressive 31 kHz (no scandoubler — the core drives the
  real `video_hs`/`video_vs` itself); display mode is selected by **sw(13)**
  (0 = 31 kHz VGA, 1 = 15 kHz TV) and toggled by **F8** (USB-HID keyboard), so a
  switch gives an out-of-the-box 31 kHz VGA image with no keyboard needed.
- **Sound**: mono PWM audio on PmodAMP2 (left channel of the core's stereo
  audio out; the right accumulator is kept in lockstep but not wired to the
  mono amp).
- **Controls**: USB-HID keyboard + JA joystick (OR-merged), 4 pushbuttons.

| Input | Keyboard |
|-------|----------|
| Move | Left / Right arrow |
| Shield | Up arrow |
| Fire | Space |
| Coin 1 | F1 |
| Start 1 | F2 |
| Start 2 | F3 |
| Service (also toggles separate audio) | F5 |
| Display mode (31 kHz / 15 kHz) | F8 |

Pushbuttons (convenience for coin/start): btnU = Coin 1, btnD = Coin 2,
btnL = Start 1, btnR = Start 2.

JA joystick (active-low, switch to GND):
- JA1 = Left, JA2 = Right, JA4 = Shield, JA7 = Fire (JA3 unused)

JA fire drives fire1; JA4 drives fire2 (shield), OR-merged with keyboard Up.

> **Keyboard is always on the Basys3 onboard USB-HID connector** (`ps2_clk` =
> C17, `ps2_dat` = B17) — plug the keyboard into the board's onboard USB-A
> port. This port does **not** use the JB PMOD. The onboard USB-HID host needs
> a ≥ 6 MHz keyboard sampling clock; here `io_ps2_keyboard`/`kbd_joystick` run
> directly on `clock_40` = 40 MHz (no divider), and the pristine 2 MHz
> `clock_kbd` divider is kept only to gate the PWM audio accumulators.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnD | `btnU` / `btnD` | coin1 / coin2 (btnD convenience — pristine coin2 tied low) |
| btnL / btnR | `btnL` / `btnR` | start1 / start2 |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | — | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV (XOR F8 toggle) |
| Onboard USB HID host C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard — always on the onboard USB-HID connector (not JB) |
| JA1, JA2, JA4, JA7 | `JA(0)`, `JA(1)`, `JA(3)`, `JA(4)` | joystick (active-low): left, right, shield, fire (JA3 / `JA(2)` unused) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz |
| LEDs | — | not used (the DE10 top's `ledr` is commented out; `dbg_cpu_addr` left open) |

## Scripted setup

`contrib/tools/setup_satans_hollow.sh` automates the manual steps below: it
fetches the Dar archive into the gitignored `dloads/` cache (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_satans_hollow_rev_0_2_2019_11_22/`, applies any
fix patches idempotently (none are needed for this core), then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_satans_hollow_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/shollow.zip`, pre/post-flight verified), rename
`82s123.12d` → `midssio_82s123.12d` and generate the PROM VHDL. Run it via
`make setup`.

Build steps (in order): `make setup create_prj clk_wiz patch synth bitstream`,
program with `make load` (existing bit) or `make rebuild-load` (fresh build
then program), remove the extracted/build tree with `make clean`.

## ROM set required

MAME ROM set `shollow.zip` (a single set), unzipped into
`tools/satan_hollow_unzip/`:

```
~/roms/shollow.zip   ->   tools/satan_hollow_unzip/
```

The set includes the midssio sound-I/O PROM as `82s123.12d`; `prep_roms.sh`
renames it to `midssio_82s123.12d` (the name the `.bat` uses). Then run
`./make_satans_hollow_proms.sh` from that directory to generate the PROM VHDL
(`satans_hollow_cpu.vhd`, `satans_hollow_sound_cpu.vhd`,
`satans_hollow_bg_bits_1.vhd`, `satans_hollow_bg_bits_2.vhd`,
`satans_hollow_sp_bits.vhd`, `midssio_82s123.vhd`). The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.