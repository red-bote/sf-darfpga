# Xevious-by-Dar — Porting spec

Upstream: `vhdl_xevious_de2_de10_lite_2017_05_01.zip` (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), which has an internal top-level folder
(`vhdl_xevious_de2_de10_lite_2017_05_01/`, extracted as `SRC_DIR` per
`setup_xevious.sh`). Project/top entity: `xevious_basys3`. Core clock:
18 MHz (pixel clock 6 MHz = `ena_vidgen`); PS/2 decoder on 11 MHz. Video
path: composite-sync core with genuine separate hsync/vsync exposed by patch —
see "Video path" below.

Port status is tracked in the root `README.md` §Status, not here (per
`.opencode/rules.md` §"Documentation scope (PORTING_SPEC.md)").

## Clocking (`clk_wiz_0`, scripted in `make_clk_wiz_0.sh`)

Single MMCM from the 100 MHz Basys 3 oscillator: `clk_out1` ~18 MHz (core:
`clock_18` into the `xevious` entity), `clk_out2` ~11 MHz (PS/2 keyboard:
`clock_11` into `io_ps2_keyboard`/`kbd_joystick`). Exact integer division of
one VCO for both is impossible (lcm(18,11)=198); e.g. a 1100 MHz VCO gives
18.03 MHz via /61 and 11.0 MHz via /100. `make_clk_wiz_0.sh` requests
`CLKOUT1=18`, `CLKOUT2=11` and records the actual frequencies from the
generated wrapper rather than baking in an M/D guess. `clk_wiz_0` `reset` is
tied to a static `'0'` (`mmcm_reset`); `btnC` resets the core only.

## Video path

### Problem

The `xevious` core (like Galaga's) generates composite sync and exposes it as
`video_csync`; its `video_hs`/`video_vs` ports are commented out in the
pristine entity (`xevious.vhd:140-141`). The pristine DE10-lite top puts
`csync` straight on `vga_hs` and ties `vga_vs` high — 15 kHz TV only. To drive
the imported MiST `scandoubler.v` in 31 kHz VGA mode, genuine separate
hsync/vsync are required (the scandoubler detects hsync on its falling edge
and copies `vs_in` through a register; it does not separate composite sync).

### Chosen approach: expose the core's internal hsync/vsync

`contrib/code/xevious_expose_hsync_vsync.patch` is a single-file patch on
`rtl_dar/xevious.vhd`:

- Realizes the entity's pre-existing commented `video_hs`/`video_vs` ports
  (`xevious.vhd:140-141`).
- Relays them from the `gen_video` instance's already-present `hsync`/`vsync`
  outputs, which the patch re-wires from `open` to `video_hs`/`video_vs`
  (the `gen_video` entity already has real `hsync`/`vsync` output ports
  driven by its `hcntReg`/`vcntReg` counters, `gen_video.vhd:14-15`).

Polarity: `gen_video`'s `hsync` is active-low (pulses low around
`hcntReg=495`), which the scandoubler requires (falling-edge detection);
`vsync` is active-low, used by the scandoubler's `vs_out <= vs_in` register
(vs_out toggles in phase).

### Scandoubler wiring

Component/port-map shape follows Galaga's (`Galaga-Midway-by-Dar/...`); the
mapping for Xevious:

| Port | Connected signal | Note |
|---|---|---|
| `clk_sys` | `clock_18` (18 MHz) | MMCM core clock |
| `ce_x1` | mod-3 enable, ~6 MHz | see clocking below |
| `ce_x2` | mod-3 enable, ~12 MHz avg | see clocking below |
| `scanlines` | `"00"` (literal) | matches fleet convention |
| `hs_in` / `vs_in` | core's `video_hs`/`video_vs`, direct | exposed by patch |
| `r_in`/`g_in`/`b_in` | `video_r & video_r(3 down to 2)` etc. | core outputs 4 bits/channel; pad to `COLOR_DEPTH=6` by MSB replication, gated `when blankn='1' else "000000"` |

Scandoubler enable clocking: the core's pixel clock is 6 MHz (`ena_vidgen`,
asserted on slots "100"/"001" of the 6-slot 18 MHz cycle). A mod-3 counter on
`clock_18` produces `ce_x1` (capture) on slot 0 and `ce_x2` (output) on slots
0 and 1 of every 3-cycle group, giving `ce_x1` ≈ 6 MHz (input pixel rate) and
`ce_x2` ≈ 12 MHz average (2x input, i.e. horizontal line doubling). The line
total (384 effective pixel ticks at 6 MHz) fits the scandoubler's
`HCNT_WIDTH=9` (512).

The `xevious_cpu_gfx_8bits` character/graphics ROM is instantiated in the
wrapper (not the core), clocked on `not clock_18` (asserting edge mid-slot),
matching the DE10 top's `clock_18n` convention.

### Dual-mode output (`sw(13)`, matches the fleet's TV/VGA switch convention)

- `sw(13) = '0'` (VGA, 31 kHz): scandoubler output `vga_r/g/b_o(5 down to 2)`
  on the top's 4-bit channels; `vga_hs <= hsync_o`, `vga_vs <= vsync_o`.
- `sw(13) = '1'` (TV, 15 kHz): native `video_r/g/b` straight out (4-bit),
  `vga_hs <= video_csync`, `vga_vs <= '1'` — exactly reproducing the pristine
  DE10-lite top's behavior.

## Other wiring decisions

- **Reset**: `reset <= btnC` (active-high, matching the DE10 `reset <= not
  key(0)`); `clk_wiz_0` reset static `'0'`.
- **Inputs — JA joystick + keyboard, OR-merged**: unlike Phoenix, the
  `xevious` core exposes discrete input ports (`coin`, `start1`, `start2`,
  `up`, `down`, `left`, `right`, `fire`, `bomb`), so the wrapper OR-merges
  the active-low JA joystick (inverted: `not JA(n)`, Galaga/Defender
  pattern) with the PS/2 keyboard path (`io_ps2_keyboard` -> `kbd_joystick`
  -> `joyBCPPFRLDU(8..0)`). Dedicated buttons add coin/start1/start2.
  JA pin assignment honoring the Makefile's "bomb=JA3":
  `JA[0]=right, JA[1]=left, JA[2]=bomb, JA[3]=up, JA[4]=fire`; `down`
  keyboard-only (the core has no down control).
- **Audio**: reuse the pristine DE10 top's PWM accumulator verbatim
  (`pwm_accumulator <= unsigned('0' & pwm_accumulator(11 downto 0)) +
  unsigned('0' & audio)`, `audio` is 11 bits, out = bit 12) — same pattern
  as every other machine (each reuses its own core's native accumulator
  width rather than a shared implementation).
- **`sw(14)`/`sw(15)`**: `sw(14)` = AMP shutdown/enable, `sw(15)` = AMP gain
  (`O_PMODAMP2_SHUTD`/`O_PMODAMP2_GAIN`), the fleet's sound-enable/AMP-gain
  pair.
- **Dip switches**: `b_test => '1'`, `b_svce => '1'` (like the DE10 top);
  no `sw` mapping for them.
- **Debug hex display**: not ported (no 7-segment wiring on this board) —
  matches every other machine.
- **LEDs**: not ported — matches the fleet.
