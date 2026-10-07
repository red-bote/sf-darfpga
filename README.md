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
confirmed PS/2 keyboard, sound, and VGA display all working; keyboard is on
the onboard USB-HID host (C17/B17), hardware-confirmed. JA joystick and
btnU/D/L/R are wired through `contrib/code/phoenix_external_inputs.patch`
(core `ext_joy` port), hardware-confirmed 2026-10-02. See
`Phoenix-by-Dar/contrib/basys3/PORTING_SPEC.md` and root `KNOWN_ISSUES.md`
for the full design record.

Xevious-by-Dar is fully scripted, documented, and hardware-verified on the
Basys 3 (assets authored end to end from the Galaga/Phoenix reference; same
imported `mist/scandoubler.v` core-family wiring with
`xevious_expose_hsync_vsync.patch`, apply-verified on the pristine CRLF
tree).

Traverse-USA-by-Dar is fully scripted, documented, and hardware-brought-up
on the Basys 3. Unlike the DE10 original (keyboard only), the Basys3 port
adds a JA joystick OR-merged with the keyboard and dedicated coin/start
buttons; keyboard is on the onboard USB-HID connector, hardware-confirmed.
See the machine `README.md`/`PORTING_SPEC.md` for the scandoubler wiring,
patch, and clock-rate detail.

Crazy-Kong-by-Dar is hardware-verified on the Basys 3 (bitstream 2026-09-07;
0 critical warnings/errors through implementation; post-route
WNS = 36.461 ns — a single 12 MHz core clock leaves huge timing margin).
Native 31 kHz progressive video (no external scandoubler); keyboard is on
the onboard USB-HID connector, hardware-confirmed. See the machine
`README.md`/`PORTING_SPEC.md` for the synthesis-fix patch and design detail.

Sky-Skipper-by-Dar is fully scripted, documented, synthesized, and
bitstream-built (0 critical warnings/errors through implementation;
post-route WNS = 21.853 ns; 1906 LUTs / 815 FFs / 18.5 BRAM tiles, no black
boxes). One closure bug surfaced at implementation -- an initially-incomplete
source list left the modular T80 CPU as a black box (`[DRC INBB-3]`); fixed
by listing all 25 sources (see `PORTING_SPEC.md`). Hardware-verified
(31 kHz VGA + USB-HID keyboard + JA joystick + PWM audio) with the default
`sw(13)=0` bitstream; `sw(13)` alone is the display-mode control. See the
machine `README.md`/`PORTING_SPEC.md` for controls and design detail.

Satans-Hollow-by-Dar is fully scripted, documented, synthesized,
bitstream-built, and hardware-verified on the Basys 3 (native progressive
31 kHz video — no scandoubler; USB-HID keyboard on the onboard connector;
mono left-channel PWM audio). See the machine `README.md`/`PORTING_SPEC.md`
for the romset/PROM and controls detail.

Every machine directory now carries a scripted setup: `contrib/tools/setup_<game>.sh`
(uses the Dar archive in `dloads/`, tracked in git and fetched from SourceForge
only if missing or the embedded SHA-256 check fails, extracts it, applies any synthesis-fix patches) chaining into
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
| Bagman (Stern 1982) | 12.288 MHz | `basys3/bagman_basys3.xpr`, `bagman_basys3` | `bagman_xor_width.patch` | `bagman.zip` |
| Burnin' Rubber (Data East 1982) | 12 MHz | `basys3/burnin_rubber_basys3.xpr`, `burnin_rubber_basys3` | `burnin_rubber_vsync_before_vblank.patch` | `brubber.zip` |
| BurgerTime (Data East 1982) | 12 MHz | `basys3/burger_time_basys3.xpr`, `burger_time_basys3` | — | `btime.zip` |
| Defender (Williams 1981) | 12 + 7.159 MHz (/2 = 3.58) | `basys3/defender_basys3.xpr`, `defender_basys3` | — | `defender.zip` |
| Galaga (Namco/Midway 1981) | 36.864 MHz | `basys3/galaga_basys3.xpr`, `galaga_basys3` | `galaga_bgpalette_xor_length_fix.patch`, `galaga_credit_mode_fix.patch`, `galaga_vga_sync.patch` | `galaga.zip` + `galagamw.zip` |
| Kick (Midway MCR 1981) | 40 MHz | `basys3/kick_basys3.xpr`, `kick_basys3` | — | `kick.zip` |
| Popeye (Nintendo 1982) | 40.32 MHz | `basys3/popeye_basys3.xpr`, `popeye_basys3` | `popeye_linmix_sensitivity.patch` | `popeye.zip` + `popeyeu.zip` |
| Phoenix (Amstar 1980) | 11 + 50 MHz | `basys3/phoenix_basys3.xpr`, `phoenix_basys3` | `phoenix_expose_hsync_vsync.patch` | `phoenix.zip` |
| Pooyan (Konami 1982) | 24.574 MHz | `basys3/pooyan_basys3.xpr`, `pooyan_basys3` | `pooyan_de10_lite_to_basys3.patch`, `pooyan_t80_xor_width.patch`, `pooyan_single_domain.patch`, `pooyan_vcnt_264_lines.patch` | `pooyan.zip` |
| Satans/Hollow (Bally Midway MCR 1981) | 40 MHz | `basys3/satans_hollow_basys3.xpr`, `satans_hollow_basys3` | — | `shollow.zip` |
| Sky Skipper (Nintendo 1981) | 40.32 MHz | `basys3/sky_skipper_basys3.xpr`, `sky_skipper_basys3` | — | `skyskipr.zip` |
| Solar Fox (Bally Midway 1981) | 40 MHz | `basys3/solar_fox_basys3.xpr`, `solar_fox_basys3` | — | `solarfox.zip` |
| Time Pilot (Konami 1982) | 24.574 MHz | `basys3/time_pilot_basys3.xpr`, `time_pilot_basys3` | `time_pilot_single_domain.patch`, `time_pilot_vcnt_264_lines.patch` | `timeplt.zip` |
| Tron (Midway MCR 1982) | 40 MHz | `basys3/tron_basys3.xpr`, `tron_basys3` | — | `tron.zip` + `kick.zip` (color PROM) |
| Traverse USA / Zippy Race (Irem 1983) | 36.842 + 7.159 MHz (/2 = 3.58) | `basys3/traverse_usa_basys3.xpr`, `traverse_usa_basys3` | `traverse_usa_expose_video_timing.patch`, `traverse_usa_de10_lite_to_basys3.patch` | `travrusa.zip` |
| Xevious (Namco 1982) | 18.432 MHz | `basys3/xevious_basys3.xpr`, `xevious_basys3` | `xevious_expose_hsync_vsync.patch` | `xevious.zip` |
| Zaxxon (Gremlin/Sega 1980) | 24.329 MHz | `basys3/zaxxon_basys3.xpr`, `zaxxon_basys3` | `zaxxon_hflip_xor_width.patch`, `zaxxon_expose_video_timing.patch` | `zaxxon.zip` |
| Computer Space (Nutting Associates 1971) | 48 MHz | `basys3/computer_space_basys3.xpr`, `computer_space_basys3` | `computer_space_de10_lite_to_basys3.patch`, `computer_space_motion_q_assoc.patch`, `computer_space_rocket_timer_synth_fix.patch` | — (discrete-game core, no romset) |
| Crazy Kong (Kyoei/Falcon 1981) | 12.288 MHz | `basys3/ckong_basys3.xpr`, `ckong_basys3` | `ckong_xor_width.patch`, `ckong_de10_lite_to_basys3.patch` | `ckong.zip` |

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
   uses the Dar source archive in the machine's `dloads/` (tracked in git;
   SHA-256 verified against the hash embedded in the script; re-downloaded from
   SourceForge when missing or tampered), extracts it as `vhdl_<machine>_rev_.../`, applies any
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

Tool/path resolution follows the standard `ENV_VAR → project default →
interactive prompt` convention — see `AGENTS.md` §"Tool / path resolution".

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
All 20 machines are on the onboard USB-HID connector (none remain on the
legacy JB PS/2 header) as of 2026-09-29. Several needed a new, independent
keyboard-clock divider to meet the onboard host's ≥ 6 MHz `io_ps2_keyboard`
floor — see each machine README for the specific divider used.
Video is 31 kHz progressive VGA; scan doubling is either built into the core or
added via an imported scandoubler. Per machine: Galaga, Burnin' Rubber,
Phoenix, Computer Space, Xevious, Traverse-USA, and Zaxxon import
`mist/scandoubler.v`
(their cores output 15 kHz only; Phoenix's, Xevious's, Traverse-USA's, and
Zaxxon's cores
needed a patch to expose hsync/vsync in the first place, unlike
Galaga/Burnin-Rubber's native ones — see
`Phoenix-by-Dar/contrib/basys3/PORTING_SPEC.md`); Time Pilot and Pooyan
use the same MiST `scandoubler.v` (since 2026-10-05); Bagman and Berzerk instantiate Dar's
`line_doubler` inside the core; Kick, Popeye, Sky Skipper, Solar Fox, Crazy
Kong, and Satans/Hollow generate progressive 31 kHz natively in the core
(`tv15Khz_mode = '0'`).
Of these, all six (Kick, Popeye, Sky Skipper, Solar Fox, Crazy Kong, and
Satans/Hollow) select the mode via `sw(13)` alone (0 = 31 kHz VGA default,
1 = 15 kHz TV) — changed 2026-09-29 from a mix of F8-only and `sw(13)`-XOR-F8
toggles to a single consistent convention.

## Backlog

None currently.

## Shared tools

`tools/vhdl_formatter.py` normalizes VHDL indentation to a fixed width per level
(`--indent`, default 2) and can optionally align `<=` and `:` columns (`--align`).
It is dependency-free (stdlib only), in-place or `--check`, and idempotent.

## Copyright

Roms and the generated PROM VHDL are copyrighted content and are
never committed or distributed. The `.patch` files are the tracked record of
changes to pristine Dar sources.
