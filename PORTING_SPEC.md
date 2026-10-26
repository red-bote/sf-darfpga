# Dar core → Basys 3 porting recipe

This is the end-to-end procedure for porting a Dar (darfpga@aol.fr, SourceForge
`darfpga/files/Software VHDL/`) DE10-lite/DE2 arcade core to the Digilent Basys 3 in this
tree. It assumes no prior session context. All 20 machines in this directory follow it;
when a step is ambiguous, read how an existing machine does it (reference model:
**`Pooyan-by-Dar`**, single clock domain, MiST scandoubler, DIP switches, plain decoder).

Binding rules: `.opencode/rules.md` (this tree's copy is authoritative for Dar work).
Agent orientation: `AGENTS.md`. Skills: `.opencode/skills/port-dar-machine`,
`vivado-batch-build`, `xpr-dependency-closure`, `romset-forensics`.
Clock data: `CLOCKING_SPEC.md`, `CLOCK_CRYSTAL_CATALOG.md`. Defect log: `KNOWN_ISSUES.md`.

## 1. Layout of one machine

```
<Machine>-by-Dar/
  Makefile                      variables + include ../tools/mk/machine.mk
  README.md                     user-facing: status, controls, IO, ROMs, build (§9 template)
  dloads/<archive>.zip          Dar's archive, tracked, SHA-256 checked
  contrib/
    tools/setup_<game>.sh       thin wrapper over tools/lib/darfpga-setup.sh
    tools/prep_roms.sh          romset -> PROM VHDL (never committed)
    code/*.patch                fix patches to Dar's core sources (applied by setup)
    code/scandoubler.v          MiST scandoubler (MiST-path machines only, never modified)
    code/scandoubler_fix.patch  applied to the project copy of scandoubler.v
    basys3/PORTING_SPEC.md      design record (§9 template)
    basys3/code/<top>.vhd       the Basys 3 wrapper: tracked, edited directly
    basys3/code/<de10top>_de10_lite_to_basys3.patch   provenance record (generated)
    basys3/tools/               make_de10_lite_to_basys3_patch.sh, make_<game>_basys3_bitstream.sh
    basys3/vivado/              <top>.xpr, Basys-3-Master.xdc, create_project.sh, make_clk_wiz_0.sh
  <SRC_DIR>/                    extracted archive + generated project (untracked)
```

Shared: `tools/lib/darfpga-{setup,patch,bitstream}.sh`, `tools/mk/machine.mk`,
`tools/check-syntax.sh` + `tools/vivado/check_syntax.tcl`, `tools/new-port.sh`,
`tools/vhdl_formatter.py`, templates in `wip/machine/`. Root `Makefile` lists the machines
in `PORTS` and delegates `make <step>-<machine>`. Pooyan keeps its core fix patches in
`contrib/basys3/code/`; new ports use `contrib/code/`.

## 2. Procedure

1. **Pick the core and read it.** Dar's archive (zip) holds `rtl_dar/` (core),
   `<game>_de10_lite.vhd` (DE10 top: PLL, keyboard, DIP constants, audio PWM), shared
   modules (`io_ps2_keyboard.vhd`, `kbd_joystick.vhd`, CPU cores), `make_<game>_proms.bat`
   and `README.txt` (romset). Note the MAME driver for the game (romset name, `XTAL`,
   screen raw parameters, DIP meanings).
2. **Scaffold.** `tools/new-port.sh <game> --src-dir <dir> --url <zip url> --sha256 <sum>
   --de10-top <file> --top-entity <game>_basys3` creates the machine directory from
   `wip/machine/`, adds it to the root `PORTS`, and places the archive in `dloads/` when
   downloaded. Check every generated file for leftover `<...>` tokens.
3. **Setup.** `make setup`: verify/extract the archive, apply `contrib/code/*.patch`
   (`patch -p1 --forward`; re-runs work because extraction restores pristine files first),
   run `prep_roms.sh` (§6). Add a fix patch only when the pristine core fails Vivado
   (record it in the machine PORTING_SPEC §9).
4. **Clock.** Choose the MMCM frequency (§5), set it in `make_clk_wiz_0.sh`; `make clk_wiz`.
5. **Project.** `contrib/basys3/vivado/<top>.xpr` (tracked) lists the core sources, PROMs,
   `clk_wiz_0`, the scandoubler import and the wrapper; `create_project.sh` copies it and
   `Basys-3-Master.xdc` into `<SRC_DIR>/basys3/`. Closure check: skill
   `xpr-dependency-closure`. Unconstrained top-level ports fail placement (`Place 30-58`).
6. **Wrapper.** Author `contrib/basys3/code/<top>.vhd` (§4), starting from
   `wip/machine/contrib/basys3/code/TOP_ENTITY.vhd.template` and the reference model.
   Format with `tools/vhdl_formatter.py`.
7. **Patch.** `make patch` places the wrapper in the project and regenerates the provenance
   patch against Dar's DE10 top. Running it twice must give identical bytes.
8. **Check.** `make check` (§7). No synthesis or bitstream unless the user asks.
9. **Build and hardware test** (user): `make bitstream`, `make load`, checklist §8.
10. **Docs.** Deliverables §9.

## 3. External IO convention (fixed for all machines)

| Function | Basys 3 | Notes |
|---|---|---|
| clock | `clk` W5, 100 MHz | into `clk_wiz_0` |
| reset | `btnC` | active-high; also resets the MMCM |
| coin | `btnU`, `btnD` | both coin 1 (or coin 2 on `btnD` where noted) |
| start 1 / 2 | `btnL` / `btnR` | |
| joystick | Pmod JXADC 1/2/3/4/7 = right/left/down/up/fire; `JXADC(0..4)`; J3/L3/M2/N2/K3 | active-low to GND; XDC `PULLUP true` |
| keyboard | onboard USB-HID host: `ps2_clk` C17, `ps2_dat` B17 | `PULLUP true` |
| audio | PmodAMP2 on JA 1/2/4 (J1/L2/G2): `O_PMODAMP2_AIN/GAIN/SHUTD` | `SHUTD <= not sw(15)` (up = off), `GAIN <= not sw(14)` (up = gain) |
| video | `vgaRed/Green/Blue(3:0)`, `vgaHsync`, `vgaVsync` | sw13 up = 15 kHz TV |
| DIPs | spare `sw` | §3.2 |
| LEDs / 7-segment | none | Dar's DE10 debug outputs are not ported |

Port names follow the wrapper's existing style (`vga_r` or `vgaRed`); the XDC names must
match. Enable only the XDC lines the wrapper uses.

### 3.1 Keyboard and joystick map (MAME defaults, 2026-10-20)

Common: arrows = directions, Left Ctrl = button 1, Left Alt = button 2, 1/2 = start, 5/6 =
coin, btnU/btnD = coin, btnL/btnR = start, btnC = reset. Per machine (MAME driver):

| Machine | Keys and joystick |
|---|---|
| Bagman, Berzerk, Burnin-Rubber, Galaga, Kick, Pooyan, Popeye, Satans-Hollow, Sky-skipper, Solar-Fox, Time-Pilot | as the `rb-fpga/ref-repos` twins; each machine README |
| Burger-Time [btime] | 4-way; pepper = Left Ctrl / JXADC7 |
| Crazy-Kong [ckong] | 4-way; jump = Left Ctrl / JXADC7 |
| Xevious [xevious] | 8-way; fire = Left Ctrl / JXADC7; bomb = Left Alt, JXADC3, JXADC up+fire |
| Traverse-USA [travrusa] | left/right; accelerate = Left Ctrl / JXADC fire; brake = Left Alt, JXADC down, down+fire; JXADC up unused |
| Zaxxon [zaxxon] | 8-way; fire = Left Ctrl / JXADC7; service = F2; F7 cocktail, F4/sw12 flip |
| Tron [tron] | 8-way; fire = Left Ctrl / JXADC7; spinner = Z / X, faster = Left Alt; service = F2 toggle; continue = F6 |
| Defender [defender] | up/down = arrows, JXADC up/down; fire = Left Ctrl / JXADC7; thrust = Left Alt / JXADC right; reverse = Z / JXADC left; smart bomb = Space / JXADC down+fire; hyperspace = Left Shift / JXADC up+fire (fire not passed through in these combos); auto-up = 9 (toggle), advance = F2, high-score reset = F1 |
| Phoenix [phoenix] | left/right; fire = Left Ctrl / JXADC7; shield = Left Alt, JXADC up, up+fire, down+fire; decoded into the core's `ext_joy` |
| Computer-Space [no MAME driver] | left/right = rotate, up = thrust, fire = Left Ctrl / JXADC7, start = 1 / 2 |

Decisions (user, 2026-10-20): keyboard on the core clock (separate keyboard clocks removed);
key 6 drives a second coin input where the core has one (Zaxxon, Solar-Fox, Kick,
Satans-Hollow, Sky-skipper, Tron); toggles flip on press; `separate_audio` `'0'`;
Defender F1/F2 held; Xevious JXADC3 = down and bomb.

### 3.2 DIP switches (policy, user 2026-10-20)

- Wire the core's DIP inputs to spare switches whenever switches are free and no core
  patch is needed. Reserved: sw13 display, sw14 gain, sw15 audio off; a switch a machine
  already uses keeps its function.
- Polarity: switch down = the constant Dar's DE10 top drives; up inverts that bit:
  `constant DIP1_DEFAULT ...; dip1 <= DIP1_DEFAULT xor sw(...)` (through a signal).
- Wire whole settings only (never part of a multi-bit field); document the fixed rest.
- Discovery: the DE10 top's `dip_switch_*`/`sw*` constants (defaults), comments in the core
  entity and the DE10 top (bit meanings), MAME driver `PORT_DIPNAME` (cross-check). A DIP
  value assigned as a constant inside the core is out of scope (needs a core patch).
- Existing `sw(7:0)` DIP banks of Pooyan, Time-Pilot (direct), Popeye (`not sw`) and
  Sky-skipper (direct) keep their hardware-verified polarity.

Spare-switch assignments (2026-10-20):

| Machine | Wired | Switches |
|---|---|---|
| Traverse-USA | `dip_switch_2` (all), `dip_switch_1` bits 3-0 | sw7-0, sw11-8 |
| Pooyan, Time-Pilot | `dip_switch_2` (existing); `dip_switch_1` Coinage A | sw7-0, sw11-8 |
| Popeye, Sky-skipper | `sw2` (existing); `sw1` coinage field | sw7-0, sw11-8 |
| Phoenix | `dip_switch` (existing); `audio_select` | sw7-0, sw10-8 |
| Berzerk, Defender | cocktail | sw12 |
| Galaga, Xevious | `b_test` (test mode) | sw12 |
| Satans-Hollow, Tron | cocktail, coin meters | sw12, sw11 |
| Zaxxon | flip (with F4) | sw12 |

No DIP inputs at the core boundary: Bagman, Burger-Time, Burnin-Rubber, Crazy-Kong (DIPs are
core constants); Kick, Solar-Fox (service menu); Computer-Space.

## 4. Wrapper recipe

### 4.1 Clock and reset

- One MMCM output (`clk_wiz_0`, 100 MHz in); CPU, pixel, sound, keyboard and PWM rates are
  clock enables from it (`.opencode/rules.md` "Clocking"). No fabric-divided clocks.
- Reset: `reset <= btnC or not mmcm_locked`; the MMCM `reset` port is `btnC`. Preferred
  form: asynchronous assert, synchronous release (Pooyan `reset_s`).

### 4.2 Core instantiation and input analysis

- Keep Dar's core entity and port map; change only what the Basys 3 needs.
- For each core input read the core source, not only the DE10 top:
  - **polarity**: active-high or active-low at the core boundary;
  - **players**: P1/P2 ports; P2 mirrors P1 unless the core has a real second set;
  - **edge vs level**: a core that latches a rising edge at the full clock rate (Galaga
    fire, `galaga.vhd:836-840`; coin counters in most cores) counts contact bounce as new
    presses and needs a debounce (§4.4). A level passed to the CPU (Xevious fire, Zaxxon
    fire) is filtered by the game's once-per-frame read and needs none. Rationale:
    `Galaga-Midway-by-Dar/contrib/basys3/PORTING_SPEC.md` §7.1.
  - **internal keyboard**: a core that decodes PS/2 itself (Phoenix) gets a small core
    patch adding an `ext_joy` input OR-merged before the CPU; its PS/2 pins are tied `'1'`
    (`Phoenix-by-Dar`, `phoenix_external_inputs.patch`).
- Route every expression actual (`a or b`, `not x`, concatenations) through a signal;
  Vivado reports expression actuals as HDL 9-3240 and rejects some at synthesis.

### 4.3 Keyboard decoder (MAME keys)

`io_ps2_keyboard` (Dar's, unmodified) on the core clock, fed from the 2-FF-synchronized
`ps2_clk`/`ps2_dat`. The wrapper decodes the scancodes; `kbd_joystick` is not instantiated
(its file stays in the project, unreferenced). Rules:
- F0 marks the next code as a release; E0 is ignored (the Basys 3 USB-HID PIC24 does not
  deliver it reliably; keypad 8/2/4/6 then alias the arrows, Right Ctrl/Alt alias Left).
- Held keys follow make/release. Toggles (service, flip, cocktail, auto-up) flip on make
  and ignore typematic repeat (track a `held` bit per key).
- Keys (PS/2 set 2): arrows up 75, down 72, left 6B, right 74; Left Ctrl 14 (button 1);
  Left Alt 11 (button 2); Space 29; Left Shift 12; Z 1A; X 22; 1 16, 2 1E (start);
  5 2E, 6 36 (coin 1/2; both on one coin input where the core has one); 9 46; F1 05, F2 06
  (service); F4 0C; F6 0B; F7 83.

```vhdl
process (clk_core)
begin
  if rising_edge(clk_core) then
    if kbd_intr = '1' then
      if kbd_scancode = x"F0" then
        kbd_rel <= '1';
      elsif kbd_scancode /= x"E0" then
        kbd_rel <= '0';
        if kbd_scancode = x"75" then kbd_joy(0) <= not kbd_rel; end if; -- up
        if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl
        -- ... one line per key; toggles: if kbd_rel = '0' and held = '0' then t <= not t
      end if;
    end if;
  end if;
end process;
```

Per-machine maps: §3.1.

### 4.4 Synchronizers, merge, debounce

- 2-FF synchronizers with `attribute ASYNC_REG ... "TRUE"` on `ps2_clk`, `ps2_dat`,
  `JXADC(4:0)` and the four buttons, on the clock the core samples with.
- Merge: `core_input <= kbd_key or not jxadc_s(n) or btn_s`, active-high (invert for an
  active-low core input). Coin = keys 5/6 + btnU/btnD; start = keys 1/2 + btnL/btnR.
- Debounce only where hardware shows a fault or the core edge-detects at full clock rate
  (§4.2): output follows the synchronized input after 2^N stable cycles (~10-14 ms; Galaga
  2^18 at 18.432 MHz). Before adding one for a joystick, rule out a faulty joystick
  (a worn joystick caused missed and double fire on Zaxxon and Galaga, 2026-10-20).
- Joystick combos (direction + fire = extra button) only with user approval, for cores
  with more buttons than the joystick (§3.1). In a combo, do not pass fire through when
  the game drops a button whose edge coincides with fire (Defender, 2026-10-21).

### 4.5 Video

Pick by what the core provides:

| Core output | Path | Machines |
|---|---|---|
| progressive 31 kHz or a `tv15Khz_mode` port | core native; `tv15Khz_mode <= sw(13)` | Bagman, Berzerk, Crazy-Kong, Kick, Popeye, Satans-Hollow, Sky-skipper, Solar-Fox, Tron |
| 15 kHz only | MiST `scandoubler.v` | Burger-Time, Burnin-Rubber, Computer-Space, Defender, Galaga, Phoenix, Pooyan, Time-Pilot, Traverse-USA, Xevious, Zaxxon |

MiST path:
- Copy `contrib/code/scandoubler.v` and `scandoubler_fix.patch` from a MiST machine
  (unmodified; the patch is applied to the project copy).
- `hs_in`/`vs_in` need separate hsync/vsync. If the core exposes only composite sync, add a
  core patch that brings out its internal hsync/vsync (`*_expose_hsync_vsync.patch`,
  `*_vga_sync.patch`, `*_expose_video_timing.patch`).
- Preferred clocking (Pooyan): `clk_sys` = core clock, `ce_x1` = pixel enable, `ce_x2` =
  exactly 2 × `ce_x1`. A fabric-derived `clk_sys` (Traverse-USA, Zaxxon) is untimed
  (`KNOWN_ISSUES.md`); do not copy it.
- Gate RGB to black outside `blankn`; pad to 6 bits by MSB replication; output bits
  `(5 downto 2)`.
- sw13: `0` = scandoubler output; `1` = native RGB, csync on HS, VS `'1'`.

### 4.6 Audio

Keep Dar's PWM accumulator (its width and scaling) on the core clock with the original
enable; `O_PMODAMP2_AIN` = accumulator MSB; mono (left channel of stereo cores;
`separate_audio` tied `'0'`). Concatenations inside a type conversion go through a typed
signal (`pwm_prev`, `audio_x4` in Pooyan).

## 5. Clock selection

1. Original rates: MAME driver `XTAL` and dividers; `CLOCK_CRYSTAL_CATALOG.md`.
2. Core clock = the master the core expects (Dar's DE10 PLL output), rescaled to the
   original crystal where Dar approximated it.
3. Video check: pixel = core clock / pixel divider; H = pixel / h_total; V = H / v_total.
   31 kHz output: H × 2 within **31.0-32.0 kHz**, V within **56-61 Hz** (acceptance
   displays: Sylvania SF150, LG Flatron L2000CP).
4. Solve: `make_clk_wiz_0.sh` requests the frequency; read the achieved value from the
   generated `clk_wiz_0_clk_wiz.v`. If Vivado's solve misses the window, force D / M / O with
   `sed` on the generated files (Galaga example).
5. Record the request, the achieved value, H/V and the speed error in the machine
   PORTING_SPEC §2, CLOCK_CRYSTAL_CATALOG and CLOCKING_SPEC. Where one clock cannot meet both
   CPU accuracy and the video window, record the trade-off.

## 6. ROMs and PROM VHDL

- `prep_roms.sh` compiles Dar's `make_vhdl_prom.c` (`gcc ... -lm`), converts
  `make_<game>_proms.bat` to shell (sed, Pooyan `prep_roms.sh:41-49`: strip CR, drop
  `rem` lines, `copy /B a + b c` → `cat a b > c`, `make_vhdl_prom` → `./make_vhdl_prom`,
  `del` → `rm`, prepend `#!/bin/bash`), unzips `~/roms/<set>.zip` (`ROMZIP`, or `ROMZIP1` + `ROMZIP2` for two sets) and
  writes the PROM VHDL into the source tree.
- Romset identification and missing files: skill `romset-forensics`.
- Roms and generated PROM VHDL are copyrighted: never committed or distributed.

## 7. Verification (no synthesis)

- `make check` runs `tools/check-syntax.sh <SRC_DIR> <TOP_ENTITY>`: Vivado
  `check_syntax` (parse only) on the project, from `/tmp`, with `tools/vivado/check_syntax.tcl`.
  It hides the expected messages (MiST `scandoubler.v` HDL 9-3527, `clk_wiz` HDL 9-1672)
  and fails on any remaining ERROR or CRITICAL WARNING. Exception: HDL 9-3240 inside Dar's
  core (`rtl_dar/`) is printed but does not fail (pre-existing on Bagman, Crazy-Kong,
  Satans-Hollow, Tron, Xevious; left as is). Wrapper messages always fail.
  Computer-Space also prints 194 HDL 9-1720 WARNINGs (positional port maps in Dar's core
  RTL; not failing). Baseline sweep 2026-10-22: all 20 machines exit 0.
- Limits: parse-only. Literal actuals on Verilog module ports (Synth 8-2398) and `&` inside
  type conversions (Synth 8-944) pass `check_syntax` and fail at synthesis; avoid both.
- `make patch` twice: the provenance patch must not change.
- Synthesis, implementation and bitstream only when the user asks (`.opencode/rules.md`
  "Vivado execution"); batch flow: skill `vivado-batch-build`.

## 8. Hardware test checklist (user)

- Both acceptance displays; sw13 down (31 kHz) and up (15 kHz TV where supported).
- Picture position and full frame; sound; sw15 up mutes, sw14 up raises gain.
- Every key of the machine's map; every JXADC pin and fire; combos if any.
- btnU/btnD coin (one credit per press, none on release), btnL/btnR start, btnC reset
  during play and at power-up.
- Each DIP switch: down = Dar default behaviour, up = the documented setting.
- Record the result in the machine README "Status" with the date.

## 9. Per-machine deliverables

- `README.md` from `wip/machine/README.md.template`: Status, Features, Controls
  (`Action | Keyboard | JXADC | Basys 3` table), Switches, IO mapping, Clocking, Required
  ROMs, Building, Known issues, Issues addressed for Basys 3, Third-party sources.
- `contrib/basys3/PORTING_SPEC.md` from
  `wip/machine/contrib/basys3/PORTING_SPEC.md.template`: 1 Upstream and reference model,
  2 Clocking, 3 Reset, 4 Core instantiation, 5 Video path, 6 Audio, 7 Inputs, 8 Switches and
  DIPs, 9 Patches, 10 PROM generation, 11 Build, 12 Open items. Status lives in the README
  only. Links to tree-level docs use `../../../<doc>.md`.
- `Makefile`: `IO_SUMMARY` (keys, JXADC, buttons, sw13/14/15, DIPs), `DISPLAY_HINT`
  (`sw(13)`).
- Tree-level: `README.md` machine index row and status; root `Makefile` `PORTS`; rows in
  §3.1 and §3.2; `CLOCK_CRYSTAL_CATALOG.md` entry; `CLOCKING_SPEC.md` table row;
  `KNOWN_ISSUES.md` entries for defects found.
- Commits: the user commits (`.opencode/rules.md` git rules).

## 10. Hard rules

- Dar's sources stay pristine; every change is a `.patch` (core) or the tracked wrapper.
- The `.xpr` lives at `<SRC_DIR>/basys3/<top>.xpr` (not nested).
- Vivado runs from `/tmp` so `vivado.log`/`vivado.jou` stay out of the repo.
- Tool/path resolution: `AGENTS.md` "Tool / path resolution" (`ENV_VAR` → default).
- No here-doc generated sources: static `.tcl` with `-tclargs`, tracked `.vhd`.
- Roms and generated PROM VHDL are never committed.
