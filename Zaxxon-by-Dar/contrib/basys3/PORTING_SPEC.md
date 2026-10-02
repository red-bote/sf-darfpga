# Zaxxon-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_zaxxon_rev_0_0_2019_11_29.zip` (SourceForge folder `zaxxon`) →
  `vhdl_zaxxon_rev_0_0_2019_11_29/` at the machine root.
- Top entity: `zaxxon_basys3` (target file `sources_1/new/zaxxon_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language.
- Status: in progress (see root `README.md` Status section for the current
  verified stage).

## 2. Clocking

- Single core clock: **24 MHz** (`clock_24`), derived on DE10-lite from
  [Clock revision 2026-10-01, `../../CLOCKING_SPEC.md` section 4: retargeted to 24.329 MHz (Vivado solve DIVCLK 3 / MULT_F 35.125 / CLKOUT0_DIVIDE_F 48.125) = 48.66 MHz crystal / 2, CPU 3.041 MHz as the original (was -1.36%); 24 MHz figures below scale by 1.0137.]
  50 MHz by `max10_pll_24M`. On Basys 3, `clk_wiz_0` derives it from the
  100 MHz board oscillator instead — single MMCM output, no second clock
  needed (unlike Burnin-Rubber/BurgerTime's 12+6 MHz pairs).
- Reset active-high (`btnC`), `locked` used — see §3.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Bagman/Berzerk/Pooyan
  pattern) — core held in reset while `btnC` is pressed or the MMCM has not
  locked. `clk_wiz_0`'s own `reset` port is driven directly by `btnC`.

## 4. Video (31 kHz VGA / 15 kHz TV, switch-selectable)

**Correction (post-hardware-bring-up):** the `zaxxon` core entity declares
`video_hs`/`video_vs` output ports, but a grep for `video_hs\s*<=`/
`video_vs\s*<=` in `vhdl_zaxxon_rev_0_0_2019_11_29/rtl_dar/zaxxon.vhd` returns
zero matches — these ports were never actually driven (only `video_csync` is
real, built from a classic analog-TV composite-sync generator with
equalizing/serration pulses). The original design intent below (this port
belongs in the "no core patch" category, same as Galaga/Burnin-Rubber) was
wrong: the port list existing is not the same as the signals being driven,
and this core in fact belongs in the **Phoenix/Xevious category** ("core
needs a patch to expose hsync/vsync in the first place"). No VGA display
output resulted on hardware bring-up until this was fixed.

`contrib/code/zaxxon_expose_video_timing.patch` fixes it: adds
`video_hs <= hsync0;` (an existing per-line pulse — low from `hs_cnt=0` to
`hs_cnt=29`, unconditional every line including during vertical blanking —
already a valid horizontal sync, so no new logic needed) and
`video_vs <= '0' when vcnt < 8 else '1';` (new, simple 8-line pulse — matching
Burnin-Rubber's own `vsync_cnt=8` pulse width — positioned inside the
existing vertical-blanking window: `video_blankn`'s own logic already treats
`vcnt < 17` as blanked, so this sits safely inside it). Deliberately
independent of the legacy `vs_cnt`/equalizing-pulse machinery that drives
`video_csync` — that scheme encodes broadcast-TV serration/equalizing pulses
and doesn't cleanly split into separate H/V.

No `line_doubler.vhd` exists in this core's source archive (that's
Bagman/Berzerk's structurally different, no-scandoubler approach), so patching
the core was the only viable fix — the Basys3 wrapper cannot derive separate
H/V itself since `hcnt`/`vcnt`/`hs_cnt`/`vs_cnt` aren't exposed at the entity
boundary.

This remains the "external MiST scandoubler needed" signature from the
`xpr-dependency-closure` skill's classification table (no `tv15Khz_mode`
input, no internal `line_doubler`) — only the "no core patch needed" half of
the original classification was wrong.

This section follows Burnin-Rubber-by-Dar's scan-doubler wiring pattern
directly; only the resolved 24 MHz clock and this core's native RGB/blank/sync
port names differ.

The imported `scandoubler.v` is the MiST scandoubler (`contrib/code/scandoubler.v`,
cleanroom import, never modified in place), sourced the same way as every
other importing machine: tracked as `contrib/code/scandoubler.v` and copied
into the project by `create_project.sh`. Added to the Vivado project under `imports/mist/`.
`contrib/code/scandoubler_fix.patch` (Vivado 2020.2 Verilog-2001 parser fix
for the single-value unpacked array size) is applied only to the copied
project instance by `create_project.sh`, never to the canonical import.

### Component declaration (as declared in `zaxxon_basys3.vhd`)

```vhdl
component scandoubler
    port (
        clk_sys   : in  std_logic;
        scanlines : in  std_logic_vector (1 downto 0);
        ce_x1     : in  std_logic;
        ce_x2     : in  std_logic;
        hs_in     : in  std_logic;
        vs_in     : in  std_logic;
        r_in      : in  std_logic_vector (5 downto 0);
        g_in      : in  std_logic_vector (5 downto 0);
        b_in      : in  std_logic_vector (5 downto 0);
        hs_out    : out std_logic;
        vs_out    : out std_logic;
        r_out     : out std_logic_vector (5 downto 0);
        g_out     : out std_logic_vector (5 downto 0);
        b_out     : out std_logic_vector (5 downto 0)
    );
end component;
```

Binds by name to the Verilog module `scandoubler`, `COLOR_DEPTH = 6` /
`HCNT_WIDTH = 9` defaults, not overridden.

### Port map (`scandoubler_inst`)

| Port | Direction | Connected signal | Type/width |
|---|---|---|---|
| `clk_sys` | in | `sd_clock_12` (derived 12 MHz, see below) | `std_logic` |
| `scanlines` | in | `"00"` (literal) | `std_logic_vector(1 downto 0)` |
| `ce_x1` | in | `sd_clock_6` (derived 6 MHz, see below) | `std_logic` |
| `ce_x2` | in | `'1'` (literal) | `std_logic` |
| `hs_in` | in | `hsync` (core `video_hs`) | `std_logic` |
| `vs_in` | in | `vsync` (core `video_vs`) | `std_logic` |
| `r_in` | in | `vga_r_i` | `std_logic_vector(5 downto 0)` |
| `g_in` | in | `vga_g_i` | `std_logic_vector(5 downto 0)` |
| `b_in` | in | `vga_b_i` | `std_logic_vector(5 downto 0)` |
| `hs_out` | out | `hsync_o` | `std_logic` |
| `vs_out` | out | `vsync_o` | `std_logic` |
| `r_out` | out | `vga_r_o` | `std_logic_vector(5 downto 0)` |
| `g_out` | out | `vga_g_o` | `std_logic_vector(5 downto 0)` |
| `b_out` | out | `vga_b_o` | `std_logic_vector(5 downto 0)` |

**Correction (post-hardware-bring-up, revised twice):** the original text
claimed `ce_x1 => clock_24` and `ce_x2 => '1'` (i.e. both firing on every
`clk_sys` edge), justified as a "single-clock-domain" precedent that doesn't
actually exist in this repo. A first fix kept `clk_sys => clock_24` directly
and derived phase-exact `ce_x1`/`ce_x2` enables from a mirrored counter —
this was *also* wrong: **`clk_sys` itself must be a derived, divided
signal, not the fast base clock fed in directly with gating enables.**

The evidence: Galaga is the origin project for this exact `scandoubler.v`
file, and its own porting record
(`Galaga-Midway-by-Dar/PORTING_SPEC.md` #12.3.3) documents a source comment
— `-- clock_18, video_clk i clock_36 no funciona` (Spanish: "does not work")
— recording that wiring the faster MMCM clocks (18 MHz, 36 MHz) directly to
`clk_sys` was tried and failed; the working design uses a *derived*
`clock_12` as `clk_sys` and `clock_6` as `ce_x1`, both produced by a
dedicated counter, with `ce_x2` tied to constant `'1'`. Burnin-Rubber
matches the same shape (`clk_sys` = 2× `ce_x1`, `ce_x2` = `'1'`), just with
real MMCM-generated 12/6 MHz clocks instead of a derived counter.

`scandoubler.v`'s `ce_x1` gates the **write side** (samples `hs_in`, writes
the incoming pixel into the line buffer) and must pulse once per incoming
pixel; `ce_x2` gates the **read side** and must pulse at exactly **2×** the
`ce_x1` rate (the module's own comment: "timing generation runs ... twice
the input signal analysis speed") to achieve real horizontal doubling.

Zaxxon's real pixel rate, confirmed by reading `zaxxon.vhd`'s video-clock
generator (not assumed):
```
clock_vid <= clock_24;                                     -- 24 MHz base
clock_cnt: 4-bit counter, +1 every clock_vid edge, /16, reset with `reset`
pix_ena  <= '1' when clock_cnt(1 downto 0) = "01" else '0'; -- 6 MHz, 1-in-4
```
`clock_cnt`'s bits give exactly the 12/6 MHz signals needed: bit 0 toggles
every `clock_24` cycle (12 MHz), bit 1 every 2 cycles (6 MHz), and bit 1's
rising edge lands exactly one `clock_24` cycle after `pix_ena` fires — right
as the core's newly-registered pixel data settles. `clock_cnt` depends on
nothing but `clock_24` and `reset`, so an equivalent counter mirrored in the
wrapper would be provably bit-identical — but `zaxxon_expose_video_timing.patch`
exposes the real signal instead (a new `pix_clk_div : out
std_logic_vector(1 downto 0)` port, `pix_clk_div <= clock_cnt(1 downto 0);`),
favoring a single source of truth over a duplicated "trust me it matches"
counter. The wrapper just slices it: `sd_clock_12 <= pix_clk_div(0);
sd_clock_6 <= pix_clk_div(1);`. Final wiring: `clk_sys => sd_clock_12`,
`ce_x1 => sd_clock_6`, `ce_x2 => '1'`.

### Upstream signals (into the scan doubler)

- `hs_in`/`vs_in`: driven directly by the core's `video_hs`/`video_vs`
  outputs (real only since `zaxxon_expose_video_timing.patch`, see above), no
  intermediate logic. `video_csync` is not connected to the scan doubler; it
  drives a local `csync` signal used only by the `sw(13)` TV-mode output mux.
- `r_in`/`g_in`/`b_in`: the core exposes native `r`/`g`/`b` as 3/3/2 bits
  (`video_r(2:0)`, `video_g(2:0)`, `video_b(1:0)`) plus a `blankn`
  (`video_blankn`) output — same widths as Burnin-Rubber. Padded to 6 bits by
  MSB replication, forced to `"000000"` while blanked:

  ```vhdl
  vga_r_i <= r & r     when blankn = '1' else "000000";
  vga_g_i <= g & g     when blankn = '1' else "000000";
  vga_b_i <= b & b & b when blankn = '1' else "000000";
  ```
- `scanlines`: tied to `"00"` (scanline attenuation unused).

### Downstream signals (out of the scan doubler) — `sw(13)` mux

- **VGA mode (`sw(13) = '0'`)** — 31 kHz progressive VGA, sync from the scan
  doubler, colour truncated to the top 4 bits of each 6-bit field:
  ```vhdl
  vgaHsync <= hsync_o;  vgaVsync <= vsync_o;
  vgaRed   <= vga_r_o(5 downto 2);
  vgaGreen <= vga_g_o(5 downto 2);
  vgaBlue  <= vga_b_o(5 downto 2);
  ```
- **TV mode (`sw(13) = '1'`)** — 15 kHz TV, native core RGB (3/3/2 padded to
  4/4/4 with zeros), composite sync on HS, VS held high:
  ```vhdl
  vgaRed <= r & '0';  vgaGreen <= g & '0';  vgaBlue <= b & "00";
  vgaHsync <= csync;  vgaVsync <= '1';
  ```

### Caveats

- The pristine DE10-lite top leaves `video_hs`/`video_vs` unconnected and
  derives all sync from `video_csync` only — and, as the Correction above
  documents, the pristine core doesn't drive `video_hs`/`video_vs` at all
  without `zaxxon_expose_video_timing.patch`. This port wires the patched
  signals into the scan doubler; not a pattern validated on real hardware in
  the original Dar release for this specific core.

## 5. Audio (mono PWM on PmodAMP2)

- `audio_out_l`/`audio_out_r` are both 16-bit on this core (unlike
  Burnin-Rubber's 11-bit mono `audio_out`) — matches Berzerk's 16-bit
  `audio_out` case per the Burnin-Rubber spec's note. Project convention is
  mono/left-channel: only `audio_out_l` is wired.
- The PWM accumulator is reused verbatim from the pristine DE10-lite top
  (`pwm_accumulator_l <= ('0' & pwm_accumulator_l(16 downto 0)) +
  ('0' & audio_l & '0')`, 18-bit accumulator, `O_PMODAMP2_AIN <=
  pwm_accumulator_l(17)`) — the DE10-lite top already implements this exact
  16-bit-audio-into-18-bit-accumulator pattern for both channels; the Basys 3
  port keeps only the left-channel instance. `audio_out_r => open` in the
  core instantiation (no accumulator for it).
- `sw(15)` → AMP gain, `sw(14)` → AMP shutdown (standard convention).

## 6. Inputs

- PS/2 keyboard + `kbd_joystick`, ported unchanged, on JB (`ps2_clk`/`ps2_dat`).
- JA joystick (5-pin, active-low, invert to active-high) OR-merged into
  movement + fire only: `JA1=Right, JA2=Left, JA3=Down, JA4=Up, JA7=Fire`.
- **Coin/start: dedicated Basys3 buttons** (per explicit decision, Burnin-Rubber
  style) in addition to the keyboard: `btnU`/`btnD` = coin (both map to the
  core's single `coin1`; `coin2` stays tied to `'0'`, matching the pristine
  top — this hardware has only one coin input), `btnL` = start 1, `btnR` =
  start 2, each OR'd with the keyboard-decoded `fn_pulse(0)`/`fn_pulse(1)`/
  `fn_pulse(2)` (F1/F2/F3). No JA fire+direction coin/start combos are added:
  unlike Bagman (no coin/start buttons available, so JA combos are its only
  non-keyboard option), Zaxxon has dedicated buttons, so the combo layer is
  redundant scope and is skipped.
- Requires uncommenting `btnU`/`btnL`/`btnR`/`btnD` in this machine's own
  `contrib/basys3/vivado/Basys-3-Master.xdc` copy (confirmed independently
  editable per machine — Burnin-Rubber's copy already diverges from Bagman's
  template in exactly this way).
- Cocktail (F7), service (F5), and flip-screen (F4) stay keyboard-only,
  decoded by the unmodified `kbd_joystick` — no dedicated Basys3 IO. Matches
  every other ported machine's convention (Tron's spec: cocktail-mode `*_c`
  ports tied off, only real inputs get board IO). Zaxxon's `left_c`/`right_c`/
  `up_c`/`down_c`/`fire_c` ports are tied to the same `joy_BBBBFRLDU` signals
  as player 1 (mirrors the pristine DE10-lite top; the core has no genuine
  second control set, only cocktail-mode duplicates).
- Player 2 mirrors player 1 inputs (no separate P2 control set in this core).

## 7. LEDs

- No `led` port: the pristine top's `ledr` assignments are debug-only
  (7-segment `dbg_cpu_addr` display, not ported — matches every other
  machine's convention of skipping the DE10-lite 7-segment debug chain).

## 8. Synthesis-fix / behavior-fix patches

- `zaxxon_hflip_xor_width.patch`: left-pads a narrow XOR literal in
  `hflip2`'s assignment from 8 to 9 bits, fixing a Vivado synthesis
  width-mismatch (`hflip`/`hflip2` are 9-bit signals) — same class of bug as
  `bagman_xor_width.patch`.
- `zaxxon_expose_video_timing.patch`: adds real `video_hs`/`video_vs` drivers
  and a `pix_clk_div` output exposing the core's real 12/6 MHz clock bits
  (see §4 Video, Correction) — a behavior fix, not a synthesis-failure fix;
  the pristine core synthesizes without error but produces no valid VGA sync.
- `scandoubler_fix.patch` (§4) is applied to the imported scandoubler copy
  only, not to the pristine `zaxxon` tree.

## 9. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/zaxxon_basys3.xpr`, sources tree at `basys3/zaxxon_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay
  out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/zaxxon.zip`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or
  distribute them.
