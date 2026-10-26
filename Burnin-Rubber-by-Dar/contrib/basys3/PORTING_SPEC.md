# Burnin-Rubber-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_burnin_rubber_rev_0_0_2017_12_22.zip` (SourceForge `darfpga/files/Software
  VHDL/burnin_rubber/`), SHA-256 in `contrib/tools/setup_burnin_rubber.sh`; extracted to
  `vhdl_burnin_rubber_rev_0_0_2017_12_22/`. Core `rtl_dar/burnin_rubber.vhd`; DE10 top
  `rtl_dar/burnin_rubber_de10_lite.vhd`.
- MAME driver: `brubber` (`dataeast/btime.cpp`, Bump 'n' Jump family).
- Model: Pooyan conventions; reference for Burger-Time (same core family).
- Top entity `burnin_rubber_basys3`; project
  `vhdl_burnin_rubber_rev_0_0_2017_12_22/basys3/burnin_rubber_basys3.xpr`.

## 2. Clocking

- Original: 12.000 MHz crystal (Bump 'n' Jump hardware); pixel 6 MHz.
- `clk_wiz_0`: request 12 MHz, achieved 12.000 MHz (5 / 49.875 / 83.125); signal
  `clock_12`. Speed error 0.
- Enables: `clock_6` = `clock_12` toggle (scandoubler `ce_x1`, 2026-10-02; previously MMCM
  `clk_out2` 6 MHz, 1 / 7.5 / 62.5 / 125, which failed hold timing, WHS -0.60 ns,
  `../../../CLOCKING_SPEC.md` 5.2). CPU and sound enables inside the core.
- Video: pixel 6 MHz, h_total 384, v_total 261 → native H 15.625 kHz, V 59.87 Hz;
  doubled H 31.25 kHz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `burnin_rubber` entity unchanged. The DE10 top leaves `video_hs`/`video_vs` open ("not
tested") and uses `video_csync` only; this port wires them to the scandoubler,
hardware-verified. `dbg_cpu_addr => open` (DE10 7-segment chain not ported). No `led` port
(DE10 `ledr` assignment is commented out).

## 5. Video path

MiST `scandoubler.v` (`contrib/code/`, project copy patched by `scandoubler_fix.patch`),
instance `scandoubler_inst`, `COLOR_DEPTH = 6`, `HCNT_WIDTH = 9` (defaults).

| Port | Signal |
|---|---|
| `clk_sys` | `clock_12` |
| `ce_x1` | `clock_6` (toggle enable) |
| `ce_x2` | `'1'` |
| `scanlines` | `"00"` |
| `hs_in` / `vs_in` | core `video_hs` / `video_vs` (15.625 kHz) |
| `r_in` / `g_in` / `b_in` | `r & r`, `g & g`, `b & b & b` when `blankn = '1'`, else `"000000"` (core RGB 3/3/2) |
| outputs | `hsync_o`, `vsync_o`, `vga_r_o/g_o/b_o` |

sw13: `0` = `vga_*_o(5 downto 2)`, `hsync_o`, `vsync_o`; `1` = `r & '0'`, `g & '0'`,
`b & "00"`, `csync` on HS, VS `'1'`. `clk_sys` must run at 12 MHz (2 × pixel) with
`ce_x2 = '1'`.

## 6. Audio

DE10 PWM accumulator: `'0' & pwm_accumulator(11 downto 0)` + `audio & "00"` (11-bit
`audio_out`), 13 bits, `O_PMODAMP2_AIN` = bit 12. `SHUTD <= not sw(15)`,
`GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_12`, wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20: arrows, Left Ctrl = jump, 1/2 =
  start, 5/6 = coin. Replaces `kbd_joystick`.
- Core inputs: active-high at the core boundary (`btn_p1 <= not(...)` inside the core);
  P2 mirrors P1.
- Merge: `not jxadc_s(n)` OR keys; JXADC1/2/3/4/7 = right/left/down/up/jump; coin = keys
  5/6, btnU, btnD; start 1 = key 1, btnL; start 2 = key 2, btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_12` (2026-10-20).
- Debounce: none.
- Combos: none (fire+up = coin, fire+left = start 1 removed 2026-10-02).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | output mux | 1 | 31 kHz VGA | |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | 1 / 1 | low gain / on | |

Fixed: `dip_sw1 <= "10011111"`, `dip_sw2 <= "00010111"` are constants inside the core
(`burnin_rubber.vhd:295-296`); need a core patch.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/burnin_rubber_vsync_before_vblank.patch` | `rtl_dar/burnin_rubber.vhd` | `vsync_cnt` reset at `vcnt = 248`: vsync no longer overlaps the last 8 active lines (2026-09-28) |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | unpacked array full range (Vivado) |
| `contrib/basys3/code/burnin_rubber_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

Retired 2026-09-28: `burnin_rubber_vcnt_272_lines.patch` (272 lines, 57.44 Hz); it caused
bottom-row clipping. Burger-Time, same horizontal path, runs the 261-line frame.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_burnin_rubber_proms.bat` → shell; romset `brubber.zip`
into `tools/burnin_rubber_unzip/`.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The project has 21
sources and 1 constraints file.

## 12. Open items

None.
