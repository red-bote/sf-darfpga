# CLOCKING_SPEC: sf-darfpga clock optimization

Cross-machine clock audit and proposals for the 20 sf-darfpga Basys3 ports
(TODO.md P0). Design intent only; per-machine status stays in each
machine's README and the root `README.md`. Data sources: the in-repo
audit of 2026-10-01 (generated `clk_wiz_0_clk_wiz.v`, wrappers, extracted
`rtl_dar/` sources) and `CLOCK_CRYSTAL_CATALOG.md` (original crystals,
MAME-sourced). Nothing outside this repo was read.

## 1. Policy

Binding version: `.opencode/rules.md` section "Clocking (Basys3 ports)"
(placed 2026-10-02; also in `sf-darfpga/.opencode/rules.md`). The draft below
is kept for the record.


- Prefer one clock domain: one MMCM output; CPU, pixel, sound and keyboard
  rates as clock enables from it.
- Reference: the original crystal and its derived clocks
  (`CLOCK_CRYSTAL_CATALOG.md`).
- Generate `clk_wiz_0` from the 100 MHz oscillator as close as practicable
  to the main-CPU clock ratio.
- VGA output close to 640x480@60: design window **H 31.0-32.0 kHz,
  V 56-61 Hz**; acceptance = sync on both reference displays, **Sylvania
  SF150** and **LG Flatron L2000CP** (Eyoyo EM08F dropped).
- Keyboard (PS/2) sampling in the same domain.
- Where one clock cannot satisfy CPU accuracy and the VGA window, record
  the trade-off in the machine's `PORTING_SPEC.md`.

## 2. MMCM rules (xc7a35t-1, 100 MHz in)

PFD = 100/D >= 10 MHz (D 1-10); VCO = 100*M/D in 600-1200 MHz; M
(`CLKFBOUT_MULT_F`) 2-64, step 0.125; O0 (`CLKOUT0_DIVIDE_F`) 1-128, step
0.125; O1-O6 integer. Solves below come from an exhaustive search over
these ranges (scratch script, not tracked); `make clk_wiz` records the
solve Vivado actually picks, and a Computer-Space-style `sed` override of
`clk_wiz_0_clk_wiz.v` is used only when Vivado's solve differs.

## 3. Output-rate formulas

| VGA path | H | V | Machines |
|---|---|---|---|
| internal `line_doubler` / MiST `scandoubler.v` (both repeat each native line once, V passes through; Pooyan/Time-Pilot used the DECA `vga_scandoubler.v` until 2026-10-05) | 2 x native H | native | Bagman, Berzerk, Burger-Time, Burnin-Rubber, Computer-Space, Crazy-Kong, Defender, Galaga, Phoenix, Pooyan, Time-Pilot, Traverse-USA, Xevious, Zaxxon |
| native progressive counters (no doubler) | f_pix / htotal | H / vtotal | Kick, Satans-Hollow, Solar-Fox, Tron (634 x 525), Popeye, Sky-skipper (640 x 526) |

## 4. Audit and proposals

Speed = main-CPU rate vs original. OUT = outside the design window.

| Machine | MMCM now (MHz) | H kHz / V Hz now | Speed now | Proposal | H / V after | Speed after |
|---|---|---|---|---|---|---|
| Bagman | 12.000 | 31.250 / 59.19 | -2.34% | 12.288 (5 / 48 / 78.125) | 32.000 / 60.61 | 0 |
| Berzerk | 10.000 | 31.250 / 59.64 | 0 | none | | |
| Burger-Time | 12.000 + 6.000 | 31.250 / 59.87 | see 5.3 | clock none; 6 MHz output see 5.2 | | |
| Burnin-Rubber | 12.000 + 6.000 | 31.250 / 59.87 (5.4) | 0 | clock none; 6 MHz output see 5.2 | | |
| Computer-Space | 50 + 6 + 12 (sed-forced); 48 single (2026-10-02) | 31.41 / 61.6 OUT | n/a (no CPU) | decision 5.5 | | |
| Crazy-Kong | 12.000 | 31.250 / 59.19 | -2.34% | 12.288 (5 / 48 / 78.125) | 32.000 / 60.61 | 0 |
| Defender | 12.000 + 7.15909 | 31.250 / 60.10 | see 5.3 | none (sound 3.5795454 exact) | | |
| Galaga | 36.000 | 31.250 / 59.19 | -2.34% | 36.863711 (6 / 56.125 / 25.375) | 32.000 / 60.61 | -8 ppm |
| Kick, Satans-Hollow, Solar-Fox, Tron | 40.000 | 31.546 / 60.09 | +0.16% | optional 39.935588 (3 / 31 / 25.875) | 31.495 / 59.99 | -10 ppm (sound -0.16%) |
| Phoenix | 11.000 + 50.000 | 31.250 / 61.04 OUT | 0 | decision 5.5 | | |
| Pooyan | 12.28790 + 14.31760 | 32.000 / 60.84 (60.61 from 2026-10-06, 5.7) | 0 | none; structure 5.1 | | |
| Popeye | 40.320 | 31.500 / 59.89 | **+26%** (5.6) | RTL fix 5.6; clock unchanged | 31.500 / 59.89 | +0.8% |
| Sky-skipper | 40.000 | 31.250 / 59.41 | **+25%** (5.6) | RTL fix 5.6; 40.32 (5 / 31.5 / 15.625) | 31.500 / 59.89 | +0.8% |
| Time-Pilot | 12.28790 + 14.31760 | 32.000 / 61.54 OUT | 0 | decision 5.7 | | |
| Traverse-USA | 36.84211 + 7.15909 | 31.981 / 56.70 | -0.07% | optional 36.863711 + 7.158801 (7 / 56.125 / 21.75 / O1 112) | 32.000 / 56.74 | -8 ppm (sound -40 ppm) |
| Xevious | 18.000 + 11.000 | 31.250 / 59.19 | -2.34% | 18.431983 (6 / 44.375 / 40.125; implemented as 7 / 61.125 / 47.375 = 18.431964); drop 11 MHz output, keyboard on core clock (5.2) | 32.000 / 60.61 | -1 ppm |
| Zaxxon | 24.000 | 31.250 / 59.19 | -1.36% | 24.329897 (5 / 44.25 / 36.375; implemented as 3 / 35.125 / 48.125 = 24.329004) | 31.680 / 60.00 | -4 ppm |

Ten proposals land on H = 32.000 kHz, the window edge already used by
Pooyan and Time-Pilot; TODO.md P0 tracks the confirmation on both displays.

## 5. Per-machine notes and decisions

### 5.1 Pooyan, Time-Pilot: duplicated `clock_6` toggles

The wrapper toggles its own `clock_6` from `clock_12` (DECA `clkvideo`,
keyboard) while the core toggles a separate `clock_6` (pixel, CPU). The two
flip-flops share no reset, so their relative phase (0 or 180 degrees) is
not fixed. The DECA doubler writes on the wrapper copy while the core
updates on its own. Candidate cause of the open KNOWN_ISSUES entry
"Pooyan-by-Dar: scandoubler intermittently fails to sync". Proposal:
expose the core's `clock_6` (or a `clock_6` enable) and drive the
doubler from it; a single source removes the ambiguity. Requires a core
patch; not a clock-frequency change.
Superseded 2026-10-05 (user decision: single domain). Survey: 9 clock nets
per machine, 1467 `no_clock` pins on Pooyan (core-to-doubler and
main-to-sound crossings untimed). Pooyan implemented: one MMCM output
`clk_core` = 24.573991 MHz (5 / 34.25 / 27.875), 6/12 MHz phases and the
14.318 MHz sound rate as enables (`pooyan_single_domain.patch`), MiST
scandoubler replacing the DECA doubler. Design:
`Pooyan-by-Dar/contrib/basys3/PORTING_SPEC.md` section 2. Pooyan
hardware-confirmed 2026-10-05 (routed WNS 19.991 / WHS 0.070; `no_clock`
1467 -> 8, the remaining 8 are YM2149 internal registers). Time-Pilot
converted the same day (`time_pilot_single_domain.patch`, same solve),
hardware-confirmed 2026-10-05.

### 5.2 MMCM outputs used as data enables or for the keyboard only

- Burger-Time, Burnin-Rubber: `clk_out2` (6 MHz) used only as the
  scandoubler `ce_x1`, sampled by `clk_out1` (12 MHz) at a nominally
  coincident edge (both phase 0). Proposal: drop `clk_out2`, generate
  `ce_x1` as a `clock_12` toggle enable (Defender pattern,
  `defender_basys3.vhd:154-158`). Implemented 2026-10-02 (single
  output 5 / 49.875 / 83.125 = 12.000); timing met (WHS 0.133 / 0.137),
  hardware-confirmed 2026-10-02.
- Computer-Space: `game_clk` (6 MHz) is also the scandoubler `ce_x1`
  sampled by `clk_sys` (12 MHz); same issue, but `game_clk` also clocks
  the core. Routed timing also fails setup on the 50 -> 6 and 50 -> 12
  MHz crossings (section 7a). Resolved 2026-10-02 (user decision: single
  domain): 48.000 MHz single output (5 / 49.5 / 20.625), 6/12 MHz as
  enables, 50 MHz-sized constants rescaled x0.96; RTL patches
  `computer_space_single_domain.patch`,
  `computer_space_motion_single_domain.patch`. Design:
  `Computer-Space-by-Dar/contrib/basys3/PORTING_SPEC.md` §Clocking.
  Timing met (WNS 4.025, WHS 0.122), hardware-confirmed 2026-10-02.
- Xevious: `clk_out2` (11 MHz) clocks only the keyboard. Proposal: clock
  the keyboard from the core clock (18.432 MHz), drop `clk_out2`.

### 5.3 Core CPU-rate questions (RTL vs catalog; confirm before acting)

- Burger-Time: main CPU enable `clock_12/16` = 750 kHz; catalog gives
  CPU-7 at XTAL/8 = 1.5 MHz (`burger_time.vhd:330`). Either the core
  halves the CPU or the catalog figure is wrong.
  MAME (2026-10-02): `btime.cpp:2300` `btime` DECO CPU-7 at
  12 MHz/8 = 1.5 MHz ("selectable between H2/H4 via jumper"); `bnj` /
  `disco` at 750 kHz (`:2399`, `:2454`). The port loads `btime.zip`
  (dedicated board). User note: the DECO Cassette version runs at
  750 kHz. User decision 2026-10-02: 1.5 MHz,
  `burger_time_cpu_1p5mhz.patch` (`hcnt(1 downto 0)="11"`; added CPU slot
  `hcnt(2:0)`=011 does not overlap video RAM fetches 000/100/101). Hardware-
  confirmed 2026-10-02 (picture, sound).
- Defender: `cpu_clock` gives two pulses per 6 `clock_6` periods (2 MHz
  pulse rate); catalog gives MC6809E at 1 MHz. The cpu09 core's
  cycles-per-clock relationship is not determined from the audit.
  MAME (2026-10-02): MC6809E at 12 MHz/12 = 1.0 MHz E
  (`williams.cpp:1537`). cpu09 advances one bus cycle per `clk`
  falling edge, so the FPGA E rate is 2.0 MHz; Dar's source comments
  mark the doubling as intentional ("speed up processor"). cpu09 also
  uses fewer cycles per instruction than a 6809. User decision
  2026-10-02 (original E = 4 MHz / 4 = 1 MHz): 1 MHz,
  `defender_cpu_1mhz.patch` (`cpu_clock` high at `pixel_cnt` 3-5; no
  overlap with the video RAM slot at `pixel_cnt` 0-1). Hardware-
  confirmed 2026-10-02.
- Bagman: AY on `hcnt(1)` = f/8 = 1.5 MHz; catalog XTAL/6 = 3.072 MHz.
  MAME (2026-10-02): AY at `BAGMAN_H0 / 2` = 1.536 MHz
  (`bagman.cpp:502`); FPGA `x_pixel(1)` = 1.536 MHz with `I_SEL_L='1'`
  (no extra divide). Core matches MAME; the catalog figure (Z80 clock)
  and the `bagman.vhd:591` "6 Mhz" comment are wrong.
  Speech (2026-10-02): core LPC sample rate 12.288 MHz / 12 / 2 / 64 =
  8.000 kHz; original TMS5110 at 640 kHz / 80 = 8 kHz (user). Match; no
  change. Closed.

### 5.4 Burnin-Rubber line count (resolved 2026-10-01)

Pristine 261 lines (`vcnt` wrap 260, `burnin_rubber.vhd:237`) plus
`burnin_rubber_vsync_before_vblank.patch`: V 59.87 Hz. Hardware-confirmed
2026-10-01 by the user (no vertical clipping) on the bitstream built
from that source (source 08:44, bitstream 08:48). Matches README.md:72-80
(272-line patch retired). The audit's "271" reading came from a tree
state before the 08:44 re-extraction. Catalog entry corrected
2026-10-02.

### 5.5 Machine-native V above 61 Hz (Phoenix 61.04, Computer-Space 61.6) (decided 2026-10-01: accept)

Decision: accepted as window exceptions; clocks unchanged; record in
each machine's PORTING_SPEC. Both are the original machines' own frame
rates at exact clocks. Options were: accept (window exception recorded here and in the machine
PORTING_SPEC), or scale the clock down (Phoenix 10.9937 MHz -> 61.0 Hz,
-0.06% speed). The Computer-Space line length (382 vs 381 clocks on one
line per frame, audit reading of `scan_counter.vhd:141-143`) is to be
confirmed first.

### 5.6 Popeye, Sky-skipper: CPU/AY counter width defect (approved and implemented 2026-10-01)

`clock_cnt2` is 4 bits but is compared with `"10011"` (19)
(`popeye.vhd:379,550`; `sky_skipper.vhd:172,340`). Under
`std_logic_unsigned`, `=` compares numeric values, so the reload never
fires; the counter wraps mod 16. `cpu_ena` (counts 0 and 10) averages
f/8 and `ay_ena` (count 0) f/16, against the intended f/10 and f/20:
CPU +26% / +25%, AY pitch about 4 semitones sharp. Pristine Dar source.
Implemented: `popeye_clock_cnt2_width.patch`, `sky_skipper_clock_cnt2_width.patch`
(each machine's `contrib/code/`), widening `clock_cnt2` to 5 bits (restores
f/10, f/20). Then:
- Popeye at 40.32 MHz: CPU 4.032 (+0.8%), AY 2.016, video 31.500 / 59.89.
- Sky-skipper: 40.32 MHz (decided 2026-10-01, consistent with Popeye;
  5 / 31.5 / 15.625): video 31.500 / 59.89, CPU +0.8%. Note: requesting
  40 MHz yields exactly 40.000 (current solve 1 / 10 / 25); 40.32 must be
  requested explicitly, as Popeye's script does.

### 5.7 Time-Pilot (V 61.54 Hz) (decided 2026-10-01: option D, implemented)

260 lines confirmed from the counter (`time_pilot.vhd:266,276-280`:
reload 0x0FC, wrap 0x1FF). Original line count: not determined in repo
(sister core Pooyan's comment lists a 263-line variant,
`pooyan.vhd:256-258`). Options:

| Option | Clock (O0 / O1) | V Hz | Speed |
|---|---|---|---|
| A | 12.180028 + 14.318783 (9 / 54.125 / 49.375 / 42) | 61.00 | -0.88% |
| B | 12.160494 + 14.316860 (4 / 24.625 / 50.625 / 43) | 60.90 | -1.04% |
| C | unchanged; RTL 264 lines (reload 0x0F8) | 60.61 | 0 |
| D (chosen) | unchanged; RTL 263 lines (reload 0x0F9), as Dar's later Pooyan core (`pooyan.vhd:256-258,277-278`) | 60.84 | 0 |

Option C changes the machine's frame structure; needs the original line
count (MAME `konami/timeplt.cpp` `set_raw`, external) confirmed by the
user.


Implemented as `Time-Pilot-by-Dar/contrib/code/time_pilot_vcnt_263_lines.patch`
(reset value 0x0FC kept, as in Pooyan). vblank 496/262, vsync 500 and the
interrupt at vcnt 493 all lie inside 249..511.

Revised 2026-10-06 (user; MAME lookup): `konami/pooyan.cpp`
`set_raw(18.432_MHz_XTAL / 3, 384, 0, 256, 264, 16, 240)`, comment "measured
~60.6Hz": 264 lines total, 224 visible. `konami/timeplt.cpp` gives only
`set_refresh_hz(60)` with the same 224-line visible area; same video family.
Option C adopted for both machines: Time-Pilot
`time_pilot_vcnt_264_lines.patch` (replaces the 263-line patch) and Pooyan
`pooyan_vcnt_264_lines.patch` (Dar's 263 -> 264), reload 0x0F8, V 60.61 Hz;
all event lines (vblank, vsync 500/504, NMI 493) inside 248..511.
Hardware-confirmed 2026-10-07 (user); no visible difference (accuracy change:
frame and game speed -0.38%, one extra blanked line).
Open (no change): Time-Pilot unblanks 234 lines (vcnt 262..495) vs 224 in
MAME and in Pooyan (271..494).

## 6. MMCM `locked` / reset convention

Project standard (`.opencode/skills/port-dar-machine` section 6, Bagman
pattern): `reset <= btnC or not mmcm_locked;` and `clk_wiz_0 reset => btnC`.

| Wiring | Machines |
|---|---|
| standard | Bagman, Berzerk, Burger-Time, Burnin-Rubber, Computer-Space, Crazy-Kong, Defender, Phoenix, Popeye, Satans-Hollow, Sky-skipper, Traverse-USA, Zaxxon |
| `locked => open`, MMCM reset unmapped | Kick, Pooyan, Solar-Fox, Time-Pilot, Tron |
| `locked => open`, MMCM reset constant `'0'` | Galaga, Xevious |

Proposal: move the seven to the standard pattern (wrapper-only change).
Approved and implemented 2026-10-01 in all seven wrappers (placed into the
projects, provenance patches regenerated, `check_syntax` clean for the
changed lines).

## 7. Documentation corrections found

- README/PORTING_SPEC claim `locked` is used, code has `locked => open`:
  Galaga (README:11, PORTING_SPEC:40-41), Kick (README:12), Pooyan
  (Satans/Sky/Popeye PORTING_SPECs call the standard pattern "Pooyan
  pattern"), Solar-Fox (README:11-12, PORTING_SPEC:14,18), Time-Pilot
  (README:13, PORTING_SPEC:42-43).
- Display-mode switch described as F8 or sw(13) XOR F8, code uses sw(13):
  Kick PORTING_SPEC:22-24, Solar-Fox PORTING_SPEC:22-24, Tron
  PORTING_SPEC:64,85, Satans-Hollow PORTING_SPEC:30-31, Sky-skipper
  PORTING_SPEC:27-28, Popeye PORTING_SPEC:29. Pooyan README:56-57 says
  15 kHz selectable; it was hard-wired off (resolved 2026-10-02: `sw(13)`).
- Frequencies (Defender, Traverse-USA READMEs corrected 2026-10-02;
  Xevious README describes the current 18.43196 MHz solve): Xevious docs say exact 18/11 MHz impossible (achieved
  exact); Defender docs/catalog say 3.58 MHz has a few-% error (achieved
  exact); Traverse-USA docs give `clk_out2` = 3.58 MHz (it is 7.15909,
  halved in fabric) and 36.86 (achieved 36.84211); Computer-Space
  generated header shows stale 11.90476.
- `CLOCK_CRYSTAL_CATALOG.md` (corrected 2026-10-02): Galaga is not
  single-clock (18.431856 / 12.287904 / 9.215928 / 6.143952 MHz fabric
  clocks, `galaga_basys3.vhd:134-244`) and has a sw(13) mode;
  Zaxxon has a generated `clk_wiz_0_clk_wiz.v`; Burnin-Rubber 272-line
  "fixed" (5.4); "single clock" entries omit `clock_kbd`.
- Pristine comment mismatches (no action): Popeye/Sky-skipper
  "divide by 20"; MCR `clk_8Mhz` is a 4 MHz square wave; Solar-Fox/Tron
  "635x525" vs 634.

## 7a. Close-out status (2026-10-02)

- 32.000 kHz edge accepted: user confirmed sync on both SF150 and L2000CP.
- Timing closure (routed summaries, WNS / WHS ns): Bagman 35.1 / 0.08,
  Crazy-Kong 35.5 / 0.04 (log), Galaga 23.7 / 0.28, Xevious 13.5 / 0.07,
  Zaxxon 11.8 / 0.03, Popeye 4.6 / 0.02, Sky-skipper 5.0 / 0.12, Time-Pilot
  36.7 / 0.15, Kick 5.0 / 0.14, Pooyan 36.4 / 0.20, Solar-Fox 4.2 / 0.03,
  Tron 3.9 / 0.04: all met. Not met: Burger-Time and Burnin-Rubber hold
  -0.60 on clk_out2 -> clk_out1 (section 5.2; fixed in source 2026-10-02),
  Computer-Space setup -4.8 on 50 -> 6/12 MHz crossings (single-domain
  refactor 2026-10-02, section 5.2). Rebuilt 2026-10-02: Burger-Time
  28.849 / 0.133, Burnin-Rubber 27.933 / 0.137, Computer-Space 4.025 /
  0.122: all met, hardware-confirmed.
- Popeye/Sky-skipper 40.333 (DE10 PLL) vs 40.32 MHz: CPU 4.032 vs 4.033 MHz
  after the counter fix; no action.
- Keyboard clock rates: unchanged; hardware-confirmed working.

## 8. Order of work (after per-item approval)

1. Clock-only changes, one machine per build: Bagman, Crazy-Kong, Galaga,
   Xevious, Zaxxon; optional MCR group, Traverse-USA.
2. Popeye/Sky-skipper counter patch (largest audible error).
3. Time-Pilot option; Phoenix/Computer-Space window decision.
4. `locked`/reset convention (7 wrappers).
5. Structure: Pooyan/Time-Pilot single `clock_6` source; Burger-Time /
   Burnin-Rubber / Xevious output removal.
6. Docs (section 7) with each machine's change.

Each change: `make clk_wiz` (records the solve), README "Solved MMCM",
PORTING_SPEC, catalog, TODO.md; synthesis and bitstream only on explicit
request; acceptance on both displays.
