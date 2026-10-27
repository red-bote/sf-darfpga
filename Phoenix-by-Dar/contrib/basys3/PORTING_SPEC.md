# Phoenix-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. User summary: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_phoenix_DE10_lite.zip` (SourceForge `darfpga/files/Software VHDL/phoenix`),
  SHA-256 in `contrib/tools/setup_phoenix.sh`; no internal top-level folder (extracted
  directly as `vhdl_phoenix_DE10_lite/`, setup `--flat-archive`). Core `rtl_dar/phoenix.vhd`;
  DE10 top `rtl_dar/phoenix_de10_lite.vhd`. The archive ships no `.bat` and no
  `tools_prom_src`; `make_phoenix_proms.sh` is reconstructed (§10).
- MAME driver: `phoenix` (romset `phoenix`).
- Top entity `phoenix_basys3`. Model: Burnin-Rubber (scandoubler component and port map).
- Phoenix is the only core in this tree that decodes PS/2 inside the core with no discrete
  input ports; inputs enter through the `ext_joy` patch (§7).

## 2. Clocking

- `clk_wiz_0` (one MMCM, VCO 1100 MHz): `clk_out1` = 11.000 MHz (`clock_11`, core), `clk_out2`
  = 50.000 MHz (`clock_50`, audio); DIVCLK 1 / MULT_F 11.000 / CLKOUT0_DIVIDE_F 100.000 /
  CLKOUT1_DIVIDE 22.
- The DE10 top feeds the raw 50 MHz board oscillator to the core's `clock_50` port; the
  `phoenix_effect1/2/3` / `phoenix_music` blocks divide it to 10 MHz internally. The wrapper
  uses the MMCM's 50 MHz output for the same purpose.
- Pixel clock 5.5 MHz (`clk11` / 2 inside the core, exposed as `video_clk`). Phoenix and
  Computer-Space were accepted as exceptions to the V ≤ 61 Hz window (2026-10-01,
  `../../../CLOCKING_SPEC.md`).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`. The reset reaches the sound
modules since 2026-10-07 (§9 `phoenix_sound_reset.patch`): in the pristine core the four sound modules (`effect1/2/3`, `music`) get `reset => '0'`
(`rtl_dar/phoenix.vhd` effect/music port maps), and the CPU-written sound registers
`sound_a`/`sound_b` are not cleared, so btnC resets CPU and video while the current sound
keeps playing (`KNOWN_ISSUES.md`). Each module already has reset logic
(`phoenix_effect1.vhd:44,74,123`, `phoenix_music.vhd:92,183,209`).
`contrib/code/phoenix_sound_reset.patch`: `reset => reset` on the four modules, and a
synchronous clear of `sound_a`/`sound_b` on `hclk` while `reset = '1'` (the other
registers in that process keep their pristine behavior).

## 4. Core instantiation

- `phoenix` entity (after the three patches, §9): `clock_11`, `clock_50`, `reset`;
  `video_r/g/b(1:0)`, `video_clk`, `video_csync`, `video_hs`, `video_vs`; `audio`
  (12 bits); `audio_select(2:0)`; `dip_switch(7:0)`; `ps2_clk`/`ps2_dat` (tied `'1'`);
  `ext_joy(7:0)`.
- Debug hex display and `ledr(8:0) <= "101010101"` (static debug pattern) are not ported.

## 5. Video path

### 5.1 Problem

`phoenix_video.vhd` (the core's video generator) implements RS-170-style
composite sync directly; pre-equalizing pulses, vsync serration, and
post-equalizing pulses, each timed off the internal `hcnt`/`vcnt` counters
(`sync <=` combinational mux at `phoenix_video.vhd:200+`); and exposes only
that single composite signal as `sync` (forwarded to the `phoenix` entity's
`video_csync` port). **No separate hsync/vsync exist anywhere in the
pristine design**; `video_hs`/`video_vs` are commented out both at the
`phoenix` entity (`phoenix.vhd:26-27`) and the DE10-lite top
(`phoenix_de10_lite.vhd`). This matches the upstream `README.txt`: "TV mode
only RBG 15kHz"; Dar never implemented VGA output for this core. The DE10
top puts `csync` directly on `vga_hs` with `vga_vs` tied high (composite
sync riding the HS line, matching this project's own "TV mode" convention
for other machines).

The already-staged MiST `scandoubler.v` requires genuine separate `hs_in`/
`vs_in` (confirmed in-module: `vs_out` is a bare registered copy of `vs_in`,
`hs_in` edges drive the internal line-length/doubling counters; it does not
separate composite sync itself). Feeding it composite sync directly would
leave `vs_out` static (never toggling), so it cannot be wired as-is.

### 5.2 Exposed hsync/vsync

A first implementation attempt authored a duration-threshold sync separator
in `phoenix_basys3.vhd` (no pristine-file changes), inferring `hs`/`vs`
edges from `video_csync`. Superseded by `contrib/code/phoenix_expose_hsync_vsync.patch`,
a single two-file patch exposing real, separately-generated hsync/vsync
from signals the core already computes internally; no threshold-guessing:

- **`rtl_dar/phoenix_video.vhd`**: adds `hsync`/`vsync` output ports,
  assigned `hsync <= pulse_a; vsync <= vblank_n;`. `pulse_a` is the file's
  existing per-line active-low sync pulse (`hcnt_i = 0xBF`→`0xD9`, ~4.7 µs,
  fixed horizontal position every line, driven unconditionally by `hcnt_i`
  comparisons; independent of the `vcntr_i`-selected composite-sync mux
  that substitutes equalizing/serration patterns on 7 lines inside vertical
  blank). `vblank_n` is the already-computed active-low form of the
  existing `vblank` output (`vblank <= not vblank_n`). Real separate-signal
  hsync doesn't need RS-170 serration at all; that encoding exists only
  for single-wire composite consumers; so using `pulse_a` unconditionally
  on every line is textbook-correct, not an approximation.
- **`rtl_dar/phoenix.vhd`**: realizes the entity's pre-existing commented
  `video_hs`/`video_vs` ports, relays them from the `phoenix_video`
  instance's new `hsync`/`vsync` outputs.

Polarity: `video_hs <= pulse_a` directly (active-low, required; the
imported `scandoubler.v` detects hsync via a falling edge,
`if(hsD && !hs_in)`). `video_vs <= vblank_n` directly (active-low; the
scandoubler's `vs_out <= vs_in` is a bare register copy with no required
polarity, chosen for consistency with `video_hs` and because it reuses an
existing signal with no new logic).

### 5.3 Scandoubler wiring

MiST `scandoubler.v` (`contrib/code/`, project copy patched by `scandoubler_fix.patch`);
values that differ from Burnin-Rubber:

| Port | Connected signal | Note |
|---|---|---|
| `clk_sys` | `clk_out1` (11 MHz) | MMCM core clock, already generated |
| `ce_x1` | `video_clk` (5.5 MHz, from the `phoenix` core instance) | Core's own pixel clock, already phase-locked to `clk_out1` (`clk11`/2 internally); no extra divider needed, unlike Burnin-Rubber's separate `clk_out2` |
| `ce_x2` | `'1'` (literal) | Matches fleet convention |
| `scanlines` | `"00"` (literal) | Matches fleet convention; no scanline control implemented anywhere in this project |
| `hs_in` / `vs_in` | core's `video_hs`/`video_vs`, direct connection | See "Chosen approach" above |
| `r_in` / `g_in` / `b_in` | `video_r & video_r & video_r` etc. | Core outputs 2 bits/channel (`video_r/g/b : std_logic_vector(1 downto 0)`); pad to `COLOR_DEPTH = 6` by triple replication. **No external blanking gate needed**: unlike Burnin-Rubber, the core already forces `video_r/g/b` to `"00"` internally during `hblank`/`vblank` (`fr_bit0`/`fr_bit1`/`bk_bit0`/`bk_bit1` are gated by `vblank`/`hblank_frgrd`/`hblank_bkgrd` at `phoenix.vhd:242-245`, feeding `color_id` which addresses a palette ROM whose index 0 is black); confirmed by the DE10 top's own `blankn <= '1'` (constant, i.e. the DE10 top deliberately disables any external blanking mask and trusts the core) |

### 5.4 Display mode (sw13)

- `sw(13) = '0'` (VGA, 31 kHz): scandoubler output, as above.
- `sw(13) = '1'` (TV, 15 kHz): `video_csync` straight onto `vga_hs`,
  `vga_vs` tied `'1'`, native `video_r`/`video_g`/`video_b` passed through
  padded to 4 bits; this exactly reproduces the pristine DE10-lite top's
  behavior.

## 6. Audio

Dar's 13-bit PWM accumulator verbatim (`'0' & acc(11:0)` + `audio & '0'`, `audio` 12 bits),
`O_PMODAMP2_AIN` = bit 12, mono. `audio_select` is 3 bits (§8). `SHUTD <= not sw(15)`,
`GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` in the wrapper on `clock_11` (PS/2 2-FF `ASYNC_REG`), decoder
  (2026-10-20; `../../../PORTING_SPEC.md` §3.1, MAME `phoenix`), F0 = release, E0 ignored,
  into `kbd_joy`: Left/Right arrows (bits 2/3), Left Ctrl = fire (4), Left Alt = shield (0),
  1 / 2 = start (5/6), 5 / 6 = coin (7). The core's `ps2_clk`/`ps2_dat` are tied `'1'`, so
  its internal `kbd_joystick` (Dar keys: Space fire, up shield, F3 coin, F1/F2 start) stays
  inactive.
- `ext_joy` (active-high, `JoyPCFRLDU` order: 7 coin, 6 start 2, 5 start 1, 4 fire,
  3 right, 2 left, 0 up = shield), OR-merged in the core before the inversion to the CPU's
  active-low inputs:
  - `ext_joy(0) <= kbd_joy(0) or jx_shield`, `jx_shield = not JXADC4 or (not JXADC3 and
    not JXADC7)` (shield: up, up+fire, down+fire; fire passes through);
  - `ext_joy(1) <= '0'` (no down input); `ext_joy(2/3)` = arrows or JXADC2/JXADC1;
  - `ext_joy(4)` = Left Ctrl or JXADC7; `ext_joy(5/6)` = 1/2 or btnL/btnR;
  - `ext_joy(7)` = 5/6 or btnU/btnD.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC (`stick_sync`) and buttons, on `clock_11`.
- Debounce: btnU/D/L/R, 2^17 `clock_11` cycles (11.9 ms).
- Combos: shield combos above (approved, §3.1).
- History: two earlier attempts (2026-09-22, 2026-09-25) registered no input and were
  reverted (`../../../KNOWN_ISSUES.md`). The pristine `phoenix` entity accepts only a PS/2
  keyboard scancode stream; its `kbd_joystick`/`io_ps2_keyboard` instances and the
  resulting `coin`/`player_start`/`buttons` signals are entirely internal, with no ports
  to intercept for a JXADC joystick or dedicated buttons (unlike every other machine in
  this project). `contrib/code/phoenix_expose_control_ports.patch` was authored to add
  `ext_coin`/`ext_start1`/`ext_start2`/`ext_fire`/ `ext_right`/`ext_left`/`ext_up` ports
  to the `phoenix` entity, OR-merged with the existing `JoyPCFRLDU`-derived signals,
  driven from the wrapper's JXADC joystick (active-low, inverted) and
  `btnU`/`btnD`/`btnL`/`btnR`. Hardware-tested: no input registered at all, on the same
  build where PS/2 keyboard, sound, and video were all confirmed working. A repo-wide
  precedent search (all ~25 machine directories, ported and unported) found Phoenix is the
  only core in this project that decodes PS/2 inside the core with no native discrete-
  input ports; every other core exposes `coin`/`start`/`fire`/direction ports directly,
  with any PS/2 decode kept in a separate board-level top file; and this patch was the
  only one, repo-wide, adding discrete control-input ports to a pristine core. There is no
  comparable, validated implementation elsewhere to debug against or copy. **Reverted**:
  the patch, the `ext_*` port map connections, the JXADC/ button wrapper wiring, and the
  `btnU`/`btnD`/`btnL`/`btnR`/`JXADC` XDC constraints have all been removed. **Third
  attempt, implemented 2026-10-02**: `contrib/code/phoenix_external_inputs.patch` adds one
  active-high `ext_joy : in std_logic_vector(7 downto 0)` port (`JoyPCFRLDU` bit order)
  and OR-merges it into each of the seven player-input assignments before their inversion
  to the CPU's active-low inputs (e.g. `coin <= not (JoyPCFRLDU(7) or ext_joy(7))`). The
  wrapper drives it from the JXADC joystick (2-FF synchronized) and debounced
  `btnU`/`btnD`/`btnL`/`btnR` on `clock_11`; the XDC lines are enabled. Hardware-confirmed
  2026-10-02.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw7-0 | `dip_switch` | 7-0 | `0` (direct `sw(7 downto 0)`, as the DE10 top alias) | Lives(1-0) / Bonus(3-2) / Coin(4) / unknown(6-5) / Cocktail(7) |
| sw10-8 | `audio_select` | 2-0 | `"000"` (mix) | `"100"`/`"101"`/`"110"`/`"111"` = effect1/effect2/effect3/melody solo; `"000"`-`"011"` mix all four |

`audio_select`: the `phoenix` entity's `audio_select` port is 3 bits (`std_logic_vector(2 downto 0)`) -
`"100"`/`"101"`/`"110"`/`"111"` select effect1/effect2/effect3/melody solo, anything else
(`"000"`-`"011"`) mixes all four; a 2-bit switch range can't reach the MSB-gated solo
selections. **Resolved**: wired `audio_select <= sw(10 downto 8)` (3 bits; `sw(10)` is
otherwise unused on this board), Makefile `IO_SUMMARY` updated to match.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/phoenix_expose_hsync_vsync.patch` | `rtl_dar/phoenix_video.vhd`, `rtl_dar/phoenix.vhd` | real hsync/vsync (§5.2). Verify: `grep -n "hsync <= pulse_a" <SRC_DIR>/rtl_dar/phoenix_video.vhd`; `grep -c video_hs <SRC_DIR>/rtl_dar/phoenix.vhd` = 2 |
| `contrib/code/phoenix_external_inputs.patch` | `rtl_dar/phoenix.vhd` | `ext_joy : in std_logic_vector(7 downto 0) := (others => '0')`, OR-merged into the seven player inputs before inversion, e.g. `coin <= not (JoyPCFRLDU(7) or ext_joy(7))` (2026-10-02). Verify: `grep -c 'or ext_joy' <SRC_DIR>/rtl_dar/phoenix.vhd` = 7 |
| `contrib/code/phoenix_sound_reset.patch` | `rtl_dar/phoenix.vhd` | sound modules reset with the core; `sound_a`/`sound_b` cleared (2026-10-07). Verify: `grep -c "btnC did not reset the sound" <SRC_DIR>/rtl_dar/phoenix.vhd` = 4 |
| `contrib/code/scandoubler_fix.patch` | project `imports/mist/scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/phoenix_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, runs the reconstructed
`make_phoenix_proms.sh` (no upstream `.bat`), unzips `ROMZIP` (default `~/roms/phoenix.zip`)
into `tools/phoenix_unzip/` and generates `phoenix_prog.vhd`, `prom_ic39.vhd`,
`prom_ic40.vhd`, `prom_ic23.vhd`, `prom_ic24.vhd`, `prom_palette_ic40.vhd`,
`prom_palette_ic41.vhd`. Never committed.

## 11. Build

`make setup` (fetch to `dloads/` with SHA-256 check, flat extract, three patches, PROMs),
`make create_prj` (project, XDC, scandoubler copy + fix), `make clk_wiz`, `make patch`,
`make check`, `make synth` / `make bitstream`. Keyboard moved from JB1/JB3 to the onboard
USB-HID host 2026-09-23 (XDC only; hardware-confirmed).

## 12. Open items

- `ce_x1 => video_clk` is a register-derived clock used as logic in the `clk_sys` domain
  (untimed, `../../../KNOWN_ISSUES.md`); no hardware symptom.
- Second MMCM output (`clock_50`, audio): kept; not converted to a single domain.

