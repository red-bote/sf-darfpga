# Tron DE10-lite → Basys3 porting spec

This spec documents the porting process of Dar's Tron (Midway MCR) hardware to the Digilent
Basys 3, mirroring the reference Pooyan port (`PORTING_SPEC.md`) and the generic workflow
(root `PORTING_SPEC.md`). Unlike Pooyan/Time-Pilot, Tron follows the sibling
Kick-Midway-MCR-by-Dar port's conventions where the two families diverge (single core clock,
no external scandoubler) — both are Midway MCR-1 SSIO-board hardware.

Tron is fully scripted (`contrib/tools/`, `contrib/basys3/vivado/`, `Makefile`:
`setup`/`create_prj`/`clk_wiz`/`patch`/`synth`/`bitstream`). The Vivado project (`.xpr`,
`clk_wiz_0` IP, authored top level) is generated and opens cleanly with the
correct top entity, part, and source list.

- Top entity: `tron_basys3` (target file `sources_1/new/tron_basys3.vhd`)
- Part: `xc7a35tcpg236-1`, VHDL target language
- Sources (per `tron_basys3.xpr`):
  - `rtl_dar/` — `tron.vhd`, `tron_sound_board.vhd`, `ctc_controler.vhd`, `ctc_counter.vhd`,
    `cmos_ram.vhd`, `gen_ram.vhd`, `io_ps2_keyboard.vhd`, `kbd_joystick.vhd`
  - `rtl_t80_304/` — `T80.vhd`, `T80_Pack.vhd`, `T80_ALU.vhd`, `T80_MCode.vhd`, `T80_Reg.vhd`,
    `T80se.vhd` (a distinct T80 revision from both Pooyan's `rtl_t80_350` and Time-Pilot's
    `rtl_T80`)
  - `rtl_mikej/` — `YM2149_linmix_sep.vhd` (same file Time-Pilot uses; two instances, stereo)
  - `clk_wiz_0` MMCM IP, generated PROM VHDL from `tools/tron_unzip/`
  - No scandoubler import — see §5.
  - `decodeur_7_seg.vhd` (DE10-lite hex-display debug decoder) and `tron_de10_lite.vhd`
    (pristine top, patch-diff base only) are **not** project sources — same convention as
    Pooyan/Time-Pilot excluding their pristine tops.

## 1. Port list (DE10-lite → Basys3)

Confirmed against `tron_de10_lite.vhd` and the authored `tron_basys3.vhd`
(`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`):

| Basys 3 port | Function |
|---|---|
| `clk` (W5) | 100 MHz into `clk_wiz_0` MMCM |
| `btnC` | reset (active-high) |
| `sw(15:0)` | see §6 (audio); no dip switches (none on the core — see §7) |
| `ps2_dat` / `ps2_clk` (JB1/JB3) | PS/2 keyboard |
| `JA(4:0)` (JA1-4, JA7) | joystick (active-low); movement/fire/coin/start only — no
  spinner equivalent (see §7) |
| `O_PMODAMP2_AIN/GAIN/SHUTD` (JC1/2/4) | PWM audio (PmodAMP2), left channel only |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, dual-mode (31 kHz VGA / 15 kHz TV) |

## 2. Clocking

- The core uses a **single 40 MHz** clock (core + sound board), derived from the 100 MHz
  Basys 3 oscillator by `clk_wiz_0` — unlike Pooyan/Time-Pilot's dual-clock cores. Matches the
  sibling Kick port's MMCM exactly (same DE10-lite `max10_pll_40M` source IP, confirmed by
  identical header comments carried into both Dar top levels).
- Solved MMCM constants (generated and verified in this environment):
  `DIVCLK_DIVIDE=1`, `CLKFBOUT_MULT_F=10.000`, `CLKOUT0_DIVIDE_F=25.000`; `clk_out1` =
  40.000 MHz. `locked` was left open (as the DE10-lite top); since 2026-10-01 the wrapper uses the
  standard `reset <= btnC or not mmcm_locked` with MMCM reset = btnC (`../../CLOCKING_SPEC.md` section 6).

## 3. Reset polarity

- **Basys 3:** `reset <= btnC` (active-high button), mirroring Pooyan/Time-Pilot/Kick.
- **DE10-lite (confirmed):** `reset_n` aliases the active-low `key(0)`; `reset <= not reset_n`.

## 4. Core instantiation

- Keep the `tron` core port map unchanged (video r/g/b/csync/blankn/hs/vs, dual audio_out_l/r,
  coin/start/movement/fire/angle, cocktail/continue/service, dbg_cpu_addr).
- `tv15Khz_mode` (F8, `fn_toggle(7)`) is a **live core input**, not a synthesis-time constant —
  the core generates true progressive 31 kHz *or* interlaced 15 kHz timing internally depending
  on its value (confirmed in `tron.vhd`'s `hcnt`/`vcnt` generation logic), unlike a scandoubler
  bolted onto a fixed-rate core.
- Cocktail-mode ports (`*_c` suffix) are tied to `'0'`/constants, matching the DE10-lite top
  exactly — the core has no genuine "player 2" port set (only cocktail-mode duplicates), and
  cocktail mode is explicitly unsupported per the archive's own header ("Cocktail mode: NO").
- **T80:** Tron uses `rtl_t80_304`, a third distinct T80 revision (Pooyan uses `rtl_t80_350`,
  Time-Pilot uses `rtl_T80`). Whether this revision needs an equivalent to Pooyan's xor-width
  fix: **not needed** — synthesis completes with no errors (`synth_1/runme.log`, 2026-10-02). Standalone
  VHDL analysis (`xvhdl`) of the full RTL chain (T80-304, YM2149, CTC, cmos_ram/gen_ram,
  keyboard/joystick, `tron`, `tron_sound_board`, and the authored wrapper) against black-box
  PROM stubs completed with **zero errors** — a first signal the core and wrapper are
  structurally sound, but not a substitute for real synthesis.

## 5. Video (dual-mode: 31 kHz VGA / 15 kHz TV, no scandoubler)

- Unlike Pooyan/Time-Pilot, **no external scandoubler is imported**. The core generates its
  own progressive/interlaced timing natively based on `tv15Khz_mode` — same convention as the
  sibling Kick port and the pattern AGENTS.md documents for Popeye/Sky Skipper/Solar Fox
  (`tv15Khz_mode` driven directly, not hardcoded).
- Unlike those other machines, Tron's DE10-lite top wires `tv15Khz_mode` to a **live F8 toggle**
  (`not fn_toggle(7)`) rather than a hardcoded `'0'`, so both video modes are switchable at
  runtime — carried over unchanged into the Basys3 wrapper.
- Output: `vga_r/g/b <= <core color> & '0'` when `blankn='1'` else `"0000"` (3-bit core color
  padded to 4 bits, no doubler-driven narrowing); `vga_hs <= csync when tv15Khz_mode='1' else
  hsync`; `vga_vs <= '1' when tv15Khz_mode='1' else vsync` — verbatim from the DE10-lite top.

## 6. Audio (stereo in the core, mono on PmodAMP2)

- The core outputs **stereo** PWM-ready audio (`audio_out_l`/`audio_out_r`, two independent PWM
  accumulator processes) — unlike Pooyan/Time-Pilot's mono core. PmodAMP2 (JC) is mono, so
  `O_PMODAMP2_AIN` is driven from the **left channel only**; the right-channel accumulator is
  still computed (parity with the DE10-lite top) but unused on Basys3. Same choice as the
  sibling Kick port.
- `sw(15)` → `O_PMODAMP2_GAIN`: gain 0 = 12 dB, 1 = 6 dB
- `sw(14)` → `O_PMODAMP2_SHUTD`: shutdown 0 = off, 1 = on
- `separate_audio` (core input, stereo/mono mix mode) stays wired to `fn_toggle(4)` (F5),
  carried over unchanged from the DE10-lite top.

## 7. Inputs

- PS/2 keyboard on JB (`ps2_dat`/`ps2_clk`) OR-merged with the JA joystick for
  movement/fire/coin/start, same convention as Pooyan/Time-Pilot/Galaga.
- JA joystick, active-low (switch to GND): `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`.
  Invert (`not JA`) to active-high to match the core boundary.
- Coin/start from joystick via fire+direction combos: `coin = fire+up`, `start1 = fire+left`,
  `start2 = fire+right`, OR-merged with the keyboard's F1/F2/F3 (unaffected).
- **Spinner (angle) is keyboard-only, matching the DE10-lite top exactly — this is not a
  functional regression from porting.** The core's `angle`/`angle_c` ports are a 7-bit analog
  rotation value with no discrete-switch equivalent; the DE10-lite top itself only ever drove
  it from a keyboard-simulated counter (`f`=spin left, `g`=spin right, `t`=speed toggle,
  carried over verbatim into the wrapper's `spin_count` process). JA has no analog output to
  offer here, so it is left unconnected to `angle`, same as upstream.
- **No dip switches**: unlike Pooyan/Time-Pilot/Galaga, the `tron` entity exposes no
  `dip_switch_*` ports at all (confirmed against `rtl_dar/tron.vhd`'s port list) — `sw(13:0)`
  is unused/reserved on this port, matching the sibling Kick port (also dip-switch-free).
- `btnC` = reset.

## 8. PROM VHDL generation (required; never distributed)

- Two source zips per the archive's own `README.txt`: `tron.zip` provides the CPU/sound/
  graphics ROMs (`pro0.d2`, `scpu_pg[b-f].d[3-7]`, `ssi_0[a-c].a[7-9]`, `scpu_bg[g,h].g[3,4]`,
  `vga.e1`/`vgb.dc1`/`vgc.cb1`/`vga.a1`); a second archive (nominally `midssio.zip`) provides
  the shared Midway SSIO color PROM `midssio_82s123.12d`.
- **Confirmed: `tron.zip` does not carry the shared Midway color PROM.** Per user
  confirmation, `contrib/tools/prep_roms.sh` pulls `82s123.12d` from `$ROMZIP2` (default
  `~/roms/kick.zip`) instead — the same color PROM the sibling Kick port copies out of its own
  romset — and renames it to `midssio_82s123.12d` (the name `make_tron_proms.bat` expects).
  Verified in this environment: `~/roms/kick.zip` contains `82s123.12d` (32 bytes), and the
  extract-and-rename step produces a correct `midssio_82s123.12d`. `prep_roms.sh` still checks
  `tron.zip` itself first (harmless, in case a future revision changes this) before falling
  back to `$ROMZIP2`, and fails loudly if the PROM is still missing afterward.
- `contrib/tools/prep_roms.sh` compiles `make_vhdl_prom`, converts `make_tron_proms.bat` →
  `.sh`, and runs it to generate: `tron_cpu.vhd`, `tron_sound_cpu.vhd`, `tron_bg_bits_1.vhd`,
  `tron_bg_bits_2.vhd`, `tron_sp_bits.vhd` (merged from `vga.e1`+`vgb.dc1`+`vgc.cb1`+`vga.a1`,
  per rev 03's release note "use merged sprite 8bits roms"), `midssio_82s123.vhd`.
- The `.xpr` references these paths in place (`tools/tron_unzip/*.vhd`) even though they do
  not exist until `make setup` runs with a real `$ROMZIP` — Vivado reports them as missing
  sources until then (confirmed: opening the project today reports exactly these six files
  missing, nothing else).
- Roms and the generated PROM VHDL are copyrighted MAME-derived content — never commit or
  distribute them.

## 9. Build / project setup

- Fully scripted, mirroring Time-Pilot/Kick: `make setup` (`contrib/tools/setup_tron.sh` —
  download/extract, apply synthesis-fix patches if any, rom-prep), `make create_prj`
  (`contrib/basys3/vivado/create_project.sh` — lays down the flat, non-nested project tree:
  `.xpr` directly in `basys3/`), `make clk_wiz` (`contrib/basys3/vivado/make_clk_wiz_0.sh`),
  `make patch` (`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh` — authors
  `tron_basys3.vhd` and its record patch), `make synth` / `make bitstream`
  (`contrib/basys3/tools/make_tron_basys3_bitstream.sh`).
- The tracked `contrib/basys3/vivado/tron_basys3.xpr` was generated (not hand-authored) via a
  one-time Vivado batch Tcl `create_project`/`add_files` pass against the real RTL tree plus
  the real generated `clk_wiz_0` IP and authored top level, with the six not-yet-existing PROM
  VHDL paths declared using temporary black-box placeholder files (deleted afterward) so
  Vivado would record their expected `tools/tron_unzip/*.vhd` paths — the same declarative
  approach every other machine's committed `.xpr` uses, just produced without GUI access.
  Reproduced end-to-end in this environment (`create_project.sh` → `make_clk_wiz_0.sh` →
  `make_de10_lite_to_basys3_patch.sh` → re-open in Vivado) with the expected result: correct
  top/part, 24 sources, only the six ROM-gated PROM files reported missing.
- No scandoubler import step (§5) — `create_project.sh` only stages the `.xpr` and
  `Basys-3-Master.xdc`.
- Run synthesis/implementation from `/tmp` so `vivado.log`/`vivado.jou` stay outside the repo.
  Tool resolution: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`; roms: `ROMZIP` →
  `~/roms/tron.zip`, `ROMZIP2` → `~/roms/kick.zip` (source of the shared `82s123.12d` color
  PROM, §8).
