# Sky-skipper-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_sky_skipper_rev_01_2020_01_28.zip` (SourceForge folder `sky_skipper`,
  per the repo-root `downloads.md`) → `vhdl_sky_skipper_rev_01_2020_01_28/` at the machine root.
- Top entity: `sky_skipper_basys3` (target file `sources_1/new/sky_skipper_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.
- Directory naming note: this machine's directory is `Sky-skipper-by-Dar` (lowercase `s`), not
  `Sky-Skipper-by-Dar` — see root `README.md`'s directory-naming bullet.

## 2. Clocking

- Single core clock: **40 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
- Solved MMCM (per machine `README.md`): `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`,
  `CLKOUT0_DIVIDE_F=25.0`. Reset active-high (`btnC`), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Berzerk/Bagman/Pooyan pattern).

## 4. Video (31 kHz VGA / 15 kHz TV)

- No external scandoubler: the core is **native progressive 31 kHz** — it drives the real
  `video_hs`/`video_vs` itself on a 20 MHz pixel clock (`tv15Khz_mode = '0'`); `'1'` selects
  15 kHz interlaced timing.
- Display mode is selected by **sw(13)** (0 = 31 kHz VGA, 1 = 15 kHz TV) XORed with the
  **F8** keyboard toggle (`fn_toggle(7)`), so F8 inverts the mode in either switch position.
  The default `sw(13)=0` (F8 not pressed) is **31 kHz VGA**, giving an out-of-the-box picture
  with no PS/2 keyboard attached. This replaces the pristine polarity
  (`tv15Khz_mode <= not fn_toggle(7)`, which defaulted to 15 kHz) and also departs from the
  Kick/Solar-Fox keyboard-only convention by adding the Bagman/Popeye-style sw(13) override.
- HS/VS select is a direct copy of the pristine DE10 top
  (`vga_hs <= csync when tv15Khz_mode = '1'`, `vga_vs <= '1' when tv15Khz_mode = '1'`);
  RGB is padded 3/3/2 → 4/4/4 (`r&'0'`, `g&'0'`, `b&"00"`) in both modes. The core's
  inverted video outputs are passed through unchanged.

## 5. Audio (mono PWM on PmodAMP2)

- Mono PWM accumulator reproducing the pristine top's 18-bit accumulator on `clock_40`,
  gated on the `clock_div = "0000"` phase of the pristine clock divider (see §6 — the
  keyboard no longer uses this divider); output is bit
  17. `sw(15)` → AMP gain, `sw(14)` → AMP shutdown.

## 6. Inputs

- Keyboard on the **Basys3 onboard USB-HID connector** (`ps2_clk` = C17, `ps2_dat` = B17),
  NOT on the JB Pmod: `io_ps2_keyboard` + `kbd_joystick` are clocked directly on `clock_40`
  (40 MHz, comfortably above the ≥ 6 MHz the onboard USB-HID host needs). The pristine
  `clock_kbd` divider (40/20 = 2 MHz) was dropped from the keyboard path (too slow for the
  USB-HID host) and is retained only as the `clock_div` gate for the PWM accumulator — the
  shared pristine counter is otherwise untouched.
- Keyboard → core: arrows = up/down/left/right, Space = fire10, F = fire11; F1/F2/F3/F4 =
  coin1/coin2/start1/start2; F7 = service; F8 = `tv15Khz_mode` toggle.
- JA joystick (active-low, invert to active-high) OR-merged with the keyboard:
  `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`; JA7 drives both the core's Fire A and
  Fire B inputs.
- Pushbuttons: `btnU` = coin1, `btnD` = coin2, `btnL` = start1, `btnR` = start2 (btnC =
  reset). Player 2 mirrors player 1 (the core has no independent P2 controls, only
  cocktail-mode duplicates).
- DIP switches keep the pristine hard constants: `sw1 = "0000000"`, `sw2 = "00000010"`; the
  board switches are not wired to them.

## 7. LEDs

- **Not ported** — the pristine DE10 top's `ledr` is commented out (dead code) and the core
  has no LED output; the wrapper declares no `led` port and the XDC keeps the LEDs commented
  (unlike Bagman/Berzerk/Pooyan which wire `led(15:0)`).

## 8. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/sky_skipper_basys3.xpr`, with the sources tree at `basys3/sky_skipper_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/skyskipr.zip`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or distribute them.
- **No synthesis-fix patch** is required for this core: every XOR is full-expression-width
  (the constant is padded to the full width by `std_logic_unsigned`, no ckong/Bagman-style
  sub-part misalignment), and all PROM address widths match their core drivers.