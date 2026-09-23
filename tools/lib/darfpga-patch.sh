#!/bin/bash
# Shared "place the Basys3 top-level VHDL + regenerate its provenance patch"
# logic for sf-darfpga Dar-convention ports.
#
# Source (not exec'd) from a machine's
# contrib/basys3/tools/make_de10_lite_to_basys3_patch.sh, then call
# darfpga_place_top_level with that machine's parameters.
#
# The Basys3 top-level wrapper is a real, git-tracked file at
# contrib/basys3/code/<top-entity>.vhd -- edit it directly, format it with
# sf-darfpga/tools/vhdl_formatter.py. It is no longer authored as a bash
# here-doc.
#
# The diff-against-pristine-upstream step below produces a provenance
# record only: it documents how the tracked top level differs from Dar's
# pristine (untracked, gitignored) upstream file. It is NOT consumed by the
# build -- the Vivado project picks up the tracked .vhd via the
# unconditional copy regardless of the diff's outcome.
#
# Requires the pristine tree (run `make setup` first).
#
# Optional flag for a machine-specific quirk (most machines don't need it):
#   --de10-dir DIR  upstream source dir holding the DE10-lite top level,
#     relative to $src_dir (default: rtl_dar) -- Computer-Space's pristine
#     tree uses rtl/ instead.
darfpga_place_top_level() {
    local root="" src_dir="" de10_top="" top_entity="" de10_dir="rtl_dar"
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) root="$2"; shift 2 ;;
            --src-dir) src_dir="$2"; shift 2 ;;
            --de10-top) de10_top="$2"; shift 2 ;;
            --top-entity) top_entity="$2"; shift 2 ;;
            --de10-dir) de10_dir="$2"; shift 2 ;;
            *) echo "darfpga_place_top_level: unknown argument: $1" >&2; return 2 ;;
        esac
    done
    if [ -z "$root" ] || [ -z "$src_dir" ] || [ -z "$de10_top" ] || [ -z "$top_entity" ]; then
        echo "darfpga_place_top_level: --root, --src-dir, --de10-top, --top-entity are all required" >&2
        return 2
    fi

    local src="$root/$src_dir/$de10_dir/$de10_top"
    local target="$root/contrib/basys3/code/$top_entity.vhd"
    local target_src="$root/$src_dir/basys3/$top_entity.srcs/sources_1/new"
    local patch_file="$root/contrib/basys3/code/${top_entity%_basys3}_de10_lite_to_basys3.patch"

    if [ ! -f "$src" ]; then
        echo "error: pristine source not found: $src" >&2
        echo "Run 'make setup' first to populate $src_dir/." >&2
        return 1
    fi
    if [ ! -f "$target" ]; then
        echo "error: tracked top-level VHDL not found: $target" >&2
        echo "Author it once; every 'make patch' then regenerates the provenance patch and re-places it, it does not overwrite it." >&2
        return 1
    fi

    mkdir -p "$(dirname "$patch_file")"
    {
        printf 'diff --git a/%s/%s/%s b/%s/%s/%s\n' "$src_dir" "$de10_dir" "$de10_top" "$src_dir" "$de10_dir" "$de10_top"
        diff -u --label "a/$src_dir/$de10_dir/$de10_top" \
                  --label "b/$src_dir/$de10_dir/$de10_top" \
                  "$src" "$target" || [ $? -eq 1 ]   # diff returns 1 when files differ (expected)
    } > "$patch_file"

    mkdir -p "$target_src"
    cp -f "$target" "$target_src/$top_entity.vhd"

    echo "Generated patch:  $patch_file"
    echo "Placed target:    $target_src/$top_entity.vhd"
    echo "Verify with:      patch -p1 --dry-run < contrib/basys3/code/$(basename "$patch_file")"
}
