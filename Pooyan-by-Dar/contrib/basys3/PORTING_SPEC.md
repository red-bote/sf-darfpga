# Pooyan-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_pooyan_rev_0_2_2020_04_26.zip`
  (<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/>), SHA-256 in
  `contrib/tools/setup_pooyan.sh`; extracted to `vhdl_pooyan_rev_0_2_2020_04_26/`. Core
  `rtl_dar/pooyan.vhd`, `rtl_dar/pooyan_sound_board.vhd`; DE10 top
  `rtl_dar/pooyan_de10_lite.vhd`. Also `rtl_t80_350/` (T80), `rtl_mikej/YM2149_linmix_sep.vhd`.
- MAME driver: `konami/pooyan.cpp` (`pooyan`).
- This machine is the reference model for new ports (`../../../PORTING_SPEC.md`).
- Wrapper `contrib/basys3/code/pooyan_basys3.vhd`: full rewrite of the DE10 top; the
  `pooyan` core port map is kept. DE10 ports (`max10_clk1_50`, `ledr`, `key`, `sw(9:0)`,
  `hex0-3`, `gpio`) replaced by the Basys 3 set; `hex0-3` and `ledr` dropped.

## 2. Clocking

- Original: 18.432 MHz crystal, pixel 6.144 MHz; sound board 14.31818 MHz.
- `clk_wiz_0`: request 24.576 MHz, achieved 24.573991 MHz (D 5 / M 34.25 / O 27.875),
  signal `clk_core` = 2 × 12.288 MHz, -75 ppm. Single domain (2026-10-05): clocks the core,
  sound board, scandoubler, keyboard and PWM.
- Enables, from a 2-bit phase counter `ph` on `clk_core` (four edges per 6 MHz period:
  e0 = former `clock_6` rising and `clock_12` rising, e1 = `clock_12` falling, e2 =
  `clock_12` rising and `clock_6` falling, e3 = `clock_12` falling; an enable is high in the
  cycle ending at its edge):

  | Enable | Edge | Replaces |
  |---|---|---|
  | `ce6` | e0 | `rising_edge(clock_6)`; T80 main CPU `CEN = cpu_ena and ce6` |
  | `ce6n` | e2 | `clock_6n` RAMs (`wram`, `spram1/2`) |
  | `ce12` | e0, e2 | `rising_edge(clock_12)` (line-buffer read, debug) |
  | `ce12n` | e1, e3 | `clock_12n` line buffers |
  | `clk6_lvl` | level, '1' from e0 to e2 | `clock_6` used as data (line-buffer `we`, read process) |
  | `ce14` | phase accumulator, 610959 / 2^20 × `clk_core` = 14.318181 MHz (jitter 1 cycle) | `rising_edge(clock_14)` |

- Sound board: `clock_div1` counts `ce14`; `cpu_ce` = `ce14` and `clock_div1(2 downto 0) =
  "011"` (former `cpu_clock` rising), `ay_ce` = `ce14` and `"111"` (former `ayx_clock`
  rising); YM2149 `ENA = ay_ce`; sound `wram` enabled by `ce14`.
- Memories: `gen_ram` gains `ce : in std_logic := '1'` gating write and registered read.
  Generated PROMs have no enable: graphics/palette ROMs on former `clock_6` use an
  address-hold mux (address captured at `ce6`); CPU program ROMs read every cycle, their
  consumers sample only on enabled edges.
- T80 (`T80s` v350) `CLK = clk_core`; its NMI edge detect (`T80.vhd:1201`) runs outside
  `CEN`, `cpu_nmi_n` changes only at e0, behaviour unchanged.
- Video: pixel 6.1435 MHz, h_total 384 → H 15.999 kHz (31 kHz output 31.997 kHz);
  v_total 264 → V 60.61 Hz.
- History: until 2026-10-05 the MMCM had `clock_12` (12.2879) and `clock_14` (14.3176)
  outputs plus register-derived `clock_6`, `clock_6n`, `clock_12n`, `clock_14n`, sound
  `cpu_clock`/`ayx_clock`, and a separate wrapper `clock_6` for the DECA doubler and
  keyboard. Vivado reported 1467 `no_clock` pins (untimed core-to-doubler and main-to-sound
  paths); VGA failed to sync on about half of the btnC resets (`../../../KNOWN_ISSUES.md`).
  User decision 2026-10-05: single domain, chosen over a minimal shared-`clock_6` fix for
  long-term maintainability (cost: core RTL patch, scandoubler replacement).

## 3. Reset

DE10: `reset <= not key(0)`. Basys 3: `reset_s` asserted asynchronously by `btnC or not
mmcm_locked` and released synchronously to `clk_core` (2-stage); MMCM reset = `btnC`.

## 4. Core instantiation

- `pooyan` port map kept (r/g/b, csync, blankn, hs, vs, audio_out) plus the enables of §2.
- `video_hs`/`video_vs` (open on the DE10) feed the scandoubler.
- `dip_switch_1 => dip1` (signal, §8); `dip_switch_2 => sw(7 downto 0)` (DE10: `X"7F"`).
- P2 inputs (`fire2/right2/left2/down2/up2`) reuse the P1 signals.

## 5. Video path

- MiST `scandoubler.v` (Till Harbaum, GPL-3.0), `contrib/code/scandoubler.v`, with
  `contrib/code/scandoubler_fix.patch` applied to the project copy. Replaced the two-clock
  DECA `vga_scandoubler.v` on 2026-10-05.
- `clk_sys = clk_core`, `ce_x1 = ce6`, `ce_x2 = ce12` (exactly 2 × `ce_x1`).
- Core 3/3/2-bit RGB zero-extended to 6 bits, gated to black outside `blankn`; output
  `(5 downto 2)` to the 4-bit connector. Core `video_hs`/`video_vs` (active-low) feed
  `hs_in`/`vs_in` directly.
- sw13: `0` = scandoubler output; `1` = native RGB gated on `blankn`, `csync` on HS, VS `'1'`.
- Open question: the `blankn` gating may be redundant (core may already output black in
  blanking); untested, picture correct with the gating.

## 6. Audio

Dar's PWM accumulator on `clk_core`, enabled by `ce14` (former `clock_14` rate):
`pwm_accumulator <= pwm_prev + audio_x4` with typed signals `pwm_prev = '0' &
accumulator(11:0)` and `audio_x4 = audio & "00"` (concatenations outside the type
conversion). Mono `O_PMODAMP2_AIN` = accumulator bit 12 (the DE10 had `pwm_audio_out_l/r`).
`O_PMODAMP2_SHUTD <= not sw(15)`, `O_PMODAMP2_GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clk_core`, wrapper decoder (MAME keys, F0 = release, E0
  ignored; `../../../PORTING_SPEC.md` §3.1, §4.3); replaced `kbd_joystick` 2026-10-20
  (`kbd_joystick.vhd` stays in the project, unreferenced).
- Core inputs: active-high at the `pooyan` boundary (`input_0/1/2 <= ... & not <input>`
  inside the core); level-read by the CPU.
- Merge: `joyPCFRLDU(0..4)` = key or `not ja_s(n)` (up JXADC4, down JXADC3, left JXADC2,
  right JXADC1, fire JXADC7); coin = keys 5/6 or btnU or btnD; start 1 = key 1 or btnL;
  start 2 = key 2 or btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC(4:0) and btnU/btnL/btnR/btnD, on
  `clk_core`. The PS/2 synchronizer was re-instated 2026-10-05 after a raw-input test (raw
  PS/2 at 24.57 MHz misbehaved on Time-Pilot; no fault seen on Pooyan).
- Debounce: none.
- Combos: none (JA fire+direction coin/start combos removed 2026-10-02).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw11-8 | `dip_switch_1` | 3-0 Coinage A | `X"F"` (Dar `X"FF"`) | `dip1 <= DIP1_DEFAULT xor (x"0" & sw(11 downto 8))`, 2026-10-20 |
| sw7-0 | `dip_switch_2` | 7 sound, 6-4 difficulty, 3 bonus, 2 cocktail, 1-0 lives | `x"00"` (Dar `X"7F"`) | direct, pre-dates §3.2, polarity kept |

Fixed: `dip_switch_1` bits 7-4 Coinage B (`X"F"`). sw13 display, sw14 gain, sw15 audio off.
DIP switches hardware-verified (dip 2, 2026-10; Coinage A 2026-10-21).

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/basys3/code/pooyan_t80_xor_width.patch` | `rtl_t80_350/T80.vhd` | operand widths of `&` differ (T80.vhd:562); Vivado rejects |
| `contrib/basys3/code/pooyan_single_domain.patch` | `rtl_dar/pooyan.vhd`, `pooyan_sound_board.vhd`, `gen_ram.vhd` | single clock domain (§2); CRLF, applied with `--binary` |
| `contrib/basys3/code/pooyan_vcnt_264_lines.patch` | `rtl_dar/pooyan.vhd` | `vcnt` reload `0x0F9` → `0x0F8`: 264 lines, V 60.61 Hz (Dar 263, 60.84 Hz), MAME `set_raw(18.432_MHz_XTAL / 3, 384, 0, 256, 264, 16, 240)`; 2026-10-06, `../../../CLOCKING_SPEC.md` 5.7 |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | unpacked array range |
| `contrib/basys3/code/pooyan_de10_lite_to_basys3.patch` | `rtl_dar/pooyan_de10_lite.vhd` | provenance record (generated) |

Pooyan keeps its core patches in `contrib/basys3/code/`; new ports use `contrib/code/`.
`make patch` (`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`, shared
`darfpga_place_top_level`) places the tracked wrapper at
`basys3/pooyan_basys3.srcs/sources_1/new/pooyan_basys3.vhd` and regenerates the provenance
patch; verify with `patch -p1 --dry-run < contrib/basys3/code/pooyan_de10_lite_to_basys3.patch`.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `tools/tools_prom_src/src/make_vhdl_prom.c`,
converts `make_pooyan_proms.bat` to shell, unzips `pooyan.zip` (`ROMZIP`) into
`tools/pooyan_unzip/`, runs it. Output: `pooyan_prog`, `pooyan_sound_prog`,
`pooyan_char_grphx1/2`, `pooyan_sprite_grphx1/2`, `pooyan_palette`,
`pooyan_char_color_lut`, `pooyan_sprite_color_lut` (`.vhd`).

## 11. Build

`make` (setup, create_prj, clk_wiz, patch), `make check`, `make bitstream`.
`create_project.sh` copies `contrib/basys3/vivado/pooyan_basys3.xpr` to
`basys3/pooyan_basys3.xpr`, `pooyan_basys3.xdc` to
`basys3/pooyan_basys3.srcs/constrs_1/imports/digilent-xdc-master/`, and
`contrib/code/scandoubler.v` to `sources_1/imports/mist/` (then applies the fix patch).
`make_clk_wiz_0.sh` generates the MMCM in a throwaway project and copies `clk_wiz_0.v`,
`clk_wiz_0_clk_wiz.v` to `sources_1/imports/clk_wiz_0/`. Project sources referenced in
place: `rtl_dar/` (`pooyan.vhd`, `pooyan_sound_board.vhd`, `gen_ram.vhd`,
`io_ps2_keyboard.vhd`, `kbd_joystick.vhd`), `rtl_t80_350/`, `rtl_mikej/YM2149_linmix_sep.vhd`,
the generated PROMs.

## 12. Open items

- `blankn` gating before the doubler possibly redundant (§5); no action.
