# Pooyan by Dar — Basys3 port

Porting Pooyan (Konami, 1982) by Dar (`darfpga@aol.fr`, <http://darfpga.blogspot.fr>) to the
Digilent Basys3 (Artix-7, part `xc7a35tcpg236-1`).

- Source archive: <https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/>
  (`vhdl_pooyan_rev_0_2_2020_04_26.zip`)
- Basys3 port by Red~Bote. Upstream Dar release notes: `vhdl_pooyan_rev_0_2_2020_04_26/README.txt`.

This file is the single source of truth for design and build. Operational rules live in
`.opencode/rules.md` and `AGENTS.md`.

## External IO (Basys3)

- Atari-style joystick on JA (active-low; internal `PULLUP true` in the XDC; inverted in the
  top-level OR-merge so a press reads active-high, matching the core). Physical map
  `JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire`; coin/start on the keyboard and
  btnU/btnL/btnR (JA fire+direction combos removed 2026-10-02).
- Single-player: P2 controls are hardwired to P1 (`fire2/right2/left2/down2/up2` reuse the
  P1 signals), regardless of input source.
- Mono PWM audio on PmodAMP2 (JC header).
- PS/2 keyboard on the onboard USB HID host (C17/B17, `ps2_clk`/`ps2_dat`, internal
  `PULLUP true` in the XDC), OR-merged with the JA joystick; `btnU` = coin, `btnL` = 1P start, `btnR` = 2P start
  (added 2026-10-01); `btnC` = reset (active-high —
  pressed asserts reset; the Basys3 button is active-high, unlike the DE10's active-low
  `key(0)`). Hardware-confirmed 2026-09-25: USB-HID keyboard working.
- 31 kHz VGA on the Basys3 VGA connector (4-bit per color RGB + HS/VS).
- PmodAMP2 sound-enable on `sw14` (down = enable, up = disable); gain-select on `sw15`
  (up = enable gain, down = disable gain).
- Dip switches: `dip_switch_1` (coinage) is hardcoded `X"FF"`; `dip_switch_2`
  (sound/difficulty/bonus/cocktail/lives) maps to `sw(7 downto 0)`, mirroring the upstream
  DE10-lite alternative. Defaults: sw7-sw0 all down = `0x00`.

### Keyboard (PS/2, JB)

- SPACE = fire; arrow keys = up/down/left/right.
- F1 = coin, F2 = start 1P, F3 = start 2P.
- Note: the upstream Dar `README.txt` mislabels the F-keys (it lists F3 = add coin,
  F2 = start 2P, F1 = start 1P). The code in `rtl_dar/kbd_joystick.vhd` is authoritative:
  F1 = coin, F2 = start 1P, F3 = start 2P.

## Clocking

Single clock domain (2026-10-05; `contrib/basys3/PORTING_SPEC.md` section 2). `clk_wiz_0`
derives one clock, `clk_core` = 24.573991 MHz (`DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=34.25`,
`CLKOUT0_DIVIDE_F=27.875`), from the 100 MHz oscillator. The former 12.288 MHz, 6.144 MHz
(and their inverted phases) and 14.318 MHz sound clocks are clock enables from the wrapper
(2-bit phase counter; 20-bit phase accumulator for the 14.318181 MHz sound rate), applied to
the core and sound board by `contrib/basys3/code/pooyan_single_domain.patch`. The former
two-output MMCM plus register-derived clocks left the core-to-scandoubler path untimed and
failed VGA sync on about half of the resets. MMCM reset is `btnC`; core reset is `btnC or
not mmcm_locked`, released synchronously to `clk_core`.

## VGA

31 kHz VGA uses the MiST scandoubler (`clk_sys = clk_core`, `ce_x1` = 6.1435 MHz pixel
enable, `ce_x2` = 2x). 15 kHz TV mode is selected by `sw(13)` = 1 (native RGB, `csync` on HS,
VS high; fleet convention). The DECA `vga_scandoubler.v` used until 2026-10-05 is no longer
part of this port.

- **Scan doubler source**: MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>;
  tracked as `contrib/code/scandoubler.v`, copied into the project by
  `create_project.sh`.

## Top level

The Basys3 top level is derived from
`vhdl_pooyan_rev_0_2_2020_04_26/rtl_dar/pooyan_de10_lite.vhd` by applying the patch
`contrib/basys3/code/pooyan_de10_lite_to_basys3.patch`, which adapts it for:
- PmodAMP2 sound output, and
- the Basys3 VGA output (4 bits/color RGB + hsync/vsync signals).

## T80 core synthesis workaround

The pristine `rtl_t80_350/T80.vhd` fails Vivado synthesis with
"operands of logical operator '&' have different lengths" (T80.vhd:562).
Apply `contrib/basys3/code/pooyan_t80_xor_width.patch` (modifies line 734).

## ROM-derived PROM VHDL (required; never distributed)

The MAME romset `pooyan.zip` is required. It is unzipped into `tools/pooyan_unzip/`; run
`./make_pooyan_proms.sh` from that directory to generate the PROM VHDL:

- `pooyan_prog.vhd`, `pooyan_sound_prog.vhd`
- `pooyan_char_grphx1.vhd`, `pooyan_char_grphx2.vhd`
- `pooyan_sprite_grphx1.vhd`, `pooyan_sprite_grphx2.vhd`
- `pooyan_palette.vhd`, `pooyan_char_color_lut.vhd`, `pooyan_sprite_color_lut.vhd`

These generated files must exist before the project can be synthesized.

- Never distribute copyrighted roms.
- Never commit or otherwise distribute the generated PROM VHDL.

## Host paths

- Vivado 2020.2: `/tools/Xilinx/Vivado/2020.2/bin/vivado`
- Romset: `~/roms/pooyan.zip`

## Project setup

The root `Makefile` wraps the scripted setup: `make setup` (download+extract upstream, apply
patch, build the PROM generator, unzip the romset, generate PROM VHDL),
`make create_prj` (lay down the project tree and copy the ported assets),
`make clk_wiz` (generate the `clk_wiz_0` IP, depends on setup and create_prj),
`make patch` (regenerate the DE10→Basys3 top level and its patch, depends on setup),
`make all` (setup + clk_wiz + patch, so transitively create_prj),
`make synth` (run synthesis, depends on setup/clk_wiz/patch), `make bitstream`
(implementation + write_bitstream, depends on synth), and `make clean` (remove the generated
`vhdl_pooyan_rev_0_2_2020_04_26/` tree).

Project structure lives in `vhdl_pooyan_rev_0_2_2020_04_26/basys3/`. Use the Xilinx project at
`vhdl_pooyan_rev_0_2_2020_04_26/basys3/pooyan_basys3.xpr` (top entity
`pooyan_basys3`, part `xc7a35tcpg236-1`).

`make create_prj` runs `contrib/basys3/vivado/create_project.sh`, which copies from
`contrib/basys3/`:

- `vivado/pooyan_basys3.xpr` → `basys3/pooyan_basys3.xpr`
- `vivado/pooyan_basys3.xdc` → `basys3/pooyan_basys3.srcs/constrs_1/imports/digilent-xdc-master/`
- `../code/scandoubler.v` → `basys3/pooyan_basys3.srcs/sources_1/imports/mist/scandoubler.v`
  (then `contrib/code/scandoubler_fix.patch` is applied to the copy)

The constraints file is based on the
[Digilent Basys-3-Master.xdc](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).

`make patch` places the top level (`sources_1/new/pooyan_basys3.vhd`) and `make clk_wiz`
generates the `clk_wiz_0` MMCM IP files (`sources_1/imports/clk_wiz_0/`).

### Build

Run Vivado build scripts from `/tmp` so `vivado.log` / `vivado.jou` stay outside the repository.

`make synth` resets and runs the `synth_1` run. `make bitstream` runs the `impl_1` run through
`write_bitstream` (it depends on `synth`), producing
`vhdl_pooyan_rev_0_2_2020_04_26/basys3/pooyan_basys3.runs/impl_1/pooyan_basys3.bit`.

## Creating the Vivado Basys3 project

From scratch, to (re)build `pooyan_basys3.xpr` (steps 1–4 are scripted by
`make create_prj`, i.e. `contrib/basys3/vivado/create_project.sh`):

1. Create a Vivado 2020.2 project for part `xc7a35tcpg236-1`, VHDL target language, top
   entity `pooyan_basys3`, saved as `basys3/pooyan_basys3.xpr`.
2. Reference (do not copy) the RTL sources from `vhdl_pooyan_rev_0_2_2020_04_26/`:
- `rtl_dar/` — `pooyan.vhd`, `pooyan_sound_board.vhd`, `gen_ram.vhd`,
      `io_ps2_keyboard.vhd`, `kbd_joystick.vhd`
   - `rtl_t80_350/` — the T80 Z80 core
   - `rtl_mikej/` — `YM2149_linmix_sep.vhd`
   - the generated PROM files from `tools/pooyan_unzip/` (must already exist, see above)
3. Add the scan doubler: `contrib/code/scandoubler.v` → `sources_1/imports/mist/scandoubler.v`,
   then apply `contrib/code/scandoubler_fix.patch` to the copy.
4. Add constraints: `contrib/basys3/vivado/pooyan_basys3.xdc` →
   `constrs_1/imports/digilent-xdc-master/`.
5. Generate the `clk_wiz_0` MMCM IP (single 24.576 MHz request, solve above) with
   `contrib/basys3/vivado/make_clk_wiz_0.sh`; outputs go under `sources_1/imports/clk_wiz_0/`.
6. Generate the top level `pooyan_basys3.vhd` under `sources_1/new/` with `make patch`
   (writes the authored top level from `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`
   and emits `contrib/basys3/code/pooyan_de10_lite_to_basys3.patch` as a record of the change;
   see the porting steps).
7. Apply `contrib/basys3/code/pooyan_t80_xor_width.patch` (`rtl_t80_350/T80.vhd`) and
   `contrib/basys3/code/pooyan_single_domain.patch` (`rtl_dar/`), both by `make setup`
   (`--binary`).
8. Run synthesis/implementation from `/tmp` so `vivado.log` / `vivado.jou` stay outside the repo.

## Porting the DE10 top level to Basys3

The adaptation is captured by `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`, which
authors the new `pooyan_basys3.vhd` top level and emits
`contrib/basys3/code/pooyan_de10_lite_to_basys3.patch` as a record of the transformation of
`vhdl_pooyan_rev_0_2_2020_04_26/rtl_dar/pooyan_de10_lite.vhd` into `pooyan_basys3.vhd`:

1. **Port list** — map the Basys3 IO per `pooyan_basys3.xdc`: `clk` (100 MHz), `sw`, `btnC`,
   joystick on `JA[]`, PS/2 on `jb` (`ps2_dat`, `ps2_clk`), PmodAMP2 on `jc`
   (`O_PMODAMP2_AIN/GAIN/SHUTD`), `vga_r/g/b[3:0]`, `vga_hs`, `vga_vs`.
2. **Clocking** — replace the DE10 `max10_pll_12M_14M` with `clk_wiz_0`; single `clk_core`
    domain with clock enables (see Clocking above).
3. **Core instantiation** — keep the `pooyan` entity port map unchanged (r/g/b, csync,
   blankn, hs, vs, audio_out).
4. **VGA via scan doubler** — MiST `scandoubler` (see VGA above); the core's 3+3+2-bit video,
   zero-extended to 6 bits and gated on `blankn`, feeds `r_in/g_in/b_in`; the core's active-low
   `video_hs`/`video_vs` feed `hs_in`/`vs_in` directly; the 6-bit outputs are reduced to the
   4-bit connector. `sw(13)` = 1 selects the native 15 kHz output.
5. **Audio** — port the DE10 PWM accumulator (on `clk_core`, enabled at the 14.318 MHz rate); drive `O_PMODAMP2_AIN`
   with the PWM bit, and route `sw14` (sound enable) to `O_PMODAMP2_SHUTD` and `sw15` (gain
   select) to `O_PMODAMP2_GAIN`.
6. **Inputs** — keep the PS/2 keyboard + `kbd_joystick`; OR-merge the JA joystick with it.
   The core's input boundary is active-high (`pooyan.vhd` `input_0/1/2 <= ... & not <input>`),
   so the active-low JA bits are inverted in the OR-merge. Coin/start come from the keyboard and
   btnU/btnL/btnR (fire+direction combos removed 2026-10-02). `btnC` = reset.

## Notes and open items

- Dip switches 1–8 confirmed working on hardware.
- Intermittent VGA sync failure after reset (reported 2026-09-25 / 2026-10-01): addressed by
  the single-domain change of 2026-10-05; hardware-confirmed 2026-10-05. See root `KNOWN_ISSUES.md`.
- 15 kHz TV mode wired to `sw(13)` 2026-10-02 (hardware-confirmed).

