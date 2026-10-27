# Zaxxon-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_zaxxon_rev_0_0_2019_11_29.zip` (SourceForge folder `zaxxon`), SHA-256 in
  `contrib/tools/setup_zaxxon.sh`; extracted to `vhdl_zaxxon_rev_0_0_2019_11_29/`. Core
  `rtl_dar/zaxxon.vhd`; DE10 top `rtl_dar/zaxxon_de10_lite.vhd`.
- MAME driver: `sega/zaxxon.cpp` (`zaxxon`).
- Model: Burnin-Rubber-by-Dar (scandoubler wiring); Galaga-Midway-by-Dar (derived
  `clk_sys`).
- Top entity `zaxxon_basys3`, part `xc7a35tcpg236-1`.

## 2. Clocking

- Original: 48.66 MHz crystal; core master 24.33 MHz, CPU f/8 = 3.041 MHz, pixel f/4 =
  6.082 MHz.
- `clk_wiz_0`: request 24.33 MHz, achieved 24.32900 MHz (D 3 / M 35.125 / O 48.125), single
  output, signal `clock_24`; core, keyboard, PWM.
- Core pixel enable: `clock_cnt` (4-bit, +1 per `clock_24` edge); `pix_ena` = `clock_cnt(1
  downto 0) = "01"` (6.08 MHz, 1 in 4).
- Video: VGA H 31.678 kHz, V 60.00 Hz.
- History: until 2026-10-01 the core clock was 24.000 MHz (D 5 / M 50.25 / O 41.875): VGA
  31.25 kHz / 59.19 Hz, -1.36% speed. Retargeted 2026-10-01 (`../../../CLOCKING_SPEC.md`
  section 4). DE10 PLL: `max10_pll_24M` from 50 MHz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`. Core held in reset while `btnC`
is pressed or the MMCM is unlocked.

## 4. Core instantiation

- `zaxxon` entity kept. Player inputs `up/down/left/right/fire` from `core_*` signals; the
  cocktail-mode duplicates `up_c/down_c/left_c/right_c/fire_c` take the same signals (as
  the DE10 top; no second control set).
- `cocktail => fn_toggle(2)` (F7), `service => fn_toggle(0)` (F2), `flip_screen =>
  flip_sel` (F4 toggle `xor not sw(12)`).
- `coin2` driven by key 6 since 2026-10-20 (was `'0'` as in the DE10 top).
- `audio_out_r => open`; `dbg_cpu_addr` open; DE10 `ledr` (debug only) not ported, no
  `led` port.
- `video_hs`, `video_vs`, `pix_clk_div` added by the patch (§5).

## 5. Video path

- Problem: the core declares `video_hs`/`video_vs` but never drives them (no `video_hs <=`
  / `video_vs <=` in `zaxxon.vhd`); only `video_csync` is real, from a composite-sync
  generator with equalizing/serration pulses. No VGA output until fixed. The core has no
  `line_doubler`, and `hcnt`/`vcnt`/`hs_cnt`/`vs_cnt` are not at the entity boundary, so a
  core patch is the only fix.
- `contrib/code/zaxxon_expose_video_timing.patch`:
  - `video_hs <= hsync0;` existing per-line pulse, low from `hs_cnt = 0` to `29`, every line;
  - `video_vs <= '0' when vcnt < 8 else '1';` new 8-line pulse inside vertical blanking
    (`video_blankn` blanks `vcnt < 17`), independent of the csync machinery;
  - `pix_clk_div <= clock_cnt(1 downto 0);` exposes the core's 12/6 MHz clock bits.
- Scandoubler (`contrib/code/scandoubler.v` + `scandoubler_fix.patch`, defaults
  `COLOR_DEPTH = 6`, `HCNT_WIDTH = 9`):

  | Port | Signal | Note |
  |---|---|---|
  | `clk_sys` | `sd_clock_12 <= pix_clk_div(0)` | 12.16 MHz |
  | `ce_x1` | `sd_clock_6 <= pix_clk_div(1)` | 6.08 MHz; rises one `clock_24` cycle after `pix_ena` |
  | `ce_x2` | `'1'` | |
  | `scanlines` | `"00"` | |
  | `hs_in` / `vs_in` | core `video_hs` / `video_vs` | |
  | `r_in/g_in/b_in` | `r & r`, `g & g`, `b & b & b` | 3/3/2 bits padded to 6, `"000000"` when `blankn = '0'` |

- `clk_sys` derivation history: a first version fed `clock_24` with `ce_x1 = clock_24`,
  `ce_x2 = '1'`; a second kept `clock_24` with derived enables; both failed. Galaga's
  record (`../../../Galaga-Midway-by-Dar/contrib/basys3/PORTING_SPEC.md` §12.3.3, source
  comment "clock_18, video_clk i clock_36 no funciona") showed the working form: a derived
  12 MHz `clk_sys`, 6 MHz `ce_x1`, `ce_x2 = '1'`. The core's own counter bits are used
  instead of a mirrored wrapper counter (single source). This `clk_sys` is register-derived
  and untimed (`../../../KNOWN_ISSUES.md`); Pooyan's form (`clk_sys` = core clock,
  `ce_x2` = 2 × `ce_x1`) is the preferred pattern for new ports.
- sw13: `0` = `vga_hs <= hsync_o`, `vga_vs <= vsync_o`, RGB `vga_*_o(5 downto 2)`;
  `1` = `vga_r <= r & '0'`, `vga_g <= g & '0'`, `vga_b <= b & "00"`,
  `vga_hs <= csync`, `vga_vs <= '1'`.

## 6. Audio

`audio_out_l`/`_r` are 16 bits. Dar's left-channel PWM accumulator verbatim (18 bits):
`pwm_accumulator_l <= ('0' & pwm_accumulator_l(16 downto 0)) + ('0' & audio_l & '0')`,
`O_PMODAMP2_AIN <= pwm_accumulator_l(17)`, gated as the DE10 top by `clock_div`. Right
channel open. `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_24`, wrapper decoder (MAME keys, F0 = release, E0
  ignored; `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20, replaces `kbd_joystick`
  (unreferenced). Keys: arrows, Left Ctrl = fire, 1/2 = start, 5 = coin 1, 6 = coin 2,
  F2 = service (was F5), F4 = flip, F7 = cocktail. Toggles flip on make and ignore
  typematic repeat (Dar toggled on release).
- Keyboard clock (2026-10-20): `clock_24`. The fabric `clock_kbd` divider (`clock_24` / 4 =
  6.08 MHz, added 2026-09-28 because the DE10's `clock_24` / 6 ≈ 4 MHz was too slow for
  the USB-HID host) is removed: single domain. Hardware-verified 2026-10-20.
- Core inputs: active-high; `p1_input` is read by the CPU as a level
  (`zaxxon.vhd:451`), so fire needs no debounce; `coin1_mem`/`coin2_mem` are edge-latched.
  Player 2 mirrors player 1: the core's `*_c` cocktail inputs take the player 1 signals.
- Merge: JXADC1 right, JXADC2 left, JXADC3 down, JXADC4 up, JXADC7 fire, OR-merged with
  the keys; coin 1 = key 5, btnU, btnD; coin 2 = key 6; start 1 = key 1, btnL; start 2 =
  key 2, btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2 and JXADC on `clock_24` (2026-10-20); buttons
  2-FF then debounce.
- Debounce (2026-10-02): btnU/btnD/btnL/btnR stable for 2^18 `clock_24` cycles (10.8 ms);
  the core edge-detects coin, release bounce counted extra coins.
- JXADC fire history (2026-10-20): presses were missed on 2-FF only, fewer with a
  stable-input debounce, and stuck/repeated with a fast-attack debounce (43 ms minimum);
  an integrating filter was written, not built. Fire reverted to 2-FF only. Cause: a faulty
  joystick; with a CX40-type joystick fire is clean on 2-FF only (hardware 2026-10-20).
- Combos: none (dedicated buttons cover coin/start).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `flip_screen` | 1 | `flip_sel = F4 toggle xor '1'` | `flip_sel <= fn_toggle(1) xor not sw(12)`; added and inverted 2026-10-02 |

Fixed: `sw1_input = cocktail & "111" & x"f"`, `sw2_input = x"33"` inside
`rtl_dar/zaxxon.vhd:453-454` (lives, bonus, difficulty, coinage; core patch needed, out of
scope). Cocktail is the F7 toggle. sw13 display, sw14 gain, sw15 audio off.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/zaxxon_hflip_xor_width.patch` | `rtl_dar/zaxxon.vhd` | `hflip2 <= hflip xor ("0" & not(hcnt(8)) & "0000000")`: 8-bit literal padded to 9 bits; Vivado rejects the mismatch (same class as `bagman_xor_width.patch`) |
| `contrib/code/zaxxon_expose_video_timing.patch` | `rtl_dar/zaxxon.vhd` | `video_hs`/`video_vs` drivers, `pix_clk_div` (§5); behaviour fix |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/zaxxon_de10_lite_to_basys3.patch` | `rtl_dar/zaxxon_de10_lite.vhd` | provenance record (generated) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, converts
`make_zaxxon_proms.bat`, unzips `zaxxon.zip` (`ROMZIP`) into `tools/zaxxon_unzip/`,
generates `zaxxon_cpu`, `zaxxon_char_bits_1/2`, `zaxxon_bg_bits_1/2/3`,
`zaxxon_sp_bits_1/2/3`, `zaxxon_map_1/2`, `zaxxon_palette`, `zaxxon_char_color` (`.vhd`).

## 11. Build

`make` (setup, create_prj, clk_wiz, patch), `make check`, `make bitstream`.
`create_project.sh` copies `zaxxon_basys3.xpr` and `Basys-3-Master.xdc` into the extracted
tree and imports `scandoubler.v` (then applies the fix patch).

## 12. Open items

- Register-derived scandoubler `clk_sys` (§5); candidate: Pooyan-style single domain
  (needs a hardware test).

