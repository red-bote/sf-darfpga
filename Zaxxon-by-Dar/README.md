# Zaxxon-by-Dar (Basys 3 port)

Zaxxon (Gremlin/Sega, 1980) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/zaxxon_basys3.xpr` (top entity
  `zaxxon_basys3`)
- Core clock: 24 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 24.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=50.250`, `CLKOUT0_DIVIDE_F=41.875`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`). sw(13) switches to 15 kHz TV mode (native
  RGB + composite sync on HS). The pristine core only drove composite sync
  (`video_csync`); `zaxxon_expose_video_timing.patch` adds real
  `video_hs`/`video_vs` drivers plus a `pix_clk_div` output exposing the
  core's real 12/6 MHz clock bits for the scandoubler's `clk_sys`/`ce_x1` —
  see `contrib/basys3/PORTING_SPEC.md` §4 for the full derivation.
- **Sound**: mono (left-channel) PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard + JA joystick (OR-merged); dedicated buttons
  for coin/start (btnU/btnD = coin, btnL = start 1, btnR = start 2), btnC =
  reset.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Fire | Space |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |
| Flip screen | F4 |
| Service | F5 |
| Cocktail/upright | F7 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
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
| JB1 / JB3 | `ps2_dat` / `ps2_clk` | PS/2 keyboard |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (mono/left channel; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`contrib/tools/setup_zaxxon.sh` automates the manual steps below: it fetches
the Dar archive into the gitignored `dloads/` cache (reused when its SHA-256
matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_zaxxon_rev_0_0_2019_11_29/`, applies
`contrib/code/zaxxon_hflip_xor_width.patch` and
`contrib/code/zaxxon_expose_video_timing.patch`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_zaxxon_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/zaxxon.zip`) and generate the PROM VHDL. Run it via `make setup`.

The remaining steps are wrapped by the machine `Makefile`: `make create_prj`
(copies `zaxxon_basys3.xpr` and `Basys-3-Master.xdc` into the extracted tree,
imports `scandoubler.v`), `make clk_wiz` (generates the `clk_wiz_0` MMCM IP
wrappers), `make patch` (regenerates `zaxxon_de10_lite_to_basys3.patch` and
places `zaxxon_basys3.vhd`), then `make synth` / `make bitstream` (Vivado
batch runs; logs stay outside the repo).

## ROM set required

MAME ROM set `zaxxon.zip`, unzipped into `tools/zaxxon_unzip/`:

```
~/roms/zaxxon.zip   ->   tools/zaxxon_unzip/
```

Then run `./make_zaxxon_proms.sh` from that directory to generate the PROM
VHDL (`zaxxon_cpu.vhd`, `zaxxon_char_bits_1/2.vhd`, `zaxxon_bg_bits_1/2/3.vhd`,
`zaxxon_sp_bits_1/2/3.vhd`, `zaxxon_map_1/2.vhd`, `zaxxon_palette.vhd`,
`zaxxon_char_color.vhd`). The Vivado project references these generated files
in place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Applying the hflip XOR-width fix

The pristine Dar core (`vhdl_zaxxon_rev_0_0_2019_11_29/rtl_dar/zaxxon.vhd`)
fails Vivado synthesis on `hflip2`'s assignment: the literal
`(not(hcnt(8)) & "0000000")` is only 8 bits wide, but `hflip`/`hflip2` are
9-bit signals. The fix left-pads the literal to 9 bits:

```vhdl
hflip2 <= hflip xor ("0" & not(hcnt(8)) & "0000000") when flip = '1' else hflip;
```

`zaxxon_hflip_xor_width.patch` in `contrib/code/` applies that change to the
unmodified Dar source. Verify it took:

```
grep -n '"0" & not(hcnt(8))' vhdl_zaxxon_rev_0_0_2019_11_29/rtl_dar/zaxxon.vhd
```

## Applying the video-timing exposure fix

The pristine core declares `video_hs`/`video_vs` output ports but never
drives them anywhere in the architecture (only `video_csync` is real, built
from a composite-sync generator with equalizing/serration pulses) — no VGA
display resulted until this was fixed. `zaxxon_expose_video_timing.patch`
adds:

```vhdl
video_hs <= hsync0;                        -- already a valid per-line pulse
video_vs <= '0' when vcnt < 8 else '1';    -- new simple pulse in the existing blanking window
pix_clk_div <= clock_cnt(1 downto 0);      -- exposes the core's real 12/6 MHz clock bits
```

`pix_clk_div` feeds the Basys3 wrapper's scandoubler `clk_sys`/`ce_x1`
directly from the core's own clock divider rather than a locally mirrored
counter — see `contrib/basys3/PORTING_SPEC.md` §4 for the full derivation,
including the Galaga-precedent finding that a fast clock fed directly into
`clk_sys` does not work for this scandoubler module. Verify the patch took:

```
grep -n 'pix_clk_div' vhdl_zaxxon_rev_0_0_2019_11_29/rtl_dar/zaxxon.vhd
```

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25, on the pre-conversion legacy JB1/JB3 PS/2 keyboard
  build). Same pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar,
  Kick-Midway-MCR-by-Dar, Tron-by-Dar, and Popeye-by-Dar. Not yet
  investigated; deferred at the user's request. See root `KNOWN_ISSUES.md`.

## Build status

The port is fully scripted (`make setup create_prj clk_wiz patch synth
bitstream`). Hardware bring-up is complete: a bitstream has been built and
the port runs correctly on the Basys 3 board.
