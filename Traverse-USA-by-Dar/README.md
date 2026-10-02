# Traverse-USA-by-Dar (Basys 3 port)

Traverse USA / Zippy Race (Irem M-52, 1983) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/traverse_usa_basys3.xpr` (top entity
  `traverse_usa_basys3`)
- Core clock: 36.842105 MHz (core) + 3.5795454 MHz (sound board), from the
  100 MHz Basys 3 oscillator via `clk_wiz_0`
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 36.842105 MHz
  (`clock_36`), `clk_out2` = 7.159091 MHz (`clock_7p16`; D 1 / M 7.875 /
  O0 21.375 / O1 110, VCO 787.5 MHz), divided by 2 in fabric to
  3.5795454 MHz (`clock_3p58`); reset active-high (btnC), `locked` used.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`). sw(13) switches to 15 kHz TV mode (native
  RGB + composite sync on HS). The pristine core only drove composite sync
  (`video_csync`); `traverse_usa_expose_video_timing.patch` un-comments the
  core's dormant `video_hs`/`video_vs` drivers (a real `hsync0` line pulse
  and a `vsync_cnt`-based `video_vs` pulse) — see
  `contrib/basys3/PORTING_SPEC.md` §4 for the full derivation.
- **Scan doubler source**: MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>;
  tracked as `contrib/code/scandoubler.v`, copied into the project by
  `create_project.sh`.
- **Sound**: mono (left-channel) PWM audio on PmodAMP2.
- **Controls**: USB-HID keyboard + JA joystick (OR-merged); dedicated buttons
  for coin/start (btnU/btnD = coin, btnL = start 1, btnR = start 2), btnC =
  reset. The core has no genuine fire input — accelerate and fire map to the
  same core port.

> **Keyboard is always on the Basys3 onboard USB-HID connector** (`ps2_clk` =
> C17, `ps2_dat` = B17) — plug the keyboard into the board's onboard USB-A
> port. This port does **not** use the JB PMOD or any external PS/2
> connector (unlike Galaga/Popeye/Tron/Defender, which put the keyboard on
> JB). The onboard USB-HID host needs a ≥ 6 MHz keyboard sampling clock; the
> pristine core's ~3 MHz divider is too slow, so this port drives
> `io_ps2_keyboard` with a dedicated `clock_kbd` at ~6.14 MHz (mod-3 on
> `clock_36`).

| Input | Keyboard |
|-------|----------|
| Accelerate | Up / Space |
| Brake | Down |
| Steer left / right | Left / Right arrows |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down (brake), JA4 = Up (accelerate),
  JA7 = Fire (accelerate)
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
| sw(13) | `sw(13)` | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV |
| Onboard USB HID host C17 / B17 | `ps2_clk` / `ps2_dat` | keyboard — always on the onboard USB-HID connector (not JB) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (mono/left channel; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`contrib/tools/setup_traverse_usa.sh` automates the manual steps below: it
fetches the Dar archive into the gitignored `dloads/` cache (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing
or tampered), extracts it as `vhdl_traverse_usa_rev_0_0_2019_03_16/`, applies
`contrib/code/traverse_usa_expose_video_timing.patch`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_travusa_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/travrusa.zip`) and generate the PROM VHDL. Run it via `make setup`.

The remaining steps are wrapped by the machine `Makefile`: `make create_prj`
(copies `traverse_usa_basys3.xpr` and `Basys-3-Master.xdc` into the extracted
tree, imports `scandoubler.v`), `make clk_wiz` (generates the `clk_wiz_0`
MMCM IP wrappers), `make patch` (regenerates
`traverse_usa_de10_lite_to_basys3.patch` and places `traverse_usa_basys3.vhd`),
then `make synth` / `make bitstream` (Vivado batch runs; logs stay outside
the repo). `make load` programs the bitstream into the Basys 3 SRAM with
openFPGALoader.

## ROM set required

MAME ROM set `travrusa.zip`, unzipped into `tools/travusa_unzip/`:

```
~/roms/travrusa.zip   ->   tools/travusa_unzip/
```

Then run `./make_travusa_proms.sh` from that directory to generate the PROM
VHDL (`travusa_cpu.vhd`, `travusa_chr_bit1/2/3.vhd`, `travusa_chr_palette.vhd`,
`travusa_spr_bit1/2/3.vhd`, `travusa_spr_palette.vhd`,
`travusa_spr_rgb_lut.vhd`, `travusa_sound.vhd`). The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

ROMs are copyrighted — never commit or redistribute them.

## Applying the video-timing exposure fix

The pristine core declares `video_hs`/`video_vs` output ports but leaves the
drivers commented out (a noted "not tested" in the DE10 top) — only
`video_csync` is active in the shipped core. `traverse_usa_expose_video_timing.patch`
un-comments the dormant drivers:

```vhdl
video_hs <= hsync0;
if    vsync_cnt = 0 then video_vs <= '0';
elsif vsync_cnt = 8 then video_vs <= '1';
end if;
```

`video_hs` is the core's real per-line `hsync0` pulse; `video_vs` is built
from the existing `vsync_cnt` (a feedback counter used by the composite-sync
generator), low at the line `vsync_cnt = 0` and high from `vsync_cnt = 8` —
a 1-line low pulse inside the existing vertical-blanking window. Verify the
patch took:

```
grep -n 'video_hs <= hsync0' vhdl_traverse_usa_rev_0_0_2019_03_16/rtl_dar/traverse_usa.vhd
```

## Known issues

- **USB-HID keyboard**: this port originally reproduced the fleet-wide symptom
  where the Basys 3 onboard USB-HID host read nothing — root cause the pristine
  keyboard sampling clock too slow for the onboard port. Fixed by giving
  `io_ps2_keyboard` a keyboard-only `clock_kbd` at ~6.14 MHz (mod-3 on
  `clock_36`, ≥ 6 MHz required). Ensure the keyboard is plugged into the
  onboard USB-A connector (C17/B17) — the JB PMOD and any external PS/2 port
  are not used.

## Build status

The port is fully scripted and documented (steps runnable end to end), and
synthesizes cleanly (0 errors, 0 critical warnings). Hardware bring-up has been
performed on the Basys 3; the onboard USB-HID keyboard path is confirmed
functional on this board (see the root `README.md` Status section). Ensure the
keyboard is plugged into the onboard USB-A connector — not JB.
