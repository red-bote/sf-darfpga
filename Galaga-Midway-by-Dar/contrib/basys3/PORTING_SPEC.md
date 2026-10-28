# Galaga-Midway-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_galaga_rev_0_3_2018_05_06.zip` (SourceForge `darfpga/files/Software
  VHDL/galaga`), SHA-256 in `contrib/tools/setup_galaga.sh`; extracted to
  `vhdl_galaga_rev_0_3_2018_05_06/`. Core `rtl_dar/galaga.vhd`; DE10 top
  `rtl_dar/galaga_de10_lite.vhd`.
- MAME driver: `galaga` (romsets `galaga` + `galagamw`).
- Top entity `galaga_basys3`; part `xc7a35tcpg236-1`, VHDL. Model: Pooyan-by-Dar
  (wrapper shape); the scandoubler wiring follows Dar's Arcade_Galaga MiST pattern.

## 2. Clocking

- Original: 18.432 MHz crystal; CPUs 3.072 MHz, pixel 6.144 MHz (MAME `galaga`).
- `clk_wiz_0`: request 36.864 MHz, achieved 36.863711 MHz (DIVCLK 6 / MULT_F 56.125 /
  CLKOUT0_DIVIDE_F 25.375), single output `clk_core`. Forced by `sed` in
  `make_clk_wiz_0.sh`: Vivado's own solve (36.86594 MHz) puts VGA H at 32.0017 kHz.
  Retargeted 2026-10-01 from 36.000 MHz (5 / 49.5 / 27.5; -2.34% speed,
  `../../../CLOCKING_SPEC.md` §4).
- Single clock domain (2026-10-28): `clk_core` clocks the core, the scandoubler, the
  keyboard, the synchronizers, the debounce and the PWM. No fabric-derived clocks.
- Enables, from a free-running toggle `ce18` in the wrapper (an enable is high in the
  `clk_core` cycle that ends at its edge):

  | Enable | Edge | Replaces |
  |---|---|---|
  | `ce18` | every other `clk_core` edge | `rising_edge(clock_18)`; T80 `CLKEN = cpuN_ena and ce18`; `mb88` `ce`; stars and sound machines; `spram1/2`; debounce, PWM |
  | `ce18n` (`not ce18`) | the other edges | `clock_18n`: IO/latch process, `bgram`, `wram1-3`, sound RAMs, stars ROM, `mb88` `ce_n` |
  | `ce_pix` (`ena_vidgen and ce18`) | 1 in 6 edges, 6.144 MHz | video generator `enable`; scandoubler `ce_x1` after a 2-cycle delay (§5.1) |

- Memories: `gen_ram` gains `ce : in std_logic := '1'` gating write and registered read.
  Generated PROMs have no enable: each ROM address is held between its enabled edges
  (captured on its enable, live while enabled), so each ROM output changes only on its
  former edge. Core patch: `contrib/code/galaga_single_domain.patch` (§9).
- History: until 2026-10-28 the core ran on `clock_18`, a fabric toggle of `clock_36`
  with async reset, and the scandoubler on `clock_12` / `clock_6` from a free-running
  mod-6 counter on `clock_36`. `clock_18` restarted at an arbitrary point after each MMCM
  lock, so the offset between pixel update and scandoubler sample changed per start;
  about 1 in 5 starts showed distorted static tiles until the next start
  (`../../../KNOWN_ISSUES.md`). User decision 2026-10-28: single domain (Pooyan /
  Time-Pilot pattern), chosen over a minimal fix (exported pixel enable, `clock_18` kept)
  for long-term maintainability; cost: core RTL patch. The DE10 top derived a `clock_9` for
  the keyboard; on Basys 3 it was used until 2026-10-20.
- Video: pixel 6.144 MHz, 384 counts/line, 264 lines → 16.0 kHz / 60.61 Hz native,
  31.9998 kHz after doubling.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC` (2026-10-01; previously
`locked => open`, MMCM reset `'0'`). DE10 top: `reset <= not key(0)`.

## 4. Core instantiation

DE10-lite → Basys 3 port list (confirmed against `rtl_dar/galaga_de10_lite.vhd`):

| DE10-lite (pristine) | Basys 3 wrapper | Function |
|---|---|---|
| `max10_clk1_50` (50 MHz) | `clk` (W5, 100 MHz) | into `clk_wiz_0` MMCM |
| `key(0)` (active-low, aliased `reset_n`) | `btnC` (active-high) | reset |
| `key(1)`, `sw(9:0)`, `ledr(9:0)` | (dropped) | unused on the DE10 top |
| (none) | `btnU/D/L/R` | coin / coin / start 1 / start 2 (§7) |
| (none) | `sw(15:0)` | sw15/14 audio (§6), sw13 display (§5), sw12 `b_test` (§8) |
| `gpio(35)`/`gpio(34)` (aliased `ps2_clk`/`ps2_dat`) | `ps2_clk` / `ps2_dat` (C17/B17, onboard USB HID) | PS/2 keyboard |
| (none) | `JXADC(4:0)` (JXADC1-4, JXADC7) | joystick (active-low); no DE10-lite equivalent (keyboard-only on that board) |
| `gpio(1)`/`gpio(3)` (aliased `pwm_audio_out_l`/`_r`, both driven from one PWM accumulator) | `O_PMODAMP2_AIN/GAIN/SHUTD` (JA1/2/4) | PWM audio (PmodAMP2), mono |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, unchanged port shape; source changes from direct `csync`/`'1'` to the scandoubler (§5) |

- `galaga` entity (after `galaga_single_domain.patch` and `galaga_vga_sync.patch`, §9):
  `clk_core`, `ce18`, `reset` in; `ce_pix` out;
  `video_r(2:0)`, `video_g(2:0)`, `video_b(1:0)`, `video_clk`, `video_csync`, `video_blankn`,
  `video_hs`, `video_vs` out; `audio(9:0)` out; inputs `b_test`, `b_svce`, `coin`,
  `start1/2`, `left1/2`, `right1/2`, `fire1/2`. No DIP bank ports (DIP banks are constants
  inside the core).
- Port map unchanged except `video_hs`/`video_vs` into the scandoubler and `b_test` from
  sw12 (§8).

## 5. Video path

MiST `scandoubler.v` (`contrib/code/`, project copy patched by `scandoubler_fix.patch`),
instance `scandoubler_inst`, `COLOR_DEPTH = 6`, `HCNT_WIDTH = 9` (defaults).

| Port | Direction | Connected signal | Type/width |
|---|---|---|---|
| `clk_sys` | in | `clk_core` | `std_logic` |
| `scanlines` | in | `"00"` (literal) | `std_logic_vector(1 downto 0)` |
| `ce_x1` | in | `ce_x1` (`ce_pix` delayed 2 cycles) | `std_logic` |
| `ce_x2` | in | `ce_x2` | `std_logic` |
| `hs_in` | in | `hsync` | `std_logic` |
| `vs_in` | in | `vsync` | `std_logic` |
| `r_in` | in | `vga_r_i` | `std_logic_vector(5 downto 0)` |
| `g_in` | in | `vga_g_i` | `std_logic_vector(5 downto 0)` |
| `b_in` | in | `vga_b_i` | `std_logic_vector(5 downto 0)` |
| `hs_out` | out | `hsync_o` | `std_logic` |
| `vs_out` | out | `vsync_o` | `std_logic` |
| `r_out` | out | `vga_r_o` | `std_logic_vector(5 downto 0)` |
| `g_out` | out | `vga_g_o` | `std_logic_vector(5 downto 0)` |
| `b_out` | out | `vga_b_o` | `std_logic_vector(5 downto 0)` |

- `hs_in`/`vs_in`: the core's native `video_hs`/`video_vs` (15 kHz class, 384 counts/line,
  264 lines), no intermediate logic. `video_csync` drives `vga_hs` only in TV mode.
- RGB: 3/3/2 bits padded to 6 by MSB replication, black while `blankn = '0'`:
  `vga_r_i <= r & r`, `vga_g_i <= g & g`, `vga_b_i <= b & b & b`. Output `(5 downto 2)`.
- `scanlines` `"00"`.

### 5.1 Scandoubler clocks

- `clk_sys` = `clk_core` (36.864 MHz MMCM output).
- `ce_x1` = `ce_pix` delayed 2 `clk_core` cycles. `ce_pix` (one cycle in 6) marks the
  edge R0 where the video generator advances `hcnt`. Core output per pixel (`ce18` edges
  R0, R1, R2): `bgpalette_do` changes at R1, `rgb_palette_do` at R2; the video mux
  registers `video_r/g/b` on every `ce18` edge and at R2 combines the new
  `rgb_palette_addr` (its `"1111"` star/transparent test) with the old `rgb_palette_do`.
  The output is final from R0 to R2 and transient from R2 to the next R0. A sample at
  `ce_pix` (just before R0) stores the transient: with `ce_x1 = ce_pix` (2026-10-28 08:05
  build) every start showed wrong pixels at text and status tile edges. Valid sample
  edges: R0+1 to R0+4 `clk_core` cycles; R0+2 is used. The path is timed (one clock).
- `ce_x2` = `ce_x1` or `ce_x1` delayed 3 `clk_core` cycles (12.288 MHz, contains every
  `ce_x1` strobe), the Pooyan pattern.
- In the former asynchronous scheme the sample point relative to R0 changed per start and
  landed in the transient on some starts (about 1 in 5).
- Former scheme (until 2026-10-28, §2 History): `clk_sys` = fabric `clock_12` pulse train,
  `ce_x1` = fabric `clock_6`, `ce_x2` = `'1'`. A source comment (`-- clock_18, video_clk i
  clock_36 no funciona`) records that Dar's attempts with `clock_18` or `clock_36` as
  `clk_sys` did not work.

Signal flow:

```
galaga core                          galaga_basys3.vhd                         scandoubler_inst              galaga_basys3.vhd            board pins
------------                         ------------------                        -----------------              ------------------            ----------
video_hs   ------------------------> hsync -----------------------------------> hs_in
video_vs   ------------------------> vsync -----------------------------------> vs_in
video_r(2:0), video_g(2:0),
video_b(1:0), video_blankn --------> r, g, b, blankn
                                      vga_r_i <= r&r      (or 0 if !blankn) ---> r_in
                                      vga_g_i <= g&g      (or 0 if !blankn) ---> g_in
                                      vga_b_i <= b&b&b    (or 0 if !blankn) ---> b_in
                                      clk_core ------------------------------> clk_sys
                                      ce_x1 ---------------------------------> ce_x1
                                      ce_x2 ----------------------------------> ce_x2
                                      "00" ------------------------------------> scanlines
                                                                                 hs_out ---> hsync_o -------> vga_hs
                                                                                 vs_out ---> vsync_o -------> vga_vs
                                                                                 r_out(5:2) -----------------------------------> vga_r ---> VGA connector R
                                                                                 g_out(5:2) -----------------------------------> vga_g ---> VGA connector G
                                                                                 b_out(5:2) -----------------------------------> vga_b ---> VGA connector B
```

### 5.2 Display mode (sw13)

- `sw(13) = '0'`: scandoubler output, `vga_hs <= hsync_o`, `vga_vs <= vsync_o`.
- `sw(13) = '1'`: 15 kHz TV, native RGB padded to 4 bits (`r & '0'`, `g & '0'`, `b & "00"`,
  blanked on `blankn`), `vga_hs <= csync`, `vga_vs <= '1'`. Needs a 15 kHz RGB monitor.
  The scandoubler and counter keep running. Mirrors the DE10 top's commented
  `tv15Khz_mode` design.

## 6. Audio

Dar's 13-bit PWM accumulator on `clk_core` gated by `ce18` (`'0' & acc(11:0)` + `audio & "000"`),
`O_PMODAMP2_AIN` = bit 12; the DE10 top drove both `pwm_audio_out_l/_r` from it; mono here.
`SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clk_core`, wrapper decoder (2026-10-20, replaces
  `kbd_joystick`; `../../../PORTING_SPEC.md` §3.1, `rb-fpga/ref-repos` Galaga mapping), F0 =
  release, E0 ignored. Left 6B, Right 74, fire Left Ctrl 14, coin 5 2E / 6 36, start 1 16 /
  2 1E. Previous map (Dar `kbd_joystick`): Space fire, F3 coin, F1/F2 start.
- Core inputs: active-high; `coin`, `start1/2` and `fire1/2` are rising-edge latched inside
  the core's 51xx logic (§7.1); left/right are levels. P2 mirrors P1 left/right/fire.
- Merge: left = Left arrow or `not JXADC(1)`; right = Right arrow or `not JXADC(0)`; fire =
  Left Ctrl or debounced JXADC7; coin = 5/6 or btnU/btnD; start 1/2 = 1/2 or btnL/btnR.
  JXADC3/4 unused.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clk_core` (2026-10-20;
  previously buttons only).
- Debounce: btnU/D/L/R and JXADC7, 2^18 `ce18` cycles (14.2 ms), on `clk_core` gated by
  `ce18` (a first version on the ungated `clock_36` changed next to the fabric `clock_18`
  edges and btnU registered inconsistently; with one clock domain the crossing is gone).
  Buttons since 2026-10-02 (release bounce counted extra coins). Fire since 2026-10-20
  (bounce on `rb-fpga/ref-repos` hardware 2026-10-19); removed for one test with a CX40-type
  joystick, restored 2026-10-21 (fire on press and release).
- Combos: none (removed 2026-10-02).

### 7.1 JXADC fire debounce: rationale (2026-10-21)

The wrapper debounce does not reproduce a circuit on the original board.

- **Original hardware:** player inputs go to the Namco 51xx custom I/O chip (Fujitsu MB8843
  MCU with its own firmware); the main CPU reads it through the 06xx interface. The 51xx
  firmware reports one fire press per button press and counts coins, and samples the
  switches at its polling-loop rate. Contact bounce (a few ms) is shorter than that loop, so
  the firmware does not see it. No dedicated debounce circuit on the schematic is known
  (from memory; no schematic in this repo).
- **Dar's core:** `rtl_dar/galaga.vhd` emulates the 51xx in logic. Release 0.2
  (`galaga.vhd:26`, "fixes twice bullets on single shot") added a rising-edge latch on
  `fire1`/`fire2` (`galaga.vhd:836-840`), cleared once per 51xx read cycle
  (`galaga.vhd:822-831`). Before 0.2 the fire level passed through, and a press held across
  two read cycles gave two bullets. The latch fixes that for a clean input: Dar's DE10
  build had only the PS/2 keyboard through `kbd_joystick`, one edge per key press, no
  bounce.
- **This port:** the edge detect runs on every 18.432 MHz clock, so it catches every rising
  edge, including the short ones from a bouncing contact. The JXADC joystick is the first
  input on this core that bounces: on release, a bounce reads as a new press, sets
  `fire1_mem` again, and the game fires a second bullet (seen with a CX40-type joystick on
  2-FF only, 2026-10-21). The 14 ms debounce gives the core what it assumes: one clean
  edge per press. It sits in the wrapper (no core patch). A closer reproduction of the
  original would sample fire at the CPU read rate inside the 51xx emulation, which needs a
  core patch.
- **Contrast, Xevious:** `rtl_dar/xevious.vhd:1240`/`:1250` passes the fire level to the
  CPU with no edge detect; the game software polls about once per frame (16.7 ms), which
  filters bounce. Xevious JXADC fire shows no double shots without a debounce (hardware,
  2026-10-21).

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `b_test` | 1 | `'1'` (off) | up = test / service mode (2026-10-20) |

Fixed (not on a switch): `b_svce` `'1'`; DIP banks A/B are constants inside
`rtl_dar/galaga.vhd` (need a core patch).

## 9. Patches

Applied by `setup_galaga.sh` (`patch -p1 --forward`), except `scandoubler_fix.patch`
(applied by `create_project.sh` to the project copy of `scandoubler.v`; the tracked
`contrib/code/scandoubler.v` stays unmodified) and the provenance patch.

| Patch | Target | Reason | Verify |
|---|---|---|---|
| `contrib/code/galaga_bgpalette_xor_length_fix.patch` | `rtl_dar/galaga.vhd` `bgpalette_addr` (~l.521) | `xor` of a 3-bit (prefix bit concatenated first) and a 2-bit operand; parenthesize `hcnt(1 downto 0) xor (flip_h & flip_h)`, then prefix | `grep -n 'xor (flip_h & flip_h))))' <SRC_DIR>/rtl_dar/galaga.vhd` |
| `contrib/code/galaga_credit_mode_fix.patch` | `rtl_dar/galaga.vhd:848` | Start ignored after coin; `cs51XX_credit_mode <= '1'` on every coin edge (investigation on hold: `contrib/code/51xx_credit_state_machine_investigation.md`) | `grep -n "cs51XX_credit_mode <= '1'" ...` |
| `contrib/code/galaga_single_domain.patch` | `rtl_dar/galaga.vhd`, `gen_ram.vhd`, `mb88.vhd`, `sound_machine.vhd`, `stars.vhd`, `stars_machine.vhd` | single clock domain (§2): `clk_core` with `ce18` / `ce18n` / `ce_pix` enables, `gen_ram` `ce`, ROM address hold, exported `ce_pix` | `grep -n "ce_pix  <= ena_pix" ...` |
| `contrib/code/galaga_vga_sync.patch` | `rtl_dar/galaga.vhd` | applied after `galaga_single_domain.patch` (glob order; its context includes `enable  => ena_pix`); uncomments `video_hs`/`video_vs` and wires the video generator's `hsync`/`vsync` to them | `grep -n "hsync   => video_hs" ...` |
| `contrib/code/scandoubler_fix.patch` | project `imports/mist/scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range | |
| `contrib/basys3/code/galaga_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated by `make patch`) | |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, converts `make_galaga_proms.bat` to
shell, unzips `ROMZIP1` / `ROMZIP2` (default `~/roms/galaga.zip`, `~/roms/galagamw.zip`;
two variables, not the single `ROMZIP`) and generates `galaga_cpu1/2/3.vhd`,
`cs54xx_prog.vhd`, `sp_graphx.vhd`, `bg_graphx.vhd`, `sp_palette.vhd`, `bg_palette.vhd`,
`rgb.vhd`, `sound_samples.vhd`, `sound_seq.vhd`. Never committed. `galagamw` provides the
`3200a`-`3700g` CPU ROMs missing from `galaga`.

## 11. Build

`make setup` (extract, patches, PROMs), `make create_prj` (project, XDC, scandoubler copy +
fix), `make clk_wiz`, `make patch` (places the tracked wrapper, regenerates the provenance
patch), `make check`, `make synth` / `make bitstream`. Project `basys3/galaga_basys3.xpr`
(not nested). Vivado from `/tmp`; `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`.

## 12. Open items

- Fix patches live in `contrib/code/` (the convention for new ports; Pooyan differs).
- `ROMZIP1`/`ROMZIP2` instead of a single `ROMZIP`: intentional, two romsets.
- 51XX credit state machine investigation on hold (§9).
- Keyboard sticking to the right (former README known issue): not observed on recent
  builds (user, 2026-10-27); entry removed from the README.
- Status tiles distorted or missing pixels after reset (user, 2026-10-27): fixed
  2026-10-28 by the single-domain conversion (§2) and the sample point after the output
  transient (§5.1); 10 of 10 starts clean (user, hardware). `../../../KNOWN_ISSUES.md`.

