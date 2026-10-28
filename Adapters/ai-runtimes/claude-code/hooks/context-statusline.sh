#!/usr/bin/env bash
# IA Engineering — Claude Code statusLine: record the context occupancy
#
# WU-IAENG-379, the compaction plan of 23 Oct 2026 (issue #304, WU-B). Claude
# Code gives `context_window.used_percentage` to one place only: the
# statusLine command's stdin (https://code.claude.com/docs/en/statusline.md).
# This command writes that percentage where the context alert hook (WU-C)
# reads it, and otherwise behaves as the status line the user already had.
# The percentage is read from the stdin JSON only, never from a transcript.
#
# WHAT IT DOES, in this order:
#   1. reads the stdin JSON (at most 1 MiB; a terminal is not read);
#   2. writes the floor of context_window.used_percentage, one integer and a
#      newline, to
#          ${TMPDIR:-/tmp}/iaeng-ctx-<uid>/<session_id>.pct
#      when the session id has the shape [A-Za-z0-9][A-Za-z0-9_-]{0,127}
#      (no dot, no separator: no path can be built from it) and the
#      percentage is a number from 0 to 100. TMPDIR is used only when it is
#      an absolute path with no . or .. component, with either separator,
#      else /tmp. The rule is context-dir.sh's, which the context alert
#      sources too, so the two cannot name different directories (#340);
#   3. prints the status line: the output of the user's own statusLine
#      command when there is one and it succeeds, else one line of its own.
#
# THE FILE IS WRITTEN ONLY SAFELY (the guards of the peer kit studied on
# 22 Oct 2026, plus the session id shape):
#   - the directory is created mode 0700; it is used only when it is a
#     directory, not a symbolic link, owned by the user, and writable by no
#     one else (on Windows, where Git Bash cannot set the mode, the profile's
#     TEMP is the user's own and the emulated mode shows no write bit for
#     others);
#   - a find that fails is not read as "safe": the write is skipped;
#   - at most once an hour, *.pct and *.alert regular files older than 24 h
#     are deleted from that directory, and so are the orphan .*.tmp files
#     a render or an alert killed before its rename left (clean_dir, below);
#   - the file is written mode 0600 whatever the umask, to a new name in that
#     directory, with noclobber, then renamed over <session_id>.pct: a reader sees the old value or the
#     new one, never half of one. A rename replaces a symbolic link and never
#     follows it, and a final name that exists but is a link or anything but
#     a regular file is left alone and not written.
#   Any failure skips the write. The status line is printed anyway.
#
# FAIL-OPEN, ALWAYS (AC3, AC7). Exit 0 on every path but the switched-off
# one (below); never an empty line
# (Claude Code shows nothing for an empty output or a non-zero exit); no
# message on stderr. Empty stdin, bad JSON, a hostile session id, a planted
# link, a read-only TMP: the line is printed and nothing else happens.
#
# CHAINING THE USER'S STATUS LINE. A statusLine in the project's
# .claude/settings.json takes precedence over the user's
# ~/.claude/settings.json (https://code.claude.com/docs/en/settings.md,
# Settings precedence), so installing this one would hide the user's own.
# It is run instead, from here, with the same stdin and environment:
#   - `--chain <command>`: install-hooks.sh wrapped the project's own
#     statusLine command; it is run with bash -c;
#   - otherwise, the statusLine of ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json
#     (type "command"): bash -c for a command, its argv for the exec form
#     ("args"), powershell -Command for "shell": "powershell". It is read with
#     jq, or by pattern without jq (a flat statusLine object; a \u escape in
#     it is not decoded, and that command is then not run). A command that
#     names this script is not chained (no loop): a --chain one that does
#     (an earlier framework path) falls back to the user's statusLine. A
#     chained run sets IAENG_CTX_CHAINED=1 so a nested copy never chains.
# The user's output is printed as it is, colours included: it is what Claude
# Code showed before. It is used when the command exits 0 within
# IAENG_CTX_CHAIN_TIMEOUT seconds (default 10, where `timeout` exists) and
# prints something; otherwise the line of its own is printed. The user's
# padding and refreshInterval are not carried over from the user file.
#
# THE LINE OF ITS OWN: "[<model>] ctx <n>% | 5h <n>%", each part only when
# known, or "ctx --". Every field from the JSON goes through the framework's
# record sanitiser rule (install-hooks.sh, flat()): no control character,
# C0 or C1, reaches the terminal. Colour only when NO_COLOR is unset or
# empty: the ctx part is yellow at or above IAENG_CTX_ALERT_PCT when that is
# set.
#
# SWITCHED OFF by the file .ia-engineering/context-hooks.off in the project,
# or IAENG_CONTEXT_HOOKS set to 0, off, false or no (any case). Then nothing
# of this script's own stays (AC5): no file is written and no line of its own
# printed; the user's statusLine command replaces this process (exec), so its
# output and exit status are exactly what Claude Code showed before, and
# with no such command nothing is printed, as before. This is the one path
# whose exit status is not always 0: it is the user's.
#
# Usage (from .claude/settings.json, written by install-hooks.sh):
#   "statusLine": {"type": "command", "command":
#     "bash \"$CLAUDE_PROJECT_DIR/<framework>/Adapters/ai-runtimes/claude-code/hooks/context-statusline.sh\" [--chain '<command>']"}

set -u
export LC_ALL=C

OUT_DONE=0
TMPF=""
LINE="ctx --"
# The EXIT trap is the one exit: never an empty line, always 0.
trap '[ -n "$TMPF" ] && rm -f -- "$TMPF" 2>/dev/null
      [ "$OUT_DONE" -eq 1 ] || printf "%s\n" "$LINE"
      exit 0' EXIT

# The block below is the installers' record sanitiser, copied byte for byte
# (its own text names the four installer copies). Adapters/scripts/tests/run.sh
# compares this fifth copy with install.sh's too (WU-IAENG-379).
# >>> record sanitiser — byte-identical in install.sh, install-hooks.sh,
# install-skills.sh and check-framework-drift.sh: none of them sources
# another, and Adapters/scripts/tests/run.sh compares the four (WU-IAENG-366).
# flat <text> — every control character (TAB, LF, CR, ESC, ...) becomes a
# space: a record is one line and carries no terminal escape.
# The C1 controls (U+0080-U+009F, CSI among them) are UTF-8 pairs \xc2\x80 to
# \xc2\x9f: a pair becomes one space. A lone byte in that range is part of
# another character and is left alone (SEC-IAENG-358-01). For these the
# result is the same under the C locale and a UTF-8 one; a UTF-8 locale also
# flattens a few other code points, U+2028 and U+2029 among them.
C1_LEAD=$'\xc2'
flat() {
  FLAT="${1//[[:cntrl:]]/ }"
  FLAT="${FLAT//"$C1_LEAD"[$'\x80'-$'\x9f']/ }"
}
# <<< record sanitiser

CHAIN_ARG=""
HAVE_CHAIN_ARG=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --chain) [ "$#" -ge 2 ] && { CHAIN_ARG="$2"; HAVE_CHAIN_ARG=1; shift; } ;;
  esac
  shift
done

OFF=0
case "${IAENG_CONTEXT_HOOKS:-}" in
  [0]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) OFF=1 ;;
esac
[ -e "${CLAUDE_PROJECT_DIR:-$PWD}/.ia-engineering/context-hooks.off" ] && OFF=1

# --- 1. stdin, bounded; a builtin read, no process started -----------------
INPUT=""
[ -t 0 ] || IFS= read -r -d '' -n 1048576 INPUT

# --- 2. the user's own status line: which command, run how ---------------------
# json_unescape <JSON string body> — sets UNESC; fails on \u escapes, which
# the pattern reader below does not decode (jq does).
json_unescape() {
  local s="$1" out="" head
  while [ -n "$s" ]; do
    head="${s%%\\*}"; out+="$head"; s="${s:${#head}}"
    [ -n "$s" ] || break
    case "${s:1:1}" in
      '"') out+='"' ;; "\\") out+="\\" ;; '/') out+='/' ;;
      n) out+=$'\n' ;; t) out+=$'\t' ;; r) out+=$'\r' ;; b|f) out+=' ' ;;
      *) return 1 ;;
    esac
    s="${s:2}"
  done
  UNESC="$out"
}
# user_statusline <settings.json> — sets MODE (bash|powershell) and CMD from
# the file's statusLine of type "command"; the exec form ("args") becomes one
# bash command, each word quoted. With jq the file is parsed; without it the
# statusLine object is read by pattern (a flat object, as Claude Code's own
# examples are), so the user's line is never hidden for want of jq.
user_statusline() {
  local f="$1" s o re a q
  [ -f "$f" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    IFS=$'\t' read -r -d '' MODE CMD < <(jq -r '
      try (.statusLine
           | select(type == "object" and .type == "command" and (.command | type) == "string")
           | if (.args | type) == "array" then "bash\t" + ([.command] + (.args | map(tostring)) | @sh)
             elif (.shell // "bash") == "powershell" then "powershell\t" + .command
             else "bash\t" + .command end)
      catch empty' -- "$f" 2>/dev/null)
    CMD="${CMD%$'\n'}"
    CMD="${CMD%$'\r'}"
    return 0
  fi
  IFS= read -r -d '' -n 262144 s < "$f"
  re='"statusLine"[[:space:]]*:[[:space:]]*\{([^{}]*)\}'
  [[ $s =~ $re ]] || return 0
  o="${BASH_REMATCH[1]}"
  re='"type"[[:space:]]*:[[:space:]]*"command"'
  [[ $o =~ $re ]] || return 0
  re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $o =~ $re ]] && json_unescape "${BASH_REMATCH[1]}" || return 0
  re='"shell"[[:space:]]*:[[:space:]]*"powershell"'
  if [[ $o =~ $re ]]; then MODE=powershell; CMD="$UNESC"; return 0; fi
  re='"args"[[:space:]]*:[[:space:]]*\[([^]]*)\]'
  if [[ $o =~ $re ]]; then
    a="${BASH_REMATCH[1]}"
    printf -v q '%q' "$UNESC"
    re='^[[:space:],]*"(([^"\\]|\\.)*)"'
    while [[ $a =~ $re ]]; do
      a="${a:${#BASH_REMATCH[0]}}"
      json_unescape "${BASH_REMATCH[1]}" || return 0
      printf -v UNESC '%q' "$UNESC"
      q+=" $UNESC"
    done
    MODE=bash; CMD="$q"; return 0
  fi
  MODE=bash; CMD="$UNESC"
}
# The command: the project's own, wrapped by install-hooks.sh (--chain), or
# the user's. A command that names this script is never run from here (no
# loop); a --chain one that does (an earlier framework path) falls back to
# the user's own, so neither line is lost.
MODE=""
CMD=""
if [ -z "${IAENG_CTX_CHAINED:-}" ]; then
  case "$CHAIN_ARG" in *context-statusline.sh*) HAVE_CHAIN_ARG=0 ;; esac
  if [ "$HAVE_CHAIN_ARG" -eq 1 ]; then
    MODE=bash
    CMD="$CHAIN_ARG"
  else
    user_statusline "${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/settings.json"
  fi
fi
case "$CMD" in *context-statusline.sh*) CMD="" ;; esac
case "$CMD" in *[![:space:]]*) ;; *) CMD="" ;; esac

# SWITCHED OFF: nothing of this script's own stays. No file, no line of its
# own, no timeout: the user's command replaces this process with the same
# stdin, so its output and exit status are exactly what Claude Code showed
# before; with no such command, nothing is printed, as before (AC5).
if [ "$OFF" -eq 1 ]; then
  trap - EXIT
  [ -n "$CMD" ] || exit 0
  export IAENG_CTX_CHAINED=1
  if [ "$MODE" = powershell ]; then
    exec powershell -NoProfile -NonInteractive -Command "$CMD" <<< "$INPUT"
  fi
  exec bash -c "$CMD" <<< "$INPUT"
fi

# --- 3. the fields ------------------------------------------------------------
SID="" PCT="" Q5="" MODEL=""
if command -v jq >/dev/null 2>&1; then
  # The first JSON value only; anything that is not an object gives nothing.
  # Every control character in a string becomes a space here, so the four
  # fields come back as one line, joined by the unit separator (byte 31). It
  # is not IFS whitespace, so an empty field stays a field (a TAB would let
  # an absent quota shift the model name into its place).
  FIELDS="$(printf '%s' "$INPUT" | jq -rn '
    (try input catch null) as $in
    | ([31] | implode) as $us
    | if ($in | type) != "object" then empty else
      def num(f): (try ($in | f) catch null) | if type == "number" then floor | tostring else "" end;
      def str(f): (try ($in | f) catch null) | if type == "string" then gsub("[[:cntrl:]]"; " ") else "" end;
      # The session id is passed whole, so its shape check sees all of it;
      # only the display name is cut.
      [str(.session_id), num(.context_window.used_percentage),
       num(.rate_limits.five_hour.used_percentage), (str(.model.display_name) | .[0:128])] | join($us)
      end' 2>/dev/null)"
  FIELDS="${FIELDS%%$'\n'*}"
  FIELDS="${FIELDS%$'\r'}"
  IFS=$'\x1f' read -r SID PCT Q5 MODEL <<< "$FIELDS"
else
  # No jq: the keys read by pattern. A key matched in valid JSON is a key,
  # never text inside a string (a quote there is escaped).
  re='"session_id"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
  [[ $INPUT =~ $re ]] && SID="${BASH_REMATCH[1]}"
  re='"context_window"[[:space:]]*:[[:space:]]*\{(([^{}]|\{[^{}]*\})*)\}'
  if [[ $INPUT =~ $re ]]; then
    cw="${BASH_REMATCH[1]}"
    # Nested objects (current_usage) out first: only the top-level key counts.
    re='\{[^{}]*\}'
    while [[ $cw =~ $re ]]; do cw="${cw/"${BASH_REMATCH[0]}"/}"; done
    re='"used_percentage"[[:space:]]*:[[:space:]]*([0-9]+)'
    [[ $cw =~ $re ]] && PCT="${BASH_REMATCH[1]}"
  fi
  re='"five_hour"[[:space:]]*:[[:space:]]*\{([^{}]*)\}'
  if [[ $INPUT =~ $re ]]; then
    q="${BASH_REMATCH[1]}"
    re='"used_percentage"[[:space:]]*:[[:space:]]*([0-9]+)'
    [[ $q =~ $re ]] && Q5="${BASH_REMATCH[1]}"
  fi
fi

# Shapes: anything else is dropped, not repaired.
[[ $SID =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$ ]] || SID=""
[[ $PCT =~ ^[0-9]{1,3}$ ]] && [ "$PCT" -le 100 ] || PCT=""
[[ $Q5 =~ ^[0-9]{1,3}$ ]] || Q5=""

# --- 4. the line of its own -------------------------------------------------
flat "$MODEL"; MODEL="${FLAT:0:40}"
ESC_ON=""
ESC_OFF=""
if [ -z "${NO_COLOR:-}" ] && [ -n "$PCT" ] \
   && [[ ${IAENG_CTX_ALERT_PCT:-} =~ ^[0-9]{1,3}$ ]] && [ "$PCT" -ge "$IAENG_CTX_ALERT_PCT" ]; then
  ESC_ON=$'\033[33m'
  ESC_OFF=$'\033[0m'
fi
LINE="ctx ${ESC_ON}${PCT:---}${PCT:+%}${ESC_OFF}"
[ -n "$MODEL" ] && LINE="[$MODEL] $LINE"
[ -n "$Q5" ] && LINE="$LINE | 5h $Q5%"

# --- 5. the file ----------------------------------------------------------------
# clean_dir <dir> <uid> — the writer cleans up after itself (Main Agent
# decision, 26 Oct 2026): at most once an hour, it deletes the *.pct and
# *.alert files in its own state directory that are older than 24 hours.
# The .*.tmp files go too (issue #345): this script's .<session>.<pid>.<n>.tmp
# and the context alert's .<session>.alert.<pid>.<n>.tmp, which a process
# killed between its write and its rename leaves behind (the statusLine runs
# under a timeout). At 24 h none is a write still in progress. Only
# regular files the user owns, at the top of the directory: find -type f
# never matches or follows a link. The hour is kept as an epoch in
# .last-clean, read and written with builtins, so a run that does not clean
# starts no process. A marker that is a link or not a regular file stops the
# cleanup; one from the future counts as stale.
clean_dir() {
  local dir="$1" uid="$2" m="$1/.last-clean" now last=""
  printf -v now '%(%s)T' -1 2>/dev/null || return 0
  [[ $now =~ ^[0-9]+$ ]] || return 0
  if [ -L "$m" ] || { [ -e "$m" ] && [ ! -f "$m" ]; }; then return 0; fi
  [ -f "$m" ] && IFS= read -r last < "$m"
  if [[ $last =~ ^[0-9]+$ ]] && [ "$last" -le "$now" ] && [ $((now - last)) -lt 3600 ]; then
    return 0
  fi
  { printf '%s\n' "$now" > "$m"; } 2>/dev/null || return 0
  find "$dir" -maxdepth 1 -type f \( -name '*.pct' -o -name '*.alert' -o -name '.*.tmp' \) \
    -uid "$uid" -mmin +1440 -delete 2>/dev/null
  return 0
}
# The directory is named by context-dir.sh, which the context alert sources
# too, so the writer and the reader cannot name two (issue #340). A missing
# file means no directory: the write is skipped and the line still printed.
case "${BASH_SOURCE[0]}" in */*) HOOKS_DIR="${BASH_SOURCE[0]%/*}" ;; *) HOOKS_DIR=. ;; esac
# shellcheck source=context-dir.sh
. "$HOOKS_DIR/context-dir.sh" 2>/dev/null
write_pct() {
  local uid="${UID:-}" dir="" f w
  iaeng_ctx_dir dir 2>/dev/null || return 0
  # -m sets the mode whatever the umask; no umask is changed, so the user's
  # command below runs with the umask Claude Code gave this script.
  if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    mkdir -m 700 -- "$dir" 2>/dev/null
  fi
  # Ours, a directory, not a link, and no one else can write in it.
  [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ] || return 0
  # A find that fails (missing, or Windows' FIND.EXE first on PATH) is not
  # read as "no one else can write": the write is skipped (SEC-IAENG-379-02).
  w="$(find "$dir" -prune \( -perm -020 -o -perm -002 \) -print 2>/dev/null)" || return 0
  [ -z "$w" ] || return 0
  clean_dir "$dir" "$uid"
  f="$dir/$SID.pct"
  if [ -L "$f" ] || { [ -e "$f" ] && [ ! -f "$f" ]; }; then
    return 0
  fi
  TMPF="$dir/.$SID.$$.$RANDOM.tmp"
  # Mode 0600 whatever the caller's umask (a reader refuses a .pct others can
  # read or write: cr-320 M1), with the umask scoped to this subshell so it
  # never reaches the user's command (cr-321 m3). Noclobber: a name that
  # exists is never written through.
  ( umask 077; set -C; printf '%s\n' "$PCT" > "$TMPF" ) 2>/dev/null || { TMPF=""; return 0; }
  mv -f -- "$TMPF" "$f" 2>/dev/null && TMPF=""
  return 0
}
[ -n "$SID" ] && [ -n "$PCT" ] && write_pct

# --- 6. the user's own status line, run ----------------------------------------
if [ -n "$CMD" ]; then
  TO=()
  if command -v timeout >/dev/null 2>&1; then
    secs="${IAENG_CTX_CHAIN_TIMEOUT:-10}"
    [[ $secs =~ ^[0-9]{1,3}$ ]] && [ "$secs" -gt 0 ] || secs=10
    TO=(timeout "$secs")
  fi
  if [ "$MODE" = powershell ]; then
    SH=(powershell -NoProfile -NonInteractive -Command "$CMD")
  else
    SH=(bash -c "$CMD")
  fi
  # A here-string, not a pipe from printf: a command that never reads its
  # stdin must not turn a writer's SIGPIPE into a failure of its own.
  USER_OUT="$(set -o pipefail
              IAENG_CTX_CHAINED=1 ${TO[@]+"${TO[@]}"} "${SH[@]}" <<< "$INPUT" 2>/dev/null \
                | head -c 65536)"
  RC=$?
  case "$USER_OUT" in
    *[![:space:]]*)
      if [ "$RC" -eq 0 ]; then
        printf '%s\n' "$USER_OUT"
        OUT_DONE=1
      fi ;;
  esac
fi
exit 0
