# Galaga-Midway-by-Dar (Basys 3 port)

Galaga (Namco/Midway, 1981) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port by Red~Bote. See
`README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/galaga_basys3.xpr` (top entity `galaga_basys3`)
- Core clock: 36 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 36.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=49.5`, `CLKOUT0_DIVIDE_F=27.5`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`), sourced from
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard + JA joystick (OR-merged), btnC = reset.

| Input | Keyboard | Scancode |
|-------|----------|----------|
| Left | ← | 0x6B |
| Right | → | 0x74 |
| Fire | Space | 0x29 |
| Coin | F3 | 0x04 |
| Start 1 | F1 | 0x05 |
| Start 2 | F2 | 0x06 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Coin = Fire + Up together; Start 1 = Fire + Left together
- Player 2 mirrors player 1 left/right/fire inputs.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU/btnL/btnR/btnD | `btnU/L/R/D` | declared, unused (reserved) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| JB1 / JB3 | `ps2_dat` / `ps2_clk` | PS/2 keyboard |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz |
| LEDs | `led(15:0)` | present |

## Known issues

- **Start 1 / Start 2 ignored after coin** (fixed in
  `rtl_dar/galaga.vhd:848`): the Namco 51XX credit-mode flag is re-enabled on
  every hardware coin edge (`cs51XX_credit_mode <= '1'`), so start inputs work
  with credits available.
- Keyboard can randomly stick to the right (and maybe left) — original core
  issue.
- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25). Same pattern reported on Solar-Fox-by-Dar,
  Kick-Midway-MCR-by-Dar, and Tron-by-Dar. Not yet investigated; deferred at
  the user's request. See root `KNOWN_ISSUES.md`.

## ROM set required

MAME ROM sets `galaga.zip` + `galagamw.zip`, unzipped into
`tools/galaga_unzip/`:

```
~/roms/galaga.zip      ->   tools/galaga_unzip/
~/roms/galagamw.zip    ->   tools/galaga_unzip/
```

The extra `galagamw` set provides the `3200a`-`3700g` CPU ROMs (not present in
the plain `galaga` set). Then run `./make_galaga_proms.sh` from that directory
to generate the PROM VHDL (`galaga_cpu1/2/3.vhd`, `cs54xx_prog.vhd`,
`sp_graphx.vhd`, `bg_graphx.vhd`, `sp_palette.vhd`, `bg_palette.vhd`,
`rgb.vhd`, `sound_samples.vhd`, `sound_seq.vhd`). The Vivado project references
these generated files in place, so the build needs only the staged ROMs + the
script.

machine ROMs are copyrighted — never commit or redistribute them.

## Fixing the background-palette XOR width

The pristine Dar core (`rtl_dar/galaga.vhd`) has a synthesis-shape bug in `bgpalette_addr`
(around line 521): the `xor` is applied after the `'1'`/`'0'` prefix bit is already concatenated
onto `hcnt(1 downto 0)`, giving it a 3-bit left operand against `flip_h & flip_h`'s 2 bits.
`galaga_bgpalette_xor_length_fix.patch` parenthesizes `hcnt(1 downto 0) xor (flip_h & flip_h)`
first (both 2-bit) and concatenates the prefix bit onto the result. Applied automatically by
`contrib/tools/setup_galaga.sh`. Verify it took:

```
grep -n "xor (flip_h & flip_h))))" vhdl_galaga_rev_0_3_2018_05_06/rtl_dar/galaga.vhd
```

## Applying the credit-mode fix

The pristine Dar core (`vhdl_galaga_rev_0_3_2018_05_06/rtl_dar/galaga.vhd`) has a
bug where Start 1 / Start 2 are ignored after inserting a coin. The one-line fix
re-enables the Namco 51XX credit-mode flag on every hardware coin edge:

```vhdl
cs51XX_credit_mode <= '1';     -- <-- RB 7/2026 - added by Big Pickle: re-enable credit mode on coin insert
```

`galaga_credit_mode_fix.patch` in this directory applies that single line to the
unmodified Dar source. From the `Galaga-Midway-by-Dar/` directory (containing
`vhdl_galaga_rev_0_3_2018_05_06/`):

```
patch -p1 < galaga_credit_mode_fix.patch
```

The patch adds the line inside the hardware coin-edge detection (`if coin = '1'
and coin_r = '0'`), i.e. at `rtl_dar/galaga.vhd:848`. Verify it took:

```
grep -n "cs51XX_credit_mode <= '1'" vhdl_galaga_rev_0_3_2018_05_06/rtl_dar/galaga.vhd
```

## Enabling VGA sync (Basys 3)

The pristine Dar core leaves `video_hs`/`video_vs` unexposed (ports commented out,
video-generator `hsync`/`vsync` wired to `open`). To drive the scan doubler's
`hsync_ext_n`/`vsync_ext_n` from the core, apply
`contrib/code/galaga_vga_sync.patch` to the pristine source. From the
`Galaga-Midway-by-Dar/` directory (containing `vhdl_galaga_rev_0_3_2018_05_06/`):

```
patch -p1 < contrib/code/galaga_vga_sync.patch
```

It un-comments the two `video_hs`/`video_vs` output ports and wires the video
generator's `hsync`/`vsync` to them. Verify it took:

```
grep -n "hsync   => video_hs" vhdl_galaga_rev_0_3_2018_05_06/rtl_dar/galaga.vhd
```

