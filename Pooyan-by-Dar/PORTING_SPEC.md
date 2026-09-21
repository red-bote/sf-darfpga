# Pooyan DE10-lite → Basys3 porting spec

This spec summarizes the step-by-step process of transforming Dar's upstream DE10-lite
top level `pooyan_de10_lite.vhd` into the Basys 3 top level `pooyan_basys3.vhd`.

The executable source of truth is
`Pooyan-by-Dar/contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`, which authors the
target, emits the patch, and places the file. This document is that script's human-readable
summary. The concrete result is the tracked diff
`Pooyan-by-Dar/contrib/basys3/code/pooyan_de10_lite_to_basys3.patch`.

- Source: `vhdl_pooyan_rev_0_2_2020_04_26/rtl_dar/pooyan_de10_lite.vhd` (pristine Dar tree)
- Target: `pooyan_basys3.vhd` (written to `basys3/pooyan_basys3/pooyan_basys3.srcs/sources_1/new/`)
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

## 2. Clocking

- Replace the DE10 `max10_pll_12M_14M` (50 MHz in) with the Basys 3 `clk_wiz_0` MMCM
  (100 MHz in → 12.288 MHz core + 14.318 MHz sound board).
- Keep the internal `clock_6` divider (halves `clock_12` → 6.144 MHz) that feeds the PS/2 path.

## 3. Reset polarity

- DE10: `reset <= not reset_n`, with `reset_n = key(0)` (active-low).
- Basys 3: `reset <= btnC` (active-high button).

## 4. Core instantiation

- Keep the `pooyan` port map (r/g/b, csync, blankn, hs, vs, audio_out) unchanged.
- `video_hs`/`video_vs` were `open` on the DE10; they are now wired to `hsync`/`vsync`
  to feed the scandoubler.
- Dip switches: `dip_switch_1 = X"FF"`; `dip_switch_2` maps to `sw(7 downto 0)`
  (was hardcoded `X"7F"` on the DE10).

## 5. Video / scan doubler (31 kHz VGA)

- DECA `vga_scandoubler.v`, canonical cleanroom import, never modified, sourced from
  <https://github.com/DECAfpga/Arcade_Pooyan/blob/main/deca/vga_scandoubler.v>.
- Feed the core's 3+3+2-bit video, zero-extended to 6-bit, into the DECA `vga_scandoubler`
  with `enable_scandoubling`/`disable_scaneffect = 1`; take the 6-bit output down to the
  Basys 3 4-bit-per-color connector (`vga_*o(5 downto 2)`).
- `clkvideo = clock_6`, `clkvga = clock_12` (~2× read ratio for real horizontal doubling).
- RGB is gated on `blankn` (black during blank) **before** the doubler, preserving the DE10
  top's blanking behavior.
- The core's `video_hs`/`video_vs` are **active-low**; they are wired **directly** (no
  inversion) to the doubler's active-low `hsync_ext_n`/`vsync_ext_n`. The doubler re-derives
  active-low `hsync`/`vsync` for the VGA connector.
- Contrast with the DE10's native output: raw `r&'0'`, `g&'0'`, `b&"00"` gated on `blankn`,
  `vga_hs <= csync`, `vga_vs <= '1'`.

## 6. Audio (mono PWM on PmodAMP2)

- Keep the same PWM accumulator clocked on `clock_14`.
- Drive the mono `O_PMODAMP2_AIN` (the DE10 had dual `pwm_audio_out_l/r`).
- `sw14` → `O_PMODAMP2_SHUTD` (sound enable), `sw15` → `O_PMODAMP2_GAIN` (gain select).

## 7. Inputs

- Keep the PS/2 keyboard (`io_ps2_keyboard`) + `kbd_joystick` on `clock_6`.
- OR-merge the JA Atari-style joystick with the keyboard path. JA is active-low (press shorts
  to ground), so it is inverted (`not JA`) to read active-high, matching the core's active-high
  input boundary and the keyboard path.
- JA physical map: `JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire`.
- Coin/start reachable from the joystick via fire+direction combos:
  `coin = fire+up`, `start1 = fire+left`, `start2 = fire+right`.
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
  pixels during blank) — to be confirmed on hardware.
- 15 kHz bypass mode remains not connected. Dip switches 1–8 confirmed working on hardware.