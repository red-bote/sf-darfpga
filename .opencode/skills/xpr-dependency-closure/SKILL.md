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
video/audio modules, PROM VHDLs, the Basys 3 wrapper, `clk_wiz_0`, the MiST scandoubler
import where used. `kbd_joystick.vhd` is listed in every existing project but no longer
instantiated (the wrapper decodes the keys, `PORTING_SPEC.md` §4.3); a new port may omit
it.

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
| No `tv15Khz_mode`; 15 kHz composite sync only | External MiST scandoubler (`contrib/code/scandoubler.v` + fix patch) | Burger-Time, Burnin-Rubber, Computer-Space, Defender, Galaga, Phoenix, Pooyan, Time-Pilot, Traverse-USA, Xevious, Zaxxon |
| Internal `line_doubler` instantiation under `tv15Khz_mode` | Doubles internally; no external doubler | Bagman, Berzerk, Crazy-Kong |
| Progressive branch under `tv15Khz_mode='0'`: vcnt counts 524/525 | Native progressive 31 kHz | Kick, Popeye, Satans-Hollow, Sky-skipper, Solar-Fox, Tron |

## Authoring the .xpr

Clone the tracked `.xpr` of the closest machine
(`Pooyan-by-Dar/contrib/basys3/vivado/pooyan_basys3.xpr` for a MiST-scandoubler machine)
and substitute:

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
