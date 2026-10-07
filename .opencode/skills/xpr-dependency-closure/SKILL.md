---
name: xpr-dependency-closure
description: Build a Vivado .xpr source list for a Dar core by transitive entity-work closure over cached archives using unzip -p streaming (no extraction), classify the video/scandoubler path, and author the .xpr by template substitution. Use when creating or editing a <game>_basys3.xpr or deciding which sources a Basys3 project needs.
---

# Building a Dar core's Vivado source list and .xpr

Companion skills: `port-dar-machine` (full port workflow),
`vivado-batch-build` (running Vivado).

## Dependency closure without extraction

Work directly on the cached archive in `dloads/`:

```
unzip -Z1 dloads/vhdl_<game>_rev_X.zip | sort                 # inventory
unzip -p dloads/<archive>.zip <path>/<game>.vhd \
  | grep -n 'entity work\.'                                   # fan-out
```

Iterate from the top module: for every `entity work.<name>`, locate the file
defining that entity (or Verilog module of the same name), add it, repeat to
fixpoint. Expect roughly: clocking wrappers, CPU library set (T80s =
T80_Pack/T80/T80_ALU/T80_MCode/T80_Reg/T80s), gen_ram, io_ps2_keyboard,
kbd_joystick, video/audio modules, PROM VHDLs, top level.

Never extract archives into the repo; extracted trees are build artifacts
(reproducible via setup scripts, removed by `make clean`).

Typical exclusions (present in trees but not elaborated): Altera PLL
replacements, 7-segment decoders, de10_lite top levels, unused CPU-library
variants.

## Video-path classification

Determines whether create_project.sh imports an external scandoubler. Confirm
by reading the wrapper's sync mux and vertical counter, not by trusting
filenames:

| Signature in the core | Video path | Machines |
|---|---|---|
| No `tv15Khz_mode`; wrapper drives `vga_hs <= csync` (15 kHz composite sync) | External MiST scandoubler needed | Galaga, Burnin-Rubber |
| Internal `line_doubler` instantiation | Doubles internally; no external doubler | Bagman, Berzerk |
| Progressive branch under `tv15Khz_mode='0'`: vcnt counts 524/525, pix_ena ~20 MHz comment | Native progressive 31 kHz | Kick, Popeye, Sky Skipper, Solar Fox |
| Ships DECA `vga_scandoubler.v` | Ported with that module | none in sf-darfpga since 2026-10-05 (Time Pilot, Pooyan moved to MiST `scandoubler.v`); still in `other/` and `red-bote/` Arcade_Pooyan / Arcade_Zaxxon |

## Authoring the .xpr

Clone `Galaga-Midway-by-Dar/contrib/basys3/vivado/galaga_basys3.xpr` and
substitute:

- Project name / TopModule (appears in both sources_1 and sim_1 configs)
- FileSet `sources_1` File entries: one per closed-over source; PROM VHDLs are
  referenced too (generated locally under `tools/<game>_unzip/`, relative
  paths into the extracted tree)
- Fresh GUID for the project `Id` (`uuidgen | tr -d '-'`)
- Runs / `AutoIncrementalDir` paths carrying the old project name
- Part/board stay fixed: `xc7a35tcpg236-1`, board `basys3`, DSABoardId
  `basys3`

Stale `Path="..."` attributes pointing at files Vivado does not manage are
harmless; prefer minimal correct entries over copying noise. Constraints: a
single `constrs_1` FileSet importing `Basys-3-Master.xdc` from
`imports/digilent-xdc-master/`.

## Verification

1. XML well-formedness (`xmllint --noout` or python ElementTree).
2. Count `<File Path=` entries vs expected closure (remember the XDC entry).
3. `grep TopModule` shows `<game>_basys3` in both configs.
4. Open-in-Vivado smoke test (see `vivado-batch-build`): warnings about the
   not-yet-generated clk_wiz_0 wrappers are expected between create_prj and
   clk_wiz steps; missing *source* files are not.
