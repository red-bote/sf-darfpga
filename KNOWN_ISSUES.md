# Known Issues

Running list of defects across all sf-darfpga machines: hardware-verified bugs found
during bring-up testing, and known gaps versus the project's own conventions (e.g. root
`PORTING_SPEC.md` §3's external-IO mapping) found by inspection. One entry per defect.
Move an entry from Open to Fixed once root-caused and resolved (see
`vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md` §5 for an example write-up of a fixed
defect's root cause), noting the fix and the commit/date.

Entry format:

```
### <Machine directory>: <short symptom>
- **Reported**: <date>
- **Symptom**: <what's observed on hardware, or the gap vs. convention>
- **Tried**: <troubleshooting already attempted and its outcome; n/a if this is a
  by-inspection gap rather than a hardware fault>
- **Status**: open | investigating | fixed
```

## Open

### Galaga-Midway-by-Dar: controls don't follow the standard button/joystick allocation
- **Reported**: 2026-09-22
- **Symptom**: only `btnC` (reset) and JA (right/left/fire) are wired; coin and start
  are reachable only via joystick fire+direction combos (fire+left = start1, fire+right
  = start2, fire+up = coin) -- no dedicated `btnU`/`btnD`/`btnL`/`btnR` for coin-in/1P
  start/2P start, unlike the standard mapping in root `PORTING_SPEC.md` §3.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: open, needs updated control wiring in `contrib/basys3/code/galaga_basys3.vhd`
  to add the standard dedicated buttons.

### Popeye-by-Dar: controls don't follow the standard button/joystick allocation
- **Reported**: 2026-09-22
- **Symptom**: only `btnC` (reset) is wired; coin and start are reachable only via
  keyboard function keys (F1/F2/F3) or joystick fire+direction combos (fire+up = coin,
  fire+left = start1) -- no dedicated `btnU`/`btnD`/`btnL`/`btnR` for coin-in/1P
  start/2P start, unlike the standard mapping in root `PORTING_SPEC.md` §3.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: open, needs updated control wiring in `contrib/basys3/code/popeye_basys3.vhd`
  to add the standard dedicated buttons.

### Kick-Midway-MCR-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-22
- **Symptom**: `btnU`/`btnD`/`btnL`/`btnR`/JA (right/left/fire) already follow the
  standard allocation -- no defect there. The keyboard, however, is still wired to the
  legacy JB1/JB3 Pmod header (`Basys-3-Master.xdc`'s `##Pmod Header JB` block active,
  `##USB HID (PS/2)` C17/B17 block commented out), not the onboard USB-HID host that's
  the project default (root `PORTING_SPEC.md` §3). Its keyboard clock (`clock_kbd`,
  `clock_40` / 10 via `clock_div`) is also ~2 MHz, shared with the PWM audio gate --
  below the >= 6 MHz the onboard USB-HID port needs, so the XDC pin swap alone won't be
  enough; needs an independent keyboard-clock divider first (same pattern as
  `vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md` §5's fix).
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault. Clock
  value independently re-verified 2026-09-24 (exact: `clock_40`=40.000 MHz, `clock_div`
  toggling `clock_kbd` every 20 cycles = 2.000 MHz) -- claim confirmed.

  A first fix attempt (2026-09-24) added a new, independent `clock_div_kbd` counter
  (2-bit, mod-3) dedicated to `clock_kbd` only (`clock_40` / 6 = 6.667 MHz), leaving
  the pre-existing `clock_div`/PWM-gate counter unchanged, plus the standard XDC pin
  swap. Staged cleanly (fresh `make setup/create_prj/clk_wiz/patch`, no errors;
  `check_syntax` clean apart from one pre-existing, unrelated warning) but hardware
  testing found **no video and no sound** -- reverted in full (tracked files restored
  to HEAD, build tree cleaned) before any further diagnosis.

  Pristine baseline hardware-confirmed 2026-09-25: PS/2 keyboard, btn, and JA inputs
  all working (F8 needed to switch to VGA mode -- expected, documented display-mode
  toggle, not a defect). Root cause of the first attempt's no-video/no-sound symptom
  was never found. Second fix attempt applied 2026-09-25 (identical design to the
  first, and to the now-proven Solar-Fox/Tron pattern): new independent
  `clock_div_kbd` counter + XDC pin swap. Staged cleanly again (fresh
  `make setup/create_prj/clk_wiz/patch`, no errors; `check_syntax` clean apart from
  the same one pre-existing, unrelated `clk_wiz_0` warning).

  Hardware-confirmed 2026-09-25: USB-HID keyboard and other controls (btn, JA) all
  working as expected, on the same second-attempt build.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Phoenix-by-Dar: no dedicated buttons/JA joystick; keyboard not on the standard USB-HID convention
- **Reported**: 2026-09-22
- **Symptom**: only `btnC` (reset) and PS/2 (`ps2_dat`/`ps2_clk`, legacy JB1/JB3) are
  wired -- no JA port exists in the entity at all, no `btnU`/`btnD`/`btnL`/`btnR`. This
  is NOT a simple oversight: per `contrib/basys3/code/phoenix_basys3.vhd`'s own header,
  a patch adding external coin/start/fire/direction ports
  (`contrib/code/phoenix_expose_control_ports.patch`) was hardware-tested and caused
  **no input to register at all** (PS/2 keyboard, sound, and video all still worked on
  that same build) -- it was reverted. Root cause of that failure was never found.
  Separately, the keyboard is on legacy JB, not the onboard USB-HID convention -- this
  part IS a simple pin swap: Phoenix's keyboard clock (`clock_11`, core-internal, no
  wrapper-level divider) is already 11 MHz, above the >= 6 MHz USB-HID needs, so no
  clock-divider fix is required here, unlike Kick-Midway-MCR above.
- **Tried**: USB-HID pin swap applied 2026-09-23: `Basys-3-Master.xdc`'s `##Pmod
  Header JB` (A14/B15) lines commented out, `##USB HID (PS/2)` (C17/B17) lines
  uncommented and retargeted from placeholder `PS2Clk`/`PS2Data` to `ps2_clk`/
  `ps2_dat` -- pure XDC change, no VHDL edit. Hardware-confirmed 2026-09-23: `btnC`
  (reset) and the full PS/2 keyboard path (coin/1P start/2P start/left/right/
  shield/fire) work correctly.

  JA/buttons attempted twice, both reverted. First attempt (recovered from git
  history, commit `64d170b`/`384b9e2`): hardware-tested with no input registering at
  all (2026-09-22). Second attempt (2026-09-25, "reapply the full patch as before"):
  rewritten from scratch (`btnU`=coin, `btnD`=redundant coin, `btnL`=1P start,
  `btnR`=2P start, JA1=right/JA2=left/JA4=up(shield)/JA7=fire), verified clean at
  the syntax/staging level, and hardware-tested extensively. Found: raw pin
  toggling confirmed correct via a temporary LED diagnostic; a forensic netlist
  trace proved every signal reaches the exact same CPU register bit
  (`phoenix_inst/cpu8085/u0/DI_Reg[0..2]`) the working PS/2 F1/F2/F3 keys use;
  quick taps were sometimes missed (no debounce existed on the raw path) and were
  fixed with an added `debounce_stretch` synchronizer -- yet even after that fix,
  JA/buttons still produced zero in-game effect, an unresolved contradiction
  between verified-correct digital logic and observed behavior. A further LED tap
  on the post-debounce `ext_coin`/`ext_start1`/`ext_start2` signals themselves was
  built but never read (hardware testing was interrupted by a JTAG/USB
  disconnection before it could be tried). Per user request (2026-09-25, "unroll
  the hacks... just leave the usb-hid conversion"), all JA/buttons code (the
  `debounce_stretch` block, `btnU`/`btnD`/`btnL`/`btnR`/`JA`/`led` ports, the
  `ext_*` signals/wiring, and the recreated core patch) was fully reverted,
  keeping only the USB-HID conversion. Verified via fresh `make clean && make
  setup && make create_prj && make clk_wiz && make patch` (no errors) and Vivado
  `check_syntax` (clean) that the reverted source matches the USB-HID-only state.
- **Status**: USB-HID pin swap and keyboard/reset are hardware-confirmed working
  and done. JA/buttons: code fully reverted 2026-09-25 (not merely paused) after
  two inconclusive hardware attempts; needs a fresh approach before retrying --
  the unread `ext_coin`/`ext_start1`/`ext_start2` LED-tap diagnostic (see above) is
  the most promising unexplored lead if this is picked up again.

### Tron-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-23
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header
  (`Basys-3-Master.xdc`'s `##Pmod Header JB` block active, `##USB HID (PS/2)` C17/B17
  block commented out), not the onboard USB-HID host that's the project default (root
  `PORTING_SPEC.md` §3). Its keyboard clock (`clock_kbd`, `clock_40` / 10 via
  `clock_div`) is ~2 MHz, shared with the PWM audio gate (same `clock_div = "0000"`
  gate) -- below the >= 6 MHz the onboard USB-HID port needs, so the XDC pin swap alone
  won't be enough; needs an independent keyboard-clock divider first (same pattern as
  `vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md` §5's fix). Identical situation to
  Kick-Midway-MCR-by-Dar above.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.

  A fix attempt (2026-09-25, same pattern as Kick-Midway-MCR/Solar-Fox: new
  independent `clock_div_kbd` counter dedicated to `clock_kbd`, XDC pin swap) staged
  and verified cleanly (fresh `make setup/create_prj/clk_wiz/patch`, no errors;
  `check_syntax` clean apart from pre-existing unrelated warnings) but was reverted
  before hardware testing at the user's request ("not sure about tron, undo it") --
  same caution as the Kick-Midway-MCR revert. Tracked files restored to HEAD, build
  tree cleaned.

  Re-attempted 2026-09-25 (identical design, same proven Kick/Solar-Fox pattern):
  new independent `clock_div_kbd` counter + XDC pin swap. Staged and verified cleanly
  again (fresh `make setup/create_prj/clk_wiz/patch`, no errors; `check_syntax` clean
  apart from the same two pre-existing, unrelated warnings -- the `clk_wiz_0`
  unmapped-`reset` pattern seen on the sibling machines, and one inside the untouched
  pristine core's palette-RAM port map).

  Hardware-confirmed 2026-09-25: USB-HID keyboard working.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Time-Pilot-by-Dar: keyboard not on USB-HID; controls don't follow the standard allocation
- **Reported**: 2026-09-23
- **Symptom**: two separate gaps.
  1. **USB-HID**: keyboard was wired to the legacy JB1/JB3 Pmod header. Unlike
     Kick/Tron above, this one needed XDC pin swap only: the keyboard clock
     (`clock_6`, a dedicated `clock_12` / 2 toggle, not shared with the PWM audio gate
     -- audio runs on its own separate `clock_14`) was independently re-verified
     (2026-09-23) at 6.144 MHz (`clock_12` achieves 12.288 MHz, not a clean 12.000 --
     a documentation-precision correction to this entry's earlier "exactly 6 MHz"; the
     verdict is unaffected), comfortably above the >= 6 MHz the onboard USB-HID port
     needs. Fixed 2026-09-23: `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented
     out, `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
     `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat` -- pure XDC change, no VHDL edit. Verified
     via fresh `make clean && make setup && make create_prj && make clk_wiz && make
     patch`: no errors, copied project XDC confirmed to carry the swap.
     Hardware-confirmed 2026-09-25.
  2. **Controls**: only `btnC` (reset) is wired; coin and start are reachable only via
     keyboard or joystick fire+direction combos (fire+up = coin, fire+left = start1,
     fire+right = start2) -- no dedicated `btnU`/`btnL`/`btnR`, unlike the standard
     mapping in root `PORTING_SPEC.md` §3 (single coin input, so no `btnD` needed, same
     as Galaga-Midway-by-Dar/Popeye-by-Dar above). The XDC already has the `btnU`/`btnL`/
     `btnR` pin definitions present, just commented out (template default). Still open.
- **Tried**: n/a -- both are by-inspection gaps vs. convention, not hardware faults.
- **Status**: USB-HID pin swap done, hardware-confirmed 2026-09-25.
  Controls still open -- needs the same dedicated-button wiring added to
  `contrib/basys3/code/time_pilot_basys3.vhd` as Galaga/Popeye above.

### Xevious-by-Dar: keyboard not on USB-HID; down movement not reachable from JA
- **Reported**: 2026-09-23
- **Symptom**: two separate gaps.
  1. **USB-HID**: keyboard was wired to the legacy JB1/JB3 Pmod header. Like
     Phoenix/Time-Pilot, this was a pure XDC pin swap: the keyboard is already clocked
     on a dedicated `clock_11` (independently re-verified 2026-09-23 at exactly
     11.000 MHz, direct MMCM output, the file's own comment already calls it
     "synchronous clock with USB HID path") -- no clock-divider work needed. Fixed
     2026-09-23: `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented out,
     `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
     `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make
     setup && make create_prj && make clk_wiz && make patch`: no errors, copied
     project XDC confirmed to carry the swap. Not yet hardware-confirmed.
  2. **Down movement**: the core has a real `down` input (wired at
     `down => joyBCPPFRLDU(1)` in the core's port map), but it's currently reachable
     only from the keyboard (`joyBCPPFRLDU(1) <= kbd_joy(1);` -- no JA source). This
     port's JA layout deviates from the standard convention on purpose: JA3
     (`JA(2)`) is repurposed as the second fire/"bomb" button instead of "down" (the
     file's own comment: "JA[2]=bomb ... down unused (the game has no down control;
     down is keyboard-only)" -- that "no down control" claim is itself inaccurate,
     since the core input clearly exists). Requested fix: OR `not JA(2)` into the
     `down` signal alongside the existing bomb wiring, so the JA3/bomb button does
     double duty as down-movement + second fire, matching what's asked here. Still
     open.
- **Tried**: n/a -- both are by-inspection gaps vs. convention/request, not hardware
  faults.
- **Status**: USB-HID pin swap done (staged/verified, not yet hardware-confirmed).
  Down/fire remap still open -- needs a one-line change in
  `contrib/basys3/code/xevious_basys3.vhd`: `joyBCPPFRLDU(1) <= kbd_joy(1) or not
  JA(2);` (alongside the existing `joyBCPPFRLDU(8) <= kbd_joy(8) or not JA(2);` bomb
  wiring, unchanged).

### Solar-Fox-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-23
- **Symptom**: `btnU`/`btnL` (coin/start) and JA already follow the standard
  allocation -- no defect there. (`btnD`/`btnR` are deliberately left unused, per the
  file's own comment: the core has no genuine second-coin/second-start facility,
  matching root `PORTING_SPEC.md` §3's own carve-out for that case -- nothing to
  standardize here.) The keyboard, however, is still wired to the legacy JB1/JB3 Pmod
  header (`Basys-3-Master.xdc`'s `##Pmod Header JB` block active, `##USB HID (PS/2)`
  C17/B17 block commented out), not the onboard USB-HID host that's the project
  default (root `PORTING_SPEC.md` §3). Its keyboard clock (`clock_kbd`, `clock_40` /
  10 via `clock_div`) is ~2 MHz, shared with the stereo PWM audio gate (same
  `clock_div = "0000"` gate) -- below the >= 6 MHz the onboard USB-HID port needs, so
  the XDC pin swap alone won't be enough; needs an independent keyboard-clock divider
  first (same pattern as `vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md` §5's fix).
  Identical situation to Kick-Midway-MCR-by-Dar/Tron-by-Dar above.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.

  Fix applied 2026-09-25 (same pattern as Kick-Midway-MCR): added a new, independent
  `clock_div_kbd` counter (2-bit, mod-3) dedicated to `clock_kbd` only (`clock_40` / 6
  = 6.667 MHz); the pre-existing `clock_div` counter is unchanged and still solely
  gates the PWM accumulator. `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented
  out, `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
  `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make
  setup && make create_prj && make clk_wiz && make patch` (no errors) and Vivado
  `check_syntax` (one pre-existing, unrelated critical warning on the `clk_wiz_0`
  instantiation's unmapped `reset` port -- confirmed via source inspection to predate
  this change; no warnings on the new divider logic itself). `make patch` regenerates
  the provenance patch idempotently.

  Hardware-confirmed 2026-09-25: USB-HID keyboard, `btnU`/`btnL`, and JA all working.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Solar-Fox-by-Dar: video columns clipping on Enoyo LCD
- **Reported**: 2026-09-25
- **Symptom**: several columns of video appear clipped on the user's Enoyo LCD monitor.
  Also observed on Galaga-Midway-by-Dar, Kick-Midway-MCR-by-Dar, and Tron-by-Dar (see
  their own entries below) -- a cross-machine pattern, not specific to this port.
- **Tried**: n/a -- not yet investigated.
- **Status**: open, deferred at the user's explicit request ("ignoring it for now") -- not
  being actively pursued.

### Galaga-Midway-by-Dar: video columns clipping on Enoyo LCD
- **Reported**: 2026-09-25
- **Symptom**: several columns of video appear clipped on the user's Enoyo LCD monitor.
  Same pattern reported on Solar-Fox-by-Dar, Kick-Midway-MCR-by-Dar, and Tron-by-Dar
  (see above/below) -- a cross-machine pattern, not specific to this port.
- **Tried**: n/a -- not yet investigated.
- **Status**: open, deferred at the user's explicit request ("we'll just note it for
  now") -- not being actively pursued.

### Kick-Midway-MCR-by-Dar: video columns clipping on Enoyo LCD
- **Reported**: 2026-09-25
- **Symptom**: several columns of video appear clipped on the user's Enoyo LCD monitor.
  Same pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar, and Tron-by-Dar (see
  above/below) -- a cross-machine pattern, not specific to this port.
- **Tried**: n/a -- not yet investigated.
- **Status**: open, deferred at the user's explicit request ("we'll just note it for
  now") -- not being actively pursued.

### Tron-by-Dar: video columns clipping on Enoyo LCD
- **Reported**: 2026-09-25
- **Symptom**: several columns of video appear clipped on the user's Enoyo LCD monitor.
  Same pattern reported on Solar-Fox-by-Dar, Galaga-Midway-by-Dar, and
  Kick-Midway-MCR-by-Dar (see above) -- a cross-machine pattern, not specific to this
  port.
- **Tried**: n/a -- not yet investigated.
- **Status**: open, deferred at the user's explicit request ("we'll just note it for
  now") -- not being actively pursued.

### (cross-machine): correlate synthesis duration with Cross Boundary and Area Optimization time and DSP Report
- **Reported**: 2026-09-24
- **Symptom**: not a defect -- pending investigation. Compare each machine's total
  synthesis `duration_s` (in `build-metrics.csv`) against the phase logged between
  "Start Cross Boundary and Area Optimization" and "Finished Cross Boundary and
  Area Optimization" in `<machine>/../runs/synth_1/runme.log`, plus the DSP Report /
  DSP48 counts from the same log and `*_utilization_synth.rpt`.
  Outliers on record: Tron 00:22:09 opt phase (2 DSP48E1, `plusOp`/`snd_1_reg`/
  `snd_2_reg`), Burnin-Rubber 4 DSP48E1 with DRC `DPIP-1`/`DPOP` pipelining
  warnings, Defender 00:03:31 opt, Zaxxon 00:02:14 opt.
- **Tried**: n/a -- pending investigation; timing data lives in `build-metrics.csv`.
- **Status**: open

## Fixed

### Burnin-Rubber-by-Dar: missing bottom horizontal rows
- **Reported**: 2026-09-22
- **Symptom**: video output is missing several horizontal rows at the bottom of the
  picture. Already noted in this port's own `README.md` "Known issues" ("Bottommost
  horizontal scanline is not visible") pre-dating this entry.
- **Tried**: monitor auto-adjust, manual vertical position adjustment -- neither remedies
  it. Code investigation (2026-09-23) found two distinct, evidenced candidate causes:
  1. The pristine upstream core's own vertical counter (`rtl_dar/burnin_rubber.vhd`
     `vcnt`) free-runs 0..260 (261 lines) instead of the documented/schematic 272 -- an
     11-line shortfall the pristine source's own author-comment flags as wrong
     ("total should be 272 from Bump&Jump schematics!"). Present in the pristine core,
     not introduced by this port.
  2. This port wires the scandoubler's `hs_in`/`vs_in` from the core's `video_hs`/
     `video_vs` -- a signal path the pristine DE10-lite top never exercised on real
     hardware (left `open`, comment "-- not tested", driving only `video_csync`/TV
     mode). `PORTING_SPEC.md` itself already flags this choice as unverified.
     The scandoubler module itself (`scandoubler.v`) has no vertical line-counting
     logic (`vs_out <= vs_in` passthrough, only horizontal buffering) and uses the same
     `clock_12`/`clock_6`/`ce_x2='1'` pattern as Galaga-Midway/Burger-Time (both
     video-defect-free), ruling out scandoubler clocking as the differentiator.

  User selected hypothesis #1 to try first. Fix applied 2026-09-23 as
  `contrib/code/burnin_rubber_vcnt_272_lines.patch`: `vcnt`'s wrap point changed from
  259 (`vcnt = 260`) to 270 (`vcnt = 271`), bringing the free-run length from 261 to 272
  lines. `vsync_cnt`'s independent reset condition (`vcnt = 240`) and `vblank`'s toggle
  points (`vcnt = 8`/`248`) are unaffected -- only the tail-end vertical blanking/retrace
  period is extended; the active-video window and vsync pulse are untouched. Applied
  patch verified to apply cleanly via `make clean && make setup` and to leave `make
  patch`'s provenance output byte-identical.

  Hardware re-tested 2026-09-23 with the fix in place: **symptom still present**.
  Hypothesis #1 alone does not resolve it (the patch is left in place -- it corrects a
  genuine schematic mismatch in the pristine core regardless -- but is confirmed
  insufficient on its own).

  15 kHz TV mode (sw(13)=1) is not available for A/B hardware testing on this setup, so
  hypothesis #2 could not be directly confirmed/ruled out that way. Instead, read
  `scandoubler.v` in full: it has no vertical logic at all beyond `vs_out <= vs_in`
  (a straight passthrough) -- it cannot itself drop lines, which narrowed the question to
  the core's own `video_vs` timing relative to `vblank`.

  Found (2026-09-23) a third, more precise candidate: `video_vs`'s `vsync_cnt` resets (and
  the pulse goes low) at `vcnt = 240`, but `vblank` doesn't assert until `vcnt = 248` -- an
  8-line window where the core is still generating active picture data *while* vsync is
  simultaneously pulsed. Fine for the pristine composite-sync CRT path (`video_csync`,
  pulse-train-based, tolerant of this), but a real discrete VGA vsync (as this port feeds
  the scandoubler) causes a monitor to discard active-video lines that coincide with the
  vsync pulse -- exactly matching "missing several bottom rows". Cross-checked against 4
  sibling cores sharing the same `vsync_cnt` sync-generator pattern: Burger-Time overlaps
  by only 2 lines (246 vs 248, imperceptible), Defender/Time-Pilot/Pooyan have *no* overlap
  at all (vsync starts 3-9 lines *after* `vblank` turns on) -- Burnin-Rubber's 8-line
  overlap is a clear, differentiated outlier vs. every comparable game in this family.

  Fix applied 2026-09-23 as `contrib/code/burnin_rubber_vsync_before_vblank.patch`:
  `vsync_cnt`'s reset trigger changed from `vcnt = 240` to `vcnt = 248`, so `video_vs`
  only asserts once `vblank` is already active (0-line overlap, matching the
  Defender/Time-Pilot/Pooyan pattern). `csync`'s (TV-mode) equalizing-pulse train shifts
  8 lines later in lockstep (still fully inside blanking either way) -- no TV-mode
  regression expected. Verified applying together with the vcnt-272 patch from a genuine
  fresh `make clean && make setup` extraction (both apply cleanly, no conflict), and
  `make patch`'s provenance output is unaffected (byte-identical, standard regression
  check).

  Both patches confirmed on real Basys 3 hardware 2026-09-23: symptom resolved. The
  vcnt-272 patch was mechanistically not what fixed the symptom (the vsync-timing fix
  alone would suffice -- the vsync pulse fits the frame regardless of 261 vs. 272 total
  lines) but is kept: it independently corrects a real schematic-documented discrepancy
  (frame refresh rate ~59.8 Hz -> ~57.44 Hz, matching Bump&Jump schematics) and is
  verified compatible with the vsync fix.
- **Status**: fixed. Root cause: `video_vs` asserted 8 lines before `vblank`, causing a
  VGA/scandoubler-connected monitor to discard the last 8 active-picture lines during its
  own vertical retrace. Fixed via `contrib/code/burnin_rubber_vsync_before_vblank.patch`
  (`vsync_cnt` reset moved from `vcnt = 240` to `vcnt = 248`), applied alongside
  `contrib/code/burnin_rubber_vcnt_272_lines.patch` (an independently-correct but
  not-load-bearing schematic-accuracy fix, kept for correctness).
