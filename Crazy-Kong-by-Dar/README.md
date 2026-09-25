# Crazy-Kong-by-Dar (Basys 3 port)

Crazy Kong (Crazy-Climber-derived hardware, Kyoei/Falcon, 1981; per MAME's
`cclimber.cpp` driver and Dar's `README.txt`, the core plays Crazy Kong
Part II / Falcon) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/ckong_basys3.xpr` (top entity `ckong_basys3`)
- Core clock: 12 MHz, from the 100 MHz Basys 3 oscillator via `clk_wiz_0`
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 12 MHz
  (`clock_12`), used for everything (core, sound, PWM audio, keyboard).
  Reset active-high (btnC), `locked` used. MMCM settles at VCO 997.5 MHz /
  output divide 83.125.

## Features supported

- **Video**: native 31 kHz progressive VGA. Unlike Galaga/Traverse-USA there
  is **no external scandoubler** — the pristine core instantiates its own
  `line_doubler` and drives real `video_hs`/`video_vs` in
  `tv15Khz_mode = '0'` (see `PORTING_SPEC.md` §3). sw(13) switches to 15 kHz
  TV mode (native RGB + composite sync on HS).
- **Sound**: mono PWM audio on PmodAMP2. Reproduces the pristine top's 13-bit
  accumulator on `clock_12` feeding bits `audio(15 downto 4)`.
- **Controls**: USB-HID keyboard + JA joystick (OR-merged); dedicated buttons
  for coin/start (btnU/btnD = coin, btnL = start 1, btnR = start 2), btnC =
  reset.

> **Keyboard is always on the Basys3 onboard USB-HID connector** (`ps2_clk` =
> C17, `ps2_dat` = B17) — plug the keyboard into the board's onboard USB-A
> port. This port does **not** use the JB PMOD (unlike Galaga/Popeye/Tron/
> Defender). The onboard USB-HID host needs a ≥ 6 MHz keyboard sampling clock;
> the pristine top already clocks `io_ps2_keyboard` at `clock_12` = 12 MHz, so
> this port needs **no divider** (unlike Traverse-USA, whose shared pristine
> divider was ~3 MHz).

| Input | Keyboard |
|-------|----------|
| Move left / right | Left / Right arrows |
| Jump (fire) | Space |
| Additional fire | Ctrl / W |
| Coin | F3 |
| Start 1 | F1 |
| Start 2 | F2 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire (jump)
- No coin/start combos on JA — dedicated buttons handle that (see below).
- Player 2 mirrors player 1 inputs (the core has no genuine second control
  set, only cocktail-mode duplicates).

Buttons (active-high, Basys3 board pull-down, same convention as btnC):
- btnU = coin-in, btnD = coin-in (this core has a single coin input; both
  buttons trigger it)
- btnL = start 1, btnR = start 2, btnC = reset

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnD | `btnU` / `btnD` | coin-in |
| btnL / btnR | `btnL` / `btnR` | start 1 / start 2 |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | `sw(13)` | display mode: 0 = 31 kHz VGA (internal line doubler), 1 = 15 kHz TV |
| Onboard USB HID host C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard — always on the onboard USB-HID connector (not JB) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (mono; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`contrib/tools/setup_ckong.sh` automates the manual steps below: it fetches
the Dar archive into the gitignored `dloads/` cache (reused when its SHA-256
matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_ckong_rev_0_1_2018_06_06/`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_ckong_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/ckong.zip`) and generate the PROM VHDL. The one synthesis-fix patch
(`contrib/code/ckong_xor_width.patch`) is applied idempotently: a 13-bit vs
5-bit `xor` length mismatch in `ckong.vhd:405-408`, fixed exactly like
`bagman_xor_width.patch` (same video-addressing code, constants zero-padded to
13 bits — no behavior change). No video-path patch is needed (native
progressive video, keyboard already at 12 MHz). Run it via `make setup`.

The remaining steps are wrapped by the machine `Makefile`: `make create_prj`
(copies `ckong_basys3.xpr` and `Basys-3-Master.xdc` into the extracted tree —
no scandoubler import), `make clk_wiz` (generates the `clk_wiz_0` MMCM IP
wrappers), `make patch` (regenerates `ckong_de10_lite_to_basys3.patch` and
places `ckong_basys3.vhd`), then `make synth` / `make bitstream` (Vivado
batch runs; logs stay outside the repo). `make load` programs the bitstream
into the Basys 3 SRAM with openFPGALoader.

## ROM set required

MAME ROM set `ckong.zip`, unzipped into `tools/ckong_unzip/`:

```
~/roms/ckong.zip   ->   tools/ckong_unzip/
```

Then run `./make_ckong_proms.sh` from that directory to generate the PROM
VHDL (all 8, with the exact entity names the core references):
`ckong_program.vhd`, `ckong_tile_bit0.vhd`, `ckong_tile_bit1.vhd`,
`ckong_big_sprite_tile_bit0.vhd`, `ckong_big_sprite_tile_bit1.vhd`,
`ckong_palette.vhd`, `ckong_big_sprite_palette.vhd`, `ckong_samples.vhd`.
The Vivado project references these generated files in place, so the build
needs only the staged ROMs + the script.

Dar's `README.txt` suggests the ckongpt2 (Crazy Kong Part II / Falcon)
contents; the `.bat`'s 17 input file names are all present in the `ckong`
parent set (`~/roms/ckong.zip`), which this port stages.

ROMs are copyrighted — never commit or redistribute them.

## Build status

Hardware-verified on the Basys 3 (bitstream 2026-09-07; 0 critical
warnings/errors through implementation; post-route WNS = 36.461 ns). See the
root `README.md` Status section, which is the current record of each machine's
verified state.