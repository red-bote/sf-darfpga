#!/bin/bash
# Normalize one text file in place (PORTING_SPEC.md section 2, step 3): CRLF/CR -> LF,
# trailing whitespace stripped, final newline. Check: content with all whitespace removed
# is unchanged, else the file is restored and the script fails. Binary files are left
# alone. Idempotent. Used on fix-patch targets only; Dar's other files stay as shipped.
#
# Usage: normalize_file.sh <file>

set -euo pipefail

f="${1:?usage: normalize_file.sh <file>}"

grep -Iq . "$f" || exit 0   # binary

squash() { tr -d ' \t\r\n\f\v' < "$1"; }

before="$(mktemp)"
cp "$f" "$before"

sed -i -e 's/\r$//' -e 's/\r/\n/g' -e 's/[ \t]*$//' "$f"
[ -n "$(tail -c1 "$f")" ] && echo >> "$f"

status=0
if ! cmp -s <(squash "$before") <(squash "$f"); then
    echo "error: non-whitespace change in $f; restored" >&2
    cp "$before" "$f"
    status=1
fi
rm -f "$before"
exit "$status"
