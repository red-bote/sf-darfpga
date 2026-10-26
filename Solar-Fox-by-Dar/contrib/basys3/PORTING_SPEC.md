# Solar-Fox-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_solar_fox_rev_0_1_2019_11_22.zip` (SourceForge `darfpga/files/Software
  VHDL/Solarfox/`), SHA-256 in `contrib/tools/setup_solar_fox.sh`; extracted to
  `vhdl_solar_fox_rev_0_1_2019_11_22/`. Core `rtl_dar/solarfox.vhd`; DE10 top
  `solarfox_de10_lite.vhd`.
- MAME driver: `bally/mcr.cpp` (`solarfox`), MCR-1 90009 CPU board + SSIO.
- Top entity `solar_fox_basys3`; part `xc7a35tcpg236-1`.
- Closest existing port used as model: Kick-Midway-MCR-by-Dar (same MCR family).

## 2. Clocking

- Original: main Z80 19.968 MHz crystal /8 = 2.496 MHz; SSIO 16 MHz (sound Z80 and AY at
  2 MHz).
- `clk_wiz_0`: request 40.000 MHz, achieved 40.000 MHz (1 / 10.0 / 25.0); signal
  `clock_40`. Main CPU +0.16% vs 19.968 MHz (39.9356 MHz retune skipped, user 2026-10-01).
- Enables: inside Dar's core; `clock_div` gates the PWM accumulators.
- Video (MCR scanner 634 x 525): progressive H = 20 MHz / 634 = 31.546 kHz, V = 60.09 Hz;
  TV H = 15.773 kHz, V = 59.75 Hz (264 lines).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC` (2026-10-01).

## 4. Core instantiation

Dar's `solarfox` entity unchanged. Core inputs driven from signals (no expression
actuals): `coin1_in`, `coin2_in`, `fast1_in`, `service`. `separate_audio => '0'`. P2 inputs
`'0'` (the core has no cocktail support).

## 5. Video path

No external scandoubler: the core generates 31 kHz progressive or 15 kHz TV.
`tv15Khz_mode <= sw(13)` (2026-09-28; pristine `not fn_toggle(7)`, the F8 key, had no
power-on reset and could boot into 15 kHz: `../../../KNOWN_ISSUES.md` "Solar-Fox-by-Dar:
no sync on Sylvania SF150 at power-on").

## 6. Audio

Dar's stereo 18-bit PWM accumulators (`pwm_accumulator_l/r`) on `clock_40`;
`O_PMODAMP2_AIN <= pwm_accumulator_l(17)` (left channel, as Kick). `separate_audio =>
'0'` (mixed, 2026-10-20, as rework; was the F5 toggle). `SHUTD <= not sw(15)`,
`GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40`, wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). Arrows, Left Ctrl = fire, Left
  Alt = fast / start (`fast1`), 5/6 = coin 1/2, F2 = service toggle (on press); keys 1/2
  are decoded but not connected (the core has no start input). Mapping as the
  hardware-verified `rb-fpga/ref-repos` Solar Fox port.
- JXADC (active-low, inverted): JXADC1/2/3/4 = right/left/down/up, JXADC7 = fire; JXADC
  direction + fire also asserts `fast1` (rework combo).
- Buttons: btnU = coin 1, btnD = coin 2 (core `coin2`, tied `'0'` before 2026-10-20),
  btnL = `fast1`; btnR unused.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`. The former
  `clock_40`/6 fabric clock `clock_kbd` (`clock_div_kbd`) is removed (single domain, as
  rework).
- Debounce: none. Combos: direction + fire = `fast1` (rework mapping, hardware-verified).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | `tv15Khz_mode` | 1 | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

No DIP bank and no cocktail input at the core boundary (`input_3 = x"FF"` inside the core);
settings via the service menu.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/basys3/code/solar_fox_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No fix patches to Dar's core.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_solar_fox_proms.bat` → shell; romset `solarfox.zip`
(`ROMZIP`). `82s123.12d` is the same PROM as Kick's.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_solar_fox_rev_0_1_2019_11_22/basys3/solar_fox_basys3.xpr`.

## 12. Open items

None.
