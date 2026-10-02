# Berzerk DE10-lite → Basys3 porting spec

This spec documents the porting decisions for Dar's Berzerk hardware to the Digilent Basys 3,
mirroring the reference Pooyan port (`PORTING_SPEC.md`) and the closest working precedent,
Bagman-FPGA-Dar (`Bagman-FPGA-Dar/`), which shares Berzerk's internal-line-doubler video path.

`contrib/tools/setup_berzerk.sh` and `contrib/tools/prep_roms.sh` have already run (source tree
extracted, reset-sensitivity patch applied, romset staged, PROM VHDL generated). The
`create_prj`/`clk_wiz`/`patch`/`synth`/`bitstream` chain is being built out per this spec; see
§10 Status.

- Top entity: `berzerk_basys3` (target file `basys3/berzerk_basys3.srcs/sources_1/new/berzerk_basys3.vhd`)
- Part: `xc7a35tcpg236-1`, VHDL target language
- Sources (per `berzerk_basys3.xpr`):
  - `rtl_dar/` — `berzerk.vhd` (reset-sensitivity patched), `berzerk_sound_fx.vhd`,
    `berzerk_speech.vhd`, `gen_ram.vhd`, `io_ps2_keyboard.vhd`, `kbd_joystick.vhd`,
    `line_doubler.vhd` (instantiated inside `berzerk.vhd`, not a project top-level source)
  - `rtl_t80_304/` — `T80se.vhd`, `T80.vhd` (instantiated directly by `T80se.vhd` as `u0 : T80`,
    not by `use` clause — confirmed by a synthesis black-box error the first time it was
    omitted), `T80_Pack.vhd`, `T80_ALU.vhd`, `T80_MCode.vhd`, `T80_Reg.vhd`. `T80_RegX.vhd`
    declares the same `T80_Reg` entity under an alternate architecture and must **not** be
    added alongside `T80_Reg.vhd` (duplicate entity). `T8080se.vhd`, `T80a.vhd`, `T80sed.vhd`
    are unused alternate top-level Z80 variants, not part of this build.
  - `clk_wiz_0` MMCM IP, generated PROM VHDL from `tools/berzerk_unzip/`
    (`berzerk_program1.vhd`, `berzerk_program2.vhd`, `berzerk_speech_rom.vhd`)

No external scandoubler import (unlike Galaga/Burnin' Rubber's `mist/scandoubler.v` or
Pooyan/Time-Pilot's `vga_scandoubler.v`) — `berzerk.vhd` instantiates `rtl_dar/line_doubler.vhd`
internally.

## 1. Port list (DE10-lite → Basys3)

Confirmed against `rtl_dar/berzerk_de10_lite.vhd` (pristine DE10-lite top):

| Basys 3 port | Function |
|---|---|
| `clk` (W5) | 100 MHz into `clk_wiz_0` MMCM |
| `btnC` | reset (active-high) |
| `btnL` / `btnR` | P1 start / P2 start (active-high, §7) |
| `btnU` / `btnD` | coin-in (active-high, either button, §7) |
| `sw(15:0)` | see §5 (video mode) and §6 (audio) |
| `ps2_dat` / `ps2_clk` (JB1/JB3) | PS/2 keyboard |
| `JA(4:0)` (JA1-4, JA7) | joystick (active-low, movement + fire only, §7) |
| `O_PMODAMP2_AIN/GAIN/SHUTD` (JC1/2/4) | PWM audio (PmodAMP2) |
| `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB, 31 kHz VGA / 15 kHz TV (§5) |

Decision (confirmed with user, revises an earlier decision in this same spec): `btnL`, `btnR`,
`btnU`, `btnD` are constrained and used for P1 start, P2 start, and coin-in (either button)
respectively — see §7. This reverses the original minimal-port decision below, which is kept for
context: the pristine top declares `ledr(9:0)` (only bit 0 driven, by `berzerk.vhd`'s `led_on`
signal) and leaves `btnU/L/R/D`-equivalent DE10 `key(1)` unused, and declaring unconstrained
ports on the Basys3 top risks a Vivado placement failure (`Place 30-58`) — moot once the ports
are constrained in the XDC, as they now are. No
`led` ports (still unconstrained, matches Bagman/Pooyan/Time-Pilot).

The pristine top's `sw(9 downto 0)` → core `sw` input and `dbg_cpu_addr`/`dbg_cpu_di` → 7-segment
hex decoder chain is DE10-lite debug-only (hex-display cpu address/data trace, gated by `sw(9)`)
and is not ported — the Basys 3 boards in this repo's other machines carry no 7-segment wiring,
and `berzerk.vhd`'s `sw` input has no dip-switch function.

## 2. Clocking

- Single core clock: **10 MHz**, derived from the 100 MHz Basys 3 oscillator by `clk_wiz_0`.
  Unlike Pooyan/Time-Pilot there is no separate sound clock — `berzerk.vhd` runs the Z80, video,
  and PS/2 logic entirely from `clock_10`.
- `clk_wiz_0` MMCM (100 MHz in), `CLKOUT1_REQUESTED_OUT_FREQ = 10`: solved constants (confirmed
  in the generated `clk_wiz_0_clk_wiz.v`): `DIVCLK_DIVIDE=2`, `CLKFBOUT_MULT_F=15.625`,
  `CLKOUT0_DIVIDE_F=78.125`. Reset active-high (`btnC`), `locked` used.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` — core held in reset while `btnC` is pressed
  or the MMCM has not locked (Bagman pattern). `clk_wiz_0`'s own `reset` port is driven directly
  by `btnC`, not by the combined signal.
- **DE10-lite (pristine):** `reset_n` aliases the active-low `key(0)`; `reset <= not reset_n`.

## 4. Core instantiation

- Keep the `berzerk` core port map (video r/g/b/hi, csync/hs/vs, audio, player inputs) unchanged;
  drop the DE10-lite-only `sw`/`ledr`/`dbg_cpu_*` debug ports (§1).
- `tv15Khz_mode <= sw(13)` (§5) replaces the pristine top's `sw(0)`.
- Entity confirmed (`rtl_dar/berzerk.vhd:72-110`): `video_r/g/b`, `video_hi` are **1-bit each**
  (not pre-expanded to 4 bits) — the 4-bit VGA expansion is done in the top level (§5), not
  inside the core.
- **T80:** Berzerk's `T80se` variant (`rtl_t80_304/`) needs no equivalent of Pooyan's xor-width
  fix: synthesis completes with no errors (`synth_1/runme.log`, 2026-10-01). Only
  `berzerk_reset_sensitivity.patch` is tracked.

## 5. Video (31 kHz VGA / 15 kHz TV, switch-selectable)

Decision (confirmed with user, mirrors Bagman rather than this port's earlier VGA-only README
draft): `sw(13)` selects between 15 kHz TV (composite sync) and 31 kHz progressive VGA at
runtime, matching Bagman's convention.

- `berzerk.vhd` doubles/passes-through scanlines internally via `rtl_dar/line_doubler.vhd`,
  muxed on `tv15Khz_mode` (`berzerk.vhd:270`: `video_s <= video_o when tv15Khz_mode = '0' else
  video_i`) — no external scandoubler import needed.
- Core outputs raw 1-bit `video_r`/`video_g`/`video_b` + `video_hi` (intensity bit). The Basys3
  wrapper must reproduce the pristine top's 4-bit expansion verbatim
  (`berzerk_de10_lite.vhd:212-222`):
  ```vhdl
  video_r <= "1100" when r = '1' and hi = '1' else
             "0100" when r = '1' and hi = '0' else
             "0000";
  -- same pattern for video_g (g), video_b (b)
  ```
  (`blankn` is hardcoded `'1'` in the pristine top — the core exposes no blank output; carried
  over unchanged, not a defect.)
- Sync mux (Bagman pattern, using the core's own `video_csync`/`video_hs`/`video_vs` outputs):
  ```vhdl
  vga_hs <= csync when sw(13) = '1' else hsync;
  vga_vs <= '1'   when sw(13) = '1' else vsync;
  ```

## 6. Audio (mono PWM on PmodAMP2)

- 13-bit PWM accumulator at `clock_10`, reproducing the pristine top's exact slice
  (`berzerk_de10_lite.vhd:366-374`):
  ```vhdl
  process(clock_10)
  begin
    if rising_edge(clock_10) then
      pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0))
                        + unsigned('0' & audio(15 downto 4)));
    end if;
  end process;
  O_PMODAMP2_AIN <= pwm_accumulator(12);
  ```
- `sw(15)` → `O_PMODAMP2_GAIN`: gain 0 = 12 dB, 1 = 6 dB.
- `sw(14)` → `O_PMODAMP2_SHUTD`: shutdown 0 = off, 1 = on.

## 7. Inputs

- PS/2 keyboard (`io_ps2_keyboard`) + joystick translation (`kbd_joystick`), both clocked at
  `clock_10` (pristine top's clocking — single clock domain, no separate PS/2 clock divider).
  `kbd_joystick.vhd`'s exact port names/widths must be confirmed against
  `rtl_dar/kbd_joystick.vhd` at authoring time — do not assume they match Bagman's interface;
  Dar's per-project `kbd_joystick` variants differ (e.g., the Somhi/DECAfpga Galaga fork
  diverged from Dar's own interface).
- Pristine top's `joyHBCPPFRLDU(9 downto 0)` index mapping to reproduce
  (`berzerk_de10_lite.vhd:183-198`): `(0)=up, (1)=down, (2)=left, (3)=right, (4)=fire,
  (5)=start1, (6)=start2, (7)=coin1`. Player 2 mirrors player 1 (same indices wired to both
  `right2/left2/down2/up2/fire2` and the P1 ports).
- JA joystick (active-low, switch to GND): `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`.
  Invert (`not JA`) to active-high to match the core boundary; OR-merge with the keyboard path
  (Bagman/Pooyan pattern). Movement + fire only — no coin/start combos on this port (revises the
  original fire+direction-combo decision below, at the user's request).
- Coin/start (confirmed with user, supersedes the original fire+direction-combo decision):
  dedicated buttons, OR-merged with the keyboard path (F1/F2/F3), not reachable from the
  joystick. `joy_start1 <= kbd_joy(5) or btnL`, `joy_start2 <= kbd_joy(6) or btnR`,
  `joy_coin <= kbd_joy(7) or btnU or btnD`. Buttons are active-high, no inversion (Basys3 board
  pull-down, same convention as `btnC`).
- `btnC` = reset (§3).

## 8. Patches

- `contrib/code/berzerk_reset_sensitivity.patch` — already applied during `make setup`. Adds
  `reset` to the sensitivity list of the process at `berzerk.vhd:330` (pristine core omitted it).
- `contrib/basys3/code/berzerk_de10_lite_to_basys3.patch` — to be generated by
  `make_de10_lite_to_basys3_patch.sh`; diffs `berzerk_de10_lite.vhd` (stale DE10-lite top, kept
  only as diff base) against the authored `berzerk_basys3.vhd`. Applied to the checked-in copy
  during `make patch` (not `make setup`).

## 9. PROM VHDL generation (required; never distributed)

- Romset `berzerk.zip` unzipped into `tools/berzerk_unzip/`, renamed to Dar's expected names
  (see README's rename table), then `contrib/tools/prep_roms.sh` compiles `make_vhdl_prom`,
  converts `make_berzerk_proms.bat` → `.sh`, and runs it to generate the PROM VHDL:
  `berzerk_program1.vhd`, `berzerk_program2.vhd`, `berzerk_speech_rom.vhd`. Already run; the
  `.xpr` references these in place.
- Roms and generated PROM VHDL are copyrighted MAME-derived content — never commit or
  distribute them.

## 10. Build / project setup

Fully scripted, mirroring Bagman:

- `make setup` (`contrib/tools/setup_berzerk.sh` — download/extract, apply
  `berzerk_reset_sensitivity.patch`, rom-prep). **Done.**
- `make create_prj` (`contrib/basys3/vivado/create_project.sh` — present;
  copies `berzerk_basys3.xpr` + `Basys-3-Master.xdc` into the non-nested `basys3/` tree). The
  `.xpr`/`.xdc` pair lives under `contrib/basys3/vivado/` (§1-§7 above).
- `make clk_wiz` (`contrib/basys3/tools/make_clk_wiz_0.sh`, Vivado-batch MMCM IP generation,
  10 MHz target).
- `make patch` (`contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh` — authors
  `berzerk_basys3.vhd` and its record patch, §8).
- `make synth` / `make bitstream`
  (`contrib/basys3/tools/make_berzerk_basys3_bitstream.sh`).
- Run synthesis/implementation from `/tmp` so `vivado.log`/`vivado.jou` stay outside the repo.
  Tool resolution: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`; roms: `ROMZIP` →
  `~/roms/berzerk.zip`.

