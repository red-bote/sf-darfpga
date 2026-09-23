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
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: open. This is one of the 5 machines already identified needing this class
  of fix (see the tabled USB-HID keyboard-conversion workstream); not yet applied here.

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
- **Tried**: JA/buttons -- see above, hardware-tested and reverted (no input
  registered). USB-HID pin swap -- not yet attempted on this machine.
- **Status**: open. USB-HID is a low-risk pin-only change (same pattern as the other
  machines in the tabled workstream). JA/buttons needs re-investigation of the prior
  failure before retrying -- do not just reapply the reverted patch unchanged.

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
- **Status**: open. One of the 5 machines already identified needing this class of fix
  (see the tabled USB-HID keyboard-conversion workstream); not yet applied here.

### Time-Pilot-by-Dar: keyboard not on USB-HID; controls don't follow the standard allocation
- **Reported**: 2026-09-23
- **Symptom**: two separate gaps.
  1. **USB-HID**: keyboard is still wired to the legacy JB1/JB3 Pmod header
     (`Basys-3-Master.xdc`'s `##Pmod Header JB` block active, `##USB HID (PS/2)` C17/B17
     block commented out). Unlike Kick/Tron above, this one needs XDC pin swap only:
     the keyboard clock (`clock_6`, a dedicated `clock_12` / 2 toggle, not shared with
     the PWM audio gate -- audio runs on its own separate `clock_14`) is exactly 6 MHz,
     already at the >= 6 MHz the onboard USB-HID port needs.
  2. **Controls**: only `btnC` (reset) is wired; coin and start are reachable only via
     keyboard or joystick fire+direction combos (fire+up = coin, fire+left = start1,
     fire+right = start2) -- no dedicated `btnU`/`btnL`/`btnR`, unlike the standard
     mapping in root `PORTING_SPEC.md` §3 (single coin input, so no `btnD` needed, same
     as Galaga-Midway-by-Dar/Popeye-by-Dar above). The XDC already has the `btnU`/`btnL`/
     `btnR` pin definitions present, just commented out (template default).
- **Tried**: n/a -- both are by-inspection gaps vs. convention, not hardware faults.
- **Status**: open. USB-HID here is a pure XDC pin swap (no clock-divider work needed,
  unlike Kick/Tron). Controls need the same dedicated-button wiring added to
  `contrib/basys3/code/time_pilot_basys3.vhd` as Galaga/Popeye above.

### Xevious-by-Dar: keyboard not on USB-HID; down movement not reachable from JA
- **Reported**: 2026-09-23
- **Symptom**: two separate gaps.
  1. **USB-HID**: keyboard is still wired to the legacy JB1/JB3 Pmod header
     (`Basys-3-Master.xdc`'s `##Pmod Header JB` block active, `##USB HID (PS/2)` C17/B17
     block commented out). Like Phoenix/Time-Pilot, this is a pure XDC pin swap: the
     keyboard is already clocked on a dedicated `clock_11` (11 MHz, direct MMCM output,
     the file's own comment already calls it "synchronous clock with USB HID path") --
     no clock-divider work needed.
  2. **Down movement**: the core has a real `down` input (wired at
     `down => joyBCPPFRLDU(1)` in the core's port map), but it's currently reachable
     only from the keyboard (`joyBCPPFRLDU(1) <= kbd_joy(1);` -- no JA source). This
     port's JA layout deviates from the standard convention on purpose: JA3
     (`JA(2)`) is repurposed as the second fire/"bomb" button instead of "down" (the
     file's own comment: "JA[2]=bomb ... down unused (the game has no down control;
     down is keyboard-only)" -- that "no down control" claim is itself inaccurate,
     since the core input clearly exists). Requested fix: OR `not JA(2)` into the
     `down` signal alongside the existing bomb wiring, so the JA3/bomb button does
     double duty as down-movement + second fire, matching what's asked here.
- **Tried**: n/a -- both are by-inspection gaps vs. convention/request, not hardware
  faults.
- **Status**: open. USB-HID is a pure XDC pin swap. Down/fire needs a one-line change
  in `contrib/basys3/code/xevious_basys3.vhd`: `joyBCPPFRLDU(1) <= kbd_joy(1) or not
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
- **Status**: open. One of the 5 machines already identified needing this class of fix
  (see the tabled USB-HID keyboard-conversion workstream); not yet applied here.

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
