# Satans-Hollow-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_satans_hollow_rev_0_2_2019_11_22.zip` (SourceForge folder `Satans_hollow`,
  per the repo-root `downloads.md`) → `vhdl_satans_hollow_rev_0_2_2019_11_22/` at the machine root.
- Top entity: `satans_hollow_basys3` (target file `sources_1/new/satans_hollow_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.
- Core structure: one main Z80 (T80se) + a sound board (`satans_hollow_sound_board.vhd`) with its
  own Z80 and two AY-3-8910 (YM2149). Only `rtl_mikej/YM2149_linmix_sep.vhd` is included in the
  project: both `YM2149_linmix_sep.vhd` and `ym_2149_linmix.vhd` declare `entity YM2149`, and the
  sound board needs the `_sep` ports (`O_CHAN`) for L/R audio.

## 2. Clocking

- Single core clock: **40 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`,
  `CLKOUT0_DIVIDE_F=25.0`. Reset active-high (`btnC`), `locked` used.
- The pristine top's PLL (`max10_pll_40M`, 50 → 40 MHz) becomes `clk_wiz_0` exactly as in the
  Sky Skipper port; nothing else derives a clock.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Berzerk/Bagman/Pooyan pattern).

## 4. Video (31 kHz VGA / 15 kHz TV)

- No external scandoubler: the core is **native progressive 31 kHz** — it drives the real
  `video_hs`/`video_vs` itself (`tv15Khz_mode = '0'`); `'1'` selects 15 kHz interlaced timing.
- Display mode is selected by **sw(13)** (0 = 31 kHz VGA, 1 = 15 kHz TV) XORed with the
  **F8** keyboard toggle (`fn_toggle(7)`), so F8 inverts the mode in either switch position.
  The default `sw(13)=0` (F8 not pressed) is **31 kHz VGA**, giving an out-of-the-box picture
  with no PS/2 keyboard attached. This replaces the pristine polarity
  (`tv15Khz_mode <= not fn_toggle(7)`, which defaulted to 15 kHz) and follows the
  Sky Skipper / display-standard convention of an sw(13) base mode with a keyboard toggle.
- HS/VS select is a direct copy of the pristine DE10 top
  (`vga_hs <= csync when tv15Khz_mode = '1'`, `vga_vs <= '1' when tv15Khz_mode = '1'`);
  RGB is padded 3/3/3 → 4/4/4 (`r&'0'`, `g&'0'`, `b&'0'`) in both modes.

## 5. Audio (mono PWM on PmodAMP2)

- The core outputs **stereo** (`audio_out_l`/`audio_out_r`, 16 bit each). The wrapper
  reproduces both pristine 18-bit accumulators on `clock_40`, gated on the
  `clock_div = "0000"` phase (see §6 — the keyboard no longer uses this divider), and wires
  only the **left** bit-17 PWM to the mono PmodAMP2; the right accumulator is kept in
  lockstep but unconnected.
- Pristine `separate_audio` (F5) selects split L/R output; on the mono amp only the left
  channel is heard. `sw(15)` → AMP gain, `sw(14)` → AMP shutdown.

## 6. Inputs

- Keyboard on the **Basys3 onboard USB-HID connector** (`ps2_clk` = C17, `ps2_dat` = B17),
  NOT on the JB Pmod: `io_ps2_keyboard` + `kbd_joystick` are clocked directly on `clock_40`
  (40 MHz, comfortably above the ≥ 6 MHz the onboard USB-HID host needs). The pristine
  `clock_kbd` divider (40/20 = 2 MHz) was dropped from the keyboard path (too slow for the
  USB-HID host) and is retained only as the `clock_div` gate for the PWM audio accumulators —
  the shared pristine counter is otherwise untouched.
- Keyboard → core (`joy_BBBBFRLDU`): Left/Right arrows = left/right, Up arrow = up
  (drives the core's `fire2` shield input), Space = `fire1` (fire); Down arrow is unused by
  the core. F1/F2/F3 = coin/start1/start2; F5 = service **and** `separate_audio`
  (the pristine top shares F5 for both); F8 = `tv15Khz_mode` toggle.
- JA joystick (active-low, invert to active-high) OR-merged with the keyboard:
  `JA1=Left, JA2=Right, JA4=Shield, JA7=Fire` (`JA3`/`JA(2)` unused); JA fire drives `fire1`,
  JA4 drives `fire2` (shield), OR-merged with keyboard Up.
- Pushbuttons: `btnU` = coin1, `btnD` = coin2 (convenience — the pristine top ties `coin2`
  low), `btnL` = start1, `btnR` = start2 (btnC = reset). The cocktail inputs (`*_c`) mirror
  player 1 and `cocktail` = '0' (pristine F7 comment "KO atm"); `coin_meters` = '0'.
- `sw1`/`sw2`-style game DIP inputs are not part of this core's entity, so the board switches
  stay on their display/audio duties only (sw13/sw14/sw15).

## 7. LEDs

- **Not ported** — the pristine DE10 top's `ledr` is commented out (dead code) and the core
  has no LED output; the wrapper declares no `led` port and the XDC keeps the LEDs commented
  (same as Sky Skipper). `dbg_cpu_addr` is left open (the DE10 7-seg debug display isn't
  ported).

## 8. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/satans_hollow_basys3.xpr`, with the sources tree at
  `basys3/satans_hollow_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/shollow.zip`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.
- **No synthesis-fix patch** is required (so far): the video path is native progressive with
  no scandoubler, the T80 cores and CTCO YM2149 blocks have all synths successfully in
  sibling ports, and the `.xpr` skips the duplicate-entity hazard by reading only the `_sep`
  YM2149.
- The midssio PROM ships in the same `shollow.zip` as `82s123.12d` and is renamed to
  `midssio_82s123.12d` by `prep_roms.sh` (single-romset port, unlike Tron's separate
  `kick.zip` for the same chip).