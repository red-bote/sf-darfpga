# Traverse-USA-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_traverse_usa_rev_0_0_2019_03_16.zip` (SourceForge `darfpga/files/Software
  VHDL/traverse_usa`), SHA-256 in `contrib/tools/setup_traverse_usa.sh`; extracted to
  `vhdl_traverse_usa_rev_0_0_2019_03_16/`. Core `rtl_dar/traverse_usa.vhd` (entity
  `traverse_usa`); DE10 top `rtl_dar/traverse_usa_de10_lite.vhd`.
- Support sources: `rtl_dar/{moon_patrol_sound_board,gen_ram,io_ps2_keyboard,kbd_joystick}.vhd`
  (`kbd_joystick` unreferenced since 2026-10-20), `rtl_jkent/cpu68.vhd` (M6803),
  `rtl_mikej/ym_2149_linmix.vhd`, `rtl_T80/*`.
- MAME driver: `travrusa` (romset `travrusa`).
- Top entity `traverse_usa_basys3`; part `xc7a35tcpg236-1`, VHDL. Model: Burnin-Rubber
  (scandoubler wiring shape), Galaga (derived `clk_sys`).

## 2. Clocking

- Original: 18.432 MHz main/video crystal (Z80 3.072 MHz, pixel 6.144 MHz); sound board
  (Irem M52) 3.579545 MHz (`../../../CLOCK_CRYSTAL_CATALOG.md`).
- DE10: `max10_pll_36p86M_3p58M` derives 36.86 and 3.58 MHz from 50 MHz.
- `clk_wiz_0` (one MMCM, two outputs): request 36.86 / 7.16 MHz, achieved `clk_out1` =
  36.842105 MHz (`clock_36`, core) and `clk_out2` = 7.159091 MHz (`clock_7p16`); DIVCLK 1 /
  MULT_F 7.875 / CLKOUT0 21.375 / CLKOUT1 110, VCO 787.5 MHz. `clock_3p58` =
  `clock_7p16` / 2 (fabric toggle) for the sound board and PWM (Defender pattern).
- Keyboard: on `clock_36` since 2026-10-20 (§7). The DE10 top derived a ~3 MHz keyboard
  toggle from a mod-6 counter; the port first used a mod-3 `clock_kbd` (~6.14 MHz).
- Video: pixel `clock_36` / 6 = 6.140351 MHz (`pix_ena` twice per 12-state `clock_cnt`),
  384 counts/line (`hcnt` 128-511), 282 lines (`vcnt` 230-511) → native 15.99 kHz /
  56.70 Hz, VGA 31.98 kHz.
- Separate domains kept (not converted): `clock_3p58`/`clock_7p16` (sound) and the fabric
  scandoubler `sd_clock_12` (§5). Retune to 36.864 MHz was optional and skipped
  (2026-10-01).

## 3. Reset

`reset <= btnC or not mmcm_locked` (Bagman/Berzerk/Pooyan pattern); MMCM reset = `btnC`.

## 4. Core instantiation

- `traverse_usa` port map kept; inputs `coin1`, `start1/2`, `right1/2`, `left1/2`,
  `accel1/2`, `brake1/2`, `dip_switch_1/2`; no fire input. `accel1` = `input_1` bit 5,
  `brake1` = bit 7.
- `video_hs`/`video_vs` are declared but not driven by the shipped core;
  `traverse_usa_expose_video_timing.patch` (§9) enables them.
- `dbg_cpu_addr` left `open`.

## 5. Video path

The core declares `video_hs`/`video_vs` but its drivers are commented out (the DE10 top
also leaves them `open`, "not tested"); only `video_csync` is active. Category: core needs a
patch to expose hsync/vsync (as Phoenix/Xevious/Zaxxon; no `tv15Khz_mode`, no internal
`line_doubler`). The patch un-comments the dormant drivers:

```vhdl
video_hs <= hsync0;
if    vsync_cnt = 0 then video_vs <= '0';
elsif vsync_cnt = 8 then video_vs <= '1';
end if;
```

`video_hs` is the core's real per-line `hsync0` pulse (already valid
horizontal sync, unconditional every line). `video_vs` is built from the
existing `vsync_cnt` variable; a 4-bit feedback counter that the
composite-sync generator already runs (it counts 0→F and is reset at line
start): `video_vs` is low only while `vsync_cnt = 0`, high otherwise, giving a
1-line vertical-sync pulse inside the existing blanking window (the same
`vsync_cnt = 8` pulse-width convention Burnin-Rubber uses). Deliberately
independent of the legacy equalizing/serration machinery that drives
`video_csync`.

No `line_doubler.vhd` exists in this core's archive (that's
Bagman/Berzerk's structurally different no-scandoubler approach), and the
wrapper is not inside the core, so the patch is the only viable fix; matching
the Phoenix/Xevious/Zaxxon signature (no `tv15Khz_mode` input, no internal
`line_doubler`) from the `xpr-dependency-closure` skill's classification
table.

### 5.1 Scandoubler wiring

- MiST `scandoubler.v` (`contrib/code/`, unmodified; project copy under `imports/mist/`
  patched by `scandoubler_fix.patch` in `create_project.sh`), `COLOR_DEPTH = 6`,
  `HCNT_WIDTH = 9` (defaults).
- Clocks: `sd_clock_12` (`clk_sys`) and `sd_clock_6` (`ce_x1`) from a mod-6 counter on
  `clock_36`, Galaga pattern (`../../../Galaga-Midway-by-Dar/contrib/basys3/PORTING_SPEC.md`
  §5.1: a fast clock directly on `clk_sys` "no funciona"); `ce_x2` `'1'`. `sd_clock_12` is a
  register-derived clock (untimed path, `../../../KNOWN_ISSUES.md`).

| Port | Direction | Connected signal | Type/width |
|---|---|---|---|
| `clk_sys` | in | `sd_clock_12` (derived, see above) | `std_logic` |
| `scanlines` | in | `"00"` (literal) | `std_logic_vector(1 downto 0)` |
| `ce_x1` | in | `sd_clock_6` (derived) | `std_logic` |
| `ce_x2` | in | `'1'` (literal) | `std_logic` |
| `hs_in` | in | `hsync` (core `video_hs`) | `std_logic` |
| `vs_in` | in | `vsync` (core `video_vs`) | `std_logic` |
| `r_in` | in | `vga_r_i` | `std_logic_vector(5 downto 0)` |
| `g_in` | in | `vga_g_i` | `std_logic_vector(5 downto 0)` |
| `b_in` | in | `vga_b_i` | `std_logic_vector(5 downto 0)` |
| `hs_out` | out | `hsync_o` | `std_logic` |
| `vs_out` | out | `vsync_o` | `std_logic` |
| `r_out` | out | `vga_r_o` | `std_logic_vector(5 downto 0)` |
| `g_out` | out | `vga_g_o` | `std_logic_vector(5 downto 0)` |
| `b_out` | out | `vga_b_o` | `std_logic_vector(5 downto 0)` |

- `hs_in`/`vs_in`: the core's patched `video_hs`/`video_vs`, no intermediate logic.
  `video_csync` drives `csync` for TV mode only.
- RGB: core 2/3/3 bits (`video_r(1:0)`, `video_g(2:0)`, `video_b(2:0)`), padded to 6 by MSB
  replication, black while `blankn = '0'`:

  ```vhdl
  vga_r_i <= r & r & r      when blankn = '1' else "000000";
  vga_g_i <= g & g           when blankn = '1' else "000000";
  vga_b_i <= b & b           when blankn = '1' else "000000";
  ```
- `scanlines` `"00"`.

### 5.2 Display mode (sw13)

- `sw(13) = '0'`: 31 kHz VGA, sync from the scandoubler, top 4 of 6 bits:

  ```vhdl
  vga_hs <= hsync_o;  vga_vs <= vsync_o;
  vga_r   <= vga_r_o(5 downto 2);
  vga_g <= vga_g_o(5 downto 2);
  vga_b  <= vga_b_o(5 downto 2);
  ```
- `sw(13) = '1'`: 15 kHz TV, native RGB padded with zeros, csync on HS, VS high:

  ```vhdl
  vga_r <= r & "00";  vga_g <= g & '0';  vga_b <= b & '0';
  vga_hs <= csync;  vga_vs <= '1';
  ```
- Caveat: the patched `video_hs`/`video_vs` are not validated on hardware in Dar's
  original release; validated on the Basys 3 build.

## 6. Audio

`audio(10:0)` mono. Dar's PWM accumulator verbatim (`'0' & acc(11:0)` + `audio & "00"`,
13 bits, `O_PMODAMP2_AIN` = bit 12) on `clock_3p58` (same clock as
`moon_patrol_sound_board`). `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: onboard USB-HID host (C17 `ps2_clk`, B17 `ps2_dat`). `io_ps2_keyboard` and the
  wrapper decoder on `clock_36` (2026-10-20, replaces `kbd_joystick`;
  `../../../PORTING_SPEC.md` §3.1, MAME `travrusa`), F0 = release, E0 ignored, into
  `kbd_joy(8:2)`: Left/Right arrows = steer, Left Ctrl = accelerate, Left Alt = brake,
  5 / 6 = coin, 1 / 2 = start. Previously Dar's `kbd_joystick` (up/Space accelerate, down
  brake, F1 coin, F2/F3 start).
- Keyboard clock history: the pristine ~3 MHz toggle left the USB-HID port non-functional
  (same symptom as Arcade_Zaxxon and Congo Bongo, hardware 2026-09-03); fixed with a
  ~6.14 MHz `clock_kbd`; moved to `clock_36` 2026-10-20 (user-approved refactor, removes the
  fabric clock and the crossing into the core; precedent Kick/Popeye/Solar-Fox 40 MHz,
  Computer-Space 48 MHz). Hardware-verified 2026-10-21.
- Core inputs: active-high levels; P2 mirrors P1 (`right2`/`left2`/`brake2`/`accel2` on the
  P1 signals, as the DE10 top).
- Merge: `core_accel <= kbd_joy(4) or not jxadc_s(4)` (Left Ctrl / JXADC7);
  `core_brake <= kbd_joy(8) or not jxadc_s(2)` (Left Alt / JXADC3); left/right =
  arrows or JXADC2/JXADC1; coin = 5/6 or btnU/btnD (single `coin1`); start 1/2 = 1/2 or
  btnL/btnR. JXADC4 (up) accelerated until 2026-10-20; removed (user), unused.
- Down+fire asserts brake and accelerate (fire passes through); brake alone covers the
  §3.1 down+fire entry.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_36` (2026-10-20;
  previously JXADC and buttons unsynchronized).
- Debounce: none. Combos: down+fire only (§3.1).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw7-0 | `dip_switch_2` | 7-0 | `x"FE"` | Diag(7) / Demo(6) / Zippy(5) / Freeze(4) / M-Km(3) / Coin mode(2) / Cocktail(1) / Flip(0) |
| sw11-8 | `dip_switch_1` | 3-0 | `x"FF"` | Cont. play(3) / Fuel consumption(2) / Fuel lost when collision(1-0) |

`dip = DEFAULT xor sw` (2026-10-20, `../../../PORTING_SPEC.md` §3.2; previously
hardcoded). Fixed: Coinage_B (`dip_switch_1` bits 7-4). sw12 spare.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/traverse_usa_expose_video_timing.patch` | `rtl_dar/traverse_usa.vhd` | enables the dormant `video_hs`/`video_vs` drivers (§5); behaviour fix, the pristine core synthesizes but has no VGA sync. Verify: `grep -n 'video_hs <= hsync0' <SRC_DIR>/rtl_dar/traverse_usa.vhd` |
| `contrib/code/scandoubler_fix.patch` | project `imports/mist/scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/traverse_usa_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No width/sensitivity synthesis fix was needed for this core.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, converts `make_travusa_proms.bat`
to shell, unzips `ROMZIP` (default `~/roms/travrusa.zip`) into `tools/travusa_unzip/` and
generates `travusa_cpu.vhd`, `travusa_chr_bit1/2/3.vhd`, `travusa_chr_palette.vhd`,
`travusa_spr_bit1/2/3.vhd`, `travusa_spr_palette.vhd`, `travusa_spr_rgb_lut.vhd`,
`travusa_sound.vhd`. The project references them in place. Never committed.

## 11. Build

`make setup` (fetch to `dloads/` with SHA-256 check, extract, video-timing patch, PROMs),
`make create_prj` (`.xpr`, `Basys-3-Master.xdc`, scandoubler import), `make clk_wiz`,
`make patch`, `make check`, `make synth` / `make bitstream`, `make load`. Project
`basys3/traverse_usa_basys3.xpr` (not nested). Vivado from `/tmp`; `VIVADO` →
`/tools/Xilinx/Vivado/2020.2/bin/vivado`; `ROMZIP` → `~/roms/travrusa.zip`.

## 12. Open items

- Sound clocks `clock_7p16`/`clock_3p58` and the scandoubler `sd_clock_12` are separate,
  partly register-derived domains (`../../../KNOWN_ISSUES.md`); single-domain conversion
  (Pooyan pattern) not done.
