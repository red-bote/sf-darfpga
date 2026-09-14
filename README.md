# FPGA ports to the Digilent Basys 3

Ports of Dar's FPGA hardware projects (`darfpga@aol.fr`, <http://darfpga.blogspot.fr>)
to the Digilent Basys 3 (Artix-7, part `xc7a35tcpg236-1`), by Red~Bote. Each
machine is an independent project under its own `<Machine>-by-Dar/` directory,
built with Vivado 2020.2.

Operational rules live in `.opencode/rules.md` and `AGENTS.md` (terminology,
git, filesystem scope, tool paths). Each machine's `README.md` is the single
source of truth for that machine's design and build.

## Status

### The following are complete, fully-scripted, hardware-verified ports:
Bagman-FPGA-Dar
Berzerk-FPGA-by-Dar
Burger-Time-by-Dar
Burnin-Rubber-by-Dar
Computer-Space-by-Dar
Crazy-Climber-by-Dar
Crazy-Kong-by-Dar
Defender-by-Dar
Galaga-Midway-by-Dar
Kick-Midway-MCR-by-Dar
Phoenix-by-Dar
Pooyan-by-Dar
Popeye-by-Dar
Satans-Hollow-by-Dar
Sky-skipper-by-Dar
Solar-Fox-by-Dar
Time-Pilot-by-Dar
Traverse-USA-by-Dar
Tron-by-Dar
Xevious-by-Dar
Zaxxon-by-Dar

Computer Space is a discrete-game core (no romset); see its README for the
dedicated controls (JA fire / pushbutton start) and rocket-missile fire fix.

Phoenix-by-Dar is fully scripted, synthesized, and bitstream-built
(0 critical warnings/errors through implementation). Hardware bring-up has
confirmed PS/2 keyboard, sound, and VGA display all working. Its core
otherwise exposed only composite sync and only a PS/2 keyboard input,
unlike every other machine in this project; `contrib/code/phoenix_expose_hsync_vsync.patch`
(a two-file patch) exposes real hsync/vsync from the core for the imported
MiST scandoubler, replacing an earlier wrapper-only composite-sync
separator that hardware-tested with no display. A separate patch adding
external control ports (JA joystick / dedicated buttons) was tried and
hardware-tested with no input registering at all; a repo-wide search found
no other core in this project needed a similar patch, so there was no
validated reference to debug against, and it has been reverted — Phoenix
is PS/2-keyboard only. See
`Phoenix-by-Dar/contrib/basys3/PORTING_SPEC.md` for the full design
record.

Xevious-by-Dar is fully scripted and documented (assets authored end to end
from the Galaga/Phoenix reference; same imported `mist/scandoubler.v`
core-family wiring with `xevious_expose_hsync_vsync.patch`, which is
apply-verified on the pristine CRLF tree). It has not yet been synthesized or
hardware-verified: `make setup create_prj clk_wiz patch` are the next
exercisable steps before `make synth` / `make bitstream`.

Traverse-USA-by-Dar is fully scripted and documented (assets authored end to
end from the Galaga/Zaxxon/Computer-Space references; same imported
`mist/scandoubler.v` wiring with `traverse_usa_expose_video_timing.patch` and
the `traverse_usa_de10_lite_to_basys3.patch` wrapper rewrite, both
apply-verified on the pristine CRLF tree). Unlike the DE10 original (keyboard
only), the Basys3 port adds a JA joystick OR-merged with the keyboard and
dedicated coin/start buttons; the core has no genuine fire input, so up and
fire both accelerate (`traverse_usa.vhd:129`). It synthesizes cleanly and has
been hardware-brought up on the Basys 3; the keyboard is **always on the
onboard USB-HID connector (C17/B17), not JB**, driven at ~6.14 MHz (the
pristine ~3 MHz keyboard clock is too slow for the onboard USB-HID host —
same fix as Congo Bongo/Arcade_Zaxxon/Pooyan). See the machine
`README.md` for the keyboard-connector/clock note.

Crazy-Kong-by-Dar is hardware-verified on the Basys 3 (bitstream 2026-09-07;
0 critical warnings/errors through implementation; post-route
WNS = 36.461 ns — a single 12 MHz core clock leaves huge timing margin).
Single-clock design, native 31 kHz progressive video: the core's internal
`line_doubler` drives real `video_hs`/`video_vs`, so the port needs no
imported scandoubler and no expose patch. The one pristine-tree change is the
synthesis-width fix `ckong_xor_width.patch` (`ckong.vhd:405-408` 13-bit vs
5-bit `xor`, the same video-addressing bug `bagman_xor_width.patch` fixes,
constants zero-padded to 13 bits — no behavior change). The keyboard is
**always on the onboard USB-HID connector (C17/B17), not JB**, already clocked
at `clock_12` = 12 MHz (no divider needed). See the machine `README.md` for
controls and the keyboard note.

Crazy-Climber-by-Dar is fully scripted and documented (assets authored end to
end from the Crazy Kong reference: same single-12-MHz-clock, native-31-kHz
progressive video family — the core's internal `line_doubler` drives real
`video_hs`/`video_vs`, so no imported scandoubler or expose patch; and the
`xor`-width operand is already parenthesized, so no synthesis-fix patch either,
unlike Crazy Kong/Bagman). It is a **two-joystick** machine (`l_*`/`r_*` stick
ports per player): the Basys3 wrapper maps the keyboard arrows to the left
stick by default and the right stick while Space (or JA7) is held, OR-merged
with a JA joystick, with dedicated btnU/btnD coin and btnL/btnR start. The
keyboard is **always on the onboard USB-HID connector (C17/B17), not JB**,
already clocked at `clock_12` = 12 MHz (no divider needed). The full
authoring/verification ladder (SHA-verified archive, patch dry-run, PROM-width
 audit, and a Vivado read-only source-closure smoke test) passed with 0 missing
 files and TOP `crazy_climber_basys3`. It has **not yet been synthesized or
 hardware-verified**: `make setup create_prj clk_wiz patch` are run and the
 read-only smoke test passes; `make synth` / `make bitstream` / `make load`
 are the next exercisable steps, pending explicit go-ahead.

Sky-Skipper-by-Dar is fully scripted and documented (assets authored end to
end from the Solar Fox/Kick references: same 40 MHz single-clock,
native-progressive audio/video family — the core drives real
`video_hs`/`video_vs` itself on a 20 MHz pixel clock, F8 toggles
progressive/interlaced, so no imported scandoubler or expose patch; and every
XOR is full-expression-width with `std_logic_unsigned` padding the constant
to the full width, so no synthesis-fix patch either, unlike Crazy
Kong/Bagman). The keyboard is **on the Basys3 onboard USB-HID connector
(c17/B17)**, clocked directly on `clock_40` (40 MHz, ≥ 6 MHz needed by the
onboard USB-HID host); the pristine 2 MHz `clock_kbd` divider was dropped from
the keyboard path and is retained only as the `clock_div` gate for the PWM
audio accumulator — it is **not** retargeted (the USB-HID host needs an
independent fast clock, per the shared-divider warning below); JA1-4 + JA7
fire are OR-merged with the keyboard
and btnU/btnD/btnL/btnR give coin1/coin2/start1/start2. `sw1`/`sw2` keep the
pristine hard-coded constant dips. The full authoring/verification ladder
(SHA-verified archive, patch dry-run + idempotency, ROM-set pre/post-flight,
PROM-width audit, and formatter-clean wrapper) passes. The port is
synthesized and bitstream-built (0 critical warnings/errors through
implementation; post-route WNS = 21.853 ns on the 40 MHz core clock;
1906 LUTs / 815 FFs / 18.5 BRAM tiles, no black boxes — the modular T80
CPU is fully implemented). One closure bug surfaced at implementation: the
initial 21-file project carried only `T80_Pack.vhd` + `T80se.vhd`, but
`T80se.vhd` is a thin wrapper around the modular `T80`
(`T80.vhd` instantiates `T80_MCode`/`T80_ALU`/`T80_Reg`), so `T80` was a
black box and `opt_design` failed `[DRC INBB-3]`; the `.xpr` now lists all
25 sources. Hardware-verified (31 kHz VGA + USB-HID keyboard + JA joystick +
PWM audio) with the default `sw(13)=0` bitstream; the display mode selector
(`sw(13)` = 31 kHz VGA / 15 kHz TV, XORed with the F8 keyboard toggle) is the
single user-facing display control.

Satans-Hollow-by-Dar is a fully scripted, documented port of Dar's Bally Midway
MCR core (native progressive 31 kHz video — no scandoubler; single 40 MHz clock
via `clk_wiz_0`; USB-HID keyboard on the onboard connector, JA1=Left/JA2=Right/
JA7=Fire joystick, mono left-channel PWM audio on PmodAMP2, `sw(13)`⊕F8 display
mode). The source archive fetch, SHA-256 integrity, `.bat` conversion and the
single-romset pre/post-flight (`~/roms/shollow.zip`, including the midssio
`82s123.12d` PROM renamed to `midssio_82s123.12d`) all pass, and all 6 PROM
VHDLs are generated; the wrapper rewrite is formatter-clean and its
`satan_hollow_de10_lite_to_basys3.patch` is generated. `make setup` / `make
patch` are exercised; `make synth` + `make bitstream` + hardware bring-up are
still pending.

Every machine directory now carries a scripted setup: `contrib/tools/setup_<game>.sh`
(fetches the Dar archive into a gitignored `dloads/` cache with an embedded
SHA-256 check, extracts it, applies any synthesis-fix patches) chaining into
`contrib/tools/prep_roms.sh` (compiles `make_vhdl_prom`, converts the
`make_<game>_proms.bat`, stages the romset(s), generates the PROM VHDL), plus a
`Makefile` wrapping both. Computer Space is the exception: it is a
discrete-game core with no romset or `make_*_proms.bat`, so its setup chains
`contrib/tools/gen_sound_roms.py` (compiles the sound-roms from Intel-HEX)
instead of `prep_roms.sh`.

## Machine index

| Machine | Core clock | Project / top entity | Patch | Romset(s) |
|---|---|---|---|---|
| Berzerk (Stern 1980) | 10 MHz | `basys3/berzerk_basys3.xpr`, `berzerk_basys3` | `berzerk_reset_sensitivity.patch` | `berzerk.zip` |
| Bagman (Stern 1982) | 12 MHz | `basys3/bagman_basys3.xpr`, `bagman_basys3` | `bagman_xor_width.patch` | `bagman.zip` |
| Burnin' Rubber (Data East 1982) | 12 + 6 MHz | `basys3/burnin_rubber_basys3.xpr`, `burnin_rubber_basys3` | — | `brubber.zip` |
| BurgerTime (Data East 1982) | 12 + 6 MHz | `basys3/burger_time_basys3.xpr`, `burger_time_basys3` | — | `btime.zip` |
| Defender (Williams 1981) | 12 + 3.58 MHz | `basys3/defender_basys3.xpr`, `defender_basys3` | — | `defender.zip` |
| Galaga (Namco/Midway 1981) | 36 MHz | `basys3/galaga_basys3.xpr`, `galaga_basys3` | `galaga_bgpalette_xor_length_fix.patch`, `galaga_credit_mode_fix.patch`, `galaga_vga_sync.patch` | `galaga.zip` + `galagamw.zip` |
| Kick (Midway MCR 1981) | 40 MHz | `basys3/kick_basys3.xpr`, `kick_basys3` | — | `kick.zip` |
| Popeye (Nintendo 1982) | 40.32 MHz | `basys3/popeye_basys3.xpr`, `popeye_basys3` | `popeye_linmix_sensitivity.patch` | `popeye.zip` + `popeyeu.zip` |
| Phoenix (Amstar 1980) | 11 + 50 MHz | `basys3/phoenix_basys3.xpr`, `phoenix_basys3` | `phoenix_expose_hsync_vsync.patch` | `phoenix.zip` |
| Pooyan (Konami 1982) | 12 + 14 MHz | `basys3/pooyan_basys3/pooyan_basys3.xpr`, `pooyan_basys3` | `pooyan_de10_lite_to_basys3.patch`, `pooyan_t80_xor_width.patch` | `pooyan.zip` |
| Satans/Hollow (Bally Midway MCR 1981) | 40 MHz | `basys3/satans_hollow_basys3.xpr`, `satans_hollow_basys3` | — | `shollow.zip` |
| Sky Skipper (Nintendo 1981) | 40 MHz | `basys3/sky_skipper_basys3.xpr`, `sky_skipper_basys3` | — | `skyskipr.zip` |
| Solar Fox (Bally Midway 1981) | 40 MHz | `basys3/solar_fox_basys3.xpr`, `solar_fox_basys3` | — | `solarfox.zip` |
| Time Pilot (Konami 1982) | 12.288 + 14.318 MHz | `basys3/time_pilot_basys3.xpr`, `time_pilot_basys3` | — | `timeplt.zip` |
| Tron (Midway MCR 1982) | 40 MHz | `basys3/tron_basys3.xpr`, `tron_basys3` | — | `tron.zip` + `kick.zip` (color PROM) |
| Traverse USA / Zippy Race (Irem 1983) | 36.86 + 3.58 MHz | `basys3/traverse_usa_basys3.xpr`, `traverse_usa_basys3` | `traverse_usa_expose_video_timing.patch`, `traverse_usa_de10_lite_to_basys3.patch` | `travrusa.zip` |
| Xevious (Namco 1982) | 18 + 11 MHz | `basys3/xevious_basys3.xpr`, `xevious_basys3` | `xevious_expose_hsync_vsync.patch` | `xevious.zip` |
| Zaxxon (Gremlin/Sega 1980) | 24 MHz | `basys3/zaxxon_basys3.xpr`, `zaxxon_basys3` | `zaxxon_hflip_xor_width.patch`, `zaxxon_expose_video_timing.patch` | `zaxxon.zip` |
| Computer Space (Nutting Associates 1971) | 6 + 50 MHz | `basys3/computer_space_basys3.xpr`, `computer_space_basys3` | `computer_space_de10_lite_to_basys3.patch`, `computer_space_motion_q_assoc.patch`, `computer_space_rocket_timer_synth_fix.patch` | — (discrete-game core, no romset) |
| Crazy Kong (Irem M-52 1981) | 12 MHz | `basys3/ckong_basys3.xpr`, `ckong_basys3` | `ckong_xor_width.patch`, `ckong_de10_lite_to_basys3.patch` | `ckong.zip` |
| Crazy Climber (Nichibutsu 1980) | 12 MHz | `basys3/crazy_climber_basys3.xpr`, `crazy_climber_basys3` | `crazy_climber_de10_lite_to_basys3.patch` | `cclimber.zip` |

Directory naming is not uniform: `Bagman-FPGA-Dar` and `Berzerk-FPGA-by-Dar`
differ from the `-by-Dar` convention; `Sky-skipper-by-Dar` uses a lowercase `s`.

The `—` patch entries mark machines that need no synthesis-fix patch. Machines
needing two romsets (`galaga`, `popeye`) require the extra set for CPU/speech
ROMs absent from the plain set. A `—` in the Romset(s) column means the machine
has no romset at all (Computer Space is a discrete-game core with no MAME ROMs).

## Common build workflow

New ports are bootstrapped from the generic templates in `wip/machine/`
(Makefile, build-script templates, and the sample Basys 3 Vivado project);
see the root `PORTING_SPEC.md` for the full bring-up procedure.

Per machine, from its own directory (see the machine's `README.md` for the exact
file names, MMCM constants, and verify commands):

1. **Run `make setup`** (or `contrib/tools/setup_<game>.sh` directly). This
   fetches the Dar source archive into the machine's gitignored `dloads/` cache
   (SHA-256 verified against the hash embedded in the script; re-downloaded when
   missing or tampered), extracts it as `vhdl_<machine>_rev_.../`, applies any
   synthesis-fix patches, and chains into `contrib/tools/prep_roms.sh`, which
   compiles `make_vhdl_prom`, converts `make_<game>_proms.bat` to `.sh`, stages
   the romset(s) from `$ROMZIP`/`$ROMZIP2` (default `~/roms/<set>.zip`), and
   generates the PROM VHDL referenced in place by the Vivado project.

The manual equivalents, if needed:

1. **Extract the Dar source** zip into the machine directory (`vhdl_<machine>_rev_.../`).
2. **Apply any synthesis-fix patch** (`patch -p1 < <machine>_*.patch`), then
   confirm it took with the `grep` given in the machine README.
3. **Generate the PROM VHDL** from the staged romset: unzip
   `~/roms/<set>.zip` into `tools/<machine>_unzip/`, then run
   `./make_<machine>_proms.sh` from that directory.
4. **Stage the Vivado project** (`contrib/basys3/vivado/create_project.sh`),
   **generate the `clk_wiz_0` MMCM IP** deriving the core clock(s) from the
   100 MHz Basys 3 oscillator, then **run synthesis/implementation from `/tmp`**
   so `vivado.log`/`vivado.jou` stay outside the repository.

Tool/path resolution is `ENV_VAR → project default → interactive prompt`:
Vivado `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`; roms `ROMZIP` →
`~/roms/`.

Each machine Makefile prints a display-mode reminder via its `make help` target and
at the end of `make all` / `make bitstream`: if nothing appears on the display after
loading the bitstream, first try toggling the display mode (F8 on the USB-HID keyboard,
or sw(13); per-machine detail in the machine README) before troubleshooting further.
`make all-<machine>` / `make bitstream-<machine>` show it too, because they delegate
to the machine `all` / `bitstream`. Machines with no display-mode toggle print no
reminder.

## Common Basys 3 platform

All ports share the same IO convention (see each machine README for the wrapper
port map): USB-HID keyboard on the onboard connector (`ps2_clk` = C17, `ps2_dat`
= B17), JA joystick (active-low, switch to GND)
OR-merged with it, mono (or left-channel) PWM audio on PmodAMP2 at JC, 4-4-4 RGB
VGA, and `btnC` = reset (active-high). `sw14` = sound enable, `sw15` = AMP gain.
Newer ports (Traverse USA, Crazy Kong, Crazy Climber, Sky Skipper) put the
keyboard on the onboard USB-HID connector; a few older ports still use the JB
PS/2 header with a slow pristine keyboard divider — the USB-HID convention
requires the `io_ps2_keyboard` clock to be independently ≥ 6 MHz (see the
shared-divider warning in `PORTING_SPEC.md`), so check each machine README.
Video is 31 kHz progressive VGA; scan doubling is either built into the core or
added via an imported scandoubler. Per machine: Galaga, Burnin' Rubber,
Phoenix, Computer Space, Xevious, Traverse-USA, and Zaxxon import
`mist/scandoubler.v`
(their cores output 15 kHz only; Phoenix's, Xevious's, Traverse-USA's, and
Zaxxon's cores
needed a patch to expose hsync/vsync in the first place, unlike
Galaga/Burnin-Rubber's native ones — see
`Phoenix-by-Dar/contrib/basys3/PORTING_SPEC.md`); Time Pilot and Pooyan
import `vga_scandoubler.v` (DECA); Bagman and Berzerk instantiate Dar's
`line_doubler` inside the core; Kick, Popeye, Sky Skipper, Solar Fox, Crazy
Kong, and Satans/Hollow generate progressive 31 kHz natively in the core
(`tv15Khz_mode = '0'`).
Of these, Sky Skipper's and Satans/Hollow's mode is selectable by `sw(13)`
(0 = 31 kHz VGA default,
1 = 15 kHz TV) XOR F8; the others are F8-toggled only.

## Shared tools

`tools/vhdl_formatter.py` normalizes VHDL indentation to a fixed width per level
(`--indent`, default 2) and can optionally align `<=` and `:` columns (`--align`).
It is dependency-free (stdlib only), in-place or `--check`, and idempotent.

## Copyright

Roms and the generated PROM VHDL are copyrighted content and are
never committed or distributed. The `.patch` files are the tracked record of
changes to pristine Dar sources.
