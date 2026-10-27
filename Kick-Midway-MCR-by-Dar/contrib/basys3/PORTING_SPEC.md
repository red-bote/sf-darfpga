# Kick-Midway-MCR-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_kick_rev_0_2_2019_11_22.zip` (SourceForge `darfpga/files/Software
  VHDL/Kick_kickman/`), SHA-256 in `contrib/tools/setup_kick.sh`; extracted to
  `vhdl_kick_rev_0_2_2019_11_22/`. Core `rtl_dar/kick.vhd`.
- MAME driver: `bally/mcr.cpp` (`kick`), MCR-1 90009 CPU board + SSIO sound board.
- Top entity `kick_basys3`; part `xc7a35tcpg236-1`.
- Closest existing port used as model: Tron-by-Dar (same MCR family).

## 2. Clocking

- Original: main Z80 19.968 MHz crystal /8 = 2.496 MHz; SSIO sound board 16 MHz (Z80 and
  2x AY-3-8910 at 2 MHz).
- `clk_wiz_0`: request 40.000 MHz, achieved 40.000 MHz (1 / 10.0 / 25.0); signal
  `clock_40`. Main CPU +0.16% fast vs 19.968 MHz.
- Enables: CPU, pixel and sound rates are enables inside Dar's core.
- Video (`rtl_dar/kick.vhd` scanner 634 x 525): progressive pixel `clock_40`/2 = 20 MHz,
  H = 20 MHz / 634 = 31.546 kHz, V = 31.546 kHz / 525 = 60.09 Hz; TV pixel 10 MHz,
  H 15.773 kHz, V 59.75 Hz (264 lines).
- The 39.9356 MHz retune (exact main CPU, sound 0.16% flat) was skipped by user decision
  2026-10-01 (`../../../CLOCKING_SPEC.md`).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC` (2026-10-01,
`../../../CLOCKING_SPEC.md` section 6; previously `locked => open`).

## 4. Core instantiation

Dar's `kick` entity unchanged. `separate_audio => '0'`; `service` from the F2 toggle;
coin 1 / coin 2 / start 1 / start 2 through signals (no expression actuals).

## 5. Video path

No external scandoubler: the core generates 31 kHz progressive or 15 kHz TV.
`tv15Khz_mode <= sw(13)` (2026-09-29; pristine: `not fn_toggle(7)`, the F8 key, which also
powered up in 15 kHz mode: `fn_toggle` has no reset in `kbd_joystick.vhd`).

## 6. Audio

Dar's stereo 18-bit PWM accumulators (`pwm_accumulator_l/r`, update when
`clock_div = "0000"`) on `clock_40`; `O_PMODAMP2_AIN <= pwm_accumulator_l(17)` (left
channel). `separate_audio => '0'` (mixed, 2026-10-20, as rework; the F5 toggle would drop
right-channel sounds on the mono amp). `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40`, wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). Left/Right = spin, Left Alt =
  spin faster, Left Ctrl = kick, 1/2 = start, 5/6 = coin 1/2, F2 = service toggle (on
  press).
- JXADC (active-low, inverted): JXADC1 = spin right, JXADC2 = spin left, JXADC4 = spin
  faster, JXADC7 = kick; JXADC3 unused.
- Buttons: btnU = coin 1, btnD = coin 2, btnL/btnR = start 1/2, OR-merged with the keys.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`. The former
  `clock_40`/6 fabric clock `clock_kbd` (`clock_div_kbd`) is removed (single domain, as
  rework).
- Debounce: none. Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | `tv15Khz_mode` | 1 | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

No DIP bank at the core boundary; settings via the service menu (F2).

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/basys3/code/kick_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No fix patches to Dar's core.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_kick_proms.bat` → shell; romset `kick.zip` (`ROMZIP`).
Concatenates the chip ROMs into `kick_cpu.bin`, `kick_sound_cpu.bin`, `kick_sp_bits.bin`
and generates `kick_cpu.vhd`, `kick_sound_cpu.vhd`, `kick_bg_bits_1/2.vhd`,
`kick_sp_bits.vhd`, `midssio_82s123.vhd`, referenced in place by the project.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_kick_rev_0_2_2019_11_22/basys3/kick_basys3.xpr`.

## 12. Open items

None.

