# Computer-Space-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_computer_space_rev_1_1_2017_11_22.zip` (SourceForge `darfpga/files/Software
  VHDL/computer_space`, v1.1 2017-11-22), SHA-256 in `contrib/tools/setup_computer_space.sh`;
  extracted to `vhdl_computer_space_rev_1_1_2017_11_22/`. Core top `rtl/computer_space_top.vhd`
  (pristine top in `rtl/`, not `rtl_dar/`: setup uses `--de10-dir rtl`); DE10 top
  `rtl/computer_space_de10_lite.vhd`.
- Discrete-TTL game core: no MAME driver, no romset, no `make_*_proms.bat`. The six
  `sound_*` roms are generated from Intel-HEX by `contrib/tools/gen_sound_roms.py`.
- Top entity `computer_space_basys3`. Model: Galaga/Phoenix (MiST scandoubler wiring);
  single domain per the clocking rule.

## 2. Clocking

- Original: discrete logic; Dar's DE10 build ran the game at 5.842 MHz pixel rate from a
  50 MHz `clock_50` master.
- `clk_wiz_0`: request 48.000 MHz, achieved 48.000 MHz (DIVCLK 5 / MULT_F 49.5 /
  CLKOUT0_DIVIDE_F 20.625), single output `clk_core` (2026-10-02,
  `.opencode/rules.md` "Clocking"). It drives the core (`clock_50` / `super_clk` /
  `timer_base_clk` nets, names kept from upstream), scandoubler `clk_sys`, keyboard, PWM.
- Enables from a 3-bit counter in the wrapper:

| Enable | Rate | Replaces | Users |
|---|---|---|---|
| `game_ce` (count = 7) | 6 MHz | `rising_edge(game_clk)` | `scan_counter`, motion-board counters/edge processes (via `SB_Y`/`MB_20`), `composite_sync`, scandoubler `ce_x1`, PWM |
| `game_ce_n` (count = 3) | 6 MHz, half-pixel offset | `rising_edge(not game_clk)` (`b5_10`) | star counter `v74161` |
| `ce_pix2` (count(1:0) = 3) | 12 MHz | former 12 MHz scandoubler `clk_sys` | scandoubler output side |

- Pixel 6.000 MHz (2.7% above Dar's 5.842 MHz; the MMCM cannot derive 5.842 MHz from
  100 MHz); video timing scales by 6/5.842 ~ 1.027.
### 2.1 Previous scheme (until 2026-10-02)

Three MMCM outputs (50 / 6 / 12 MHz, VCO 600). Routed timing failed: setup -4.785 ns on
the sound sum `audio` (clock_50) into `pwm_accumulator` (game_clk); setup -4.322 ns on
`Sync_Star_Brd/b5_5` (clock_50) into the scandoubler line buffer (clk_sys); hold -0.497 ns
on the `game_clk` clock net used as scandoubler `ce_x1` logic. Untimed 50 -> 6 MHz
crossings inside the core (`Memory_Brd` -> `Motion_Brd`) met only by chance. A
wrapper-local resync (option A) was rejected in favor of this refactor for long-term
maintainability (all crossings removed; matches the clocking rule); the cost is RTL
patches to Dar's core.

### 2.2 Rate-dependent constants (50 → 48 MHz, x0.96)

Counters sized for 50 MHz `clock_50` are rescaled so durations and audio rates are
unchanged (to < 0.1%). Toggle dividers scale the period `N+1`; duration thresholds scale
`N`.

| File | Constant | 50 MHz | 48 MHz | Function |
|---|---|---|---|---|
| `clocks.vhd` | `thrust_and_rotate_clk_count` | 2777778 | 2666667 | 18 Hz thrust/rotate |
| `clocks.vhd` | `explosion_clk_count` | 4166667 | 4000000 | 6 Hz explosion |
| `clocks.vhd` | `explosion_rotate_clk_count` | 147 | 141 | explosion rotate |
| `clocks.vhd` | `seconds_clk_count` | 25000000 | 24000000 | 1 Hz game time |
| `clocks.vhd` | `rocket_missile_life_time_duration` | 115000000 | 110400000 | 2.3 s |
| `clocks.vhd` | `saucer_missile_life_time_duration` | 115000000 | 110400000 | 2.3 s |
| `clocks.vhd` | `saucer_missile_hold_duration` | 10000000 | 9600000 | 0.2 s |
| `clocks.vhd` | `signal_delay_duration` | 150000 | 144000 | 3 ms |
| `sound.vhd` | `sample_rate_count >` | 4535 | 4354 | 11.02 kHz sample rate |
| `computer_space_sound.vhd` | `noise_cnt =` | 4544 | 4362 | 11.0 kHz noise/filter/envelope rate |

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC`.

## 4. Core instantiation

- `computer_space_top` exposes discrete parallel inputs `signal_ccw`, `signal_cw`,
  `signal_thrust`, `signal_fire`, `signal_start`; no in-core PS/2 decode. Enables
  `game_ce`, `game_ce_n` added by `computer_space_single_domain.patch` (§9).
- Video out: 4-bit `video` [normal/inverse, objects, scores, stars], `hsync`, `vsync`,
  csync. The DE10 top maps the 3 object bits through a normal/inverse monochrome level
  lookup (`video(3)` selects reverse video); reproduced in the wrapper; R, G and B are
  driven from the same level (white on black).
- `audio_out`/`wav_out` are unused; only `audio` is driven by the top.
- `motion_board.vhd` is imported into the project (`sources_1/imports/rtl/motion_board.vhd`);
  `make create_prj` copies it fresh from `rtl/motion_board.vhd` and applies the three
  motion-board patches to the copy (§9). The pristine file is never modified; the setup
  patch loop excludes those patches.

## 5. Video path

- MiST `scandoubler.v` (`contrib/code/`, project copy patched by `scandoubler_fix.patch`);
  `clk_sys = clk_core`, `ce_x1 = game_ce`, `ce_x2 = ce_pix2` (exactly 2 × `ce_x1`); `hs_in`/
  `vs_in` from the core's own `hsync`/`vsync`.
- sw13: `0` = scandoubler output (31 kHz); `1` = native RGB, composite sync on HS, VS `'1'`
  (15 kHz TV).

## 6. Audio

Wrapper PWM accumulator (17 bits, `'0' & acc(15:0)` + `audio_us`) on `clk_core` enabled by
`game_ce` (carrier and resolution unchanged from the 6 MHz scheme); `O_PMODAMP2_AIN` = bit
16, mono. `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clk_core` (48 MHz; was `game_clk` 6 MHz, unsynchronized),
  wrapper decoder (2026-10-20, replaces `kbd_joystick`; `../../../PORTING_SPEC.md` §3.1, no
  MAME key set), F0 = release, E0 ignored, into `joyPCFRLDU`: Left arrow = CCW, Right arrow
  = CW, Up arrow = thrust, Left Ctrl = fire, 1 / 2 = start. The 15-tick `clk_filter` in
  `io_ps2_keyboard` is 0.31 us at 48 MHz (2.5 us at 6 MHz); hardware-verified 2026-10-20.
- Core inputs: active-high levels.
- Merge (`in_s(1)` = synchronized `btnR & btnL & btnD & btnU & JXADC`):
  - `ctl_ccw    <= joyPCFRLDU(2) or not in_s(1)(1)` (JXADC2)
  - `ctl_cw     <= joyPCFRLDU(3) or not in_s(1)(0)` (JXADC1)
  - `ctl_thrust <= joyPCFRLDU(0) or not in_s(1)(3)` (JXADC4)
  - `ctl_fire   <= joyPCFRLDU(4) or not in_s(1)(4)` (JXADC7)
  - `ctl_start  <= joyPCFRLDU(6) or` any of btnU/btnD/btnL/btnR
  - JXADC3 is spare (no down/reverse input).
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC and the four buttons (`in_s`), on
  `clk_core`.
- Debounce: none. Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| (none) | | | | the core top has no DIP or option inputs |

sw13-15 as fixed by the convention; sw0-12 unused.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/computer_space_single_domain.patch` | `computer_space_top.vhd`, `computer_space_logic.vhd`, `sync_star_board.vhd` (`game_clk` port → `game_ce`/`game_ce_n`); `scan_counter.vhd` (`super_clk` + `game_ce`; star counter `game_ce_n`); `v74161.vhd`, `v74161_16bit.vhd` (`CE`, default `'1'`); `composite_sync.vhd` (`ce`, default `'1'`); `clocks.vhd`, `sound.vhd`, `computer_space_sound.vhd` (constants, §2) | single clock domain; generic setup loop, `--binary` (CRLF) |
| `contrib/code/computer_space_motion_q_assoc.patch` | imported `motion_board.vhd` | association fix (applied by `create_project.sh`) |
| `contrib/code/computer_space_rocket_timer_synth_fix.patch` | imported `motion_board.vhd` | synthesis fix (integers out of the sensitivity list) plus the rocket-missile fire fix (§9.1) |
| `contrib/code/computer_space_motion_single_domain.patch` | imported `motion_board.vhd` | the internal `clk` net (`not MB_20` = game_clk) becomes an enable; its processes and the two `v74161_16bit` instances run on `super_clk`; applied after the two patches above |
| `contrib/code/scandoubler_fix.patch` | project `imports/mist/scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/computer_space_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

Setup extensions (`setup_computer_space.sh`): `--de10-dir rtl`, `--extra-exclude` (the
motion-board patches), `--binary`.

### 9.1 Rocket-missile fire fix

The pristine `rtl/motion_board.vhd` has an unreachable-clear bug in the
rocket-missile fire/lifetime process: the counter-expiry check is an `elsif`
sibling of the "increment while firing" branch, so once `missile_timer`
latches `'1'` on the first fire it can never reach the clear branch; fire
is permanently dead after the first launch. `computer_space_rocket_timer_synth_fix.patch`
began as a synthesis-only fix (moving the integer signals out of the process
sensitivity list, preserving the same bug in nested form) and now also carries
the functional fix: the counter-expiry check moves inside the
`missile_timer = '1'` branch and is evaluated first each clock edge, so the
clear is reachable and sustained/refired fire works.

Design note on patch strategy: `motion_board.vhd` is the one exception to the
usual "reference pristine sources in place" convention; the project imports
its own copy (`sources_1/imports/rtl/motion_board.vhd`), and `make create_prj`
copies it fresh from `rtl/motion_board.vhd` and applies the two
`motion_board` patches to that copy only. The pristine file is never modified.
See the machine `README.md` for the exact wiring and verify commands.

Fixed form:

```vhdl
elsif rising_edge (timer_base_clk) then
    if (missile_timer = '1') then
        if (missile_life_time_counter > rocket_missile_life_time_duration) then
            missile_life_time_counter <= 0;
            missile_timer <= '0';
            d6_1 <= '1';
            MB_2_rocket <= '0';
        else
            missile_life_time_counter <= missile_life_time_counter + 1;
        end if;
    end if;
end if;
```

Verify after `make create_prj`:

```
grep -n 'if (missile_life_time_counter > rocket_missile_life_time_duration) then' \
  vhdl_computer_space_rev_1_1_2017_11_22/basys3/computer_space_basys3.srcs/sources_1/imports/rtl/motion_board.vhd
```

Hardware: missile visible with sound while active; sustained fire and refire work. The
spawn point is offset from the ship's nose: original 1971 behaviour (Dar's comments near
`motion_board.vhd:572` and `:617`: the missile launches from the ship's centre via a fixed
screen-relative offset), not introduced by the fix or the port.

## 10. PROM generation

No PROMs. `make setup` chains `contrib/tools/gen_sound_roms.py` (via
`contrib/tools/prep_roms.sh`), which generates the six `rom_*.vhd` sound roms from the
archive's Intel-HEX files.

## 11. Build

`make setup`, `make create_prj` (project, XDC, scandoubler copy + fix, `motion_board.vhd`
import + 3 patches), `make clk_wiz`, `make patch`, `make check`, `make synth` /
`make bitstream`. The motion-board import convention was re-verified with `make setup` +
`make create_prj` (patches apply cleanly, pristine file untouched) and a fresh build and
hardware reflash.

## 12. Open items

- Real coin/credit start (note only): the core keeps a coin-microswitch start state machine
  (`IDLE/COIN_INSERTED/GAME_ON` in `sync_star_board.vhd`), but the wrapper drives
  `signal_start` directly and bypasses it. A coin button would require exposing
  `signal_coin` at the `computer_space_top` boundary (tied to `signal_start` internally).
- Diode-matrix input (note only): not needed (parallel `signal_*` bus). For many controls
  over few Pmod pins, a scanned row x column matrix with steering diodes is the pattern;
  out of scope.
