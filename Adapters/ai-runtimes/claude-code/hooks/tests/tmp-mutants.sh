#!/usr/bin/env bash
# TEMPORARY (WU-IAENG-359 Linux red-run evidence, branch tmp/wu359-linux-red,
# never merged). Applies each mutant of tmp-mutants.txt to its own disposable
# copy of the framework and runs tests/drift.sh against it, printing the
# result line and every FAIL line. The checkout itself is never mutated.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../../../../.." && pwd)"
SPEC="$HERE/tmp-mutants.txt"
echo "== tmp: Linux red runs for WU-IAENG-359 ($(uname -s), $(id -un), bash $BASH_VERSION)"
echo "-- green: unmutated tests/drift.sh"
bash "$HERE/drift.sh" 2>&1 | grep -E '^   (FAIL|info)|result' | sed 's/^/   /'
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  name="${line%% ||| *}"; rest="${line#* ||| }"
  rel="${rest%% ||| *}"; rest="${rest#* ||| }"
  old="${rest%% ||| *}"; new="${rest#* ||| }"
  d="$(mktemp -d)"
  cp -R "$SRC/Adapters" "$SRC/Registry" "$SRC/Core" "$SRC/Templates" "$d/"
  cp "$SRC/.gitattributes" "$d/"
  content="$(cat "$d/$rel"; printf x)"; content="${content%x}"
  case "$content" in *"$old"*) ;; *) echo "-- $name: OLD NOT FOUND in $rel"; continue ;; esac
  printf '%s' "${content/"$old"/"$new"}" > "$d/$rel"
  echo "-- mutant $name: $rel: $old  ->  $new"
  timeout 900 bash "$d/Adapters/ai-runtimes/claude-code/hooks/tests/drift.sh" 2>&1 \
    | grep -E '^   FAIL|^         \||result' | sed 's/^/   /'
done < "$SPEC"
echo "== tmp: end of Linux red runs"
exit 0
