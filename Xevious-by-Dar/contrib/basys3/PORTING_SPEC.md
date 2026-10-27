# Xevious-by-Dar — porting spec

Design record for the Basys 3 port. Procedure and conventions:
`../../../PORTING_SPEC.md`. Status: `../../README.md`.

## 1. Upstream and reference model

- Archive `vhdl_xevious_de2_de10_lite_2017_05_01.zip` (darfpga@aol.fr,
  <http://darfpga.blogspot.fr>), internal top folder; SHA-256 in
  `contrib/tools/setup_xevious.sh`; extracted to `vhdl_xevious_de2_de10_lite_2017_05_01/`.
  Core `rtl_dar/xevious.vhd`; DE10 top `rtl_dar/xevious_de10_lite.vhd`.
- MAME driver: `namco/xevious.cpp` (`xevious`).
- Model: Galaga-Midway-by-Dar (same Namco core family, composite-sync core, MiST
  scandoubler).

## 2. Clocking

- Original: 18.432 MHz crystal; pixel 6.144 MHz (`ena_vidgen`), CPUs 3.072 MHz.
- `clk_wiz_0`: request 18.432 MHz, achieved 18.43196 MHz (D 7 / M 61.125 / O 47.375), single
  output, signal `clock_18`; clocks the core, scandoubler, keyboard and PWM.
- Enables: the core derives pixel and CPU enables from `clock_18` (6-slot cycle).
- Video: 384 pixel ticks per line at 6.144 MHz → H 16.000 kHz (31 kHz output 32.000 kHz),
  V 60.61 Hz.
- The `xevious_cpu_gfx_8bits` CPU/graphics ROM is instantiated in the wrapper, clocked on
  `clock_18n <= not clock_18` (a signal, not an expression actual), as the DE10 top's
  `clock_18n`.
- History: until 2026-10-01 the MMCM had 18.000 MHz (core) and 11.000 MHz (keyboard only)
  outputs: VGA 31.25 kHz / 59.19 Hz, -2.34% speed. Revision 2026-10-01
  (`../../../CLOCKING_SPEC.md` sections 4 and 5.2): single output at the original crystal;
  keyboard moved to `clock_18`. The earlier note that exact 18/11 MHz division was
  impossible was wrong (Vivado solved both at VCO 990 MHz).

## 3. Reset

`reset <= btnC or not mmcm_locked`; MMCM reset = `btnC` (2026-10-01,
`../../../CLOCKING_SPEC.md` section 6; previously the MMCM reset was tied `'0'` and the core
reset was `btnC` alone).

## 4. Core instantiation

- `xevious` entity kept; discrete inputs `coin`, `start1`, `start2`, `up`, `down`, `left`,
  `right`, `fire`, `bomb` driven from `joyBCPPFRLDU(8..0)`.
- `video_hs`/`video_vs` added by the expose patch (§5) and fed to the scandoubler.
- `b_test => b_test_in` (signal, §8); `b_svce => '1'` (DE10 value).
- Debug hex display (`dbg_cpu_addr`) and LEDs not ported.

## 5. Video path

- Problem: the core generates composite sync (`video_csync`); its `video_hs`/`video_vs`
  ports are commented out in the pristine entity (`xevious.vhd:140-141`); the DE10 top puts
  csync on `vga_hs` and ties `vga_vs` high (15 kHz TV only). The MiST scandoubler needs
  separate hsync/vsync (it detects hsync on its falling edge and registers `vs_in`).
- Fix: `contrib/code/xevious_expose_hsync_vsync.patch` realizes the commented ports and
  wires them from the `gen_video` instance's existing `hsync`/`vsync` outputs
  (`gen_video.vhd:14-15`, driven by `hcntReg`/`vcntReg`). Both active-low.
- Scandoubler (`contrib/code/scandoubler.v` + `scandoubler_fix.patch`):

  | Port | Signal | Note |
  |---|---|---|
  | `clk_sys` | `clock_18` | core clock |
  | `ce_x1` | mod-3 enable, 6.144 MHz | slot 0 of each 3-cycle group |
  | `ce_x2` | mod-3 enable, 12.288 MHz average | slots 0 and 1 |
  | `scanlines` | `"00"` | |
  | `hs_in` / `vs_in` | core `video_hs` / `video_vs` | direct |
  | `r_in/g_in/b_in` | `video_r & video_r(3 downto 2)` etc. | 4 bits padded to 6 by MSB replication, black when `blankn = '0'` |

  Line total 384 ticks fits `HCNT_WIDTH = 9`.
- sw13: `0` = scandoubler output `(5 downto 2)`, `vga_hs/vs` from the doubler; `1` = native
  4-bit RGB, `vga_hs <= video_csync`, `vga_vs <= '1'` (the DE10 top's path).

## 6. Audio

Dar's PWM accumulator verbatim: `pwm_accumulator <= unsigned('0' &
pwm_accumulator(11 downto 0)) + unsigned('0' & audio)` (`audio` 11 bits), output bit 12 to
`O_PMODAMP2_AIN`. `O_PMODAMP2_SHUTD <= not sw(15)`, `O_PMODAMP2_GAIN <= not sw(14)`.

## 7. Inputs

- Keyboard: `io_ps2_keyboard` on `clock_18`, wrapper decoder (MAME keys, F0 = release, E0
  ignored; `../../../PORTING_SPEC.md` §3.1, §4.3): arrows, Left Ctrl = fire, Left Alt =
  bomb, 1/2 = start, 5/6 = coin (2026-10-20; replaced Dar's `kbd_joystick`, which is no
  longer instantiated).
- Player 2 mirrors player 1.
- Core inputs: active-high discrete ports; fire and bomb are passed to the CPU as levels
  (`xevious.vhd:1240`, `:1250`), so contact bounce is filtered by the game's once-per-frame
  read: no JXADC fire debounce (no double shots on hardware, 2026-10-21; contrast Galaga,
  `../../../Galaga-Midway-by-Dar/contrib/basys3/PORTING_SPEC.md` §7.1).
- Merge (`joyBCPPFRLDU`): JXADC1 right, JXADC2 left, JXADC3 down and bomb (the core uses
  `down`, `xevious.vhd:1218`; JXADC3 added to down 2026-10-01), JXADC4 up, JXADC7 fire;
  coin = keys 5/6, btnU, btnD; start 1 = key 1, btnL; start 2 = key 2, btnR; bomb = Left
  Alt, JXADC3, or JXADC up + fire.
- Synchronizers (2026-10-02): 2-FF `ASYNC_REG` on `ps2_clk`/`ps2_dat`, JXADC(4:0) and
  btnU/btnD/btnL/btnR, on `clock_18`. After the keyboard moved to `clock_18` (2026-10-01),
  keyboard and joystick inputs stuck or were missed: `io_ps2_keyboard` has no synchronizer
  or frame check, so a lost make code is a missed key and a lost F0 a stuck key.
- Debounce (2026-10-02): btnU/btnD/btnL/btnR stable for 2^18 `clock_18` cycles (14.2 ms);
  the core edge-detects coin, so release bounce counted extra coins.
- Combos: JXADC up + fire = bomb (approved 2026-10-20); up and fire pass through.
  Wrapper signals `stick_meta`/`stick_s` carry JXADC.

## 8. Switches and DIPs

| Switch | Core input | Bits | Default (down) | Notes |
|---|---|---|---|---|
| sw12 | `b_test` | 1 | `'1'` (off) | up = test/service mode; `b_test_in <= B_TEST_DEFAULT xor sw(12)`, 2026-10-20 |

Fixed: `b_svce = '1'`. The DIP banks `dip_a = "11111111"` (cabinet, lives, bonus, coin A)
and `dip_b` (freeze, difficulty, coin B) are constants inside `rtl_dar/xevious.vhd:410-411`
(core patch needed; out of scope). sw13 display, sw14 gain, sw15 audio off.

## 9. Patches

| Patch | Target | Reason |
|---|---|---|
| `contrib/code/xevious_expose_hsync_vsync.patch` | `rtl_dar/xevious.vhd` | separate hsync/vsync for the scandoubler (§5) |
| `contrib/code/xevious_synth_fix_xor_spflips.patch` | `rtl_dar/xevious.vhd` | `xor spflips` operand widths differ; Vivado rejects |
| `contrib/code/scandoubler_fix.patch` | project copy of `scandoubler.v` | Vivado (Verilog-2001): block labels for local declarations, `sd_buffer` full range |
| `contrib/basys3/code/xevious_de10_lite_to_basys3.patch` | `rtl_dar/xevious_de10_lite.vhd` | provenance record (generated) |

## 10. PROM generation

`contrib/tools/prep_roms.sh`: compiles `make_vhdl_prom`, rebuilds
`make_xevious_proms.sh` from `make_xevious_proms.bat`, unzips `xevious.zip` (`ROMZIP`)
into `tools/xevious_unzip/roms/` (distinct from the archive's `tools/xevious_unzip_win64/`), renames the 9 color/sound PROMs to Dar's names
(`xvi-8*.6a` → `xvi_8bpr.6a`, ...), generates the PROM VHDL (incl.
`xevious_cpu_gfx_8bits.vhd`). The project references the generated files in place.

## 11. Build

`make` (setup, create_prj, clk_wiz, patch), `make check`, `make bitstream`. Project
`vhdl_xevious_de2_de10_lite_2017_05_01/basys3/xevious_basys3.xpr` (top `xevious_basys3`).
`make check`
shows one pre-existing CRITICAL WARNING HDL 9-3240 (`r2_port_in`,
`rtl_dar/xevious.vhd:1469`, core-internal).

## 12. Open items

None.

