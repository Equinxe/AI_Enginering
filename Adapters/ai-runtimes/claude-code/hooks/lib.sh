#!/usr/bin/env bash
# IA Engineering — Claude Code hooks: shared helpers
#
# Sourced by every hook in this directory. Claude Code delivers hook input as
# one JSON object on stdin (session_id, cwd, hook_event_name, tool_name,
# tool_input, ...). `jq` is preferred for reading it; when jq is absent the
# helpers fall back to a sed extraction that handles JSON string escapes for
# the flat fields these hooks need. A hook that cannot read its input FAILS
# CLOSED (exit 2 with the reason) rather than allowing the action — a guard
# that silently allows everything when a dependency is missing is the defect
# Adapters/README.md's Check Convention exists to name.
#
# Exit code contract (Claude Code):
#   0  allow / nothing to add
#   2  block the tool call (PreToolUse) or keep the session going (Stop), with
#      stderr shown to the model as the reason
#   other  non-blocking error, stderr shown to the user only

set -uo pipefail
export LC_ALL=C

IAENG_INPUT="$(cat)"

iaeng_have_jq() { command -v jq >/dev/null 2>&1; }

# iaeng_field <jq-path>  — prints the string at that path, or nothing.
# The fallback takes the LAST path component as a flat key, which is what the
# hooks here need (tool_name, tool_input.command, tool_input.file_path, ...).
iaeng_field() {
  local path="$1" key
  if iaeng_have_jq; then
    printf '%s' "$IAENG_INPUT" | jq -r "$path // empty" 2>/dev/null
    return
  fi
  key="${path##*.}"
  printf '%s' "$IAENG_INPUT" \
    | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' \
    | sed 's/\\"/"/g; s/\\n/\
/g; s/\\t/\t/g; s/\\\\/\\/g'
}

# iaeng_bool <jq-path>  — prints true/false/(empty).
iaeng_bool() {
  local path="$1" key
  if iaeng_have_jq; then
    printf '%s' "$IAENG_INPUT" | jq -r "$path // empty" 2>/dev/null
    return
  fi
  key="${path##*.}"
  printf '%s' "$IAENG_INPUT" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p'
}

# iaeng_require_object  — refuses (exit 2) a payload that is not readable as a
# JSON object. For a hook whose "nothing to check" outcome is ALLOW: iaeng_field
# prints nothing for an unparseable payload exactly as it does for a valid one
# that lacks the field, so without this check "could not read" is
# indistinguishable from "nothing to inspect" and the edit goes through. With
# jq the payload must be exactly ONE JSON value and that value an object (a
# stream of two values would otherwise be judged by its last one only); without jq it must at least be
# non-blank (the sed fallback and the whole-payload match over-approximate).
iaeng_require_object() {
  local ok=1
  if iaeng_have_jq; then
    printf '%s' "$IAENG_INPUT" | jq -es 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1 && ok=0
  else
    case "$IAENG_INPUT" in *[![:space:]]*) ok=0 ;; esac
  fi
  [ "$ok" -eq 0 ] || iaeng_block "cannot read the hook payload as a JSON object — an input that could not be inspected is not allowed" \
    "Adapters/ai-runtimes/claude-code/hooks/README.md, Design Rules — the hook fails closed rather than allowing what it could not read."
}

iaeng_block() {
  # $1 = one-line reason, $2 = standard reference
  {
    printf 'iaeng: BLOCKED — %s\n' "$1"
    printf '  %s\n' "$2"
    printf '  A control in the way is a rule in the way: escalate it with this message quoted.\n'
    printf '  If the Director has decided this action, a human runs it by hand — the hook never learns exceptions.\n'
  } >&2
  exit 2
}

# Framework root relative to the project: "." when this IS the framework
# repository, "ia-engineering" when imported as a submodule at the path
# Workflows/ONBOARDING.md assumes, or $IAENG_FRAMEWORK when set.
iaeng_framework_root() {
  local base="${CLAUDE_PROJECT_DIR:-.}" c
  for c in "${IAENG_FRAMEWORK:-}" "$base" "$base/ia-engineering"; do
    [ -n "$c" ] && [ -f "$c/Core/AGENT_CONDUCT.md" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# --- SESSION_STATE freshness helpers ----------------------------------------
# Shared by session-start.sh (warns) and stop-gate.sh (blocks). Both compare
# .ia-engineering/SESSION_STATE.md's file mtime against HEAD's commit time —
# mtime, not the free-text "_Last updated:" header, is the primary signal: the
# header is precisely what goes stale (edited many times, never refreshed).
# Every helper here FAILS SAFE: on any error it prints nothing and returns 1,
# so a caller that only acts when both values are present never mis-blocks or
# mis-warns on a git error or an unsupported `date` flag. `date -r` (mtime of
# a file) is available in both GNU date (Linux CI) and the GNU coreutils Git
# for Windows ships (this box) — verified, not assumed.

# iaeng_is_int <value>  — true if value is a non-negative integer.
iaeng_is_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# EACH HELPER HAS TWO FORMS (WU-IAENG-410). The by-name form, iaeng_*_to
# <var> ..., sets the variable named <var> (empty on any error, and returns
# 1), as iaeng_cache_dir does. The printing form, used as X="$(iaeng_...)",
# prints the same value; it wraps the by-name form, so the rule lives once.
# The by-name form exists for the cost: $(helper) forks a subshell around the
# helper's own $(command), one more process per value on every call, and on
# Windows a process is the hooks' latency under load
# (Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md). stop-gate.sh uses the
# by-name forms; session-start.sh, run once per session, the printing ones.
# Locals are named _iaeng_* so that no caller's <var> is shadowed.

# iaeng_file_mtime_to <var> <path>  — epoch seconds of the file's last
# modification, or empty (and non-zero) if the file is missing, `date -r` is
# unsupported, or the value is not a non-negative integer (a pre-1970 mtime
# reads as negative: no value, so the caller says it cannot verify).
iaeng_file_mtime_to() {
  local _iaeng_ts
  printf -v "$1" '%s' ''
  _iaeng_ts="$(date -r "$2" +%s 2>/dev/null)" || return 1
  iaeng_is_int "$_iaeng_ts" || return 1
  printf -v "$1" '%s' "$_iaeng_ts"
}

# iaeng_file_mtime <path>  — the printing form of iaeng_file_mtime_to.
iaeng_file_mtime() {
  local _iaeng_out
  iaeng_file_mtime_to _iaeng_out "$1" || return 1
  printf '%s' "$_iaeng_out"
}

# iaeng_head_commit_time <repo-base>  — epoch seconds of HEAD's commit time,
# or nothing (and non-zero) if there is no HEAD yet or git errors. This is
# the RAW committer time. A clock-skewed or deliberately future-dated commit
# is returned as-is — check it against iaeng_now before using it as the
# comparison partner for SESSION_STATE's mtime; see iaeng_now for why a live
# "cap" (min of this and now, re-read on every invocation) was tried and
# reverted. iaeng_head_commit_time_to <var> <repo-base> is the by-name form.
iaeng_head_commit_time_to() {
  local _iaeng_ts
  printf -v "$1" '%s' ''
  _iaeng_ts="$(git -C "$2" log -1 --format=%ct 2>/dev/null)" || return 1
  iaeng_is_int "$_iaeng_ts" || return 1
  printf -v "$1" '%s' "$_iaeng_ts"
}

iaeng_head_commit_time() {
  local _iaeng_out
  iaeng_head_commit_time_to _iaeng_out "$1" || return 1
  printf '%s' "$_iaeng_out"
}

# iaeng_now  — epoch seconds of the current time, or nothing (and non-zero)
# if the clock cannot be read. iaeng_now_to <var> is the by-name form. It
# reads bash's own clock (printf '%(%s)T', bash 4.2 and later: no process)
# and falls back to `date` when that gives no integer (an older bash).
#
# HEAD_TS > iaeng_now is treated as a FAIL-SAFE condition, not something to
# clamp and keep comparing against. A first pass capped HEAD_TS at
# min(HEAD_TS, now) and re-ran that comparison on every invocation — which
# looked fixed (a file touched in the same second as the check passed) but
# was not: "now" is re-read live every run while SESSION_STATE's mtime is
# frozen at whatever moment it was actually touched, so real time moving
# forward alone re-opens the gate a second later with no edit and nothing
# for a human to act on — reported and reproduced in review (stop-gate
# rc=0 immediately after `touch`, rc=2 one second later, no change made).
# A future HEAD_TS means the comparison partner itself cannot be trusted
# (clock skew, or a deliberately forward-dated commit), so the honest
# answer is "cannot verify this — here is why", exactly like a missing
# mtime or a git error, not a clamped comparison dressed up as a real one.
iaeng_now_to() {
  local _iaeng_ts=""
  printf -v "$1" '%s' ''
  printf -v _iaeng_ts '%(%s)T' -1 2>/dev/null
  if ! iaeng_is_int "$_iaeng_ts"; then
    _iaeng_ts="$(date +%s 2>/dev/null)" || return 1
    iaeng_is_int "$_iaeng_ts" || return 1
  fi
  printf -v "$1" '%s' "$_iaeng_ts"
}

iaeng_now() {
  local _iaeng_out
  iaeng_now_to _iaeng_out || return 1
  printf '%s' "$_iaeng_out"
}

# --- SESSION_STATE header date parsing (portable — no `date -d`) -----------
# `date -d "24 September 2026"` (GNU date) is the obvious way to parse the
# header's free-text date, and is exactly what a first pass used — but it is
# a GNU extension BSD/macOS date does not have, where it fails every time
# and the header-staleness check silently never fires. `date -r <file>`
# (used elsewhere in this file for mtime) is a different, portable feature;
# `date -d` is not. These build "YYYY-MM-DD" out of a "DD Month YYYY" triple
# with a plain month-name table instead.

# iaeng_month_num <name>  — "01".."12" for an English month name, matched
# case-insensitively by prefix (so "Sep" and "September" both work), or
# nothing (and non-zero) if <name> is not one of the twelve.
iaeng_month_num() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    jan*) printf '01' ;;
    feb*) printf '02' ;;
    mar*) printf '03' ;;
    apr*) printf '04' ;;
    may*) printf '05' ;;
    jun*) printf '06' ;;
    jul*) printf '07' ;;
    aug*) printf '08' ;;
    sep*) printf '09' ;;
    oct*) printf '10' ;;
    nov*) printf '11' ;;
    dec*) printf '12' ;;
    *) return 1 ;;
  esac
}

# iaeng_zeropad2 <n>  — <n> left-padded to two digits with a leading zero.
# Not printf '%02d': bash's printf treats a leading-zero numeric argument as
# octal ("09" is not a valid octal digit and errors), and a day-of-month is
# exactly the kind of value that arrives un-padded ("9", not "09").
iaeng_zeropad2() {
  case "$1" in
    ?) printf '0%s' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

# iaeng_ymd_from_header_date <"D(D) Month YYYY">  — "YYYY-MM-DD", or nothing
# (and non-zero) if the day, month name, or year cannot all be recognised.
# `read` (not an unquoted `set -- $1`) does the whitespace split, so a
# fourth stray token lands in $extra instead of being silently dropped.
iaeng_ymd_from_header_date() {
  local day mon year extra monnum
  read -r day mon year extra <<< "$1"
  [ -n "$year" ] && [ -z "$extra" ] || return 1
  iaeng_is_int "$day" || return 1
  iaeng_is_int "$year" || return 1
  [ "${#year}" -eq 4 ] || return 1
  monnum="$(iaeng_month_num "$mon")" || return 1
  printf '%s-%s-%s' "$year" "$monnum" "$(iaeng_zeropad2 "$day")"
}

# --- The drift cache directory (WU-IAENG-359) -------------------------------
# session-start.sh keeps check-framework-drift.sh --quick's result, and what
# it has already said once, in a user-level directory. The rule is the
# script's own (cache_dir_canon and untrusted in check-framework-drift.sh,
# which sources nothing): never inside the project, resolved through symbolic
# links and without . or .. with either separator, and used only when the
# user alone could have written it (SEC-IAENG-359-01, -03).

# iaeng_cache_dir <dir> <project> <var> — sets the variable named <var> to
# <dir> made canonical (links resolved in the part that exists), and returns
# non-zero, leaving <var> alone, when <dir> is not absolute, has a . or ..
# component, cannot be resolved, or is the project or inside it. One fork.
#
# Windows reads a backslash as a separator, so every backslash is read as one
# before the test and the walk (issue #342). Split on / alone, the part still
# to be made kept "..\proj\cache", or "proj\cache" with no .. at all, as one
# name below a directory outside the project: never tested, it was made
# inside the project. The absolute test reads <dir> as given, so \x stays
# relative. The backslash is held in a variable, so no copy of this line can
# lose it in transport (context-dir.sh, issue #340).
iaeng_cache_dir() {
  local bs="\\" p proj="$2" tail="" n canon
  case "$1" in /*|[A-Za-z]:[/\\]*) ;; *) return 1 ;; esac
  p="${1//"$bs"//}"
  p="${p%/}"
  case "/$p/" in */../*|*/./*) return 1 ;; esac
  while [ ! -d "$p" ]; do
    n="${p%/*}"
    { [ -z "$n" ] || [ "$n" = "$p" ]; } && return 1
    case "$n" in */*) ;; *) n="$n/" ;; esac
    # The root of a drive that does not exist (Q:/) gives itself back: the
    # walk would never end, and session-start.sh runs it with no time limit.
    [ "$n" = "$p" ] && return 1
    tail="${p##*/}${tail:+/$tail}"
    p="$n"
  done
  canon="$(cd -P "$p" 2>/dev/null && pwd -P)" || return 1
  # The part that exists resolved to the root: the join would give //<tail>,
  # which Windows reads as a network (UNC) path that the test below never
  # sees (////localhost/C$/<project>, SEC-IAENG-399-01). Refused, as
  # /<missing>/x already is. Not ${canon%/}: for a // canon it gives / and
  # /<tail>, the same // again.
  case "$canon" in *[!/]*) ;; *) return 1 ;; esac
  p="$canon"
  while :; do
    [ "$p" -ef "$proj" ] && return 1
    n="${p%/*}"
    { [ -z "$n" ] || [ "$n" = "$p" ]; } && break
    p="$n"
  done
  printf -v "$3" '%s' "$canon${tail:+/$tail}"
}

# iaeng_untrusted <path>... — true when any path is not owned by the user, is
# a symbolic link, or is group- or world-writable. Each path is absolute.
iaeng_untrusted() {
  local p bad
  for p in "$@"; do
    { [ -O "$p" ] && [ ! -L "$p" ]; } || return 0
  done
  bad="$(find "$@" -prune \( -perm -020 -o -perm -002 \) -print 2>/dev/null)" || return 0
  [ -n "$bad" ]
}
