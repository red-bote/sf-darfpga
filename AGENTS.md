# AGENTS.md

Operational guidance for AI sessions in this repository. See also
`.opencode/rules.md` for terminology, filesystem scope, and git rules.

The porting procedure for a new Dar core is `PORTING_SPEC.md`. The authoritative rule and
skill set for Dar work is this tree's `.opencode/` (`rules.md`; skills
`port-dar-machine`, `vivado-batch-build`, `xpr-dependency-closure`,
`romset-forensics`); the copies at the workspace top level point here. Consult them before
starting a port or running a Vivado build.

## What this repo is

FPGA ports of Dar's arcade hardware (`darfpga@aol.fr`) to the Digilent Basys 3
(Artix-7 `xc7a35tcpg236-1`), built with Vivado 2020.2. Each machine is an
independent project under its own `<Machine>-by-Dar/` directory.

A directory is an actual Basys 3 port if it has `contrib/`, a `Makefile`, and
a `README.md`. Currently 20 machine dirs qualify, every one listed in the root
`Makefile` `PORTS` table.

New ports are scaffolded by `tools/new-port.sh` from the templates in `wip/machine/`
(Makefile, scripts, XDC, `.xpr`, skeleton wrapper, README and PORTING_SPEC templates);
reference machine `Pooyan-by-Dar` (`PORTING_SPEC.md` §2).

## Repo layout

- Each `<Machine>-by-Dar/` owns its own `Makefile`, `contrib/`, `README.md`,
  and a `contrib/basys3/PORTING_SPEC.md`.
- The root `Makefile` delegates to per-machine Makefiles:
  `make <step>-<machine>` (e.g. `make setup-galaga`, `make synth-pooyan`).
- Root `README.md` is the machine index with clock frequencies, project names,
  romsets, and a one-line status per machine.
- Each machine's `README.md` carries its dated `## Status`, controls, switches and IO;
  its `contrib/basys3/PORTING_SPEC.md` carries the design detail.
- `tools/vhdl_formatter.py` — stdlib-only VHDL indent/alignment formatter
  (`--check`, `--align`, `--indent N`).
- Archive URL + SHA-256 for each machine's Dar source are **embedded in
  `contrib/tools/setup_<game>.sh`**, not in a separate index.

## Build workflow (per machine)

Steps must run in order. From the machine directory:

1. `make setup` — uses the Dar source archive in `dloads/` (tracked in git;
   fetched from SourceForge only if missing or the SHA-256 differs), extracts it, applies synthesis-fix patches,
   compiles `make_vhdl_prom`, converts the `.bat` to `.sh`, stages romsets,
   generates PROM VHDL.
2. `make create_prj` — `contrib/basys3/vivado/create_project.sh` lays down the
   project tree and copies `.xpr`/`.xdc`/scandoubler into it. Every machine
   exposes this step; `setup` does not copy the ported assets.
3. `make clk_wiz` — generates `clk_wiz_0` MMCM IP (100 MHz → core clocks).
4. `make patch` — places the tracked wrapper `contrib/basys3/code/<top>.vhd` in the
   project and regenerates the provenance patch.
5. `make check` — parse-only Vivado `check_syntax` (`tools/check-syntax.sh`); no
   synthesis, allowed without a user request.
6. `make synth` — synthesis only (resets `synth_1` first). User request only.
7. `make bitstream` — implementation + `write_bitstream`. User request only.
8. `make load` — program the existing `.bit` into SRAM (`openFPGALoader`).
9. `make clean` — removes the extracted tree and Vivado project only.

Root-level shorthand: `make all-galaga`, `make bitstream-pooyan`, etc.
Aggregates over all machines: `make clean` (delegated) and `make bitstream`
(sweep that builds only machines lacking an `impl_1` `.bit`, skipping
already-built ones; long-running Vivado sweep).

**The root `Makefile` delegates every step for the 20 `PORTS`-listed machines.**
Its targets, `.PHONY` list, and `make help` matrix are all generated from the
single `PORTS` list (`token:directory`), so the matrix cannot drift. Root step
names are hyphenated (`create-prj-galaga`, `clk-wiz-galaga`); per-machine
Makefile targets use underscores (`create_prj`, `clk_wiz`).

## Tool / path resolution

`ENV_VAR → project default → interactive prompt`:
- Vivado: `VIVADO` → `/tools/Xilinx/Vivado/2020.2/bin/vivado`
- romsets: `ROMZIP` → `~/roms/<set>.zip`; two-romset machines: Galaga and Popeye
  `ROMZIP1` + `ROMZIP2`, Tron `ROMZIP` + `ROMZIP2` (`midssio.zip`)

**Vivado builds run from `/tmp`** so `vivado.log`/`vivado.jou` stay outside the
repo.

The MiST `scandoubler.v` import under `contrib/code/` (Burger-Time,
Burnin-Rubber, Computer-Space, Defender, Galaga, Phoenix, Pooyan, Time-Pilot,
Traverse-USA, Xevious, Zaxxon) is a cleanroom import — **never modify it**;
Vivado fixes go in `contrib/code/scandoubler_fix.patch`, applied to the
project copy.

## Copyright hard rule

Roms and generated PROM VHDL are copyrighted content — **never commit or
distribute** them. `.patch` files are the tracked record of changes to
pristine Dar sources.

## VHDL formatting

Run `tools/vhdl_formatter.py` on VHDL files. Dependency-free (stdlib only).
Idempotent. `--check` for CI, `--align` for column alignment. There is no
automated test suite; verification is `make check` (parse-only `check_syntax`),
`make patch` run twice (provenance patch unchanged), formatter `--check`, then Vivado
synthesis/timing and the hardware checklist (`PORTING_SPEC.md` §7, §8) on the user's
request.

## Common gotchas

- Directory naming is not uniform: `Bagman-FPGA-Dar` and `Berzerk-FPGA-by-Dar`
  differ from the `-by-Dar` convention; `Sky-skipper-by-Dar` uses a lowercase `s`.
- Machines needing two romsets (Galaga, Tron, Popeye) require the extra set for
  color PROMs, CPU/speech ROMs absent from the plain set (resolved via
  `ROMZIP2`).
- Each machine README `## Status` is the current record of its verified state; the
  root `README.md` Status section summarizes it.
- Don't trust other agents' doc (e.g. `CLAUDE.md`) for counts/status — they
  drift; the root `Makefile` `PORTS` list and the present machine dirs are the
  live record (the root `README.md` Status can lag a dir removal).