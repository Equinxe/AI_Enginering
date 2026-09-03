#!/usr/bin/env bash
# IA Engineering — Claude Code PostToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Runs the cheapest available check on the file just written and feeds a
# failure straight back to the model (exit 2, stderr) instead of waiting for
# CI. Standards/CODE_QUALITY_STANDARD.md, Automated Quality: verify with tools
# at the earliest point they can run.
#
# What runs, by file:
#   *.sh, files under */git-hooks/*      bash -n, then shellcheck when installed
#   anything                             .ia-engineering/lint.sh <file>, when the
#                                        project provides it (executable). This
#                                        is the project's own linter entry point
#                                        — the framework cannot know the stack.
#
# Absence of a linter is REPORTED, not passed silently: a file that was checked
# by nothing is said to have been checked by nothing.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$(iaeng_field '.tool_name')"
case "$TOOL" in ""|Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

FILE="$(iaeng_field '.tool_input.file_path')"
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

BASE="${CLAUDE_PROJECT_DIR:-.}"
RAN=0
FAILED=0
OUT=""

is_shell=0
case "$FILE" in
  *.sh|*/git-hooks/*) is_shell=1 ;;
  *) head -1 "$FILE" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && is_shell=1 ;;
esac

if [ "$is_shell" -eq 1 ]; then
  RAN=1
  if ! r="$(bash -n "$FILE" 2>&1)"; then FAILED=1; OUT="$OUT$r"$'\n'; fi
  if command -v shellcheck >/dev/null 2>&1; then
    if ! r="$(shellcheck -x -P SCRIPTDIR "$FILE" 2>&1)"; then FAILED=1; OUT="$OUT$r"$'\n'; fi
  else
    OUT="$OUT(shellcheck not installed — syntax only; the Shellcheck Adapters CI job is the control)"$'\n'
  fi
fi

if [ -x "$BASE/.ia-engineering/lint.sh" ]; then
  RAN=1
  if ! r="$("$BASE/.ia-engineering/lint.sh" "$FILE" 2>&1)"; then FAILED=1; OUT="$OUT$r"$'\n'; fi
fi

if [ "$FAILED" -eq 1 ]; then
  {
    echo "iaeng: lint failed for $FILE — fix before continuing (Standards/CODE_QUALITY_STANDARD.md). Never suppress inline."
    printf '%s' "$OUT" | head -40 | sed 's/^/  /'
  } >&2
  exit 2
fi

if [ "$RAN" -eq 1 ]; then
  [ -n "$OUT" ] && printf '%s' "$OUT" >&2
  exit 0
fi

# Nothing applicable ran. Say so — once, briefly — rather than implying a check.
echo "iaeng: no linter ran for $FILE (not shell; no .ia-engineering/lint.sh in the project)." >&2
exit 0
