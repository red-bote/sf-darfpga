#!/bin/bash
# Shared setup logic for sf-darfpga Dar-convention Basys3 ports: fetch/verify
# the SourceForge source archive, extract it, apply fix patches, run rom-prep.
#
# Source (not exec'd) from a machine's contrib/tools/setup_<game>.sh, then
# call darfpga_setup with that machine's parameters. See
# sf-darfpga/PORTING_SPEC.md for the convention this implements.
#
# Optional flags for machine-specific quirks (most machines need neither):
#   --extra-exclude PATTERN  (repeatable) exclude another shell-glob-matched
#     patch from the generic apply loop, alongside the two hardcoded below --
#     for a machine with its own additional generated/provenance patches
#     (e.g. Computer-Space's motion-board patches, applied later to an
#     imported copy by create_project.sh, not to the pristine tree).
#   --binary  apply patches with `patch --binary` (preserves CRLF line
#     endings) instead of plain `patch` -- for a machine whose fix patches
#     are CRLF-sensitive (e.g. Computer-Space).
#   --flat-archive  extract the zip into $root/$src_dir/ directly, instead
#     of into $root/ (the default, for archives whose own top-level folder
#     already matches $src_dir) -- for a machine whose archive has no
#     internal top-level folder at all (e.g. Phoenix-by-Dar: its members
#     sit at the zip root).
#
# Roms and the generated PROM VHDL stay local (never distributed).

# Patches under contrib/*/code/*.patch and contrib/code/*.patch that must
# NEVER be applied to the pristine tree during setup, because they are
# provenance records of a generated target file, not fixes to apply:
#   *_de10_lite_to_basys3.patch -- authored by darfpga_place_top_level
#     (see darfpga-patch.sh), applied to a different target file.
#   *scandoubler_fix.patch -- applied later, to the imported scandoubler
#     copy, by create_project.sh, not to the pristine tree.
# This exclusion lives in exactly one place so it cannot drift out of sync
# per machine the way it once did: Popeye-by-Dar's setup_popeye.sh once
# omitted it, which corrupted its generated .patch file on a second
# `make patch` run.
_darfpga_setup_excluded() {
    local pattern="$1"; shift
    case "$pattern" in
        *_de10_lite_to_basys3.patch) return 0 ;;
        *scandoubler_fix.patch) return 0 ;;
    esac
    # Machine-specific extra exclusions (contrib/*/code/*.patch files that
    # are also provenance/generated records, not fixes to apply -- e.g.
    # Computer-Space's motion-board patches, applied later to an imported
    # copy by create_project.sh).
    local extra
    for extra in "$@"; do
        case "$pattern" in
            $extra) return 0 ;;
        esac
    done
    return 1
}

darfpga_setup() {
    local root="" src_dir="" url="" sha256="" binary="" flat_archive=""
    local extra_excludes=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) root="$2"; shift 2 ;;
            --src-dir) src_dir="$2"; shift 2 ;;
            --url) url="$2"; shift 2 ;;
            --sha256) sha256="$2"; shift 2 ;;
            --extra-exclude) extra_excludes+=("$2"); shift 2 ;;
            --binary) binary=1; shift ;;
            --flat-archive) flat_archive=1; shift ;;
            *) echo "darfpga_setup: unknown argument: $1" >&2; return 2 ;;
        esac
    done
    if [ -z "$root" ] || [ -z "$src_dir" ] || [ -z "$url" ] || [ -z "$sha256" ]; then
        echo "darfpga_setup: --root, --src-dir, --url, --sha256 are all required" >&2
        return 2
    fi

    local src_path="$root/$src_dir"
    local dload_dir="$root/dloads"
    local zip="$dload_dir/$src_dir.zip"

    _darfpga_step() { printf '\n==> %s\n' "$1"; }

    _darfpga_step "1/4 Fetching source archive (cached or verified)"
    mkdir -p "$dload_dir"
    if [ -f "$zip" ]; then
        local actual
        actual=$(sha256sum "$zip" | cut -d' ' -f1)
        if [ "$actual" = "$sha256" ]; then
            echo "Using cached source archive (SHA-256 verified)"
        else
            echo "WARNING: cached archive hash mismatch; re-downloading" >&2
            rm -f "$zip"
        fi
    fi
    if [ ! -f "$zip" ]; then
        wget -O "$zip" "$url"
        local actual
        actual=$(sha256sum "$zip" | cut -d' ' -f1)
        if [ "$actual" != "$sha256" ]; then
            echo "ERROR: downloaded archive failed SHA-256 integrity check" >&2
            rm -f "$zip"
            return 1
        fi
    fi

    _darfpga_step "2/4 Extracting $src_dir/ into repo root"
    mkdir -p "$src_path"
    if [ -n "$flat_archive" ]; then
        unzip -o "$zip" -d "$src_path"
    else
        unzip -o "$zip" -d "$root"
    fi

    _darfpga_step "3/4 Applying fix patches (contrib/*/code/*.patch and contrib/code/*.patch)"
    local p
    for p in "$root"/contrib/*/code/*.patch "$root"/contrib/code/*.patch; do
        [ -e "$p" ] || continue
        if _darfpga_setup_excluded "$p" "${extra_excludes[@]}"; then
            continue
        fi
        echo "==> applying $p"
        if [ -n "$binary" ]; then
            (cd "$root" && patch -p1 --forward --binary < "$p")
        else
            (cd "$root" && patch -p1 --forward < "$p")
        fi
    done

    _darfpga_step "4/4 Running rom-prep"
    "$root/contrib/tools/prep_roms.sh"

    echo
    echo "Setup complete. Source tree in:"
    echo "  $src_path"
}
