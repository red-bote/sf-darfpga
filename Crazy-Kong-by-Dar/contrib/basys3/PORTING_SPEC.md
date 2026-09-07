# Crazy-Kong-by-Dar — Porting spec

## 1. Reference model

- Source archive: `vhdl_ckong_rev_0_1_2018_06_06.zip` (SourceForge folder
  `crazy_kong`) → `vhdl_ckong_rev_0_1_2018_06_06/` at the machine root.
  SHA-256 `953bd4fdfaaad1cfcb1b9c5adee41636056b2353910664321e7422ae515a0700`
  (baked into `contrib/tools/setup_ckong.sh`).
- Core: `rtl_dar/ckong.vhd` (entity `ckong`); off-core support
  `rtl_dar/{ckong_sound, video_gen, line_doubler, gen_ram, io_ps2_keyboard,
  kbd_joystick}.vhd`, `rtl_dar/ym_2149_linmix.vhd` (entity `ym2149`, used by
  the sound), `rtl_T80/*` (T80s Z80-family CPU, instantiated here as
  `T80s` with `Mode => 0`).
- Top entity: `ckong_basys3` (target file `sources_1/new/ckong_basys3.vhd`).
- Part: `xc7a35tcpg236-1`, VHDL target language. Design is 100% VHDL; the
  only non-pristine RTL is the `clk_wiz_0` MMCM IP Netlist/Verilog wrapper
  (Vivado 2020.2-generated, no parser fixes needed).

## 2. Clocking

- **Single core clock: 12 MHz** (`clock_12`). On DE10-lite this came from
  `max10_pll_12M` (50 MHz in); on Basys 3 the `clk_wiz_0` MMCM derives it
  from the 100 MHz board oscillator (DIVCLK_DIVIDE=5, CLKFBOUT_MULT_F=49.875,
  CLKOUT0_DIVIDE_F=83.125 → VCO 997.5 MHz → 12.0 MHz; clk_out1).
- Everything runs on `clock_12`: the `ckong` core, `ckong_sound`/`ym2149`,
  the PWM audio accumulator, and the PRMSG keyboard chain — mirroring the
  pristine DE10 top exactly.
- The core derives its own internal sub-clocks from `clock_12` via
  `video_gen`: `ena_pixel` (÷2 → 6 MHz pixel rate) and `cpu_clock`
  (`not hcnt(0)` gated → ~3 MHz CPU clock, `T80s` CLK).
- Reset active-high (`btnC`), `locked` used — see §3.

## 3. Reset polarity

- **Basys 3:** `reset <= btnC or not mmcm_locked;` (Bagman/Berzerk/Pooyan
  pattern) — core held in reset while `btnC` is pressed or the MMCM has not
  locked. `clk_wiz_0`'s own `reset` port is driven directly by `btnC`.

## 4. Video (native 31 kHz progressive — no external scandoubler)

This core belongs in the **Kick/Popeye category** from the
`xpr-dependency-closure` skill's classification table: the core instantiates
its own `line_doubler` (ckong.vhd:634) and drives **real** `video_hs`/
`video_vs` — `video_hs <= hsync_o`, `video_vs <= vsync_o` are active drivers
(ckong.vhd:219-220), no expose patch needed (unlike the
Phoenix/Xevious/Traverse-USA family). There is **no imported scandoubler**,
no `contrib/code/scandoubler.v` copy, and no `--board_vga`-style generation in
`create_project.sh`.

- `tv15Khz_mode` (DE10's sw(0), here sw(13)) selects the output:
  - `'0'` → 31 kHz progressive VGA: core's internal `line_doubler` drives
    `hsync_o`/`vsync_o`, which the core output as `video_hs`/`video_vs`; the
    wrapper drives the VGA sync pins directly.
  - `'1'` → 15 kHz TV: composite sync `video_csync` on HS, VS held high
    (needs a 15 kHz RGB monitor or an RGB→composite converter).
- RGB is 3/3/2 (`video_r`/`video_g`/`video_b`), padded to 4/4/4 the same way
  in both modes, exactly as the pristine `vga_r/g/b` assignments:
  `vgaRed <= r & '0'; vgaGreen <= g & '0'; vgaBlue <= b & "00";`.
- No intermediate signals, no scanline attenuation, no blanking mux (the core
  output is intrinsically blank-aware via the board pipeline).

## 5. Audio (mono PWM on PmodAMP2)

- `audio_out` is 16-bit (`audio(15:0)`), mono.
- The PWM accumulator is reused verbatim from the pristine DE10 top: a 13-bit
  accumulator on `clock_12` adding `audio(15 downto 4)`, output bit 12 →
  `O_PMODAMP2_AIN`. No divider runs the audio (unlike Traverse-USA, whose
  sound board and accumulator ran on a separate clock).
- `sw(15)` → AMP gain, `sw(14)` → AMP shutdown (standard convention).

## 6. Inputs

- **Keyboard is always on the Basys 3 onboard USB HID host** (C17 =
  `ps2_clk`, B17 = `ps2_dat`) — the onboard USB-A port, never JB and never an
  external PS/2 connector (Computer-Space / Congo Bongo convention).
- **No keyboard divider is needed.** The onboard USB-HID host requires a
  ≥ 6 MHz keyboard sampling clock; the pristine DE10 top already drives
  `io_ps2_keyboard.clk` directly from `clock_12` (12 MHz). Unlike
  Traverse-USA's ~3 MHz shared divider (which had to be fixed), the 12 MHz
  native clock is comfortably above the ≥ 6 MHz threshold, so `kbd_joystick`/
  `io_ps2_keyboard` are wired unmodified.
- The `kbd_joystick` here is the **`joyHBCPPFRLDU` (10-bit)** variant:
  bit0=Up, bit1=Down, bit2=Left, bit3=Right, bit4=Space (fire/jump), bit5=F1
  (start 1), bit6=F2 (start 2), bit7=F3 (coin), bit8=Ctrl, bit9=W. (Core has
  no key for UP on US-keyboard layouts except the arrow and W; Space is the
  sole dedicated fire/jump key.)
- JA joystick (5-pin, active-low, inverted to active-high like the keyboard
  path) OR-merged into movement + fire only: JA1=Right, JA2=Left, JA3=Down,
  JA4=Up, JA7=Fire.
- **Coin/start: dedicated Basys3 buttons** in addition to the keyboard:
  `btnU`/`btnD` = coin (both OR the core's single `coin1` with
  `joyHBCPPFRLDU(7)` F3), `btnL` = start 1 (OR F1), `btnR` = start 2 (OR F2).
  No JA coin/start combos — the dedicated buttons make them redundant.
- Player 2 mirrors player 1 inputs (the core has no genuine second control
  set, only cocktail-mode duplicates — matches the pristine DE10 top).
- No dip switches are exposed; the core's defaults match the pristine top.

## 7. LEDs

- No `led` port: the pristine top's 7-segment `hex0..3` debug chain
  (`dbg_cpu_addr`) is not ported; `dbg_cpu_addr` is left `open`.

## 8. Synthesis-fix / behavior-fix patches

- `contrib/code/ckong_xor_width.patch` (`ckong.vhd:405-408`): the four
  sprite-address cases XOR the 13-bit `tile_graph_rom_addr` driver with 5-bit
  literals. `&` binds tighter than `xor`, so the whole 13-bit vector is the
  XOR operand, and Vivado rejects the length mismatch (`bagman_xor_width.patch`
  is the identical pattern — the same video-addressing code in both cores).
  The fix zero-pads each constant to 13 bits
  (`"00000"→"0000000000000"`, `"01000"→"0000000001000"`,
  `"10111"→"0000000010111"`, `"11111"→"0000000011111"`), preserving the exact
  parsed semantics — a synthesis width fix, no behavior change. Applied
  idempotently by `setup_ckong.sh` (guarded by a reverse dry-run) to the
  pristine CRLF tree.
- No video-path fix is needed: video is natively progressive with real HS/VS
  (no expose patch, §4) and the keyboard is already ≥ 6 MHz at `clock_12`
  (no divider fix, §6).
- The only other patch in this port is the wrapper generator
  `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`, which emits
  `contrib/basys3/code/ckong_de10_lite_to_basys3.patch` (the DE10 top →
  `ckong_basys3` wrapper conversion).

## 9. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/ckong_basys3.xpr`, sources tree at `basys3/ckong_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log`/`vivado.jou` stay
  out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/ckong.zip`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or
  distribute them.