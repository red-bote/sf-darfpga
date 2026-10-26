---
name: romset-forensics
description: Find which romset zip provides a given ROM/PROM file - scan the ROMZIP directory by filename, byte-compare candidates across sets, resolve darfpga-vs-MAME naming mismatches. Use when a make_*_proms.bat expects a file missing from the obvious romset, or before adding a ROMZIP dependency.
---

# Romset forensics

Scope: the `$ROMZIP` dir (default `~/roms/`) is approved read territory.
Never add a romset dependency without byte-level confirmation.

## Scan all zips for a filename

```
for z in ~/roms/*.zip; do
  unzip -Z1 "$z" | grep -qi '<name>' && echo "$z"
done
```

Case-insensitive; upstream zip layouts vary. Inspect hits without extracting:

```
unzip -p ~/roms/<set>.zip <path/in/zip> | md5sum
```

Compare candidate bytes across every set carrying the file; identical hashes
mean one shared device, not independent copies.

## Precedents

- Shared color PROM inside the game zips (Midway MCR hardware): `82s123.12d`
  (renamed `midssio_82s123.12d` by the ports) ships inside kick.zip,
  solarfox.zip, and several other MCR sets - all byte-identical. Result: no
  separate midssio.zip dependency for those; each prep script unzips only its own
  machine's set and renames the file (guarded, so reruns are idempotent).
  Exception: tron.zip lacks the PROM; Tron's `prep_roms.sh` takes it from
  `ROMZIP2` (default `~/roms/midssio.zip`).
- darfpga-vs-MAME filename mismatches: the Dar archive's `.bat` may expect
  upstream names while local romsets use different ones. Fix by renaming
  during prep, with the full old->new mapping table documented in the
  machine's README (see `Berzerk-FPGA-by-Dar/README.md`), never silently.
- Genuine second romsets stay separate dependencies (Popeye: popeyeu.zip
  supplies the unprotected speech ROMs absent from popeye.zip).

## Decision rule

Prefer the copy that ships inside the machine's own romset over adding an
extra ROMZIP dependency. Document any rename/mapping in the machine README;
keep prep scripts idempotent (guard renames).
