#!/usr/bin/env bash
# IA Engineering — Claude Code PreToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Mechanically enforces Standards/CODE_QUALITY_STANDARD.md, No Inline
# Suppression: refuses an edit that writes a linter / type-checker / test
# disable directive into code. A rule that is wrong for the project is tuned in
# the tool's configuration file, where the change is a reviewed diff; a skipped
# or focused test is a red signal turned green without changing what it
# measured.
#
# NAMED EXEMPTION: documentation files (.md, .rst, .txt, .adoc). This
# framework's own Standard quotes every pattern below in order to forbid it;
# a hook that blocked the Standard from being written would be the joke
# version of itself. Code is never exempt, and there is no environment
# override — the one admissible inline case (a tool false positive that
# configuration cannot scope) is applied by a human, with the forcing
# constraint written on the preceding line, as the Standard requires.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$(iaeng_field '.tool_name')"
case "$TOOL" in ""|Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

FILE="$(iaeng_field '.tool_input.file_path')"

# NAMED EXEMPTIONS — three, all by path, none a fall-through.
#
# 1. Documentation. Standards/CODE_QUALITY_STANDARD.md quotes every directive
#    below in order to forbid it; a hook that stopped the Standard from being
#    written would be the joke version of itself.
# 2. This hook's own test corpus, this hook's tests/ directory. A test that
#    proves a directive is refused has to contain that directive. Found by this
#    hook refusing the very file that tests it — the same shape as (1), one
#    level down. Scoped to that one directory rather than to any hooks/tests/ or any path containing the
#    word test, because a directory whose whole contents become exempt is how
#    the synthetic-fixture marker was defeated before it was anchored
#    (Standards/DATA_PROTECTION_STANDARD.md, Synthetic Fixtures).
#
# Code is never exempt, and there is no environment override. Note that this
# file is not exempt from itself: its own comments name the directives
# obliquely for that reason, and the rule they implement is stated in full in
# the Standard.
# `shopt -s nocasematch
case "$FILE" in
  *.md|*.rst|*.txt|*.adoc) exit 0 ;;
esac
shopt -u nocasematch

# The two path exemptions compare CANONICAL paths, not suffixes. A suffix match
# exempted any file that merely ended in the same words (evil/Adapters/scripts/
# <the pattern file's name>, src/hooks/tests/anything), and the pattern-file
# match was case-insensitive as well. The edit's path is made absolute (a
# relative one against the payload's cwd), `.` and `..` are resolved, and it is
# compared with the framework's OWN files, which this hook locates from its own
# directory — so the same rule holds in this repository and under an adopter's
# ia-engineering/. Symlinks are not resolved: a link inside tests/ that points
# elsewhere is still exempt, which is the same reach the write already has.
#
# 2. (continued) the hooks/tests/ directory next to this hook.
# 3. The pattern file (Adapters/scripts/suppression-patterns.tsv): it quotes
#    every directive in order to forbid it, and exempting it also lets a deleted
#    copy be restored through Write.
iaeng_canon() {
  local p="$1" base="${2:-}" seg n r=""
  local out=()
  if command -v cygpath >/dev/null 2>&1; then
    p="$(cygpath -u -- "$p" 2>/dev/null)" || p="$1"
    [ -z "$base" ] || base="$(cygpath -u -- "$base" 2>/dev/null)" || base="${2:-}"
  else
    p="${p//\\//}"
    base="${base//\\//}"
  fi
  case "$p" in /*) ;; *) p="${base:-$PWD}/$p" ;; esac
  set -f
  local IFS=/
  for seg in $p; do
    case "$seg" in
      ''|.) ;;
      ..) n=${#out[@]}; if [ "$n" -gt 0 ]; then unset "out[$((n - 1))]"; fi ;;
      *) out+=("$seg") ;;
    esac
  done
  set +f
  for seg in ${out[@]+"${out[@]}"}; do r="$r/$seg"; done
  printf '%s' "${r:-/}"
}

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS="$HOOK_DIR/../../../scripts/suppression-patterns.tsv"
if [ -n "$FILE" ]; then
  CANON="$(iaeng_canon "$FILE" "$(iaeng_field '.cwd')")"
  [ "$CANON" != "$(iaeng_canon "$PATTERNS")" ] || exit 0
  case "$CANON" in "$(iaeng_canon "$HOOK_DIR")"/tests/*) exit 0 ;; esac
fi

# Every string the edit would write. With jq: new_string, content, and each
# MultiEdit edit's new_string. Without jq: the raw payload — the patterns are
# distinctive enough that matching the whole JSON is a safe over-approximation
# (it can block, never allow, more than the exact text would).
if iaeng_have_jq; then
  TEXT="$(printf '%s' "$IAENG_INPUT" \
    | jq -r '.tool_input | [.new_string?, .content?, (.edits[]?.new_string?)] | .[] | select(. != null)' 2>/dev/null)"
else
  TEXT="$IAENG_INPUT"
fi
[ -n "$TEXT" ] || exit 0

# CASE-INSENSITIVE. The filename exemption above folds case and the directives
# it guards did not, so the upper-case spelling of the Python lint pragma was
# allowed while the lower-case one was refused — and the tool honours both,
# making it a live suppression and the second spelling anyone reaching for a
# bypass would try. Blanket -i rather than deciding per tool which spellings
# are honoured: it errs toward blocking, which is the direction these hooks
# fail in by design, and the cost of over-blocking is a rename, not a lost
# control.
# here-string, not `printf | grep -q`. Under the `set -o pipefail` this hook
# inherits from lib.sh, grep -q closing the pipe on its first match makes the
# printf take SIGPIPE, and pipefail reports that as the pipeline's failure —
# so a directive near the top of a payload larger than the ~64 KB pipe buffer
# reads as ABSENT and the edit is ALLOWED. A 64 KB source file is ordinary, not
# adversarial, so this bypassed the control with no obfuscation at all. The
# here-string is not a pipeline; pipefail does not apply. TROUBLESHOOTING X.
# THE PATTERNS LIVE IN ONE DATA FILE, Adapters/scripts/suppression-patterns.tsv
# (label<TAB>ERE), read by this hook and by check-inline-suppression.sh. This
# hook sees only Edit/Write/MultiEdit; a directive written through the Bash
# tool, by a human, or by another runtime never reaches it, and the Pull
# Request check reads the same list where those paths meet. Two copies of the
# list would drift.
#
# FAIL CLOSED when the file is missing: an absent pattern list is not an empty
# one, and a hook that allowed everything because its data was gone is the
# defect Adapters/README.md's Check Convention names. Same shape as the lexer
# check in block-escape-hatches.sh. The pattern file itself is exempt by path
# (below, with the other named exemptions) because it quotes every directive;
# that also lets a deleted file be restored through an Edit or Write.
check() {
  local rc=0
  grep -qiE -- "$1" <<< "$TEXT" || rc=$?
  # rc 2 is a pattern grep could not compile: an unreadable rule is a failure,
  # not a rule that matched nothing.
  [ "$rc" -le 1 ] || iaeng_block "suppression-patterns.tsv holds a pattern grep cannot compile: $1" "Fix the row."
  return "$rc"
}

if [ ! -f "$PATTERNS" ]; then
  iaeng_block "Adapters/scripts/suppression-patterns.tsv is missing — cannot tell which edits are suppressions" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression. Restore the file; the hook reads its patterns from it and fails closed without it."
fi

SEEN=0
while IFS= read -r row || [ -n "$row" ]; do
  row="${row%$'\r'}"
  case "$row" in ''|'#'*) continue ;; esac
  case "$row" in *$'\t'*) ;; *) iaeng_block "malformed row in suppression-patterns.tsv (no TAB): $row" "Each row is label<TAB>ERE." ;; esac
  label="${row%%$'\t'*}"
  re="${row#*$'\t'}"
  if [ -z "$label" ] || [ -z "$re" ]; then
    iaeng_block "malformed row in suppression-patterns.tsv (empty label or pattern): $row" "Each row is label<TAB>ERE."
  fi
  SEEN=$((SEEN + 1))
  if check "$re"; then
    iaeng_block "inline suppression: ${label} (${FILE:-unknown file}) — a red signal turned green without changing what it measured" \
      "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression (Standards/TESTING_STANDARD.md for skipped tests). Configure the rule for the project, or satisfy it; a tool false positive that configuration cannot scope is applied by a human with the constraint named on the preceding line."
  fi
done < "$PATTERNS"

[ "$SEEN" -gt 0 ] || iaeng_block "suppression-patterns.tsv holds no patterns" "An empty list would allow everything; restore it."

exit 0
