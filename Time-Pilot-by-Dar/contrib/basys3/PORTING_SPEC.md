# Time-Pilot-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_time_pilot_rev_0_0_2017_11_05.zip` (SourceForge `darfpga/files/Software
  VHDL/time_pilot`), SHA-256 in `contrib/tools/setup_time_pilot.sh`; extracted to
  `vhdl_time_pilot_rev_0_0_2017_11_05/`. Core `rtl_dar/time_pilot.vhd`; DE10 top
  `rtl_dar/time_pilot_de10_lite.vhd`.
- MAME driver: `timeplt` (romset `timeplt`); video timing from `konami/pooyan.cpp` (same
  Konami video hardware).
- Top entity `time_pilot_basys3`; part `xc7a35tcpg236-1`, VHDL. Model: Pooyan-by-Dar (same
  single-domain design).
- Project sources (`time_pilot_basys3.xpr`): `rtl_dar/` `time_pilot.vhd`,
  `time_pilot_sound_board.vhd`, `gen_ram.vhd`, `io_ps2_keyboard.vhd`, `kbd_joystick.vhd`
  (unreferenced since 2026-10-20); `rtl_T80/` `T80.vhd`, `T80_Pack.vhd`, `T80_ALU.vhd`,
  `T80_MCode.vhd`, `T80_RegX.vhd`, `T80se.vhd`; `rtl_mikej/YM2149_linmix_sep.vhd`;
  `clk_wiz_0`; MiST `scandoubler.v`; PROM VHDL from `tools/time_pilot_unzip/`.

## 2. Clocking

- Original: 18.432 MHz crystal (pixel 6.144 MHz, CPU 3.072 MHz), 14.31818 MHz sound.
- `clk_wiz_0`: request 24.576 MHz, achieved 24.573991 MHz (DIVCLK 5 / MULT_F 34.25 /
  CLKOUT0_DIVIDE_F 27.875), single output `clk_core` (2026-10-05).
- Enables: the former `clock_12`, `clock_6`, `clock_6n`, `clock_12n`, `clock_14`,
  `clock_14n`, sound `cpu_clock` and `ayx_clock` are clock enables, as Pooyan
  (`../../../Pooyan-by-Dar/contrib/basys3/PORTING_SPEC.md` §2: enable table, ROM
  address-hold mux, `gen_ram` `ce` port, 20-bit 14.318181 MHz phase accumulator `ce14`).
  Reason: VGA failed to sync on about half of the btnC resets; the register-derived clocks
  left the core-to-scandoubler path untimed (`../../../KNOWN_ISSUES.md`).
- Time-Pilot differences: T80se (v247) `CLK_n = clk_core`, `CLKEN = cpu_ena and ce6` (main),
  `CLKEN = cpu_ce` (sound); all T80se state, including `T80_RegX` `RAM16X1D` WE and the NMI
  edge detect, is CLKEN-gated. Six PROMs on the former `clock_6` (char, char palette,
  sprite, sprite palette, two RGB palettes) use the address-hold mux.
- Video: pixel 6.1435 MHz, 384 counts/line, 264 lines (§9 `vcnt` patch) → VGA 31.997 kHz,
  60.61 Hz. Pristine 260 lines gave 61.54 Hz. MAME `konami/pooyan.cpp`
  `set_raw(18.432_MHz_XTAL / 3, 384, 0, 256, 264, 16, 240)` ("measured ~60.6Hz");
  `timeplt.cpp` gives only a nominal 60 Hz. Replaced the 2026-10-01 263-line patch
  (`../../../CLOCKING_SPEC.md` 5.7).

## 3. Reset

`reset <= btnC or not mmcm_locked`, asserted asynchronously, released synchronously to
`clk_core`; MMCM reset = `btnC`. DE10 top: `reset <= not reset_n` (`key(0)`).

## 4. Core instantiation

| Basys 3 port | Function |
|---|---|
| `clk` (W5) | 100 MHz into `clk_wiz_0` |
| `btnC` | reset (active-high) |
| `btnU/D/L/R` | coin / coin / start 1 / start 2 (§7) |
| `sw(15:0)` | audio (§6), display (§5), DIPs (§8) |
| `ps2_clk` / `ps2_dat` (C17/B17) | keyboard |
| `JXADC(4:0)` (JXADC1-4, JXADC7) | joystick (active-low) |
| `O_PMODAMP2_AIN/GAIN/SHUTD` (JA1/2/4) | audio |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

- `time_pilot` port map kept (video r/g/b, csync, blankn, hs, vs, audio, enables from the
  single-domain patch). `video_r/g/b` are 5 bits/color (Pooyan: 3/3/2).
- T80 variant: `rtl_T80/T80.vhd` + `T80se.vhd` (Pooyan: `rtl_t80_350`/`T80pa`). It
  synthesizes with 0 errors; no T80 fix patch (Pooyan needs `pooyan_t80_xor_width.patch`).

## 5. Video path

- MiST `scandoubler.v` (`contrib/code/`, project copy patched by `scandoubler_fix.patch`);
  `clk_sys = clk_core`, `ce_x1 = ce6`, `ce_x2 = ce12`. Replaced the two-clock DECA
  `vga_scandoubler.v` on 2026-10-05.
- `hs_in`/`vs_in`: the core's `video_hs`/`video_vs`. The DE10 top leaves them `open`
  ("not tested") although `time_pilot.vhd` drives them; confirmed correct on hardware.
- RGB: 5 bits padded with one `'0'` (`r & "0"`) to 6, gated on `blankn`; output
  `(5 downto 2)`.
- sw13: `0` = scandoubler output; `1` = native RGB gated on `blankn`, `csync` on HS, VS
  `'1'` (wired 2026-10-02 via the DECA bypass, moved to the wrapper mux 2026-10-05).
- The tracked `.xpr` references the local import `sources_1/imports/mist/scandoubler.v`.

## 6. Audio

Dar's PWM accumulator, accumulating at the former `clock_14` rate (`ce14`), typed
`pwm_prev` signal (no `&` inside a type conversion); `O_PMODAMP2_AIN` = bit 12, mono.
`SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clk_core`, wrapper decoder (2026-10-20, replaces
  `kbd_joystick`; `../../../PORTING_SPEC.md` §3.1, `rb-fpga/ref-repos` Time-Pilot mapping plus
  key 6), F0 = release, E0 ignored: arrows = move, Left Ctrl = fire, 5 / 6 = coin, 1 / 2 =
  start (previously Space fire, F1 coin, F2/F3 start).
- Core inputs: active-high; P2 mirrors P1 movement/fire.
- Merge: directions = arrows or `not JXADC(0..3)`; fire = Left Ctrl or `not JXADC(4)`;
  coin = 5/6 or btnU/btnD (btnD 2026-10-20); start 1/2 = 1/2 or btnL/btnR.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clk_core`. With raw PS/2 at
  24.57 MHz the Time-Pilot keyboard misbehaved (user evaluation 2026-10-05; Pooyan showed
  no fault); the synchronizer was re-instated on both.
- Debounce: none.
- Combos: none (removed 2026-10-02).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw11-8 | `dip_switch_1` | 3-0 | `X"FF"` | Coinage A; `dip1 = X"FF" xor (x"0" & sw(11:8))` (2026-10-20) |
| sw7-0 | `dip_switch_2` | 7-0 | `0` | Sound(8) / Difficulty(7-5) / Bonus(4) / Cocktail(3) / Lives(2-1); direct `sw(7 downto 0)` (Pooyan pattern); hardware-confirmed |

The DE10 top hardcoded both registers (`dip_switch_1 => X"FF"`, `dip_switch_2 => X"4F"`).
Fixed: Coinage B (`dip_switch_1` bits 7-4).

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/time_pilot_single_domain.patch` | `rtl_dar/time_pilot.vhd`, `time_pilot_sound_board.vhd`, `gen_ram.vhd` | single clock domain (§2); CRLF, `setup_time_pilot.sh --binary`; sorts and applies before the 264-line patch |
| `contrib/code/time_pilot_vcnt_264_lines.patch` | `rtl_dar/time_pilot.vhd` | `vcnt` reload `0x0FC` → `0x0F8`, 264 lines, 60.61 Hz (2026-10-06) |
| `contrib/code/scandoubler_fix.patch` | project `imports/mist/scandoubler.v` | Vivado rejects the single-value unpacked array size |
| `contrib/basys3/code/time_pilot_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated by `make patch`) |

`setup_time_pilot.sh` globs `contrib/*/code/*.patch` and excludes the provenance patch and
`scandoubler_fix.patch` by name.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, converts
`make_time_pilot_proms.bat` to shell, unzips `ROMZIP` (default `~/roms/timeplt.zip`) into
`tools/time_pilot_unzip/`, and generates `time_pilot_prog.vhd`,
`time_pilot_sound_prog.vhd`, `time_pilot_char_grphx.vhd`, `time_pilot_sprite_grphx.vhd`,
`time_pilot_palette_blue_green.vhd`, `time_pilot_palette_green_red.vhd`,
`time_pilot_char_color_lut.vhd`, `time_pilot_sprite_color_lut.vhd`. The `.xpr` references
them in place. Never committed.

## 11. Build

`make setup`, `make create_prj` (project tree, `.xpr`, `Basys-3-Master.xdc`,
`scandoubler.v` + fix), `make clk_wiz`, `make patch`, `make check`, `make synth` /
`make bitstream`. Project `basys3/time_pilot_basys3.xpr` (not nested). Constraints: the
Digilent master XDC with `btnC/U/D/L/R`, `JXADC[0:4]` (`PULLUP true`), `sw`, `ps2_*`,
`O_PMODAMP2_*` and VGA lines enabled. Vivado from `/tmp`; `VIVADO` →
`/tools/Xilinx/Vivado/2020.2/bin/vivado`.

## 12. Open items

None.
