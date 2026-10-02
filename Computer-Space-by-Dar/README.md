# Computer-Space-by-Dar (Basys 3 port)

Computer Space (Nutting Associates, 1971) by Dar (`darfpga@aol.fr`,
http://darfpga.blogspot.fr). Basys 3 (Artix-7) port built with Vivado 2020.2.
See `README.txt` in the extracted source archive for the original Dar release
notes.

- Vivado 2020.2 project: `basys3/computer_space_basys3.xpr` (top entity
  `computer_space_basys3`)
- Clock: single 48 MHz domain (`clk_wiz_0` single output, D 5 / M 49.5 /
  O0 20.625 from the 100 MHz oscillator). 6 MHz pixel and 12 MHz
  scandoubler rates are clock enables; the core's 50 MHz-sized timer and
  sound constants are rescaled by `contrib/code/computer_space_single_domain.patch`
  and `computer_space_motion_single_domain.patch` (design:
  `contrib/basys3/PORTING_SPEC.md` §Clocking).

## Features supported

- **Video**: 31 kHz progressive VGA via the imported scandoubler
  (`mist/scandoubler.v`). sw(13) switches to 15 kHz TV mode
  (native RGB + composite sync on HS). White-on-black monochrome picture.
- **Scan doubler source**: MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>;
  tracked as `contrib/code/scandoubler.v`, copied into the project by
  `create_project.sh`.
- **Sound**: mono PWM audio on PmodAMP2.
- **Controls**: PS/2 keyboard + JA joystick (OR-merged); pushbuttons
  btnU/btnD/btnL/btnR double as start; btnC = reset.

| Input | Keyboard |
|-------|----------|
| Rotate CCW | Left arrow |
| Rotate CW | Right arrow |
| Thrust | Up arrow |
| Fire | Space |
| Start | F2 |

JA joystick (active-low, switch to GND; XDC `PULLUP true`):
- JA1 = Right/CW, JA2 = Left/CCW, JA4 = Up/Thrust, JA7 = Fire
- JA3 = spare (this core has no "down"/reverse input).

Pushbuttons (active-high, Basys3 board pull-down, same convention as btnC):
- btnU / btnD / btnL / btnR = start (F2); btnC = reset.

## IO mapping

| Basys 3 resource | Wrapper port | Function |
|------------------|--------------|----------|
| clk (W5, 100 MHz) | `clk` | clock into `clk_wiz_0` MMCM |
| btnC | `btnC` | reset (active-high) |
| btnU / btnD / btnL / btnR | `btnU` / `btnD` / `btnL` / `btnR` | start (F2) |
| sw(15) | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| sw(14) | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| sw(13) | `sw(13)` | display mode: 0 = 31 kHz VGA, 1 = 15 kHz TV |
| JB1 / JB3 | `ps2_dat` / `ps2_clk` | PS/2 keyboard |
| JA1-JA4, JA7 | `JA(0..4)` | joystick (active-low) |
| JC (PmodAMP2) | `O_PMODAMP2_AIN` | PWM audio (mono; JC1=AIN, JC2=GAIN, JC4=SHUTD) |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `vgaHsync`, `vgaVsync` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV |

## Scripted setup

`make setup` archives/stages the Dar source and generates the six
`rom_*.vhd` sound-rom replacements from Intel-HEX (via
`contrib/tools/gen_sound_roms.py`; Computer Space is a discrete-game core, so
there are no MAME ROMs or PROM generation). Then `make create_prj`,
`make clk_wiz`, `make patch`, and `make synth` / `make bitstream`.

`motion_board.vhd` is the one exception to the usual "reference pristine
sources in place" pattern: the `.xpr` imports its own project-local copy
(`sources_1/imports/rtl/motion_board.vhd`), and `make create_prj` copies it
there fresh from `rtl/motion_board.vhd` and applies
`computer_space_motion_q_assoc.patch` + `computer_space_rocket_timer_synth_fix.patch`
+ `computer_space_motion_single_domain.patch`
to that copy only. The pristine `rtl/motion_board.vhd` is never modified —
`make setup`'s patch loop explicitly excludes these three patches for this reason.

## Applying the rocket-missile fire fix

The pristine core (`rtl/motion_board.vhd`) has an unreachable clear branch
in the rocket-missile fire/lifetime process: the counter-expiry check is an
`elsif` sibling of the "increment while firing" branch, so once
`missile_timer` latches `'1'` on the first fire it can never reach the
clear branch — fire is permanently dead after the first launch (or never
fires at all, depending on when the latch engages). `computer_space_rocket_timer_synth_fix.patch`
(originally a synthesis-only fix — moving integer signals out of the
process sensitivity list — which preserved this same bug in nested form)
now also carries the functional fix: the counter-expiry check moves inside
the `missile_timer = '1'` branch, checked first every clock edge, so the
clear is actually reachable:

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

This patch is applied to the project's own imported copy of
`motion_board.vhd` by `make create_prj`, not to the pristine file (see
"Scripted setup" above). Verify it took, after running `make create_prj`:

```
grep -n 'if (missile_life_time_counter > rocket_missile_life_time_duration) then' \
  vhdl_computer_space_rev_1_1_2017_11_22/basys3/computer_space_basys3.srcs/sources_1/imports/rtl/motion_board.vhd
```

(present only in the fixed nested form; the pristine/synth-fix-only forms
both have the expiry check as a sibling `elsif`, not nested inside the
`missile_timer = '1'` branch.)

Confirmed working on hardware: fired missile visible on screen with sound
while active, sustained/refire working as expected. The missile's spawn
point is noticeably offset from the ship's nose — traced this to original
1971 hardware behavior (Dar's own comments in `motion_board.vhd` around
line 572 and 617 describe the missile as launching from "the heart"/center
of the ship via a fixed screen-relative offset, not a rotation-aware nose
position), not something introduced by this fix or by porting.

## Known issues

- The `motion_q_assoc`/`rocket_timer_synth_fix` patches now apply to the
  project's imported copy of `motion_board.vhd`, not the pristine file
  (see "Scripted setup" above) — re-verified via `make setup` + `make
  create_prj` (patches apply cleanly, pristine file confirmed untouched,
  fixed logic confirmed present in the imported copy) and a read-only
  Vivado project open (0 missing files beyond the expected
  not-yet-generated `clk_wiz_0`/top-level wrapper at that build stage). 
  Re-verified with a fresh `make synth` / `make bitstream` / hardware
  reflash since this convention change.

## Build status

See the root `sf-darfpga/README.md` Status section.

## Potential future work (note only)

- Real coin/credit start: the core keeps a coin-microswitch start state
  machine (`IDLE/COIN_INSERTED/GAME_ON` in `sync_star_board.vhd`), but the
  current wrapper drives `signal_start` directly (F2 or any pushbutton) and
  bypasses it. A dedicated coin button would require exposing `signal_coin`
  at the `computer_space_top` boundary (it is currently tied to `signal_start`
  internally).
- Diode-matrix input: not needed here (the core's input is a simple parallel
  `signal_*` bus). If a future port needs many controls over few Pmod pins, a
  scanned row x column matrix with steering diodes (to prevent ghosting) is
  the pattern; it is intentionally out of scope for this port.
