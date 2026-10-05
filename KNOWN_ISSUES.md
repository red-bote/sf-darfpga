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

### Phoenix-by-Dar: btnC reset does not reset the sound
- **Reported**: 2026-10-02 (user, hardware)
- **Symptom**: btnC resets the CPU/video but the sound keeps playing.
- **Cause** (by inspection, pristine Dar core): the four sound modules get
  `reset => '0'` (`rtl_dar/phoenix.vhd:364,376,388,398`, effect1/2/3 and music; each
  has working synchronous reset logic), and the CPU-written sound registers
  `sound_a`/`sound_b` (`phoenix.vhd:200-212`) are not cleared on reset.
- **Proposed fix**: core patch `phoenix_sound_reset.patch`: `reset => reset` on the four
  modules and `sound_a`/`sound_b` <= 0 while reset (CRLF-preserving, as the other
  Phoenix patches).
- **Status**: open, deferred (user, 2026-10-02).

### Tron-by-Dar: bottom horizontal line shows flickering junk
- **Reported**: 2026-10-01 (user, hardware)
- **Symptom**: the bottom scan line of the picture shows flickering garbage.
- **Tried**: n/a.
- **Status**: open, deferred (user, 2026-10-01). Native progressive timing (634 x 525,
  `vcnt` wrap 524); compare vblank/vsync thresholds with the active window first.

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

### Time-Pilot-by-Dar, Pooyan-by-Dar: intermittent sync failure after reset (~50%)
- **Reported**: 2026-10-01 (user, hardware; builds of 2026-10-01 with the `locked`
  reset convention, Time-Pilot also with the 263-line patch)
- **Symptom**: press btnC, watch for sync; the display fails to sync on about half of
  the resets (Time-Pilot: 4 of 5 in one count). Same behavior on both machines. Extends the existing Pooyan entry below.
- **Tried**: n/a.
- **Candidate cause** (by inspection, not confirmed): the wrapper and the core each
  toggle their own `clock_6` from `clock_12` with no common reset, so the DECA
  scandoubler (`clkvideo` = wrapper copy) and the core (core copy) start in phase or
  180 degrees apart depending on reset timing. A coin-flip per reset matches the ~50%
  rate. `CLOCKING_SPEC.md` section 5.1 (proposed fix: drive the doubler from the
  core's own `clock_6`).
- **Status**: fixed 2026-10-05 (hardware-confirmed on both machines, user). Fixed by the
  combined change below (single clock domain + MiST scandoubler); per-cause attribution not
  tested (`CLOCKING_SPEC.md` 5.1). History: open, deferred (user, 2026-10-01). Re-observed 2026-10-05 (user, both
  machines). Survey 2026-10-05: 9 clock nets per machine, Vivado `no_clock` on the
  register-derived clocks, so the core-to-doubler path is untimed. Fix in progress
  (user decision: single domain): Pooyan converted 2026-10-05 (one `clk_core`,
  enables, MiST scandoubler; `Pooyan-by-Dar/contrib/basys3/PORTING_SPEC.md`
  section 2), hardware-confirmed 2026-10-05 (user). Time-Pilot converted the same day
  (`Time-Pilot-by-Dar/contrib/code/time_pilot_single_domain.patch`), hardware-confirmed 2026-10-05 (user).
- **Earlier Pooyan record** (merged 2026-10-02 from the 2026-09-25 entry):
  - **Reported**: 2026-09-25
  - **Symptom**: the double-scanner (`vga_scandoubler.v`, the canonical DECA
    cleanroom import) doesn't always sync up on real hardware -- an intermittent
    clocking issue, not yet characterized. Observed alongside the hardware
    confirmation of the USB-HID keyboard fix (unrelated: the USB-HID change was
    XDC-only, no clocking touched).
  - **Tried**: n/a -- not yet investigated.
  - **Status** (superseded, see above): open, todo -- needed further hardware investigation to characterize
    the intermittency (e.g. cold-start vs. warm reset, sw(13) 31 kHz/15 kHz mode
    correlation, `clock_12`/`clock_6`/`clock_14` MMCM lock timing).

### Bagman, Berzerk, Galaga-Midway, Kick-Midway-MCR, Popeye, Solar-Fox, Tron, Zaxxon: video columns clipping on Eyoyo EM08F
- **Reported**: 2026-09-25 (user, hardware; eight separate entries, merged here)
- **Symptom**: several columns of video clipped on the Eyoyo EM08F monitor only.
- **Tried**: n/a (not investigated).
- **Status**: closed 2026-10-02 without a fix: Eyoyo EM08F retired from use (user).
  Reference displays are the Sylvania SF150 and LG Flatron L2000CP
  (`CLOCKING_SPEC.md` section 2).

### Burger-Time-by-Dar, Burnin-Rubber-by-Dar, Computer-Space-by-Dar: routed timing not met
- **Reported**: 2026-10-02 (routed timing summaries, by inspection)
- **Symptom**: Burger-Time / Burnin-Rubber WHS -0.60 ns (6 MHz `clk_out2` as
  scandoubler `ce_x1` into the 12 MHz domain). Computer-Space WNS -4.785 ns / WHS
  -0.497 ns (50 -> 6 and 50 -> 12 MHz crossings; `game_clk` net as `ce_x1`). No
  hardware symptom reported.
- **Tried**: n/a (by inspection).
- **Fix applied** (2026-10-02, `CLOCKING_SPEC.md` 5.2): single clock domain on all
  three. Burger-Time / Burnin-Rubber: `clk_out2` removed, `ce_x1` = `clock_12`
  toggle. Computer-Space: 48 MHz single output, 6/12 MHz enables, RTL patches
  `computer_space_single_domain.patch` / `computer_space_motion_single_domain.patch`
  (`Computer-Space-by-Dar/contrib/basys3/PORTING_SPEC.md` §Clocking), PS/2, JA and
  buttons 2-FF synchronized.
- **Status**: fixed 2026-10-02. Rebuilt: WNS / WHS Burger-Time 28.849 / 0.133,
  Burnin-Rubber 27.933 / 0.137, Computer-Space 4.025 / 0.122; hardware-confirmed (user).

### Solar-Fox-by-Dar: no sync on Sylvania SF150 at power-on (15 kHz TV-mode default)
- **Reported**: 2026-09-28
- **Symptom**: on the user's Sylvania SF150 (31 kHz+ multiscan, 1024x768 @ up to
  85 Hz) Solar Fox shows no sync on reset until F8 is pressed.
- **Cause**: Solar Fox's display mode was `tv15Khz_mode <= not fn_toggle(7)` (F8
  toggle from the DE10-lite convention), and `fn_toggle` in `kbd_joystick.vhd`
  has no reset/init -- the register powers up to 0, so the machine boots into
  15 kHz interlaced TV mode (csync on HS, VS held high) every power-on. sw(13)
  had no effect on this machine (unlike every other port). The core's 31 kHz
  mode is textbook 634x525 @ 20 MHz (31.55 kHz / 60.1 Hz, 512x480) and locks
  the SF150 immediately.
- **Tried**: 2026-09-28 -- confirmed on the bench that F8 (31 kHz) syncs the
  SF150; root-caused in RTL to the missing reset/init on the toggle flip-flop.
- **Resolved**: 2026-09-28 -- mode moved to the other ports' convention,
  `tv15Khz_mode <= sw(13)` (wrapper-only; `0` = 31 kHz VGA default, `1` =
  15 kHz TV), so power-on with sw(13)=0 outputs 31 kHz without any key press.
  `solar_fox_de10_lite_to_basys3.patch` regenerated; new bitstream built.
- **Status**: fixed 2026-09-28 (see Resolved above).

### (cross-machine): control input inconsistencies
- **Reported**: 2026-10-01 (user, hardware sweep of the 2026-10-01 builds). USB-HID
  keyboard and btnC = reset confirmed working on all machines tested.
- **Symptom / resolution**:
  - JA fire missing on all twelve tested, and Sky-skipper JA left/right: a broken
    joystick connection (user, 2026-10-01). RTL and XDC were correct (fire = `JA(4)`,
    pin H1, JA7, on every machine); working with a new joystick connection.
  - No btnU/D/L/R: seven machines constrained only btnC (Bagman, Galaga, Phoenix,
    Pooyan, Popeye, Time-Pilot, Tron). Fixed in source 2026-10-01 for six (wrapper +
    XDC, standard mapping btnU = coin, btnL = 1P start, btnR = 2P start, OR-merged
    with keyboard and JA combos; Tron also btnD = coin 2). Phoenix deferred: its
    keyboard is decoded inside the core, so JA and buttons need a core patch to
    expose the player inputs (open entry below).
  - Xevious JA down: entry below. Sky-skipper / Solar-Fox Left Ctrl: Fixed.
- **Status**: fixed; six button machines hardware-confirmed 2026-10-02 (user sweep).
  Phoenix done separately (own entry in Fixed, hardware-confirmed 2026-10-02).

### Galaga-Midway-by-Dar: controls don't follow the standard allocation; keyboard not on USB-HID
- **Reported**: 2026-09-22
- **Symptom**: two separate gaps.
  1. **Controls**: only `btnC` (reset) and JA (right/left/fire) are wired; coin and start
     are reachable only via joystick fire+direction combos (fire+left = start1, fire+right
     = start2, fire+up = coin) -- no dedicated `btnU`/`btnD`/`btnL`/`btnR` for coin-in/1P
     start/2P start, unlike the standard mapping in root `PORTING_SPEC.md` §3.
  2. **USB-HID**: keyboard is still wired to the legacy JB1/JB3 Pmod header (confirmed
     2026-09-25 via direct XDC inspection, part of a repo-wide audit that found 9 machines
     still on legacy JB, not just the 6 already tracked/fixed above). Keyboard clock
     (`clock_9`) is a dedicated divider (`clock_36`/2/2, requested-nominal 36 MHz source,
     no achieved-frequency data on disk) not shared with PWM (which uses `clock_18`
     instead) -- pure XDC pin swap, no VHDL change needed. Fixed 2026-09-25:
     `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented out, `##USB HID (PS/2)`
     lines uncommented and retargeted from placeholder `PS2Clk`/`PS2Data` to
     `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make setup && make create_prj
     && make clk_wiz && make patch` (no errors) and Vivado `check_syntax` (no
     errors/critical warnings). `make patch` re-run confirms idempotent provenance-patch
     regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard working (video
     columns clipping also observed on this build -- see the cross-machine clipping
     entry below).
- **Tried**: n/a -- both are by-inspection gaps vs. convention, not hardware faults.
- **Status**: controls fixed 2026-10-01 (btnU = coin, btnL = 1P start, btnR = 2P
  start, OR-merged; XDC lines enabled); hardware-confirmed 2026-10-02 (user sweep).
  USB-HID pin swap fixed and hardware-confirmed 2026-09-25.

### Popeye-by-Dar: controls don't follow the standard allocation; keyboard not on USB-HID
- **Reported**: 2026-09-22
- **Symptom**: two separate gaps.
  1. **Controls**: only `btnC` (reset) is wired; coin and start are reachable only via
     keyboard function keys (F1/F2/F3) or joystick fire+direction combos (fire+up = coin,
     fire+left = start1) -- no dedicated `btnU`/`btnD`/`btnL`/`btnR` for coin-in/1P
     start/2P start, unlike the standard mapping in root `PORTING_SPEC.md` §3.
  2. **USB-HID**: keyboard is still wired to the legacy JB1/JB3 Pmod header (confirmed
     2026-09-25, same repo-wide audit as Galaga above). Keyboard clock (`clock_kbd`,
     `clock_40`/20 via `clock_div`) is ~2.016 MHz (requested-nominal 40.32 MHz source),
     shared with the PWM audio gate (`clock_div = "0000"`) -- below the >= 6 MHz the
     onboard USB-HID port needs, so the XDC pin swap alone won't be enough; needs an
     independent keyboard-clock divider first (same pattern as Kick-Midway-MCR/Tron/
     Solar-Fox above): new mod-3 counter off `clock_40` alone -> 6.72 MHz, leaving
     `clock_div`/PWM untouched. Hardware-confirmed 2026-09-25: legacy JB1/JB3 PS/2
     keyboard working (baseline, pre-USB-HID-conversion).

     **2026-09-26**: at the user's explicit direction, the divider fix above was not
     applied; a plain XDC pin swap was done instead (same pattern as the other 9
     machines), on the reasoning that the keyboard already works on the legacy
     JB Pmod so the onboard USB-HID host should too. `Basys-3-Master.xdc`'s
     `##Pmod Header JB` lines commented out, `##USB HID (PS/2)` lines uncommented and
     retargeted from placeholder `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via
     fresh `make clean && make setup && make create_prj && make clk_wiz && make patch`
     (no errors) and Vivado `check_syntax` (no errors/critical warnings); `make patch`
     re-run confirms idempotent provenance-patch regeneration. This does **not**
     resolve the documented <6 MHz clock-rate concern above -- whether the ~2 MHz
     `clock_kbd` is fast enough for the onboard USB-HID host is unverified and
     untested on real hardware; if the keyboard doesn't respond, the divider fix
     described above is the fallback.

     **2026-09-28**: plain pin swap confirmed non-functional on hardware. Fallback
     divider fix applied: `contrib/basys3/code/popeye_basys3.vhd`'s combined
     `clock_div`/`clock_kbd` process split in two -- `clock_div` (4-bit, unchanged)
     still free-runs and gates the PWM accumulator only; a new `clock_div_kbd`
     (2-bit, mod-3) drives `clock_kbd` independently at `clock_40`/6 = 6.72 MHz,
     matching the Kick-Midway-MCR/Solar-Fox precedent. `keyboard`/`joystick`
     entities unchanged (still clocked from `clock_kbd`, now fast). Verified via
     fresh `make clean && make setup && make create_prj && make clk_wiz && make
     patch` (no errors), Vivado `check_syntax` (no errors/critical warnings), and
     `make patch` re-run (idempotent provenance-patch regeneration).
     Hardware-confirmed 2026-09-28: USB-HID keyboard working.
- **Tried**: n/a -- both are by-inspection gaps vs. convention, not hardware faults.
- **Status**: controls fixed 2026-10-01 (btnU = coin, btnL = 1P start, btnR = 2P
  start, OR-merged; XDC lines enabled); hardware-confirmed 2026-10-02 (user sweep).
  USB-HID: plain pin swap (2026-09-26) failed; fallback divider fix fixed and
  hardware-confirmed 2026-09-28.

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

  **2026-09-29**: the F8-based display-mode toggle noted above (line 121) shared the
  exact same latent defect subsequently found and fixed on Solar-Fox (see "Solar-Fox-by-Dar:
  no sync on Sylvania SF150 at power-on" above): `tv15Khz_mode <= not fn_toggle(7)`, and
  `fn_toggle` in `kbd_joystick.vhd` has no reset/init, so the machine could boot into 15 kHz
  TV mode on some monitors until F8 was pressed once. Changed to `tv15Khz_mode <= sw(13)`
  (`contrib/basys3/code/kick_basys3.vhd`), matching the Solar-Fox/Satans-Hollow/Sky-skipper/
  Tron convention -- also requested independently by the user as part of standardizing all
  machines onto `sw(13)`. Not yet hardware-confirmed on this specific monitor-sync symptom
  (no report of it occurring on Kick), but the code path is identical to Solar-Fox's
  confirmed, resolved defect. Staged/verified via fresh `make clean && make setup && make
  create_prj && make clk_wiz && make patch` (no errors), Vivado `check_syntax` (only
  pre-existing, unrelated warnings), and `make patch` re-run (idempotent).
- **Status**: fixed and hardware-confirmed 2026-09-25 (USB-HID). Display-mode toggle changed
  to sw(13) 2026-09-29, staged/verified, not yet hardware-confirmed on this specific build.

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

  **2026-09-29**: this port's F8-based display-mode toggle (`tv15Khz_mode <= not
  fn_toggle(7)`) shared the same latent defect found and fixed on Solar-Fox (see
  "Solar-Fox-by-Dar: no sync on Sylvania SF150 at power-on" above) -- `fn_toggle` has no
  reset/init in `kbd_joystick.vhd`, so the machine could boot into 15 kHz TV mode on some
  monitors until F8 was pressed once. Changed to `tv15Khz_mode <= sw(13)`
  (`contrib/basys3/code/tron_basys3.vhd`), matching the Solar-Fox/Satans-Hollow/
  Sky-skipper/Kick convention -- also requested independently by the user as part of
  standardizing all machines onto `sw(13)`. Not yet hardware-confirmed on this specific
  monitor-sync symptom (no report of it occurring on Tron), but the code path is
  identical to Solar-Fox's confirmed, resolved defect. Staged/verified via fresh `make
  clean && make setup && make create_prj && make clk_wiz && make patch` (no errors),
  Vivado `check_syntax` (only pre-existing, unrelated warnings), and `make patch`
  re-run (idempotent).
- **Status**: fixed and hardware-confirmed 2026-09-25 (USB-HID). Display-mode toggle
  changed to sw(13) 2026-09-29, staged/verified, not yet hardware-confirmed on this
  specific build.

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
  Controls fixed 2026-10-01 (btnU/btnL/btnR as Galaga/Popeye); hardware-confirmed
  2026-10-02 (user sweep).

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
     project XDC confirmed to carry the swap. Hardware-confirmed 2026-09-25: USB-HID
     keyboard working.
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
- **Status**: USB-HID pin swap done, hardware-confirmed 2026-09-25.
  Down remap done 2026-10-01 (`joyBCPPFRLDU(1) <= kbd_joy(1) or not JA(2);`, bomb
  wiring unchanged); hardware-confirmed 2026-10-02.

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

### Bagman-FPGA-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header. Found via a
  repo-wide XDC audit (2026-09-25) that turned up 9 machines never previously tracked in
  this file's USB-HID workstream. Keyboard clock (`clock_12`) is the core's own
  undivided master clock (requested-nominal 12 MHz, direct `clk_wiz_0` output, no
  fabric division) -- already >= 6 MHz; also used for the core and the PWM accumulator,
  but as the master clock, not a dedicated/retunable divider, so sharing is not a
  concern here. Fixed 2026-09-25: `Basys-3-Master.xdc`'s `##Pmod Header JB` lines
  commented out, `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
  `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make
  setup && make create_prj && make clk_wiz && make patch` (no errors) and Vivado
  `check_syntax` (6 pre-existing critical warnings, `[HDL 9-3240]`, confirmed via source
  inspection to be inside untouched pristine core files `rtl_dar/bagman_speech.vhd` and
  `rtl_dar/bagman.vhd`, unrelated to this XDC-only change; no new warnings). `make
  patch` re-run confirms idempotent provenance-patch regeneration. Hardware-confirmed
  2026-09-25: USB-HID keyboard working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Berzerk-FPGA-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above). Keyboard clock (`clock_10`) is the core's own
  undivided master clock (requested-nominal 10 MHz) -- already >= 6 MHz; also used for
  the PWM accumulator as the master clock, same non-concern as Bagman. Fixed 2026-09-25:
  `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented out, `##USB HID (PS/2)`
  lines uncommented and retargeted from placeholder `PS2Clk`/`PS2Data` to
  `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make setup && make create_prj
  && make clk_wiz && make patch` (no errors) and Vivado `check_syntax` (no
  errors/critical warnings). `make patch` re-run confirms idempotent provenance-patch
  regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Burger-Time-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above). Keyboard clock (`clock_12`) is the core's own
  undivided master clock (requested-nominal 12 MHz) -- already >= 6 MHz; also used for
  the core `clk_sys` and PWM accumulator as the master clock, same non-concern as
  Bagman. Fixed 2026-09-25: `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented
  out, `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
  `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make
  setup && make create_prj && make clk_wiz && make patch` (no errors) and Vivado
  `check_syntax` (no errors/critical warnings). `make patch` re-run confirms idempotent
  provenance-patch regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard
  working, display OK (no video defects observed).
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Burnin-Rubber-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above). Keyboard clock (`clock_12`) is the core's own
  undivided master clock (requested-nominal 12 MHz) -- already >= 6 MHz; same
  master-clock/PWM structure as Burger-Time, same non-concern. Fixed 2026-09-25:
  `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented out, `##USB HID (PS/2)`
  lines uncommented and retargeted from placeholder `PS2Clk`/`PS2Data` to
  `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make setup && make create_prj
  && make clk_wiz && make patch` (no errors) and Vivado `check_syntax` (no
  errors/critical warnings). `make patch` re-run confirms idempotent provenance-patch
  regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard and controls working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Burnin-Rubber-by-Dar: missing bottom horizontal rows (regression)
- **Reported**: 2026-09-22; regression reported 2026-09-25
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
  Hypothesis #1 alone does not resolve it. (This patch was **retired** 2026-09-28 --
  see the resolution below; the "leave it in place as a schematic correction" position
  held here turned out to be what caused the 2026-09-25 regression.)

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

  **Regression reported 2026-09-25**: on the fresh USB-HID-converted build (XDC-only
  change, both video patches still applied and unmodified), video clipping was observed
  again on hardware. The USB-HID change itself was XDC-only (no video/clocking code
  touched), so the recurrence was in the video patches, not the keyboard conversion.

  **Root-caused 2026-09-28** by A/B hardware testing plus a timing cross-check against
  the sibling cores. The regression's cause is the `vcnt_272_lines` patch, not the
  vsync fix:

  - Timing cross-check: both Burnin-Rubber and Burger-Time share an identical
    horizontal path (hcnt 0..383, `hcnt_base = 312`, hblank 267->13, 253 active
    columns, 240 active lines, vblank onset `vcnt = 248`). Burger-Time -- a
    video-defect-free sibling on that same path -- emits 522 lines @ 59.86 Hz
    (`vcnt` 0..260, vsync reset 2 lines before vblank). Burnin-Rubber with the vcnt-272
    patch emitted 544 lines @ 57.44 Hz (`vcnt` 0..271, vsync reset at 248, zero
    overlap). The patched envelope matches no other port in the family.
  - A/B on hardware 2026-09-28: two bitstreams were built, one with both patches and
    one with the vsync fix alone (pristine `vcnt = 260` 261-line frame). The both-patches
    build clipped the bottom rows; the **vsync-only build showed no clipping**
    (hardware-confirmed by the user). This proves the vsync fix is the sole
    load-bearing patch and the vcnt-272 patch was actively harmful.

  **Resolved 2026-09-28**: `contrib/code/burnin_rubber_vcnt_272_lines.patch` **retired**
  (deleted). `contrib/code/burnin_rubber_vsync_before_vblank.patch` retained as the
  sole fix. Verified from a genuine fresh `make clean && make setup`: the remaining
  vsync patch applies standalone with no conflict, the tree's `vcnt` wrap is back to the
  pristine 260/261 lines, no 271/272 references remain, and `make patch`'s provenance
  output is byte-identical (standard regression check). This is exactly the source state
  of the hardware-confirmed-clean bitstream, so no rebuild was required.
- **Status**: resolved 2026-09-28. Root cause of the original symptom: `video_vs`
  asserted 8 lines before `vblank`, causing a VGA/scandoubler-connected monitor to
  discard the last 8 active-picture lines during its own vertical retrace; fixed via
  `contrib/code/burnin_rubber_vsync_before_vblank.patch`. The 2026-09-25 regression was
  caused by the accompanying `vcnt_272_lines` patch, now retired. Hardware-confirmed
  no clipping with the vsync fix alone.

### Defender-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above). Keyboard clock (`clock_12`) is the core's own
  undivided master clock (requested-nominal 12 MHz) -- already >= 6 MHz. PWM audio
  uses a separate `clock_3p58` chain (not the kbd clock), so no sharing concern at all
  here. Fixed 2026-09-25: `Basys-3-Master.xdc`'s `##Pmod Header JB` lines commented
  out, `##USB HID (PS/2)` lines uncommented and retargeted from placeholder
  `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make
  setup && make create_prj && make clk_wiz && make patch` (no errors) and Vivado
  `check_syntax` (no errors/critical warnings). `make patch` re-run confirms idempotent
  provenance-patch regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard and
  controls working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Pooyan-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above; this machine's XDC is at the non-standard path
  `contrib/basys3/vivado/pooyan_basys3.xdc`, not the usual `Basys-3-Master.xdc`).
  Keyboard clock (`clock_6`) is a dedicated toggle-FF divider off `clock_12`
  (requested-nominal 12.288 MHz source) -- net 6.144 MHz, already >= 6 MHz and matching
  this repo's own confirmed-working USB-HID reference rate (root `PORTING_SPEC.md` §3).
  Shared with the scandoubler's `clkvideo`, not PWM -- no sharing concern since no
  change is needed at this rate. Fixed 2026-09-25: `contrib/basys3/vivado/
  pooyan_basys3.xdc`'s `##Pmod Header JB` lines commented out, `##USB HID (PS/2)` lines
  uncommented and retargeted from placeholder `PS2Clk`/`PS2Data` to
  `ps2_clk`/`ps2_dat`. Verified via fresh `make clean && make setup && make create_prj
  && make clk_wiz && make patch` (no errors) and Vivado `check_syntax` (one
  pre-existing, unrelated critical warning on the `clk_wiz_0` instantiation's unmapped
  `reset` port -- same pattern already confirmed benign on Kick/Tron/Solar-Fox; no
  warnings on the XDC change itself). `make patch` re-run confirms idempotent
  provenance-patch regeneration. Hardware-confirmed 2026-09-25: USB-HID keyboard
  working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: fixed and hardware-confirmed 2026-09-25.

### Zaxxon-by-Dar: keyboard not on the standard onboard USB-HID convention
- **Reported**: 2026-09-25
- **Symptom**: keyboard is still wired to the legacy JB1/JB3 Pmod header (same
  repo-wide audit as Bagman above). Keyboard clock (`clock_kbd`, `clock_24`/6 via
  `clock_div`, the file's own header comment confirms this divider is "reused verbatim
  from the pristine top") is ~4 MHz (requested-nominal 24 MHz source), shared with the
  PWM audio gate (`clock_div = "0000"`) -- below the >= 6 MHz the onboard USB-HID port
  needs, so the XDC pin swap alone won't be enough; needs an independent
  keyboard-clock divider first. Note: a *different*, unrelated `other/` tree port
  (`Arcade_Zaxxon`, not this `Zaxxon-by-Dar` sf-darfpga port) independently hit and
  fixed the identical symptom by dividing by 4 instead of 6 (documented in
  `vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md` §5) -- that fix was never applied
  to this port. New mod-2 counter off `clock_24` alone -> 6 MHz exactly, leaving
  `clock_div`/PWM untouched, mirrors that known-working ratio. Hardware-confirmed
  2026-09-25: legacy JB1/JB3 PS/2 keyboard working (baseline, pre-USB-HID-conversion).

  **2026-09-26**: at the user's explicit direction, the divider fix above was not
  applied; a plain XDC pin swap was done instead (same pattern as the other 9
  machines), on the reasoning that the keyboard already works on the legacy JB Pmod
  so the onboard USB-HID host should too. `Basys-3-Master.xdc`'s `##Pmod Header JB`
  lines commented out, `##USB HID (PS/2)` lines uncommented and retargeted from
  placeholder `PS2Clk`/`PS2Data` to `ps2_clk`/`ps2_dat`. Verified via fresh `make
  clean && make setup && make create_prj && make clk_wiz && make patch` (no errors)
  and Vivado `check_syntax` (no errors/critical warnings); `make patch` re-run
  confirms idempotent provenance-patch regeneration. This does **not** resolve the
  documented <6 MHz clock-rate concern above -- whether the ~4 MHz `clock_kbd` is
  fast enough for the onboard USB-HID host is unverified and untested on real
  hardware; if the keyboard doesn't respond, the divider fix described above is the
  fallback.

  **2026-09-28**: plain pin swap confirmed non-functional on hardware. Fallback
  divider fix applied: `contrib/basys3/code/zaxxon_basys3.vhd`'s combined
  `clock_div`/`clock_kbd` process split in two -- `clock_div` (4-bit, unchanged)
  still free-runs and gates the PWM accumulator only; a new `clock_div_kbd`
  (1-bit, mod-2) drives `clock_kbd` independently at `clock_24`/4 = 6 MHz exactly,
  matching the Kick-Midway-MCR/Solar-Fox/Popeye precedent and the known-working
  divide-by-4 ratio from the unrelated `Arcade_Zaxxon` `other/` port. `keyboard`/
  `joystick` entities unchanged (still clocked from `clock_kbd`, now fast).
  Verified via fresh `make clean && make setup && make create_prj && make clk_wiz
  && make patch` (no errors), Vivado `check_syntax` (no errors/critical warnings),
  and `make patch` re-run (idempotent provenance-patch regeneration).
  Hardware-confirmed 2026-09-28: USB-HID keyboard working.
- **Tried**: n/a -- a by-inspection gap vs. convention, not a hardware fault.
- **Status**: plain pin swap (2026-09-26) failed; fallback divider fix fixed and
  hardware-confirmed 2026-09-28.

### Galaga-Midway-by-Dar: btnU coin inconsistent vs keyboard F3 after debounce
- **Reported**: 2026-10-02 (user, hardware)
- **Symptom**: fast repeated btnU presses, then btnU registers nothing for a couple of
  seconds; F3 (keyboard coin) behaves consistently.
- **Cause** (by inspection): the debounce ran on `clock_36` (MMCM) while the core runs
  on `clock_18`, a toggle of `clock_36` in fabric. `btn_db` could change next to a
  `clock_18` edge on an untimed path, so the core's coin edge detect and BCD credit
  registers (`galaga.vhd:844-856`) could sample it inconsistently. The keyboard path
  runs on `clock_9`, toggled from `clock_18`, so it is in step with the core.
  Xevious and Zaxxon debounce on their core clocks already.
- **Fix** (2026-10-02, wrapper-only): debounce moved to `clock_18` (18-bit counter,
  14.2 ms). Wrapper placed, `check_syntax` clean.
- **Status**: fixed, hardware-confirmed 2026-10-02 (user).

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
  Third attempt 2026-10-02: `contrib/code/phoenix_external_inputs.patch` adds an
  active-high `ext_joy` core input OR-merged with `JoyPCFRLDU` before the core's single
  inversion (`coin <= not (JoyPCFRLDU(7) or ext_joy(7))`, etc.), so external inputs use
  exactly the keyboard's bits and polarity. (A merge of active-low terms with OR would
  never go low on a single press; whether the earlier attempts did that is not known,
  their code was reverted.) Wrapper: JA synchronized, btnU/D/L/R synchronized and
  debounced on `clock_11`; led(7:0) = `ext_joy` as the bring-up diagnostic (remove after
  confirmation). Patch tested on a fresh extraction; `check_syntax` clean.
  Hardware-confirmed 2026-10-02 (user); LED diagnostic removed afterwards.

### (cross-machine): button behavior, debounce, JA coin/start combos
- **Reported**: 2026-10-02 (user, hardware sweep of all 20 bitstreams)
- **Findings**:
  - Coin acts on press on Galaga, Xevious, Zaxxon: the core edge-detects coin
    (`galaga.vhd:844-847`, `xevious.vhd:1164-1167`, `zaxxon.vhd:480-481`). Release
    bounce produced extra edges (possible extra coins).
  - Coin acts on press-and-release on Bagman, Burger-Time, Burnin-Rubber, Popeye,
    Satans-Hollow, Sky-skipper, Solar-Fox, Tron: the coin level goes to the game CPU and
    the original program credits after release. Original machine behavior; no change.
  - No sf-darfpga machine had button debounce (Phoenix's attempt was rolled back).
  - Eight machines still had JA fire+direction coin/start combos (Bagman, Burnin-Rubber,
    Galaga, Pooyan, Popeye, Solar-Fox, Time-Pilot, Tron), redundant with the buttons and
    prone to misfire (fire while moving up inserts a coin).
  - Display flip: only Zaxxon (F4, `flip_screen` core port).
- **Fix** (2026-10-02, wrapper-only): debounce (2-FF sync + saturating counter, ~10-14
  ms) on Galaga (btnU/L/R), Xevious (btnU/L/R), Zaxxon (btnU/D/L/R); combos removed
  from the eight wrappers; Zaxxon `flip_screen <= fn_toggle(3) xor sw(12)` (sw(12) inverted to `xor not sw(12)` 2026-10-02, hardware-confirmed). Wrappers
  placed, provenance patches regenerated, `check_syntax` clean on changed lines.
- **Status**: fixed, hardware-confirmed 2026-10-02 (user, all ten machines).

### Xevious-by-Dar: JA down triggers bomb but not down movement
- **Reported**: 2026-10-01 (user, hardware)
- **Symptom**: pushing the JA stick down fired the bomb but did not move down. The core
  uses `down` (`rtl_dar/xevious.vhd:1218`), but the wrapper drove it from the keyboard
  only; JA3 went to `bomb` only.
- **Fix** (2026-10-01, wrapper-only): `joyBCPPFRLDU(1) <= kbd_joy(1) or not JA(2);`,
  JA3 still also drives bomb. README control tables corrected.
- **Status**: fixed, hardware-confirmed 2026-10-02 (user).

### Xevious-by-Dar: stuck and missed inputs (keyboard and JA)
- **Reported**: 2026-10-02 (user, hardware; build with the 2026-10-01 changes)
- **Symptom**: keyboard and JA both show stuck inputs and missed presses. The keyboard
  was confirmed working before the 2026-10-01 changes.
- **Cause** (by inspection): the 2026-10-01 single-domain change moved
  `io_ps2_keyboard` from the 11 MHz output to the 18.432 MHz core clock, with no
  synchronizer on `ps2_clk`/`ps2_dat`. Same mechanism as
  `pinballwiz/NEXYS2-Pacman` PORTING_SPEC section 11 (hardware-confirmed there): a
  dropped bit gives a missed key, a lost F0 a stuck key. Keyboard and JA are
  OR-merged per direction, so a stuck keyboard bit also holds the JA direction.
- **Fix** (2026-10-02, wrapper-only): 2-FF synchronizers (`ASYNC_REG`) on
  `ps2_clk`/`ps2_dat`, `JA(4:0)` and `btnU`/`btnL`/`btnR` (`clock_18`). Wrapper placed,
  provenance patch regenerated, `check_syntax` clean on the changed lines.
- **Status**: fixed, hardware-confirmed 2026-10-02 (user).

### Solar-Fox-by-Dar: Fast (speed-up) on F2; Left Ctrl preferred
- **Reported**: 2026-10-01 (user)
- **Symptom**: Fast (`fast1`) was on F2 (`fn_pulse(1)` from `kbd_joystick`).
- **Fix** (2026-10-01, wrapper-only, no core patch): `solar_fox_basys3.vhd` decodes
  Left Ctrl (0x14) make/break on `clock_kbd` into `kbd_lctrl`, which replaces F2 in
  `fn_pulse(1)` (still OR JA fire+left and btnL). Same method as Sky-skipper below.
- **Status**: fixed, hardware-confirmed 2026-10-01 (user).

### Sky-skipper-by-Dar: second fire on the "F" key; Left Ctrl preferred
- **Reported**: 2026-10-01 (user)
- **Symptom**: Fire B (`fire11`/`fire21`) was on the letter F: the core's own
  `rtl_dar/kbd_joystick.vhd:36` maps 0x2B to `joy_BBBBFRLDU(5)`.
- **Fix** (2026-10-01, wrapper-only, no core patch): `sky_skipper_basys3.vhd` decodes
  Left Ctrl (0x14) make/break from `kbd_intr`/`kbd_scancode` into `kbd_lctrl`, which
  drives `fire11`/`fire21` (OR JA fire); F no longer fires. Wrapper placed, provenance
  patch regenerated, `check_syntax` clean.
- **Status**: fixed, hardware-confirmed 2026-10-01 (user).
