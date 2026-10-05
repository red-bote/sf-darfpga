# Clock and Crystal Frequency Catalog

## Scope and purpose

This document catalogs, for each of the 20 committed `sf-darfpga` machine ports,
three related but distinct frequency figures:

1. The FPGA-side `clk_wiz_0` MMCM output frequency/frequencies actually
   achieved on the Basys 3 (Artix-7), derived from the 100 MHz board
   oscillator.
2. The resultant VGA/TV output timing (31 kHz progressive vs. 15 kHz TV-style,
   and, where the core's horizontal/vertical scan-counter totals are readily
   available in already-extracted pristine source, the computed horizontal
   scan rate and vertical frame rate).
3. The original arcade PCB's real crystal oscillator frequency/frequencies,
   from external research (MAME driver source, schematic archives).

This addressed a backlog item formerly recorded in root `README.md` ("Backlog":
catalog achieved clk_wiz_0 frequencies, resultant VGA frequency, and original
arcade crystal frequency per machine) — removed from that file's Backlog
section once this catalog superseded it.

## Confidence / sourcing note

- **FPGA-achieved clocks** are read from generated Vivado build artifacts
  (`sources_1/imports/clk_wiz_0/clk_wiz_0.v` header comments, which record
  Vivado's actually-solved MMCM output frequencies) where present on disk, or
  from each machine's own `README.md` "Solved MMCM" line where that line
  already documents the solved (not merely requested) DIVCLK/MULT_F/DIVIDE_F
  parameters. Where neither is available, the figure is marked
  requested-only/unconfirmed and sourced from
  `contrib/basys3/vivado/make_clk_wiz_0.sh`'s `CONFIG.CLKOUT*_REQUESTED_OUT_FREQ`
  arguments. As of 2026-10-02 every machine has a generated
  `clk_wiz_0_clk_wiz.v`; its MMCM primitive parameters (`DIVCLK_DIVIDE`,
  `CLKFBOUT_MULT_F`, `CLKOUTn_DIVIDE[_F]`, 100 MHz input) are the source of
  truth for every figure below. Where the `clk_wiz_0.v` header comment
  differs (Vivado auto-solve before a scripted `sed` override: Galaga) or the
  README states a nominal figure (Traverse-USA), the entry says so.
- **VGA/TV rates** are computed from each core's own horizontal/vertical
  scan-counter (`hcnt`/`vcnt`) wrap values, read directly from already-extracted
  pristine `rtl_dar/*.vhd` (or `rtl/*.vhd`) sources on disk, combined with the
  achieved pixel clock. No pristine source was newly extracted for this
  catalog (per task scope); where a machine's source was not already present
  on disk (Zaxxon), no rate was computed and the gap is marked explicitly.
  These are RTL-derived figures, not measurements from real hardware or from
  Vivado timing simulation — treat them as design-intent calculations.
- **Original arcade crystal frequencies** are external research (MAME driver
  source `XTAL(...)` declarations preferred as most authoritative, cross-checked
  against schematic/forum sources where possible). Every figure below is
  cited; "not determined" is used explicitly wherever a reliable source could
  not be found, per hard instruction not to estimate or fabricate.
- This file reflects a point-in-time survey, most recently revised
  2026-10-02 (FPGA-side clocks re-surveyed against the generated
  `clk_wiz_0_clk_wiz.v` and wrappers after the `CLOCKING_SPEC.md`
  retargets; see Change log). Ports are still under active
  development (see `sf-darfpga/README.md` Status section); a future MMCM
  re-solve, patch, or newly-extracted pristine source could shift the
  FPGA-side figures. Re-verify against the generated `clk_wiz_0.v` and each
  machine's own README before relying on this file for hardware bring-up
  decisions.

## Change log (clock retargets)

Decisions: `CLOCKING_SPEC.md` sections 4, 5, 7, 7a. Entries below carry the
current solves (re-surveyed 2026-10-02 against generated
`clk_wiz_0_clk_wiz.v`).

| Date | Machine | Was | Now (D / M / O) |
|---|---|---|---|
| 2026-10-01 | Bagman-FPGA-Dar | 12.000 MHz | 12.288 MHz (5 / 48 / 78.125) |
| 2026-10-01 | Crazy-Kong-by-Dar | 12.000 MHz | 12.288 MHz (5 / 48 / 78.125) |
| 2026-10-01 | Galaga-Midway-by-Dar | 36.000 MHz | 36.863711 MHz (6 / 56.125 / 25.375, `sed`-forced) |
| 2026-10-01 | Xevious-by-Dar | 18.000 + 11.000 MHz | 18.43196 MHz single output (7 / 61.125 / 47.375) |
| 2026-10-01 | Zaxxon-by-Dar | 24.000 MHz | 24.32900 MHz (3 / 35.125 / 48.125) |
| 2026-10-01 | Sky-skipper-by-Dar | 40.000 MHz (1 / 10 / 25) | 40.320 MHz (5 / 31.5 / 15.625) |
| 2026-10-01 | Time-Pilot-by-Dar | 260 lines, V 61.54 Hz | 263 lines, V 60.84 Hz (RTL patch; clock unchanged) |
| 2026-10-01 | Popeye-by-Dar, Sky-skipper-by-Dar | CPU f/8, AY f/16 | CPU f/10, AY f/20 (RTL patch; clock unchanged) |
| 2026-10-02 | Burger-Time-by-Dar | 12.000 + 6.000 MHz (1 / 7.5 / 62.5 / 125) | 12.000 MHz single output (5 / 49.875 / 83.125) |
| 2026-10-02 | Burnin-Rubber-by-Dar | 12.000 + 6.000 MHz (1 / 7.5 / 62.5 / 125) | 12.000 MHz single output (5 / 49.875 / 83.125) |
| 2026-10-02 | Computer-Space-by-Dar | 50 + 6 + 12 MHz (`sed`-forced VCO 600) | 48.000 MHz single output (5 / 49.5 / 20.625); timing met, hardware-confirmed |

---

### Bagman-FPGA-Dar (Bagman — Stern, 1982, per this port's README)

- **FPGA achieved clock**: `clk_out1` = 12.288 MHz, single clock (core,
  video, audio, keyboard all run on it). `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=48.000`, `CLKOUT0_DIVIDE_F=78.125` (VCO 960 MHz). Source:
  generated `clk_wiz_0_clk_wiz.v` (retarget 2026-10-01, was 12.000 MHz).
- **VGA mode**: switch-selectable via `sw(13)` — 0 = 31 kHz progressive VGA
  (scan doubling built into the core via `rtl_dar/line_doubler.vhd`), 1 =
  15 kHz TV (composite sync on HS). Native core scan (from
  `rtl_dar/video_gen.vhd`, `hcnt` 128–511 = 384 px, `vcnt` 248–511 = 264
  lines, pixel enable = `clock_12`/2 = 6.144 MHz): H = 6.144 MHz / 384 =
  16,000 Hz, V = 16,000 / 264 = 60.61 Hz. The core's internal `line_doubler`
  reads at the full 12.288 MHz and doubles the horizontal rate for VGA
  output (32.000 kHz H), preserving the 60.61 Hz frame rate.
- **FPGA AY rate**: `x_pixel(1)` with `I_SEL_L='1'` = 12.288 / 8 =
  1.536 MHz, matching MAME (below). The `bagman.vhd:591` "6 Mhz" comment is
  incorrect.
- **FPGA speech rate**: `clock_1mhz` = `clock_12`/12 = 1.024 MHz
  (`bagman.vhd:165-177`), /2 = 512 kHz (`bagman_speech.vhd:76-81`), /64 =
  8.000 kHz LPC sample rate (`plc10_speech_synthetizer.vhd:231`). Original
  TMS5110 at 640 kHz (user, 2026-10-02): 640 kHz / 80 = 8 kHz. Rates match
  exactly since the 12.288 MHz retarget (7.8125 kHz at 12.000 MHz).
- **Original crystal**: **18.432 MHz**, single crystal on the main PCB.
  Drives the Z80 main CPU at XTAL/3/2 = 3.072 MHz, the video pixel/HCLK at
  XTAL/3 = 6.144 MHz, and the AY-3-8910 sound chip at `BAGMAN_H0 / 2` =
  1.536 MHz (`bagman.cpp:502`; a previous revision of this entry gave
  XTAL/6 = 3.072 MHz, which is the Z80 clock). No
  separate sound-board crystal. Source: MAME `src/mame/valadon/bagman.h`
  (`BAGMAN_MAIN_CLOCK XTAL(18'432'000)`), corroborated by ROM-set/hardware
  comments in `src/mame/valadon/bagman.cpp` ("18.432 MHz crystal").

### Berzerk-FPGA-by-Dar (Berzerk — Stern, 1980)

- **FPGA achieved clock**: `clk_out1` = 10.000 MHz, single clock.
  `DIVCLK_DIVIDE=2`, `CLKFBOUT_MULT_F=15.625`, `CLKOUT0_DIVIDE_F=78.125`.
  Source: README "Solved MMCM" line, confirmed identical in the generated
  `clk_wiz_0.v` header (`clk_out1__10.00000`).
- **VGA mode**: switch-selectable via `sw(13)` — 0 = 31 kHz progressive VGA
  (internal `line_doubler`), 1 = 15 kHz TV (composite sync on HS, VS held
  high). Native core scan (Berzerk's own `rtl_dar/video_gen.vhd` variant:
  `hcnt` total 320 px, `vcnt` total 262 lines per its own comments; pixel
  enable = `clock`/2 = 5 MHz): H = 5 MHz / 320 = 15,625 Hz, V = 15,625 / 262 =
  59.64 Hz. Doubled by the internal line doubler for VGA output to ~31.25 kHz
  H, same ~59.64 Hz frame rate.
- **Original crystal**: **10.000 MHz**, single crystal. Drives the Z80 main
  CPU at XTAL/4 = 2.5 MHz, the pixel clock at XTAL/2 = 5 MHz, and the S14001A
  speech-synthesis chip's base clock at XTAL/4 = 2.5 MHz (the S14001A further
  divides this in software; MAME's driver comment calls this a "placeholder
  clock"). Source: MAME `src/mame/stern/berzerk.cpp`
  (`MASTER_CLOCK (XTAL(10'000'000))`).

### Burger-Time-by-Dar (BurgerTime — Data East, 1982)

- **FPGA achieved clock**: `clk_out1` = 12.000 MHz, single output (core,
  scandoubler `clk_sys`, keyboard). `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=49.875`, `CLKOUT0_DIVIDE_F=83.125` (VCO 997.5 MHz).
  Source: generated `clk_wiz_0_clk_wiz.v` (2026-10-02; was 12.000 + 6.000 MHz,
  1 / 7.5 / 62.5 / 125). The scandoubler's 6 MHz `ce_x1` is a `clock_12`
  toggle in the wrapper (`burger_time_basys3.vhd:127-135`, Defender pattern),
  replacing MMCM `clk_out2`, which failed hold timing as a data enable
  (`CLOCKING_SPEC.md` 5.2, 7a). Rebuild pending.
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler;
  `sw(13)` switches to 15 kHz TV mode. Native core scan
  (`rtl_dar/burger_time.vhd`: `hcnt` 0–383 = 384 px on the `clock_6` = 6 MHz
  enable; H = 6 MHz / 384 = 15,625 Hz). The core's own comment states a
  schematic-intended `vcnt` range of 272 lines (57.44 Hz); the RTL wraps
  `vcnt` at 260 (261 states), V = 15,625 / 261 = 59.87 Hz. Sister core
  Burnin-Rubber briefly carried a 272-line patch, retired 2026-09-28 after it
  caused bottom-row clipping (see that entry); both ports run the pristine
  261-line frame. Scandoubler doubles H for VGA output (31.25 kHz), same
  59.87 Hz frame rate.
- **FPGA main-CPU rate**: pristine `cpu_ena` = `clock_6` with
  `hcnt(2 downto 0)="111"` (`burger_time.vhd:330`) = 750 kHz. MAME
  `btime.cpp:2300` gives `btime` DECO CPU-7 at 12 MHz/8 = 1.5 MHz
  (jumper-selectable H2/H4); `bnj`/`disco` run 750 kHz (`:2399`, `:2454`).
  The port loads `btime.zip`. Patched 2026-10-02 to 1.5 MHz
  (`burger_time_cpu_1p5mhz.patch`, `hcnt(1 downto 0)="11"`); hardware-confirmed (`CLOCKING_SPEC.md` 5.3).
- **Active picture window resolved**: unlike Defender, `hcnt` here directly
  IS the pixel counter (one state per true pixel, not a coarser "character"
  count) — both the `hcnt`/`vcnt` counters and the `hblank`/`vblank`
  assignment process (`burger_time.vhd:618-627`) are gated by the identical
  condition `rising_edge(clock_12) and clock_6='1'`, so there is no
  sub-state/fractional-pixel offset between them. `hblank` sets/clears at
  exact `hcnt` value matches (267/14); `vblank` at exact `vcnt` matches
  (248/8) — confirmed by cycle-by-cycle simulation (2 laps, accounting for
  the one-cycle register delay). Active window: 253 of 384 `hcnt` states ×
  240 of 261 `vcnt` states — the 261-vs-272 line-count question concerns
  only blanking/retrace overhead near the wrap point, not active
  picture. Native
  active resolution: **253×240**, exact (was previously an approximation).
  Doubled for VGA output (real vertical line-doubling, confirmed by reading
  the shared MiST `scandoubler.v` directly — see Pooyan's entry above):
  **253×480**, exact — the 480-line height matches VGA's standard, the
  253px width does not.
- **Original crystal**: **12.000 MHz**, single crystal on the main PCB (no
  separate sound-board crystal — the audio 6502 shares it). Drives the main
  CPU (DECO CPU-7, a customized 6502) at XTAL/8 = 1.5 MHz, the audio M6502 at
  XTAL/2/2/3/2 = 500 kHz, the video pixel clock at XTAL/2 = 6 MHz, and two
  AY-3-8910s at XTAL/8 = 1.5 MHz each. Source: MAME
  `src/mame/dataeast/btime.cpp` `btime()` machine-config block, corroborated
  by an in-file ASCII PCB-layout comment marking "12MHz" at position Z20.1L
  and a note that the CPU-7 epoxy block runs at "1.5MHz [12/8]".

### Burnin-Rubber-by-Dar (Burnin' Rubber / Bump 'n' Jump — Data East, 1982)

- **FPGA achieved clock**: `clk_out1` = 12.000 MHz, single output;
  identical MMCM solve and wrapper structure to Burger-Time (sister core).
  `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=49.875`, `CLKOUT0_DIVIDE_F=83.125`.
  Source: generated `clk_wiz_0_clk_wiz.v` (2026-10-02; was 12.000 + 6.000
  MHz, 1 / 7.5 / 62.5 / 125). Scandoubler 6 MHz `ce_x1` = `clock_12` toggle
  (`burnin_rubber_basys3.vhd:125-133`); keyboard on `clock_12`. Rebuild
  pending.
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler;
  `sw(13)` switches to 15 kHz TV mode. Native core scan
  (`rtl_dar/burnin_rubber.vhd`: `hcnt` 0–383 = 384 px @ 6 MHz pixel enable,
  H = 15,625 Hz). `vcnt` wraps at 260 (pristine, 261 lines,
  `burnin_rubber.vhd:237`), plus
  `contrib/code/burnin_rubber_vsync_before_vblank.patch` (`vsync_cnt` reset
  moved from `vcnt` = 240 to 248, the `vblank` onset). V = 15,625 / 261 =
  59.87 Hz. The 272-line patch (`burnin_rubber_vcnt_272_lines.patch`,
  57.44 Hz) was retired 2026-09-28 after hardware A/B testing showed it
  caused bottom-row clipping; no clipping hardware-confirmed 2026-10-01
  (`CLOCKING_SPEC.md` 5.4, README "Missing bottom horizontal rows").
- **Active picture window**: identical `hblank`/`vblank` threshold values
  (267/14, 248/8), clock-gating and `vcnt` period as Burger-Time — see that
  entry's "Active picture window resolved" note for the full derivation.
  Native active resolution: **253×240**, exact. Doubled for VGA output:
  **253×480**, exact.
- **Original crystal**: **12.000 MHz**, same physical hardware family and
  same MAME driver (`btime.cpp`) `bnj()` machine-config, single crystal.
  Main CPU (DECO C10707, a customized 6502) runs at XTAL/2/2/2/2 = 750 kHz
  (a different divider than BurgerTime's CPU-7); audio CPU (500 kHz), video
  pixel clock (6 MHz), and the two AY-3-8910s (1.5 MHz each) are inherited
  unchanged from the shared `btime()` config. Source: MAME
  `src/mame/dataeast/btime.cpp` `bnj()` machine-config block (covers both the
  `brubber`/Burnin' Rubber and `bnj`/`bnjm` Bump 'n' Jump ROM sets).

### Computer-Space-by-Dar (Computer Space — Nutting Associates, 1971)

- **FPGA achieved clock**: `clk_out1` = 48.000 MHz, single output (core,
  scandoubler `clk_sys`, keyboard, PWM). `DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=49.500`, `CLKOUT0_DIVIDE_F=20.625` (VCO 990 MHz). Source:
  generated `clk_wiz_0_clk_wiz.v` and `clk_wiz_0.v` header
  (`clk_out1__48.00000`), no `sed` override (2026-10-02; timing met, hardware-confirmed).
  The 6 MHz pixel rate (`game_ce`, plus `game_ce_n` half-pixel offset) and
  the 12 MHz scandoubler output rate (`ce_pix2` → `ce_x2`) are clock enables
  from a 3-bit counter in the wrapper (`computer_space_basys3.vhd:178-190`).
  Core constants sized for 50 MHz are rescaled x0.96 by
  `computer_space_single_domain.patch` /
  `computer_space_motion_single_domain.patch`. Design:
  `Computer-Space-by-Dar/contrib/basys3/PORTING_SPEC.md` §Clocking. Previous
  scheme: three outputs 50 / 6 / 12 MHz (`sed`-forced VCO 600, 1 / 6 / 12 /
  100 / 50), retired after routed setup failures on the 50 → 6/12 MHz
  crossings (`CLOCKING_SPEC.md` 5.2, 7a).
- **VGA mode**: 31 kHz progressive VGA via the imported MiST scandoubler;
  `sw(13)` switches to 15 kHz TV mode. Native scan timing comes from a
  gate-level 74161-counter emulation (`rtl/scan_counter.vhd`, credited to
  "Mattias G, 2015" reproducing the original discrete-logic Sync Star Board),
  not the Dar-convention `hcnt`/`vcnt` scanner used elsewhere in this catalog —
  a two-state (`sLINE`/`sSYNC_BLANK`) FSM rather than a simple `hcnt`/`vcnt`
  threshold comparison. Resolved by direct cycle-by-cycle behavioral
  simulation (3 simulated frames to confirm periodicity) rather than by
  inspection: 382 pixel (6 MHz, `game_ce`) periods per line exactly (126
  sync/blank-state cycles + 256 line-state cycles — confirms the figures this
  entry already carried from reading the state machine), `vcount`
  free-running 1–255 (255 lines exactly, confirmed by simulated wrap
  detection). H = 6 MHz / 382 = 15,706.81 Hz, V = H / 255 = 61.60 Hz — no
  longer approximate, though still a design-intent calculation from the RTL,
  not a real-hardware measurement.
- **Active picture window**: simulation-confirmed clean and uniform — every
  one of the 239 visible lines is exactly 256 pixel periods wide (`hblank`
  is asserted for the entire `sSYNC_BLANK` state and deasserted for the
  entire `sLINE` state, so there is no partial-cycle truncation inside the
  active window itself). `vblank` is asserted for `vcount` 240–255 (16 lines)
  and deasserted for `vcount` 1–239 (239 lines) — the `vcount = 255` reload
  quirk noted above only affects the blanking-region `hcount` reload value
  (0 vs. 1), not the active window's length. Native active resolution:
  **256×239**. Doubled for VGA output (same vertical-doubling behavior as
  this catalog's other MiST-scandoubler machines): **256×478**, no standard
  VGA/VESA match.
- **Original crystal**: **not determined**. Computer Space is fully discrete
  TTL logic (no CPU, no ROM); no MAME driver exists for it, so the usual
  `XTAL(...)` cross-check is unavailable. The original schematic set
  documents a master timing crystal on the "sync star board" (reference
  designator CR60/U) that sets overall game/object speed, but no source found
  states its actual frequency. An arcade-preservation forum thread
  (arcade-museum.com forums, "Computer Space - single chip fpga with sound &
  ntsc/pal video out", 2015) about a from-schematics FPGA recreation shows
  the builder explicitly guessing "between 3-6 MHz" and another poster citing
  only the crystal component's manufacturing rating range (5–20 MHz) — not a
  confirmed design value; the thread starter states outright that the exact
  frequency was never established. Do not treat any number here as reliable.
  **Deferred at the user's request (2026-09-29)**: not being pursued further.

### Crazy-Kong-by-Dar (Crazy Kong — Crazy-Climber-derived hardware, Kyoei/Falcon, 1981; per MAME's `cclimber.cpp` driver and Dar's own release notes, the core plays "Crazy Kong Part II / Falcon")

- **FPGA achieved clock**: `clk_out1` = 12.288 MHz, single clock (core,
  video, keyboard). `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=48.000`,
  `CLKOUT0_DIVIDE_F=78.125` (VCO 960 MHz). Source: generated
  `clk_wiz_0_clk_wiz.v` (retarget 2026-10-01, was 12.000 MHz).
- **VGA mode**: `sw(13)` — 0 = 31 kHz progressive VGA (core's own internal
  `line_doubler` drives real `video_hs`/`video_vs`, no imported scandoubler),
  1 = 15 kHz TV. `rtl_dar/video_gen.vhd` is structurally identical to
  Bagman's (`hcnt` 128–511 = 384 px, `vcnt` 248–511 = 264 lines, pixel enable
  = `clock_12`/2 = 6.144 MHz): H = 16,000 Hz native, V = 16,000 / 264 =
  60.61 Hz. Line-doubled for VGA to 32.000 kHz H, same 60.61 Hz frame.
- **Original crystal**: MAME's `ckong`/`ckongpt2` romset family (Kyoei/Falcon,
  1981 — the romset Dar's own `README.txt` names as the ROM source) is driven
  by `src/mame/nichibutsu/cclimber.cpp`'s shared `cclimber` machine config:
  single **18.432 MHz** crystal — `Z80(config, m_maincpu,
  18.432_MHz_XTAL/3/2)` → 3.072 MHz Z80; same crystal drives the sample-based
  audio circuit at ÷12 = 1.536 MHz; no separate sound-board crystal; no
  separate video-clock XTAL found in source. This applies uniformly across
  the whole `ckong`/`ckongpt2` family regardless of specific bootleg variant.
  Corroborated independently by Wikipedia (Crazy Kong runs on modified Crazy
  Climber hardware; official cabinets by Zaccaria). Single-sourced for the
  exact XTAL value (MAME only), not cross-checked against a schematic.

  **Raster discrepancy resolved**: read `~/src/mame/src/mame/nichibutsu/
  cclimber.cpp` directly (outside this repo; read with the user's explicit
  permission). `ckong`'s `GAME()` entry (line 4240) uses machine-config
  `cclimber`, which calls `root(config)` (`cclimber_state::root`,
  lines 2486-2508) and does **not** override its screen setup. `root()` sets
  `m_screen->set_size(32*8, 32*8)` (256×256 — this is MAME's *total* raster
  size) **and** `m_screen->set_visarea(0*8, 32*8-1, 2*8, 30*8-1)` — i.e. an
  *active* window of 256×224 (0-255 horizontally, 16-239 vertically). Every
  `ckong`/`ckongpt2`/`ckongb` variant in the file (`ckongo`, `ckongpt2`,
  `ckongpt2a/j/jeu/ss/b/b2`, `ckongb`) inherits this same `cclimber`/`root`
  config with no per-variant screen override (`ckongb` only adds an NMI-mask
  callback tweak, confirmed by reading its config function directly) — so
  this active window is uniform across the entire family Dar's release notes
  could plausibly target.
  This was **never a genuine hardware-identity conflict** — it was an
  apples-to-oranges comparison in this catalog's earlier research: MAME's
  256×256 *total* raster was being compared against Dar's 384×264 *total*
  `hcnt`/`vcnt` scan-count (which legitimately includes real horizontal/
  vertical blanking overhead, per Dar's own PCB-derived README description),
  rather than against MAME's *active* window. Compared active-to-active:
  Dar's core's own confirmed active resolution is **256×224** (see the
  summary table's `VGA mode` column) — an **exact match** to MAME's
  `set_visarea` for `ckong`/`ckongpt2`. MAME's abstraction for this driver
  simply doesn't model real blanking-porch totals the way Dar's `hcnt`/`vcnt`
  counters do; both sources are correct in their own terms, and Dar's core is
  fully consistent with the genuine `ckong`/`ckongpt2` hardware.

### Defender-by-Dar (Defender — Williams, 1981)

- **FPGA achieved clock**: `clk_out1` = 12.000 MHz exactly (core +
  scandoubler `clk_sys` + keyboard), `clk_out2` = 7.159091 MHz (787.5 / 110).
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=7.875`, `CLKOUT0_DIVIDE_F=65.625`,
  `CLKOUT1_DIVIDE=110` (VCO 787.5 MHz; generated `clk_wiz_0_clk_wiz.v`).
  `clk_out2` is **divided by 2 in fabric** (`defender_basys3.vhd:145-151`)
  to 3.5795454 MHz for the sound board and the PWM audio accumulator; this
  equals the 3.579545 MHz NTSC colorburst crystal (315/88 MHz) to within
  rounding (README corrected 2026-10-02; `CLOCKING_SPEC.md` 7).
- **FPGA main-CPU rate**: pristine `cpu_clock` gives two pulses per 6
  `clock_6` periods; cpu09 advances one bus cycle per `clk` falling edge, so
  the pristine E rate is 2.0 MHz. MAME `williams.cpp:1537`: MC6809E at
  12 MHz/12 = 1.0 MHz E. Dar's source marks the doubling as intentional
  ("speed up processor"); cpu09 also uses fewer cycles per instruction than a
  6809. Patched 2026-10-02 to 1.0 MHz E (`defender_cpu_1mhz.patch`);
  hardware-confirmed (`CLOCKING_SPEC.md` 5.3).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler
  (its 6 MHz `ce_x1` = `clk_out1`/2 in fabric); `sw(13)` switches to 15 kHz
  TV mode. Native core scan (`rtl_dar/defender.vhd`'s own comment, exact at
  the achieved 12.000 MHz core clock): `hcnt` 64×6 = 384 px, H = 15,625 Hz;
  `vcnt` 252–511 = 260 lines, V = 15,625 / 260 = 60.1 Hz (both figures stated
  directly in the core's own header comment and reproduced here). Scandoubler
  doubles H for VGA output to ~31.25 kHz.
- **Active picture window resolved**: `hcnt` is a coarser "character" counter
  (0–63) — the core's own ASCII timing diagram (`defender.vhd:347-348`) shows
  each `hcnt` value spans 6 true pixel_cnt sub-ticks, matching the "64x6=384
  pixels" comment; `hblank`/`vblank` (lines 772-777) are set/cleared on exact
  `hcnt`/`vcnt` value matches (`hcnt`=52/1, `vcnt`=492/262), both processes
  clocked on the same `clock_6n` the counters themselves use — no fractional-
  pixel or sub-state ambiguity (confirmed by cycle-by-cycle simulation,
  2 laps each). Active window: 51 of 64 `hcnt` states (× 6 true pixels/state
  = **306 true pixels**) × 230 of 260 `vcnt` states. Native active resolution:
  **306×230**, exact. Doubled for VGA output (real vertical line-doubling,
  confirmed by reading the shared MiST `scandoubler.v` directly — see
  Pooyan's entry above): **306×460**, exact — no longer approximate, and no
  standard VGA/VESA match.
- **Original crystal**: **12.000 MHz** main/video crystal and a separate
  **3.579545 MHz** (NTSC colorburst) sound crystal — two distinct crystals.
  Main CPU (MC6809E) = 12 MHz ÷3÷4 = 1 MHz; video/pixel clock = 12 MHz ×2/3 =
  8 MHz (same 12 MHz oscillator, not a separate crystal). Sound CPU (M6808,
  on-board audio section) runs on its own 3.579545 MHz XTAL (driver comment:
  "internal clock divider of 4, effective frequency is 894.886kHz"). Source:
  MAME `src/mame/williams/williams.cpp` (`MASTER_CLOCK = XTAL(12'000'000)`,
  `SOUND_CLOCK = XTAL(3'579'545)`). Single-sourced from MAME; an Aussie
  Arcade forum thread on Defender's sound crystal exists as a secondary lead
  but could not be fetched (403) to quote verbatim in this pass.

### Galaga-Midway-by-Dar (Galaga — Namco/Midway, 1981)

- **FPGA achieved clock**: `clk_out1` = 36.863711 MHz, one MMCM output.
  `DIVCLK_DIVIDE=6`, `CLKFBOUT_MULT_F=56.125`, `CLKOUT0_DIVIDE_F=25.375`
  (VCO 935.4167 MHz). Source: generated `clk_wiz_0_clk_wiz.v`, forced by a
  `sed` override in `make_clk_wiz_0.sh`; the `clk_wiz_0.v` header shows
  Vivado's auto-solve (`clk_out1__36.86594`), not the forced value
  (retarget 2026-10-01, was 36.000 MHz).
- **Fabric-derived clocks (not single-clock)**: the core does not run on
  `clk_out1`. The wrapper (`galaga_basys3.vhd`) derives:
  `clock_18` = `clock_36`/2 = 18.431856 MHz toggle (lines 134-143), the
  core clock (`galaga.vhd` port `clock_18`; `ena_vidgen` 2 of 6 slots =
  6.143952 MHz pixel enable); `clock_12` (12.287904 MHz pulse train, 2 of 6
  `clock_36` slots) and `clock_6` (6.143952 MHz toggle) from a mod-6
  counter, used as scandoubler `clk_sys` / `ce_x1` (lines 182-198);
  `clock_9` = `clock_18`/2 = 9.215928 MHz toggle, keyboard decoder clock
  (lines 235-244).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler;
  `sw(13)` = 1 selects 15 kHz TV (composite sync on HS, VS held high), per
  the wrapper (the README does not document it). **Note**: the tree contains a file `rtl_dar/galaga_video.vhd` whose
  entity is literally `phoenix_video` (a leftover, unused copy of Phoenix's
  own video-generator source, header "Phoenix video generator by Dar") — it
  is *not* instantiated by `galaga.vhd`, which actually uses `gen_video`
  (`rtl_dar/gen_video.vhd`) for its real scanner. `gen_video.vhd`: `hcnt`
  128–511 = 384 px, `vcnt` 0–263 = 264 lines (same family as Bagman/Xevious),
  pixel rate 6.143952 MHz (`clock_18` ÷ 3 via `ena_vidgen`). H =
  6.143952 MHz / 384 = 15,999.87 Hz, V = 15,999.87 / 264 = 60.61 Hz.
  Scandoubler doubles H to 32.000 kHz VGA (31.9997), same 60.61 Hz frame.
- **Original crystal**: single **18.432 MHz** crystal for the whole PCB (no
  separate sound-board crystal). Drives all three Z80s (main + two sub-CPUs)
  at XTAL/6 = 3.072 MHz each; video/pixel clock at XTAL/3 = 6.144 MHz; Namco
  WSG sound generator at XTAL/6/32 = 96 kHz; Namco 06XX/51XX/54XX custom I/O
  chips at XTAL/6/2 = 1.536 MHz. Source: MAME `src/mame/namco/galaga.cpp`
  (`#define MASTER_CLOCK (XTAL(18'432'000))`). Single-sourced from MAME (no
  reference designator given in the source comments; not independently
  cross-checked).

### Kick-Midway-MCR-by-Dar (Kick — Midway MCR, 1981; romset `kick.zip`)

- **FPGA achieved clock**: `clk_out1` = 40.000 MHz, single MMCM output.
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`. Source:
  generated `clk_wiz_0_clk_wiz.v`. Keyboard: `clock_kbd` = `clock_40`/6 =
  6.667 MHz, a fabric-derived clock net (toggle every 3 `clock_40` cycles,
  `kick_basys3.vhd:236-251`), not an enable; clocks `io_ps2_keyboard` and `kbd_joystick`.
- **VGA mode**: native 31 kHz progressive (no scandoubler); `sw(13)` selects
  31 kHz VGA (0) / 15 kHz TV (1) -- changed 2026-09-29 from the pristine
  core's F8 keyboard toggle (`tv15Khz_mode <= not fn_toggle(7)`) to match this
  repo's `sw(13)` convention; also fixes the same latent power-on defect
  found on Solar-Fox (`fn_toggle` has no reset in `kbd_joystick.vhd`, so the
  F8-based signal could default to 15 kHz TV mode at power-on). `rtl_dar/kick.vhd` scanner ("Video scanner 634x525
  @20Mhz, display 512x480"): `hcnt` 0–633 = 634, `vcnt` progressive 0–524 =
  525 / TV(interlaced) 0–263 = 264. `pix_ena` progressive = `clock_40`/2 =
  20 MHz, TV = `clock_40`/4 = 10 MHz. **Progressive**: H = 20 MHz / 634 =
  31,545.74 Hz, V = 31,545.74 / 525 = 60.09 Hz. **TV**: H = 10 MHz / 634 =
  15,772.87 Hz, V = 15,772.87 / 264 = 59.75 Hz.
- **Original crystal**: MAME's `kick`/`kickman` sets run on Midway's MCR-1
  "90009 CPU board", driver `src/mame/bally/mcr.cpp` (not `mcr3.cpp`, and
  the driver lives under `bally/`, not `midway/`, per MAME's 2022
  manufacturer-subdir reorg). Main CPU (Z80) crystal: **19.968 MHz**
  (`MAIN_OSC_MCR_I`), ÷8 = 2.496 MHz. Separate sound-board crystal
  ("Midway Super Sound I/O"/SSIO board, its own Z80 + 2× AY-3-8910):
  **16 MHz** (device default clock, no override in this driver's config);
  sound Z80 and both AY-3-8910s run at 16 MHz ÷8 = 2 MHz. No separate
  video-clock crystal identified. Both figures sourced from MAME
  (`src/mame/bally/mcr.h` `MAIN_OSC_MCR_I`, `src/mame/bally/midway_sound.h`
  SSIO default clock); single-sourced, not independently cross-checked
  against a schematic, though independently corroborated within this
  research pass by the same 19.968 MHz/16 MHz pair turning up for
  Satan's Hollow, Solar Fox, and Tron (all same MCR-1 hardware lineage,
  researched separately below).

### Phoenix-by-Dar (Phoenix — Amstar, 1980)

- **FPGA achieved clock**: `clk_out1` = 11.000 MHz (core; pixel clock
  5.5 MHz internally), `clk_out2` = 50.000 MHz (audio effect/music blocks).
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=11.000`, `CLKOUT0_DIVIDE_F=100.000`,
  `CLKOUT1_DIVIDE=22`. Source: README "Solved MMCM" line, confirmed identical
  in the generated `clk_wiz_0.v` header (`clk_out1__11.00000`,
  `clk_out2__50.00000`).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler, fed
  by real hsync/vsync exposed via `phoenix_expose_hsync_vsync.patch` (the
  pristine core otherwise only exposes composite sync); `sw(13)` switches to
  15 kHz TV mode. `rtl_dar/phoenix.vhd` instantiates its own genuine
  `phoenix_video` entity (`hclk_i` toggles every `clk11` cycle → pixel =
  5.5 MHz; `hcnt_i` a 9-bit counter wrapping 160–511 = 352 states; `vcnt_i`
  0–255 = 256 states, clocked once per line). H = 5.5 MHz / 352 = 15,625 Hz
  exactly, V = 15,625 / 256 = 61.035 Hz. Scandoubler doubles H to ~31.25 kHz
  VGA, same ~61.04 Hz frame.
- **Active picture window**: `hblank_bkgrd` (line 171 of `phoenix_video.vhd`) is
  gate-level JK-flip-flop logic (`q1`/`q2`, ports `j1`/`k1`/`j2`/`k2` driven from
  `hcnt_i` bits and `hstb_i`), not a simple threshold — resolved by direct
  behavioral simulation (cycle-by-cycle, 3 laps to reach steady state) rather
  than by inspection. Two distinct horizontal windows exist, one per graphics
  layer (`phoenix.vhd:254-257` gates foreground sprite bits on `hblank_frgrd`,
  background starfield bits on `hblank_bkgrd`):
  - **`hblank_frgrd`** (= `hstb_i`, the source's own comment at line 81 calls
    this "hblank") is the canonical, full-width active window: 256 of 352
    `hcnt_i` states (`0x108`–`0x1FF` then wrapping `0xA0`–`0xA7`), simulation-
    confirmed contiguous once the counter's wraparound is accounted for.
  - **`hblank_bkgrd`** is a narrower, background-layer-only window nested
    inside the foreground window: 239 states (`0x111`–`0x1FF`, no wrap),
    9 states later on the leading edge and missing the 8-state wrapped tail
    entirely — an intentional hardware quirk restricting the starfield's
    horizontal extent relative to sprites, not a bug.
  - Native active resolution (using the canonical `hblank_frgrd` window,
    consistent with how every other machine in this catalog is measured):
    **256×208**. Doubled for VGA output (same vertical-doubling behavior as
    this catalog's other MiST-scandoubler machines): **256×416**, no standard
    VGA/VESA match.
- **Original crystal**: single **11.000 MHz** crystal for the whole board.
  Main CPU (Intel 8085A) and video/pixel clock both run at XTAL/2 = 5.5 MHz
  (same oscillator, not separate crystals). No separate sound crystal —
  Phoenix's sound is generated by a TMS36XX chime and a discrete-logic sound
  device, neither tied to a distinct XTAL in source. Source: MAME
  `src/mame/phoenix/phoenix.h` (`#define MASTER_CLOCK XTAL(11'000'000)`).
  **Caveat**: the driver's own inline comment on the CPU-clock line says
  "// 2.75 MHz", which is inconsistent with both the macro math
  (11 MHz ÷2 = 5.5 MHz) and an identical macro's comment ("// 5.50 MHz")
  used a few lines later for the `survival` variant — this looks like a
  stale/incorrect comment in MAME itself; the 5.5 MHz figure (matching the
  macro math and a separately found, unverified web reference to "8085 CPU
  running at 5.5 MHz") is used here. Single-sourced from MAME; not
  independently cross-checked against a schematic.

### Pooyan-by-Dar (Pooyan — Konami, 1982)

- **FPGA achieved clock (2026-10-05, single domain)**: `clk_out1` =
  `clk_core` = 24.573991 MHz (D 5 / M 34.25 / O0 27.875); 12.287 / 6.1435 MHz
  phases and a 14.318181 MHz phase-accumulator sound enable derived in the
  wrapper (`Pooyan-by-Dar/contrib/basys3/PORTING_SPEC.md` section 2);
  hardware-confirmed 2026-10-05. Previous
  solve, kept below for reference: `clk_out1` = 12.28790 MHz (video-board core
  clock), `clk_out2` = 14.31760 MHz (sound board). `DIVCLK_DIVIDE=7`,
  `CLKFBOUT_MULT_F=56.125`, `CLKOUT0_DIVIDE_F=65.25`, `CLKOUT1_DIVIDE=56`.
  Source: README, confirmed identical in the generated `clk_wiz_0.v` header
  (`clk_out1__12.28790`, `clk_out2__14.31760`) — both are close to but not
  bit-exact with the nominal 12.288/14.318 MHz named in the README prose;
  the achieved figures are what the MMCM actually outputs.
- **VGA mode**: 31 kHz VGA via the DECA `vga_scandoubler`
  (`enable_scandoubling`/`disable_scaneffect` both `1`); the scandoubler's
  15 kHz bypass exists but this port's README notes "15 kHz display is not
  connected; needs a switch wired to enable/disable TV mode" — TV mode isn't
  user-exposed yet in this port. `rtl_dar/pooyan.vhd`: `clock_6` =
  `clk_out1`/2 (achieved ≈6.14395 MHz); `hcnt` 0–47 (48 states × 8 `pxcnt`
  sub-ticks = 384 px total). `vcnt`: the core's own comment gives two
  alternative line counts (260 or 263); reading the actual RTL confirms the
  live reset value is `0x F9` (249), i.e. the **263-line** variant is what's
  implemented (`vcnt` 249–511 = 263 states) — the 260-line alternative in the
  comment is dead/commented-out code. H = 6.14395 MHz / 384 = 15,999.87 Hz
  (~16.000 kHz), V = 15,999.87 / 263 = 60.84 Hz. Scandoubler roughly doubles
  H for the 31 kHz VGA path (~32.0 kHz), same ~60.84 Hz frame.
- **Doubling axis resolved**: read `contrib/basys3/code/vga_scandoubler.v`
  directly (the DECA/"Deca Neptuno board test" import). It is a genuine
  double-buffered line store: the write side (`clkvideo`) captures one native
  scanline per line into a 2-line ping-pong buffer; the read side (`clkvga`,
  running at ~2x `clkvideo`) walks the *same address range* (`totalhor`, the
  captured line's own pixel count) but at twice the clock rate, and — per the
  module's own Spanish comments — when it finishes that address range before
  the source's next `hsync` arrives, it re-reads the same buffer half from
  its origin (`addrvga` low bits reset, high "half" bit unchanged) rather
  than advancing to a new line. Net effect: each captured line is displayed
  **twice** (occupying the same wall-clock time as one native line), with
  the pixel address range — and so the pixel *count* per line — unchanged.
  This is real **vertical** line-doubling (matching every other scandoubler/
  line_doubler family in this catalog), not horizontal pixel-count doubling.
  The design note's "real horizontal doubling" phrasing (elsewhere in this
  port's own docs) refers to the *horizontal scan rate* (Hz) genuinely
  doubling via this buffered double-speed readout — not the image's
  horizontal pixel count increasing; earlier revisions of this catalog
  misread that phrase as width-doubling. Active resolution 256×224 native
  (`rtl_dar/pooyan.vhd:640-646`) → **256×448** doubled, no standard VGA/VESA
  match.
- **Original crystal**: main/video crystal **18.432 MHz** — main CPU (Z80)
  at XTAL/3/2 = 3.072 MHz, video/pixel clock at XTAL/3 = 6.144 MHz (screen
  raw-timing comment: "measured ~60.6 Hz"). Separate sound-board crystal
  **14.31818 MHz** (14,318,181 Hz) — the default clock of the shared
  `TIMEPLT_AUDIO` device (a Time-Pilot-style Z80 + 2× AY-3-8910 sound board),
  instantiated with no override; sound Z80 and both AY-3-8910s run at this
  crystal ÷8 ≈ 1.790 MHz. Source: MAME `src/mame/konami/pooyan.cpp` and
  `src/mame/shared/timeplt_a.h`/`.cpp`. Both figures are common/standard
  values for Konami boards of this era (corroborative, not independent
  confirmation); single-sourced from MAME, not cross-checked against a
  schematic in this pass.

### Popeye-by-Dar (Popeye — Nintendo, 1982; two romsets `popeye.zip` + `popeyeu.zip`)

- **FPGA achieved clock**: `clk_out1` = 40.320 MHz, single MMCM output.
  `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=31.5`, `CLKOUT0_DIVIDE_F=15.625`
  (VCO 630 MHz). Source: generated `clk_wiz_0_clk_wiz.v` (header
  `clk_out1__40.32000`). Keyboard: `clock_kbd` = `clock_40`/6 = 6.72 MHz, a
  fabric-derived clock net (toggle every 3 `clock_40` cycles,
  `popeye_basys3.vhd:189-204`), not an enable; clocks `io_ps2_keyboard` and
  `kbd_joystick`.
- **FPGA CPU/AY rate**: `popeye_clock_cnt2_width.patch` widens `clock_cnt2`
  to 5 bits so the `"10011"` reload fires (pristine 4-bit counter wrapped
  mod 16: CPU f/8, AY f/16, +26%). After the patch: CPU f/10 = 4.032 MHz
  (+0.8% vs 4 MHz), AY f/20 = 2.016 MHz (`CLOCKING_SPEC.md` 5.6).
- **VGA mode**: native 31 kHz progressive (no scandoubler); `sw(13)` selects
  31 kHz VGA / 15 kHz TV (`tv15Khz_mode` port). `rtl_dar/popeye.vhd` scanner
  is the same family as Kick/Satans-Hollow/Solar-Fox/Tron/Sky-Skipper: `hcnt`
  0–639 = 640, `vcnt` progressive 0–525 = 526 / TV 0–262 = 263. `pix_ena`
  progressive = `clock_40`/2 = 20.16 MHz, TV = `clock_40`/4 = 10.08 MHz.
  **Progressive**: H = 20.16 MHz / 640 = **31,500 Hz exactly**, V = 31,500 /
  526 = 59.886 Hz. **TV**: H = 10.08 MHz / 640 = **15,750 Hz exactly**
  (standard NTSC-family rate), V = 15,750 / 263 = 59.886 Hz. The 40.32 MHz
  core clock was evidently chosen specifically to land on these clean
  31.5 kHz / 15.75 kHz figures.
- **Original crystal**: single **8.000 MHz** crystal for the whole board
  (one-PCB design, no separate sound daughterboard). Main CPU (Z80) at
  XTAL/2 = 4 MHz; AY-3-8910 sound chip at XTAL/4 = 2 MHz. No separate
  video-clock crystal found (screen is a fixed `set_refresh_hz(59.94)`, not
  derived from a dedicated XTAL in source). Source: MAME
  `src/mame/nintendo/popeye.cpp` (board code "TNX-1"). Single-sourced from
  MAME, not cross-checked against a schematic in this pass.

### Satans-Hollow-by-Dar (Satan's Hollow — Bally Midway MCR, 1981, per README)

- **FPGA achieved clock**: `clk_out1` = 40.000 MHz, single clock (core,
  keyboard: `io_ps2_keyboard`/`kbd_joystick` on `clock_40`, `satans_hollow_basys3.vhd`).
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`. Source:
  generated `clk_wiz_0_clk_wiz.v`.
- **VGA mode**: native progressive 31 kHz (no scandoubler); `sw(13)` alone
  selects 31 kHz VGA / 15 kHz TV -- changed 2026-09-29 to drop the F8
  keyboard XOR (the pristine core's F8-only default, `not fn_toggle(7)`, was
  never wired here; this port already had `sw(13)` as the base with F8 XORed
  in, so removing the XOR is a pure simplification, not a bug fix -- power-on
  behavior with `sw(13)=0` was already 31 kHz VGA either way).
  `rtl_dar/satans_hollow.vhd` is the same MCR-family scanner as
  Kick/Tron/Solar-Fox ("Video scanner 634x525 @20Mhz"): progressive
  H = 20 MHz / 634 = 31,545.74 Hz, V = 31,545.74 / 525 = 60.09 Hz; TV
  (by the same structural pattern) H = 10 MHz / 634 = 15,772.87 Hz,
  V = 15,772.87 / 264 = 59.75 Hz.
- **Original crystal**: MAME's `shollow`/`shollow2` sets run on Midway's
  MCR-1 "90010 Super CPU board" (driver `src/mame/bally/mcr.cpp`, not
  `mcr3.cpp` — that file covers a different, later MCR-3 game roster). Same
  main-CPU crystal as Kick/Solar-Fox/Tron: **19.968 MHz** (`MAIN_OSC_MCR_I`)
  ÷8 = 2.496 MHz Z80. Same separate sound-board crystal: **16 MHz** (Midway
  SSIO board default, board# 90913; sound Z80 + 2× AY-3-8910 at ÷8 = 2 MHz
  each; an in-source comment corroborates "Starts with a 16MHz oscillator").
  No separate video-clock crystal identified. Single-sourced from MAME;
  independently corroborated within this research pass by the same pair
  turning up for Kick, Solar Fox, and Tron (separately researched).

### Sky-skipper-by-Dar (Sky Skipper — Nintendo, 1981)

- **FPGA achieved clock**: `clk_out1` = 40.320 MHz, single clock (core,
  keyboard: `io_ps2_keyboard`/`kbd_joystick` on `clock_40`,
  `sky_skipper_basys3.vhd`). `DIVCLK_DIVIDE=5`, `CLKFBOUT_MULT_F=31.5`,
  `CLKOUT0_DIVIDE_F=15.625` (VCO 630 MHz). Source: generated
  `clk_wiz_0_clk_wiz.v` (header `clk_out1__40.32000`; retarget 2026-10-01,
  was 40.000 MHz, 1 / 10 / 25; same solve as Popeye).
- **FPGA CPU/AY rate**: `sky_skipper_clock_cnt2_width.patch` widens
  `clock_cnt2` to 5 bits so the `"10011"` reload fires (pristine 4-bit
  counter wrapped mod 16: CPU f/8, AY f/16, +25%). After the patch: CPU
  f/10 = 4.032 MHz (+0.8% vs 4 MHz), AY f/20 = 2.016 MHz
  (`CLOCKING_SPEC.md` 5.6).
- **VGA mode**: native progressive 31 kHz; `sw(13)` alone selects 31 kHz
  VGA / 15 kHz TV -- changed 2026-09-29 to drop the F8 keyboard XOR (this
  port already had `sw(13)` as the base, so removing the XOR is a pure
  simplification, not a bug fix; power-on behavior with `sw(13)=0` was
  already 31 kHz VGA either way). `rtl_dar/sky_skipper.vhd`
  scanner ("Video scanner 640x512 @20Mhz / 640x256 @10Mhz, display 512x448"):
  `hcnt` 0–639 = 640; `vcnt` progressive 0–525 = 526, TV 0–262 = 263.
  `pix_ena` progressive = `clock_40`/2 = 20.16 MHz, TV = `clock_40`/4 =
  10.08 MHz. **Progressive**: H = 20.16 MHz / 640 = 31,500 Hz, V = 31,500 /
  526 = 59.886 Hz. **TV**: H = 10.08 MHz / 640 = 15,750 Hz, V = 15,750 / 263
  = 59.886 Hz (identical to Popeye).
- **Original crystal**: Sky Skipper is **not** a separate MAME driver — it
  lives in `src/mame/nintendo/popeye.cpp`, sharing Popeye's exact single-PCB
  `tnx1_state`/TNX-1 hardware and machine-config. Same figures as Popeye:
  single **8.000 MHz** crystal — main CPU (Z80) at XTAL/2 = 4 MHz, AY-3-8910
  sound at XTAL/4 = 2 MHz, no separate video-clock or sound-board crystal.
  Source: MAME `src/mame/nintendo/popeye.cpp`
  (`GAME(1981, skyskipr, 0, config, skyskipr, tnx1_state, ...)`).
  Single-sourced from MAME, not cross-checked against a schematic.

### Solar-Fox-by-Dar (Solar Fox — Bally Midway, 1981)

- **FPGA achieved clock**: `clk_out1` = 40.000 MHz, single MMCM output.
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.0`, `CLKOUT0_DIVIDE_F=25.0`. Source:
  generated `clk_wiz_0_clk_wiz.v`. Keyboard: `clock_kbd` = `clock_40`/6 =
  6.667 MHz, a fabric-derived clock net (toggle every 3 `clock_40` cycles,
  `solar_fox_basys3.vhd:226-241`), not an enable; clocks `io_ps2_keyboard` and `kbd_joystick`.
- **VGA mode**: native progressive 31 kHz; `sw(13)` selects 31 kHz VGA (0) /
  15 kHz TV (1). **Correction**: this entry previously (incorrectly) stated
  "F8 toggles ... no sw(13) documented" -- direct source inspection
  (2026-09-29) confirms `tv15Khz_mode <= sw(13)` in the wrapper, matching a
  2026-09-28 hardware fix (see `KNOWN_ISSUES.md` -> "Solar-Fox-by-Dar: no
  sync on Sylvania SF150 at power-on"): the original F8-only toggle
  (`not fn_toggle(7)`) had no power-on reset, so the machine could boot into
  15 kHz TV mode and show no sync on some monitors until F8 was pressed once;
  moving to `sw(13)` fixed it. `rtl_dar/solarfox.vhd` is the
  same MCR-family scanner as Kick/Satans-Hollow/Tron: progressive H = 20 MHz
  / 634 = 31,545.74 Hz, V = 31,545.74 / 525 = 60.09 Hz; TV H = 10 MHz / 634 =
  15,772.87 Hz, V = 15,772.87 / 264 = 59.75 Hz (by structural analogy to the
  identical scanner code, not independently re-derived line-by-line).
- **Original crystal**: MAME's `solarfox`/`solarfoxc` sets run on Midway's
  MCR-1 "90009 CPU board" (driver `src/mame/bally/mcr.cpp`, not a standalone
  `solarfox.cpp`). Same crystal pair as Kick/Satan's Hollow: main CPU (Z80)
  **19.968 MHz** (`MAIN_OSC_MCR_I`) ÷8 = 2.496 MHz; sound board (Midway
  SSIO) **16 MHz** default, sound Z80/AY-3-8910s at ÷8 = 2 MHz. No separate
  video-clock crystal identified. Single-sourced from MAME; independently
  corroborated within this pass by the same pair for Kick, Satan's Hollow,
  and Tron. (This research pass did not verify the "licensed from Zaccaria"
  attribution in the task's own game list — not addressed, clocks only.)

### Time-Pilot-by-Dar (Time Pilot — Konami, 1982)

- **FPGA achieved clock (2026-10-05, single domain)**: `clk_core` =
  24.573991 MHz (D 5 / M 34.25 / O0 27.875), same design as Pooyan
  (`Time-Pilot-by-Dar/contrib/basys3/PORTING_SPEC.md` section 2);
  hardware-confirmed 2026-10-05. Previous solve, kept for reference: `clk_out1` = 12.28790 MHz
  (machine core), `clk_out2` = 14.31760 MHz (sound) — identical MMCM solve to
  Pooyan (sister core). `DIVCLK_DIVIDE=7`, `CLKFBOUT_MULT_F=56.125`, `CLKOUT0_DIVIDE_F=65.25`,
  `CLKOUT1_DIVIDE=56`. Source: README, confirmed identical in the generated
  `clk_wiz_0.v` header.
- **VGA mode**: 31 kHz VGA via the DECA `vga_scandoubler` (same as Pooyan);
  README likewise notes "15 kHz display is not connected; needs a switch
  wired to enable/disable TV mode." `rtl_dar/time_pilot.vhd` shares Pooyan's
  `pxcnt`/`hcnt` structure (48 × 8 = 384 px). Pristine `vcnt` reloads to
  `0xFC` (252) at the 0x1FF wrap, 252–511 = 260 states (61.54 Hz).
  `contrib/code/time_pilot_vcnt_263_lines.patch` (2026-10-01,
  `CLOCKING_SPEC.md` 5.7 option D) changes the reload to `0xF9` (249), as
  in Pooyan: 249–511 = **263** states (reset value `0xFC` kept). H =
  6.14395 MHz / 384 = 15,999.87 Hz (~16.000 kHz), V = 15,999.87 / 263 =
  60.84 Hz. Keyboard on the wrapper's `clock_6` toggle (6.14395 MHz).
- **Doubling axis**: same DECA `vga_scandoubler.v` as Pooyan — see that
  entry's "Doubling axis resolved" note for the full derivation. Real
  vertical line-doubling, width unchanged. Active resolution 256×234 native
  (`rtl_dar/time_pilot.vhd:634-642`) → **256×468** doubled, no standard
  VGA/VESA match.
- **Original crystal**: main crystal **18.432 MHz** — main CPU (Z80) at
  XTAL/6 = 3.072 MHz (MAME driver comment flags the /6 divisor itself as
  "not confirmed, but common for Konami games of the era" — the crystal
  value itself is an explicit `XTAL()` literal, high confidence). Separate
  sound-board crystal **14.31818 MHz** (14,318,181 Hz, NTSC colorburst ×4),
  the default clock of the "Time Pilot Audio" device (Z80 + 2× AY-3-8910),
  instantiated with no override; sound CPU and both AY-3-8910s run at ÷8 =
  1.789772 MHz. No separate video crystal (screen uses a fixed
  `set_refresh_hz(60)`). Source: MAME `src/mame/konami/timeplt.cpp` and
  `src/mame/shared/timeplt_a.h`. Single-sourced from MAME, not independently
  cross-checked against a schematic.

### Traverse-USA-by-Dar (Traverse USA / Zippy Race — Irem M-52, 1983)

- **FPGA achieved clock — discrepancy flagged**: README states `clk_out1` =
  36.86 MHz (nominal/requested figure, matching
  `CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {36.86}` in `make_clk_wiz_0.sh`), but
  the generated `clk_wiz_0.v` header shows the true Vivado-solved achieved
  value is **36.84211 MHz**, not 36.86. `clk_out2` achieved 7.15909 MHz
  (requested 7.16), which the wrapper VHDL
  (`contrib/basys3/code/traverse_usa_basys3.vhd`) divides by 2 in fabric
  (`clock_3p58 <= not clock_3p58` toggling on `clock_7p16`) to derive
  `clock_3p58` ≈ 3.58 MHz for the sound board — the same "divide the ~7.16 MHz
  MMCM output by 2 in fabric" pattern Defender uses; the README's top-level
  summary line just doesn't spell out that intermediate step the way
  Defender's does. Use 36.84211 MHz as the true achieved core clock per this
  catalog's stated priority (generated file over README nominal figure).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler
  (`traverse_usa_expose_video_timing.patch` exposes real hs/vs); `sw(13)`
  switches to 15 kHz TV mode. `rtl_dar/traverse_usa.vhd`: `hcnt` 0x80–0x1FF
  (128–511) = 384 px; `vcnt` 0xE6–0x1FF (230–511) = 282 lines. `pix_ena`
  fires twice per a 12-state `clock_cnt` cycle → pixel clock = `clock_36`/6.
  Using the **achieved** `clock_36` = 36.84211 MHz: pixel ≈ 6.140351 MHz,
  H = 6.140351 MHz / 384 = 15,990.5 Hz, V = 15,990.5 / 282 = 56.70 Hz. (The
  core's own comment claims "384/6.144Mhz => 16.000KHz" — a stale figure
  copy-pasted from the Pooyan/Time-Pilot family's comment template; it does
  not match Traverse-USA's actual ~6.14 MHz pixel rate, though the two are
  close enough that the discrepancy is cosmetic, not a functional bug.)
- **Original crystal**: main/video crystal **18.432 MHz** — main CPU (Z80)
  at XTAL/6 = 3.072 MHz, video/pixel clock at the same crystal ÷3 = 6.144 MHz
  (driver comment: "verified from schematics" for the pixel-clock tap).
  Separate sound-board crystal (Irem M52 "Soundc" audio board, Hitachi 6803
  CPU + 2× AY-3-8910 + 2× MSM5205 ADPCM): CPU/AY-3-8910 crystal
  **3.579545 MHz** ("verified on pcb"; AY-3-8910s run at ÷4), plus a
  separate **384 kHz** crystal for the two MSM5205 ADPCM chips ("verified on
  pcb"). Source: MAME `src/mame/irem/travrusa.cpp` and
  `src/mame/irem/irem.cpp` (`m52_soundc_audio_device`). The "verified from
  schematics"/"verified on pcb" comments in MAME's own source give this one
  higher confidence than most other entries in this catalog. Note the FPGA
  port's achieved core clock (36.84211 MHz) is close to 2× this 18.432 MHz
  arcade crystal (36.864 MHz); this repo's own core-clock choice was not
  independently confirmed to be an intentional 2× multiple of the real
  crystal — flagging the numeric proximity only, not asserting a confirmed
  design relationship.

### Tron-by-Dar (Tron — Midway MCR, 1982)

- **FPGA achieved clock**: `clk_out1` = 40.000 MHz, single MMCM output.
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.000`, `CLKOUT0_DIVIDE_F=25.000`.
  Source: generated `clk_wiz_0_clk_wiz.v`. Keyboard: `clock_kbd` =
  `clock_40`/6 = 6.667 MHz, a fabric-derived clock net (toggle every 3
  `clock_40` cycles, `tron_basys3.vhd:239-254`), not an enable; clocks
  `io_ps2_keyboard` and `kbd_joystick`.
- **VGA mode**: dual-mode, generated **natively by the core** (no external
  scandoubler); `sw(13)` selects 31 kHz progressive VGA (0) / 15 kHz TV (1)
  -- changed 2026-09-29 from the pristine core's F8 keyboard toggle
  (`tv15Khz_mode <= not fn_toggle(7)`) to match this repo's `sw(13)`
  convention; also fixes the same latent power-on defect found on Solar-Fox
  (`fn_toggle` has no reset in `kbd_joystick.vhd`, so the F8-based signal
  could default to 15 kHz TV mode at power-on).
  `rtl_dar/tron.vhd` is the same MCR-family scanner as Kick/Satans-Hollow/
  Solar-Fox ("Video scanner 634x525 @20Mhz"). Progressive: H = 20 MHz / 634 =
  31,545.74 Hz, V = 31,545.74 / 525 = 60.09 Hz. TV: H = 10 MHz / 634 =
  15,772.87 Hz, V = 15,772.87 / 264 = 59.75 Hz.
- **Original crystal**: Tron runs on the earlier Midway MCR-1 "Super CPU"
  (90010 board) + "Super Sound I/O" board, driver `src/mame/bally/mcr.cpp`
  (**not** `mcr3.cpp`, which is a distinct, later MCR-3 hardware revision
  with a different game roster). Main CPU (Z80) crystal: **19.968 MHz**
  (`MAIN_OSC_MCR_I`) ÷8 = 2.496 MHz — same figure as Kick/Satan's
  Hollow/Solar Fox (same board family). Separate sound-board crystal:
  **16 MHz** default (Midway SSIO board, boards 90908/90913/91483), sound
  Z80 and both AY-3-8910s at ÷8 = 2 MHz. No separate video-clock crystal
  identified (MCR-1/2 video generator board timing has no distinct `XTAL()`
  in source). Source: MAME `src/mame/bally/mcr.h`/`mcr.cpp`,
  `src/mame/bally/midway_sound.h`. Note: "Discs of Tron" is a different,
  later game/PCB (a raw, non-XTAL 5 MHz literal for its CPU board) — not
  conflated with this figure. Single-sourced from MAME; independently
  corroborated within this pass by the same 19.968 MHz/16 MHz pair for Kick,
  Satan's Hollow, and Solar Fox (researched separately).

### Xevious-by-Dar (Xevious — Namco, 1982)

- **FPGA achieved clock**: `clk_out1` = 18.43196 MHz (18.431964), single
  output: core (pixel rate 6.143988 MHz via `ena_vidgen`), scandoubler
  `clk_sys` and PS/2 keyboard decoder (`xevious_basys3.vhd:276,286`).
  `DIVCLK_DIVIDE=7`, `CLKFBOUT_MULT_F=61.125`, `CLKOUT0_DIVIDE_F=47.375`
  (VCO 873.2143 MHz). Source: generated `clk_wiz_0_clk_wiz.v` (header
  `clk_out1__18.43196`; retarget 2026-10-01). Scandoubler `ce_x1` (6.144 MHz)
  and `ce_x2` (12.288 MHz average) are enables from a mod-3 counter on
  `clock_18` (lines 196-213). Previous solve: 18.000 + 11.000 MHz (11 MHz
  keyboard-only output), both exact; the README statement that exact 18/11
  MHz was unreachable was incorrect (`CLOCKING_SPEC.md` 7).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler, fed
  genuine separate hsync/vsync exposed via
  `xevious_expose_hsync_vsync.patch`; `sw(13)` switches to 15 kHz TV mode.
  `rtl_dar/gen_video.vhd`: `hcnt` 128–511 = 384 px, `vcnt` 0–263 = 264 lines
  (same family as Bagman/Galaga); pixel rate 6.143988 MHz (explicit "clk &
  ena at 6MHz: 1 pixel" comment, core clock ÷ 3). H = 6.143988 MHz / 384 =
  15,999.97 Hz, V = 15,999.97 / 264 = 60.61 Hz. Scandoubler doubles H to
  32.000 kHz VGA, same 60.61 Hz frame.
- **Original crystal**: single **18.432 MHz** master crystal, shared by all
  three Z80 CPUs (main, sub/sprite-motion, sub2/sound-WSG-control) at
  XTAL/6 = 3.072 MHz each, and by the video/pixel clock at XTAL/3 =
  6.144 MHz. Namco WSG sound generator at XTAL/6/32 = 96 kHz; Namco
  50XX/51XX/54XX custom ICs at XTAL/6/2 = 1.536 MHz; Namco 06XX at
  XTAL/6/64. No separate sound-board crystal — all three Z80s including the
  sound-handling one live on the same PCB set sharing this one oscillator.
  Source: MAME `src/mame/namco/xevious.cpp`
  (`#define MASTER_CLOCK (XTAL(18'432'000)) // same as galaga.cpp`).
  Single-sourced from MAME.

### Zaxxon-by-Dar (Zaxxon — Gremlin/Sega, 1980, per README)

- **FPGA achieved clock**: `clk_out1` = 24.32900 MHz (24.329004), single
  MMCM output. `DIVCLK_DIVIDE=3`, `CLKFBOUT_MULT_F=35.125`,
  `CLKOUT0_DIVIDE_F=48.125` (VCO 1170.8333 MHz). Source: generated
  `clk_wiz_0_clk_wiz.v` (present; header `clk_out1__24.32900`; retarget
  2026-10-01, was 24.000 MHz, 5 / 50.25 / 41.875). Keyboard: `clock_kbd` =
  `clock_24`/4 = 6.08225 MHz, a fabric-derived clock net
  (`zaxxon_basys3.vhd:248-261`).
- **VGA mode**: 31 kHz progressive VGA via an imported MiST scandoubler
  (the core's own `pix_clk_div` bits, 12.16450 / 6.08225 MHz square waves,
  feed the scandoubler's `clk_sys`/`ce_x1`, `zaxxon_basys3.vhd:265-266`);
  `sw(13)` switches to 15 kHz TV mode. The core's entity port `clock_24`
  (`rtl_dar/zaxxon.vhd:117`) is assigned to `clock_vid` with no division
  (line 293). `pix_ena` fires when `clock_cnt(1 downto 0) = "01"`
  (line 335), once every 4 `clock_vid` cycles = 6.082251 MHz. `hcnt` wraps
  128–511 = 384 states (line 358), `vcnt` wraps 0–263 = 264 states
  (line 364); same structure as the Bagman/Crazy-Kong/Galaga-Midway/
  Xevious family. H = 6.082251 MHz / 384 = 15,839.20 Hz, V = 15,839.20 / 264
  = 60.00 Hz (59.997). Scandoubler doubles H to 31.678 kHz VGA. The core's
  header comment (`zaxxon.vhd:338-344`, "Video scanner 384x264 @6.083 MHz
  ... 60.00Hz") now agrees with the achieved rate to within 0.01%.
- **Active picture window**: `video_blankn` (`zaxxon.vhd:384-386`) asserts
  active when `(hcnt >= 260 or hcnt < 132) and vcnt >= 17 and vcnt < 240` —
  256 `hcnt` states (260–511 wrapping to 128–131) × 223 `vcnt` states
  (17–239). Matches the core's own header comment ("display 256x224",
  `zaxxon.vhd:340`) almost exactly — 223 vs. 224 is the comment's
  boundary-inclusive rounding, not a calculation error. Native active
  256×223. Doubled for VGA output (real vertical line-doubling, confirmed
  this session by reading the shared MiST `scandoubler.v` directly — see
  Pooyan's entry above for the general finding): **256×446**, no standard
  VGA/VESA match.
- **Original crystal**: single master crystal **48.66 MHz** — an unusual,
  non-catalog crystal value (not a standard off-the-shelf frequency), which
  is itself a signal it was likely measured/read from a schematic rather
  than guessed, though the MAME source carries no explicit "verified"
  comment on this line. Main CPU (Z80) at XTAL/16 ≈ 3.04125 MHz; video/pixel
  clock at XTAL/8 ≈ 6.0825 MHz (same oscillator). **No separate sound CPU or
  sound crystal**: Zaxxon's own machine-config in MAME only adds a
  `SAMPLES` device (standing in for the original discrete/analog sound
  board) — corroborated by PCB-repair/schematic discussion sites
  (mikesarcade.com, coinop.org) describing Zaxxon's sound board as discrete
  analog circuitry, not microprocessor-driven. (MAME's driver does declare a
  separate 4 MHz `SOUND_CLOCK` XTAL and an SN76489A sound config, but that
  applies only to **Congo Bongo**, a different game on the same hardware
  lineage — confirmed by reading the machine-config functions directly; do
  not attribute the 4 MHz figure to Zaxxon.) Source: MAME
  `src/mame/sega/zaxxon.cpp` (`static constexpr XTAL MASTER_CLOCK =
  48.66_MHz_XTAL;`). Single-sourced from MAME for the crystal value itself.

---

## Summary table

Full sourcing, caveats, and discrepancy notes are in each machine's own section above; this
table gives bare figures only. "DE10-lite PLL" is the pristine upstream `max10_pll_*`
ALTPLL requested output(s), always from the DE10-Lite board's 50 MHz oscillator (per-file
confirmed, not assumed) — the frequencies Dar's own DE10-lite top-level specified, before
this repo's Basys3 port re-solved them on `clk_wiz_0`. Divergences between this column and
"FPGA clock(s)" reflect deliberate Basys3-port choices (e.g. an added clock, a combined
single output, or a differently-tapped fabric-divided rate), not defects. "VGA pixel clock"
is the clock actually driving VGA-mode pixel output on the Basys3 board — `clk_sys` fed to
an imported MiST scandoubler, `clkvga` fed to the DECA scandoubler, the internal
`line_doubler`'s read clock, or (for machines with no scandoubler at all — the core generates
progressive video natively) the core's own progressive-mode `pix_ena` rate — read directly
from each machine's wrapper/core source, not derived from the H-rate. "VGA mode" is the
active picture window (visible pixels x visible lines) in VGA mode, isolated from each core's
blanking logic, not the raw hcnt/vcnt total wrap count. Every figure in this column is now
independently confirmed from source (no remaining assumptions): Phoenix's horizontal window,
Computer-Space's active window, and Pooyan/Time-Pilot's doubling axis were all previously
unresolved or assumed and have since been resolved by direct source-reading or behavioral
simulation — see each machine's own section above for the details this uncovered.

| Machine                | DE10-lite PLL (50 MHz in)    | FPGA clock(s)                 | VGA pixel clock           | VGA mode (active px)                               | H-rate    | Frame rate(s)         | Crystal(s)                    |
|------------------------|------------------------------|-------------------------------|---------------------------|----------------------------------------------------|-----------|-----------------------|-------------------------------|
| Bagman-FPGA-Dar        | 12 MHz                       | 12.288 MHz                    | 12.288 MHz                | 256×448 (non-standard)                             | 32.00 kHz | 60.61 Hz              | 18.432 MHz                    |
| Berzerk-FPGA-by-Dar    | 10 MHz                       | 10.000 MHz                    | 10.000 MHz                | 256×448 (non-standard)                             | 31.25 kHz | 59.64 Hz              | 10.000 MHz                    |
| Burger-Time-by-Dar     | 12 MHz                       | 12.000 MHz                    | 12.000 MHz                | 253×480 (480-line matches VGA; width non-standard) | 31.25 kHz | 59.87 Hz (261-line)   | 12.000 MHz                    |
| Burnin-Rubber-by-Dar   | 12 MHz                       | 12.000 MHz                    | 12.000 MHz                | 253×480 (480-line matches VGA; width non-standard) | 31.25 kHz | 59.87 Hz (261-line)   | 12.000 MHz                    |
| Computer-Space-by-Dar  | 6.000 + 5.84 MHz (c0 unused) | 48.000 MHz                    | 12.000 MHz (enable on 48) | 256×478 (non-standard)                             | 31.41 kHz | 61.60 Hz              | not determined                |
| Crazy-Kong-by-Dar      | 12 MHz                       | 12.288 MHz                    | 12.288 MHz                | 256×448 (non-standard)                             | 32.00 kHz | 60.61 Hz              | 18.432 MHz                    |
| Defender-by-Dar        | 12 + 3.58 MHz                | 12.000 + 7.15909 MHz          | 12.000 MHz                | 306×460 (non-standard)                             | 31.25 kHz | 60.1 Hz               | 12.000 + 3.579545 MHz         |
| Galaga-Midway-by-Dar   | 18 + 11 MHz                  | 36.863711 MHz (core 18.43186) | 12.28790 MHz              | 288×448 (non-standard)                             | 32.00 kHz | 60.61 Hz              | 18.432 MHz                    |
| Kick-Midway-MCR-by-Dar | 40 MHz                       | 40.000 MHz                    | 20.000 MHz                | 512×480 (480-line matches VGA; width non-standard) | 31.55 kHz | 60.09 Hz / 59.75 Hz   | 19.968 + 16 MHz               |
| Phoenix-by-Dar         | 11 MHz                       | 11.000 + 50.000 MHz           | 11.000 MHz                | 256×416 (non-standard)                             | 31.25 kHz | 61.04 Hz              | 11.000 MHz                    |
| Pooyan-by-Dar          | 12.288 + 14.318 MHz          | 12.28790 + 14.31760 MHz       | 12.28790 MHz              | 256×448 (non-standard)                             | 32.00 kHz | 60.84 Hz              | 18.432 + 14.31818 MHz         |
| Popeye-by-Dar          | 40.32 MHz                    | 40.320 MHz                    | 20.160 MHz                | 512×448 (non-standard)                             | 31.50 kHz | 59.886 Hz / 59.886 Hz | 8.000 MHz                     |
| Satans-Hollow-by-Dar   | 40 MHz                       | 40.000 MHz                    | 20.000 MHz                | 512×480 (480-line matches VGA; width non-standard) | 31.55 kHz | 60.09 Hz / 59.75 Hz   | 19.968 + 16 MHz               |
| Sky-skipper-by-Dar     | 40 MHz                       | 40.320 MHz                    | 20.160 MHz                | 512×448 (non-standard)                             | 31.50 kHz | 59.886 Hz / 59.886 Hz | 8.000 MHz                     |
| Solar-Fox-by-Dar       | 40 MHz                       | 40.000 MHz                    | 20.000 MHz                | 512×480 (480-line matches VGA; width non-standard) | 31.55 kHz | 60.09 Hz / 59.75 Hz   | 19.968 + 16 MHz               |
| Time-Pilot-by-Dar      | 12.288 + 14.318 MHz          | 12.28790 + 14.31760 MHz       | 12.28790 MHz              | 256×468 (non-standard)                             | 32.00 kHz | 60.84 Hz              | 18.432 + 14.31818 MHz         |
| Traverse-USA-by-Dar    | 36.86 + 3.58 MHz             | 36.84211 + 7.15909 MHz        | 12.28070 MHz              | 240×512 (non-standard)                             | 31.98 kHz | 56.70 Hz              | 18.432 + 3.579545 + 0.384 MHz |
| Tron-by-Dar            | 40 MHz                       | 40.000 MHz                    | 20.000 MHz                | 512×480 (480-line matches VGA; width non-standard) | 31.55 kHz | 60.09 Hz / 59.75 Hz   | 19.968 + 16 MHz               |
| Xevious-by-Dar         | 18 + 11 MHz                  | 18.43196 MHz                  | 18.43196 MHz              | 288×448 (non-standard)                             | 32.00 kHz | 60.61 Hz              | 18.432 MHz                    |
| Zaxxon-by-Dar          | 24 MHz                       | 24.32900 MHz                  | 12.16450 MHz (clock_24/2) | 256×446 (non-standard)                             | 31.68 kHz | 60.00 Hz              | 48.66 MHz                     |

`H-rate` and `Frame rate(s)` are both **VGA-mode** figures only (TV mode's separate H-rate,
where applicable, is covered in each machine's own section above, not repeated here). Where
scandoubling applies, H-rate is the *doubled* figure (real vertical line-doubling reads the
same pixel data out at ~2x rate — see Pooyan's entry above for the general derivation) —
native H-rate is exactly half. A single `Frame rate(s)` value applies to both VGA and TV modes
for that family (doubling only changes H-rate, not V); two values (`VGA / TV`) are given only
where the core generates genuinely separate native timing per mode (no scandoubler at all).
