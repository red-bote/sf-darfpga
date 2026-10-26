# Tron-by-Dar: porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_tron_rev_0_3_2019_11_22.zip` (SourceForge `darfpga/files/Software
  VHDL/tron/`), SHA-256 in `contrib/tools/setup_tron.sh`; extracted to
  `vhdl_tron_rev_0_3_2019_11_22/`. Core `rtl_dar/tron.vhd`; DE10 top `tron_de10_lite.vhd`
  (patch base only; `decodeur_7_seg.vhd` not a project source).
- Project sources (`tron_basys3.xpr`): `rtl_dar/` `tron.vhd`, `tron_sound_board.vhd`,
  `ctc_controler.vhd`, `ctc_counter.vhd`, `cmos_ram.vhd`, `gen_ram.vhd`,
  `io_ps2_keyboard.vhd`, `kbd_joystick.vhd` (unreferenced); `rtl_t80_304/` (T80 revision
  distinct from Pooyan's `rtl_t80_350` and Time-Pilot's `rtl_T80`; no xor-width fix needed,
  synthesis clean 2026-10-02); `rtl_mikej/YM2149_linmix_sep.vhd` (two instances, stereo);
  `clk_wiz_0`; the six generated PROM files.
- MAME driver: `bally/mcr.cpp` (`tron`), MCR-1 + SSIO.
- Top entity `tron_basys3`; part `xc7a35tcpg236-1`.
- Closest existing port used as model: Kick-Midway-MCR-by-Dar (same MCR family, same
  `max10_pll_40M` source PLL).

## 2. Clocking

- Original: main Z80 19.968 MHz crystal /8 = 2.496 MHz; SSIO 16 MHz.
- `clk_wiz_0`: request 40.000 MHz, achieved 40.000 MHz (1 / 10.000 / 25.000); signal
  `clock_40`, one domain for core and sound board. Main CPU +0.16% vs 19.968 MHz (39.9356 MHz
  retune skipped, user 2026-10-01).
- Enables: inside Dar's core; `clock_div` gates the PWM accumulators.
- Video (MCR scanner 634 x 525): progressive H = 31.546 kHz, V = 60.09 Hz; TV H =
  15.773 kHz, V = 59.75 Hz.

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC` (2026-10-01,
`../../../CLOCKING_SPEC.md` section 6; the DE10 top left `locked` open and used
`reset <= not key(0)`).

## 4. Core instantiation

- Dar's `tron` port map kept (video r/g/b/csync/blankn/hs/vs, `audio_out_l/r`,
  coin/start/movement/fire/angle, cocktail/continue/service, `dbg_cpu_addr`). Inputs through
  signals (no expression actuals).
- Cocktail-mode ports (`*_c`) tied off as in the DE10 top; `angle_c => "0000000"`. The
  archive header states "Cocktail mode: NO".
- `angle => spin_count(9 downto 3)`: the spinner counter process copied from the DE10 top,
  driven by keys (§7).
- `separate_audio => '0'`; `service` (F2) and `continue` (F6) from wrapper toggles;
  `cocktail` and `coin_meters` from the DIP signals (§8).

## 5. Video path

No external scandoubler: the core generates progressive 31 kHz or interlaced 15 kHz timing
from `tv15Khz_mode` (`tron.vhd` `hcnt`/`vcnt`). `tv15Khz_mode <= sw(13)` (2026-09-29;
pristine `not fn_toggle(7)`, the F8 key). Output copied from the DE10 top:
`vga_r/g/b <= color & '0'` when `blankn = '1'` else `"0000"`; `vga_hs <= csync` and
`vga_vs <= '1'` when `tv15Khz_mode = '1'`, else `hsync` / `vsync`.

## 6. Audio

Stereo core (`audio_out_l/r`), two 18-bit accumulators on `clock_40` (parity with the DE10
top); `O_PMODAMP2_AIN <= pwm_accumulator_l(17)` (left channel, as Kick).
`separate_audio => '0'` (mixed, 2026-10-20; was `fn_toggle(4)` (F5), which on the mono amp
would drop right-channel sounds). `SHUTD <= not sw(15)`, `GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_40`, wrapper decoder (MAME keys, MAME driver
  `tron`, `../../../PORTING_SPEC.md` §3.1, §4.3), replaces `kbd_joystick` (2026-10-20;
  `kbd_joystick.vhd` stays in the project, unreferenced). Arrows = 8-way move, Left Ctrl =
  fire, Z / X = spin left / right, Left Alt = spin faster (held), 1/2 = start, 5/6 = coin
  1/2, F2 = service toggle, F6 = continue toggle (Dar's F6 kept; toggles flip on press).
- Spinner: `angle` is a 7-bit rotation value with no discrete-switch equivalent. Dar's top
  drives it from a key-simulated counter (Dar keys `f` left, `g` right, `t` faster; here
  Z / X / Left Alt, `spin_count` process). JXADC has no analog output, so `angle` is
  keyboard-only, as upstream.
- JXADC (active-low, inverted): JXADC1/2/3/4 = right/left/down/up, JXADC7 = fire.
- Buttons: btnU = coin 1, btnD = coin 2, btnL/btnR = start 1/2, OR-merged with the keys.
- Synchronizers: 2-FF `ASYNC_REG` on PS/2, JXADC, buttons, on `clock_40`. The former
  `clock_40`/6 fabric clock `clock_kbd` (`clock_div_kbd`) is removed (one clock domain).
- Debounce: none. Combos: none.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `cocktail` | 1 | `'0'` (Dar) | `COCKTAIL_DEFAULT xor sw(12)` (2026-10-20, §3.2); cocktail not supported per Dar's top |
| sw11 | `coin_meters` | 1 | `'1'` (Dar) | `COIN_METERS_DEFAULT xor sw(11)` |
| sw13 | `tv15Khz_mode` | | 31 kHz VGA | up = 15 kHz TV |
| sw14 / sw15 | PmodAMP2 GAIN / SHUTD | | gain low / audio on | |

No `dip_switch_*` ports in the `tron` entity; settings via the service menu. sw10-0 spare.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/basys3/code/tron_de10_lite_to_basys3.patch` | DE10 top | provenance record (generated) |

No fix patches to Dar's core.

## 10. PROM generation

`contrib/tools/prep_roms.sh`: `make_tron_proms.bat` → shell. `tron.zip` (`ROMZIP`) provides
CPU, sound and graphics ROMs (`pro0.d2`, `scpu_pg[b-f].d[3-7]`, `ssi_0[a-c].a[7-9]`,
`scpu_bg[g,h].g[3,4]`, `vga.e1`/`vgb.dc1`/`vgc.cb1`/`vga.a1`). It lacks the Midway SSIO
PROM: `prep_roms.sh` checks `tron.zip` first, then extracts `82s123.12d` from `ROMZIP2`
(default `~/roms/midssio.zip`) and renames it `midssio_82s123.12d`; it fails if still
missing. Output: `tron_cpu.vhd`, `tron_sound_cpu.vhd`, `tron_bg_bits_1.vhd`,
`tron_bg_bits_2.vhd`, `tron_sp_bits.vhd` (merged sprite ROMs, rev 03), `midssio_82s123.vhd`.
Until `make setup` runs, Vivado reports exactly these six files missing.

## 11. Build

`make` (setup, project, clk_wiz, patch), `make check`, `make bitstream`. The `.xpr` lives
at `vhdl_tron_rev_0_3_2019_11_22/basys3/tron_basys3.xpr`. The tracked `.xpr` was created by
a one-time batch `create_project`/`add_files` run against the real tree, with placeholder
files for the six PROM paths (removed afterwards). `create_project.sh` stages only the
`.xpr` and XDC (no scandoubler).

## 12. Open items

- Optional JXADC approximation of the spinner.
- Core-internal HDL 9-3240 at `rtl_dar/tron.vhd:945` (pre-existing; left as is, user
  decision pending).
