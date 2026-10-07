# Pooyan DE10-lite → Basys3 porting spec

This spec summarizes the step-by-step process of transforming Dar's upstream DE10-lite
top level `pooyan_de10_lite.vhd` into the Basys 3 top level `pooyan_basys3.vhd`.

The executable source of truth is
`Pooyan-by-Dar/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`, which authors the
target, emits the patch, and places the file. This document is that script's human-readable
summary. The concrete result is the tracked diff
`Pooyan-by-Dar/contrib/basys3/code/pooyan_de10_lite_to_basys3.patch`.

- Source: `vhdl_pooyan_rev_0_2_2020_04_26/rtl_dar/pooyan_de10_lite.vhd` (pristine Dar tree)
- Target: `pooyan_basys3.vhd` (written to `basys3/pooyan_basys3.srcs/sources_1/new/`)
- Nature of the change: a **full rewrite of the wrapper**; the `pooyan` core port map is
  unchanged.

## 1. Port list (DE10-lite → Basys3)

Replace the DE10-lite ports (`max10_clk1_50`, `ledr`, `key`, `sw(9:0)`, `hex0-3`,
`gpio(35:0)`) with the Basys 3 set:

| DE10-lite | Basys 3 |
|---|---|
| `max10_clk1_50` (50 MHz) | `clk` (100 MHz) |
| `key` / `sw(9:0)` | `sw(15:0)`, `btnC` |
| `hex0-3`, `ledr` | (dropped) |
| `gpio` (audio, PS/2) | `ps2_dat`, `ps2_clk`, `O_PMODAMP2_AIN/GAIN/SHUTD`, `JA(4:0)` |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | unchanged (same 4-4-4 RGB + HS/VS) |

## 2. Clocking (single domain, 2026-10-05)

Rule: `.opencode/rules.md` §"Clocking (Basys3 ports)". One MMCM output, `clk_core` =
2 x 12.288 MHz, solved as 24.573991 MHz (D 5 / M 34.25 / O0 27.875, -75 ppm; pixel
6.1435 MHz, VGA H 31.997 kHz), clocks the core, sound board,
scandoubler, keyboard and PWM. Every former clock is a clock enable.

### Previous scheme and why it changed

MMCM `clock_12` (12.2879) + `clock_14` (14.3176), plus register-derived clocks: core
`clock_6`, an independent wrapper `clock_6` (DECA doubler `clkvideo`, keyboard),
`clock_6n`, `clock_12n`, `clock_14n`, sound `cpu_clock` (`clock_div1(2)`) and
`ayx_clock` (`not clock_div1(2)`). Vivado reported these as `no_clock` (1467 pins), so
the core-to-doubler path and the main-to-sound crossing were untimed. Hardware: VGA
failed to sync on about half of the btnC resets (`KNOWN_ISSUES.md`). User decision
2026-10-05: single domain (chosen over a minimal shared-`clock_6` fix for long-term
maintainability; cost: core RTL patch and scandoubler replacement).

### Enables (wrapper, from a 2-bit phase counter `ph` on `clk_core`)

Four `clk_core` edges per 6 MHz period: e0 = former `clock_6` rising (and `clock_12`
rising), e1 = `clock_12` falling, e2 = `clock_12` rising and `clock_6` falling,
e3 = `clock_12` falling. An enable is high in the cycle that ends at its edge.

| Enable | Edge | Replaces |
|---|---|---|
| `ce6` | e0 | `rising_edge(clock_6)`; T80 main CPU `CEN = cpu_ena and ce6` |
| `ce6n` | e2 | `clock_6n` RAM (`wram`, `spram1/2`) |
| `ce12` | e0, e2 | `rising_edge(clock_12)` (line-buffer read, debug) |
| `ce12n` | e1, e3 | `clock_12n` line buffers |
| `clk6_lvl` | level, '1' between e0 and e2 | `clock_6` used as data (line-buffer `we`, read process) |
| `ce14` | phase accumulator, average 14.31818 MHz (ratio 0.58262, jitter 1 cycle = 41 ns) | `rising_edge(clock_14)` |

Sound board: `clock_div1` counts `ce14`; `cpu_ce` = `ce14` and `clock_div1(2 downto 0)
= "011"` (former `cpu_clock` rising), `ay_ce` = `ce14` and `"111"` (former `ayx_clock`
rising); YM2149 `ENA = ay_ce` (port existed, tied to `'1'`); sound `wram` enabled by
`ce14`.

### Memories without enables

- `gen_ram` (`rtl_dar/gen_ram.vhd`, shared by core and sound board) gains
  `ce : in std_logic := '1'` gating write and registered read, so each RAM updates on
  its original edge only.
- Generated PROM entities (`make_vhdl_prom`, registered read, no enable port, not
  tracked): graphics/palette ROMs on former `clock_6` use an address-hold mux
  (`addr` when `ce6`, else the address captured at the last `ce6`), so the registered
  output changes only at e0, as before. CPU program ROMs (main on `clock_6n`, sound
  on `clock_14n`) read every `clk_core` cycle: their consumers (T80) sample only on
  enabled edges with a stable address, so the result is unchanged.

### T80

`T80s` (v350) `CLK = clk_core`. Its NMI edge detect (`T80.vhd:1201`) runs on every
`CLK` edge outside `CEN`; `cpu_nmi_n` changes only at e0 and `NMI_s` is consumed in
CEN-gated logic, so behavior is unchanged.

### Patches

- `contrib/basys3/code/pooyan_single_domain.patch` (CRLF; `setup_pooyan.sh` applies with `--binary`):
  `rtl_dar/pooyan.vhd`, `rtl_dar/pooyan_sound_board.vhd`, `rtl_dar/gen_ram.vhd`.
- `contrib/basys3/code/pooyan_vcnt_264_lines.patch` (2026-10-06, applied after the
  single-domain patch): `vcnt` reload `0x0F9` -> `0x0F8`, 264 lines, V 60.61 Hz (Dar's core:
  263 lines, 60.84 Hz), per MAME `konami/pooyan.cpp`
  `set_raw(18.432_MHz_XTAL / 3, 384, 0, 256, 264, 16, 240)` ("measured ~60.6Hz").
  `../../CLOCKING_SPEC.md` 5.7.

## 3. Reset polarity

- DE10: `reset <= not reset_n`, with `reset_n = key(0)` (active-low).
- Basys 3: `reset <= btnC` (active-high button).

## 4. Core instantiation

- Keep the `pooyan` port map (r/g/b, csync, blankn, hs, vs, audio_out) unchanged.
- `video_hs`/`video_vs` were `open` on the DE10; they are now wired to `hsync`/`vsync`
  to feed the scandoubler.
- Dip switches: `dip_switch_1 = X"FF"`; `dip_switch_2` maps to `sw(7 downto 0)`
  (was hardcoded `X"7F"` on the DE10).

## 5. Video / scan doubler (31 kHz VGA / 15 kHz TV)

- MiST `scandoubler.v` (Till Harbaum, GPL-3.0),
  <https://github.com/DECAfpga/Arcade_Galaga/blob/main/mist/scandoubler.v>, tracked as
  `contrib/code/scandoubler.v` with `contrib/code/scandoubler_fix.patch` (the 9-machine
  fleet copy). Replaces the two-clock DECA `vga_scandoubler.v` (2026-10-05, §2).
- `clk_sys = clk_core`, `ce_x1 = ce6` (6.144 MHz pixel), `ce_x2 = ce12` (exactly 2x).
- Core 3+3+2-bit video zero-extended to 6 bits and gated on `blankn` before the doubler;
  6-bit output reduced to the 4-bit connector (`(5 downto 2)`).
- Core `video_hs`/`video_vs` are active-low and fed directly; the doubler replicates
  hsync at 2x (active-low out) and passes vsync through.
- `sw(13)`: 0 = scandoubler output, 1 = 15 kHz TV (native RGB gated on `blankn`,
  `csync` on HS, VS high), fleet convention.

## 6. Audio (mono PWM on PmodAMP2)

- PWM accumulator on `clk_core`, enabled by `ce14` (same rate as the former `clock_14`).
- Drive the mono `O_PMODAMP2_AIN` (the DE10 had dual `pwm_audio_out_l/r`).
- `sw14` → `O_PMODAMP2_SHUTD` (sound enable), `sw15` → `O_PMODAMP2_GAIN` (gain select).

## 7. Inputs

- PS/2 keyboard (`io_ps2_keyboard`) + `kbd_joystick` on `clk_core`; JA and buttons pass a
  2-FF synchronizer (`ASYNC_REG`).
  PS/2 `ps2_clk`/`ps2_dat` also pass the 2-FF synchronizer. Evaluation 2026-10-05 (user):
  with raw PS/2 at 24.57 MHz the Time-Pilot keyboard misbehaved and Pooyan showed no fault;
  the synchronizer was re-instated on both.
- OR-merge the JA Atari-style joystick with the keyboard path. JA is active-low (press shorts
  to ground), so it is inverted (`not JA`) to read active-high, matching the core's active-high
  input boundary and the keyboard path.
- JA physical map: `JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire`.
- Coin = keyboard OR `btnU`; Start 1 = keyboard OR `btnL`; Start 2 = keyboard OR `btnR`.
  No JA fire+direction combos (removed 2026-10-02).
- P2 controls mirror P1 (`fire2/right2/left2/down2/up2` reuse the P1 signals).

## 8. Patch generation & placement (the automation)

The `make_de10_lite_to_basys3_patch.sh` script does the following (requires the pristine tree,
i.e. `make setup` first; runs from `/tmp` so scratch stays out of the repo):

1. Authors the full target `pooyan_basys3.vhd` (the rewrite described above) into a scratch dir.
2. Diffs it against the pristine upstream source to emit the git-style patch
   `contrib/basys3/code/pooyan_de10_lite_to_basys3.patch` — the tracked record of the change.
3. Copies the target to `sources_1/new/pooyan_basys3.vhd`, where the `.xpr` expects it.

Verify with:

```
patch -p1 --dry-run < contrib/basys3/code/pooyan_de10_lite_to_basys3.patch
```

## 9. Open items

- Whether the `blankn` gating before the doubler is redundant (if the core already emits black
  pixels during blank): untested; blanking is correct on hardware with the gating in place.
- 15 kHz bypass mode: `enable_scandoubling <= not sw(13)`, wired 2026-10-02, hardware-confirmed.
  Dip switches 1–8 confirmed working on hardware.