# Popeye-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User-facing summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_popeye_rev_0_3_2020_01_27.zip` (SourceForge `darfpga/files/Software
  VHDL/popeye/`), SHA-256 in `contrib/tools/setup_popeye.sh`; extracted to
  `vhdl_popeye_rev_0_3_2020_01_27/`. Core `rtl_dar/popeye.vhd`; YM2149 `rtl_mikej/`.
- MAME driver: `nintendo/popeye.cpp` (board TNX-1).
- Top entity `popeye_basys3`; part `xc7a35tcpg236-1`.
- Closest existing port used as model: Bagman-FPGA-Dar (`tv15Khz_mode` on sw13).

## 2. Clocking

- Original: single 8.000 MHz crystal; Z80 XTAL/2 = 4 MHz, AY-3-8910 XTAL/4 = 2 MHz.
- `clk_wiz_0`: request 40.32 MHz, achieved 40.320 MHz (5 / 31.5 / 15.625, VCO 630 MHz);
  signal `clock_40`.
- Enables: `clock_cnt2` (after the width patch) CPU f/10 = 4.032 MHz (+0.8%), AY f/20 =
  2.016 MHz; `clock_div` (0-9) gates the PWM accumulator.
- Video (scanner 640 x 526): progressive pixel `clock_40`/2 = 20.16 MHz, H = 31.500 kHz,
  V = 59.886 Hz; TV pixel 10.08 MHz, H = 15.750 kHz, V = 59.886 Hz (263 lines).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `popeye` entity unchanged. `sw1`, `sw2`, `service` and the player inputs through
signals (no expression actuals).

## 5. Video path

No external scandoubler: the core generates 31 kHz progressive or 15 kHz TV.
`tv15Khz_mode => sw(13)`.

## 6. Audio

Dar's mono 18-bit PWM accumulator, updated when `clock_div = "0000"`, on `clock_40`;
`O_PMODAMP2_AIN <= pwm_accumulator(17)`. `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40`, wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). Arrows, Left Ctrl = punch,
  1/2 = start, 5/6 = coin, 9 = service (held, MAME service 1). Mapping as the
  hardware-verified `rb-fpga/ref-repos` Popeye port.
- JXADC (active-low, inverted): JXADC1/2/3/4 = right/left/down/up, JXADC7 = punch.
- Buttons: btnU/btnD = coin, btnL/btnR = start 1/2. Player 2 mirrors player 1.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`. The former
  `clock_40`/6 fabric clock `clock_kbd` (`clock_div_kbd`) is removed (single domain, as
  rework).
- Debounce: none. Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw7-0 | `sw2` | 7-0 | `not sw` = `x"FF"` | cocktail / music / bonus (2) / difficulty (2) / lives (2); `not sw(7:0)` as rework, hardware 2026-10-19; Dar's DE10 value `"00111101"` |
| sw11-8 | `sw1` | 3-0 coinage | Dar's value | `SW1_DEFAULT xor ("000" & sw(11:8))`, `SW1_DEFAULT = not("10" & '1' & "1111")` (2026-10-20, §3.2) |
| sw13 | `tv15Khz_mode` | | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

Fixed: `sw1` copyright (bits 6-5) and N.U. (bit 4) at Dar's value (no spare switches for
a whole field; sw12 spare).

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/popeye_clock_cnt2_width.patch` | `rtl_dar/popeye.vhd` | 4-bit `clock_cnt2` never reached the `"10011"` reload; CPU f/8, AY f/16 (+26%); widened to 5 bits (2026-10-01, `../../../CLOCKING_SPEC.md` 5.6) |
| `contrib/code/popeye_linmix_sensitivity.patch` | `rtl_mikej/ym_2149_linmix.vhd` | `p_rdata` sensitivity list lacked `ioa_inreg`, `iob_inreg` (`iob_inreg` added 2026-10-07); a port-input change left `O_DA` stale |
| `contrib/basys3/code/popeye_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

Verify the linmix fix: `grep -n "busctrl_re, addr, reg, ioa_inreg, iob_inreg"
vhdl_popeye_rev_0_3_2020_01_27/rtl_mikej/ym_2149_linmix.vhd`.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_popeye_proms.bat` → shell; romsets `popeye.zip`
(`ROMZIP1`) + `popeyeu.zip` (`ROMZIP2`, the `7a`/`7b`/`7c`/`7e` ROMs). Output (referenced in
place): `popeye_cpu`, `popeye_cpu_protected`, `popeye_ch_bits`, `popeye_sp_bits_1..4`,
`popeye_ch_palette_rgb`, `popeye_sp_palette_gb`, `popeye_sp_palette_rg`,
`popeye_bg_palette_rgb` (`.vhd`).

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_popeye_rev_0_3_2020_01_27/basys3/popeye_basys3.xpr`.

## 12. Open items

None.

