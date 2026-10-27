# Burger-Time-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User-facing summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_burger_time_rev_0_0_2017_12_27.zip` (SourceForge `darfpga/files/Software
  VHDL/burger_time/`), SHA-256 in `contrib/tools/setup_burger_time.sh`; extracted to
  `vhdl_burger_time_rev_0_0_2017_12_27/`. Core `rtl_dar/burger_time.vhd`; DE10 top
  `rtl_dar/burger_time_de10_lite.vhd`.
- MAME driver: `btime` (`dataeast/btime.cpp`).
- Model: Burnin-Rubber-by-Dar (same core family and scandoubler wiring).
- Top entity `burger_time_basys3`; project
  `vhdl_burger_time_rev_0_0_2017_12_27/basys3/burger_time_basys3.xpr`.

## 2. Clocking

- Original: 12.000 MHz crystal, shared by the main CPU and the sound 6502; pixel 6 MHz;
  main CPU 1.5 MHz (`btime`, jumper H2/H4), 750 kHz on `bnj`/`disco`.
- `clk_wiz_0`: request 12 MHz, achieved 12.000 MHz (5 / 49.875 / 83.125); signal
  `clock_12`. Speed error 0.
- Sound board (core): CPU 500 kHz (`clock_12`/24), AY-3-8910 1.5 MHz (`clock_12`/8).
- Enables: `clock_6` = `clock_12` toggle (scandoubler `ce_x1`, 2026-10-02; previously MMCM
  `clk_out2` 6 MHz, which failed hold timing, WHS -0.60 ns, `../../../CLOCKING_SPEC.md`
  5.2). CPU enable inside the core (§9).
- Video: pixel 6 MHz, h_total 384, v_total 261 → native H 15.625 kHz, V 59.87 Hz;
  doubled H 31.25 kHz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `burger_time` entity unchanged. The DE10 top leaves `video_hs`/`video_vs` open ("not
tested") and uses `video_csync` only; this port wires them to the scandoubler (as
Burnin-Rubber), hardware-verified. `dbg_cpu_addr => open` (DE10 7-segment chain not
ported). No `led` port (DE10 `ledr` assignment is commented out).

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
  `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20: arrows, Left Ctrl = pepper, 1/2 =
  start, 5/6 = coin. Replaces `kbd_joystick`.
- Core inputs: active-high; single `coin1`, `fire1`; P2 mirrors P1.
- Merge: `not stick_s(n)` OR keys; JXADC1/2/3/4/7 = right/left/down/up/pepper; coin =
  keys 5/6, btnU, btnD; start 1 = key 1, btnL; start 2 = key 2, btnR. No `coin2` port.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_12` (2026-10-20).
- Debounce: none.
- Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | output mux | 1 | 31 kHz VGA | |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | 1 / 1 | low gain / on | |

Fixed: `dip_sw1 = "01111111"`, `dip_sw2 = "11101011"` are constants inside the core
(`burger_time.vhd:293-294`); need a core patch.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/burger_time_cpu_1p5mhz.patch` | `rtl_dar/burger_time.vhd` | main CPU 1.5 MHz (MAME `btime`, 2026-10-02) |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/burger_time_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

CPU rate detail: Dar's `cpu_ena <= '1' when hcnt(2 downto 0) = "111" and clock_6 = '1'`
(`burger_time.vhd:330`) = 6 MHz / 8 = 750 kHz. The patch uses `hcnt(1 downto 0) = "11"`
(slots 011 and 111) = 1.5 MHz. `cpu_ena` also selects the CPU address on the shared
foreground/sprite RAM mux (`fg_ram_addr_sel`); video samples `fg_ram_low_do` at
`hcnt(2:0)` = 000, 100 and 101, so slot 011 does not overlap. Hardware-confirmed
2026-10-02 (picture and sound correct). Revert by removing the patch.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_burger_time_proms.bat` → shell; romset `btime.zip`
into `tools/burger_time_unzip/`. Output: `burger_time_prog`, `bg_map`, `bg_graphx_1/2/3`,
`fg_sp_graphx_1/2/3`, `burger_time_sound_prog` (`.vhd`).

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`.

## 12. Open items

None.

