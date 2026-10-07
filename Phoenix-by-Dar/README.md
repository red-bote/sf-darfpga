# Phoenix-by-Dar (Basys 3 port)

Phoenix (Amstar, 1980) by Dar (`darfpga@aol.fr`, http://darfpga.blogspot.fr).
Basys 3 (Artix-7) port by Red~Bote. See `README.txt` in the extracted source
archive for the original Dar release notes.

- Vivado 2020.2 project: `basys3/phoenix_basys3.xpr` (top entity
  `phoenix_basys3`)
- Core clock: 11 MHz (pixel clock 5.5 MHz internally); audio effect/music
  blocks run on 50 MHz (from the 100 MHz Basys 3 oscillator via `clk_wiz_0`)
- `clk_wiz_0` Clocking Wizard (MMCM, 100 MHz in): `clk_out1` = 11.000 MHz +
  `clk_out2` = 50.000 MHz; reset active-high (btnC), `locked` used. Solved
  MMCM: `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=11.000`, `CLKOUT0_DIVIDE_F=100.000`,
  `CLKOUT1_DIVIDE=22`.

## Features supported

- **Video**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`imports/mist/scandoubler.v`) fed by real hsync/vsync exposed from the
  core (`contrib/code/phoenix_expose_hsync_vsync.patch` — the pristine core
  otherwise exposes only composite sync). sw(13) switches to 15 kHz TV mode
  (native RGB + composite sync on HS, reproducing the pristine DE10-lite
  top's own output path). See `contrib/basys3/PORTING_SPEC.md` for the full
  design record.
- **Scan doubler source**: MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>;
  tracked as `contrib/code/scandoubler.v`, copied into the project by
  `create_project.sh`.
- **Sound**: mono PWM audio on PmodAMP2; `audio_select` (3-bit, sw(10:8))
  selects effect1/effect2/effect3/melody solo or the default mix.
- **Controls**: PS/2 keyboard (decoded inside the core) OR-merged with the JA
  joystick and dedicated buttons (third attempt, 2026-10-02): JA1 = right,
  JA2 = left, JA4 = up (protection), JA7 = fire; btnU/btnD = coin, btnL = 1P
  start, btnR = 2P start. The core patch `phoenix_external_inputs.patch` adds
  an active-high `ext_joy` input merged before the core's inversion to the
  CPU's active-low inputs. Hardware-confirmed 2026-10-02.

| Input | Keyboard |
|-------|----------|
| Move (right/left) | Arrow keys |
| Shield | Up arrow |
| Fire | Space |
| Coin | F3 |
| Start 1 | F1 |
| Start 2 | F2 |

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnD / btnL / btnR | `btnU`/`btnD`/`btnL`/`btnR` | coin / coin / 1P start / 2P start (debounced ~12 ms) |
| JA1 / JA2 / JA4 / JA7 | `JA(0)`/`JA(1)`/`JA(3)`/`JA(4)` | right / left / up (protection) / fire (JA3 unused) |
| sw(7:0) | `sw(7 downto 0)` | dip switches (lives, bonus life, coin mode, upright/cocktail) |
| sw(10:8) | `sw(10 downto 8)` | `audio_select`: solo effect1/2/3/melody or mixed |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown/enable: 0 = off, 1 = on |
| sw(13) | `sw(13)` | display mode: 0 = VGA, 1 = 15 kHz TV |
| C17 / B17 (onboard USB HID) | `ps2_clk` / `ps2_dat` | PS/2 keyboard (USB keyboard via onboard host) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`contrib/tools/setup_phoenix.sh` automates the manual steps below: it
fetches the Dar archive into the `dloads/` cache (tracked in git) (reused when its
SHA-256 matches the hash embedded in the script; re-downloaded when missing
or tampered), extracts it as `vhdl_phoenix_DE10_lite/` (the archive has no
internal top-level folder, unlike every other machine's), applies the fix
patches (see "Fix patches" below), then runs
`contrib/tools/prep_roms.sh` to compile `make_vhdl_prom`, run the
reconstructed `make_phoenix_proms.sh` (the upstream archive ships no
`.bat`/`tools_prom_src`), stage the romset from `$ROMZIP` (default
`~/roms/phoenix.zip`), and generate the PROM VHDL. Run it via `make setup`.
The MiST `scandoubler.v` (see Features above) is tracked in `contrib/code/`
and copied into the project by `create_project.sh`.

## ROM set required

MAME ROM set `phoenix.zip`, unzipped into `tools/phoenix_unzip/`:

```
~/roms/phoenix.zip   ->   tools/phoenix_unzip/
```

Then run `./make_phoenix_proms.sh` from that directory to generate the PROM
VHDL (`phoenix_prog.vhd`, `prom_ic39.vhd`, `prom_ic40.vhd`, `prom_ic23.vhd`,
`prom_ic24.vhd`, `prom_palette_ic40.vhd`, `prom_palette_ic41.vhd`). The
Vivado project references these generated files in place, so the build
needs only the staged ROMs + the script.

machine ROMs are copyrighted — never commit or redistribute them.

## Fix patches

### `phoenix_external_inputs.patch`

Adds `ext_joy : in std_logic_vector(7 downto 0) := (others => '0')` (active-high,
`JoyPCFRLDU` bit order) to the `phoenix` entity and OR-merges it into each of the
seven player-input assignments before their inversion, e.g.
`coin <= not (JoyPCFRLDU(7) or ext_joy(7));` (2026-10-02). Verify:
`grep -c 'or ext_joy' vhdl_phoenix_DE10_lite/rtl_dar/phoenix.vhd` prints `7`.

### `phoenix_sound_reset.patch`

Ties the four sound modules' `reset` to the core `reset` (pristine: `'0'`) and clears
`sound_a`/`sound_b` while `reset = '1'`, so btnC also silences the sound (2026-10-07).
Verify: `grep -c "btnC did not reset the sound" vhdl_phoenix_DE10_lite/rtl_dar/phoenix.vhd`
prints `4`.

### `phoenix_expose_hsync_vsync.patch`

Two-file patch exposing real hsync/vsync end-to-end (the pristine core
otherwise only produces composite sync):

- Adds `hsync`/`vsync` output ports to the pristine `phoenix_video` entity
  (`rtl_dar/phoenix_video.vhd`), assigned from its already-internal
  `pulse_a` (per-line hsync pulse) and `vblank_n` (active-low vsync window)
  signals.
- Realizes the pristine `phoenix` entity's commented-out `video_hs`/
  `video_vs` ports (`rtl_dar/phoenix.vhd`), relaying them from
  `phoenix_video`'s new `hsync`/`vsync` outputs.

Verify it took:

```
grep -n "hsync <= pulse_a" vhdl_phoenix_DE10_lite/rtl_dar/phoenix_video.vhd
grep -c video_hs vhdl_phoenix_DE10_lite/rtl_dar/phoenix.vhd   # expect 2 (port decl + output assignment)
```

## Known issues

- JA joystick / dedicated buttons: two earlier attempts (2026-09-22, 2026-09-25)
  registered no input and were reverted (root `KNOWN_ISSUES.md`). Third attempt
  2026-10-02 merges the inputs before the core's inversion (see Fix patches);
  hardware-confirmed 2026-10-02.

Fixed 2026-09-23: keyboard moved from the legacy JB1/JB3 Pmod header onto
the onboard USB-HID host (C17/B17), matching the project default. Pure XDC
pin swap, no clock-divider work needed. Hardware-confirmed 2026-09-23.

Fixed 2026-09-23: reset (`btnC`) hardware-confirmed working.

## Build status

See root `README.md` §Status.
