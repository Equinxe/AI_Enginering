#!/usr/bin/env bash
# IA Engineering — Claude Code hook: context alert → Handoff checklist
#
# WU-IAENG-380, the compaction plan of 23 Oct 2026 (issue #304, WU-C). When
# the Main Agent's context reaches IAENG_CTX_ALERT_PCT, this hook tells it,
# once, to head for the Handoff: finish the Work Unit in progress, dispatch no
# new Employee for any other work, then run the Handoff to a New Conversation
# checklist of Templates/SESSION_STATE.md, so a compaction that follows loses
# nothing. A second, "last call" message comes once at IAENG_CTX_LAST_CALL_PCT:
# write the Handoff now, then resume. It never blocks: it adds context, and
# every path exits 0.
#
# EVENTS (https://code.claude.com/docs/en/hooks.md):
#   UserPromptSubmit  the alert, as additionalContext beside the prompt;
#   PostToolBatch     the alert, after a batch of tool calls resolves and
#                     before the next model call, so a long stretch of work
#                     with no prompt is covered too;
#   SessionStart      run by session-start.sh with --session-start, not from
#                     a settings entry of its own: a warning in plain text,
#                     only when the alert threshold may come after
#                     auto-compaction (below).
# The two alert events are told apart by the payload's hook_event_name; any
# other event gets nothing.
#
# MAIN AGENT ONLY. A payload with a non-empty agent_id comes from a subagent
# (an Employee): tool events fire inside subagents with agent_id set (hooks
# reference, common input fields). It is ignored. agent_type alone is not a
# subagent: the main thread carries it under `claude --agent`.
#
# WHERE THE PERCENTAGE COMES FROM. Only from the file the statusLine wrapper
# (hooks/context-statusline.sh, WU-IAENG-379) writes:
#     ${TMPDIR:-/tmp}/iaeng-ctx-<uid>/<session_id>.pct
# with the writer's rules for the directory (TMPDIR only when absolute with no
# . or .. component, else /tmp) and for the session id
# ([A-Za-z0-9][A-Za-z0-9_-]{0,127}: no path can be built from it). Never from
# the transcript. Before anything is said, the file is believed only when:
#   - the directory is a directory, not a symbolic link, owned by the user,
#     and writable by neither group nor others;
#   - the file is a regular file, not a symbolic link, owned by the user,
#     writable by neither group nor others, and at most 4 bytes long;
#   - its content is one whole number from 0 to 100, an optional newline
#     after it, and nothing else.
# Otherwise, or when the file is absent: silence, exit 0. On Windows (Git
# Bash on NTFS) the mode bits are not kept and -O holds for the user's files,
# so the group/other rule is always met there: the boundary is the per-user
# %TEMP% ACL, as for the writer.
#
# ONLY THIS SESSION'S FILES. The hook reads <session_id>.pct and
# <session_id>.alert for the session in the payload, and nothing else in the
# directory: another session's files are never read, judged or removed. So a
# session that ended after its reading crossed a step (its .pct left behind)
# costs the others nothing, and two sessions run with different thresholds
# cannot re-arm each other (SEC-IAENG-380-02, SRE F1 and F2, CR M2). Removing
# files of ended sessions is the writer's job (#321).
#
# ONCE PER STEP. Two steps: the alert at IAENG_CTX_ALERT_PCT (default 60, the
# Director's provisional default of 23 Oct 2026, issue #304) and the last call
# at IAENG_CTX_LAST_CALL_PCT (default: the alert + 10; none when that passes
# 100). Each is said once: the step said is kept in
#     <same directory>/<session_id>.alert
# — the user-level directory above, never inside the project — written to a
# new name with noclobber and renamed over it (a rename replaces a link, never
# follows one), and believed only under the same rules as the .pct file. The
# message is printed only when that write succeeded: an alert that cannot be
# remembered would repeat on every prompt, and "at most once per step" is the
# acceptance criterion (AC3). A reading below the alert threshold — after a
# compaction or a /clear — removes this session's record, so the next
# crossing is said again. A reading above both steps at once says the last
# call alone.
#
# CHEAP WHEN THERE IS NOTHING TO SAY. PostToolBatch runs after every batch of
# tool calls, and on Windows every process costs (the bash that runs this
# hook is the floor). So the first 4 KiB of the payload are read with a shell
# builtin; a payload whose head names a non-empty agent_id is a subagent's
# and is dropped; the session id is taken from the head (the hooks reference
# puts it first), and this session's two files are read with builtins. Only
# when this session has a step left to hear (or a record to re-arm) does the
# hook read the rest of the payload, start jq and run every check above. A
# nested "agent_id" or "session_id" key inside a tool's input, in the head,
# can make one event miss its alert: fail-quiet, the next event recovers.
# Without a session id in the head, the full path runs.
#
# WHY +10 FOR THE LAST CALL (Governance/CONTEXT_COMPACTION_MEASUREMENT.md,
# WU-IAENG-374): auto-compaction ran at a median of 96.8 % of the 1M window
# and never below 84.8 % in 24 real compactions; ordinary growth is about
# 31,000 tokens per 20 calls (3.1 points). The last call at 70 % leaves about
# 15 points (some 95 calls at that rate) before the lowest compaction seen and
# 27 points before the median one: room for a Handoff even when the Work Unit
# overruns. The alert-to-last-call gap of 10 points is about 64 calls, enough
# for most Work Units to close. The measurement's own caveat holds: the D+14
# trial measures the real overshoot.
#
# THE SESSIONSTART WARNING compares the steps with an ESTIMATE of where
# auto-compaction may run, as a percentage of the context window the status
# line measures (Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md, section
# A, item 5). The median point is window% × (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
# or 100) / 100, where window% is CLAUDE_CODE_AUTO_COMPACT_WINDOW over an
# assumed 1,000,000-token context window, or 96 when the variable is unset
# (the documented ~967K default of a 1M model; 96.8 % measured). The warning
# uses the FLOOR, 12 points lower: the lowest compaction measured (848,341
# tokens) came about 120,000 tokens, 12 points of a 1M window, under the
# median one (968,011), because the reading the status line shows is the last
# call's, and a large turn can trigger a compaction from there (SRE F3). It
# warns when the alert is at or above the floor, or else when the last call
# is. Only the environment is read: a window set with /autocompact or the
# autoCompactWindow setting is not seen. With DISABLE_AUTO_COMPACT or
# DISABLE_COMPACT set there is no auto-compaction to compare with, and no
# warning. An IAENG_CTX_ALERT_PCT that is not a whole number from 1 to 100 is
# also said there (the default is used). The payload is not read.
#
# SWITCHED OFF, as the statusLine is: the file .ia-engineering/context-hooks.off
# in the project, or IAENG_CONTEXT_HOOKS set to 0, off, false or no (any case).
#
# FAIL-OPEN, ALWAYS (AC3, AC7): exit 0 on every path, nothing on stderr,
# nothing on stdout but one JSON object when there is something to say (with
# --session-start, the warning's plain text).

set -u
export LC_ALL=C

trap 'exit 0' EXIT

MODE=alert
[ "${1:-}" = --session-start ] && MODE=session-start

# --- Switch -------------------------------------------------------------------
case "${IAENG_CONTEXT_HOOKS:-}" in
  [0]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) exit 0 ;;
esac
[ -e "${CLAUDE_PROJECT_DIR:-$PWD}/.ia-engineering/context-hooks.off" ] && exit 0

# --- Thresholds ---------------------------------------------------------------
DEFAULT_ALERT=60
ALERT_RAW="${IAENG_CTX_ALERT_PCT:-}"
ALERT_BAD=0
if [ -z "$ALERT_RAW" ]; then
  ALERT=$DEFAULT_ALERT
elif [[ $ALERT_RAW =~ ^[0-9]{1,3}$ ]] && [ "$((10#$ALERT_RAW))" -ge 1 ] && [ "$((10#$ALERT_RAW))" -le 100 ]; then
  ALERT=$((10#$ALERT_RAW))
else
  ALERT=$DEFAULT_ALERT
  ALERT_BAD=1
fi
LAST=""
LAST_RAW="${IAENG_CTX_LAST_CALL_PCT:-}"
if [[ $LAST_RAW =~ ^[0-9]{1,3}$ ]] && [ "$((10#$LAST_RAW))" -gt "$ALERT" ] && [ "$((10#$LAST_RAW))" -le 100 ]; then
  LAST=$((10#$LAST_RAW))
elif [ $((ALERT + 10)) -le 100 ]; then
  LAST=$((ALERT + 10))
fi

# step_of <pct> — STEP: 0 under the alert, 1 from the alert, 2 from the last call.
step_of() {
  STEP=0
  [ "$1" -ge "$ALERT" ] && STEP=1
  [ -n "$LAST" ] && [ "$1" -ge "$LAST" ] && STEP=2
  return 0
}

# json_out <event> <text> — the one JSON object Claude Code reads on exit 0.
# The text is this script's own: only \, " and newlines need escaping.
json_out() {
  local t="$2"
  t="${t//\\/\\\\}"
  t="${t//\"/\\\"}"
  t="${t//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$t"
}

# --- SessionStart: the threshold warning --------------------------------------
if [ "$MODE" = session-start ]; then
  MSG=""
  if [ "$ALERT_BAD" -eq 1 ]; then
    MSG="IA Engineering context alert: IAENG_CTX_ALERT_PCT is not a whole number from 1 to 100, so the default of $DEFAULT_ALERT % is used (Adapters/ai-runtimes/claude-code/hooks/README.md, Context Alert). Tell the Director in one line."
  fi
  off=0
  for v in "${DISABLE_AUTO_COMPACT:-}" "${DISABLE_COMPACT:-}"; do
    case "$v" in ''|0|[Ff][Aa][Ll][Ss][Ee]) ;; *) off=1 ;; esac
  done
  if [ "$off" -eq 0 ]; then
    WIN_PCT=96
    SRC="the default window"
    W="${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}"
    if [[ $W =~ ^([0-9]{1,9})([kKmM]?)$ ]]; then
      w=$((10#${BASH_REMATCH[1]}))
      case "${BASH_REMATCH[2]}" in k|K) w=$((w * 1000)) ;; m|M) w=$((w * 1000000)) ;; esac
      [ "$w" -lt 100000 ] && w=100000
      [ "$w" -gt 1000000 ] && w=1000000
      WIN_PCT=$((w * 100 / 1000000))
      SRC="CLAUDE_CODE_AUTO_COMPACT_WINDOW"
    fi
    OV="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-}"
    EFF=$WIN_PCT
    if [[ $OV =~ ^[0-9]{1,3}$ ]] && [ "$((10#$OV))" -ge 1 ] && [ "$((10#$OV))" -le 100 ]; then
      EFF=$((WIN_PCT * 10#$OV / 100))
      SRC="$SRC and CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
    fi
    FLOOR=$((EFF - 12))
    [ "$FLOOR" -lt 1 ] && FLOOR=1
    if [ "$ALERT" -ge "$FLOOR" ]; then
      MSG="${MSG:+$MSG$'\n'}IA Engineering context alert: the alert threshold ($ALERT %, IAENG_CTX_ALERT_PCT) is at or above where auto-compaction may run: about $EFF % of the context window at the median, and as low as about $FLOOR % (the lowest compaction measured in Governance/CONTEXT_COMPACTION_MEASUREMENT.md came 12 points under the median), estimated from $SRC, assuming a 1,000,000-token window. The alert may come after the compaction it exists to prepare for. Tell the Director in one line, and suggest an IAENG_CTX_ALERT_PCT below $FLOOR (Adapters/ai-runtimes/claude-code/hooks/README.md, Context Alert)."
    elif [ -n "$LAST" ] && [ "$LAST" -ge "$FLOOR" ]; then
      MSG="${MSG:+$MSG$'\n'}IA Engineering context alert: the last call ($LAST %) is at or above where auto-compaction may run, as low as about $FLOOR % of the context window (about $EFF % at the median; estimated from $SRC, assuming a 1,000,000-token window); only the first alert, at $ALERT %, is sure to come before it. Tell the Director in one line."
    fi
  fi
  # Plain text: session-start.sh prints it among its own lines, and Claude
  # Code adds a SessionStart hook's plain stdout to the context.
  [ -n "$MSG" ] && printf '%s\n' "$MSG"
  exit 0
fi

# --- The directory --------------------------------------------------------------
BASE="${TMPDIR:-}"
case "$BASE" in
  /*|[A-Za-z]:[/\\]*) ;;
  *) BASE=/tmp ;;
esac
case "/$BASE/" in */../*|*/./*) BASE=/tmp ;; esac
BASE="${BASE%/}"
[[ ${UID:-} =~ ^[0-9]+$ ]] || exit 0
DIR="$BASE/iaeng-ctx-$UID"
# Ours before anything in it is opened (SEC-IAENG-380-01): a directory
# another user created first is never read.
[ -d "$DIR" ] && [ ! -L "$DIR" ] && [ -O "$DIR" ] || exit 0

# trusted <path>... — each is not a link, is owned by the user, and is
# writable by neither group nor others; a regular file among them holds at
# most 4 bytes ("100" and a newline), so nothing after a NUL byte, which the
# shell's read would stop at, can hide behind a valid number. One find.
trusted() {
  local p out
  for p in "$@"; do
    [ ! -L "$p" ] && [ -O "$p" ] || return 1
  done
  out="$(find "$@" -prune \( -perm -020 -o -perm -002 -o \( -type f -size +4c \) \) -print 2>/dev/null)" || return 1
  [ -z "$out" ]
}

# said_of <file> — SAID: the step a .alert record holds, 0 when none. The
# redirection is inside the group, so a failed open says nothing on stderr.
said_of() {
  local s=""
  SAID=0
  if [ ! -f "$1" ] || [ -L "$1" ]; then return 0; fi
  { IFS= read -r -n 4 s < "$1"; } 2>/dev/null
  case "$s" in 1|2) SAID=$s ;; esac
  return 0
}

# --- Payload head: builtins only -------------------------------------------------
[ -t 0 ] && exit 0
HEAD=""
IFS= read -r -d '' -n 4096 HEAD
if [[ $HEAD =~ \"agent_id\"[[:space:]]*:[[:space:]]*\"[^\"] ]]; then
  exit 0
fi

# --- Fast gate: this session's two files, builtins only ---------------------------
# Exits when this session has nothing to hear. Every rule is checked again on
# the full path before anything is said or removed.
SID_HEAD=""
if [[ $HEAD =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([A-Za-z0-9][A-Za-z0-9_-]{0,127})\" ]]; then
  SID_HEAD="${BASH_REMATCH[1]}"
fi
if [ -n "$SID_HEAD" ]; then
  f="$DIR/$SID_HEAD.pct"
  if [ ! -f "$f" ] || [ -L "$f" ]; then exit 0; fi
  v=""
  { IFS= read -r -n 4 v < "$f"; } 2>/dev/null
  if ! [[ $v =~ ^[0-9]{1,3}$ ]] || [ "$((10#$v))" -gt 100 ]; then exit 0; fi
  step_of "$((10#$v))"
  a="$DIR/$SID_HEAD.alert"
  said_of "$a"
  if [ "$STEP" -eq 0 ]; then
    # Nothing to say; go on only to re-arm a record this session holds.
    { [ -e "$a" ] || [ -L "$a" ]; } || exit 0
  elif [ "$STEP" -le "$SAID" ]; then
    exit 0
  fi
fi

# --- Full path: the whole payload ---------------------------------------------------
INPUT="$HEAD"
[ "${#HEAD}" -lt 4096 ] || INPUT="$HEAD$(cat 2>/dev/null)"

SID="" AGENT="" EVENT=""
if command -v jq >/dev/null 2>&1; then
  # The first JSON value only; anything that is not an object gives nothing.
  # Fields joined by the unit separator (byte 31), control characters out.
  FIELDS="$(printf '%s' "$INPUT" | jq -rn '
    (try input catch null) as $in
    | ([31] | implode) as $us
    | if ($in | type) != "object" then empty else
      def str(f): (try ($in | f) catch null) | if type == "string" then gsub("[[:cntrl:]]"; " ") else "" end;
      [str(.session_id), str(.agent_id), str(.hook_event_name)] | join($us)
      end' 2>/dev/null)"
  FIELDS="${FIELDS%%$'\n'*}"
  FIELDS="${FIELDS%$'\r'}"
  IFS=$'\x1f' read -r SID AGENT EVENT <<< "$FIELDS"
else
  # No jq: a key is matched by pattern, and a key that appears more than once
  # (a nested object of a tool's input may carry one) is not trusted: a second
  # session_id or event name means silence, any agent_id means a subagent.
  # A quote inside a JSON string is escaped, so text in a string never matches.
  sid_re='"session_id"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
  ev_re='"hook_event_name"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
  n_sid="$(grep -o '"session_id"[[:space:]]*:' <<< "$INPUT" | wc -l)"
  n_ev="$(grep -o '"hook_event_name"[[:space:]]*:' <<< "$INPUT" | wc -l)"
  if grep -q '"agent_id"[[:space:]]*:' <<< "$INPUT"; then
    AGENT=present
  fi
  if [ "${n_sid// /}" = 1 ] && [ "${n_ev// /}" = 1 ]; then
    [[ $INPUT =~ $sid_re ]] && SID="${BASH_REMATCH[1]}"
    [[ $INPUT =~ $ev_re ]] && EVENT="${BASH_REMATCH[1]}"
  fi
fi

# A subagent's hook, or a payload this hook cannot place: nothing.
[ -z "$AGENT" ] || exit 0
case "$EVENT" in
  UserPromptSubmit|PostToolBatch) ;;
  *) exit 0 ;;
esac
[[ $SID =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$ ]] || exit 0

# --- This session's percentage, every rule checked ---------------------------------
PCT_F="$DIR/$SID.pct"
SAID_F="$DIR/$SID.alert"
if [ ! -f "$PCT_F" ] || [ -L "$PCT_F" ]; then exit 0; fi
trusted "$DIR" "$PCT_F" || exit 0
RAW=""
{ IFS= read -r -d '' -n 16 RAW < "$PCT_F"; } 2>/dev/null
[[ $RAW =~ ^([0-9]{1,3})$'\n'?$ ]] || exit 0
PCT=$((10#${BASH_REMATCH[1]}))
[ "$PCT" -le 100 ] || exit 0

step_of "$PCT"
SAID=0
if [ -f "$SAID_F" ] && [ ! -L "$SAID_F" ] && trusted "$SAID_F"; then
  said_of "$SAID_F"
fi
if [ "$STEP" -eq 0 ]; then
  # Below the alert: this session's next crossing is said again. A link is
  # removed, never followed (rm acts on the link itself).
  { [ -e "$SAID_F" ] || [ -L "$SAID_F" ]; } && rm -f -- "$SAID_F" 2>/dev/null
  exit 0
fi
[ "$STEP" -gt "$SAID" ] || exit 0

# Remember first; say only what is remembered.
if [ -L "$SAID_F" ] || { [ -e "$SAID_F" ] && [ ! -f "$SAID_F" ]; }; then exit 0; fi
TMPF="$DIR/.$SID.alert.$$.$RANDOM.tmp"
trap '[ -n "${TMPF:-}" ] && rm -f -- "$TMPF" 2>/dev/null; exit 0' EXIT
( umask 077; set -C; printf '%s\n' "$STEP" > "$TMPF" ) 2>/dev/null || { TMPF=""; exit 0; }
mv -f -- "$TMPF" "$SAID_F" 2>/dev/null || exit 0
TMPF=""

HANDOFF="the Handoff to a New Conversation checklist of Templates/SESSION_STATE.md, items 1 to 6, written into .ia-engineering/SESSION_STATE.md: today's absolute date in the header; Where the Project Stands and Next Step rewritten as of now; Blocked On with every open Director question; open Pull Requests and Employees in flight, and whether their work is committed; runtime memory pointing to that file, not duplicating it; the right working directory"

if [ "$STEP" -eq 1 ]; then
  NEXT_LINE="A last call follows at ${LAST:-?} %."
  [ -n "$LAST" ] || NEXT_LINE="No further alert follows."
  MSG="IA Engineering context alert: this session's context is at $PCT % of the window (alert threshold $ALERT %). Head for the Handoff, so a compaction loses nothing; do not stop or abandon the work in hand:
1. Finish the Work Unit in progress. Start no other one until the Handoff is written.
2. Dispatch no new Employee for any other work. Allowed: continuing an Employee already dispatched (answering it, waiting for its report, reviewing its work), and dispatching an Employee the Work Unit in progress still needs to be delivered, such as its reviewers.
3. When that Work Unit is delivered, run $HANDOFF.
4. Then tell the Director in one line that the Handoff is written, and carry on; no answer is needed.
This alert is said once and blocks nothing. $NEXT_LINE"
else
  MSG="IA Engineering context last call: this session's context is at $PCT % of the window (last call $LAST %). Write the Handoff now, before any other step, even if the current Work Unit is not finished: run $HANDOFF. Record where the unfinished Work Unit stands and which Employees are still in flight. Dispatch no new Employee for any other work; continuing one already dispatched is allowed. Then tell the Director in one line that the Handoff is written, and resume the Work Unit; no answer is needed. Said once; blocks nothing."
fi
json_out "$EVENT" "$MSG"
exit 0
