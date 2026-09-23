# Generic DE10-lite → Basys3 porting spec

This spec describes how to prepare a new machine's Basys3 porting project in this repo.
It is written generically using `<machine>` / `<set>` placeholders; see the per-machine specs
for concrete values (`<Machine>-by-Dar/PORTING_SPEC.md`).

Bring up a new machine by mirroring an existing complete, working port in this repo: its
scripted Makefile and `contrib/basys3/` layout are the template. When a step below is
ambiguous, copy what an existing full port does.

## 1. Reference model

- Each machine lives in its own `<Machine>-by-Dar/` directory.
- Each machine's `README.md` is the single source of truth for that machine's design and build.
- Each machine carries a `PORTING_SPEC.md` documenting its specific porting decisions.
  Canonical location is `<Machine>-by-Dar/contrib/basys3/PORTING_SPEC.md`; some
  machines still have it at the machine-directory top level pending migration.
- Shared assets live under `<Machine>-by-Dar/contrib/basys3/`:
  - `code/` — `vga_scandoubler.v` (canonical, never modify) + `*.patch` (synthesis-fix records)
  - `vivado/` — `.xpr`, `.xdc`, clock-IP and project scripts
  - `tools/` — source-setup and rom-prep scripts

## 2. Prep workflow (order matters)

Bring the machine up in this order, mirroring an existing full port's scripts for each step.

1. **Scaffold** — `sf-darfpga/tools/new-port.sh <game> --src-dir ... --url ... --sha256 ...
   --de10-top ... --top-entity ...` generates the `Makefile`, `contrib/{tools,basys3/tools,
   basys3/vivado}` scripts, and a stub `contrib/basys3/code/<top-entity>.vhd` from the
   `wip/machine/` templates in one step (see step 8's note on what it does and does not fill
   in). Then author `README.md` at the machine root and `PORTING_SPEC.md` under
   `contrib/basys3/` by hand.
2. **Source archive** — obtain the Dar source zip (download index: `~/tmp/downloads.md`) and
   extract it into `vhdl_<machine>_rev_.../` at the machine root.
3. **Synthesis-fix patches** — any `contrib/basys3/code/*.patch` (e.g. a core-specific
   synthesis-fix record) applied idempotently with `patch -p1 --forward`. Only needed if the
   pristine core fails Vivado synthesis.
4. **Rom prep** — `prep_roms.sh`: compile `make_vhdl_prom` on the host (`gcc ... -lm`), convert
   `make_<machine>_proms.bat` → `.sh` (the `.bat`→`.sh` sed rules), unzip `~/roms/<set>.zip`,
   run the generator to produce the PROM VHDL in place.
5. **Source setup** — `setup_<machine>.sh`: a thin wrapper around the shared
   `darfpga_setup()` (`sf-darfpga/tools/lib/darfpga-setup.sh`), which downloads/extracts the
   archive, applies fix patches (excluding the `*_de10_lite_to_basys3.patch` provenance
   record — hardcoded in the shared function, not a per-machine detail to get right or wrong),
   then chains into rom-prep.
6. **Clock IP** — `make_clk_wiz_0.sh`: generate the `clk_wiz_0` MMCM deriving the core/sound
   clocks from the 100 MHz Basys 3 oscillator; place its wrappers where the `.xpr` references them.
7. **Project** — `create_project.sh`: clone the starting project from
   `wip/machine/contrib/basys3/basys3-project-template/` (the sample project; see
   §3) as the port's own `.xpr`/`.xdc`, and copy the
   template constraints file `Basys-3-Master.xdc`, uncommenting/renaming only the
   port lines the port uses;
   add the core sources, scandoubler import, and clk_wiz_0 wrappers.
8. **Makefile** — set `GAME` / `SRC_DIR` / `TOP_ENTITY` / `IO_SUMMARY` / `DISPLAY_HINT` and
   `include ../tools/mk/machine.mk`, which defines all 8 standard targets (`setup create_prj
   clk_wiz patch synth bitstream clean help`) once, shared across every migrated machine.

Steps 4–7 are templated under `wip/machine/contrib/` (`tools/`, `basys3/tools/`,
`basys3/vivado/`); `new-port.sh` (step 1) substitutes `<game>` / `<src_dir>` / archive URL+SHA
/ entity-name tokens automatically. What's still authored by hand per port: the top-level VHDL
itself (a real, tracked file at `contrib/basys3/code/<top-entity>.vhd` — format it with
`sf-darfpga/tools/vhdl_formatter.py`; see §4), `prep_roms.sh`'s romset-unzip step (single vs.
multi-romset, or a cross-machine borrow like Tron's `midssio.zip`), and
`create_project.sh`'s scandoubler import / `make_clk_wiz_0.sh`'s clock frequency.

**Migration status**: all 21 committed sf-darfpga machines use the shared-library convention
above (`tools/lib/darfpga-{setup,patch,bitstream}.sh` + `tools/mk/machine.mk`). Two needed a
small, backward-compatible extension to the shared library, each documented in its own thin
wrapper script: **Computer-Space-by-Dar** (`--de10-dir rtl`, `--extra-exclude`, `--binary` — its
pristine top lives in `rtl/` not `rtl_dar/`, it has two extra provenance-only patches, and its
fix patches are CRLF-sensitive; its former inline rom-prep logic also moved into a proper
`contrib/tools/prep_roms.sh` to fit the shared `darfpga_setup()`'s call shape), and
**Phoenix-by-Dar** (`--flat-archive`, its zip has no internal top-level folder). `machine.mk`
also gained `load`/`rebuild-load` targets and a `DISPLAY_NAME` variable during this migration,
needed by machines whose prior Makefile already had them.

**Pooyan-by-Dar** originally needed a third extension (`--xpr-subdir`, for a Vivado project
nested one level deeper than every other machine: `basys3/pooyan_basys3/pooyan_basys3.xpr`).
That nesting was a leftover artifact from however its tracked `.xpr` was first captured (Vivado's
own `create_project <name> <dir>` command defaults to a nested `<dir>/<name>/<name>.xpr` layout;
every other machine's `.xpr` was captured flat from the start), not a deliberate design choice —
it has since been flattened to match the standard `basys3/<top-entity>.xpr` layout, and
`--xpr-subdir`/`XPR_SUBDIR` were removed from the shared library entirely (no other machine used
them).

New ports (via `new-port.sh`, step 1) start directly in this shape; verify any future change to
the shared library or to a machine's own scripts with `make clean && make setup && make patch
&& make patch` (the second `patch` run is the regression check — it must reproduce the exact
`.patch` bytes already at `HEAD`) — this is exactly the check that caught the original
Popeye-by-Dar bug that motivated this convention (a missing patch-exclusion, corrupting the
generated `.patch` on a second run; see git history).

## 3. External IO convention (standard Basys3 mapping)

Every new port starts from the sample Vivado project: the ported `.xpr` and `.xdc`
derive from `wip/machine/contrib/basys3/basys3-project-template/`
(part `xc7a35tcpg236-1`, board
`digilentinc.com:basys3:part0:1.2`), specifically
`basys3-project-template.xpr` and its in-project constraints
`basys3-project-template.srcs/constrs_1/imports/digilent-xdc-master/Basys-3-Master.xdc`. The template XDC ships with
every pin commented out; a port uncomments and renames only the lines it uses — never re-author
the XDC, and keep the XDC-constrained port set minimal (declaring unconstrained ports fails
placement with `Place 30-58`).

The default external-IO mapping below is used unless a specific source port forces otherwise:

| Function | Basys 3 resource | Notes |
|---|---|---|
| reset | `btnC` | active-high |
| coin-in | `btnU` | |
| second coin-in | `btnD` | only if the core has 2 coin inputs |
| 1P start | `btnL` | |
| 2P start | `btnR` | |
| joystick left/right/up/down/fire | PMODA `JA[0..4]` (JA1–4, JA7) | active-low, switch to GND; OR-merged with the keyboard |
| PS/2 keyboard | onboard USB HID `ps2_dat`/`ps2_clk` (B17/C17) — **default**; JB1/JB3 Pmod (A14/B15) legacy | take all keys defined in the DE10-lite top source being ported; see keyboard-clock note below |
| dipswitches | `sw` bits | map all dipswitches from the DE10-lite top |
| audio PWM | `O_PMODAMP2_AIN/GAIN/SHUTD` (JC) | sound-enable + gain on the switches |
| VGA | `vgaRed/vgaGreen/vgaBlue(3:0)`, `Hsync`, `Vsync` | 4-4-4 RGB; see TV note below |

- **PS/2 keyboard, two IO options — pick per port, both wire to the same
  `io_ps2_keyboard.vhd`/`kbd_joystick.vhd` unchanged**:
  - **Onboard USB HID host** (the template's `##USB HID (PS/2)` XDC block,
    B17/C17 `ps2_dat`/`ps2_clk`) — the Basys 3 has an onboard PIC24-based
    USB-A host port that translates a plugged-in USB keyboard into the
    *same* PS/2 protocol/pins a direct device would use. **This is the
    project default for all new ports** (convention since 2026-09); it needs
    no external breakout and is what the template XDC ships enabled.
    No VHDL logic change either way — this is purely an XDC pin choice
    (comment out the JB1/JB3 lines, uncomment the `##USB HID (PS/2)` lines,
    retarget their placeholder `PS2Clk`/`PS2Data` port names to the port's
    actual `ps2_clk`/`ps2_dat`).
  - **JB1/JB3 Pmod** (A14/B15 `ps2_dat`/`ps2_clk`) — an external PS/2
    breakout wired to the Pmod header. Legacy option, kept for older ports
    that predate the USB-HID convention; not used for new ports.
  - **Keyboard-clock rate matters and differs between the two options —
    this is the one gotcha that isn't a simple pin swap.** The clock fed to
    `io_ps2_keyboard`'s `clk` port (usually a divided-down `clock_24` or
    similar, reused verbatim from the DE10-lite top in most pristine
    sources) is commonly ~4 MHz by whatever divider ratio the source
    happens to use. **4 MHz works fine for a real PS/2 device on JB1/JB3,
    but has been found non-functional for the onboard USB HID host port** —
    confirmed on real hardware (`vhdl_congo_bongo/contrib/basys3/PORTING_SPEC.md`
    §5 has the full root-cause writeup: it built and flashed cleanly, only
    the keyboard didn't respond, everything else on the board worked fine).
    **6 MHz is the confirmed-working rate** for the onboard USB HID port —
    independently confirmed by two other ports in this repository
    (`Arcade_Zaxxon` and `Pooyan-by-Dar`) that either hit and fixed this
    exact symptom or already used 6 MHz for unrelated reasons. When porting
    a new machine for the onboard USB HID port (or moving an existing one
    to it), check/set the keyboard-clock divider to give **at least 6 MHz**,
    not whatever ratio the pristine source happens to use verbatim. Sky
    Skipper clocks `io_ps2_keyboard`/`kbd_joystick` directly on its 40 MHz
    core clock — the simplest independent clock.
  - **Don't just retarget the pristine divider's threshold if it's shared
    with anything else.** Some pristine tops reuse the same divider/counter
    for the keyboard clock *and* another gated signal (e.g. a PWM audio
    accumulator update, as in Congo Bongo) — changing that counter's period
    to hit 6 MHz would also change the other signal's rate as an untested
    side effect. Add a second, independent counter dedicated to the
    keyboard clock instead (or feed a fast core clock directly — Sky Skipper
    re-clocks `io_ps2_keyboard`/`kbd_joystick` straight off its 40 MHz core
    clock and leaves the pristine counter gating only the PWM accumulator),
    and leave the original counter (and whatever else it gates) untouched.
- **TV display**: VGA is always supported. Additionally keep 15 kHz TV display support
  (native RGB + composite sync on HS) if the source port provides it.
- **LEDs / 7-segment display**: if the port source actively drives LEDs or a 7-segment
  display (e.g. the DE10-lite top carries `ledr`, `hex0-3`, or a debug hex-display path),
  map them on the Basys 3 too by uncommenting the template XDC's `led[0..15]` /
  `seg[0..6]`/`dp`/`an[0..3]` lines. Only include these if the source actually drives them.

## 4. Porting steps (DE10-lite → Basys3)

The reusable transformations for the top-level wrapper. Each should be confirmed against the
pristine core, using an existing full port's top level as the worked example. On a
shared-library machine (§2 step 8) the result is authored directly as
`contrib/basys3/code/<top-entity>.vhd`, a real file — not as a bash here-doc inside the patch
script. The diff this file's `make patch` step produces against the pristine upstream top
level is a provenance record only; it documents the transformation below, it does not drive it.

1. **Port list** — replace the DE10-lite ports (`max10_clk1_50`, `ledr`, `key`, `sw(9:0)`,
   `hex0-3`, `gpio`) with the Basys 3 set (`clk` 100 MHz, `sw(15:0)`, `btnC`, `ps2_dat/ps2_clk`,
   `O_PMODAMP2_AIN/GAIN/SHUTD`, `JA(4:0)`, 4-4-4 RGB + `vga_hs/vs`).
2. **Clocking** — replace the DE10 PLL (`max10_pll_*`) with `clk_wiz_0` (MMCM, 100 MHz in →
   core + sound clocks); the internal clock divider feeding the PS/2 path can be kept
   verbatim only if targeting JB1/JB3 — for the onboard USB HID host port, check its
   rate against the ≥6 MHz requirement in §3's keyboard-clock note first.
3. **Reset polarity** — DE10 uses an active-low key; Basys 3 uses active-high `btnC`.
4. **Core instantiation** — keep the core port map unchanged; wire `video_hs`/`video_vs` (often
   left `open` on the DE10) to feed the scandoubler.
5. **Video / scan doubler** — feed the core's native video (zero-extended to 6-bit) into the DECA
   `vga_scandoubler` (`enable_scandoubling`/`disable_scaneffect = 1`), narrow the 6-bit output to
   the Basys 3 4-bit/color connector; gate RGB on `blankn` before the doubler; wire the core's
   active-low HS/VS directly to the doubler's active-low inputs. Clock `clkvideo`/`clkvga` to give
   the ~2× read/write ratio for real horizontal doubling.
6. **Audio** — keep the PWM accumulator; drive mono `O_PMODAMP2_AIN`; route the sound-enable and
   gain switches to `O_PMODAMP2_SHUTD` / `O_PMODAMP2_GAIN`.
7. **Inputs** — keep the keyboard (`io_ps2_keyboard` + `kbd_joystick`) on the onboard USB-HID
    connector by default; OR-merge the JA joystick (inverted
   active-low → active-high to match the core boundary); coin/start via fire+direction combos;
   P2 mirrors P1.
8. **PROM VHDL** — generated from the staged romset (never distributed).

## 5. Shared conventions & hard rules

- **Non-nested project layout**: the `.xpr` lives directly in `basys3/` as
  `basys3/<machine>_basys3.xpr`, with the sources tree at `basys3/<machine>_basys3.srcs/`.
- **Vivado build scripts run from `/tmp`** so `vivado.log` / `vivado.jou` stay out of the repo.
- **Tool/path resolution** is `ENV_VAR → project default → interactive prompt`:
  - Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
  - roms: `ROMZIP` → `~/roms/`
- **Roms and generated PROM VHDL are copyrighted content** — never commit or
  distribute them. The `*.patch` files are the tracked record of changes to pristine Dar sources.
