# Sky-skipper-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User-facing summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_sky_skipper_rev_01_2020_01_28.zip` (SourceForge `darfpga/files/Software
  VHDL/sky_skipper/`), SHA-256 in `contrib/tools/setup_sky_skipper.sh`; extracted to
  `vhdl_sky_skipper_rev_01_2020_01_28/`. Core `rtl_dar/sky_skipper.vhd`.
- MAME driver: `nintendo/popeye.cpp` (`skyskipr`, `tnx1_state`, same TNX-1 board as Popeye).
- Top entity `sky_skipper_basys3`; part `xc7a35tcpg236-1`. Directory `Sky-skipper-by-Dar`
  (lowercase `s`).
- Closest existing port used as model: Popeye-by-Dar.

## 2. Clocking

- Original: single 8.000 MHz crystal; Z80 XTAL/2 = 4 MHz, AY-3-8910 XTAL/4 = 2 MHz.
- `clk_wiz_0`: request 40.32 MHz, achieved 40.320 MHz (5 / 31.5 / 15.625, VCO 630 MHz);
  signal `clock_40`. Retuned 2026-10-01 from 40.000 MHz (1 / 10 / 25), as Popeye
  (`../../../CLOCKING_SPEC.md` 5.6).
- Enables: `clock_cnt2` (after the width patch) CPU f/10 = 4.032 MHz (+0.8%), AY f/20 =
  2.016 MHz; `clock_div` gates the PWM accumulator.
- Video (scanner 640 x 526, display 512 x 448): progressive pixel `clock_40`/2 = 20.16 MHz,
  H = 31.500 kHz, V = 59.886 Hz; TV pixel 10.08 MHz, H = 15.750 kHz, V = 59.886 Hz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `sky_skipper` entity unchanged. Core inputs driven from signals (no expression
actuals): `sw1_in`, `sw2_in`, `service1`, player inputs. The core's inverted video outputs
pass through unchanged.

## 5. Video path

No external scandoubler: native progressive 31 kHz on a 20 MHz pixel enable
(`tv15Khz_mode = '0'`); `'1'` selects 15 kHz interlaced timing. `tv15Khz_mode <= sw(13)`
(2026-09-29; earlier sw13 XOR the F8 toggle `fn_toggle(7)`; pristine
`not fn_toggle(7)` defaulted to 15 kHz). HS/VS select copied from the DE10 top
(`vga_hs <= csync`, `vga_vs <= '1'` when `tv15Khz_mode = '1'`); RGB padded 3/3/2 → 4/4/4
(`r&'0'`, `g&'0'`, `b&"00"`).

## 6. Audio

Pristine mono 18-bit accumulator on `clock_40`, gated on `clock_div = "0000"`;
`O_PMODAMP2_AIN <= pwm_accumulator(17)`. `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40` (onboard USB-HID C17/B17), wrapper decoder (MAME
  keys, `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). The pristine `clock_kbd`
  (`clock_40`/20 = 2 MHz) was too slow for the USB-HID host and is no longer produced; its
  `clock_div` counter remains for the PWM gate.
- Keys: arrows = directions, Left Ctrl = `fire10` (speed up), Left Alt = `fire11` (bomb),
  1/2 = start, 5/6 = coin 1/2, 9 = `service1` (held). Mapping as the hardware-verified
  `rb-fpga/ref-repos` Sky Skipper port.
- JXADC (active-low, inverted): JXADC1/2/3/4 = right/left/down/up, JXADC7 = bomb
  (`fire11`); any JXADC direction also drives `fire10` (speed up), as rework.
- Buttons: btnU = coin 1, btnD = coin 2, btnL/btnR = start 1/2. Player 2 mirrors player 1
  (the core has only cocktail-mode duplicates).
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`.
- Debounce: none. Combos: none beyond the rework direction → speed-up mapping.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw7-0 | `sw2` | 7-0 | `'0'` | `sw2_in <= sw(7 downto 0)`, not inverted (as rework, hardware 2026-10-19); cocktail (P) / service2 (O) / bonus (N) / difficulty (MLK) / lives (IJ); Dar's DE10 value `not("11111101")` = `"00000010"` |
| sw11-8 | `sw1` | 3-0 coinage DCBA | `"0000000"` (Dar `not("1111111")`) | `SW1_DEFAULT xor ("000" & sw(11:8))` (2026-10-20, §3.2) |
| sw13 | `tv15Khz_mode` | | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

Fixed: `sw1` n.u. bits 6-4 (hard-wired in Dar's top). sw12 spare.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/sky_skipper_clock_cnt2_width.patch` | `rtl_dar/sky_skipper.vhd` | 4-bit `clock_cnt2` never reached the `"10011"` reload; CPU f/8, AY f/16; widened to 5 bits (2026-10-01) |
| `contrib/basys3/code/sky_skipper_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No synthesis-fix patch: every XOR is full-width and all PROM address widths match their
core drivers.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_sky_skipper_proms.bat` → shell; romset `skyskipr.zip`
(`ROMZIP`). Output (referenced in place): `sky_skipper_cpu`, `sky_skipper_ch_bits`,
`sky_skipper_sp_bits_1..4`, `sky_skipper_ch_palette_rgb`, `sky_skipper_sp_palette_gb`,
`sky_skipper_sp_palette_rg`, `sky_skipper_bg_palette_rgb` (`.vhd`).

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_sky_skipper_rev_01_2020_01_28/basys3/sky_skipper_basys3.xpr`.
The project lists all 25 core sources: an incomplete list left the modular T80 CPU as a
black box (`[DRC INBB-3]` at implementation). Post-route WNS 21.853 ns; 1906 LUTs /
815 FFs / 18.5 BRAM tiles.

## 12. Open items

None.

