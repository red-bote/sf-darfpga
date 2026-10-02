# Computer-Space-by-Dar — Porting spec

Upstream: `vhdl_computer_space_rev_1_1_2017_11_22.zip` (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), which extracts as `SRC_DIR` per
`setup_computer_space.sh`. Project/top entity: `computer_space_basys3`. Core
clock: single 48 MHz domain; the 6 MHz pixel rate is a clock enable
(§Clocking). Computer Space is a discrete-TTL game core with no romset
and no `make_*_proms.bat`; its six `sound_*` roms are generated from Intel-HEX
by `contrib/tools/gen_sound_roms.py` instead of a `prep_roms.sh` chain.

Port status is tracked in the root `README.md` §Status, not here (per
`.opencode/rules.md` §"Documentation scope (PORTING_SPEC.md)").

## Clocking (`clk_wiz_0`, scripted in `make_clk_wiz_0.sh`)

Single clock domain (revised 2026-10-02, per `.opencode/rules.md`
§"Clocking (Basys3 ports)"). One MMCM output, `clk_out1` = 48.000 MHz,
drives the whole design: core (`clock_50` / `super_clk` /
`timer_base_clk` nets, names kept from upstream), scandoubler `clk_sys`,
keyboard, PWM.

Rates derived as clock enables in the wrapper from a 3-bit counter:

| Enable | Rate | Replaces | Users |
|---|---|---|---|
| `game_ce` (count = 7) | 6 MHz | `rising_edge(game_clk)` | `scan_counter`, motion-board counters/edge processes (via `SB_Y`/`MB_20`), `composite_sync`, scandoubler `ce_x1`, PWM |
| `game_ce_n` (count = 3) | 6 MHz, half-pixel offset | `rising_edge(not game_clk)` (`b5_10`) | star counter `v74161` |
| `ce_x2` (count(1:0) = 3) | 12 MHz | scandoubler `clk_sys` = 12 MHz | scandoubler output side |

Video timing is unchanged (6.000 MHz pixel rate, as before).

### Previous scheme and why it changed

Three MMCM outputs (50 / 6 / 12 MHz, VCO 600). Routed timing failed:
setup -4.785 ns on the sound sum `audio` (clock_50) into
`pwm_accumulator` (game_clk); setup -4.322 ns on `Sync_Star_Brd/b5_5`
(clock_50) into the scandoubler line buffer (clk_sys); hold -0.497 ns on
the `game_clk` clock net used as scandoubler `ce_x1` logic. Untimed
50 -> 6 MHz crossings inside the core (`Memory_Brd` -> `Motion_Brd`)
met only by chance. A wrapper-local resync (option A) was rejected in
favor of this refactor for long-term maintainability (all crossings
removed; matches the clocking rule); the cost is RTL patches to Dar's
core.

### Rate-dependent constants (50 -> 48 MHz, x0.96)

Counters sized for 50 MHz `clock_50` are rescaled so durations and
audio rates are unchanged (to < 0.1%). Toggle dividers scale the
period `N+1`; duration thresholds scale `N`.

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

### Patches

- `contrib/code/computer_space_single_domain.patch` (generic setup
  loop, `--binary`, CRLF): `computer_space_top.vhd`,
  `computer_space_logic.vhd`, `sync_star_board.vhd` (`game_clk` port
  replaced by `game_ce` / `game_ce_n`); `scan_counter.vhd` (clocked by
  `super_clk`, enabled by `game_ce`; star counter enabled by
  `game_ce_n`); `v74161.vhd`, `v74161_16bit.vhd` (`CE` input, default
  `'1'`); `composite_sync.vhd` (`ce` input, default `'1'`); `clocks.vhd`,
  `sound.vhd`, `computer_space_sound.vhd` (constants above).
- `contrib/code/computer_space_motion_single_domain.patch` (imported
  `motion_board.vhd` copy, applied by `create_project.sh` after the two
  existing motion-board patches): the internal `clk` net (`not MB_20`,
  = game_clk) becomes an enable; its processes and the two
  `v74161_16bit` instances run on `super_clk`.

### Keyboard

`io_ps2_keyboard` / `kbd_joystick` run at 48 MHz (was 6 MHz). PS/2
clock/data pass a 2-FF synchronizer (`ASYNC_REG`) in the wrapper. The
15-tick `clk_filter` is 0.31 us at 48 MHz (2.5 us at 6 MHz); hardware
check required.

### PWM

Accumulator clocked at 48 MHz, enabled by `game_ce`: carrier and
resolution unchanged from the 6 MHz scheme.

## Video path

Computer Space uses the imported MiST `mist/scandoubler.v` for 31 kHz
progressive VGA (same core-family wiring as Galaga/Phoenix/Xevious/Zaxxon).
The core drives the scandoubler with its own `hsync`/`vsync` and monochrome
`video` from `computer_space_top`:

- **Dual-mode output (`sw(13)`, fleet TV/VGA switch convention)**:
  - `sw(13) = '0'` (VGA, 31 kHz): scandoubler output.
  - `sw(13) = '1'` (TV, 15 kHz): native RGB + composite sync on HS.

White-on-black monochrome picture (`video` is a 4-bit grey/white bus).

## Controls design

The core exposes discrete parallel input ports at the `computer_space_top`
boundary (`signal_ccw`, `signal_cw`, `signal_thrust`, `signal_fire`,
`signal_start`) — there is no in-core PS/2 decode, so the wrapper owns input
merging:

- **PS/2 keyboard** (JB) via the shared `kbd_joystick.vhd` decode of
  `joyPCFRLDU(7:0)`: bit0 = up (thrust), bit2 = left (CCW), bit3 = right
  (CW), bit4 = space (fire), bit6 = F2 (start).
- **JA joystick**, active-low (press shorts pin to GND; XDC `PULLUP true`),
  OR-merged with the keyboard bits using `not JA(x)`:
  - `signal_ccw <= joyPCFRLDU(2) or not JA(1)` (JA2 = left/CCW)
  - `signal_cw <= joyPCFRLDU(3) or not JA(0)` (JA1 = right/CW)
  - `signal_thrust <= joyPCFRLDU(0) or not JA(3)` (JA4 = up/thrust)
  - `signal_fire <= joyPCFRLDU(4) or not JA(4)` (JA7 = fire)
  - JA3 is spare (this core has no "down"/reverse input).
- **Pushbuttons** (active-high, Basys3 pull-down, same convention as `btnC`):
  `signal_start <= joyPCFRLDU(6) or btnU or btnD or btnL or btnR` — any
  pushbutton doubles as start; `btnC` = reset.

## Rocket-missile fire fix

The pristine `rtl/motion_board.vhd` has an unreachable-clear bug in the
rocket-missile fire/lifetime process: the counter-expiry check is an `elsif`
sibling of the "increment while firing" branch, so once `missile_timer`
latches `'1'` on the first fire it can never reach the clear branch — fire
is permanently dead after the first launch. `computer_space_rocket_timer_synth_fix.patch`
began as a synthesis-only fix (moving the integer signals out of the process
sensitivity list, preserving the same bug in nested form) and now also carries
the functional fix: the counter-expiry check moves inside the
`missile_timer = '1'` branch and is evaluated first each clock edge, so the
clear is reachable and sustained/refired fire works.

Design note on patch strategy: `motion_board.vhd` is the one exception to the
usual "reference pristine sources in place" convention — the project imports
its own copy (`sources_1/imports/rtl/motion_board.vhd`), and `make create_prj`
copies it fresh from `rtl/motion_board.vhd` and applies the two
`motion_board` patches to that copy only. The pristine file is never modified.
See the machine `README.md` for the exact wiring and verify commands.

## Other wiring decisions

- **Reset**: `reset <= btnC or not mmcm_locked` (project-standard pattern);
  `clk_wiz_0`'s `reset` driven by `btnC` directly.
- **Audio**: mono PWM output on PmodAMP2 (JC), reusing the core's native
  audio path (`wav_out`/`audio` from `computer_space_top`); `sw14` = sound
  enable (`O_PMODAMP2_SHUTD`), `sw15` = AMP gain (`O_PMODAMP2_GAIN`) — the
  fleet-standard pair.
- **Display mode**: `sw(13)` toggles 31 kHz VGA vs 15 kHz TV (see "Video
  path").
- **Debug hex display / LEDs**: not ported — no Basys3 machine here carries
  7-segment wiring, and the core's LED outputs are static/non-essential
  (matches the rest of the fleet).
