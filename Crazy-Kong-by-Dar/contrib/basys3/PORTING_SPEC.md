# Crazy-Kong-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_ckong_rev_0_1_2018_06_06.zip` (SourceForge `darfpga/files/Software
  VHDL/crazy_kong/`), SHA-256
  `953bd4fdfaaad1cfcb1b9c5adee41636056b2353910664321e7422ae515a0700`
  (`contrib/tools/setup_ckong.sh`); extracted to `vhdl_ckong_rev_0_1_2018_06_06/`. Core
  `rtl_dar/ckong.vhd` (entity `ckong`); DE10 top `rtl_dar/ckong_de10_lite.vhd`.
- Support sources: `rtl_dar/{ckong_sound, video_gen, line_doubler, gen_ram,
  io_ps2_keyboard, kbd_joystick}.vhd` (`kbd_joystick` unreferenced),
  `rtl_dar/ym_2149_linmix.vhd` (entity `ym2149`), `rtl_T80/*` (`T80s`, `Mode => 0`).
  100% VHDL plus the generated `clk_wiz_0` wrapper.
- MAME driver: `ckong` (`nichibutsu/cclimber.cpp`).
- Model: Bagman-FPGA-Dar (same video-addressing code, core-internal line doubler).
- Top entity `ckong_basys3`; project `vhdl_ckong_rev_0_1_2018_06_06/basys3/ckong_basys3.xpr`.

## 2. Clocking

- Original: 18.432 MHz crystal; Z80 3.072 MHz, pixel 6.144 MHz.
- `clk_wiz_0`: request 12.288 MHz, achieved 12.288 MHz (5 / 48 / 78.125, VCO 960 MHz);
  signal `clock_12`. Speed error 0. Retargeted 2026-10-01 from 12.000 MHz (5 / 49.875 /
  83.125, -2.34%, `../../../CLOCKING_SPEC.md` §4). DE10 original: `max10_pll_12M`.
- Enables: inside the core (`video_gen`: `ena_pixel` = `clock_12`/2; `cpu_clock` from
  `not hcnt(0)`). Core, `ckong_sound`/`ym2149`, PWM and keyboard all on `clock_12`, as the
  DE10 top.
- Video: pixel 6.144 MHz, h_total 384, v_total 264 → native H 16.000 kHz, V 60.61 Hz;
  31 kHz output H 32.000 kHz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

Dar's `ckong` entity unchanged; `tv15Khz_mode => sw(13)` (DE10 `sw(0)`). `dbg_cpu_addr`
`open` (DE10 7-segment chain not ported). No `led` port.

## 5. Video path

Core-internal `line_doubler` (`ckong.vhd:634`) with real `video_hs <= hsync_o`,
`video_vs <= vsync_o` (`ckong.vhd:219-220`); no expose patch, no scandoubler import. RGB
3/3/2 padded in both modes as the DE10 top: `r & '0'`, `g & '0'`, `b & "00"`; no blanking
mux. sw13: `0` = `video_hs`/`video_vs`; `1` = `video_csync` on HS, VS `'1'`.

## 6. Audio

`audio_out` 16 bits, mono. DE10 accumulator: 13 bits on `clock_12` adding
`audio(15 downto 4)`; `O_PMODAMP2_AIN` = bit 12. `SHUTD <= not sw(15)`,
`GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_12` (DE10 clocking), wrapper decoder (MAME keys,
  `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20. `kbd_joy(7:0)` keeps Dar's
  `joyHBCPPFRLDU` order: 0 up, 1 down, 2 left, 3 right (arrows), 4 Left Ctrl (jump), 5 key
  1, 6 key 2, 7 keys 5/6. Replaces `kbd_joystick` (renamed from `joyHBCPPFRLDU`; Dar's
  bits 8/9, Ctrl / W, were never merged).
- Core inputs: active-high; single `coin1`; P2 mirrors P1 (cocktail duplicates only).
- Merge: `not stick_s(n)` OR keys; JXADC1/2/3/4/7 = right/left/down/up/jump; coin =
  keys 5/6, btnU, btnD; start 1 = key 1, btnL; start 2 = key 2, btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_12` (2026-10-20).
- Debounce: none.
- Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw13 | `tv15Khz_mode`, sync mux | 1 | 31 kHz VGA | |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | 1 / 1 | low gain / on | |

Fixed: the DIP byte is a constant inside the core (`ckong.vhd:295`, `"10000000"`, upright);
needs a core patch.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/ckong_xor_width.patch` | `rtl_dar/ckong.vhd:405-408` | four XOR literals zero-padded to 13 bits (`&` binds tighter than `xor`, so the 13-bit vector is the operand; Vivado rejects the length mismatch); no behaviour change |
| `contrib/basys3/code/ckong_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated; name from `TOP_ENTITY` `ckong_basys3`) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_ckong_proms.bat` → shell; romset `ckong.zip` into
`tools/ckong_unzip/`; 8 PROM VHDL files with the entity names the core references:
`ckong_program`, `ckong_tile_bit0/1`, `ckong_big_sprite_tile_bit0/1`, `ckong_palette`,
`ckong_big_sprite_palette`, `ckong_samples`. Dar's `README.txt` names the `ckongpt2`
contents; all 17 files the `.bat` reads are in the `ckong` parent set.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. `make check`
reports a pre-existing core-internal HDL 9-3240 (`ckong_sound.vhd`). First bitstream
2026-09-07: no critical warnings or errors through implementation, post-route WNS
36.461 ns.

## 12. Open items

None.

