---
name: port-dar-machine
description: Checklist for porting a new Dar (darfpga) core to Basys 3 in sf-darfpga - scaffold with tools/new-port.sh, setup and rom-prep scripts, clock, tracked .xpr/.xdc, tracked wrapper, make check, docs. Use when adding a new <Machine>-by-Dar directory or changing an existing machine's scripts.
---

# Porting a new Dar machine to Basys 3

The procedure, conventions and per-machine tables are in `PORTING_SPEC.md` (this tree);
this skill is the working checklist and the pitfalls. Rules: `.opencode/rules.md`.
Companion skills: `xpr-dependency-closure` (.xpr source list), `romset-forensics`
(romset availability), `vivado-batch-build` (running Vivado). Reference machine:
`Pooyan-by-Dar`.

## Work order

1. Upstream archive and core reading (`PORTING_SPEC.md` §2 step 1)
2. Scaffold: `tools/new-port.sh`
3. `contrib/tools/setup_<game>.sh`, `prep_roms.sh`; `make setup`
4. Clock: `make_clk_wiz_0.sh` (`PORTING_SPEC.md` §5); `make clk_wiz`
5. `.xpr` source list, XDC (`xpr-dependency-closure`); `make create_prj`
6. Wrapper `contrib/basys3/code/<top>.vhd` (`PORTING_SPEC.md` §4); `make patch`
7. `make check`; smoke test (below)
8. Docs (`PORTING_SPEC.md` §9)
9. User: `make bitstream`, `make load`, hardware checklist (`PORTING_SPEC.md` §8)

## 1. Upstream archive

- darfpga SourceForge pattern:
  `https://sourceforge.net/projects/darfpga/files/Software%20VHDL/<folder>/<archive>.zip/download`
- The zip's top-level folder usually equals the archive basename; that name is
  `SRC_DIR` (e.g. `vhdl_bagman_rev_0_1_2018_06_05`). A zip without a top folder needs
  `--flat-archive` (Phoenix).
- Download once, compute SHA-256, embed it in the setup script; commit the zip in
  `<machine>/dloads/` (tracked).

## 2. Scaffold

`tools/new-port.sh <game> --src-dir <dir> --url <url> --sha256 <sum> --de10-top <file>
--top-entity <game>_basys3`. It fills the `wip/machine/` templates (Makefile, setup,
prep_roms, create_project, make_clk_wiz_0, patch and bitstream wrappers, XDC, skeleton
wrapper, README and PORTING_SPEC templates) and adds the machine to the root `PORTS`.
Afterwards: `grep -rn '<[a-z_]*>' <Machine>/` must find no leftover tokens.

## 3. setup_<game>.sh and prep_roms.sh

`setup_<game>.sh` is a thin call to `darfpga_setup()` (`tools/lib/darfpga-setup.sh`):
SHA-256 checked cache in `dloads/`, extract, apply `contrib/*/code/*.patch` and
`contrib/code/*.patch` with `patch -p1 --forward`, then `prep_roms.sh`.

Patch-loop exclusions (built into the library): `*_de10_lite_to_basys3.patch`
(provenance record, different target file) and `*scandoubler_fix.patch` (applied to the
project copy by `create_project.sh`). A machine with extra provenance-only patches passes
`--extra-exclude` (Computer-Space). Setup normalizes each patch target (whitespace
only, `tools/normalize_file.sh`) before applying; author fix patches as LF diffs against
the normalized file.

Pitfall: `patch --forward` is not idempotent on its own (it exits 1 and writes a `.rej`
on an already-applied patch). `darfpga_setup` is safe because `unzip -o` restores the
pristine files before the patch loop. A script that patches without re-extracting must
guard each patch with a reverse dry run:

```bash
if (cd "$ROOT" && patch -p1 -R --dry-run --forward < "$p" > /dev/null 2>&1); then
    echo "==> already applied, skipping $p"
else
    (cd "$ROOT" && patch -p1 --forward < "$p")
fi
```

`prep_roms.sh` (clone `Pooyan-by-Dar/contrib/tools/prep_roms.sh`):

1. `gcc "$SRC_DIR/tools/.../make_vhdl_prom.c" -lm` (path varies; check the tree).
2. `.bat` → `.sh`, exact sed rules, order matters:
   ```
   s/\r$//                                  strip CRLF
   /^rem/d                                  drop remark lines
   s/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/   binary concat -> cat redirect
   s/ \+ / /g                               join operands
   s/^make_vhdl_prom /.\/make_vhdl_prom /
   s/^del /rm /
   ```
   then prepend `#!/bin/bash` and `chmod +x`.
3. Unzip the romset(s): `ROMZIP` (default `$HOME/roms/<set>.zip`); two sets use
   `ROMZIP1` + `ROMZIP2` (Galaga, Popeye) or `ROMZIP` + `ROMZIP2` (Tron, `midssio.zip`).
4. Run the converted script.

Pitfalls:

- `/^rem/d`, not `/^rem /d`: bare `rem` lines survive the spaced pattern (exit 127).
- Diff the generated `.sh` against the `.bat` before running it.
- A wrong or incomplete romset fails silently (`cat` writes an empty file;
  `make_vhdl_prom` writes nothing). Add a pre-flight check (every input file the script
  names exists in the unzip dir) and a post-flight check (every expected `.vhd` exists and
  is non-empty), each listing exactly what is missing.
- Translate the generated script's filenames to the romset's naming rather than renaming
  rom files. Missing files: `romset-forensics`.

## 4. Makefile

Variables `GAME`, `SRC_DIR`, `TOP_ENTITY`, `DISPLAY_NAME`, `IO_SUMMARY`, `DISPLAY_HINT`
(`sw(13) ...`), then `include ../tools/mk/machine.mk`. Targets: `all` (setup clk_wiz
patch), `setup`, `create_prj`, `clk_wiz`, `patch`, `check`, `synth`, `bitstream`, `load`
(program existing `.bit` into SRAM with `openFPGALoader -b basys3`, volatile),
`rebuild-load`, `clean`, `help`. Root `Makefile`: add the directory to `PORTS`
(`make <step>-<machine>`).

## 5. Project (.xpr, XDC)

- Tracked `contrib/basys3/vivado/<top>.xpr` and `Basys-3-Master.xdc`; `create_project.sh`
  copies both into `<SRC_DIR>/basys3/` (non-nested), imports the MiST scandoubler when the
  video path needs it (`PORTING_SPEC.md` §4.5) and applies `scandoubler_fix.patch` to the
  copy.
- Source list: `xpr-dependency-closure`. Naming: `<game>_basys3` for project, srcs dir,
  wrapper file and top entity.
- Declare only ports the XDC constrains; an unconstrained port fails placement with
  `Place 30-58` inside `Place 30-99 IO Clock Placer failed`. The XDC enables exactly the
  lines the wrapper uses (JXADC with `PULLUP true`, all five buttons, `sw[0..15]`, USB-HID
  `ps2_clk`/`ps2_dat`, JA amp pins, VGA, `clk`).

## 6. Wrapper

- Start from the skeleton `wip/machine/contrib/basys3/code/TOP_ENTITY.vhd.template` and
  `Pooyan-by-Dar/contrib/basys3/code/pooyan_basys3.vhd`. Rules: `PORTING_SPEC.md` §4.
- The wrapper is a tracked file, edited directly. `make patch` places it in the project
  and regenerates `contrib/basys3/code/<de10top>_de10_lite_to_basys3.patch` (provenance
  record; name from the DE10 top, e.g. `ckong` for Crazy-Kong). Run `make patch` twice:
  the patch bytes must not change.
- Reset: `reset <= btnC or not mmcm_locked`; MMCM `reset => btnC`.
- Expression actuals through signals; literals into Verilog modules instantiated from
  VHDL through typed signals (`Synth 8-2398`); concatenations inside a type conversion
  through a typed signal (`Synth 8-944`). `check_syntax` does not catch the last two.
- Format: `tools/vhdl_formatter.py`.

## 7. Verification ladder

1. `bash -n` every touched script.
2. `make setup` with the real romset(s); confirm the generated PROM VHDL files.
3. Tamper test: corrupt the cached zip, rerun, expect re-download and pass.
4. `make -n <targets>` for Makefile wiring.
5. `make check` (parse-only, `PORTING_SPEC.md` §7).
6. Read-only project smoke test (no run launched): open the project, confirm every
   `get_files` entry exists. Write the Tcl as a file in `/tmp`, run
   `vivado -mode batch -nolog -nojournal -source smoke.tcl` from `/tmp`:
   ```tcl
   open_project /path/to/<top>.xpr
   set missing 0
   foreach f [get_files -quiet] {
       if { ![file exists $f] } { puts "MISSING: $f"; incr missing }
   }
   puts "MISSING_COUNT: $missing"
   close_project
   ```
7. Timing-equivalence audit before the first synth, wherever a fix patch or the wrapper
   replaces a RAM, ROM or primitive in Dar's clock-enable designs (fast `clk` plus
   enables); record in the machine PORTING_SPEC:
   - RAM/ROM port table: per port, clock, enable, write enable, read latency (async /
     every `clk` / on enable), read-during-write; compare with the original primitive and
     any sibling port. A dropped read enable shifts a pipeline by one pixel and shows only
     on hardware.
   - Registers that ignore the clock enable: harmless (address stable for the enable
     period) or a defect, with the reason.
   - Sibling diff against a working port of the same core.
8. Synthesis and bitstream only on the user's explicit request: `vivado-batch-build`.

## 8. Docs

`PORTING_SPEC.md` §9: machine README and PORTING_SPEC from the `wip/machine/` templates,
Makefile `IO_SUMMARY`/`DISPLAY_HINT`, root README index row, root `PORTS`,
§3.1/§3.2 rows, `CLOCK_CRYSTAL_CATALOG.md`, `CLOCKING_SPEC.md`, `KNOWN_ISSUES.md`.
Terminology: hardware = FPGA platform; machine = hardware + romset; say roms/romset.

