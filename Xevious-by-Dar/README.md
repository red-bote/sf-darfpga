# Xevious-by-Dar (Basys 3 port)

Xevious (Namco, 1982) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port. See `README.txt` in the
extracted source archive for the original Dar release notes.

- Vivado 2020.2 project: `basys3/xevious_basys3.xpr` (top entity
  `xevious_basys3`)
- Core clock: 18 MHz (pixel clock 6 MHz, `ena_vidgen`); the PS/2 keyboard
  decoder runs on 11 MHz — both from the 100 MHz Basys 3 oscillator via
  `clk_wiz_0`
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): request `clk_out1` =
  18 MHz + `clk_out2` = 11 MHz. Exact integer division for both from one MMCM
  is impossible (lcm(18,11)=198); Vivado picks a VCO near 1100 MHz giving
  ~18.03 MHz and ~11.00 MHz. Record the actual frequencies from the generated
  wrapper. See `contrib/basys3/PORTING_SPEC.md`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`). The core produces genuine separate
  hsync/vsync (exposed by `contrib/code/xevious_expose_hsync_vsync.patch`),
  so the scandoubler is fed directly. sw(13) switches to 15 kHz TV mode
  (native RGB + composite sync on HS, reproducing the pristine DE10-lite
  top's own output path). See `contrib/basys3/PORTING_SPEC.md` for the full
  design record.
- **Sound**: mono PWM audio on PmodAMP2; `sw(14)` = AMP shutdown/enable,
  `sw(15)` = AMP gain.
- **Controls**: JA joystick + PS/2 keyboard (JB), OR-merged. Xevious has an
  "up" (move flight path up) control but no "down" control; "down" is
  keyboard-only. Dedicated buttons: btnU = coin, btnL = start1, btnR = start2.

| Input | JA pin | Keyboard |
|-------|--------|----------|
| Right | JA1 | Right arrow |
| Left | JA2 | Left arrow |
| Up | JA4 | Up arrow |
| (Down — no core control) | — | Down arrow (no effect) |
| Fire | JA7 | Space |
| Bomb | JA3 | Ctrl |
| Coin | btnU | F3 |
| Start 1 | btnL | F1 |
| Start 2 | btnR | F2 |

JA is active-low (pressed shorts to ground); the wrapper inverts each signal
so a press reads active-high, matching the core boundary, and OR-merges with
the keyboard.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnL / btnR | `btnU`/`btnL`/`btnR` | coin / start1 / start2 |
| JA1-4,7 | `JA(0..4)` | right, left, up, fire, bomb (down unused) |
| JB1 / JB3 | `ps2_dat` / `ps2_clk` | PS/2 keyboard |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| sw(13) | `sw(13)` | display mode: 0 = VGA, 1 = 15 kHz TV |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown/enable: 0 = off, 1 = on |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| VGA | `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

Dip switches are hardcoded in the core (no `sw` mapping), matching the
pristine DE10 top's `b_test => '1'`, `b_svce => '1'`.

## Scripted setup

`contrib/tools/setup_xevious.sh` automates the manual steps: it fetches the
Dar archive into the gitignored `dloads/` cache (reused when its SHA-256
matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_xevious_de2_de10_lite_2017_05_01/`, applies
the fix patches, then runs `contrib/tools/prep_roms.sh` to compile
`make_vhdl_prom`, reconstruct `make_xevious_proms.sh` from the upstream
`make_xevious_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/xevious.zip`), rename the color/sound PROMs to the Dar names the
`.bat` expects, and generate the PROM VHDL. Run it via `make setup`.

## ROM set required

MAME ROM set `xevious.zip`, unzipped into `tools/xevious_unzip/roms/`
(a build dir created by `make setup`, distinct from the archive-shipped
`tools/xevious_unzip_win64/` Windows staging dir):

```
~/roms/xevious.zip   ->   tools/xevious_unzip/roms/
```

`prep_roms.sh` renames the 9 color/sound PROMs to the Dar names the upstream
`make_xevious_proms.bat` expects (e.g. `xvi-8*.6a` -> `xvi_8bpr.6a`). Then
`make_xevious_proms.sh` (reconstructed from the `.bat`) generates the PROM
VHDL (including `xevious_cpu_gfx_8bits.vhd`, the CPU + graphics ROM). The
Vivado project references these generated files in place, so the build needs
only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Fix patches

### `xevious_expose_hsync_vsync.patch`

Realizes the pristine `xevious` entity's commented-out `video_hs`/`video_vs`
ports, relaying them from the internally-generated `hsync`/`vsync` of the
`gen_video` instance. This gives the scandoubler genuine separate sync signals.

Verify it took:

```
grep -c video_hs vhdl_xevious_de2_de10_lite_2017_05_01/rtl_dar/xevious.vhd   # expect 2 (port decl + output assignment)
```

## Build status

See root `README.md` §Status.
