---
name: port-dar-machine
description: Checklist for onboarding a new Dar hardware platform as a Basys3 port - authoring contrib/tools/setup_<game>.sh and prep_roms.sh, the machine Makefile, create_project.sh, and README updates. Use when adding or porting a new <Machine>-by-Dar directory or its scripts.
---

# Porting a new Dar machine to Basys3

Procedure only; facts live in each machine's `README.md` and the root
`README.md`. Terminology and scope rules: `.opencode/rules.md`. Companion
skills: `xpr-dependency-closure` (.xpr authoring), `romset-forensics`
(romset availability), `vivado-batch-build` (running builds).

## Work order

1. Identify the upstream archive
2. `contrib/tools/setup_<game>.sh`
3. `contrib/tools/prep_roms.sh`
4. Machine `Makefile`
5. `contrib/basys3/vivado/create_project.sh` + `.xpr`
6. Top-level wrapper / patch generator
7. Docs
8. Verification ladder

## 1. Upstream archive

- darfpga SourceForge pattern:
  `https://sourceforge.net/projects/darfpga/files/Software%20VHDL/<folder>/<archive>.zip/download`
- The zip's top-level folder equals the archive basename; that name is
  `SRC_DIR` everywhere (e.g. `vhdl_bagman_rev_0_1_2018_06_05`) - used by every
  script and the Makefile `clean` target.
- Download once, compute SHA-256, embed it in the setup script.

## 2. setup_<game>.sh

Clone an existing one (`Bagman-FPGA-Dar/contrib/tools/setup_bagman.sh` is the
minimal reference). Structure:

1. `fetch_zip`: cache into `<machine>/dloads/` (tracked in git for sf-darfpga machines; commit a new archive there); reuse only if the
   embedded SHA-256 matches; re-download and re-verify otherwise; hard-fail on
   mismatch after download.
2. Extract into the repo root as `$SRC_DIR/`.
3. Patch loop, idempotent (`patch -p1 --forward`), globbing both
   `contrib/*/code/*.patch` and `contrib/code/*.patch`.
4. Chain into `prep_roms.sh`.

Patch-loop exclusions (document each in the header comment):

- `*_de10_lite_to_basys3.patch`: generated record of the top-level rewrite;
  it applies to a different target file, never to the pristine tree.
- `*scandoubler_fix.patch`: applied later by create_project.sh to the imported
  scandoubler copy, not to the pristine tree.

## 3. prep_roms.sh

Clone `Bagman-FPGA-Dar/contrib/tools/prep_roms.sh`:

1. Compile the host PROM generator:
   `gcc "$SRC_DIR/tools/tools_prom_src/src/make_vhdl_prom.c" -lm` (path varies
   per machine - check the extracted tree).
2. Convert the `.bat` to `.sh` with sed (table below).
3. Unzip romset(s) into `$SRC_DIR/tools/<game>_unzip/`; `ROMZIP` env override,
   default `$HOME/roms/<game>.zip`. Multi-romset machines list several zips
   (Popeye needs popeyeu.zip for its unprotected speech ROMs).
4. Run the converted script there.

.bat -> .sh conversion (exact sed rules, order matters):

```
s/\r$//                                  strip CRLF
/^rem/d                                  drop remark lines
s/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/   binary concat -> cat redirect
s/ \+ / /g                               collapse multiple spaces
s/^make_vhdl_prom /.\/make_vhdl_prom /
s/^del /rm /
```

then prepend `#!/bin/bash` and `chmod +x`.

Pitfalls:

- Use `/^rem/d`, NOT `/^rem /d`: bare `rem` lines (no trailing space) survive
  the spaced pattern and later cause exit 127 when the converted script runs.
- Verify by diffing the generated `.sh` against the `.bat` before running it.
- If the `.bat` expects a file the obvious romset lacks, see
  `romset-forensics` before adding ROMZIP dependencies.

## 4. Machine Makefile

Clone the Galaga structure exactly - a faithful template even for doc-only
ports whose deep targets fail until their basys3 assets are ported:

```
TOOLS        := contrib/tools
BASYS3_TOOLS := contrib/basys3/tools
VIVADO       := contrib/basys3/vivado
```

Targets: `all` (setup clk_wiz patch), `setup`, `create_prj`, `clk_wiz` (needs
setup + create_prj), `patch`, `synth` (resets synth_1 first), `bitstream`,
`clean` (removes `$SRC_DIR`). Substitute `<game>` everywhere including the
clean dir name.

Root `Makefile` delegation uses `<step>-<machine>` (hyphenated at root,
underscore inside the machine dir) and is added per machine as its tooling
matures; bare `make` prints help.

## 5. create_project.sh + .xpr

Clone an existing variant; the header must state why no external scandoubler
is imported (or why one is). Steps 1-3: mkdir project dirs, copy
`<game>_basys3.xpr` into `$SRC_DIR/basys3/`, copy `Basys-3-Master.xdc` into
`constrs_1/imports/digilent-xdc-master/`. Variants:

- Galaga / Burnin-Rubber: also imports mist/scandoubler.v (+ applies its fix).
- All others: no scandoubler import (internal doubler or native progressive).

Source-list construction and video-path classification: see
`xpr-dependency-closure`. Naming: project/top entity `<game>_basys3`
everywhere (.xpr name, srcs dir, top VHDL, TopModule entries).

## 6. Top-level wrapper / patch generator

Clone Galaga's `contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh`
(Bagman's is the no-scandoubler reference). Structure:

1. Author the target `<game>_basys3.vhd` as a heredoc in a /tmp scratch dir.
2. Emit a git-style patch: `diff -u` of pristine
   `rtl_dar/<game>_de10_lite.vhd` vs target, with `a/...`/`b/...` labels and
   `|| [ $? -eq 1 ]` to tolerate diff's files-differ exit code.
3. `mkdir -p "$(dirname "$PATCH")"` before writing - `contrib/basys3/code/`
   may not exist on first run.
4. Place the target at
   `$SRC_DIR/basys3/<game>_basys3.srcs/sources_1/new/<game>_basys3.vhd`
   (the path the .xpr references).

Constrained-ports rule: the shared `Basys-3-Master.xdc` ships with LEDs and
btnU/btnL/btnR/btnD commented out (only `btnC` among buttons is active).
Declare only ports the XDC constrains. Declaring unconstrained ports fails
placement with `Place 30-58` ("unplaced terminals ... greater than number of
available sites (0)") wrapped in `Place 30-99 IO Clock Placer failed`; fix by
dropping the ports, never by editing the shared XDC.

MMCM/reset structure - project standard going forward (Bagman pattern):

```vhdl
reset <= btnC or not mmcm_locked;   -- core in reset while pressed OR MMCM unlocking

clk_wiz_0 port map( ..., reset => btnC, locked => mmcm_locked );
```

btnC (active-high) drives both the MMCM reset and, via the `!locked` gating,
the core reset. Existing ports keep their own patterns (Galaga leaves the
MMCM unreset); do not retrofit unless asked.

## 7. Docs

Machine `README.md` sections, in order: title `(Basys 3 port)` + header
bullets (upstream link, project/top entity, clk_wiz MMCM values, video path),
`Features supported`, `IO mapping` (rows must correspond to XDC-constrained
ports actually declared), `Scripted setup` (cache / SHA-256 / patch
chain / prep chain, `$ROMZIP` defaults), `ROM set required`, fix-patch
sections (each with a verify grep), `Known issues`.

Root `README.md`: Status row, Machine index entry, Common build workflow if
the workflow changed, video classification note.

Terminology: hardware = FPGA platform; machine = hardware + romset. Say
roms/romset; describe machines, not games (upstream filenames keep their
names).

## 8. Verification ladder

1. `bash -n` every touched script.
2. End-to-end `make setup` with real romsets; confirm generated PROM VHDLs.
3. Tamper test: corrupt the cached zip, rerun, expect re-download + pass.
4. `make -n <targets>` dry runs for Makefile wiring.
5. Timing-equivalence audit, before the first synth, wherever a fix patch
   or the wrapper replaces a RAM, ROM or primitive in Dar's clock-enable
   designs (fast `clk` plus enables). Record results in the machine's
   `PORTING_SPEC.md`.
   - RAM/ROM port table: per port, clock, enable, write enable, read
     latency (async / every `clk` / on enable), read-during-write.
     Compare against the original primitive (often left as a comment)
     and any sibling port of the same core. A dropped read enable shifts
     a pipeline by one pixel and shows only on hardware (precedent: the
     root repo's `pinballwiz/TangNano9K-Pacman` sprite line buffer,
     vertical bar on sprite right edges).
   - Registers that ignore the clock enable: classify each as harmless
     (address stable for the whole enable period) or a defect, with the
     reason.
   - Sibling diff: diff each module against a working port of the same
     core before the first build.
   - Literals into Verilog modules instantiated from VHDL without a
     component declaration: route through typed signals (`Synth 8-2398`
     "N visible types match"). Vivado `check_syntax` is parse-only and
     does not catch this.
6. Vivado runs: see `vivado-batch-build`.
