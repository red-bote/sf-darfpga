# Popeye-by-Dar (Basys 3 port)

Popeye (Nintendo, 1982) by Dar (`darfpga@aol.fr`, http://darfpga.blogspot.fr).
Basys 3 (Artix-7) port by Red~Bote. See `README.txt` in the extracted source
archive for the original Dar release notes.

- Vivado 2020.2 project: `basys3/popeye_basys3.xpr` (top entity `popeye_basys3`)
- Core clock: 40.32 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 40.320 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=31.5`, `CLKOUT0_DIVIDE_F=15.625`.

## Features supported

- **Video**: 31 kHz progressive VGA (scan doubling built into the core).
  **sw(13)** selects 31 kHz VGA / 15 kHz TV.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard + JA joystick (OR-merged, verified working),
  btnC = reset.

| Input | Keyboard |
|-------|----------|
| Move | Arrow keys |
| Punch | Space |
| Coin | F1 |
| Start 1 | F2 |
| Start 2 | F3 |
| Service | F7 |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Punch
- Coin = Fire + Up together; Start 1 = Fire + Left together
- Player 2 mirrors player 1 inputs.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | `tv15Khz_mode` | 0 = 31 kHz VGA, 1 = 15 kHz TV |
| JB1 / JB3 | `ps2_dat` / `ps2_clk` | PS/2 keyboard |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz |
| LEDs | `led(15:0)` | present |

## Scripted setup

`contrib/tools/setup_popeye.sh` automates the manual steps below: it fetches the
Dar archive into the gitignored `dloads/` cache (reused when its SHA-256 matches
the hash embedded in the script; re-downloaded when missing or tampered),
extracts it as `vhdl_popeye_rev_0_3_2020_01_27/`, applies
`contrib/code/popeye_linmix_sensitivity.patch`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_popeye_proms.bat`, stage the romsets from `$ROMZIP`/`$ROMZIP2` (defaults
`~/roms/popeye.zip` and `~/roms/popeyeu.zip`) and generate the PROM VHDL. Run it
via `make setup`.

## ROM set required

MAME ROM sets `popeye.zip` + `popeyeu.zip`, unzipped into `tools/popeye_unzip/`:

```
~/roms/popeye.zip    ->   tools/popeye_unzip/
~/roms/popeyeu.zip   ->   tools/popeye_unzip/
```

The extra `popeyeu` set provides the `7a`/`7b`/`7c`/`7e` speech ROMs (not in
the US `popeye` set). Then run `./make_popeye_proms.sh` from that directory to
generate the PROM VHDL (`popeye_cpu.vhd`, `popeye_cpu_protected.vhd`,
`popeye_ch_bits.vhd`, `popeye_sp_bits_1..4.vhd`, `popeye_ch_palette_rgb.vhd`,
`popeye_sp_palette_gb.vhd`, `popeye_sp_palette_rg.vhd`,
`popeye_bg_palette_rgb.vhd`). The Vivado project references these generated
files in place, so the build needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Applying the linmix sensitivity fix

The pristine YM2149 mixer (`vhdl_popeye_rev_0_3_2020_01_27/rtl_mikej/
ym_2149_linmix.vhd`) has a process whose sensitivity list omits `ioa_inreg`.
The one-line fix adds it:

`p_rdata` is a combinational process that drives the chip's read-back data bus
`O_DA`. When Port A is configured as input, it selects that branch of the
`case addr`:

```vhdl
when x"E" => if (reg(7)(6) = '0') then -- input
               O_DA <= ioa_inreg;
             else
               O_DA <= reg(14);
             end if;
```

so the process reads `ioa_inreg` to produce `O_DA`. Missing from the sensitivity
list, a change in `ioa_inreg` (e.g. a Port A input level change) does not
re-evaluate `p_rdata`, leaving the read-back data stale until some other listed
signal (like `addr` or `reg`) changes. Because `ioa_inreg` is itself
combinational (`ioa_inreg <= I_IOA;`), this is a real logic-simulation bug, not
just a Vivado lint warning, and must be fixed for the port to run correctly.

```vhdl
p_rdata                : process(busctrl_re, addr, reg, ioa_inreg)
```

`popeye_linmix_sensitivity.patch` in this directory applies that single line to
the unmodified Dar source. From the `Popeye-by-Dar/` directory (containing
`vhdl_popeye_rev_0_3_2020_01_27/`):

```
patch -p1 < popeye_linmix_sensitivity.patch
```

Verify it took:

```
grep -n "busctrl_re, addr, reg, ioa_inreg" vhdl_popeye_rev_0_3_2020_01_27/rtl_mikej/ym_2149_linmix.vhd
```

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25, on the pre-conversion legacy JB1/JB3 PS/2 keyboard
  build). Same pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar,
  Kick-Midway-MCR-by-Dar, Tron-by-Dar, and Zaxxon-by-Dar. Not yet
  investigated; deferred at the user's request. See root `KNOWN_ISSUES.md`.

