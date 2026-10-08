#!/usr/bin/env bash
# IA Engineering — usage-dashboard.sh
#
# Builds ONE self-contained static HTML page showing how a project actually
# uses its Employees and Agent Chains: which Employees are dispatched and
# commit most, which are never used, which chain steps are never exercised,
# which models do the work, and how many tokens it takes per day.
#
# WHY THIS EXISTS
#
# The roster (Registry/employees.yml) and the chains (Registry/chains.yml) are
# design decisions: forty-odd Employees and six chains, each a claim that the
# work needs that role at that step. Nothing measured whether the claims held.
# An Employee that is never dispatched is either a gap in Core/EMPLOYEE_SELECTION.md's
# triggers, a chain that routes around it, or a role the work does not need,
# and those are three different decisions — but all three start with seeing
# the zero. This page makes the zero visible. It informs roster and chain
# tuning; it decides nothing (Governance/DISPATCH_IN_PRACTICE.md, Measuring
# Usage).
#
# WHAT IT READS
#
#   git (runtime-agnostic)   per commit: the `Employee:` and `Co-Authored-By:`
#                            trailers as git parses them, the column-0
#                            `Work Unit:` line, and the numstat line counts,
#                            each value shape-checked — never the rest of the
#                            message, never a diff. Non-merge commits only.
#   Registry/employees.yml   the framework roster, plus the project roster
#                            (.ia-engineering/Registry/employees.yml) unioned
#                            in exactly as check-employee-trailers.sh does
#   Registry/chains.yml      chain steps, in order
#   Registry/work-units.yml  the PROJECT's own registry, never the framework's
#                            read on its behalf (WU-IAENG-320)
#   AI-runtime transcripts   through a runtime collector, when one is present:
#                            Adapters/ai-runtimes/claude-code/usage-collect.sh.
#                            Absent collector or absent transcripts is a
#                            source reported as missing, not an error.
#
# Standards/DATA_PROTECTION_STANDARD.md: the page holds aggregates only —
# counts, token totals, names of Employees, models, agent types and Work Unit
# IDs. No prompt, reply, commit-message body, file content or secret is read
# into it, nor into the cache kept between runs (see KEPT FRESH). The default
# output path is gitignored (.ia-engineering/usage/), and the page makes no
# network request: inline CSS, inline JS, inline SVG.
#
# USAGE
#
#   usage-dashboard.sh [--project-dir DIR] [--out FILE] [--since REF]
#                      [--transcripts-dir DIR] [--prices FILE]
#                      [--open [--no-wait]] [--watch [SECONDS]]
#                      [--refresh | --refresh-in-background]
#                      [--min-interval SECONDS]
#
#   --project-dir      the project's git work tree (default: the one containing
#                      the current directory; run from inside a framework
#                      submodule, the project that includes it)
#   --out              output file (default: <project>/.ia-engineering/usage/dashboard.html)
#   --since            start of the "range" columns (default: the latest v* tag
#                      reachable from HEAD; all-time columns are always shown)
#   --transcripts-dir  passed to the runtime collector instead of its own lookup
#   --prices           a TSV of USD prices per million tokens, one model per
#                      line: <model-id> <input> <output> <cache-write> <cache-read>.
#                      Without it the page shows no cost, and says so.
#   --open             open the page in the default browser: at once when it is
#                      current, after an incremental rebuild otherwise (see
#                      KEPT FRESH; $IAENG_USAGE_OPENER, when set, is the opener)
#   --no-wait          with --open: open the page as it is and refresh it in
#                      the background (see KEPT FRESH)
#   --watch [SECONDS]  live mode: rebuild the page every SECONDS (default 10,
#                      minimum 10) until Ctrl-C; the page reloads itself at the
#                      same interval and shows when it was last updated. With
#                      --open, the browser is opened once, after the first
#                      build. See "Live mode" below.
#   --refresh, --refresh-in-background, --min-interval SECONDS
#                      rebuild the page only when it is stale, in the
#                      foreground or detached; see KEPT FRESH.
#
# PER PROJECT
#
# Everything is the project's own: its git history, the framework roster plus
# its project roster, its Registry/, the transcripts of ITS path's slug only,
# and its own .ia-engineering/usage/ for output. A new project therefore
# starts at zero. Two caveats, both about the transcripts: a project re-created
# at the SAME path inherits that path's earlier transcripts (pass
# --transcripts-dir, or remove the old directory under the runtime's
# projects/), and the runtime deletes transcripts older than its retention
# period (Claude Code: cleanupPeriodDays, 30 days by default), so token and
# dispatch history is a rolling window while the git columns are permanent.
#
# KEPT FRESH (WU-IAENG-341) — AND THE CONTRACT A HOOK OR A COMMAND CALLS
#
# The page is meant to be current whenever it is opened, with no rebuild to
# wait for. Three pieces, all per project.
#
# The cache. <project>/.ia-engineering/usage/cache/ ($IAENG_USAGE_CACHE when
# set) keeps the git half per HEAD (git/) and the collector's per-transcript
# records (transcripts/) between runs, so only the first run reads everything.
# It is created 0700 and holds shape-checked values only, each checked again
# when read: commit messages and transcript text are read in per-run temporary
# directories, removed on exit. It is not used — the run says why and reads
# everything again into a cache of its own, removed on exit — when it is, or
# is reached through, a symbolic link or a junction, is not owned by you, sits
# in a folder others can write to without the sticky bit, or lies in the work
# tree without git saying it ignores it. A default output folder reached
# through a link is refused outright, and a detached refresh that cannot use
# the cache writes nothing in the work tree: it records why in the
# repository's git directory, and the hook starts none for an interval. A build that uses it holds its lock, <cache>/lock/, stale once
# its process is gone or after 10 minutes. A registry edit, a new tag or a
# newer version of these scripts makes what they change be read again.
#
# The fingerprint. Beside the page, .<page name>.fingerprint records what it
# was built from: HEAD, the build arguments, and the size and modification time
# of every transcript — the cheap listing --watch compares each cycle. The page
# is current while that is unchanged and no registry, price file, tag ref or
# one of these scripts is newer than the fingerprint.
#
# The modes, for Claude Code's Stop hook and /dashboard command
# (WU-IAENG-342) or any other runtime's equivalent. A hook passes the project
# explicitly: --project-dir "$CLAUDE_PROJECT_DIR".
#
#   --refresh-in-background [--min-interval SECONDS] [build options]
#     For an end-of-turn hook. Returns at once: it runs no git and starts no
#     process but the refresh. Prints exactly one line on stdout — started,
#     skipped and why, or not started and why — nothing on stderr, and exits 0
#     in every case, a bad argument included: a hook must never fail. Starts
#     no refresh while one runs or within SECONDS of the last one's start
#     (default 60, 10 to 86400). The refresh is the --refresh below, detached:
#     setsid where it exists, nohup elsewhere, under nice -n 10 except on
#     Windows (see spawn_worker), with stdin, stdout and stderr all
#     redirected, so it holds none of the caller's pipes (Windows Git Bash
#     has no setsid; redirecting the three is what releases a native caller's
#     pipes there, measured). It logs to .ia-engineering/usage/refresh.log,
#     moved to refresh.log.1 past 64 KiB.
#   --refresh [--min-interval SECONDS] [build options]
#     The same refresh in the foreground. Skipped when one runs, within
#     SECONDS of the last one's start, or — cheaply, with no build — when the
#     fingerprint is unchanged; otherwise an incremental rebuild, whose page
#     reloads itself every SECONDS. Exit 0 when refreshed or skipped, 1 when
#     the cache cannot be used or the rebuild failed.
#   --open [build options]
#     Opens the page at once when it is current; otherwise waits for a running
#     refresh, rebuilds incrementally, then opens it.
#   --open --no-wait [--min-interval SECONDS] [build options]
#     For an "open the dashboard" command. Opens the existing page at once,
#     however old — when this script wrote it: its fingerprint beside it,
#     ignored and untracked by git; any other page is rebuilt first — then
#     starts the background refresh — not held back by the
#     interval, since it was asked for — and the page, which reloads itself,
#     catches up. With no page yet, builds one first. Exit 0, or 1 when no
#     page could be built or opened.
#
# Inside an AI-runtime session every turn grows the session's transcript, so
# by the time a command runs the fingerprint has changed: there --open would
# rebuild almost every time, which is why --no-wait exists.
#
# Requires bash, git, awk and jq — the framework's existing dependencies.
#
# Exit 0 when the page was written or was already current (with --watch: when
# stopped; with --refresh: also when skipped), 1 when it could not be (not a
# git work tree, a dependency or the roster missing, a bad --since ref, a write
# failure, a first --watch build that failed), 2 on a usage error.
# --refresh-in-background always exits 0.

set -uo pipefail

err() { printf 'usage-dashboard: ERROR: %s\n' "$1" >&2; }
note() { printf 'usage-dashboard: %s\n' "$1" >&2; }

# open_page <file> — hand the page to the default browser. Returns 1 only
# when the path is refused; a browser that cannot be started is a note.
open_page() {
  local page="$1"
  if [ -n "${IAENG_USAGE_OPENER:-}" ]; then
    "$IAENG_USAGE_OPENER" "$page" || note "could not open a browser; open $page yourself."
    return 0
  fi
  case "$(uname -s 2>/dev/null)" in
    # explorer.exe, not `cmd /c start`: cmd would interpret & | ^ %VAR% in
    # the path (PR #196 review, F4). explorer exits 1 even on success, so
    # its status says nothing and is not reported.
    MINGW*|MSYS*|CYGWIN*)
      # explorer.exe reads a comma as a switch separator, so a path with
      # one would open something else, or nothing. Refused, not guessed.
      case "$page" in
        *,*)
          err "--open: the path contains a comma, which explorer.exe would read as a switch separator. The page is written at $page; open it yourself, or pass an --out without a comma."
          return 1 ;;
      esac
      explorer.exe "$(cygpath -w "$page")"; true ;;
    Darwin) open "$page" || note "could not open a browser; open $page yourself." ;;
    *) xdg-open "$page" >/dev/null 2>&1 || note "could not open a browser; open $page yourself." ;;
  esac
  return 0
}

usage() {
  cat >&2 <<'USAGE'
Usage: usage-dashboard.sh [--project-dir DIR] [--out FILE] [--since REF]
                          [--transcripts-dir DIR] [--prices FILE]
                          [--open [--no-wait]] [--watch [SECONDS]]
                          [--refresh | --refresh-in-background]
                          [--min-interval SECONDS]
  Builds a self-contained HTML usage dashboard (Employees, chains, models,
  tokens, Work Units) for a project. Aggregates only; no network.
  --open opens it, rebuilt first only when something changed; with
  --no-wait it opens at once and is refreshed in the background.
  --watch keeps it live: rebuilt every SECONDS (default and minimum 10).
  --refresh rebuilds it only when stale; --refresh-in-background does that
  detached, for an end-of-turn hook: one line, exit 0, at most once every
  --min-interval SECONDS (default 60). See the script's header.
USAGE
}

# Resolved with builtins — cd in this shell and back — not $(cd ... && pwd):
# under --watch every cycle starts this script again, and on Windows each
# command substitution is a fork that costs a quarter of a second and more.
START_PWD="$PWD"
# The Windows launcher (usage-dashboard.cmd) passes this script as a native
# path, C:\...\usage-dashboard.sh: backslashes become slashes first, which
# Git Bash accepts, or the directory part would never be split off.
SCRIPT_SRC="${BASH_SOURCE[0]//\\//}"
case "$SCRIPT_SRC" in
  */*) SCRIPT_DIR="${SCRIPT_SRC%/*}" ;;
  *) SCRIPT_DIR="." ;;
esac
CDPATH='' cd -- "$SCRIPT_DIR" || { printf 'usage-dashboard: ERROR: cannot enter %s\n' "$SCRIPT_DIR" >&2; exit 1; }
SCRIPT_DIR="$PWD"
CDPATH='' cd -- "$SCRIPT_DIR/../.." || { printf 'usage-dashboard: ERROR: cannot find the framework root\n' >&2; exit 1; }
FRAMEWORK_DIR="$PWD"
CDPATH='' cd -- "$START_PWD" || exit 1
COLLECTOR="$FRAMEWORK_DIR/Adapters/ai-runtimes/claude-code/usage-collect.sh"
SELF="$SCRIPT_DIR/${SCRIPT_SRC##*/}"

PROJECT_ARG=""
OUT=""
SINCE=""
TRANSCRIPTS_DIR=""
PRICES=""
OPEN=""
NO_WAIT=""
WATCH=""
MODE=""
MIN_INTERVAL=""
# --refresh-in-background is a hook's command: whatever goes wrong, it prints
# one line and exits 0. Known before parsing, so that a parse error obeys it.
BG=""
for arg in "$@"; do [ "$arg" = --refresh-in-background ] && BG=1; done

# fail_usage <message> — a usage error: exit 2, or for a hook one line and 0.
fail_usage() {
  if [ -n "$BG" ]; then printf 'usage-dashboard: refresh not started: %s\n' "$1"; exit 0; fi
  err "$1"; usage; exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --watch)
      # The interval is optional, so `--open --watch` and `--watch --open`
      # both work — the Windows launcher passes its arguments after --open.
      # Only a plain decimal of at most six digits is an interval: no leading
      # zero (bash reads 010 as octal), nothing that overflows. Anything else
      # after --watch is parsed as the next argument, and refused if it is
      # not one (PR #204 review, F4; code review m2).
      WATCH=10
      if [ "$#" -ge 2 ] && [[ "$2" =~ ^[1-9][0-9]{0,5}$ ]]; then
        WATCH=$((10#$2)); shift
      elif [ "$#" -ge 2 ] && [[ "$2" =~ ^0[0-9]+$ ]]; then
        fail_usage "--watch $2: write the interval without a leading zero (bash would read $2 as an octal number)."
      fi
      shift ;;
    --min-interval)
      # The same rule as --watch's interval, but the value is not optional.
      [ "$#" -ge 2 ] || fail_usage "--min-interval needs a value"
      [[ "$2" =~ ^0[0-9]+$ ]] && fail_usage "--min-interval $2: write the interval without a leading zero (bash would read $2 as an octal number)."
      [[ "$2" =~ ^[1-9][0-9]{0,5}$ ]] || fail_usage "--min-interval $2: the interval is 10 to 86400 seconds."
      MIN_INTERVAL=$((10#$2)); shift 2 ;;
    --project-dir|--out|--since|--transcripts-dir|--prices)
      [ "$#" -ge 2 ] || fail_usage "$1 needs a value"
      case "$1" in
        --project-dir) PROJECT_ARG="$2" ;;
        --out) OUT="$2" ;;
        --since) SINCE="$2" ;;
        --transcripts-dir) TRANSCRIPTS_DIR="$2" ;;
        --prices) PRICES="$2" ;;
      esac
      shift 2 ;;
    --open) OPEN=1; shift ;;
    --no-wait) NO_WAIT=1; shift ;;
    --refresh|--refresh-in-background)
      [ -z "$MODE" ] || [ "$MODE" = "$1" ] || fail_usage "--refresh and --refresh-in-background are exclusive."
      MODE="$1"; shift ;;
    -h|--help)
      [ -z "$BG" ] || fail_usage "--help is not a refresh; run it without --refresh-in-background."
      usage; exit 0 ;;
    *) fail_usage "unknown argument '$1'" ;;
  esac
done

if [ -n "$WATCH" ] && { [ "$WATCH" -lt 10 ] || [ "$WATCH" -gt 86400 ]; }; then
  fail_usage "--watch $WATCH: the interval is 10 to 86400 seconds."
fi
if [ -n "$MIN_INTERVAL" ] && { [ "$MIN_INTERVAL" -lt 10 ] || [ "$MIN_INTERVAL" -gt 86400 ]; }; then
  fail_usage "--min-interval $MIN_INTERVAL: the interval is 10 to 86400 seconds."
fi
if [ -n "$MODE" ] && { [ -n "$WATCH" ] || [ -n "$OPEN" ]; }; then
  # The Windows launcher always adds --open: say what to run instead (QA).
  fail_usage "$MODE goes with neither --watch nor --open: it is for an end-of-turn hook, run with bash usage-dashboard.sh (not through usage-dashboard.cmd, which adds --open)."
fi
if [ -n "$NO_WAIT" ] && { [ -z "$OPEN" ] || [ -n "$WATCH" ]; }; then
  fail_usage "--no-wait goes with --open, and not with --watch."
fi
if [ -n "$MIN_INTERVAL" ] && [ -z "$MODE" ] && [ -z "$NO_WAIT" ]; then
  fail_usage "--min-interval applies to --refresh, --refresh-in-background and --open --no-wait."
fi
MIN_INTERVAL="${MIN_INTERVAL:-60}"

# Set only for a build started by --watch: the page then carries the reload
# directive and the "last updated" line. Anything but a plain decimal is
# ignored. The two test knobs of the watch loop are numbers or nothing:
# they used to reach bash arithmetic, which evaluates what it is given
# (PR #204 review, F4 and F5). A refresh sets REFRESH itself, and AUTO, for
# a page that says it is kept fresh in the background.
REFRESH="${IAENG_USAGE_REFRESH:-}"
[[ "$REFRESH" =~ ^[1-9][0-9]{0,5}$ ]] || REFRESH=""
WATCH_CHILD="${REFRESH:+1}"
AUTO=""
[[ "${IAENG_USAGE_WATCH_SLEEP:-}" =~ ^[0-9]{1,6}$ ]] || IAENG_USAGE_WATCH_SLEEP=""
[[ "${IAENG_USAGE_WATCH_MAX_CYCLES:-}" =~ ^[1-9][0-9]{0,5}$ ]] || IAENG_USAGE_WATCH_MAX_CYCLES=""
# A refresh started detached by this script: "bg" from a hook, "now" from
# --open --no-wait (not held back by the interval). It logs to refresh.log.
# The test knob makes it wait that many seconds once it holds the lock, so a
# test can see the caller return while the refresh still runs.
WORKER="${IAENG_USAGE_WORKER:-}"
case "$MODE:$WORKER" in --refresh:bg|--refresh:now) ;; *) WORKER="" ;; esac
[[ "${IAENG_USAGE_WORKER_DELAY:-}" =~ ^[1-9][0-9]?$ ]] || IAENG_USAGE_WORKER_DELAY=""

# --- Locks and stamps, with builtins ------------------------------------------
# The hook path below starts no process but the refresh, so everything it
# reads — the lock's owner, the time of the last refresh — is read with
# builtins, and only from a regular file (a FIFO would block the hook).

LEASE=600
# Where a detached refresh that could not use the cache records why, in the
# repository's git directory: "<epoch><TAB><reason>".
REFUSED_NAME="ia-engineering-usage.refused"
NOW_S=""
now_epoch() {
  if [ -n "${EPOCHSECONDS:-}" ]; then NOW_S="$EPOCHSECONDS"
  else printf -v NOW_S '%(%s)T' -1 2>/dev/null || NOW_S="$(date +%s)"; fi
}

# read_number <file> — NUM from a file holding one decimal, or return 1.
NUM=""
read_number() {
  local s=""
  NUM=""
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  IFS= read -r s < "$1" || [ -n "$s" ] || return 1
  [[ "$s" =~ ^[0-9]{1,12}$ ]] || return 1
  NUM="$((10#$s))"
}

# read_lock_owner <lock-dir> — LOCK_PID and LOCK_T (its start, in epoch
# seconds) from <lock-dir>/owner, when that holds two numbers.
LOCK_PID=""
LOCK_T=""
read_lock_owner() {
  local p="" t=""
  LOCK_PID=""
  LOCK_T=""
  [ -f "$1/owner" ] && [ ! -L "$1/owner" ] || return 1
  read -r p t _ < "$1/owner" || [ -n "$t" ] || return 1
  [[ "$p" =~ ^[1-9][0-9]{0,9}$ ]] && [[ "$t" =~ ^[0-9]{1,12}$ ]] || return 1
  LOCK_PID="$p"
  LOCK_T="$((10#$t))"
}

# lock_live <lock-dir> — 0 while its owner runs and is within the lease.
# A start in the future (a planted owner, or a clock stepped back) is stale,
# as the refresh stamp's is ignored: otherwise it would never age out while
# its pid lives (PR #230 security review, S3).
lock_live() {
  local age
  read_lock_owner "$1" || return 1
  now_epoch
  age=$((NOW_S - LOCK_T))
  [ "$age" -ge 0 ] && [ "$age" -le "$LEASE" ] && kill -0 "$LOCK_PID" 2>/dev/null
}

# link_under <root> <path> — 0 when <path>, or a directory between <root> and
# it, is a symbolic link or a junction. A cloned repository decides what sits
# at .ia-engineering/usage: committed as a link, it would send the page, the
# cache and the log anywhere the user can write (PR #230 security review,
# S1). Builtins only: the hook path below may not start a process.
link_under() {
  local rest="${2#"$1"/}" acc="$1" part
  [ "$rest" != "$2" ] || return 1
  while [ -n "$rest" ]; do
    case "$rest" in
      */*) part="${rest%%/*}"; rest="${rest#*/}" ;;
      *) part="$rest"; rest="" ;;
    esac
    acc="$acc/$part"
    [ -L "$acc" ] && return 0
  done
  return 1
}

# spawn_worker <bg|now> <project-dir> <out> — starts `--refresh` detached.
# stdin, stdout and stderr all redirected: a hook runner waits until every
# copy of its pipes is closed, and a child that kept one would hold it for
# the whole refresh (measured from Node and PowerShell on Windows Git Bash,
# which has no setsid). setsid, where it exists, also puts the refresh out of
# the caller's session, so a signal to the hook's process group misses it.
# nice -n 10 keeps the refresh behind the user's own work where the scheduler
# shares by weight (Linux, macOS). Not on Windows: there any nice of 5 or
# more is the below-normal priority class, which a busy machine starves.
# Measured there: a fixed CPU loop ran 4 to 5 times slower under nice, and a
# refresh of a tiny project took 510 s instead of 13 s — a page that is
# never fresh.
spawn_worker() {
  local a=(--refresh --min-interval "$MIN_INTERVAL") run=(nohup)
  [ -n "$2" ] && a+=(--project-dir "$2")
  [ -n "$3" ] && a+=(--out "$3")
  [ -n "$SINCE" ] && a+=(--since "$SINCE")
  [ -n "$TRANSCRIPTS_DIR" ] && a+=(--transcripts-dir "$TRANSCRIPTS_DIR")
  [ -n "$PRICES" ] && a+=(--prices "$PRICES")
  command -v setsid >/dev/null 2>&1 && run=(setsid)
  case "${OSTYPE:-}" in
    msys*|cygwin*|win*) ;;
    *) command -v nice >/dev/null 2>&1 && run+=(nice -n 10) ;;
  esac
  IAENG_USAGE_WORKER="$1" IAENG_USAGE_REFRESH="" IAENG_USAGE_PAGEDIR="" IAENG_USAGE_WORKDIR="" \
    "${run[@]}" bash "$SELF" "${a[@]}" </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

# --- In the background (an end-of-turn hook) -----------------------------------
# No git, no process but the refresh: the project is the nearest directory
# holding .git, found with builtins, and the refresh itself (the one --refresh
# run, with git) settles everything again. Run from inside this framework
# when it is a submodule or a linked worktree, with no --project-dir, that
# question is git's, so it is left to the refresh.
if [ "$MODE" = --refresh-in-background ]; then
  d="${PROJECT_ARG:-.}"
  CDPATH='' cd -- "$d" 2>/dev/null || fail_usage "--project-dir '$d' is not a directory."
  d="$PWD"
  CDPATH='' cd -- "$START_PWD" 2>/dev/null || fail_usage "cannot return to '$START_PWD'."
  root=""
  while :; do
    if [ -e "$d/.git" ]; then root="$d"; break; fi
    case "$d" in /|"") break ;; esac
    d="${d%/*}"
    [ -n "$d" ] || d="/"
  done
  [ -n "$root" ] || fail_usage "'${PROJECT_ARG:-$START_PWD}' is not inside a git work tree."
  if [ -z "$PROJECT_ARG" ] && [ "$root" -ef "$FRAMEWORK_DIR" ] && [ -f "$root/.git" ]; then root=""; fi
  if [ -n "$root" ] && link_under "$root" "$root/.ia-engineering/usage"; then
    fail_usage "$root/.ia-engineering/usage is reached through a symbolic link or a junction; nothing is written through it."
  fi
  if [ -n "$root" ]; then
    c="${IAENG_USAGE_CACHE:-$root/.ia-engineering/usage/cache}"
    if lock_live "$c/lock"; then
      printf 'usage-dashboard: refresh skipped: one is already running (pid %s).\n' "$LOCK_PID"
      exit 0
    fi
    # A refresh refused within the interval is not started again (QA of
    # #230): its reason, recorded in .git by the refused refresh, is said.
    r="$root/.git/$REFUSED_NAME"
    if [ -d "$root/.git" ] && [ -f "$r" ] && [ ! -L "$r" ] && IFS=$'\t' read -r t why < "$r" \
        && [[ "$t" =~ ^[0-9]{1,12}$ ]]; then
      now_epoch
      if [ $((NOW_S - 10#$t)) -ge 0 ] && [ $((NOW_S - 10#$t)) -lt "$MIN_INTERVAL" ]; then
        printf 'usage-dashboard: refresh not started: the last one, %s s ago, could not use the cache: %s.\n' \
          "$((NOW_S - 10#$t))" "${why:0:400}"
        exit 0
      fi
    fi
    if read_number "$c/refresh.stamp"; then
      now_epoch
      if [ $((NOW_S - NUM)) -ge 0 ] && [ $((NOW_S - NUM)) -lt "$MIN_INTERVAL" ]; then
        printf 'usage-dashboard: refresh skipped: the last one started %s s ago (at most one every %s s).\n' \
          "$((NOW_S - NUM))" "$MIN_INTERVAL"
        exit 0
      fi
    fi
  fi
  spawn_worker bg "$PROJECT_ARG" "$OUT"
  printf 'usage-dashboard: refreshing the usage dashboard in the background (log: .ia-engineering/usage/refresh.log).\n'
  exit 0
fi

# The page, the cache and the build files are this user's alone.
umask 077

# Everything a run may leave behind, removed on any exit in one process: the
# temporary page, this run's private directories, the watch's state, and the
# cache lock when this run holds it.
TMPD=""
TMPD_OWN=""
WATCH_STATE=""
PAGE_DIR=""
PAGE_DIR_OWN=""
PAGE_TMP=""
CACHE=""
LOCK=""
LOCK_HELD=""
cleanup() {
  local gone=()
  [ -n "$PAGE_TMP" ] && [ -e "$PAGE_TMP" ] && gone+=("$PAGE_TMP")
  [ -n "$PAGE_DIR_OWN" ] && gone+=("$PAGE_DIR_OWN")
  [ -n "$TMPD_OWN" ] && gone+=("$TMPD_OWN")
  [ -n "$WATCH_STATE" ] && gone+=("$WATCH_STATE")
  # Only the lock this run holds: one taken over as stale is the new owner's.
  [ -n "$LOCK_HELD" ] && read_lock_owner "$LOCK" && [ "$LOCK_PID" = "$$" ] && gone+=("$LOCK")
  [ "${#gone[@]}" -eq 0 ] || rm -rf "${gone[@]}"
}
trap 'cleanup' EXIT

for dep in git awk jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    err "$dep is required and was not found on PATH."
    exit 1
  fi
done

# --- The project ---------------------------------------------------------------

START_DIR="${PROJECT_ARG:-.}"
if [ ! -d "$START_DIR" ]; then
  err "--project-dir '$START_DIR' does not exist."
  exit 1
fi
# One git call for the work tree, the repository's common directory (where its
# tags are, for the freshness check) and HEAD. Without commits, git still
# prints the first two and then the literal "HEAD", and fails; outside a work
# tree it prints nothing.
GITINFO="$(git -C "$START_DIR" rev-parse --show-toplevel --git-common-dir HEAD 2>/dev/null)"
PROJECT="${GITINFO%%$'\n'*}"
GIT_COMMON=""
HEAD_SHA=""
# set_common_head <dir> <common-dir-and-HEAD> — the common directory (made
# absolute: git prints it relative to <dir> when it is not) and HEAD.
set_common_head() {
  case "$2" in *$'\n'*) GIT_COMMON="${2%%$'\n'*}"; HEAD_SHA="${2#*$'\n'}" ;; *) return ;; esac
  case "$GIT_COMMON" in /*|[A-Za-z]:*) ;; ?*) GIT_COMMON="$1/$GIT_COMMON" ;; esac
}
case "$GITINFO" in *$'\n'*) set_common_head "$START_DIR" "${GITINFO#*$'\n'}" ;; esac
if [ -z "$PROJECT" ]; then
  err "'$START_DIR' is not inside a git work tree. The dashboard reads Employee and Work Unit trailers from git history; there is nothing to measure without one. Pass --project-dir <your project>."
  exit 1
fi
# Run from inside the framework when the framework is a submodule of a
# project (cd ia-engineering && Adapters/scripts/usage-dashboard.sh), the work
# tree found is the framework's own, and the page would measure the framework
# on the project's behalf. Without an explicit --project-dir, the project
# that includes the framework is the one measured.
if [ -z "$PROJECT_ARG" ] && [ "$PROJECT" -ef "$FRAMEWORK_DIR" ]; then
  SUPER="$(git -C "$PROJECT" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
  if [ -n "$SUPER" ]; then
    note "measuring $SUPER, the project that includes this framework (pass --project-dir to measure the framework itself)."
    PROJECT="$SUPER"
    HEAD_SHA=""
    set_common_head "$PROJECT" "$(git -C "$PROJECT" rev-parse --git-common-dir HEAD 2>/dev/null)"
  fi
fi

if ! [[ "$HEAD_SHA" =~ ^[0-9a-f]{40,64}$ ]]; then
  err "$PROJECT has no commits yet; there is no history to measure."
  exit 1
fi

# HH:MM:SS for the watch log, from the printf builtin where bash has it
# (4.2+), from date(1) where it does not (macOS's bash 3.2).
now_hms() {
  printf -v NOW '%(%H:%M:%S)T' -1 2>/dev/null || NOW="$(date '+%H:%M:%S')"
}

OUT_DEFAULT=""
[ -n "$OUT" ] || OUT_DEFAULT=1
OUT="${OUT:-$PROJECT/.ia-engineering/usage/dashboard.html}"
# A native Windows path (C:\...\dash.html, as typed in PowerShell or passed
# through the launcher) has no "/", so the directory part would never split
# off: slashes, which Git Bash accepts, first (PR #204 code re-check, R1).
OUT="${OUT//\\//}"
# Parameter expansion and a test, not dirname and an unconditional mkdir:
# under --watch these run every cycle, and each process counts.
case "$OUT" in
  */*) OUT_DIR="${OUT%/*}" ;;
  *) OUT_DIR="." ;;
esac
# The default folder is the project's, so the repository decides what sits
# there: one reached through a link is refused before anything is created
# (S1). An --out the user names is the user's choice, links included.
if [ -n "$OUT_DEFAULT" ] && link_under "$PROJECT" "$OUT_DIR"; then
  err "$OUT_DIR is reached through a symbolic link or a junction; refusing to write the page through it. Pass --out to write it elsewhere."
  exit 1
fi
if [ ! -d "$OUT_DIR" ] && ! mkdir -p "$OUT_DIR"; then
  err "cannot create $OUT_DIR."
  exit 1
fi
# An output folder that other users can write to, without the sticky bit,
# lets them rename or replace what lands there — the page included. That is
# refused, once per plain build or watch start (a watch's own builds inherit
# the check). Group-writable is only warned about: with Debian and Ubuntu's
# default umask 002 every user folder is writable by the user's own private
# group, and refusing it would refuse ordinary use. Windows has no such mode
# bits to read (PR #204 security re-check, R3).
case "${OSTYPE:-}" in
  msys*|cygwin*|win*) ;;
  *)
    # "$OUT_DIR/." so that find inspects the folder itself, not a symlink
    # that leads to it (a link's own mode reads 0777): portable to BSD find.
    if [ -z "$WATCH_CHILD" ]; then
      if [ -n "$(find "$OUT_DIR/." -maxdepth 0 -perm -0002 ! -perm -1000 2>/dev/null)" ]; then
        err "$OUT_DIR is writable by other users and has no sticky bit; refusing to write the page there. Use a private --out."
        exit 1
      fi
      if [ -n "$(find "$OUT_DIR/." -maxdepth 0 -perm -0020 ! -perm -1000 2>/dev/null)" ]; then
        note "warning: $OUT_DIR is group-writable without the sticky bit; anyone in its group could replace the page."
      fi
    fi
    ;;
esac

if [ -n "$PRICES" ] && [ ! -f "$PRICES" ]; then
  err "--prices '$PRICES' does not exist."
  exit 1
fi

# --- Kept fresh: what the page and the git half are built from -------------------
# Besides HEAD, the arguments and the transcripts, which the fingerprint holds,
# these files change what a build shows. Every candidate is listed, not only
# the one first_file would pick: one more rebuild after an edit costs little.
GIT_INPUTS=("$SELF" "${IAENG_REGISTRY:-}" "$PROJECT/Registry/employees.yml"
  "$PROJECT/ia-engineering/Registry/employees.yml" "$FRAMEWORK_DIR/Registry/employees.yml"
  "${IAENG_PROJECT_ROSTER:-}" "$PROJECT/.ia-engineering/Registry/employees.yml"
  "$PROJECT/Registry/chains.yml" "$PROJECT/ia-engineering/Registry/chains.yml"
  "$FRAMEWORK_DIR/Registry/chains.yml" "${IAENG_REGISTRY_WORK_UNITS:-}" "$PROJECT/Registry/work-units.yml"
  "$GIT_COMMON/refs/tags" "$GIT_COMMON/packed-refs")
FP_INPUTS=("${GIT_INPUTS[@]}" "$COLLECTOR" "$PRICES")

# any_newer <ref> <file...> — 0 when a file is newer than ref, or ref is gone.
any_newer() {
  local ref="$1" f
  shift
  [ -e "$ref" ] || return 0
  for f in "$@"; do [ -n "$f" ] && [ "$f" -nt "$ref" ] && return 0; done
  return 1
}

FP_FILE="$OUT_DIR/.${OUT##*/}.fingerprint"
FP_KEY="$SINCE|$PRICES|$TRANSCRIPTS_DIR|${IAENG_REGISTRY:-}|${IAENG_PROJECT_ROSTER:-}|${IAENG_REGISTRY_WORK_UNITS:-}"
FP_TEXT=""
# fp_text <transcripts-status> <listing> — the fingerprint, into FP_TEXT. The
# status is the collector's exit when it listed nothing (3 none, 4
# ambiguous), "none" without a collector, and 0 otherwise.
fp_text() {
  FP_TEXT="iaeng-usage-fingerprint 1
head $HEAD_SHA
key $FP_KEY
transcripts $1
$2"
}
# fp_now — the fingerprint of the project as it is now: one collector --list.
fp_now() {
  local listing="" rc=none la=(--project-dir "$PROJECT")
  [ -n "$TRANSCRIPTS_DIR" ] && la=(--transcripts-dir "$TRANSCRIPTS_DIR")
  if [ -f "$COLLECTOR" ]; then
    listing="$(bash "$COLLECTOR" "${la[@]}" --list 2>/dev/null)"
    rc=$?
    [ -z "$listing" ] || rc=0
  fi
  fp_text "$rc" "$listing"
}
# The page, when it is a regular file of this user's. Anything else is
# rebuilt, and the rename then replaces it.
page_ok() { [ -f "$OUT" ] && [ ! -L "$OUT" ] && [ -O "$OUT" ]; }
# page_ours — a page --no-wait may open without a build: one this script
# wrote, with its fingerprint beside it, and — in the work tree — ignored and
# untracked, the only case check-ignore answers 0. A page the repository
# supplied, even force-added under an ignore rule, is rebuilt first (PR #230
# security review, S2).
page_ours() {
  page_ok && [ -f "$FP_FILE" ] && [ ! -L "$FP_FILE" ] && [ -O "$FP_FILE" ] || return 1
  git -C "$PROJECT" check-ignore -q -- "$OUT" 2>/dev/null
  case "$?:$OUT" in
    0:*) return 0 ;;
    *:"$PROJECT"/*) return 1 ;;
    128:*) return 0 ;;
  esac
  return 1
}
# fp_fresh — 0 when the page is current: its fingerprint is this user's
# regular file, nothing it is built from is newer, and it equals fp_now.
fp_fresh() {
  local old=""
  page_ok && [ -f "$FP_FILE" ] && [ ! -L "$FP_FILE" ] && [ -O "$FP_FILE" ] || return 1
  any_newer "$FP_FILE" "${FP_INPUTS[@]}" && return 1
  IFS= read -r -d '' old < "$FP_FILE"
  fp_now
  [ "$old" = "$FP_TEXT" ]
}

# --- Kept fresh: the cache -----------------------------------------------------
# setup_cache — CACHE is the persistent cache, checked and created 0700, or
# "" with the reason in CACHE_WHY. A --watch build skips what its watch
# checked once (git, the folder's mode), as it does for the output folder.
CACHE_WHY=""
CACHE_SET=""
setup_cache() {
  local c="${IAENG_USAGE_CACHE:-$PROJECT/.ia-engineering/usage/cache}" rc
  c="${c//\\//}"
  CACHE=""
  CACHE_SET=1
  if [ -L "$c" ]; then CACHE_WHY="$c is a symbolic link or a junction"; return 1; fi
  if [ -e "$c" ] && [ ! -d "$c" ]; then CACHE_WHY="$c is not a directory"; return 1; fi
  if link_under "$PROJECT" "$c"; then CACHE_WHY="$c is reached through a symbolic link or a junction"; return 1; fi
  if [ -z "$WATCH_CHILD" ]; then
    # Never committed: in the work tree, git must ignore it, which is checked
    # before anything is created there. Any other answer for a path in the
    # project — 128 is also "beyond a symbolic link" — is a refusal; only a
    # path outside the project is outside the tree (S1).
    git -C "$PROJECT" check-ignore -q -- "$c/" 2>/dev/null
    rc=$?
    case "$rc:$c" in
      0:*) ;;
      1:*)
        CACHE_WHY="git does not ignore $c, so it could be committed; add .ia-engineering/usage/ to the project's .gitignore (install.sh does)"
        return 1 ;;
      *:"$PROJECT"/*)
        CACHE_WHY="git cannot say it ignores $c (exit $rc)"
        return 1 ;;
    esac
  fi
  if [ ! -d "$c" ] && ! mkdir -p "$c" 2>/dev/null; then CACHE_WHY="$c cannot be created"; return 1; fi
  if [ ! -O "$c" ]; then CACHE_WHY="$c is not owned by you"; return 1; fi
  case "${OSTYPE:-}" in
    msys*|cygwin*|win*) ;;
    *)
      if [ -z "$WATCH_CHILD" ]; then
        # Others able to rename in its folder could swap it (R3, above).
        if [ -n "$(find "$c/.." -maxdepth 0 -perm -0002 ! -perm -1000 2>/dev/null)" ]; then
          CACHE_WHY="the folder holding $c is writable by other users and has no sticky bit"
          return 1
        fi
        chmod 0700 "$c" 2>/dev/null
      fi
      ;;
  esac
  CACHE="$c"
}

# lock_try — 0 when this run now holds <cache>/lock, 1 when a live run holds
# it, 2 when it cannot be made. mkdir is the atomic test-and-set. A lock is
# stale once its owner's process is gone or it is older than LEASE; it is
# then renamed away first, which only one of two runs that judged it stale
# at the same moment can do.
lock_try() {
  local was old age
  LOCK="$CACHE/lock"
  if ! mkdir "$LOCK" 2>/dev/null; then
    [ -d "$LOCK" ] || return 2
    if read_lock_owner "$LOCK"; then
      now_epoch
      age=$((NOW_S - LOCK_T))
      # Older than the lease, started in the future (S3), or its process gone.
      [ "$age" -gt "$LEASE" ] || [ "$age" -lt 0 ] || ! kill -0 "$LOCK_PID" 2>/dev/null || return 1
    else
      # No owner yet (being written this instant), or a run that died
      # between the two steps: stale only past the lease.
      [ -n "$(find "$LOCK" -maxdepth 0 -mmin +$((LEASE / 60)) 2>/dev/null)" ] || return 1
    fi
    was="$LOCK_PID $LOCK_T"
    old="$LOCK.stale.$$"
    mv "$LOCK" "$old" 2>/dev/null || return 1
    # Another run took it over and made a fresh lock between the check and
    # the rename: that lock is given back.
    if read_lock_owner "$old" && [ "$LOCK_PID $LOCK_T" != "$was" ]; then
      mv "$old" "$LOCK" 2>/dev/null || rm -rf "$old"
      return 1
    fi
    rm -rf "$old"
    note "took over a stale lock (owner ${was% *} gone or older than $LEASE s)."
    mkdir "$LOCK" 2>/dev/null || return 1
  fi
  now_epoch
  printf '%s %s\n' "$$" "$NOW_S" > "$LOCK/owner"
  LOCK_HELD=1
}

# say <message> — a refresh's report, with the time: it reads as a log.
say() {
  local t
  printf -v t '%(%Y-%m-%d %H:%M:%S %z)T' -1 2>/dev/null || t="$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '%s usage-dashboard: %s\n' "$t" "$1"
}

# worker_log — a detached refresh writes to .ia-engineering/usage/refresh.log,
# moved to refresh.log.1 once past 64 KiB: at most twice that on disk. Not a
# link, not another user's, not a folder others can rename in; otherwise the
# refresh writes nowhere.
worker_log() {
  local dir="$PROJECT/.ia-engineering/usage" log
  log="$dir/refresh.log"
  ! link_under "$PROJECT" "$dir" || return 0
  [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 0
  if [ -L "$log" ] || { [ -e "$log" ] && { [ ! -f "$log" ] || [ ! -O "$log" ]; }; }; then return 0; fi
  case "${OSTYPE:-}" in
    msys*|cygwin*|win*) ;;
    *) [ -z "$(find "$dir/." -maxdepth 0 -perm -0002 ! -perm -1000 2>/dev/null)" ] || return 0 ;;
  esac
  if [ -n "$(find "$log" -maxdepth 0 -size +64k 2>/dev/null)" ]; then mv -f "$log" "$log.1" 2>/dev/null; fi
  exec >> "$log" 2>&1
}

# --- Kept fresh: the modes ---------------------------------------------------------

# --open --no-wait: the page as it is, at once, and a refresh behind it.
if [ -n "$NO_WAIT" ] && page_ours; then
  open_page "$OUT" || exit 1
  if lock_live "${IAENG_USAGE_CACHE:-$PROJECT/.ia-engineering/usage/cache}/lock"; then
    echo "Usage dashboard opened as it is; a refresh is already running (pid $LOCK_PID) and will update it."
  else
    spawn_worker now "$PROJECT" "$OUT"
    echo "Usage dashboard opened as it is; refreshing it in the background (log: .ia-engineering/usage/refresh.log)."
  fi
  exit 0
fi
# Without a page of its own yet, --no-wait builds one first: one that reloads
# itself, as a refresh's does.
if [ -n "$NO_WAIT" ]; then AUTO=1; REFRESH="$MIN_INTERVAL"; fi

# --open: at once when nothing the page is built from has changed.
if [ -n "$OPEN" ] && [ -z "$WATCH" ] && [ -z "$NO_WAIT" ] && fp_fresh; then
  echo "Usage dashboard is up to date (nothing it is built from has changed): $OUT"
  open_page "$OUT" || exit 1
  exit 0
fi

# --refresh: one at a time, at most one start per interval, nothing done when
# the fingerprint is unchanged. It then falls through to the build below,
# holding the lock, and its page reloads itself every interval.
if [ "$MODE" = --refresh ]; then
  # The cache is settled before anything is written: a detached refresh that
  # may not use it — a folder git does not ignore, a link — writes no log in
  # the work tree (QA of #230). It records why in the repository's git
  # directory instead, which git never shows or commits, and the hook reads
  # that to start no refresh for an interval.
  if ! setup_cache; then
    if [ -n "$WORKER" ]; then
      [ -d "$GIT_COMMON" ] && [ ! -L "$GIT_COMMON/$REFUSED_NAME" ] && now_epoch \
        && printf '%s\t%s\n' "$NOW_S" "${CACHE_WHY:0:400}" > "$GIT_COMMON/$REFUSED_NAME"
      exit 0
    fi
    say "refresh not done: the persistent cache cannot be used: $CACHE_WHY."
    exit 1
  fi
  [ -z "$WORKER" ] || worker_log
  say "refresh started (pid $$)."
  lock_try
  case "$?" in
    1) say "refresh skipped: another one is running (pid $LOCK_PID)."; exit 0 ;;
    2) say "refresh not done: cannot make the lock in $CACHE."; exit 1 ;;
  esac
  [ -z "$IAENG_USAGE_WORKER_DELAY" ] || sleep "$IAENG_USAGE_WORKER_DELAY"
  if [ "$WORKER" != now ] && read_number "$CACHE/refresh.stamp"; then
    now_epoch
    if [ $((NOW_S - NUM)) -ge 0 ] && [ $((NOW_S - NUM)) -lt "$MIN_INTERVAL" ]; then
      say "refresh skipped: the last refresh started $((NOW_S - NUM)) s ago (at most one every $MIN_INTERVAL s)."
      exit 0
    fi
  fi
  now_epoch
  printf '%s\n' "$NOW_S" > "$CACHE/refresh.stamp"
  if fp_fresh; then
    say "no change in HEAD, the transcripts or what the page is built from; page kept."
    exit 0
  fi
  AUTO=1
  REFRESH="$MIN_INTERVAL"
fi

# --- Live mode -------------------------------------------------------------------
# --watch rebuilds the page every N seconds until interrupted. Each build is a
# child run of this script, so a build that fails leaves the page as it was
# and the loop going; only a failing FIRST build stops it, since that is a
# configuration fault rather than a passing one. A cycle starts only after
# the previous one has finished, and is skipped when neither HEAD nor any
# transcript's size changed. The builds share the persistent cache (KEPT
# FRESH): the git half is computed once per HEAD, and only the transcripts
# that grew are read, from where the previous build stopped (usage-collect.sh)
# — so a new watch starts warm. For tests, IAENG_USAGE_WATCH_MAX_CYCLES stops
# after that many cycles and IAENG_USAGE_WATCH_SLEEP replaces the interval
# actually slept.

watch_loop() {
  local cycle=0 start fp last_fp="" opened="" rc nap interval
  local child_args=(--project-dir "$PROJECT" --out "$OUT") list_args=(--project-dir "$PROJECT")
  [ -n "$SINCE" ] && child_args+=(--since "$SINCE")
  [ -n "$PRICES" ] && child_args+=(--prices "$PRICES")
  if [ -n "$TRANSCRIPTS_DIR" ]; then
    child_args+=(--transcripts-dir "$TRANSCRIPTS_DIR")
    list_args=(--transcripts-dir "$TRANSCRIPTS_DIR")
  fi
  interval="${IAENG_USAGE_WATCH_SLEEP:-$WATCH}"
  WATCH_STATE="$(mktemp -d "${TMPDIR:-/tmp}/obs330-watch.XXXXXX")" || { err "cannot create a temporary directory"; return 1; }
  # The private directory every build renders its page into, created once
  # here, beside the page, and reused by each cycle's build.
  PAGE_DIR="$(mktemp -d "$OUT_DIR/.usage-dashboard.XXXXXX")" || { err "cannot create a private directory in $OUT_DIR"; return 1; }
  PAGE_DIR_OWN="$PAGE_DIR"
  export IAENG_USAGE_PAGEDIR="$PAGE_DIR"
  # Each build's work files — raw git output among them — stay in the watch's
  # own temporary directory, never in the cache. The cache is the persistent
  # one every run shares; when it may not be used, the watch keeps one of its
  # own until it stops, as before WU-IAENG-341.
  mkdir "$WATCH_STATE/build" || return 1
  export IAENG_USAGE_WORKDIR="$WATCH_STATE/build"
  if setup_cache; then
    export IAENG_USAGE_CACHE="$CACHE"
  else
    note "not using the persistent cache: $CACHE_WHY. This watch keeps a cache of its own until it stops."
    export IAENG_USAGE_CACHE="$WATCH_STATE/cache"
  fi
  trap 'note "stopped; the page keeps its last update."; exit 0' INT TERM
  # The transcript directories are resolved once, here, and handed to every
  # build (usage-collect.sh, IAENG_USAGE_TRANSCRIPT_DIRS). None found yet: each
  # cycle looks again, so a first session started after the watch is seen.
  if [ -f "$COLLECTOR" ] && [ -z "$TRANSCRIPTS_DIR" ]; then
    IAENG_USAGE_TRANSCRIPT_DIRS="$(bash "$COLLECTOR" --project-dir "$PROJECT" --dirs 2>/dev/null || true)"
    [ -z "$IAENG_USAGE_TRANSCRIPT_DIRS" ] || export IAENG_USAGE_TRANSCRIPT_DIRS
  fi
  note "watching $PROJECT every $WATCH s; the page reloads itself. Ctrl-C to stop."
  while :; do
    cycle=$((cycle + 1))
    start=$SECONDS
    fp="$(git -C "$PROJECT" rev-parse HEAD 2>/dev/null)"
    if [ -f "$COLLECTOR" ]; then
      fp="$fp
$(bash "$COLLECTOR" "${list_args[@]}" --list 2>/dev/null)"
    fi
    if [ "$fp" = "$last_fp" ]; then
      now_hms
      note "$NOW no change in HEAD or the transcripts; page kept ($((SECONDS - start)) s)"
    elif IAENG_USAGE_REFRESH="$WATCH" bash "$SELF" "${child_args[@]}" > /dev/null 2> "$WATCH_STATE/build.err"; then
      last_fp="$fp"
      now_hms
      note "$NOW rebuilt in $((SECONDS - start)) s: $OUT"
      if [ -n "$OPEN" ] && [ -z "$opened" ]; then
        opened=1
        open_page "$OUT" || return 1
      fi
    else
      rc=$?
      now_hms
      note "$NOW rebuild failed (exit $rc); the page keeps its last update:"
      sed 's/^/    /' "$WATCH_STATE/build.err" >&2
      [ "$cycle" -gt 1 ] || return 1
    fi
    if [ -n "${IAENG_USAGE_WATCH_MAX_CYCLES:-}" ] && [ "$cycle" -ge "$IAENG_USAGE_WATCH_MAX_CYCLES" ]; then
      return 0
    fi
    nap=$((10#$interval - (SECONDS - start)))
    [ "$nap" -ge 1 ] || nap=1
    sleep "$nap"
  done
}

if [ -n "$WATCH" ]; then
  watch_loop
  exit $?
fi

# --- The build ---------------------------------------------------------------------

# The persistent cache (a refresh has settled it already), held under its
# lock. A run that finds the lock taken waits for that run to end — with
# --open, its page may then be current — and a lock that cannot be made, or
# is not released within the lease, leaves this run to a cache of its own.
[ -n "$CACHE_SET" ] || setup_cache || note "not using the persistent cache: $CACHE_WHY. This run reads everything again."
if [ -n "$CACHE" ] && [ -z "$LOCK_HELD" ]; then
  lock_try
  lrc=$?
  if [ "$lrc" = 1 ]; then
    note "waiting for the refresh that is running (pid ${LOCK_PID:-unknown}) to finish..."
    waited=0
    while [ "$lrc" = 1 ] && [ "$waited" -le $((LEASE + 60)) ]; do
      sleep 1
      waited=$((waited + 1))
      lock_try
      lrc=$?
    done
    if [ "$lrc" = 0 ] && [ -n "$OPEN" ] && fp_fresh; then
      echo "Usage dashboard is up to date (the refresh that just ended rebuilt it): $OUT"
      open_page "$OUT" || exit 1
      exit 0
    fi
  fi
  if [ "$lrc" != 0 ]; then
    note "cannot lock the persistent cache $CACHE; this run reads everything again."
    CACHE=""
  fi
fi

# A build started by --watch works in a fixed directory the watch made in its
# own temporary state, overwritten each cycle and removed with it: no mktemp
# and no rm per cycle. Any other build uses a temporary directory of its own.
# Never the cache: these files hold raw git output.
W="${IAENG_USAGE_WORKDIR:-}"
if [ -n "$W" ] && [ -d "$W" ] && [ ! -L "$W" ] && [ -O "$W" ]; then
  TMPD="$W"
else
  TMPD="$(mktemp -d "${TMPDIR:-/tmp}/obs326-usage.XXXXXX")" || { err "cannot create a temporary directory"; exit 1; }
  TMPD_OWN="$TMPD"
fi

# Sources, for the page header: name <TAB> found|missing|error <TAB> detail.
SOURCES="$TMPD/sources.tsv"
: > "$SOURCES"
source_line() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$SOURCES"; }

# first_file <candidate...> — the first candidate that names an existing file.
first_file() {
  local c
  for c in "$@"; do
    if [ -n "$c" ] && [ -f "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

# Paths shown on the page are relative to the project, or to the framework,
# so the page does not carry the local directory layout of the machine.
show_path() {
  case "$1" in
    "$PROJECT"/*) printf '%s' "${1#"$PROJECT"/}" ;;
    "$FRAMEWORK_DIR"/*) printf 'framework:%s' "${1#"$FRAMEWORK_DIR"/}" ;;
    *) printf '%s' "$(basename -- "$1")" ;;
  esac
}

# A git value matching a credential family counts as "(redacted)" before any
# shape check — the same expression as usage-collect.sh's SECRET_RE, kept
# equal by a test in tests/run.sh rather than by memory.
SECRET_RE='AKIA[0-9A-Z]{12}|ASIA[0-9A-Z]{12}|gh[pousr]_[A-Za-z0-9]{16}|xox[baprs]-|xapp-|sk_(live|test)_|rk_(live|test)_|sk-ant-|sk-[A-Za-z0-9]{20}|AIza[0-9A-Za-z_-]{20}|eyJ[A-Za-z0-9_-]+\.|hf_[A-Za-z0-9]{20}|glpat-|npm_[A-Za-z0-9]{20}|BEGIN.*PRIVATE|[A-Za-z0-9]{24}'

# Everything read from git and the registries: the rosters, the chains, the
# Work Unit registry, and the per-commit trailers.
collect_git_side() {
  # --- Rosters ---------------------------------------------------------------------
  # The same resolution as check-employee-trailers.sh, with the framework this
  # script belongs to as the last candidate: a project that vendors the
  # framework under ia-engineering/ finds it there, and a run from anywhere else
  # still has the roster the script shipped with.

  ROSTER_TSV="$TMPD/roster.tsv"
  if ! ROSTER="$(first_file "${IAENG_REGISTRY:-}" "$PROJECT/Registry/employees.yml" \
      "$PROJECT/ia-engineering/Registry/employees.yml" "$FRAMEWORK_DIR/Registry/employees.yml")"; then
    err "Could not locate Registry/employees.yml (looked at \$IAENG_REGISTRY, the project's Registry/ and ia-engineering/Registry/, and $FRAMEWORK_DIR/Registry/). Without the roster, never-used Employees cannot be shown."
    exit 1
  fi
  # Tabs are written by awk, never by a sed replacement: `\t` in sed's
  # replacement is a GNU extension, and BSD sed (macOS) writes a literal `t`,
  # which would join every name to its source and show the whole roster as
  # never used.
  grep -E '^  - name: ' "$ROSTER" | sed 's/^  - name: //' | tr -d '\r' \
    | awk -v src=framework '{ print $0 "\t" src }' > "$ROSTER_TSV"
  if [ ! -s "$ROSTER_TSV" ]; then
    err "$ROSTER yielded no Employee names (parsing contract: '  - name: <Name>')."
    exit 1
  fi
  source_line "Employee roster" found "$(show_path "$ROSTER") ($(grep -c . "$ROSTER_TSV") Employees)"

  PROJECT_ROSTER=""
  if [ -n "${IAENG_PROJECT_ROSTER:-}" ]; then
    if [ ! -f "$IAENG_PROJECT_ROSTER" ]; then
      err "IAENG_PROJECT_ROSTER is set to '$IAENG_PROJECT_ROSTER' but no such file exists; fix the path or unset it."
      exit 1
    fi
    PROJECT_ROSTER="$IAENG_PROJECT_ROSTER"
  elif [ -f "$PROJECT/.ia-engineering/Registry/employees.yml" ]; then
    PROJECT_ROSTER="$PROJECT/.ia-engineering/Registry/employees.yml"
  fi
  if [ -n "$PROJECT_ROSTER" ]; then
    before="$(grep -c . "$ROSTER_TSV")"
    grep -E '^  - name: ' "$PROJECT_ROSTER" | sed 's/^  - name: //' | tr -d '\r' \
      | awk -v src=project '{ print $0 "\t" src }' >> "$ROSTER_TSV"
    source_line "Project roster" found "$(show_path "$PROJECT_ROSTER") ($(( $(grep -c . "$ROSTER_TSV") - before )) Domain Employees)"
  else
    source_line "Project roster" missing "no .ia-engineering/Registry/employees.yml (no Domain Employees)"
  fi

  # --- Chains ----------------------------------------------------------------------
  # chain <TAB> employee|gate <TAB> name <TAB> always|conditional, in file order.
  # A step is conditional when it carries a `when:` other than `Always`.

  CHAINS_TSV="$TMPD/chains.tsv"
  : > "$CHAINS_TSV"
  if CHAINS="$(first_file "$PROJECT/Registry/chains.yml" "$PROJECT/ia-engineering/Registry/chains.yml" \
      "$FRAMEWORK_DIR/Registry/chains.yml")"; then
    tr -d '\r' < "$CHAINS" | awk -v OFS='\t' '
      function flush() { if (kind != "") print chain, kind, name, cond; kind = "" }
      /^  - name: /         { flush(); chain = substr($0, 11); next }
      /^      - employee: / { flush(); kind = "employee"; name = substr($0, 19); cond = "always"; next }
      /^      - gate: /     { flush(); kind = "gate"; name = substr($0, 15); cond = "always"; next }
      /^        when: /     { if (kind != "" && substr($0, 15) != "Always") cond = "conditional"; next }
      END { flush() }
    ' > "$CHAINS_TSV"
    source_line "Agent Chains" found "$(show_path "$CHAINS") ($(cut -f1 "$CHAINS_TSV" | sort -u | grep -c .) chains)"
  else
    source_line "Agent Chains" missing "no Registry/chains.yml"
  fi

  # --- Work Unit registry ------------------------------------------------------------

  WUS_TSV="$TMPD/wus.tsv"
  : > "$WUS_TSV"
  if WUS="$(first_file "${IAENG_REGISTRY_WORK_UNITS:-}" "$PROJECT/Registry/work-units.yml")"; then
    tr -d '\r' < "$WUS" | awk -v OFS='\t' '
      /^  - id: /       { id = substr($0, 9); next }
      /^    employee: / { if (id != "") { print id, substr($0, 15); id = "" } }
    ' > "$WUS_TSV"
    source_line "Work Unit registry" found "$(show_path "$WUS") ($(grep -c . "$WUS_TSV") Work Units)"
  else
    source_line "Work Unit registry" missing "no Registry/work-units.yml in the project"
  fi

  # --- Git history ---------------------------------------------------------------------

  if [ -z "$SINCE" ]; then
    SINCE="$(git -C "$PROJECT" describe --tags --abbrev=0 --match 'v*' HEAD 2>/dev/null || true)"
  fi
  INRANGE="$TMPD/inrange.txt"
  if [ -n "$SINCE" ]; then
    if ! git -C "$PROJECT" rev-parse -q --verify "$SINCE^{commit}" >/dev/null; then
      err "--since '$SINCE' is not a commit in $PROJECT."
      exit 1
    fi
    RANGE_LABEL="since $SINCE"
    if ! git -C "$PROJECT" rev-list --no-merges "$SINCE..HEAD" > "$INRANGE"; then
      err "git rev-list failed over $SINCE..HEAD."
      exit 1
    fi
  else
    RANGE_LABEL="all time (no release tag)"
    if ! git -C "$PROJECT" rev-list --no-merges HEAD > "$INRANGE"; then
      err "git rev-list failed."
      exit 1
    fi
  fi

  # Employee and Co-Authored-By are read as REAL trailers, parsed by git from
  # the message's trailer block (PR #196 review, F3): a line that merely looks
  # like one in the body is not attribution, and nothing else of the body is
  # read. `Work Unit:` cannot be a git trailer (its key has a space;
  # Standards/COMMIT_STANDARD.md, Trailers), so it is read as check-work-units.sh
  # reads it — a column-0 line — and kept only when it is a Work Unit ID.
  TRAILERS="$TMPD/trailers.txt"
  BODIES="$TMPD/bodies.txt"
  NUMSTAT="$TMPD/numstat.txt"
  if ! git -C "$PROJECT" log --no-merges \
      --format='%x1e%H%x1f%(trailers:key=Employee,valueonly,unfold,separator=%x1d)%x1f%(trailers:key=Co-authored-by,valueonly,unfold,separator=%x1d)' > "$TRAILERS" \
    || ! git -C "$PROJECT" log --no-merges --format='%x1e%H%n%B' > "$BODIES" \
    || ! git -C "$PROJECT" log --no-merges --format='%x1e%H' --numstat > "$NUMSTAT"; then
    err "git log failed in $PROJECT."
    exit 1
  fi

  # sha <TAB> in-range <TAB> employee <TAB> work-unit <TAB> model <TAB> added <TAB> deleted
  # Every emitted value is shape-checked: an Employee or model name is one short
  # name ([A-Za-z0-9 ._()/-], at most 64 characters, no `@`), a Work Unit is
  # ^WU-[A-Z0-9]+-[0-9]+$. Absent is "(no trailer)", malformed "(unrecognised)".
  # The model is the name of the co-author whose address is the runtime's
  # <noreply@anthropic.com>, not whichever co-author came first.
  # The four file names reach awk through the environment, not -v: -v
  # processes backslash escapes, and a Windows TMPDIR (C:\Users\...) would be
  # mangled so that no FILENAME ever matched and every commit vanished.
  # A value matching a credential family counts as "(redacted)" before any
  # shape check: SECRET_RE, defined above this function.
  COMMITS_TSV="$TMPD/commits.tsv"
  F_INR="$INRANGE" F_NUM="$NUMSTAT" F_TR="$TRAILERS" F_BODY="$BODIES" F_SECRET="$SECRET_RE" awk -v OFS='\t' '
    BEGIN { f_inr = ENVIRON["F_INR"]; f_num = ENVIRON["F_NUM"]; f_tr = ENVIRON["F_TR"]; f_body = ENVIRON["F_BODY"]; secret = ENVIRON["F_SECRET"] }
    function shaped(v,   ok) {
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v == "") return "(no trailer)"
      if (v ~ secret) return "(redacted)"
      ok = (v ~ /^[A-Za-z0-9][-A-Za-z0-9 ._()\/]*$/ && length(v) <= 64 && index(v, "@") == 0)
      return ok ? v : "(unrecognised)"
    }
    { sub(/\r$/, "") }
    FILENAME == f_inr { inr[$0] = 1; next }
    FILENAME == f_num {
      if (substr($0, 1, 1) == "\036") { cur = substr($0, 2); next }
      split($0, ns, "\t")
      if (ns[1] ~ /^[0-9]+$/) add[cur] += ns[1]
      if (ns[2] ~ /^[0-9]+$/) del[cur] += ns[2]
      next
    }
    FILENAME == f_tr {
      if (substr($0, 1, 1) != "\036") next
      n = split(substr($0, 2), tf, "\037")
      sha = tf[1]; order[++nc] = sha
      split(tf[2], emps, "\035"); emp[sha] = shaped(emps[1])
      model[sha] = "(no trailer)"
      m = split(tf[3], coauth, "\035")
      for (i = 1; i <= m; i++) {
        if (index(coauth[i], "<noreply@anthropic.com>") > 0) {
          v = coauth[i]; sub(/[ \t]*<.*$/, "", v); model[sha] = shaped(v); break
        }
      }
      next
    }
    FILENAME == f_body {
      if (substr($0, 1, 1) == "\036") { bsha = substr($0, 2); next }
      if (!(bsha in wu) && $0 ~ /^Work Unit: /) {
        v = substr($0, 12); sub(/[ \t]+$/, "", v)
        wu[bsha] = (v ~ /^WU-[A-Z0-9]+-[0-9]+$/) ? v : "(unrecognised)"
      }
    }
    END {
      for (k = 1; k <= nc; k++) {
        s = order[k]
        print s, (s in inr ? 1 : 0), emp[s], ((s in wu) ? wu[s] : "(no trailer)"), model[s], add[s] + 0, del[s] + 0
      }
    }
  ' "$INRANGE" "$NUMSTAT" "$TRAILERS" "$BODIES" > "$COMMITS_TSV" || {
    err "reading the commit trailers failed (awk). A page built on it would show every Employee as never used; no page was written."
    exit 1
  }
  source_line "Git history" found "$(grep -c . "$COMMITS_TSV") non-merge commits; range: $RANGE_LABEL"
  printf '%s' "$RANGE_LABEL" > "$TMPD/range.txt"
}

# The git half is the same for as long as HEAD is: it is computed once per
# HEAD and reused from the persistent cache, across runs and watches. The key
# also carries what changes its meaning without a commit — the --since
# argument and the registry overrides — and a key older than a registry, the
# tag refs or this script is not trusted: an uncommitted registry edit, a new
# release tag or a new version of this script recomputes it.
ROSTER_TSV="$TMPD/roster.tsv"
CHAINS_TSV="$TMPD/chains.tsv"
WUS_TSV="$TMPD/wus.tsv"
COMMITS_TSV="$TMPD/commits.tsv"
GIT_CACHE="${CACHE:+$CACHE/git}"
GIT_KEY=""
CACHED_KEY=""
if [ -n "$GIT_CACHE" ]; then
  GIT_KEY="$HEAD_SHA|${SINCE}|${IAENG_REGISTRY:-}|${IAENG_PROJECT_ROSTER:-}|${IAENG_REGISTRY_WORK_UNITS:-}"
  [ -f "$GIT_CACHE/key" ] && [ ! -L "$GIT_CACHE/key" ] && IFS= read -r CACHED_KEY < "$GIT_CACHE/key"
  any_newer "$GIT_CACHE/key" "${GIT_INPUTS[@]}" && CACHED_KEY=""
fi
if [ -n "$GIT_CACHE" ] && [ "$GIT_KEY" = "$CACHED_KEY" ]; then
  # A hit is read in place — no copy, which would be one more process per
  # cycle — except the sources list, which this build appends to: that is
  # copied line by line with builtins.
  ROSTER_TSV="$GIT_CACHE/roster.tsv"
  CHAINS_TSV="$GIT_CACHE/chains.tsv"
  WUS_TSV="$GIT_CACHE/wus.tsv"
  COMMITS_TSV="$GIT_CACHE/commits.tsv"
  IFS= read -r RANGE_LABEL < "$GIT_CACHE/range.txt" || true
  # A cached label is one of the two shapes this script writes, or neither.
  [[ "$RANGE_LABEL" =~ ^(since\ [A-Za-z0-9._/-]{1,100}|all\ time\ \(no\ release\ tag\))$ ]] \
    || RANGE_LABEL="all time (cached label unreadable)"
  while IFS= read -r sline; do printf '%s\n' "$sline"; done < "$GIT_CACHE/sources.tsv" > "$SOURCES"
else
  collect_git_side
  # The key is emptied first and written last: files copied by a run that
  # stopped half-way never pass for the HEAD of the key they sit beside.
  if [ -n "$GIT_CACHE" ] && { [ -d "$GIT_CACHE" ] || mkdir -p "$GIT_CACHE"; } && : > "$GIT_CACHE/key" \
      && cp "$ROSTER_TSV" "$CHAINS_TSV" "$WUS_TSV" "$COMMITS_TSV" "$SOURCES" "$TMPD/range.txt" "$GIT_CACHE"/; then
    printf '%s\n' "$GIT_KEY" > "$GIT_CACHE/key"
  fi
fi

# --- AI-runtime transcripts -------------------------------------------------------------

USAGE_TSV="$TMPD/usage.tsv"
: > "$USAGE_TSV"
# The listing the collector worked from becomes the page's fingerprint, so a
# build costs no second listing. Emptied first: a watch reuses this directory.
LISTING_FILE="$TMPD/listing.txt"
: > "$LISTING_FILE"
COLLECT_RC=none
if [ -f "$COLLECTOR" ]; then
  collect_args=(--project-dir "$PROJECT" --listing-out "$LISTING_FILE")
  [ -n "$TRANSCRIPTS_DIR" ] && collect_args+=(--transcripts-dir "$TRANSCRIPTS_DIR")
  [ -n "$CACHE" ] && collect_args+=(--cache-dir "$CACHE/transcripts")
  if [ -z "$CACHE" ] || [ ! -f "$CACHE/transcripts/v1/index.tsv" ]; then
    note "reading Claude Code transcripts (a large project can take a minute)..."
  fi
  bash "$COLLECTOR" "${collect_args[@]}" > "$USAGE_TSV" 2> "$TMPD/collect.err"
  rc=$?
  COLLECT_RC="$rc"
  case "$rc" in
    0)
      # The collector prints its `source` line first; read it with a builtin.
      read -r _ ndirs nfiles ncalls ndisp < "$USAGE_TSV"
      dsuffix="ies"; [ "$ndirs" = 1 ] && dsuffix="y"
      source_line "Claude Code transcripts" found "$nfiles files in $ndirs director$dsuffix; $ncalls API calls, $ndisp dispatches" ;;
    3)
      : > "$USAGE_TSV"
      source_line "Claude Code transcripts" missing "none found for this project" ;;
    4)
      # Several transcript directories could be this project's, and the
      # collector refused to guess (code review M1). Nothing is counted
      # rather than another project's usage.
      : > "$USAGE_TSV"
      note "transcripts are AMBIGUOUS for this project; none are counted. Pass --transcripts-dir, or set CLAUDE_CODE_PROJECT_DIR_NAME with CLAUDE_CONFIG_DIR."
      source_line "Claude Code transcripts" ambiguous "several directories could be this project's (its path is longer than the runtime keeps); none counted. Pass --transcripts-dir, or set CLAUDE_CODE_PROJECT_DIR_NAME with CLAUDE_CONFIG_DIR" ;;
    *)
      : > "$USAGE_TSV"
      note "the Claude Code collector failed (exit $rc); the page is built without transcript data: $(head -c 300 "$TMPD/collect.err")"
      source_line "Claude Code transcripts" error "collector exit $rc; see the command's output" ;;
  esac
else
  source_line "Claude Code transcripts" missing "no runtime collector installed"
fi
# What this build read, recorded beside the page once it is written — the
# form fp_now computes. A collector that failed records nothing: the next
# --open or refresh then rebuilds rather than keep an error page as current.
FP_BUILD=""
case "$COLLECT_RC" in
  0|3|4|none)
    listing=""
    [ -s "$LISTING_FILE" ] && IFS= read -r -d '' listing < "$LISTING_FILE"
    trc="$COLLECT_RC"
    [ -z "$listing" ] || trc=0
    fp_text "$trc" "$listing"
    FP_BUILD="$FP_TEXT" ;;
esac

PRICES_TSV="$TMPD/prices.tsv"
: > "$PRICES_TSV"
if [ -n "$PRICES" ]; then
  tr -d '\r' < "$PRICES" | grep -vE '^[[:space:]]*(#|$)' > "$PRICES_TSV" || true
  source_line "Prices" found "$(grep -c . "$PRICES_TSV") model price line(s), USD per million tokens"
else
  source_line "Prices" missing "no --prices file; no cost is shown"
fi

# --- Aggregate ---------------------------------------------------------------------------

# The `Engineer` placeholder in Registry/chains.yml stands for whichever
# implementing Employee the work needs (that file's header lists them). Its
# usage is the sum of theirs, labelled as such on the page.
ENGINEERS="Backend Engineer|Frontend Engineer|iOS Engineer|Android Engineer|Cross-Platform Engineer|Database Engineer|Event-Driven Engineer|Integration Engineer"

JQ_BUILD="$(cat <<'JQ'
def rows($s): $s | split("\n") | map(select(length > 0) | split("\t"));
def slug: ascii_downcase | gsub("/"; " ") | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | rtrimstr("-");
def clip: tostring | if length > 80 then .[0:77] + "..." else . end;
def tally(f): reduce .[] as $x ({}; .[$x | f] += 1);
# Under --watch the commit rows may come from the cache: they pass the same
# shapes again rather than being trusted (PR #204 review, F3).
def bucket: . == "(no trailer)" or . == "(unrecognised)" or . == "(redacted)";
def gitname: if type != "string" then "(unrecognised)" elif bucket then .
             elif test("^[A-Za-z0-9][A-Za-z0-9 ._()/-]{0,63}$") | not then "(unrecognised)"
             elif test($secret) then "(redacted)" else . end;
def gitwu: if type == "string" and (bucket or test("^WU-[A-Z0-9]+-[0-9]+$")) then . else "(unrecognised)" end;
def count: if type == "string" and test("^[0-9]{1,12}$") then tonumber else 0 end;
# The sources list may come from the cache too: a status is one this script
# writes, and a name or detail is one bounded line of text.
def srcstatus: if . == "found" or . == "missing" or . == "error" or . == "ambiguous" then . else "error" end;
def srctext: tostring | if length > 300 then .[0:297] + "..." else . end;

(rows($commits) | map(select(length == 7)
                      | {sha: .[0], inr: (.[1] == "1"), emp: (.[2] | gitname), wu: (.[3] | gitwu),
                         model: (.[4] | gitname), add: (.[5] | count), del: (.[6] | count)})) as $c
| (rows($usage)) as $u
| ($u | map(select(.[0] == "dispatch") | {type: .[1], model: .[2], n: (.[3] | tonumber)})) as $disp
| ($u | map(select(.[0] == "call") | {day: .[1], model: .[2], agent: .[3],
        input: (.[4] | tonumber), output: (.[5] | tonumber), cw: (.[6] | tonumber),
        cr: (.[7] | tonumber), calls: (.[8] | tonumber)})) as $calls
| (reduce $disp[] as $d ({}; .[$d.type] += $d.n)) as $dispByType
| ($c | tally(.emp)) as $commitsAll
| ($c | map(select(.inr)) | tally(.emp)) as $commitsRange
| (rows($wus)) as $wuRows
| ($wuRows | tally(.[1])) as $wuByEmp
| (reduce rows($roster)[] as $r ([]; if (map(.[0]) | index($r[0])) != null then . else . + [$r] end)) as $rosterRows
| ($rosterRows | map(.[0] | slug)) as $rosterSlugs
| ($rosterRows | map(.[0])) as $rosterNames
| ($rosterRows | map(.[0] as $n | {
      name: $n, roster: .[1],
      dispatches: ($dispByType[$n | slug] // 0),
      commits_range: ($commitsRange[$n] // 0),
      commits_all: ($commitsAll[$n] // 0),
      work_units: ($wuByEmp[$n] // 0)
    } | .activity = (.dispatches + .commits_all + .work_units)
      | .status = (if .activity == 0 then "never" elif (.dispatches + .commits_all) < 3 then "rare" else "used" end))
  | sort_by(-.dispatches, -.commits_all, -.work_units, .name)) as $employees
| ($employees | map({key: .name, value: .}) | from_entries) as $empIdx
| ($engineers | split("|") | map(select(. as $e | $rosterNames | index($e)))) as $engSet
| (rows($chains) | reduce .[] as $r ([];
      if (length > 0 and .[-1].name == $r[0]) then .[-1].steps += [$r] else . + [{name: $r[0], steps: [$r]}] end)
   | map(.steps |= (to_entries | map(.value as $s | {n: (.key + 1), kind: $s[1], name: $s[2], conditional: ($s[3] == "conditional")}
        | if .kind == "gate" then .
          elif .name == "Engineer" then
            .placeholder = true
            | .dispatches = ([$engSet[] | $empIdx[.].dispatches] | add // 0)
            | .commits_all = ([$engSet[] | $empIdx[.].commits_all] | add // 0)
            | .commits_range = ([$engSet[] | $empIdx[.].commits_range] | add // 0)
          else
            .dispatches = ($empIdx[.name].dispatches // 0)
            | .commits_all = ($empIdx[.name].commits_all // 0)
            | .commits_range = ($empIdx[.name].commits_range // 0)
            | .on_roster = ($empIdx[.name] != null)
          end
        | if .kind == "employee" then .exercised = ((.dispatches + .commits_all) > 0) else . end)))
   | map(.exercised = ([.steps[] | select(.kind == "employee" and .exercised)] | length)
         | .employee_steps = ([.steps[] | select(.kind == "employee")] | length))) as $chainList
| ($disp | map(select(.type as $t | $rosterSlugs | index($t) | not))
   | group_by(.type) | map({type: .[0].type, dispatches: (map(.n) | add)}) | sort_by(-.dispatches, .type)) as $otherAgents
| ($disp | sort_by(.type, .model)) as $dispModels
| ($c | map(select(.emp != "(no trailer)" and (.emp as $e | $rosterNames | index($e) | not)))
   | group_by(.emp) | map({name: .[0].emp, commits: length}) | sort_by(-.commits)) as $unrostered
| ($c | group_by(.model) | map({model: .[0].model, commits_all: length, commits_range: (map(select(.inr)) | length)})
   | sort_by(-.commits_all)) as $commitModels
| (rows($prices) | map({key: .[0], value: {input: (.[1] | tonumber? // 0), output: (.[2] | tonumber? // 0),
                                             cw: (.[3] | tonumber? // 0), cr: (.[4] | tonumber? // 0)}}) | from_entries) as $price
| def sums: {calls: (map(.calls) | add // 0), input: (map(.input) | add // 0), output: (map(.output) | add // 0),
             cw: (map(.cw) | add // 0), cr: (map(.cr) | add // 0)}
            | .total = (.input + .output + .cw + .cr)
            | .cache_read_share = (if (.input + .cw + .cr) > 0 then (.cr / (.input + .cw + .cr)) else 0 end);
  def cost($m): if $price[$m] then ((.input * $price[$m].input + .output * $price[$m].output
                                      + .cw * $price[$m].cw + .cr * $price[$m].cr) / 1000000) else null end;
{
  generated: $generated, project: $project, range: $range_label,
  sources: (rows($sources) | map({name: (.[0] | srctext), status: (.[1] // "" | srcstatus), detail: (.[2] // "" | srctext)})),
  have_transcripts: (($calls | length) > 0 or ($disp | length) > 0),
  have_prices: (($price | length) > 0),
  employees: $employees,
  other_agents: $otherAgents,
  dispatch_models: $dispModels,
  unrostered: $unrostered,
  chains: $chainList,
  engineer_set: $engSet,
  commit_models: $commitModels,
  calls_by_model: ($calls | group_by(.model) | map(.[0].model as $m | sums + {model: $m} | .cost = cost($m)) | sort_by(-.calls)),
  tokens_by_day: ($calls | group_by(.day) | map(sums + {day: .[0].day}) | sort_by(.day) | reverse),
  tokens_by_agent: ($calls | group_by(.agent) | map(sums + {agent: .[0].agent}) | sort_by(-.total)),
  work_units: ($c | map(select(.wu | startswith("WU-"))) | group_by(.wu)
               | map(.[0].wu as $id | {id: $id,
                     employee: (($wuRows | map(select(.[0] == $id)) | .[0][1]) // .[0].emp),
                     commits: length, commits_range: (map(select(.inr)) | length),
                     lines: (map(.add + .del) | add)})
               | sort_by(-.commits, -.lines) | .[0:30]),
  totals: {
    roster: ($employees | length),
    never: ($employees | map(select(.status == "never")) | length),
    rare: ($employees | map(select(.status == "rare")) | length),
    dispatches: ($disp | map(.n) | add // 0),
    commits_all: ($c | length),
    commits_range: ($c | map(select(.inr)) | length),
    tokens: ($calls | sums)
  }
}
JQ
)"

# Local time with its UTC offset, so "last updated" reads as the reader's
# clock. The printf builtin where bash has it (4.2+); date(1) otherwise.
printf -v GENERATED '%(%Y-%m-%d %H:%M:%S %z)T' -1 2>/dev/null \
  || GENERATED="$(date '+%Y-%m-%d %H:%M:%S %z')"

BUILD_ARGS=(--rawfile commits "$COMMITS_TSV" --rawfile usage "$USAGE_TSV" --rawfile wus "$WUS_TSV"
  --rawfile roster "$ROSTER_TSV" --rawfile chains "$CHAINS_TSV" --rawfile sources "$SOURCES"
  --rawfile prices "$PRICES_TSV" --arg engineers "$ENGINEERS"
  --arg generated "$GENERATED" --arg project "${PROJECT##*/}" --arg range_label "$RANGE_LABEL"
  --arg secret "$SECRET_RE")
DATA="$TMPD/data.json"
# A --watch build renders straight from the aggregate in the same jq process
# (below); a plain build keeps the aggregate, which also prints the summary.
if [ -z "$REFRESH" ] && ! jq -n "${BUILD_ARGS[@]}" "$JQ_BUILD" > "$DATA"; then
  err "aggregating the collected data failed (jq). No page was written."
  exit 1
fi

# --- Render ------------------------------------------------------------------------------
# One jq program turns the aggregate into the page. Every string goes through
# @html; the embedded JSON copy has `<` escaped so it cannot close its script.

JQ_RENDER="$(cat <<'JQ'
def e: tostring | @html;
def commas: tostring as $s | if ($s | length) <= 3 then $s else ($s[0:-3] | commas) + "," + $s[-3:] end;
def n: if type == "number" then (round | commas) else e end;
def pct: (. * 1000 | round / 10 | tostring) + "%";
def usd: if . == null then "n/a" else ((. * 100 | round) / 100 | tostring | "$" + .) end;
def short: tostring | if length > 34 then .[0:31] + "..." else . end;

# cell: a number (sortable, right-aligned), a string, or {h: raw-html, v: sort-key}.
def cell: if type == "number" then "<td class=\"num\" data-v=\"\(.)\">\(n)</td>"
          elif type == "object" then "<td data-v=\"\(.v | e)\">\(.h)</td>"
          elif . == null then "<td data-v=\"\">n/a</td>"
          else "<td>\(e)</td>" end;
def table($caption; $heads; $rows):
  "<div class=\"tw\"><table class=\"sortable\"><caption>\($caption | e)</caption><thead><tr>"
  + ($heads | map("<th scope=\"col\" data-type=\"\(.[1])\"><button type=\"button\">\(.[0] | e)</button></th>") | join(""))
  + "</tr></thead><tbody>"
  + (if ($rows | length) == 0 then "<tr><td colspan=\"\($heads | length)\" class=\"empty\">No data.</td></tr>"
     else ($rows | map("<tr\(if .cls then " class=\"" + .cls + "\"" else "" end)>" + (.cells | map(cell) | join("")) + "</tr>") | join("")) end)
  + "</tbody></table></div>";
def barchart($title; $rows):
  ($rows | map(.value) | max // 0) as $max
  | if ($rows | length) == 0 then "<p class=\"empty\">\($title | e): no data.</p>" else
  "<figure><figcaption>\($title | e)</figcaption><svg role=\"img\" aria-label=\"\($title | e)\" viewBox=\"0 0 720 \(($rows | length) * 24 + 8)\" preserveAspectRatio=\"xMinYMin meet\">"
  + ([$rows | to_entries[] | .key as $i | .value as $r | ($i * 24 + 4) as $y
      | (if $max > 0 then ($r.value / $max * 360) else 0 end) as $w
      | "<g><title>\($r.label | e): \($r.value | n)</title>"
        + "<text x=\"236\" y=\"\($y + 15)\" class=\"lbl\" text-anchor=\"end\">\($r.label | short | e)</text>"
        + (if $w > 0 then "<rect x=\"244\" y=\"\($y + 3)\" width=\"\([$w, 2] | max)\" height=\"16\" rx=\"3\" class=\"bar\"/>" else "" end)
        + "<text x=\"\(250 + $w)\" y=\"\($y + 15)\" class=\"val\">\($r.value | n)</text></g>"] | join(""))
  + "</svg></figure>" end;
def badge: if . == "never" then {h: "<span class=\"badge never\">NEVER USED</span>", v: "0"}
           elif . == "rare" then {h: "<span class=\"badge rare\">rarely used</span>", v: "1"}
           else {h: "<span class=\"badge used\">used</span>", v: "2"} end;

. as $d
| $d.totals as $t
| "<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
+ "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:\">"
# Only under --watch, or for a page a refresh keeps fresh: the page reloads
# itself from disk every N seconds. A meta refresh is navigation, which no CSP
# directive governs, so default-src 'none' does not block it; and it needs no
# script.
+ (if $refresh != "" then "<meta http-equiv=\"refresh\" content=\"\($refresh)\">" else "" end)
+ "<title>Usage dashboard - \($d.project | e)</title><style>
:root{color-scheme:light;--surface:#fcfcfb;--panel:#f3f2ef;--text:#0b0b0b;--text2:#52514e;--rule:#d6d4cf;--bar:#2a78d6;--never-bg:#fde7e7;--never-fg:#8a1414;--rare-bg:#fff3d6;--rare-fg:#6b4a00;--used-fg:#1f5a1f;--focus:#2a78d6}
@media (prefers-color-scheme: dark){:root{color-scheme:dark;--surface:#1a1a19;--panel:#242422;--text:#ffffff;--text2:#c3c2b7;--rule:#45443f;--bar:#3987e5;--never-bg:#4a1c1c;--never-fg:#ffd2d2;--rare-bg:#3d3214;--rare-fg:#ffe7a8;--used-fg:#b9e6b9;--focus:#86b6ef}}
*{box-sizing:border-box}body{margin:0;background:var(--surface);color:var(--text);font:15px/1.5 system-ui,-apple-system,'Segoe UI',Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px}h1{font-size:1.6rem;margin:0 0 4px}h2{font-size:1.25rem;margin:40px 0 8px;padding-top:8px;border-top:1px solid var(--rule)}h3{font-size:1.05rem;margin:24px 0 6px}
p,li{color:var(--text)}.muted{color:var(--text2)}nav a{color:var(--text);margin-right:14px}a:focus,button:focus{outline:3px solid var(--focus);outline-offset:2px}
.tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px;margin:16px 0}.tile{background:var(--panel);border-radius:8px;padding:12px}.tile .k{font-size:.85rem;color:var(--text2)}.tile .v{font-size:1.5rem;font-weight:650;font-variant-numeric:tabular-nums}
.tw{overflow-x:auto}table{border-collapse:collapse;width:100%;margin:8px 0 16px;font-variant-numeric:tabular-nums}caption{text-align:left;font-weight:600;padding:4px 0;color:var(--text)}
th,td{padding:5px 10px;border-bottom:1px solid var(--rule);text-align:left;vertical-align:top}td.num{text-align:right}th button{all:unset;cursor:pointer;font-weight:600;color:var(--text)}th[aria-sort] button::after{content:' \\2195';color:var(--text2)}
th[aria-sort=ascending] button::after{content:' \\2191'}th[aria-sort=descending] button::after{content:' \\2193'}
tr.never td{background:var(--never-bg)}tr.rare td{background:var(--rare-bg)}.badge{font-size:.8rem;font-weight:650;padding:1px 6px;border-radius:4px;white-space:nowrap}.badge.never{color:var(--never-fg);border:1px solid currentColor}.badge.rare{color:var(--rare-fg);border:1px solid currentColor}.badge.used{color:var(--used-fg)}
figure{margin:12px 0 20px}figcaption{font-weight:600;margin-bottom:4px}svg{width:100%;max-width:900px;height:auto;display:block}svg .lbl{font-size:13px;fill:var(--text)}svg .val{font-size:12px;fill:var(--text2)}svg .bar{fill:var(--bar)}
.src{list-style:none;padding:0}.src li{margin:2px 0}.st{display:inline-block;min-width:70px;font-weight:650}.st.found{color:var(--used-fg)}.st.missing{color:var(--text2)}.st.error{color:var(--never-fg)}.empty{color:var(--text2);font-style:italic}
.live{border-left:4px solid var(--bar);background:var(--panel);padding:6px 10px;border-radius:4px}
footer{margin-top:48px;padding-top:12px;border-top:1px solid var(--rule)}
@media (forced-colors: active){svg .bar{fill:CanvasText}tr.never td,tr.rare td{background:Canvas}}
</style></head><body><main>"
+ "<header><h1>Usage dashboard: \($d.project | e)</h1>"
+ (if $auto != "" then "<p class=\"live\"><strong>Kept fresh:</strong> last updated \($d.generated | e) - rebuilt in the background when the project changes (usage-dashboard.sh --refresh-in-background, at most once every \($refresh) s); this page reloads itself every \($refresh) s.</p>"
   elif $refresh != "" then "<p class=\"live\"><strong>Live:</strong> last updated \($d.generated | e) - refreshes every \($refresh) s while the --watch command runs. Stop the command and the page stays at its last update.</p>" else "" end)
+ "<p class=\"muted\">Generated \($d.generated | e). Range columns: <strong>\($d.range | e)</strong>; all-time columns cover the whole history. Transcript data covers whatever the runtime has retained.</p>"
+ "<h2 id=\"sources\">Data sources</h2><ul class=\"src\">"
+ ($d.sources | map("<li><span class=\"st \(.status | e)\">\(.status | e)</span> <strong>\(.name | e)</strong> - \(.detail | e)</li>") | join(""))
+ "</ul></header>"
+ "<nav aria-label=\"Sections\"><a href=\"#agents\">Agents</a><a href=\"#chains\">Chains</a><a href=\"#models\">Models</a><a href=\"#tokens\">Tokens &amp; cache</a><a href=\"#workunits\">Work Units</a><a href=\"#limits\">Limits</a></nav>"
+ "<div class=\"tiles\">"
+ ([["Employees on roster", $t.roster], ["Never used", $t.never], ["Rarely used", $t.rare], ["Dispatches", $t.dispatches],
    ["Commits (\($d.range))", $t.commits_range], ["Commits (all time)", $t.commits_all], ["API calls", $t.tokens.calls],
    ["Tokens (all types)", $t.tokens.total]] | map("<div class=\"tile\"><div class=\"k\">\(.[0] | e)</div><div class=\"v\">\(.[1] | n)</div></div>") | join(""))
+ "<div class=\"tile\"><div class=\"k\">Cache-read share of input</div><div class=\"v\">\($t.tokens.cache_read_share | pct)</div></div></div>"

# --- Agents
+ "<section><h2 id=\"agents\">Agents</h2><p>Every Employee on the roster. <strong>NEVER USED</strong> means no dispatch in the transcripts, no commit trailer and no registered Work Unit; <strong>rarely used</strong> means fewer than 3 dispatches and commits together. Dispatches are matched to an Employee by its agent name (the slug generate-agents.sh gives it).</p>"
+ barchart("Dispatches per Employee (transcripts)"; [$d.employees[] | select(.dispatches > 0) | {label: .name, value: .dispatches}])
+ barchart("Commits per Employee, all time (Employee trailer)"; [$d.employees | sort_by(-.commits_all)[] | select(.commits_all > 0) | {label: .name, value: .commits_all}])
+ table("Employees: dispatches, commits and Work Units"; [["Employee", "text"], ["Status", "text"], ["Roster", "text"], ["Dispatches", "num"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"], ["Work Units registered", "num"]];
    [$d.employees[] | {cls: (if .status == "used" then null else .status end), cells: [.name, (.status | badge), .roster, .dispatches, .commits_range, .commits_all, .work_units]}])
+ table("Dispatched agent types that are not Employees"; [["Agent type", "text"], ["Dispatches", "num"]];
    [$d.other_agents[] | {cells: [.type, .dispatches]}])
+ table("Dispatches by agent type and requested model"; [["Agent type", "text"], ["Requested model", "text"], ["Dispatches", "num"]];
    [$d.dispatch_models[] | {cells: [.type, .model, .n]}])
+ (if ($d.unrostered | length) > 0 then table("Employee trailer names not on the roster"; [["Name in trailer", "text"], ["Commits", "num"]]; [$d.unrostered[] | {cells: [.name, .commits]}]) else "" end)
+ "</section>"

# --- Chains
+ "<section><h2 id=\"chains\">Chains coverage</h2><p>Each Agent Chain's steps in order, with the usage of the Employee at each step. A step is <strong>exercised</strong> when its Employee has at least one dispatch or commit; usage is per Employee, so it shows that the Employee works, not that it worked inside this chain. <em>Engineer</em> is the chain placeholder: its numbers are the sum over \($d.engineer_set | map(e) | join(", ")).</p>"
+ ($d.chains | map(. as $ch | "<h3>\($ch.name | e) - \($ch.exercised) of \($ch.employee_steps) Employee steps exercised</h3>"
    + table("\($ch.name) steps"; [["#", "num"], ["Step", "text"], ["When", "text"], ["Exercised", "text"], ["Dispatches", "num"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"]];
        [$ch.steps[] | if .kind == "gate" then {cls: null, cells: [.n, {h: "<em>\(.name | e) gate</em>", v: .name}, (if .conditional then "conditional" else "always" end), "gate", "", "", ""]}
          else {cls: (if .exercised then null else "never" end),
                cells: [.n, (.name + (if .placeholder then " (placeholder)" else "" end) + (if .on_roster == false then " (not on roster)" else "" end)),
                        (if .conditional then "conditional" else "always" end),
                        (if .exercised then {h: "yes", v: "1"} else {h: "<span class=\"badge never\">NEVER</span>", v: "0"} end),
                        .dispatches, .commits_range, .commits_all]} end]))
   | join(""))
+ (if ($d.chains | length) == 0 then "<p class=\"empty\">No chain registry found.</p>" else "" end)
+ "</section>"

# --- Models
+ "<section><h2 id=\"models\">Models mix</h2>"
+ barchart("Commits per model, all time (Co-Authored-By trailer)"; [$d.commit_models[] | {label: .model, value: .commits_all}])
+ table("Commits per model"; [["Model (Co-Authored-By)", "text"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"]];
    [$d.commit_models[] | {cells: [.model, .commits_range, .commits_all]}])
+ barchart("API calls per model (transcripts)"; [$d.calls_by_model[] | {label: .model, value: .calls}])
+ table("API calls and tokens per model"; [["Model (API id)", "text"], ["Calls", "num"], ["Input", "num"], ["Output", "num"], ["Cache write", "num"], ["Cache read", "num"], ["Cache-read share", "num"], ["Cost (USD)", "num"]];
    [$d.calls_by_model[] | {cells: [.model, .calls, .input, .output, .cw, .cr, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}, (if .cost == null then null else {h: (.cost | usd), v: (.cost | tostring)} end)]}])
+ "</section>"

# --- Tokens
+ "<section><h2 id=\"tokens\">Tokens &amp; cache by day</h2><p>Days are UTC. Cache-read share = cache read / (input + cache write + cache read): the part of the input side served from the prompt cache.</p>"
+ barchart("Tokens per day, all types (latest 31 days)"; [$d.tokens_by_day[0:31][] | {label: .day, value: .total}])
+ table("Tokens per day"; [["Day (UTC)", "text"], ["Calls", "num"], ["Input", "num"], ["Output", "num"], ["Cache write", "num"], ["Cache read", "num"], ["Cache-read share", "num"]];
    [$d.tokens_by_day[] | {cells: [.day, .calls, .input, .output, .cw, .cr, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}]}])
+ table("Tokens per agent (main session or subagent type)"; [["Agent", "text"], ["Calls", "num"], ["Output", "num"], ["All tokens", "num"], ["Cache-read share", "num"]];
    [$d.tokens_by_agent[] | {cells: [.agent, .calls, .output, .total, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}]}])
+ "</section>"

# --- Work Units
+ "<section><h2 id=\"workunits\">Work Units</h2>"
+ barchart("Top Work Units by commits, all time"; [$d.work_units[0:15][] | {label: .id, value: .commits}])
+ table("Top 30 Work Units by commits"; [["Work Unit", "text"], ["Employee", "text"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"], ["Lines changed", "num"]];
    [$d.work_units[] | {cells: [.id, .employee, .commits_range, .commits, .lines]}])
+ "</section>"

# --- Limits
+ "<footer><h2 id=\"limits\">What this cannot tell you</h2><ul>"
+ "<li><strong>Cost.</strong> " + (if $d.have_prices then "Cost is computed only for the models listed in the --prices file you supplied, at the prices it states; other models show n/a." else "No cost is shown: no prices are configured (pass --prices FILE). Token counts are not money." end) + "</li>"
+ "<li><strong>Time saved.</strong> There is no baseline of how long the work would have taken otherwise, so nothing here measures productivity or time saved.</li>"
+ "<li><strong>Quality.</strong> A dispatch or a commit is activity, not value. A rarely used Employee may be exactly as rare as its work; a frequently used one may be over-dispatched.</li>"
+ "<li><strong>Chain fidelity.</strong> Usage is per Employee, not per chain run: the page cannot show that a chain ran end to end, only which of its Employees work at all.</li>"
+ "<li><strong>Coverage of transcripts.</strong> Only the runtime transcripts still on this machine are counted; the runtime prunes old sessions, and other machines and other runtimes are not seen. Commit counts come from git and are complete for the history present.</li>"
+ "<li><strong>Attribution of older commits.</strong> Employee and model are read from the git trailer block only. A commit whose trailers git cannot parse as a block (older commits that put a non-trailer line among them) counts as \"(no trailer)\"; a value that is not a plain name or Work Unit ID counts as \"(unrecognised)\", and a transcript value shaped like a credential as \"(redacted)\".</li>"
+ "<li><strong>Content.</strong> By design the page holds no prompt, reply, message body or file content - aggregates only (Standards/DATA_PROTECTION_STANDARD.md).</li>"
+ "</ul><p class=\"muted\">Roster and chain changes remain Director decisions; this page informs them.</p></footer></main>"
+ "<script type=\"application/json\" id=\"usage-data\">" + ($d | tojson | gsub("<"; "\\u003c")) + "</script>"
+ "<script>(function(){document.querySelectorAll('table.sortable').forEach(function(t){var hs=t.querySelectorAll('th');hs.forEach(function(th,i){th.setAttribute('aria-sort','none');th.querySelector('button').addEventListener('click',function(){var asc=th.getAttribute('aria-sort')!=='ascending';hs.forEach(function(h){h.setAttribute('aria-sort','none')});th.setAttribute('aria-sort',asc?'ascending':'descending');var num=th.dataset.type==='num';var b=t.tBodies[0];var rs=Array.prototype.slice.call(b.rows);rs.sort(function(x,y){var a=x.cells[i],c=y.cells[i];if(!a||!c)return 0;var va=a.dataset.v!==undefined?a.dataset.v:a.textContent,vb=c.dataset.v!==undefined?c.dataset.v:c.textContent;var r=num?((parseFloat(va)||0)-(parseFloat(vb)||0)):va.localeCompare(vb);return asc?r:-r});rs.forEach(function(r){b.appendChild(r)})})})})})();</script>"
+ "</body></html>"
JQ
)"

# The page is rendered into a PRIVATE directory in the output folder, made
# by mktemp -d (0700, a name nobody can predict), then renamed over the
# destination: a rename within one filesystem is atomic, so a browser
# reloading under --watch reads the old page or the new one, never half of
# one. Nothing in a shared output folder is ever opened for writing, so a
# planted file, symlink or FIFO cannot receive the page or block the build
# (PR #204 review F6; re-check R1-sec — noclobber refuses regular files
# only). Under --watch the loop made the directory once and passes it down;
# it is used only if it is a real directory of this user's, directly in the
# output folder. Otherwise this build makes its own and removes it on exit.
PAGE_DIR="${IAENG_USAGE_PAGEDIR:-}"
if [ -z "$PAGE_DIR" ] || [ "${PAGE_DIR%/*}" != "$OUT_DIR" ] || [ -L "$PAGE_DIR" ] \
    || [ ! -d "$PAGE_DIR" ] || [ ! -O "$PAGE_DIR" ]; then
  PAGE_DIR="$(mktemp -d "$OUT_DIR/.usage-dashboard.XXXXXX")" || { err "cannot create a private directory in $OUT_DIR. No page was written."; exit 1; }
  PAGE_DIR_OWN="$PAGE_DIR"
fi
PAGE_TMP="$PAGE_DIR/page.html.tmp"
if [ -n "$REFRESH" ]; then
  render() { jq -n -r "${BUILD_ARGS[@]}" --arg refresh "$REFRESH" --arg auto "$AUTO" "($JQ_BUILD) | ($JQ_RENDER)"; }
else
  render() { jq -r --arg refresh "" --arg auto "" "$JQ_RENDER" < "$DATA"; }
fi
# A render that fails leaves no orphan behind: the partial page is removed
# here, and the private directory with it on exit.
if ! render > "$PAGE_TMP" || [ ! -s "$PAGE_TMP" ]; then
  rm -f "$PAGE_TMP"
  err "rendering the page failed (jq). No page was written."
  exit 1
fi
if ! mv -f "$PAGE_TMP" "$OUT"; then
  rm -f "$PAGE_TMP"
  err "cannot write $OUT."
  exit 1
fi
# The fingerprint follows the page the same way: written in the private
# directory, renamed beside it. Without one, the page is rebuilt next time.
if [ -n "$FP_BUILD" ]; then
  if ! { printf '%s' "$FP_BUILD" > "$PAGE_DIR/fingerprint.tmp" && mv -f "$PAGE_DIR/fingerprint.tmp" "$FP_FILE"; }; then
    note "could not record the page's fingerprint; it will be rebuilt next time."
  fi
elif [ -e "$FP_FILE" ]; then
  rm -f "$FP_FILE"
fi

echo "Usage dashboard written: $OUT"
# Under --watch nobody reads this summary (the loop prints its own line), so
# the process that prints it is not spent; nor in a refresh's log.
[ -n "$REFRESH" ] || jq -r '"  Employees: \(.totals.roster) on roster, \(.totals.never) never used, \(.totals.rare) rarely used",
       "  Dispatches: \(.totals.dispatches); commits: \(.totals.commits_range) (\(.range)), \(.totals.commits_all) all time",
       "  API calls: \(.totals.tokens.calls); tokens: \(.totals.tokens.total); cache-read share: \(.totals.tokens.cache_read_share * 1000 | round / 10)%",
       (.sources[] | "  source \(.status): \(.name)")' < "$DATA"
[ "$MODE" != --refresh ] || say "page rebuilt in ${SECONDS} s."

if [ -n "$OPEN" ]; then
  open_page "$OUT" || exit 1
fi
# No final `exit 0`: the run ends with status 0 by reaching the end. shellcheck
# runs an EXIT trap's handler at the end of the script, so an unconditional
# exit there would report cleanup() unreachable (SC2317), and suppressing that
# is not allowed (Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression).
