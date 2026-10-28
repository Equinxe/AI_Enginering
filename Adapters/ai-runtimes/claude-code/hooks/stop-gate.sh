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
# could never end. This guard is checked FIRST and applies to every block
# below, including the SESSION_STATE gate — one continuation total, not one
# per condition.
#
# SESSION_STATE GATE (Director-approved 24 Sep): this is the one place this
# repository's own measured failure — a SESSION_STATE.md whose "_Last
# updated:" header read 15 days stale while the body kept being edited, with
# nothing at session end saying so — gets a mechanical answer. Checked only
# once the tracked-changes gate above has passed (a clean tree), and only
# when the file EXISTS: if SESSION_STATE.md is older than HEAD's last
# commit, this BLOCKS the stop (exit 2) so the agent updates it itself
# before the session ends. Updating it creates no commit — it is gitignored
# — so this cannot loop on its own; the stop_hook_active guard still applies
# if something else keeps the session from ending. If the file does not
# exist, this gate does not block forever waiting for one: it leaves a
# non-blocking reminder pointing at Templates/SESSION_STATE.md, because a
# project that has never created the file is a different condition than one
# whose file went stale, and treating them the same would block every
# no-state project on every stop. When HEAD's commit time is AFTER the
# system clock (clock skew, or a deliberately future-dated commit), this
# gate does not compare mtime against it at all: it prints the same
# fail-safe "cannot verify" message as a missing mtime or a git error and
# does not block. A first pass instead clamped HEAD's time at "now" and
# kept comparing — which looked fixed but was not, because "now" is re-read
# live on every invocation while SESSION_STATE's mtime stays fixed at
# whatever moment it was actually touched: real time moving forward, with
# no edit at all, silently re-opened the block a second later. Treating a
# future HEAD_TS as unusable is the same fail-safe posture this gate
# already takes when it cannot read a value at all — it just cannot verify.
#
# ADVISORY BY DESIGN for everything else: this hook does not know whether a
# Work Unit Report was written (it lives in a PR body or a named file). It
# reminds; it blocks only on the two conditions it can verify.

# This hook's own directory, from BASH_SOURCE and never $0: bash finding the
# hook through PATH leaves $0 the bare name, whose dirname is the working
# directory, where a cloned repository could plant lib.sh (issue #344). Either
# separator, as dirname reads a Windows path in Git Bash.
case "${BASH_SOURCE[0]}" in
  */*|*\\*) HOOKS_DIR="${BASH_SOURCE[0]%[/\\]*}" ;;
  *) HOOKS_DIR=. ;;
esac
# shellcheck source=lib.sh
. "$HOOKS_DIR/lib.sh"

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

# --- SESSION_STATE freshness gate — see header comment ----------------------
STATE="$BASE/.ia-engineering/SESSION_STATE.md"
if [ -f "$STATE" ]; then
  STATE_MTIME="$(iaeng_file_mtime "$STATE")"
  HEAD_TS="$(iaeng_head_commit_time "$BASE")"
  NOW="$(iaeng_now)"
  if [ -n "$STATE_MTIME" ] && [ -n "$HEAD_TS" ] && [ -n "$NOW" ]; then
    if [ "$HEAD_TS" -gt "$NOW" ]; then
      # HEAD's commit is dated after the system clock: clock skew, or a
      # deliberately future-dated commit. The comparison partner itself
      # cannot be trusted, so this is treated exactly like the "could not
      # determine" branch below — warn, do not block — rather than blocked
      # or silently passed.
      HEAD_CDATE="$(git -C "$BASE" log -1 --format=%cd 2>/dev/null)"
      echo "iaeng: stop gate — HEAD's last commit is dated after the system clock ($HEAD_CDATE vs. $(date 2>/dev/null)) — cannot verify whether SESSION_STATE.md is current; not blocking on it. Verify by hand." >&2
    elif [ "$STATE_MTIME" -lt "$HEAD_TS" ]; then
      BEHIND="$(git -C "$BASE" rev-list --count --since="@$STATE_MTIME" HEAD 2>/dev/null)"
      HEAD_CDATE="$(git -C "$BASE" log -1 --format=%cd 2>/dev/null)"
      {
        echo "iaeng: stop gate — .ia-engineering/SESSION_STATE.md is behind the repository"
        if [ -n "$BEHIND" ] && iaeng_is_int "$BEHIND"; then
          echo "  ($BEHIND commit(s) have landed since it was last saved)."
        fi
        if [ -n "$HEAD_CDATE" ]; then
          echo "  HEAD's last commit is dated: $HEAD_CDATE (vs. system clock: $(date 2>/dev/null))."
        fi
        echo "  Update it now, then stop: an absolute date in the _Last updated: header, and"
        echo "  rewrite \"Where the Project Stands\" and \"Next Step\" as a snapshot of where things"
        echo "  stand right now — not a new log entry (Templates/SESSION_STATE.md). This does not"
        echo "  create a commit — the file is gitignored — so this gate cannot loop on it."
      } >&2
      exit 2
    fi
  else
    # Fail safe: a git error or an unreadable mtime/clock must not turn into
    # a false block. Warn — do not block — and let the session end.
    echo "iaeng: stop gate — could not determine whether SESSION_STATE.md is current (mtime, HEAD commit time, or system clock unavailable); not blocking on it. Verify by hand." >&2
  fi
else
  ROOT="$(iaeng_framework_root || true)"
  if [ -n "$ROOT" ]; then
    HELPER="$ROOT/Adapters/scripts/create-session-state.sh"
  else
    HELPER="the framework's Adapters/scripts/create-session-state.sh"
  fi
  echo "iaeng: SESSION_STATE.md does not exist — not blocking, but create it before the next session resumes (Core/AGENT_CONDUCT.md, Read First): run $HELPER, which writes the Template block of Templates/SESSION_STATE.md with today's date." >&2
fi

exit 0
