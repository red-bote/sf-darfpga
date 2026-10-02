# Phoenix-by-Dar — Porting spec

Upstream: `vhdl_phoenix_DE10_lite.zip` (darfpga@aol.fr,
<http://darfpga.blogspot.fr>), no internal top-level folder (extracted
directly as `SRC_DIR`, per `setup_phoenix.sh`). Project/top entity:
`phoenix_basys3`. Core clock: 11 MHz (pixel clock 5.5 MHz = `clk11`
internally divided by 2). Video path: composite-sync-only core, no native
VGA/scandoubled output — see "Video path" below.

Port status is tracked in the root `README.md` §Status, not here (per
`.opencode/rules.md` §"Documentation scope (PORTING_SPEC.md)").

## Clocking (`clk_wiz_0`, already scripted in `make_clk_wiz_0.sh`)

Single MMCM, VCO 1100 MHz: `clk_out1` = 11 MHz (core: `clock_11` in to the
`phoenix` entity), `clk_out2` = 50 MHz (audio: `clock_50` in — the pristine
DE10 top feeds the raw 50 MHz board oscillator directly to this port; the
`phoenix_effect1/2/3`/`phoenix_music` blocks divide it internally to 10 MHz,
so the Basys3 wrapper reuses the MMCM's synthesized 50 MHz output for the
same purpose instead of a second board oscillator).

## Video path

### Problem

`phoenix_video.vhd` (the core's video generator) implements RS-170-style
composite sync directly — pre-equalizing pulses, vsync serration, and
post-equalizing pulses, each timed off the internal `hcnt`/`vcnt` counters
(`sync <=` combinational mux at `phoenix_video.vhd:200+`) — and exposes only
that single composite signal as `sync` (forwarded to the `phoenix` entity's
`video_csync` port). **No separate hsync/vsync exist anywhere in the
pristine design**; `video_hs`/`video_vs` are commented out both at the
`phoenix` entity (`phoenix.vhd:26-27`) and the DE10-lite top
(`phoenix_de10_lite.vhd`). This matches the upstream `README.txt`: "TV mode
only RBG 15kHz" — Dar never implemented VGA output for this core. The DE10
top puts `csync` directly on `vga_hs` with `vga_vs` tied high (composite
sync riding the HS line, matching this project's own "TV mode" convention
for other machines).

The already-staged MiST `scandoubler.v` requires genuine separate `hs_in`/
`vs_in` (confirmed in-module: `vs_out` is a bare registered copy of `vs_in`,
`hs_in` edges drive the internal line-length/doubling counters — it does not
separate composite sync itself). Feeding it composite sync directly would
leave `vs_out` static (never toggling), so it cannot be wired as-is.

### Chosen approach: patch the core to expose real hsync/vsync

A first implementation attempt authored a duration-threshold sync separator
in `phoenix_basys3.vhd` (no pristine-file changes), inferring `hs`/`vs`
edges from `video_csync`. Superseded by `contrib/code/phoenix_expose_hsync_vsync.patch`,
a single two-file patch exposing real, separately-generated hsync/vsync
from signals the core already computes internally — no threshold-guessing:

- **`rtl_dar/phoenix_video.vhd`**: adds `hsync`/`vsync` output ports,
  assigned `hsync <= pulse_a; vsync <= vblank_n;`. `pulse_a` is the file's
  existing per-line active-low sync pulse (`hcnt_i = 0xBF`→`0xD9`, ~4.7 µs,
  fixed horizontal position every line, driven unconditionally by `hcnt_i`
  comparisons — independent of the `vcntr_i`-selected composite-sync mux
  that substitutes equalizing/serration patterns on 7 lines inside vertical
  blank). `vblank_n` is the already-computed active-low form of the
  existing `vblank` output (`vblank <= not vblank_n`). Real separate-signal
  hsync doesn't need RS-170 serration at all — that encoding exists only
  for single-wire composite consumers — so using `pulse_a` unconditionally
  on every line is textbook-correct, not an approximation.
- **`rtl_dar/phoenix.vhd`**: realizes the entity's pre-existing commented
  `video_hs`/`video_vs` ports, relays them from the `phoenix_video`
  instance's new `hsync`/`vsync` outputs.

Polarity: `video_hs <= pulse_a` directly (active-low, required — the
imported `scandoubler.v` detects hsync via a falling edge,
`if(hsD && !hs_in)`). `video_vs <= vblank_n` directly (active-low; the
scandoubler's `vs_out <= vs_in` is a bare register copy with no required
polarity, chosen for consistency with `video_hs` and because it reuses an
existing signal with no new logic).

### Scandoubler wiring

Same component/port-map shape as Burnin-Rubber's (see
`Burnin-Rubber-by-Dar/contrib/basys3/PORTING_SPEC.md` for the full component
declaration and port table); values that differ for Phoenix:

| Port | Connected signal | Note |
|---|---|---|
| `clk_sys` | `clk_out1` (11 MHz) | MMCM core clock, already generated |
| `ce_x1` | `video_clk` (5.5 MHz, from the `phoenix` core instance) | Core's own pixel clock, already phase-locked to `clk_out1` (`clk11`/2 internally) — no extra divider needed, unlike Burnin-Rubber's separate `clk_out2` |
| `ce_x2` | `'1'` (literal) | Matches fleet convention |
| `scanlines` | `"00"` (literal) | Matches fleet convention — no scanline control implemented anywhere in this project |
| `hs_in` / `vs_in` | core's `video_hs`/`video_vs`, direct connection | See "Chosen approach" above |
| `r_in` / `g_in` / `b_in` | `video_r & video_r & video_r` etc. | Core outputs 2 bits/channel (`video_r/g/b : std_logic_vector(1 downto 0)`); pad to `COLOR_DEPTH = 6` by triple replication. **No external blanking gate needed**: unlike Burnin-Rubber, the core already forces `video_r/g/b` to `"00"` internally during `hblank`/`vblank` (`fr_bit0`/`fr_bit1`/`bk_bit0`/`bk_bit1` are gated by `vblank`/`hblank_frgrd`/`hblank_bkgrd` at `phoenix.vhd:242-245`, feeding `color_id` which addresses a palette ROM whose index 0 is black) — confirmed by the DE10 top's own `blankn <= '1'` (constant, i.e. the DE10 top deliberately disables any external blanking mask and trusts the core) |

### Dual-mode output (`sw(13)`, matches the fleet's TV/VGA switch convention)

- `sw(13) = '0'` (VGA, 31 kHz): scandoubler output, as above.
- `sw(13) = '1'` (TV, 15 kHz): `video_csync` straight onto `vgaHsync`,
  `vgaVsync` tied `'1'`, native `video_r`/`video_g`/`video_b` passed through
  padded to 4 bits — this exactly reproduces the pristine DE10-lite top's
  behavior.

## Other wiring decisions

- **Reset**: `reset <= btnC or not mmcm_locked` (project-standard MMCM/reset
  pattern); `clk_wiz_0`'s own `reset` port driven by `btnC` directly.
- **Inputs — JA joystick / dedicated buttons (two attempts reverted; third
  implemented 2026-10-02, see end of this item)**: the
  pristine `phoenix` entity accepts only a PS/2 keyboard scancode stream —
  its `kbd_joystick`/`io_ps2_keyboard` instances and the resulting
  `coin`/`player_start`/`buttons` signals are entirely internal, with no
  ports to intercept for a JA joystick or dedicated buttons (unlike every
  other machine in this project). `contrib/code/phoenix_expose_control_ports.patch`
  was authored to add `ext_coin`/`ext_start1`/`ext_start2`/`ext_fire`/
  `ext_right`/`ext_left`/`ext_up` ports to the `phoenix` entity, OR-merged
  with the existing `JoyPCFRLDU`-derived signals, driven from the wrapper's
  JA joystick (active-low, inverted) and `btnU`/`btnD`/`btnL`/`btnR`.
  Hardware-tested: no input registered at all, on the same build where
  PS/2 keyboard, sound, and video were all confirmed working. A repo-wide
  precedent search (all ~25 machine directories, ported and unported)
  found Phoenix is the only core in this project that decodes PS/2 inside
  the core with no native discrete-input ports — every other core exposes
  `coin`/`start`/`fire`/direction ports directly, with any PS/2 decode kept
  in a separate board-level top file — and this patch was the only one,
  repo-wide, adding discrete control-input ports to a pristine core. There
  is no comparable, validated implementation elsewhere to debug against or
  copy. **Reverted**: the patch, the `ext_*` port map connections, the JA/
  button wrapper wiring, and the `btnU`/`btnD`/`btnL`/`btnR`/`JA` XDC
  constraints have all been removed.
  **Third attempt, implemented 2026-10-02**: `contrib/code/phoenix_external_inputs.patch`
  adds one active-high `ext_joy : in std_logic_vector(7 downto 0)` port
  (`JoyPCFRLDU` bit order) and OR-merges it into each of the seven player-input
  assignments before their inversion to the CPU's active-low inputs (e.g.
  `coin <= not (JoyPCFRLDU(7) or ext_joy(7))`). The wrapper drives it from
  the JA joystick (2-FF synchronized) and debounced `btnU`/`btnD`/`btnL`/`btnR`
  on `clock_11`; the XDC lines are enabled. Hardware-confirmed 2026-10-02.
- **`audio_select` needs a wider switch range than the Makefile originally
  documented**: the `phoenix` entity's `audio_select` port is 3 bits
  (`std_logic_vector(2 downto 0)`) — `"100"`/`"101"`/`"110"`/`"111"` select
  effect1/effect2/effect3/melody solo, anything else (`"000"`-`"011"`) mixes
  all four; a 2-bit switch range can't reach the MSB-gated solo selections.
  **Resolved**: wired `audio_select <= sw(10 downto 8)` (3 bits; `sw(10)` is
  otherwise unused on this board), Makefile `IO_SUMMARY` updated to match.
- **`sw(14)`/`sw(15)` naming**: the Makefile's `IO_SUMMARY` originally said
  `sw(14)=shutdown`, `sw(15)=gain` — functionally the fleet's
  sound-enable/AMP-gain pair (root `README.md` §"Common Basys 3 platform":
  `sw14` = sound enable, `sw15` = AMP gain), just named differently.
  **Resolved**: `IO_SUMMARY` wording aligned; the underlying signal
  connections are unchanged (`O_PMODAMP2_SHUTD <= sw(14)`,
  `O_PMODAMP2_GAIN <= sw(15)`, same as every other machine).
- **Audio**: reuse the pristine DE10 top's 13-bit PWM accumulator verbatim
  (`pwm_accumulator <= unsigned('0' & pwm_accumulator(11 downto 0)) +
  unsigned(audio & '0')`, `audio` is 12 bits) — same pattern as every other
  machine in this project (each reuses its own core's native accumulator
  width/slicing rather than a shared implementation).
- **Debug hex display**: not ported (no Basys3 board in this repo carries
  7-segment wiring) — matches every other machine.
- **LEDs**: the pristine top's `ledr(8 downto 0) <= "101010101"` is a static
  debug pattern, not meaningfully core-driven; omit the `led` port entirely
  (matches Bagman/Pooyan/Time-Pilot/Berzerk/Burnin-Rubber's convention).
