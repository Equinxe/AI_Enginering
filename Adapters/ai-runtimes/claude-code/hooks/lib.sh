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

# iaeng_file_mtime <path>  — epoch seconds of the file's last modification, or
# nothing (and non-zero) if the file is missing or `date -r` is unsupported.
iaeng_file_mtime() {
  local ts
  ts="$(date -r "$1" +%s 2>/dev/null)" || return 1
  iaeng_is_int "$ts" || return 1
  printf '%s' "$ts"
}

# iaeng_head_commit_time <repo-base>  — epoch seconds of HEAD's commit time,
# or nothing (and non-zero) if there is no HEAD yet or git errors. This is
# the RAW committer time — a clock-skewed or deliberately future-dated
# commit is returned as-is; cap it with iaeng_cap_at_now before comparing it
# against "now" (a freshly touched SESSION_STATE.md must always clear).
iaeng_head_commit_time() {
  local ts
  ts="$(git -C "$1" log -1 --format=%ct 2>/dev/null)" || return 1
  iaeng_is_int "$ts" || return 1
  printf '%s' "$ts"
}

# iaeng_cap_at_now <epoch>  — <epoch>, or the current time if <epoch> is
# later than now. A future commit time — clock skew on the machine that
# made the commit, or a deliberately future-dated one — is never a "you are
# behind" signal: without this cap, SESSION_STATE.md touched at the actual
# present moment would compare as older than a HEAD dated tomorrow and could
# never clear the gate until the real clock caught up. Fails open: if "now"
# cannot be read, <epoch> passes through unchanged rather than the
# comparison being silently skipped.
iaeng_cap_at_now() {
  local ts="$1" now
  now="$(date +%s 2>/dev/null)"
  iaeng_is_int "$now" || { printf '%s' "$ts"; return 0; }
  if iaeng_is_int "$ts" && [ "$ts" -gt "$now" ]; then
    printf '%s' "$now"
  else
    printf '%s' "$ts"
  fi
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
