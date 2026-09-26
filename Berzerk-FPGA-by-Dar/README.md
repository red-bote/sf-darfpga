# Berzerk-FPGA-by-Dar (Basys 3 port)

Berzerk (Stern, 1980) by Dar (`darfpga@aol.fr`, http://darfpga.blogspot.fr).
Basys 3 (Artix-7) port by Red~Bote. See `README.txt` in the extracted source
archive for the original Dar release notes.

- Vivado 2020.2 project: `basys3/berzerk_basys3.xpr` (top entity `berzerk_basys3`)
- Core clock: 10 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 10.000 MHz;
  reset active-high (btnC), `locked` used. Solved MMCM: `DIVCLK_DIVIDE=2`,
  `CLKFBOUT_MULT_F=15.625`, `CLKOUT0_DIVIDE_F=78.125`.

## Features supported

- **Video**: switch-selectable via `sw(13)` — 0 = 31 kHz progressive VGA (scan doubling built
  into the core via `rtl_dar/line_doubler.vhd`), 1 = 15 kHz TV (native rate, composite sync on
  HS, VS held high; requires a 15 kHz RGB monitor or RGB-to-composite converter).
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard (onboard USB HID host) + JA joystick (movement + fire,
  OR-merged), dedicated buttons for coin/start, btnC = reset. Hardware-confirmed
  2026-09-25: USB-HID keyboard working.

| Input | Keyboard | Button |
|-------|----------|--------|
| Move | Arrow keys | — |
| Fire | Space | — |
| Coin | F3 | btnU or btnD |
| Start 1 | F1 | btnL |
| Start 2 | F2 | btnR |

JA joystick (active-low, switch to GND):
- JA1 = Right, JA2 = Left, JA3 = Down, JA4 = Up, JA7 = Fire
- Movement + fire only — coin/start are not reachable from the joystick on this port.
- Player 2 mirrors player 1 movement/fire inputs.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnL | `btnL` | P1 start (active-high) |
| btnR | `btnR` | P2 start (active-high) |
| btnU | `btnU` | coin-in (active-high) |
| btnD | `btnD` | coin-in (active-high) |
| sw(13) | `sw(13)` | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low, movement + fire) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vga_r/vga_g/vga_b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz / 15 kHz |

No `led` ports — unconstrained on this port (matches Bagman/Pooyan/Time-Pilot's minimal,
placement-proven port list).

## Scripted setup

`contrib/tools/setup_berzerk.sh` automates the manual steps below: it fetches
the Dar archive into the gitignored `dloads/` cache (reused when its SHA-256
matches the hash embedded in the script; re-downloaded when missing or
tampered), extracts it as `vhdl_berzerk_rev_0_1_2018_08_08/`, applies
`contrib/code/berzerk_reset_sensitivity.patch`, then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, convert
`make_berzerk_proms.bat`, stage the romset from `$ROMZIP` (default
`~/roms/berzerk.zip`) and generate the PROM VHDL. The prep also renames the
romset files to the descriptive names the `.bat` expects (rename table below).
Run it via `make setup`.

## ROM set required

MAME ROM set `berzerk.zip`, unzipped into `tools/berzerk_unzip/`:

```
~/roms/berzerk.zip   ->   tools/berzerk_unzip/
```

Then run `./make_berzerk_proms.sh` from that directory to generate the PROM VHDL
(`berzerk_program1/2.vhd`, `berzerk_speech_rom.vhd`). The Vivado project
references these generated files in place, so the build needs only the staged
ROMs + the script.

### ROM file rename

Dar's `make_berzerk_proms.bat` expects descriptive file names
(`berzerk_rc31_1c.rom0.1c`, ...) while the MAME `berzerk.zip` dump uses position
names (`1c-0`, `1d-1`, ...). `prep_roms.sh` renames the romset files to the names
the script expects; the mapping is:

| `berzerk.zip` file | `make_berzerk_proms.bat` name | role |
|--------------------|-------------------------------|------|
| `1c-0`             | `berzerk_rc31_1c.rom0.1c`     | program rom0 |
| `1d-1`             | `berzerk_rc31_1d.rom1.1d`     | program rom1 |
| `3d-2`             | `berzerk_rc31_3d.rom2.3d`     | program rom2 |
| `5d-3`             | `berzerk_rc31_5d.rom3.5d`     | program rom3 |
| `6d-4`             | `berzerk_rc31_6d.rom4.6d`     | program rom4 |
| `5c-5`             | `berzerk_rc31_5c.rom5.5c`     | program rom5 |
| `1c`               | `berzerk_r_vo_1c.1c`          | voice rom1 |
| `2c`               | `berzerk_r_vo_2c.2c`          | voice rom2 |

machine ROMs are copyrighted — never commit or redistribute them.

## Applying the reset-sensitivity fix

The pristine Dar core (`vhdl_berzerk_rev_0_1_2018_08_08/rtl_dar/berzerk.vhd`)
has a process whose sensitivity list omits `reset`. The one-line fix adds it:

```vhdl
process (clock_10, cpu_iorq_n, cpu_addr, reset)
```

`berzerk_reset_sensitivity.patch` in this directory applies that single line to
the unmodified Dar source. From the `Berzerk-FPGA-by-Dar/` directory (containing
`vhdl_berzerk_rev_0_1_2018_08_08/`):

```
patch -p1 < berzerk_reset_sensitivity.patch
```

Verify it took:

```
grep -n "cpu_iorq_n, cpu_addr, reset" vhdl_berzerk_rev_0_1_2018_08_08/rtl_dar/berzerk.vhd
```

## Known issues

- Several columns of video appear clipped on the user's Enoyo LCD monitor
  (reported 2026-09-25, on the hardware-confirmed USB-HID build). Same
  pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar,
  Kick-Midway-MCR-by-Dar, Tron-by-Dar, Zaxxon-by-Dar, Popeye-by-Dar, and
  Bagman-FPGA-Dar. Not yet investigated; deferred at the user's request.
  See root `KNOWN_ISSUES.md`.

