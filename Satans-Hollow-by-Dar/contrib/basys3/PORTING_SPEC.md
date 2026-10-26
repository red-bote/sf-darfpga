# Satans-Hollow-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_satans_hollow_rev_0_2_2019_11_22.zip` (SourceForge `darfpga/files/Software
  VHDL/Satans_hollow/`), SHA-256 in `contrib/tools/setup_satans_hollow.sh`; extracted to
  `vhdl_satans_hollow_rev_0_2_2019_11_22/`. Core `rtl_dar/satans_hollow.vhd`.
- Core structure: main Z80 (T80se) + sound board (`satans_hollow_sound_board.vhd`) with its
  own Z80 and two AY-3-8910 (YM2149). Only `rtl_mikej/YM2149_linmix_sep.vhd` is in the
  project: it and `ym_2149_linmix.vhd` both declare `entity YM2149`, and the sound board
  needs the `_sep` ports (`O_CHAN`) for L/R audio.
- MAME driver: `bally/mcr.cpp` (`shollow`), MCR-1 90010 Super CPU board + SSIO 90913.
- Top entity `satans_hollow_basys3`; part `xc7a35tcpg236-1`.
- Closest existing port used as model: Sky-skipper-by-Dar (same 40 MHz single-clock top).

## 2. Clocking

- Original: main Z80 19.968 MHz crystal /8 = 2.496 MHz; SSIO 16 MHz (sound Z80 and 2x
  AY-3-8910 at 2 MHz).
- `clk_wiz_0`: request 40.000 MHz, achieved 40.000 MHz (1 / 10.0 / 25.0); signal
  `clock_40`. The pristine PLL `max10_pll_40M` (50 → 40 MHz) becomes `clk_wiz_0`; no other
  derived clock.
- Enables: inside Dar's core; `clock_div` (0-9) gates the PWM accumulators.
- Video (scanner 634 x 525 @ 20 MHz): progressive H = 20 MHz / 634 = 31.546 kHz,
  V = 60.09 Hz; TV H = 15.773 kHz, V = 59.75 Hz (264 lines).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `satans_hollow` entity unchanged. Core inputs driven from signals (no expression
actuals). `separate_audio => '0'`; `service` from the F2 toggle; `cocktail` and
`coin_meters` from the DIP signals (§8). `dbg_cpu_addr` open.

## 5. Video path

No external scandoubler: native progressive 31 kHz (`tv15Khz_mode = '0'`, the core drives
real `video_hs`/`video_vs`); `'1'` selects 15 kHz interlaced timing.
`tv15Khz_mode <= sw(13)` (2026-09-29; earlier sw13 XOR the F8 toggle `fn_toggle(7)`;
pristine `not fn_toggle(7)` defaulted to 15 kHz). HS/VS select copied from the DE10 top
(`vga_hs <= csync`, `vga_vs <= '1'` when `tv15Khz_mode = '1'`); RGB padded 3/3/3 → 4/4/4.

## 6. Audio

The core outputs stereo (`audio_out_l`/`audio_out_r`, 16 bit). Both pristine 18-bit
accumulators on `clock_40`, gated on `clock_div = "0000"`; `O_PMODAMP2_AIN <=
pwm_accumulator_l(17)`; the right accumulator is unconnected. `separate_audio => '0'`
(mixed, 2026-10-20, as rework; the F5 toggle split L/R, of which the mono amp carries
only the left). `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40` (onboard USB-HID C17/B17), wrapper decoder (MAME
  keys, `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). The pristine `clock_kbd`
  (`clock_40`/20 = 2 MHz) was too slow for the USB-HID host and is no longer produced;
  its `clock_div` counter remains for the PWM gate.
- Keys: Left/Right = move, Left Ctrl = `fire1` (fire), Left Alt = `fire2` (shield),
  1/2 = start, 5/6 = coin 1/2, F2 = service toggle (on press). Mapping as the
  hardware-verified `rb-fpga/ref-repos` Satan's Hollow port.
- JXADC (active-low, inverted): JXADC1 = right, JXADC2 = left, JXADC3 = shield, JXADC7 =
  fire; JXADC4 unused.
- Buttons: btnU = coin 1, btnD = coin 2 (pristine top ties `coin2` low), btnL/btnR = start.
  Cocktail inputs (`*_c`) mirror player 1.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`.
- Debounce: none. Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `cocktail` | 1 | `'0'` (Dar) | `COCKTAIL_DEFAULT xor sw(12)` (2026-10-20, §3.2); Dar marks cocktail "KO atm" |
| sw11 | `coin_meters` | 1 | `'0'` (Dar) | `COIN_METERS_DEFAULT xor sw(11)` |
| sw13 | `tv15Khz_mode` | | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

No game DIP bank in the core entity (`input_2 = x"FF"` inside the core); settings via the
service menu.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/basys3/code/satans_hollow_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No fix patches to Dar's core (native video, sibling-proven T80/YM2149; the `.xpr` avoids the
duplicate `YM2149` entity by listing only the `_sep` file).

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_satans_hollow_proms.bat` → shell; romset `shollow.zip`
(`ROMZIP`); `82s123.12d` renamed to `midssio_82s123.12d` (the SSIO PROM ships in the same
set, unlike Tron's separate `midssio.zip`).

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_satans_hollow_rev_0_2_2019_11_22/basys3/satans_hollow_basys3.xpr`.

## 12. Open items

- Core-internal HDL 9-3240 at `rtl_dar/satans_hollow.vhd:934` (pre-existing; left as is,
  user decision pending).
