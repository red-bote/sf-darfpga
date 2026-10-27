# Defender-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_defender_rev_0_0_2017_10_15.zip` (darfpga@aol.fr), SHA-256 in
  `contrib/tools/setup_defender.sh`; extracted to `vhdl_defender_rev_0_0_2017_10_15/`.
  Core `rtl_dar/defender.vhd` (sound board, cpu09 in `rtl_jkent/`); DE10 top
  `rtl_dar/defender_de10_lite.vhd`.
- MAME driver: `midway/williams.cpp` (`defender`).
- Model: Burnin-Rubber / Burger-Time (same scandoubler wiring with a 12 MHz `clk_sys` and
  6 MHz `ce_x1`).

## 2. Clocking

- Original: 12 MHz master (E clock 12 / 3 / 4 = 1 MHz, MAME `williams.cpp:1537`; pixel
  8 MHz per the MAME screen setup); sound board 3.579545 MHz (315/88). Williams hardware
  description: 1 MHz video counter, 16640 counts per frame (16.64 ms), 304 x 256 visible.
  Dar's core uses 6 MHz, 384 px per 64 us line: same 15.625 kHz line and 60.1 Hz frame
  rate. The 512 px/line figure formerly derived here (8 MHz x 64 us) is not sourced and was
  dropped (user, 2026-10-27).
- `clk_wiz_0`: D 1 / M 7.875 / O0 65.625 / O1 110 (VCO 787.5 MHz): `clk_out1` = 12.000 MHz
  (`clock_12`: core, scandoubler `clk_sys`, keyboard), `clk_out2` = 7.159091 MHz
  (`clock_7p16`). `clock_3p58 = clock_7p16 / 2` in fabric (3.5795454 MHz) for the sound
  board and PWM: the MMCM cannot output 3.58 MHz (VCO floor ~600 MHz, max divide 128).
- Enables: `ce1` = `clock_12 / 2` (6 MHz pixel enable for the scandoubler); the core
  derives its own 6 MHz internally.
- Video: pixel 6 MHz, 384 × 260, 64 us per line → H 15.625 kHz (31 kHz output 31.25 kHz).
- Two clock domains (core `clock_12`, sound `clock_3p58`); predates the single-clock rule,
  not changed.

### Main CPU rate (1 MHz, 2026-10-02)

- Original MC6809E E clock = 1 MHz. Pristine `rtl_dar/defender.vhd:313-342` drives the
  cpu09 `clk` (E, falling-edge active) high at `pixel_cnt` 3 and 5 of the 6-pixel (1 us)
  period: 2 MHz (Dar: "speed up processor (two clocks / 1us)"). User decision: 1 MHz.
- `contrib/code/defender_cpu_1mhz.patch` removes the `pixel_cnt = "011"` (clear) and
  `"100"` (set) branches: `cpu_clock` high at `pixel_cnt` 3-5, low at 0-2, one falling edge
  per 1 us, 50% duty.
- RAM sharing: `wram_addr` selects the CPU address while `cpu_clock = '1'` (`:403-405`);
  video latches `wram*_do` at `pixel_cnt = 1` (`:427`). No overlap.
- cpu09 is not cycle-compatible with a 6809 (fewer cycles on several instructions,
  `rtl_jkent/cpu09l_128.vhd:14`): throughput at 1 MHz stays above the original.
- Hardware-confirmed 2026-10-02 (picture, sound). Revert: remove the patch.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

- `defender` entity kept. Inputs: `btn_auto_up`, `btn_advance`, `btn_high_score_reset`,
  `btn_left_coin`, `btn_one_player`, `btn_two_players`, `btn_fire`, `btn_thrust`,
  `btn_smart_bomb`, `btn_hyperSpace`, `btn_reverse`, `btn_down`, `btn_up` (active-high,
  from signals).
- `sw_coktail_table => cocktail_in` (signal, §8); `cmd_select_players_btn` open.
- `video_hs`/`video_vs` (left open "not tested" in the DE10 top, which uses csync only)
  feed the scandoubler; hardware-verified.
- `dbg_cpu_addr` open; the DE10 7-segment chain (`decodeur_7_seg`) not ported.

## 5. Video path

MiST `scandoubler.v` (`contrib/code/`, + `scandoubler_fix.patch`), instance
`scandoubler_inst`, `COLOR_DEPTH = 6`, `HCNT_WIDTH = 9` (defaults):

| Port | Signal | Note |
|---|---|---|
| `clk_sys` | `clock_12` | 12 MHz |
| `ce_x1` | `ce1` | 6 MHz, `clock_12 / 2` |
| `ce_x2` | `'1'` | every `clk_sys` edge |
| `scanlines` | `"00"` | |
| `hs_in` / `vs_in` | core `video_hs` / `video_vs` | direct, ~15.625 kHz |
| `r_in/g_in/b_in` | `vga_r_i = r & r`, `vga_g_i = g & g`, `vga_b_i = b & b & b` | 3/3/2 bits padded to 6, `"000000"` when `blankn = '0'` |

sw13: `0` = `vga_hs <= hsync_o`, `vga_vs <= vsync_o`, RGB `vga_*_o(5 downto 2)`;
`1` = `vga_r <= r & '0'`, `vga_g <= g & '0'`, `vga_b <= b & "00"`,
`vga_hs <= csync`, `vga_vs <= '1'`.

## 6. Audio

Dar's 13-bit PWM accumulator on `clock_3p58` (as the DE10 top): `pwm_accumulator <=
pwm_prev + audio_x4`, typed signals `pwm_prev = '0' & accumulator(11:0)`,
`audio_x4 = '0' & audio & "00"` (`audio_out` is 8 bits). With the synchronizer array type
visible, `&` inside a type conversion was ambiguous (HDL 9-1752). `O_PMODAMP2_AIN =
accumulator(12)`. `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_12`, wrapper decoder (MAME keys, F0 = release, E0
  ignored; `../../../PORTING_SPEC.md` §3.1, §4.3), 2026-10-20, replaces Dar's
  `kbd_joystick` (unreferenced) and its `keys_hua`. Keys: up/down arrows, Left Ctrl = fire,
  Left Alt = thrust, Z = reverse, Space = smart bomb, Left Shift = hyperspace, 1/2 = start,
  5/6 = coin, 9 = auto-up (toggle on make, typematic ignored, `kbd_9_held`), F2 = advance
  (held), F1 = high-score reset (held).
- Merge: JXADC1 = thrust (right), JXADC2 = reverse (left), JXADC3 = down, JXADC4 = up,
  JXADC7 = fire; coin = keys 5/6, btnU, btnD (single coin input); start 1 = key 1, btnL;
  start 2 = key 2, btnR.
- Synchronizers (2026-10-20): 2-FF `ASYNC_REG` on PS/2, JXADC and buttons, on `clock_12`
  (previously none). Wrapper signal `stick_s` carries JXADC.
- Debounce: JXADC fire, 2^17 `clock_12` cycles (10.9 ms), 2026-10-21; the debounced fire
  feeds normal fire and the combos.
- Combos (user-approved): smart bomb = JXADC down + fire, hyperspace = JXADC up + fire.
  `joy_fire <= kbd_joy(4) or (fire_db and stick_s(2) and stick_s(3))`: fire is not passed through
  while up or down is held; up/down pass through.
  - History: 2026-10-20 the combos were left/right + fire, which fired whenever the player
    fired while thrusting or reversing. 2026-10-21 moved to down/up + fire with fire passed
    through: no effect on hardware with a CX40-type joystick while Space / Left Shift worked
    (also with Left Ctrl held). Checks: joystick up held + Left Shift hyperspaced, so a held
    direction does not block it; the remaining difference was fire and hyperspace rising
    together. With fire suppressed in the combo both work (hardware-verified 2026-10-21).
- No joystick combos for coin/start.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `sw_coktail_table` | 1 | `'1'` (upright, Dar) | up = cocktail; `cocktail_in <= COCKTAIL_DEFAULT xor sw(12)`, 2026-10-20 |

No DIP bank: settings live in CMOS, changed with advance/auto-up/high-score reset.
sw13 display, sw14 gain, sw15 audio off.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/defender_cpu_1mhz.patch` | `rtl_dar/defender.vhd` | main CPU 1 MHz (§2) |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/defender_de10_lite_to_basys3.patch` | `rtl_dar/defender_de10_lite.vhd` | provenance record (generated) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, converts
`make_defender_proms.bat`, unzips `defender.zip` (`ROMZIP`) into `tools/defender_unzip/`,
generates `defender_prog.vhd` (11 ROMs concatenated with `cat`), `defender_decoder_2.vhd`,
`defender_decoder_3.vhd`, `defender_sound.vhd`.

## 11. Build

`make` (setup, create_prj, clk_wiz, patch), `make check`, `make bitstream`. Project
`vhdl_defender_rev_0_0_2017_10_15/basys3/defender_basys3.xpr` (top `defender_basys3`).

## 12. Open items

None.

