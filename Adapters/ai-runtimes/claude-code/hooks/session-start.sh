#!/usr/bin/env bash
# IA Engineering — Claude Code SessionStart hook (matcher: startup|resume|compact)
#
# Mechanically enforces Core/AGENT_CONDUCT.md, Read First: whatever this hook
# prints to stdout is added to the model's context at the start of the
# session, so the reading order is not something the model has to remember —
# it is the first thing it sees. It prints the pointers and the *current*
# state, never a copy of CLAUDE.md (one fact, one place — Templates/SESSION_STATE.md).

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

BASE="${CLAUDE_PROJECT_DIR:-.}"
ROOT="$(iaeng_framework_root || true)"
STATE="$BASE/.ia-engineering/SESSION_STATE.md"

echo "IA Engineering — read first, then say in one line what you read and what you are about to do (Core/AGENT_CONDUCT.md, Read First):"
echo
echo "  1. CLAUDE.md — the project's stable contract."
if [ -f "$STATE" ]; then
  echo "  2. .ia-engineering/SESSION_STATE.md — where things actually stand. Never committed."
  LAST="$(grep -m1 -E '^_Last updated:' "$STATE" | sed 's/^_//; s/_$//')"
  [ -n "$LAST" ] && echo "     $LAST"
  NEXT="$(awk '/^## Next Step/{f=1; next} /^## /{f=0} f && NF' "$STATE" | head -5)"
  if [ -n "$NEXT" ]; then
    echo "     Next Step, as recorded:"
    printf '%s\n' "$NEXT" | sed 's/^/       /'
  fi
  BLOCKED="$(awk '/^## Blocked On/{f=1; next} /^## /{f=0} f && NF' "$STATE" | head -3)"
  if [ -n "$BLOCKED" ] && ! printf '%s' "$BLOCKED" | grep -qiE '^\[?nothing'; then
    echo "     Blocked on:"
    printf '%s\n' "$BLOCKED" | sed 's/^/       /'
  fi
else
  if [ -n "$ROOT" ] && [ -f "$ROOT/Templates/SESSION_STATE.md" ]; then
    echo "  2. .ia-engineering/SESSION_STATE.md does not exist. Create it from $ROOT/Templates/SESSION_STATE.md before any other action; it is gitignored and refused by the pre-commit hook."
  else
    echo "  2. .ia-engineering/SESSION_STATE.md does not exist and the framework's template was not found (looked for Core/AGENT_CONDUCT.md at ., ia-engineering/, \$IAENG_FRAMEWORK)."
  fi
fi
echo "  3. The Employee Brief for the Work Unit, and the Standards it names."
echo

if git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Repository state now:"
  git -C "$BASE" status --short --branch 2>/dev/null | head -15 | sed 's/^/  /'
  echo
fi

echo "Rules enforced by hooks in this session (Adapters/ai-runtimes/claude-code/hooks/): no escape hatch in shell commands (Standards/GIT_STANDARD.md), no inline lint/test suppression in code (Standards/CODE_QUALITY_STANDARD.md), no stopping with uncommitted tracked changes unexplained (Core/AGENT_CONDUCT.md, Reporting Contract). Every Work Unit ends with a Work Unit Report (Templates/WORK_UNIT_REPORT.md) — a bare Done is a failed Work Unit."
exit 0
