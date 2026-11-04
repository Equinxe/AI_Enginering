#!/usr/bin/env bash
# IA Engineering — hook tests: the context alert (WU-IAENG-380)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/context-alert.sh [--verbose]
#
# What is proved, each against a scratch TMPDIR, fallback (in place of
# /tmp, IAENG_CTX_TEST_FALLBACK) and project, never the real ones; the last
# check is that the user's real iaeng-ctx directory was left alone
# (tests/real-ctx-dir.sh, issue #345):
#
#   - never blocks: exit 0 and nothing on stderr on every input, the hostile
#     ones included (empty, not JSON, not an object, unusable directory);
#   - silent without the .pct file, below the threshold, for another
#     session's file, for a subagent's payload (agent_id), and for a .pct that
#     is forged or unsafe (not a number, out of range, extra bytes, a NUL, a
#     directory, a link, a directory or file others can write, a hostile
#     session id);
#   - once per step: the alert once at the threshold, the last call once at
#     the threshold + 10, on UserPromptSubmit and PostToolBatch alike, said
#     again after the reading falls below the threshold; a reading past both
#     steps says the last call alone;
#   - the output is one JSON object of the documented shape, naming the
#     Handoff checklist, the Work Unit to finish and no new Employee;
#   - the overrides (IAENG_CTX_ALERT_PCT, IAENG_CTX_LAST_CALL_PCT) and the
#     switches (IAENG_CONTEXT_HOOKS, .ia-engineering/context-hooks.off);
#   - the SessionStart warning against the estimated compaction threshold;
#   - the payload read without jq;
#   - the writer (context-statusline.sh) and this reader name the same
#     directory for every TMPDIR form, a backslash .. included (issue #340).
#
# ORACLES (Standards/TESTING_STANDARD.md, Independent Oracle), none taken from
# the hook's own output:
#   - 60 % default, once per step, never blocks, Main Agent only: issue #304
#     (decision log of 23 Oct 2026) and the WU-IAENG-380 brief;
#   - +10 for the last call: Governance/CONTEXT_COMPACTION_MEASUREMENT.md, as
#     argued in the hook's header;
#   - the file's path and content: the WU-IAENG-379 writer's contract,
#     ${TMPDIR}/iaeng-ctx-<uid>/<session_id>.pct holding "<integer>\n";
#   - the output shape {"hookSpecificOutput":{"hookEventName","additionalContext"}}
#     and agent_id as the subagent marker: https://code.claude.com/docs/en/hooks.md;
#   - the compaction estimate, worked by hand from TROUBLESHOOTING.md section A
#     item 5: a 400,000-token window on a 1M model compacts near 40 %; the
#     default window (967K) with CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50 near 48 %;
#   - the checklist's wording: Templates/SESSION_STATE.md, Handoff to a New
#     Conversation.
#
# A case the platform cannot stage (a symbolic link Git Bash cannot create,
# a mode Windows does not enforce) is reported "n/a" with its reason, never
# counted as a pass. A file owned by another user cannot be staged without
# root; its guard (-O) is read in review. Exit 0 when every check passes, 1
# when any fails, 2 when the environment is unusable. With
# IAENG_HOOK_TESTS_COUNTS set to a file, "<total> <failed>" is written there.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "context-alert.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
AL="$HOOKS/context-alert.sh"

command -v jq >/dev/null 2>&1 || {
  echo "context-alert.sh: jq is required and is not installed. Reported rather than skipped." >&2
  exit 2
}
[ -f "$AL" ] || { echo "context-alert.sh: $AL is missing" >&2; exit 2; }

FAILED=0
TOTAL=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0; }
na() { printf '   n/a   %s — %s\n' "$1" "$2"; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-ctx380.XXXXXX")" || { echo "context-alert.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'chmod -R u+w "$T" 2>/dev/null; cd / && rm -rf "$T"' EXIT

ID="$(id -u 2>/dev/null)"
[ -n "${UID:-}" ] && ID="$UID"
TMPD="$T/tmp"
PROJ="$T/project"
# The fallback a refused TMPDIR takes, in place of /tmp (issue #345): every
# run sets IAENG_CTX_TEST_FALLBACK to it, so no case reads or writes the
# user's real /tmp/iaeng-ctx-<uid>.
FB="$T/fallback"
mkdir -p "$TMPD" "$PROJ" "$FB"
DIR="$TMPD/iaeng-ctx-$ID"
mkdir -p "$DIR"
chmod 700 "$DIR"
# The user's real context directories, listed before any hook runs and
# checked at the end (tests/real-ctx-dir.sh).
# shellcheck source=real-ctx-dir.sh
. "$HERE/real-ctx-dir.sh"
real_ctx_begin "$T"

# pct <session> <content> — writes the file as the WU-IAENG-379 writer does.
pct() { printf '%s\n' "$2" > "$DIR/$1.pct"; }

# run <payload> [args...] — runs the hook as Claude Code does, with a scratch TMPDIR
# and project and none of the variables it reads, plus RUN_ENV. Sets OUT,
# ERR, RC.
RUN_ENV=()
run() {
  printf '%s' "$1" | env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_ALERT_PCT -u IAENG_CTX_LAST_CALL_PCT \
    -u CLAUDE_CODE_AUTO_COMPACT_WINDOW -u CLAUDE_AUTOCOMPACT_PCT_OVERRIDE \
    -u DISABLE_AUTO_COMPACT -u DISABLE_COMPACT \
    TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" CLAUDE_PROJECT_DIR="$PROJ" ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
    bash "$AL" "${@:2}" > "$T/out" 2> "$T/err"
  RC=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}
# ups <session> / ptb <session> — the two alert events' payloads.
ups() { jq -cn --arg s "$1" '{session_id:$s, transcript_path:"/x.jsonl", cwd:"/x", permission_mode:"default", hook_event_name:"UserPromptSubmit", prompt:"go on"}'; }
ptb() { jq -cn --arg s "$1" '{session_id:$s, transcript_path:"/x.jsonl", cwd:"/x", permission_mode:"default", hook_event_name:"PostToolBatch", tool_calls:[{tool_name:"Read", tool_input:{file_path:"/a"}, tool_use_id:"toolu_01", tool_response:"1\tx"}]}'; }
sst() { jq -cn '{session_id:"s-start", hook_event_name:"SessionStart", source:"startup"}'; }

# silent <label> — exit 0, no stdout, no stderr.
silent() {
  if [ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ]; then ok "$1: exit 0, silent"
  else bad "$1: exit 0, silent" "rc=$RC out=[$OUT] err=[$ERR]"; fi
}
# says <label> <event> <substring>... — exit 0, no stderr, stdout one JSON
# object of the documented shape for <event>, whose additionalContext holds
# every substring. With <event> "text" (--session-start): stdout is plain
# text, not JSON, holding every substring.
says() {
  local label="$1" ev="$2" ctx s; shift 2
  if [ "$RC" -ne 0 ] || [ -n "$ERR" ]; then bad "$label" "rc=$RC err=[$ERR]"; return; fi
  if [ "$ev" = text ]; then
    case "$OUT" in ''|'{'*) bad "$label" "not plain text: [$OUT]"; return ;; esac
    for s in "$@"; do
      grep -qF -- "$s" <<< "$OUT" || { bad "$label" "missing [$s] in: $OUT"; return; }
    done
    ok "$label"; return
  fi
  if ! jq -es --arg e "$ev" 'length == 1 and (.[0] | keys == ["hookSpecificOutput"])
        and (.[0].hookSpecificOutput | keys == ["additionalContext", "hookEventName"])
        and .[0].hookSpecificOutput.hookEventName == $e
        and (.[0].hookSpecificOutput.additionalContext | type == "string")' <<< "$OUT" >/dev/null 2>&1; then
    bad "$label" "not one {hookSpecificOutput:{hookEventName:$ev, additionalContext}} object: [$OUT]"; return
  fi
  ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<< "$OUT" | tr -d '\r')"
  for s in "$@"; do
    grep -qF -- "$s" <<< "$ctx" || { bad "$label" "missing [$s] in: $ctx"; return; }
  done
  ok "$label"
}

can_link() {
  rm -f "$T/probe-link"
  MSYS=winsymlinks:sys ln -s "$T" "$T/probe-link" 2>/dev/null
  [ -L "$T/probe-link" ] && { rm -f "$T/probe-link"; return 0; }
  return 1
}
# Group- and world-write bits are kept and seen by find -perm (not on Windows).
mode_kept() {
  : > "$T/probe-mode"; chmod 666 "$T/probe-mode" 2>/dev/null
  local r=1
  [ -n "$(find "$T/probe-mode" -perm -002 2>/dev/null)" ] && r=0
  rm -f "$T/probe-mode"
  return "$r"
}

# =============================================================================
echo "== context-alert.sh — silence"

run "$(ups s-none)"
silent "no .pct file for the session"
rm -rf "$DIR"
run "$(ups s-none)"
silent "no iaeng-ctx directory at all"
mkdir -p "$DIR"; chmod 700 "$DIR"

pct s-low 59
run "$(ups s-low)"
silent "59 %, one point under the default 60 %"

pct s-other 90
run "$(ups s-mine)"
silent "another session's file at 90 %, none for this session"
if [ ! -e "$DIR/s-other.alert" ] && [ ! -e "$DIR/s-mine.alert" ]; then ok "another session's file: nothing recorded for either"; else bad "another session's file: nothing recorded for either" "$(ls -a "$DIR")"; fi

pct s-sub 80
run "$(jq -cn '{session_id:"s-sub", hook_event_name:"PostToolBatch", agent_id:"a84afd0c1caac6f42", agent_type:"platform-engineer", tool_calls:[]}')"
silent "a subagent's PostToolBatch (agent_id set) at 80 %"
run "$(jq -cn '{session_id:"s-sub", hook_event_name:"UserPromptSubmit", agent_id:"a1", prompt:"x"}')"
silent "a subagent's UserPromptSubmit (agent_id set) at 80 %"
if [ ! -e "$DIR/s-sub.alert" ]; then ok "a subagent's hook records nothing"; else bad "a subagent's hook records nothing"; fi
run "$(jq -cn '{session_id:"s-sub", hook_event_name:"UserPromptSubmit", agent_id:"", prompt:"x"}')"
says "an empty agent_id is the Main Agent: it is told" UserPromptSubmit "last call"
rm -f "$DIR/s-sub.alert"
run "$(jq -cn '{session_id:"s-sub", hook_event_name:"UserPromptSubmit", agent_type:"claude", prompt:"x"}')"
says "agent_type alone (the main thread under claude --agent) is the Main Agent: it is told" UserPromptSubmit "last call"

for p in '' 'not json' '[1,2]' '"a string"' '{"session_id":' 'null'; do
  run "$p"
  silent "payload [$p]"
done
pct s-ev 80
run "$(jq -cn '{session_id:"s-ev", hook_event_name:"Stop"}')"
silent "another event (Stop) at 80 %"
run "$(jq -cn '{session_id:"s-ev", hook_event_name:"PostToolUse", tool_name:"Read"}')"
silent "PostToolUse (not one of its events) at 80 %"
run "$(jq -cn '{session_id:"s-ev", hook_event_name:"SessionStart", source:"startup"}')"
silent "a SessionStart payload without --session-start at 80 %: not an alert event"
# 300 KB of tool results, through a file: too long for an argument.
head -c 300000 /dev/zero | tr '\0' 'x' > "$T/big"
BIG_P="$(jq -cn --rawfile b "$T/big" '{session_id:"s-ev", hook_event_name:"PostToolBatch", tool_calls:[{tool_name:"Read", tool_response:$b}]}')"
if [ "${#BIG_P}" -gt 300000 ]; then ok "the 300 KB payload is built"; else bad "the 300 KB payload is built" "${#BIG_P} bytes"; fi
run "$BIG_P"
says "a 300 KB PostToolBatch payload is read whole: the alert at 80 %" PostToolBatch "context last call" "context is at 80 %"
rm -f "$DIR/s-ev.alert"
run "$(jq -c '. + {agent_id:"a-late"}' <<< "$BIG_P")"
silent "a subagent whose agent_id comes after 300 KB of tool results"
if [ ! -e "$DIR/s-ev.alert" ]; then ok "a late agent_id: nothing recorded"; else bad "a late agent_id: nothing recorded"; fi

# =============================================================================
echo "== context-alert.sh — forged or unsafe .pct"

forged() {
  local label="$1"
  run "$(ups s-forged)"
  silent "$label"
  rm -rf "$DIR/s-forged.pct" "$DIR/s-forged.alert"
}
for c in abc 101 '60x' '-5' ' 60' '60.5' '1000' ''; do
  printf '%s\n' "$c" > "$DIR/s-forged.pct"; forged "a .pct holding [$c]"
done
printf '60\n70\n' > "$DIR/s-forged.pct"; forged "a .pct holding two lines"
printf '60\r\n' > "$DIR/s-forged.pct"; forged "a .pct with a CR"
printf '60\n\n\n' > "$DIR/s-forged.pct"; forged "a .pct with bytes after its newline"
printf '60\000junk\n' > "$DIR/s-forged.pct"; forged "a .pct with a NUL and more after 60"
# Two files that pass the fast gate (its first line is a number) and that
# only the full path's rules refuse: a byte after the newline within 4 bytes
# (the content rule), and a NUL after the newline (the 4-byte size rule; the
# shell's read stops at the NUL, so "60\n" alone would be read).
printf '60\n7' > "$DIR/s-forged.pct"; forged "a .pct with a byte after its newline, 4 bytes in all"
printf '60\n\000junk' > "$DIR/s-forged.pct"; forged "a .pct with a NUL and more after its newline"
mkdir -p "$DIR/s-forged.pct"; forged "a directory in place of the .pct"

# Each hostile id finds a valid 90 % .pct at the very path it would reach
# without the shape check, so only that check keeps it silent (QA Q8):
#   ../s-esc  $DIR/../s-esc.pct = $TMPD/s-esc.pct; its temporary record
#             $DIR/.../s-esc.alert.* needs a directory "..." in $DIR, made
#             here so the write would succeed;
#   s.dot, -dash  $DIR/s.dot.pct, $DIR/-dash.pct;
#   ESC id    jq turns the control character into a space: $DIR/s x.pct.
N_ALERT="$(find "$TMPD" -name '*.alert' 2>/dev/null | wc -l | tr -d ' ')"
mkdir -p "$DIR/..."
printf '90\n' > "$TMPD/s-esc.pct"
printf '90\n' > "$DIR/s.dot.pct"
printf '90\n' > "$DIR/-dash.pct"
printf '90\n' > "$DIR/s x.pct"
for sid in '../s-esc' 's.dot' '-dash' "$(printf 's\033x')" ''; do
  run "$(jq -cn --arg s "$sid" '{session_id:$s, hook_event_name:"UserPromptSubmit", prompt:"x"}')"
  silent "a hostile session id [$sid], a 90 % .pct at the path it would reach"
done
if [ "$(find "$TMPD" -name '*.alert' 2>/dev/null | wc -l | tr -d ' ')" = "$N_ALERT" ]; then ok "a hostile session id: nothing recorded anywhere"; else bad "a hostile session id: nothing recorded anywhere" "$(find "$TMPD" -name '*.alert')"; fi
rm -rf "$DIR/..." "$TMPD/s-esc.pct" "$DIR/s.dot.pct" "$DIR/-dash.pct" "$DIR/s x.pct"

if can_link; then
  printf '90\n' > "$T/target.pct"
  MSYS=winsymlinks:sys ln -s "$T/target.pct" "$DIR/s-link.pct"
  run "$(ups s-link)"
  silent "a .pct that is a symbolic link to a valid file"
  LT="$T/linktmp"; mkdir -p "$LT" "$T/elsewhere"; chmod 700 "$T/elsewhere"
  printf '90\n' > "$T/elsewhere/s-dl.pct"
  MSYS=winsymlinks:sys ln -s "$T/elsewhere" "$LT/iaeng-ctx-$ID"
  RUN_ENV=(TMPDIR="$LT"); run "$(ups s-dl)"; RUN_ENV=()
  silent "an iaeng-ctx directory that is a symbolic link"
  if [ ! -e "$T/elsewhere/s-dl.alert" ]; then ok "a linked directory: nothing recorded through it"; else bad "a linked directory: nothing recorded through it"; fi
  pct s-al 65
  printf 'keep\n' > "$T/victim"
  MSYS=winsymlinks:sys ln -s "$T/victim" "$DIR/s-al.alert"
  run "$(ups s-al)"
  silent "a symbolic link planted at <session>.alert"
  if [ "$(cat "$T/victim")" = keep ]; then ok "a planted .alert link: its target is neither read as a record nor written"; else bad "a planted .alert link: its target is neither read as a record nor written" "$(cat "$T/victim")"; fi
else
  na "symbolic links (.pct, the directory, .alert)" "symbolic links cannot be created here (Git Bash without the right to create them)"
fi

if mode_kept; then
  pct s-ww 80; chmod 666 "$DIR/s-ww.pct"
  run "$(ups s-ww)"
  silent "a .pct others can write (0666)"
  OW="$T/openwrite"; mkdir -p "$OW/iaeng-ctx-$ID"; chmod 777 "$OW/iaeng-ctx-$ID"
  printf '80\n' > "$OW/iaeng-ctx-$ID/s-ow.pct"
  RUN_ENV=(TMPDIR="$OW"); run "$(ups s-ow)"; RUN_ENV=()
  silent "a directory others can write in (0777)"
else
  na "modes (a 0666 .pct, a 0777 directory)" "this platform does not keep group and world write bits (Windows)"
fi
# A 0500 directory refuses its owner (not on Windows, not as root).
mkdir -p "$T/probe-ro" && chmod 500 "$T/probe-ro"
if ( : > "$T/probe-ro/x" ) 2>/dev/null; then
  na "a directory the said-once record cannot be written in (0500)" "this platform does not enforce a 0500 directory against its owner (Windows or root)"
else
  pct s-ro 80; chmod 500 "$DIR"
  run "$(ups s-ro)"
  chmod 700 "$DIR"
  silent "a directory the said-once record cannot be written in (0500): no alert it could not remember"
fi
chmod 700 "$T/probe-ro"; rm -rf "$T/probe-ro"

# A TMPDIR the rules refuse names a directory that exists and holds an 80 %
# .pct for the session, so only the rule keeps the hook from using it (QA
# Q5): "$T/tmp/../tmp" resolves to the real $TMPD; "relative/tmp" exists
# under $T, where the hook is run from.
pct s-tmpd 80
mkdir -p "$T/relative/tmp/iaeng-ctx-$ID"; chmod 700 "$T/relative/tmp/iaeng-ctx-$ID"
printf '80\n' > "$T/relative/tmp/iaeng-ctx-$ID/s-tmpd.pct"
WAS_IN="$PWD"
cd "$T" || exit 2
for tmp in relative/tmp "$T/tmp/../tmp"; do
  RUN_ENV=(TMPDIR="$tmp"); run "$(ups s-tmpd)"; RUN_ENV=()
  silent "TMPDIR=$tmp (relative, or with ..): not used, though an 80 % .pct waits there"
done
cd "$WAS_IN" || exit 2
if [ ! -e "$DIR/s-tmpd.alert" ] && [ ! -e "$T/relative/tmp/iaeng-ctx-$ID/s-tmpd.alert" ]; then ok "a refused TMPDIR: nothing recorded there"; else bad "a refused TMPDIR: nothing recorded there"; fi
rm -rf "$T/relative" "$DIR/s-tmpd.pct"

# =============================================================================
echo "== context-alert.sh — once per step"

pct s-a 60
run "$(ups s-a)"
says "60 %: the alert, on UserPromptSubmit" UserPromptSubmit \
  "context is at 60 %" "alert threshold 60 %" \
  "Head for the Handoff" "do not stop or abandon the work in hand" \
  "Finish the Work Unit in progress" "Dispatch no new Employee for any other work" \
  "Allowed: continuing an Employee already dispatched" \
  "dispatching an Employee the Work Unit in progress still needs to be delivered, such as its reviewers" \
  "Handoff to a New Conversation checklist of Templates/SESSION_STATE.md, items 1 to 6" \
  ".ia-engineering/SESSION_STATE.md" "today's absolute date" "not duplicating it" \
  "and carry on; no answer is needed" "A last call follows at 70 %" "blocks nothing"
if [ "$(tr -d '\r' < "$DIR/s-a.alert")" = 1 ] && [ -z "$(find "$DIR" -name '*.tmp')" ]; then ok "the alert is recorded as step 1, no temporary file left"; else bad "the alert is recorded as step 1" "$(ls -a "$DIR")"; fi
run "$(ups s-a)"
silent "60 % again: said once"
pct s-a 66
run "$(ptb s-a)"
silent "66 % on PostToolBatch: the same step, said once"
pct s-a 70
run "$(ptb s-a)"
says "70 %: the last call, on PostToolBatch" PostToolBatch \
  "context last call" "context is at 70 %" "last call 70 %" "Write the Handoff now" \
  "even if the current Work Unit is not finished" "Dispatch no new Employee for any other work" \
  "Handoff to a New Conversation checklist of Templates/SESSION_STATE.md, items 1 to 6" \
  "and resume the Work Unit; no answer is needed"
pct s-a 75
run "$(ups s-a)"
silent "75 %: the last call, said once"
run "$(ptb s-a)"
silent "75 % on PostToolBatch: the last call, said once"
pct s-a 8
run "$(ups s-a)"
silent "8 % after a compaction"
if [ ! -e "$DIR/s-a.alert" ]; then ok "below the threshold the record is removed"; else bad "below the threshold the record is removed"; fi
pct s-a 61
run "$(ptb s-a)"
says "61 % after the reset: the alert again" PostToolBatch "context is at 61 %" "Finish the Work Unit in progress"

pct s-jump 85
run "$(ups s-jump)"
says "85 % at first sight: the last call alone" UserPromptSubmit "context last call" "context is at 85 %"
if ! grep -qF "Finish the Work Unit in progress" <<< "$OUT"; then ok "85 % at first sight: the first alert is not also said"; else bad "85 % at first sight: the first alert is not also said"; fi
pct s-jump 90
run "$(ups s-jump)"
silent "90 % after the last call: nothing more"

# A payload whose session id comes after its first 4 KiB skips the fast
# gate: the full path alone must keep "said once".
head -c 5000 /dev/zero | tr '\0' 'y' > "$T/pad"
late() { jq -c --rawfile p "$T/pad" -n '{tool_calls:[{tool_name:"Read", tool_response:$p}], hook_event_name:"PostToolBatch", session_id:"s-late"}'; }
pct s-late 65
run "$(late)"
says "a session id past the first 4 KiB: the alert, by the full path" PostToolBatch "context is at 65 %"
run "$(late)"
silent "a session id past the first 4 KiB: said once all the same"

# Two sessions, two thresholds (SRE F2, CR M2b): a session never judges,
# reads or removes another session's record. Session T30 runs with
# IAENG_CTX_ALERT_PCT=30 and is told at 35 % (its last call is at 40 %);
# session T60, on the default threshold at 10 %, must leave T30's record
# alone, so T30 is not told again.
pct s-t30 35
RUN_ENV=(IAENG_CTX_ALERT_PCT=30); run "$(ups s-t30)"; RUN_ENV=()
says "two thresholds: the session on 30 % is told at 35 %" UserPromptSubmit "alert threshold 30 %"
pct s-t60 10
run "$(ptb s-t60)"
silent "two thresholds: the session on the default, at 10 %"
if [ -f "$DIR/s-t30.alert" ]; then ok "two thresholds: the other session's record is left alone"; else bad "two thresholds: the other session's record is left alone" "$(ls -a "$DIR")"; fi
RUN_ENV=(IAENG_CTX_ALERT_PCT=30); run "$(ups s-t30)"; RUN_ENV=()
silent "two thresholds: the session on 30 % is not told twice"

# The cost (SEC-IAENG-380-02, SRE F1, CR M2c). Every external command the
# hook can start is a shim that leaves a mark, so "no process" is observed,
# not assumed. A session that ended after its reading crossed a step leaves
# a .pct and no .alert behind; it must not send another session down the
# full path.
SHIM="$T/shim-bin"; MARK="$T/shim-mark"; mkdir -p "$SHIM"
for tool in jq cat find mv rm grep wc; do
  p="$(command -v "$tool" 2>/dev/null)" || continue
  printf '#!%s\nprintf "%%s\\n" %s >> "%s"\nexec "%s" "$@"\n' "$(command -v bash)" "$tool" "$MARK" "$p" > "$SHIM/$tool"
  chmod +x "$SHIM/$tool"
done
shimmed() { rm -f "$MARK"; RUN_ENV=(PATH="$SHIM:$PATH"); run "$1"; RUN_ENV=(); }
marks() { if [ -f "$MARK" ]; then tr '\n' ' ' < "$MARK"; fi; }
pct s-dead 75
rm -f "$DIR/s-dead.alert"
pct s-live 30
shimmed "$(ptb s-live)"
silent "cost: a dead session's .pct at 75 % beside this session at 30 %"
if [ -z "$(marks)" ]; then ok "cost: no process started when this session has nothing to hear, a dead session's file present"; else bad "cost: no process started when this session has nothing to hear, a dead session's file present" "started: $(marks)"; fi
pct s-live 65
shimmed "$(ptb s-live)"
says "cost: the shims run the hook as usual (the alert at 65 %)" PostToolBatch "context is at 65 %"
if [ -n "$(marks)" ]; then ok "cost: the seam sees the processes of the full path (jq and the record write)"; else bad "cost: the seam sees the processes of the full path" "no mark: the shims are not on the hook's PATH"; fi
shimmed "$(ptb s-live)"
silent "cost: 65 % again"
if [ -z "$(marks)" ]; then ok "cost: no process started once the step is said"; else bad "cost: no process started once the step is said" "started: $(marks)"; fi
shimmed "$(jq -cn '{session_id:"s-live", hook_event_name:"PostToolBatch", agent_id:"a-emp", tool_calls:[]}')"
if [ -z "$(marks)" ] && [ -z "$OUT" ]; then ok "cost: a subagent's batch starts no process"; else bad "cost: a subagent's batch starts no process" "started: $(marks)"; fi
if [ ! -e "$DIR/s-dead.alert" ]; then ok "cost: the dead session's files are not touched"; else bad "cost: the dead session's files are not touched"; fi

# A .pct that cannot be opened says nothing on stderr either (SEC-03): the
# redirection of every read covers the open (not on Windows, not as root).
pct s-noread 65; chmod 000 "$DIR/s-noread.pct"
if cat "$DIR/s-noread.pct" >/dev/null 2>&1; then
  na "a .pct that cannot be opened" "this platform lets its owner read a 0000 file (Windows or root)"
else
  run "$(ups s-noread)"
  silent "a .pct that cannot be opened: no stderr"
fi
chmod 600 "$DIR/s-noread.pct"; rm -f "$DIR/s-noread.pct"

# =============================================================================
echo "== context-alert.sh — thresholds and switches"

RUN_ENV=(IAENG_CTX_ALERT_PCT=30)
pct s-o 29; run "$(ups s-o)"; silent "IAENG_CTX_ALERT_PCT=30: 29 %"
pct s-o 30; run "$(ups s-o)"; says "IAENG_CTX_ALERT_PCT=30: the alert at 30 %" UserPromptSubmit "alert threshold 30 %" "A last call follows at 40 %"
pct s-o 40; run "$(ups s-o)"; says "IAENG_CTX_ALERT_PCT=30: the last call at 40 %" UserPromptSubmit "last call 40 %"
RUN_ENV=(IAENG_CTX_ALERT_PCT=30 IAENG_CTX_LAST_CALL_PCT=50)
pct s-o2 45; run "$(ups s-o2)"; says "IAENG_CTX_LAST_CALL_PCT=50: 45 % is the first alert" UserPromptSubmit "A last call follows at 50 %"
pct s-o2 49; run "$(ups s-o2)"; silent "IAENG_CTX_LAST_CALL_PCT=50: 49 %"
pct s-o2 50; run "$(ups s-o2)"; says "IAENG_CTX_LAST_CALL_PCT=50: the last call at 50 %" UserPromptSubmit "last call 50 %"
RUN_ENV=(IAENG_CTX_ALERT_PCT=95)
pct s-o3 99; run "$(ups s-o3)"; says "IAENG_CTX_ALERT_PCT=95: no last call past 100, the alert says so" UserPromptSubmit "alert threshold 95 %" "No further alert follows"
pct s-o3 100; run "$(ups s-o3)"; silent "IAENG_CTX_ALERT_PCT=95: 100 % after the alert, no step left"
for v in abc 0 101 -5 '6 0'; do
  RUN_ENV=(IAENG_CTX_ALERT_PCT="$v")
  rm -f "$DIR/s-bad.alert"
  pct s-bad 59; run "$(ups s-bad)"; silent "IAENG_CTX_ALERT_PCT=[$v] is invalid: 59 % is under the default"
  pct s-bad 60; run "$(ups s-bad)"; says "IAENG_CTX_ALERT_PCT=[$v] is invalid: the default 60 % applies" UserPromptSubmit "alert threshold 60 %"
done
RUN_ENV=()

pct s-off 80
for v in off OFF 0 false no; do
  RUN_ENV=(IAENG_CONTEXT_HOOKS="$v"); run "$(ups s-off)"; RUN_ENV=()
  silent "IAENG_CONTEXT_HOOKS=$v"
done
mkdir -p "$PROJ/.ia-engineering"; : > "$PROJ/.ia-engineering/context-hooks.off"
run "$(ups s-off)"
silent ".ia-engineering/context-hooks.off in the project"
rm -f "$PROJ/.ia-engineering/context-hooks.off"
if [ ! -e "$DIR/s-off.alert" ]; then ok "switched off: nothing recorded"; else bad "switched off: nothing recorded"; fi

# =============================================================================
echo "== context-alert.sh — SessionStart"

# Oracles worked by hand: median point = window% x override / 100 (96 with
# no window set; TROUBLESHOOTING.md A.5); floor = median - 12, the spread
# between the median (968,011) and the lowest (848,341) compaction of
# Governance/CONTEXT_COMPACTION_MEASUREMENT.md, in points of a 1M window.
run "$(sst)" --session-start
silent "SessionStart, defaults: alert 60, last call 70, floor 84"
RUN_ENV=(IAENG_CTX_ALERT_PCT=70); run "$(sst)" --session-start
silent "SessionStart, alert 70, last call 80: both under the floor 84"
RUN_ENV=(IAENG_CTX_ALERT_PCT=85); run "$(sst)" --session-start
says "SessionStart, alert 85 on the default window: past the floor 84 (SRE F3)" text "the alert threshold (85 %" "about 96 % of the context window at the median" "as low as about 84 %" "below 84" "Tell the Director in one line"
RUN_ENV=(IAENG_CTX_ALERT_PCT=84); run "$(sst)" --session-start
says "SessionStart, alert 84: at the floor counts" text "the alert threshold (84 %" "as low as about 84 %"
RUN_ENV=(IAENG_CTX_ALERT_PCT=75); run "$(sst)" --session-start
says "SessionStart, alert 75: the last call at 85 passes the floor 84" text "the last call (85 %)" "as low as about 84 %" "only the first alert, at 75 %" "Tell the Director in one line"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000); run "$(sst)" --session-start
says "SessionStart, a 400,000-token window: median 40 %, floor 28 %, the 60 % alert comes after" text "the alert threshold (60 %" "about 40 %" "as low as about 28 %" "CLAUDE_CODE_AUTO_COMPACT_WINDOW" "below 28"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400k); run "$(sst)" --session-start
says "SessionStart, a 400k window: the same 40 % and 28 %" text "about 40 %" "about 28 %"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 IAENG_CTX_ALERT_PCT=15); run "$(sst)" --session-start
silent "SessionStart, a 400,000 window (floor 28), alert 15 and last call 25: both come before it"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 IAENG_CTX_ALERT_PCT=20); run "$(sst)" --session-start
says "SessionStart, a 400,000 window, alert 20: the last call at 30 passes the floor 28" text "the last call (30 %)" "only the first alert, at 20 %"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=800000); run "$(sst)" --session-start
says "SessionStart, an 800,000 window (floor 68): the alert at 60 comes first, the last call at 70 does not" text "the last call (70 %)" "about 80 %" "as low as about 68 %" "only the first alert, at 60 %"
RUN_ENV=(CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50); run "$(sst)" --session-start
says "SessionStart, CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50 on the default window: median 48 %, floor 36 %" text "about 48 %" "as low as about 36 %" "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 DISABLE_AUTO_COMPACT=1); run "$(sst)" --session-start
silent "SessionStart, DISABLE_AUTO_COMPACT=1: no auto-compaction, no warning"
RUN_ENV=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 DISABLE_COMPACT=1); run "$(sst)" --session-start
silent "SessionStart, DISABLE_COMPACT=1: no warning"
RUN_ENV=(IAENG_CTX_ALERT_PCT=abc); run "$(sst)" --session-start
says "SessionStart, an invalid IAENG_CTX_ALERT_PCT is said, for the Director" text "is not a whole number from 1 to 100" "default of 60 %" "Tell the Director in one line."
RUN_ENV=(IAENG_CONTEXT_HOOKS=off IAENG_CTX_ALERT_PCT=99); run "$(sst)" --session-start
silent "SessionStart, switched off"
RUN_ENV=()

# session-start.sh runs it and prints its line among its own; silent when
# there is nothing to warn about.
ss_with() {
  env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_ALERT_PCT -u IAENG_CTX_LAST_CALL_PCT -u IAENG_FRAMEWORK \
    -u CLAUDE_CODE_AUTO_COMPACT_WINDOW -u CLAUDE_AUTOCOMPACT_PCT_OVERRIDE -u DISABLE_AUTO_COMPACT -u DISABLE_COMPACT \
    CLAUDE_PROJECT_DIR="$PROJ" "$@" bash "$HOOKS/session-start.sh" < /dev/null > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"
}
ss_with CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000
if [ "$RC" -eq 0 ] && grep -qF "the alert threshold (60 %, IAENG_CTX_ALERT_PCT) is at or above" <<< "$OUT"; then ok "session-start.sh prints the warning (a 400,000 window)"; else bad "session-start.sh prints the warning (a 400,000 window)" "rc=$RC $(head -c 400 <<< "$OUT")"; fi
ss_with IAENG_CTX_ALERT_PCT=60
if [ "$RC" -eq 0 ] && ! grep -qF "IA Engineering context" <<< "$OUT" && grep -qF "Rules enforced by hooks" <<< "$OUT"; then ok "session-start.sh says nothing of the alert when nothing is wrong"; else bad "session-start.sh says nothing of the alert when nothing is wrong" "rc=$RC"; fi

# =============================================================================
echo "== context-alert.sh — no jq"

NOJQ="$T/nojq-bin"; mkdir -p "$NOJQ"
for tool in cat find mv rm grep wc; do
  p="$(command -v "$tool" 2>/dev/null)" || continue
  printf '#!%s\nexec "%s" "$@"\n' "$(command -v bash)" "$p" > "$NOJQ/$tool"
  chmod +x "$NOJQ/$tool"
done
BASH_BIN="$(command -v bash)"
nojq() {
  printf '%s' "$1" | env -i PATH="$NOJQ" TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" CLAUDE_PROJECT_DIR="$PROJ" "$BASH_BIN" "$AL" > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
}
if env -i PATH="$NOJQ" "$BASH_BIN" -c 'command -v jq' >/dev/null 2>&1; then
  bad "no jq: the test PATH still finds jq"
else
  pct s-nojq 62
  nojq '{"session_id":"s-nojq","hook_event_name":"UserPromptSubmit","prompt":"x"}'
  says "no jq: the alert at 62 %" UserPromptSubmit "context is at 62 %"
  nojq '{"session_id":"s-nojq","hook_event_name":"UserPromptSubmit","prompt":"x"}'
  silent "no jq: said once"
  pct s-nojq2 80
  nojq '{"session_id":"s-nojq2","hook_event_name":"PostToolBatch","agent_id":"a1","tool_calls":[]}'
  silent "no jq: a subagent's payload"
  nojq '{"session_id":"s-nojq2","hook_event_name":"PostToolBatch","tool_calls":[{"tool_input":{"session_id":"s-nojq"}}]}'
  silent "no jq: a second session_id key in a tool's input is not trusted"
  nojq '{"session_id":"s-nojq2","hook_event_name":"UserPromptSubmit","prompt":"say \"agent_id\": 1"}'
  says "no jq: agent_id inside a string is text, not a key" UserPromptSubmit "context last call"
  nojq 'garbage {"session_id": "x'
  silent "no jq: not JSON"
fi

# =============================================================================
echo "== context-statusline.sh then context-alert.sh — one directory for every TMPDIR (issue #340)"
# The writer and the reader must name the same directory, or the alert never
# fires. For each TMPDIR form below, the real writer records 90 %, then the
# real reader runs under the same environment. The oracle is written by hand
# from the rule (hooks/README.md, Context Status Line, The file: TMPDIR counts
# only when absolute with no . or .. component, with either separator, else
# /tmp), never taken from the hooks:
#   - where the .pct must land: TMPDIR's own iaeng-ctx-<uid>, the fallback's
#     when the rule refuses TMPDIR, or nowhere when the directory cannot be
#     made;
#   - the reader then says the last call at 90 %, or, when nothing was
#     written, both refuse alike: no file anywhere, and silence.
# Every case runs in a scratch working directory, so a relative path a broken
# rule accepted would land there and be seen. The fallback is /tmp for the
# user and the scratch $FB here (IAENG_CTX_TEST_FALLBACK, issue #345), so no
# case touches the user's real /tmp/iaeng-ctx-<uid>, and every .pct written
# is under $T, where it is counted. That /tmp is the fallback itself is
# checked by naming the directory, which writes nothing (after the pairs).
SL="$HOOKS/context-statusline.sh"
FALLBACK="$FB/iaeng-ctx-$ID"
H394="$T/home394"; CWD394="$T/cwd394"
mkdir -p "$H394" "$CWD394" "$T/dotdot394"
: > "$T/afile394"
N394=0
# pair <label> <expected directory, or none> <TMPDIR, or -unset>
pair() {
  local label="$1" want="$2" tmp="$3" sid where n tenv payload
  N394=$((N394 + 1))
  sid="s394-$$-$N394"
  if [ "$tmp" = -unset ]; then tenv=(-u TMPDIR); else tenv=(TMPDIR="$tmp"); fi
  # Here-strings, not pipes: a hook that exits before it reads its stdin
  # must not turn the feeder's broken pipe into a failure (pipefail is on).
  payload="$(printf '{"session_id":"%s","context_window":{"used_percentage":90}}' "$sid")"
  ( cd "$CWD394" && env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_CHAINED -u CLAUDE_CONFIG_DIR -u IAENG_CTX_ALERT_PCT \
      -u IAENG_CTX_LAST_CALL_PCT "${tenv[@]}" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$H394" CLAUDE_PROJECT_DIR="$PROJ" \
      bash "$SL" <<< "$payload" ) > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
  if [ "$RC" -eq 0 ] && [ -n "$OUT" ] && [ -z "$ERR" ]; then ok "$label: the writer exits 0 with a line"; else bad "$label: the writer exits 0 with a line" "rc=$RC out=[$OUT] err=[$ERR]"; fi
  # One path per line, counted as lines: a path with a space (a Windows
  # profile such as "C:\Users\Jean Dupont") is still one file (cr-343).
  where="$(find "$T" -name "$sid.pct" 2>/dev/null)"
  n="$(find "$T" -name "$sid.pct" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$want" = none ]; then
    if [ "$n" -eq 0 ]; then ok "$label: no .pct written anywhere"; else bad "$label: no .pct written anywhere" "found: $(tr '\n' ' ' <<< "$where")"; fi
  elif [ -f "$want/$sid.pct" ] && [ "$(cat "$want/$sid.pct")" = 90 ] && [ "$n" -eq 1 ]; then
    ok "$label: the .pct lands in $want"
  else
    bad "$label: the .pct lands in $want" "found $n: [$(tr '\n' ' ' <<< "$where")]"
  fi
  payload="$(ups "$sid")"
  ( cd "$CWD394" && env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_ALERT_PCT -u IAENG_CTX_LAST_CALL_PCT \
      "${tenv[@]}" IAENG_CTX_TEST_FALLBACK="$FB" CLAUDE_PROJECT_DIR="$PROJ" bash "$AL" <<< "$payload" ) > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
  if [ "$want" = none ]; then
    silent "$label: the reader refuses as the writer did"
  else
    says "$label: the reader finds the writer's .pct and says the last call" UserPromptSubmit "context is at 90 %"
  fi
}
pair "TMPDIR unset" "$FALLBACK" -unset
pair "TMPDIR normal" "$DIR" "$TMPD"
pair "TMPDIR with a trailing slash" "$DIR" "$TMPD/"
pair "TMPDIR with a forward-slash .." "$FALLBACK" "$T/tmp/../dotdot394"
pair "TMPDIR with a forward-slash ." "$FALLBACK" "$T/./tmp"
pair "TMPDIR C:\\x\\..\\y (backslash ..)" "$FALLBACK" 'C:\x\..\y'
pair "TMPDIR C:\\x\\.\\y (backslash .)" "$FALLBACK" 'C:\x\.\y'
pair "TMPDIR C:/x/./y (drive, forward-slash .)" "$FALLBACK" 'C:/x/./y'
pair "TMPDIR relative" "$FALLBACK" "relative394/tmp"
pair "TMPDIR a regular file" none "$T/afile394"
pair "TMPDIR missing" none "$T/no/such394"
if command -v cygpath >/dev/null 2>&1; then
  # Real Windows paths: the directory with backslashes and with a drive and
  # forward slashes, and a \..\ that names a directory which exists, so only
  # the .. rule keeps either hook out of it.
  pair "TMPDIR $(cygpath -w "$TMPD") (Windows form)" "$DIR" "$(cygpath -w "$TMPD")"
  pair "TMPDIR $(cygpath -m "$TMPD")/ (drive, forward slashes)" "$DIR" "$(cygpath -m "$TMPD")/"
  pair "TMPDIR <Windows path>\\..\\dotdot394 (an existing directory)" "$FALLBACK" "$(cygpath -w "$T/tmp")\\..\\dotdot394"
else
  na "TMPDIR as a real Windows path" "no Windows paths on this platform (no cygpath); the literal C:\\ forms above run everywhere"
fi
if [ -z "$(ls -A "$T/dotdot394")" ] && [ -z "$(ls -A "$CWD394")" ]; then ok "a refused TMPDIR is never written to, and nothing lands in the working directory"; else bad "a refused TMPDIR is never written to, and nothing lands in the working directory" "$(ls -A "$T/dotdot394" "$CWD394")"; fi

# The fallback itself, named and not written (issue #345): every pair above
# runs with the scratch fallback, so /tmp as the default is checked here, by
# calling the rule in a subshell. Nothing is created. Oracle: the rule as
# hooks/README.md states it, and context-dir.sh's own words for the test
# fallback (the same rule judges it; a refused value leaves /tmp).
# named <TMPDIR or -unset> <IAENG_CTX_TEST_FALLBACK or -unset>
named() {
  (
    if [ "$1" = -unset ]; then unset TMPDIR; else export TMPDIR="$1"; fi
    if [ "$2" = -unset ]; then unset IAENG_CTX_TEST_FALLBACK; else export IAENG_CTX_TEST_FALLBACK="$2"; fi
    # shellcheck source=../context-dir.sh
    . "$HOOKS/context-dir.sh" || exit 1
    X=""
    iaeng_ctx_dir X && printf '%s' "$X"
  )
}
# <expected>|<TMPDIR>|<fallback>. Naming touches no file, so the backslash
# forms run on every platform: C:\tmp is accepted and /a\..\b refused, which
# a context-dir.sh that lost or doubled its backslash gets wrong.
for c in "/tmp/iaeng-ctx-$ID|-unset|-unset" \
         "/tmp/iaeng-ctx-$ID|relative394/tmp|-unset" \
         "/tmp/iaeng-ctx-$ID|C:\\x\\..\\y|-unset" \
         "C:\\tmp/iaeng-ctx-$ID|C:\\tmp|-unset" \
         "/tmp/iaeng-ctx-$ID|/a\\..\\b|-unset" \
         "/tmp/iaeng-ctx-$ID|-unset|relative394/fb" \
         "/tmp/iaeng-ctx-$ID|-unset|C:\\x\\..\\y" \
         "/tmp/iaeng-ctx-$ID|-unset|$T/./fb" \
         "$FB/iaeng-ctx-$ID|-unset|$FB" \
         "$FB/iaeng-ctx-$ID|C:\\x\\..\\y|$FB/" \
         "$TMPD/iaeng-ctx-$ID|$TMPD|$FB"; do
  want="${c%%|*}"; rest="${c#*|}"; tmp="${rest%%|*}"; fb="${rest#*|}"
  got="$(named "$tmp" "$fb")"
  if [ "$got" = "$want" ]; then ok "the rule names $want for TMPDIR=[$tmp], fallback=[$fb]"; else bad "the rule names $want for TMPDIR=[$tmp], fallback=[$fb]" "named: [$got]"; fi
done

# =============================================================================
echo "== the user's real context directory (issue #345)"
LEFT="$(real_ctx_changed)"
if [ -z "$LEFT" ]; then ok "no case wrote into the user's real iaeng-ctx directory (/tmp's or TMPDIR's)"; else bad "no case wrote into the user's real iaeng-ctx directory (/tmp's or TMPDIR's)" "added or modified: $(tr '\n' ' ' <<< "$LEFT")"; fi

# =============================================================================
if [ -n "${IAENG_HOOK_TESTS_COUNTS:-}" ]; then
  printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
fi
if [ "$FAILED" -eq 0 ]; then
  printf '   %s checks passed\n' "$TOTAL"
  exit 0
fi
printf '   %s of %s checks failed\n' "$FAILED" "$TOTAL"
exit 1
