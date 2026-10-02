# Defender-by-Dar — Porting spec

## Scan doubler wiring (31 kHz VGA / 15 kHz TV)

This section is self-contained. It specifies how the `scandoubler` component
(from `imports/mist/scandoubler.v`) is instantiated and wired into the Basys 3
top level (`basys3/defender_basys3.srcs/sources_1/new/defender_basys3.vhd`,
instance label `scandoubler_inst`). It covers the component declaration, every
port connection, the signals on each side of the instance, and the
upstream/downstream logic those signals connect to, including the clock signals
that drive the instance.

The imported `scandoubler.v` is the MiST scandoubler (Till Harbaum), sourced
from the same file used by the BurgerTime port. It is tracked under
`contrib/code/scandoubler.v` and added to the Vivado project as a source file
(imported under `imports/mist/`).

### Component declaration (as declared in `defender_basys3.vhd`)

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

This declaration binds by name to the Verilog module `scandoubler`, which
parameterizes `COLOR_DEPTH = 6` and `HCNT_WIDTH = 9` at its defaults; the top
level does not override either parameter.

### Port map (`scandoubler_inst`)

| Port | Direction | Connected signal | Type/width |
|---|---|---|---|
| `clk_sys` | in | `clk_out1` (`clock_12`) | `std_logic` |
| `scanlines` | in | `"00"` (literal) | `std_logic_vector(1 downto 0)` |
| `ce_x1` | in | `ce1` (6 MHz, `clk_out1`/2) | `std_logic` |
| `ce_x2` | in | `'1'` (literal) | `std_logic` |
| `hs_in` | in | `hsync` | `std_logic` |
| `vs_in` | in | `vsync` | `std_logic` |
| `r_in` | in | `vga_r_i` | `std_logic_vector(5 downto 0)` |
| `g_in` | in | `vga_g_i` | `std_logic_vector(5 downto 0)` |
| `b_in` | in | `vga_b_i` | `std_logic_vector(5 downto 0)` |
| `hs_out` | out | `hsync_o` | `std_logic` |
| `vs_out` | out | `vsync_o` | `std_logic` |
| `r_out` | out | `vga_r_o` | `std_logic_vector(5 downto 0)` |
| `g_out` | out | `vga_g_o` | `std_logic_vector(5 downto 0)` |
| `b_out` | out | `vga_b_o` | `std_logic_vector(5 downto 0)` |

### Upstream signals (into the scan doubler)

#### `hs_in` / `vs_in`

Driven directly by the `hsync` and `vsync` outputs of the core instance (its
`video_hs` / `video_vs` ports), with no intermediate logic. These are the
core's native, undoubled sync signals, generated internally by the core at a
~15.625 kHz horizontal line rate (Defender scans 384×260, 64 µs/line). The
core's `video_csync` output is not connected to the scan doubler; it drives a
separate local `csync` signal used only by the `sw(13)` TV-mode output mux.

#### `r_in` / `g_in` / `b_in`

Driven by intermediate signals `vga_r_i`, `vga_g_i`, `vga_b_i`, each declared
as `std_logic_vector(5 downto 0)`. These are combinationally assigned,
immediately ahead of the instance, from the core's native RGB output and its
`blankn` output.

The core exposes native `r`/`g`/`b` as 3/3/2 bits respectively (like the other
Dar cores), plus a `blankn` blanking output. Each channel is padded to 6 bits
by MSB replication and forced to `"000000"` during blanking:

```vhdl
vga_r_i <= r & r     when blankn = '1' else "000000";
vga_g_i <= g & g     when blankn = '1' else "000000";
vga_b_i <= b & b & b when blankn = '1' else "000000";
```

`r & r` duplicates the 3-bit red field to fill 6 bits, etc., matching the scan
doubler's `COLOR_DEPTH = 6` default.

#### `clk_sys`, `ce_x1`, `ce_x2`

`clk_sys` is driven by `clk_out1` (12 MHz) from the design's `clk_wiz_0` MMCM.

`ce_x1` is `ce1`, a **6 MHz** enable produced in fabric as `clk_out1 / 2`
(a toggling FF). Defender's native pixel rate is 6 MHz (the core itself derives
its internal clock at `clock_12 / 2`, and 6 pixels/µs give the 64 µs line).
`ce_x1` must match that native rate. On the BurgerTime port the same 6 MHz came
from the MMCM's second output; here the MMCM's second output is 7.16 MHz (for
the sound clock), so `ce_x1` is re-created in fabric from `clk_out1`. This
mirrors the Burgtime/Burnin wiring where `ce_x1` is the 6 MHz native pixel
enable and `clk_sys` is 12 MHz.

`ce_x2` is tied to the constant `'1'`, so the scan doubler's output/ re-timing
stage is enabled on every `clk_sys` edge with no additional gating.

#### `scanlines`

Tied to the constant `"00"`, disabling the scan doubler's built-in scanline
attenuation feature.

### Downstream signals (out of the scan doubler)

#### `hs_out` / `vs_out` / `r_out` / `g_out` / `b_out` — output mux

The scan-doubler outputs (`hsync_o`, `vsync_o`, `vga_r_o`, `vga_g_o`,
`vga_b_o`), each `std_logic_vector(5 downto 0)` for the colour channels, drive
the board-facing VGA ports through a `sw(13)` display-mode mux:

- **VGA mode (sw(13) = '0')** — 31 kHz progressive VGA. Sync comes straight
  from the scan doubler; colour is truncated to the top 4 bits of each 6-bit
  field:

  ```vhdl
  vgaHsync <= hsync_o;
  vgaVsync <= vsync_o;
  vgaRed   <= vga_r_o (5 downto 2);
  vgaGreen <= vga_g_o (5 downto 2);
  vgaBlue  <= vga_b_o (5 downto 2);
  ```

- **TV mode (sw(13) = '1')** — 15 kHz TV. Native core RGB passes straight
  through (padded 3/3/2 → 4/4/4 with zeros), and composite sync (`csync`) is
  placed on the HS line with VS held high:

  ```vhdl
  vgaRed    <= r & '0';
  vgaGreen  <= g & '0';
  vgaBlue   <= b & "00";
  vgaHsync  <= csync;
  vgaVsync  <= '1';
  ```

The two low-order bits of each scan-doubler output channel are discarded.
`vgaRed`/`vgaGreen`/`vgaBlue`/`vgaHsync`/`vgaVsync` are the entity's
board-facing VGA ports, constrained in `Basys-3-Master.xdc` to the Basys 3's
4-bit-per-channel VGA connector pins.

### Caveats

- Native RGB widths (3/3/2) and the presence of `blankn` are confirmed against
  the Defender core.
- `clk_sys` must be the 12 MHz rate and `ce_x1` the 6 MHz enable for the scan
  doubler to work.
- The pristine DE10-lite top leaves the core's `video_hs`/`video_vs` outputs
  open (commented "not tested") and derives all sync from `video_csync` only.
  This port wires `video_hs`/`video_vs` into the scan doubler instead (same
  choice as the Burnin-Rubber / BurgerTime ports of the Dar core family);
  hardware-verified on the Basys 3.

## Other wiring decisions (outside the scan doubler)

- **Clocks / reset**: MMCM `clk_wiz_0` derives `clk_out1` = 12 MHz (core) and
  `clk_out2` ≈ 7.16 MHz. The core reset is `reset <= btnC or not mmcm_locked`
  (btnC resets the MMCM too, via its `reset` port). The sound board's 3.58 MHz
  clock is `clk_out2 / 2` in fabric (an exact 3.58 MHz is unreachable from the
  MMCM: VCO floor ~600 MHz vs max divide 128, 600/3.58≈167>128). The
  sample-based PIA/D-A sound logic tolerates the few-% error.
- **Inputs**: PS/2 keyboard + `kbd_joystick` OR-merged with the JA joystick
  (active-low, inverted) for move/fire: JA1=Thrust(right), JA2=Reverse(left),
  JA3=Down, JA4=Up, JA7=Fire. Smart bomb (CTRL) and hyperspace (W) — and the
  service keys (A/U/H) — are keyboard-only, because the 5-pin JA header cannot
  carry Defender's full button set.
- **Coin/start — no fire+direction combos** (root `PORTING_SPEC.md` §3
  policy): `coin` = keyboard F3 or `btnU`; `start1` = F1 or `btnL`;
  `start2` = F2 or `btnR`. No JA combos; there is no coin2 on this core.
- **Audio**: the mono PWM accumulator is reused verbatim from the pristine
  DE10-lite top, but run on the sound-board clock (`clock_3p58`), matching the
  pristine top (`pwm_accumulator <= unsigned('0' & pwm_accumulator(11 downto
  0)) + unsigned('0' & audio & "00")`, 13-bit accumulator,
  `O_PMODAMP2_AIN <= pwm_accumulator(12)`). Defender's `audio_out` is **8 bits**
  (not 11 like the Data East family), so the sound term is
  `'0' & audio & "00"` (10 bits), widening into the 13-bit accumulator.
- **Debug hex display**: `dbg_cpu_addr` is left open (`=> open`); the
  DE10-lite 7-segment debug decoder chain (`decodeur_7_seg`) is not ported and
  not in the .xpr.
- **`sw_coktail_table`**: tied `'1'` (upright cabinet), like the pristine top;
  `cmd_select_players_btn` is left open.

## Main CPU rate (1 MHz, 2026-10-02)

Original hardware: MC6809E E clock = 4 MHz / 4 = 1 MHz (MAME
`williams.cpp:1537`, 12 MHz / 3 / 4). Pristine `rtl_dar/defender.vhd:313-342`
drives the cpu09 `clk` (E, falling-edge active) high at `pixel_cnt` 3 and 5
of the 6-pixel (1 us) period: 2 MHz, Dar comment "speed up processor (two
clocks / 1us)". User decision: run at 1 MHz.

- `contrib/code/defender_cpu_1mhz.patch`: removes the `pixel_cnt = "011"`
  (clear) and `pixel_cnt = "100"` (set) branches. `cpu_clock` is then high at
  `pixel_cnt` 3-5 and low at 0-2: one falling edge per 1 us, 50% duty.
- RAM sharing: `wram_addr` selects the CPU address while `cpu_clock = '1'`
  (`:403-405`); video latches `wram*_do` at `pixel_cnt = 1` (`:427`), address
  presented during `pixel_cnt = 0`. The CPU window (3-5) does not overlap.
- cpu09 is not cycle-compatible with a 6809 (fewer cycles on several
  instructions, `rtl_jkent/cpu09l_128.vhd:14`), so throughput at 1 MHz
  remains above the original.
- `setup_defender.sh` applies the generic patch loop with `--binary` (the
  extracted rtl is CRLF).
- Hardware-confirmed 2026-10-02 (user): picture and sound correct. Revert
  by removing the patch.
