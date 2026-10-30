#!/usr/bin/env bash
# IA Engineering — hook tests: the user's real context directory is left alone
#
# WU-IAENG-401, issue #345. Sourced by tests/context-statusline.sh and
# tests/context-alert.sh; it defines functions and runs nothing.
#
# The context hooks write under ${TMPDIR:-/tmp}/iaeng-ctx-<uid>. A test case
# whose TMPDIR the rule refused fell back to /tmp, and wrote into the user's
# real directory, the live one of their own sessions (sess-bad-tmp.pct, 27 Oct
# 2026). Every case now points TMPDIR, and the fallback through
# IAENG_CTX_TEST_FALLBACK (hooks/context-dir.sh), at the suite's scratch
# tree. These functions check that it stays so.
#
# real_ctx_begin <scratch dir> — names the real directories (/tmp's, and
#     TMPDIR's as the suite was given it), drops a time stamp in <scratch
#     dir>, and keeps the list of what they hold. Call it before any hook runs.
# real_ctx_changed — prints each entry of those directories added or
#     modified since real_ctx_begin, one "<dir>/<name>" per line; nothing
#     when they were left alone.
#
# The user's own sessions keep writing there while a suite runs, so their
# names are left out. A Claude Code session id is a UUID, and the hooks' names
# for it are <uuid>.pct, <uuid>.alert and .<uuid>.*.tmp; .last-clean is the
# writer's hourly marker. No test session id has that shape, so any file a
# case writes there is seen.
#
# Ceilings. A deletion is not checked: only a file older than 24 h is ever
# deleted there, and the user's own sessions delete those too. A file that a
# case writes there and removes before the check is not seen; no case removes
# anything there, so a write stays until the check.

REAL_CTX_LIVE='^(\.?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\..*|\.last-clean)$'
REAL_CTX_DIRS=()
REAL_CTX_BEFORE=()
REAL_CTX_STAMP=""

# real_ctx_names <dir> — the names in <dir> that are not a live session's,
# sorted; nothing when <dir> is not a directory.
real_ctx_names() {
  [ -d "$1" ] || return 0
  find "$1" -mindepth 1 -maxdepth 1 2>/dev/null | sed 's|^.*/||' \
    | { grep -Ev "$REAL_CTX_LIVE" || :; } | LC_ALL=C sort
}

real_ctx_begin() {
  local id d
  id="$(id -u 2>/dev/null)"
  [ -n "${UID:-}" ] && id="$UID"
  REAL_CTX_DIRS=("/tmp/iaeng-ctx-$id")
  [ -n "${TMPDIR:-}" ] && REAL_CTX_DIRS+=("${TMPDIR%/}/iaeng-ctx-$id")
  REAL_CTX_STAMP="$1/real-ctx.stamp"
  : > "$REAL_CTX_STAMP"
  REAL_CTX_BEFORE=()
  for d in "${REAL_CTX_DIRS[@]}"; do
    REAL_CTX_BEFORE+=("$(real_ctx_names "$d")")
  done
}

real_ctx_changed() {
  local i d n
  for i in "${!REAL_CTX_DIRS[@]}"; do
    d="${REAL_CTX_DIRS[$i]}"
    [ -d "$d" ] || continue
    {
      # Added: a name absent from the first list.
      LC_ALL=C comm -13 <(printf '%s\n' "${REAL_CTX_BEFORE[$i]}") <(real_ctx_names "$d")
      # Modified: written after the stamp.
      find "$d" -mindepth 1 -maxdepth 1 -newer "$REAL_CTX_STAMP" 2>/dev/null \
        | sed 's|^.*/||' | { grep -Ev "$REAL_CTX_LIVE" || :; }
    } | LC_ALL=C sort -u | while IFS= read -r n; do
      [ -n "$n" ] && printf '%s/%s\n' "$d" "$n"
    done
  done
  return 0
}
