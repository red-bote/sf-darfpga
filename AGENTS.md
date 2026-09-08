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
a `README.md`. Currently all 20 machine dirs are ports.

New ports start from the generic templates in `wip/machine/`: the project
`wip/machine/contrib/basys3/basys3-project-template.xpr`, its in-project
constraints `basys3-project-template.srcs/constrs_1/imports/
digilent-xdc-master/Basys-3-Master.xdc`, the per-machine Makefile
`wip/machine/Makefile.template`, and the tokenized build-script templates
under `wip/machine/contrib/` (`tools/`, `basys3/tools/`, `basys3/vivado/`).
The ported `.xpr` and `.xdc` derive from the sample project
(`basys3-project-template.xpr` + its in-project `Basys-3-Master.xdc`).

## Repo layout

- Each `<Machine>-by-Dar/` owns its own `Makefile`, `contrib/`, and
  `PORTING_SPEC.md`.
- The root `Makefile` delegates to per-machine Makefiles:
  `make <step>-<machine>` (e.g. `make setup-galaga`, `make synth-pooyan`).
- Root `README.md` is the machine index with clock frequencies, project names,
  and romsets.
- Each machine's `README.md` is the single source of truth for that machine's
  design and build.
- `tools/vhdl_formatter.py` — stdlib-only VHDL indent/alignment formatter
  (`--check`, `--align`, `--indent N`).
- `downloads.md` — index of archived Dar source zips (SourceForge URL + SHA
  pattern); consult when a `setup_<machine>.sh` needs an archive URL/hash.

## Build workflow (per machine)

Steps must run in order. From the machine directory:

1. `make setup` — fetches Dar source archive (SHA-256 verified), applies
   synthesis-fix patches, compiles `make_vhdl_prom`, converts the `.bat` to
   `.sh`, stages romsets, generates PROM VHDL.
2. `make create_prj` — creates Vivado project, copies `.xpr`/`.xdc`, imports
   scandoubler. (Not all machines have this step.)
3. `make clk_wiz` — generates `clk_wiz_0` MMCM IP (100 MHz → core clocks).
4. `make patch` — regenerates top-level wrapper and porting patch.
5. `make synth` — synthesis only (resets `synth_1` first).
6. `make bitstream` — implementation + `write_bitstream`.
7. `make clean` — removes the Vivado project/build tree only.

Root-level shorthand: `make all-galaga`, `make bitstream-pooyan`, etc.

**Root Makefile covers only 13 of the 20 ports** (Galaga, Pooyan, Time Pilot,
Bagman, Berzerk, Tron, Kick, BurgerTime, Defender, Traverse-USA, Crazy Kong,
Crazy Climber, Sky Skipper).
Burnin-Rubber, Popeye, Phoenix, Solar-Fox, Computer-Space,
Xevious, and Zaxxon each have a machine-level `Makefile` but no root
delegation — build those with `make <step>` from inside the machine directory. Root step names are hyphenated
(`create-prj-galaga`, `clk-wiz-galaga`); per-machine Makefile targets use
underscores (`create_prj`, `clk_wiz`). Run `make help` for the current step
matrix.

## Tool / path resolution

`ENV_VAR → project default → interactive prompt`:
- Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
- ROMs: `ROMZIP` → `~/roms/<set>.zip` (some machines use `ROMZIP2`)

**Vivado builds run from `/tmp`** so `vivado.log`/`vivado.jou` stay outside the
repo.

`contrib/basys3/vga_scandoubler.v` is the canonical cleanroom import — **never
modify it**.

## Copyright hard rule

Roms and generated PROM VHDL are copyrighted content — **never commit or
distribute** them. `.patch` files are the tracked record of changes to
pristine Dar sources.

## VHDL formatting

Run `tools/vhdl_formatter.py` on VHDL files. Dependency-free (stdlib only).
Idempotent. `--check` for CI, `--align` for column alignment.

## Common gotchas

- Directory naming is not uniform: `Bagman-FPGA-Dar` and `Berzerk-FPGA-by-Dar`
  differ from the `-by-Dar` convention; `Sky-skipper-by-Dar` uses a lowercase `s`.
- Machines needing two romsets (Tron, Galaga, Popeye) require the extra set for
  color PROMs, CPU/speech ROMs absent from the plain set (resolved via `ROMZIP2`).
- Some ports are scripted but not yet through `make synth`/`make bitstream`
  (e.g. Xevious); the root `README.md` Status
  section is the current record of each machine's verified state.
