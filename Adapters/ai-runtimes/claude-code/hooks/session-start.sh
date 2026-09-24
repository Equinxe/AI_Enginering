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

  # mtime is computed once and used by both Warning 1 and Warning 2: it is
  # the file's own record of when it was last touched, independent of
  # whether the header inside it was updated in the same edit (Warning 2
  # exists because it often was not).
  STATE_MTIME="$(iaeng_file_mtime "$STATE")"

  # --- Warning 1: behind the repository -----------------------------------
  if [ -n "$STATE_MTIME" ] && git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    HEAD_TS="$(iaeng_head_commit_time "$BASE")"
    if [ -n "$HEAD_TS" ] && [ "$STATE_MTIME" -lt "$HEAD_TS" ]; then
      BEHIND="$(git -C "$BASE" rev-list --count --since="@$STATE_MTIME" HEAD 2>/dev/null)"
      if [ -n "$BEHIND" ] && iaeng_is_int "$BEHIND"; then
        echo "     WARNING: SESSION_STATE.md is $BEHIND commit(s) behind the repository — refresh it before acting."
      else
        echo "     WARNING: SESSION_STATE.md is behind the repository (commit count unavailable) — refresh it before acting."
      fi
    fi
  fi

  # --- Warning 2: header not refreshed on the last edit -------------------
  # The header is free-text ("DD Month YYYY, morning/evening by ..."), so
  # this parses defensively: an unparsable header is reported as such, never
  # silently skipped — that silence is exactly the failure mode this Work
  # Unit exists to catch (the header can go stale while the body keeps
  # moving, and nothing said so).
  if [ -n "$STATE_MTIME" ]; then
    HEADER_DATE="$(printf '%s' "$LAST" | grep -oE '[0-9]{1,2} [A-Za-z]+ [0-9]{4}' | head -1)"
    if [ -n "$HEADER_DATE" ]; then
      HEADER_YMD="$(date -d "$HEADER_DATE" +%Y-%m-%d 2>/dev/null)"
      MTIME_YMD="$(date -r "$STATE" +%Y-%m-%d 2>/dev/null)"
      if [ -n "$HEADER_YMD" ] && [ -n "$MTIME_YMD" ]; then
        if [[ "$HEADER_YMD" < "$MTIME_YMD" ]]; then
          echo "     WARNING: the _Last updated: header ($HEADER_DATE) was not refreshed on the file's last edit ($MTIME_YMD) — update it every time the body changes."
        fi
      else
        echo "     WARNING: the _Last updated: header's date could not be parsed for freshness comparison — verify it was refreshed by hand."
      fi
    else
      echo "     WARNING: no parsable date found in the _Last updated: header — verify it was refreshed by hand."
    fi
  fi

  # --- Warning 3: size ----------------------------------------------------
  # Loaded on every resume (this hook prints it, unabridged, into context),
  # so its size is occupation paid on every session, not just its author's —
  # see Core/CONTEXT_BUDGET.md, rule 3 ("read what you will not use") and its
  # own measured baseline for this file (6,456 characters). 15,000 characters
  # (~3.75k tokens at the ~4 chars/token estimate CONTEXT_BUDGET.md uses) is
  # a little over twice that healthy baseline, and well under the ~36,000
  # characters / 224 lines this file had grown to when this Work Unit was
  # opened — chosen as a threshold that catches "becoming a log" before it
  # reaches "is one". Measured in characters; this is an estimate, not a
  # token count.
  STATE_CHARS="$(wc -c < "$STATE" | tr -d '[:space:]')"
  if [ -n "$STATE_CHARS" ] && iaeng_is_int "$STATE_CHARS" && [ "$STATE_CHARS" -gt 15000 ]; then
    echo "     WARNING: SESSION_STATE.md is $STATE_CHARS characters (Core/CONTEXT_BUDGET.md: measured in characters, ~4 chars/token estimate) — over the 15,000-character budget and loaded on every resume. Prune \"Where the Project Stands\" and \"Next Step\" to a snapshot; history belongs in git or the Journal, not here."
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
