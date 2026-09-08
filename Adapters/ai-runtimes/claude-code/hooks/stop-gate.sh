#!/usr/bin/env bash
# IA Engineering — Claude Code Stop hook
#
# Mechanically enforces the end of Core/AGENT_CONDUCT.md's Reporting Contract:
# a session does not end with tracked changes left uncommitted and unexplained.
# A Work Unit is one commit; uncommitted work at stop is either a Work Unit
# that was not finished or one that was finished and not recorded — both are
# what the Work Unit Report exists to make visible.
#
# LOOP GUARD: Claude Code sets stop_hook_active=true when the model is
# continuing *because* a Stop hook blocked it. The hook then exits 0, so the
# model gets exactly one continuation to commit or to state, in its final
# message, why the changes stay uncommitted. Without the guard the session
# could never end.
#
# ADVISORY BY DESIGN for everything else: this hook does not know whether a
# Work Unit Report was written (it lives in a PR body or a named file). It
# reminds; it blocks only on the one condition it can verify.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ACTIVE="$(iaeng_bool '.stop_hook_active')"
[ "$ACTIVE" = "true" ] && exit 0

BASE="${CLAUDE_PROJECT_DIR:-.}"
git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHANGES="$(git -C "$BASE" status --porcelain --untracked-files=no 2>/dev/null)"
if [ -n "$CHANGES" ]; then
  {
    echo "iaeng: stop gate — tracked files have uncommitted changes:"
    printf '%s\n' "$CHANGES" | head -20 | sed 's/^/  /'
    echo "  One Work Unit is one commit (Standards/COMMIT_STANDARD.md), and a Work Unit ends with its"
    echo "  Work Unit Report (Templates/WORK_UNIT_REPORT.md). Either commit — with the Work Unit: and"
    echo "  Employee: trailers — or state explicitly in your final message why these changes remain"
    echo "  uncommitted and what the Director must decide. Then stop. Update .ia-engineering/SESSION_STATE.md"
    echo "  (absolute date) if the project's state changed."
  } >&2
  exit 2
fi

exit 0
