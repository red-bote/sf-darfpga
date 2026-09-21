# AGENTS.md

Operational guidance for AI sessions in this repository. See also
`.opencode/rules.md` for terminology, filesystem scope, and git rules.

Detailed porting/procedure how-tos live in `.opencode/skills/`:
`port-dar-machine`, `vivado-batch-build`, `xpr-dependency-closure`,
`romset-forensics`. Consult them before starting a port or running a Vivado
build.

## What this repo is

FPGA ports of Dar's arcade hardware (`darfpga@aol.fr`) to the Digilent Basys 3
(Artix-7 `xc7a35tcpg236-1`), built with Vivado 2020.2. Each machine is an
independent project under its own `<Machine>-by-Dar/` directory.

A directory is an actual Basys 3 port if it has `contrib/`, a `Makefile`, and
a `README.md`. Currently 20 machine dirs qualify. `Crazy-Climber-by-Dar/` is
documented in the root `README.md` and has root Makefile targets, but the
directory does not exist yet — treat anything about Crazy Climber as
aspirational.

New ports start from the generic templates in `wip/machine/`: the project
`wip/machine/contrib/basys3/basys3-project-template.xpr`, its in-project
constraints `basys3-project-template.srcs/constrs_1/imports/
digilent-xdc-master/Basys-3-Master.xdc`, the per-machine Makefile
`wip/machine/Makefile.template`, and the tokenized build-script templates
under `wip/machine/contrib/` (`tools/`, `basys3/tools/`, `basys3/vivado/`).
The ported `.xpr` and `.xdc` derive from the sample project.

## Repo layout

- Each `<Machine>-by-Dar/` owns its own `Makefile`, `contrib/`, `README.md`,
  and a `PORTING_SPEC.md` (canonical location `contrib/basys3/PORTING_SPEC.md`;
  Galaga, Pooyan, Time-Pilot still have it at the machine top level).
- The root `Makefile` delegates to per-machine Makefiles:
  `make <step>-<machine>` (e.g. `make setup-galaga`, `make synth-pooyan`).
- Root `README.md` is the machine index with clock frequencies, project names,
  romsets, and the per-machine Status (scripted / synthesized / bitstream /
  hardware-verified) — the authoritative status record.
- Each machine's `README.md` is the single source of truth for that machine's
  design and build (IO pinout, MMCM constants, verify greps).
- `tools/vhdl_formatter.py` — stdlib-only VHDL indent/alignment formatter
  (`--check`, `--align`, `--indent N`).
- Archive URL + SHA-256 for each machine's Dar source are **embedded in
  `contrib/tools/setup_<game>.sh`**, not in a separate index.

## Build workflow (per machine)

Steps must run in order. From the machine directory:

1. `make setup` — fetches Dar source archive into the gitignored `dloads/`
   cache (SHA-256 verified), extracts it, applies synthesis-fix patches,
   compiles `make_vhdl_prom`, converts the `.bat` to `.sh`, stages romsets,
   generates PROM VHDL.
2. `make create_prj` — `contrib/basys3/vivado/create_project.sh` lays down the
   project tree and copies `.xpr`/`.xdc`/scandoubler into it. Every machine
   exposes this step; `setup` does not copy the ported assets.
3. `make clk_wiz` — generates `clk_wiz_0` MMCM IP (100 MHz → core clocks).
4. `make patch` — regenerates top-level wrapper and porting patch.
5. `make synth` — synthesis only (resets `synth_1` first).
6. `make bitstream` — implementation + `write_bitstream`.
7. `make clean` — removes the Vivado project/build tree only.

Root-level shorthand: `make all-galaga`, `make bitstream-pooyan`, etc.
Aggregates over all machines: `make clean` (delegated) and `make bitstream`
(sweep that builds only machines lacking an `impl_1` `.bit`, skipping
already-built ones; long-running Vivado sweep).

**The root `Makefile` delegates every step for all 20 present machine dirs.**
Its targets, `.PHONY` list, and `make help` matrix are all generated from the
single `PORTS` list (`token:directory`), so the matrix cannot drift. Root step
names are hyphenated (`create-prj-galaga`, `clk-wiz-galaga`); per-machine
Makefile targets use underscores (`create_prj`, `clk_wiz`).

## Tool / path resolution

`ENV_VAR → project default → interactive prompt`:
- Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
- romsets: `ROMZIP` → `~/roms/<set>.zip`; two-romset machines add `ROMZIP2`
  (Galaga uses `ROMZIP1` + `ROMZIP2`)

**Vivado builds run from `/tmp`** so `vivado.log`/`vivado.jou` stay outside the
repo.

`contrib/basys3/code/vga_scandoubler.v` (the DECA scandoubler, per-machine
import for Pooyan and Time-Pilot) is a cleanroom import — **never modify
it**. Same for the `mist/scandoubler.v` import under `contrib/code/` where
present.

## Copyright hard rule

Roms and generated PROM VHDL are copyrighted content — **never commit or
distribute** them. `.patch` files are the tracked record of changes to
pristine Dar sources.

## VHDL formatting

Run `tools/vhdl_formatter.py` on VHDL files. Dependency-free (stdlib only).
Idempotent. `--check` for CI, `--align` for column alignment. There is no
automated test suite; verification is patch dry-runs + formatter `--check` +
Vivado synthesis/timing (status in root `README.md`).

## Common gotchas

- Directory naming is not uniform: `Bagman-FPGA-Dar` and `Berzerk-FPGA-by-Dar`
  differ from the `-by-Dar` convention; `Sky-skipper-by-Dar` uses a lowercase `s`.
- Machines needing two romsets (Galaga, Tron, Popeye) require the extra set for
  color PROMs, CPU/speech ROMs absent from the plain set (resolved via
  `ROMZIP2`).
- Some ports are scripted but not yet through `make synth`/`make bitstream`
  (e.g. Xevious, Satans-Hollow); the root `README.md` Status section is the
  current record of each machine's verified state.
- `Crazy-Climber-by-Dar/` has a README stanza but no directory, so it is
  deliberately **not** in the root Makefile `PORTS` list — there are no
  `*-crazy-climber` targets.
- Don't trust other agents' doc (e.g. `CLAUDE.md`) for counts/status — they
  drift; the root `Makefile` and `README.md` Status are the live record.