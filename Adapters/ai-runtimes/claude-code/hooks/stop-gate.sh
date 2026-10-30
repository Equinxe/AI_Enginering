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
# continuing *because* a Stop hook blocked it. The hook then exits 0 and says
# nothing, so the model gets exactly one continuation to commit or to state,
# in its final message, why the changes stay uncommitted. Without the guard
# the session could never end. The guard applies to every block AND every
# reminder below, including the SESSION_STATE gate — one continuation total,
# not one per condition. It is read where the hook is about to block or
# remind (yield_to_loop_guard), not first: the path most stops take, a clean
# tree and a current SESSION_STATE, says nothing, so it never needs the
# guard, and reading it there cost a jq process on every stop (PROCESSES ARE
# THE COST, below).
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
#
# PROCESSES ARE THE COST (WU-IAENG-410, issue #351). On Windows every
# command this hook starts is a process creation, and under parallel agents
# that, not the hook's own work, is its latency: 29 processes per call,
# p95 16 s and p99 26 s in production
# (Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md). A Stop hook that reaches
# its timeout is cancelled and the session ends unchecked; "onFailure" has
# no effect on Stop, so being fast is this gate's only protection against
# its own timeout. On the common path the hook therefore starts cat (lib.sh),
# git status, date and git log, and nothing else: lib.sh is found without
# dirname, git rev-parse runs only when git status fails (the same
# decision: git status fails outside a work tree), the clock is bash's own,
# the mtime and HEAD's time are read without a subshell around them, and
# the loop guard is read only before the hook says something.
# tests/run.sh holds the budget.

# This hook's own directory, never the working directory (issue #344). It is
# taken from $0 when $0 holds a / or \, because the environment cannot set $0.
# A bare $0 means bash found the hook through PATH or in the working
# directory, where dirname "$0" would name the working directory; then
# BASH_SOURCE[0], the path bash found, is used. BASH_SOURCE is not taken first
# because bash 5.3 imports it from the environment (SEC-IAENG-400-01). Both
# separators count, as Git Bash's dirname reads both.
HOOKS_DIR="$0"
case "$HOOKS_DIR" in */*|*\\*) ;; *) HOOKS_DIR="${BASH_SOURCE[0]}" ;; esac
case "$HOOKS_DIR" in
  */*|*\\*) HOOKS_DIR="${HOOKS_DIR%[/\\]*}" ;;
  *) HOOKS_DIR=. ;;
esac
# shellcheck source=lib.sh
. "$HOOKS_DIR/lib.sh"

# yield_to_loop_guard — exits 0, silently, on the continuation a block gave.
# Called before every block and every reminder; see LOOP GUARD above.
yield_to_loop_guard() {
  [ "$(iaeng_bool '.stop_hook_active')" = "true" ] && exit 0
  return 0
}

BASE="${CLAUDE_PROJECT_DIR:-.}"
CHANGES="$(git -C "$BASE" status --porcelain --untracked-files=no 2>/dev/null)" \
  || git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || exit 0

if [ -n "$CHANGES" ]; then
  yield_to_loop_guard
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
  # lib.sh's iaeng_file_mtime, iaeng_head_commit_time and iaeng_now, read in
  # place: $(helper) wraps the helper's own $(command) in a second subshell.
  # A value that is not an integer is no value, as there.
  STATE_MTIME="$(date -r "$STATE" +%s 2>/dev/null)"
  iaeng_is_int "$STATE_MTIME" || STATE_MTIME=""
  HEAD_TS="$(git -C "$BASE" log -1 --format=%ct 2>/dev/null)"
  iaeng_is_int "$HEAD_TS" || HEAD_TS=""
  # bash's own clock (bash 4.2 and later): no process. Elsewhere, date.
  NOW=""
  printf -v NOW '%(%s)T' -1 2>/dev/null
  iaeng_is_int "$NOW" || NOW="$(iaeng_now)"
  if [ -n "$STATE_MTIME" ] && [ -n "$HEAD_TS" ] && [ -n "$NOW" ]; then
    if [ "$HEAD_TS" -gt "$NOW" ]; then
      # HEAD's commit is dated after the system clock: clock skew, or a
      # deliberately future-dated commit. The comparison partner itself
      # cannot be trusted, so this is treated exactly like the "could not
      # determine" branch below — warn, do not block — rather than blocked
      # or silently passed.
      yield_to_loop_guard
      HEAD_CDATE="$(git -C "$BASE" log -1 --format=%cd 2>/dev/null)"
      echo "iaeng: stop gate — HEAD's last commit is dated after the system clock ($HEAD_CDATE vs. $(date 2>/dev/null)) — cannot verify whether SESSION_STATE.md is current; not blocking on it. Verify by hand." >&2
    elif [ "$STATE_MTIME" -lt "$HEAD_TS" ]; then
      yield_to_loop_guard
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
    yield_to_loop_guard
    echo "iaeng: stop gate — could not determine whether SESSION_STATE.md is current (mtime, HEAD commit time, or system clock unavailable); not blocking on it. Verify by hand." >&2
  fi
else
  yield_to_loop_guard
  ROOT="$(iaeng_framework_root || true)"
  if [ -n "$ROOT" ]; then
    HELPER="$ROOT/Adapters/scripts/create-session-state.sh"
  else
    HELPER="the framework's Adapters/scripts/create-session-state.sh"
  fi
  echo "iaeng: SESSION_STATE.md does not exist — not blocking, but create it before the next session resumes (Core/AGENT_CONDUCT.md, Read First): run $HELPER, which writes the Template block of Templates/SESSION_STATE.md with today's date." >&2
fi

exit 0
