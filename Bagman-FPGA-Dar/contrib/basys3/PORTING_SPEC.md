# Bagman-FPGA-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_bagman_rev_0_1_2018_06_05.zip` (SourceForge `darfpga/files/Software
  VHDL/bagman/`), SHA-256 in `contrib/tools/setup_bagman.sh`; extracted to
  `vhdl_bagman_rev_0_1_2018_06_05/`. Core `rtl_dar/bagman.vhd`; DE10 top
  `rtl_dar/bagman_de10_lite.vhd`.
- MAME driver: `bagman` (`valadon/bagman.cpp`).
- Model: Berzerk-FPGA-by-Dar (core-internal line doubler, same reset/audio pattern).
- Top entity `bagman_basys3`; project `vhdl_bagman_rev_0_1_2018_06_05/basys3/bagman_basys3.xpr`.

## 2. Clocking

- Original: 18.432 MHz crystal; Z80 3.072 MHz, pixel 6.144 MHz, AY-3-8910 1.536 MHz,
  TMS5110 speech 640 kHz (8 kHz LPC rate).
- `clk_wiz_0`: request 12.288 MHz, achieved 12.288 MHz (5 / 48 / 78.125, VCO 960 MHz);
  signal `clock_12`. Speed error 0. Retargeted 2026-10-01 from 12.000 MHz (-2.34%,
  `../../../CLOCKING_SPEC.md` §4).
- Enables: inside the core (pixel = `clock_12`/2, CPU, AY `x_pixel(1)`, speech
  `clock_12`/12/2/64 = 8.000 kHz).
- Video: pixel 6.144 MHz, h_total 384, v_total 264 → native H 16.000 kHz, V 60.61 Hz;
  31 kHz output H 32.000 kHz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `bagman` entity unchanged; `tv15Khz_mode => sw(13)`; P2 inputs mirror P1
(`joy_*` signals). Core inputs active-high.

## 5. Video path

Core-internal line doubler (`rtl_dar/line_doubler.vhd`), no external scandoubler. RGB
3/3/2 bits padded to 4 bits (`r & '0'`, `g & '0'`, `b & "00"`); the DE10 `blankn` gate
(forced '1' there) dropped. sw13: `0` = core 31 kHz output with `hsync`/`vsync`; `1` =
`csync` on HS, VS `'1'`.

## 6. Audio

Dar's 13-bit PWM accumulator on `clock_12`; mono. `SHUTD <= not sw(15)`,
`GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_12`, wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20: arrows, Left Ctrl = jump, 1/2 =
  start, 5/6 = coin. Replaces `kbd_joystick` (F-keys; file stays in the project,
  unreferenced).
- Core inputs: active-high; P1 and P2 sets, P2 mirrors P1.
- Merge: `joy_* <= kbd_joy(n) or not jxadc_s(n)`; JXADC1/2/3/4/7 =
  right/left/down/up/jump; coin = keys 5/6, btnU, btnD; start 1 = key 1, btnL; start 2 =
  key 2, btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_12` (2026-10-20).
- Debounce: none.
- Combos: none (JA coin/start combos removed 2026-10-02).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | `tv15Khz_mode`, sync mux | 1 | 31 kHz VGA | |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | 1 / 1 | low gain / on | |

Fixed: DIP bank is a constant inside the core (`bagman.vhd:288`, `not("00110001")`:
cabinet 7, bonus 6, language 5, difficulty 4-3, coin 2, lives 1-0); needs a core patch.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/bagman_xor_width.patch` | `rtl_dar/bagman.vhd` | four `tile_graph_rom_addr` XOR literals left-padded to 13 bits (Vivado width mismatch) |
| `contrib/basys3/code/bagman_de10_lite_to_basys3.patch` | `rtl_dar/bagman_de10_lite.vhd` | provenance record (generated) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_bagman_proms.bat` → shell; romset `bagman.zip` into
`tools/bagman_unzip/`.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. `make check`
reports a pre-existing core-internal HDL 9-3240 (`bagman.vhd`, `bagman_speech.vhd`).

## 12. Open items

None.
