#!/usr/bin/env bash
# IA Engineering — hook tests: the context statusLine (WU-IAENG-379)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/context-statusline.sh [--verbose]
#
# What is proved, on real files in a scratch TMPDIR and HOME. The fallback a
# refused TMPDIR takes is scratch too (IAENG_CTX_TEST_FALLBACK, in place of
# /tmp), and the last check is that the user's real iaeng-ctx directory was
# left alone (tests/real-ctx-dir.sh, issue #345):
#
#   - context-statusline.sh exits 0, prints a non-empty line and nothing on
#     stderr for every input: a valid payload, empty stdin, bad JSON, a value
#     that is not an object, ESC / CR / a C1 CSI in the fields, a ../ or
#     otherwise malformed session id, a planted symbolic link (the directory,
#     the .pct file), a .pct that is a directory, a directory others can
#     write in, a read-only or unusable TMPDIR, no jq;
#   - the .pct holds the floor of the percentage and a newline, and is
#     written only where it should be, with no temporary file left behind;
#   - no control character from the payload reaches its own line, and
#     NO_COLOR removes the one colour it prints;
#   - the user's own statusLine (~/.claude or CLAUDE_CONFIG_DIR) is run with
#     the same stdin and its output printed; the exec form; a failing, silent
#     or slow one falls back to the line of its own; one that names this
#     script does not loop; --chain runs the command it is given;
#   - the off switches (IAENG_CONTEXT_HOOKS, .ia-engineering/context-hooks.off)
#     write nothing, create no directory and pass straight through to the
#     user's command (its output and exit status), or print nothing;
#   - without jq the user's statusLine is still run (JSON escapes, exec form);
#     a --chain naming this script falls back to it; the user's command keeps
#     the caller's umask, and every .pct is 0600 under umask 002;
#   - a find that fails skips the write; the cleanup deletes only old *.pct,
#     *.alert and orphan .*.tmp regular files, at most once an hour;
#   - a relative TMPDIR, or one with .., falls back: the .pct is written
#     there, never in the TMPDIR given;
#   - install-hooks.sh installs the statusLine, wraps an adopter's own
#     statusLine instead of replacing it (padding kept, an apostrophe in its
#     command survives, the exec form folded), is idempotent, keeps a
#     PowerShell one as it is and says so, reports a settings.local.json one
#     as shadowed, and --check reports each case; the installed command, run
#     as Claude Code runs it (bash -c), writes the .pct and prints the
#     adopter's line;
#   - the line of its own (WU-IAENG-421, issue #390), each case the exact
#     bytes expected: the context as a percentage and as input tokens out of
#     the window; the weekly quota with its reset time and the time a steady
#     pace reaches 100 %; no 5-hour quota; the branch read from the
#     repository's HEAD, its Work Unit id, a linked worktree, a detached HEAD,
#     a Windows path; colours at the context alert's two steps, NO_COLOR;
#   - .ia-engineering/statusline-own: the line of its own replaces the user's
#     and the --chain command, which are not run; the off switch wins;
#     deleting the file restores the chaining; the user's settings.json is
#     never written. A .pct that already holds the value is not rewritten.
#
# A check that the platform cannot run (a symbolic link Git Bash cannot
# create, a mode Windows does not enforce) is reported as "n/a" with the
# reason and not counted as a pass; CI runs them on Linux.
#
# Exit 0 when every check passes, 1 when any fails, 2 when the environment
# is unusable. With IAENG_HOOK_TESTS_COUNTS set to a file, "<total> <failed>"
# is written there for run.sh.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "context-statusline.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"
SL="$HOOKS/context-statusline.sh"

command -v jq >/dev/null 2>&1 || {
  echo "context-statusline.sh: jq is required and is not installed. Reported rather than skipped." >&2
  exit 2
}
[ -f "$SL" ] || { echo "context-statusline.sh: $SL is missing" >&2; exit 2; }

FAILED=0
TOTAL=0
NA=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0; }
na() { NA=$((NA + 1)); printf '   n/a   %s — %s\n' "$1" "$2"; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-ctx379.XXXXXX")" || { echo "context-statusline.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'chmod -R u+w "$T" 2>/dev/null; cd / && rm -rf "$T"' EXIT

ID="$(id -u 2>/dev/null)"
[ -n "${UID:-}" ] && ID="$UID"
TMPD="$T/tmp"
HOMED="$T/home"
PROJ="$T/project"
# The fallback a refused TMPDIR takes, in place of /tmp (issue #345): every
# run sets IAENG_CTX_TEST_FALLBACK to it, so no case writes into the user's
# real /tmp/iaeng-ctx-<uid>.
FB="$T/fallback"
mkdir -p "$TMPD" "$HOMED/.claude" "$PROJ" "$FB"
DIR="$TMPD/iaeng-ctx-$ID"
FBD="$FB/iaeng-ctx-$ID"
# The user's real context directories, listed before any hook runs and
# checked at the end (tests/real-ctx-dir.sh).
# shellcheck source=real-ctx-dir.sh
. "$HERE/real-ctx-dir.sh"
real_ctx_begin "$T"

# run <stdin> [args...] — runs the statusLine as Claude Code does: stdin, a
# scratch TMPDIR, fallback, HOME and project, none of the switches. Sets OUT,
# ERR, RC.
run() {
  local input="$1"; shift
  printf '%s' "$input" | env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_CHAINED -u CLAUDE_CONFIG_DIR \
    -u NO_COLOR -u IAENG_CTX_ALERT_PCT -u IAENG_CTX_LAST_CALL_PCT \
    TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$HOMED" CLAUDE_PROJECT_DIR="$PROJ" ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
    bash "$SL" "$@" > "$T/out" 2> "$T/err"
  RC=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}
RUN_ENV=()

# fine <label> — exit 0, a non-blank line, nothing on stderr.
fine() {
  case "$OUT" in
    *[![:space:]]*) if [ "$RC" -eq 0 ] && [ -z "$ERR" ]; then ok "$1: exit 0, a line, no stderr"; return; fi ;;
  esac
  bad "$1: exit 0, a line, no stderr" "rc=$RC out=[$OUT] err=[$ERR]"
}
has() { if grep -qF -- "$2" <<< "$OUT"; then ok "$1"; else bad "$1" "output: [$OUT]"; fi; }
pct_is() { if [ -f "$DIR/$2.pct" ] && [ "$(cat "$DIR/$2.pct")" = "$3" ]; then ok "$1"; else bad "$1" "$(find "$DIR" 2>&1 | tr '\n' ' ')"; fi; }
no_pct() { if [ ! -e "$DIR/$2.pct" ]; then ok "$1"; else bad "$1" "$DIR/$2.pct exists"; fi; }
count_files() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }

# A link Git Bash reads as one on Windows needs MSYS=winsymlinks:sys and the
# right to create it; elsewhere the variable is ignored.
can_link() {
  rm -f "$T/probe-link"
  MSYS=winsymlinks:sys ln -s "$T" "$T/probe-link" 2>/dev/null
  [ -L "$T/probe-link" ] && { rm -f "$T/probe-link"; return 0; }
  return 1
}
# The platform enforces a 0555 directory against its owner (not Windows, not root).
mode_enforced() {
  mkdir -p "$T/probe-ro" && chmod 555 "$T/probe-ro"
  if ( : > "$T/probe-ro/x" ) 2>/dev/null; then chmod 755 "$T/probe-ro"; rm -rf "$T/probe-ro"; return 1; fi
  chmod 755 "$T/probe-ro"; rm -rf "$T/probe-ro"; return 0
}

GOOD='{"session_id":"sess-1","model":{"display_name":"Opus 5.5"},"context_window":{"used_percentage":42.7,"total_input_tokens":427000,"context_window_size":1000000,"current_usage":{"input_tokens":5}},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1}}}'
# The line of its own for GOOD: no 5-hour quota (issue #390, the Director's
# scope of 24 Nov 2026), and no weekly one or branch in this payload.
GOOD_LINE="[Opus 5.5] ctx 42% 427k/1M"

# line_is <label> <expected> — exit 0, nothing on stderr, and the line is
# exactly <expected>, escapes included.
line_is() {
  if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ "$OUT" = "$2" ]; then ok "$1"
  else bad "$1" "rc=$RC err=[$ERR] got: $(printf '%s' "$OUT" | od -c | tr -s ' ' | tr '\n' ' ' | head -c 400)"; fi
}

# =============================================================================
echo "== context-statusline.sh — the line and the file"

run "$GOOD"
fine "a valid payload"
line_is "a valid payload: the model and the context, its tokens out of the window; no 5-hour quota" "$GOOD_LINE"
pct_is "a valid payload: <session_id>.pct holds the floor of the percentage" sess-1 42
if [ "$(od -An -c "$DIR/sess-1.pct" 2>/dev/null | tr -d ' ')" = '42\n' ]; then ok "the .pct is the integer and one LF, nothing else"; else bad "the .pct is the integer and one LF, nothing else" "$(od -c "$DIR/sess-1.pct")"; fi
if [ -z "$(find "$DIR" -name '*.tmp' 2>/dev/null)" ]; then ok "no temporary file is left in the directory"; else bad "no temporary file is left in the directory"; fi
if [ -d "$DIR" ] && [ ! -L "$DIR" ] && [ -O "$DIR" ]; then ok "the directory is a directory, owned by the user, not a link"; else bad "the directory is a directory, owned by the user, not a link"; fi
if mode_enforced; then
  # -perm with no prefix matches the mode exactly.
  if [ -n "$(find "$DIR" -prune -perm 700 2>/dev/null)" ]; then ok "the directory is created 0700"; else bad "the directory is created 0700" "find -perm 700 did not match $DIR"; fi
  # Every .pct is 0600 whatever the caller's umask, on a later run too
  # (cr-320 M1: under umask 002 it was 0664, and the reader refuses that).
  UM_SAVED="$(umask)"
  umask 002
  run '{"session_id":"sess-um","context_window":{"used_percentage":3}}'
  run '{"session_id":"sess-um","context_window":{"used_percentage":4}}'
  umask "$UM_SAVED"
  if [ -n "$(find "$DIR/sess-um.pct" -perm 600 2>/dev/null)" ]; then ok "under umask 002 the .pct is 0600"; else bad "under umask 002 the .pct is 0600" "find -perm 600 did not match $DIR/sess-um.pct"; fi
else
  na "the directory is created 0700; the .pct is 0600 under umask 002" "this platform does not enforce modes (Windows or root)"
fi

run '{"session_id":"sess-1","context_window":{"used_percentage":55}}'
pct_is "a second payload replaces the value (rename over the old file)" sess-1 55

run ''
fine "empty stdin"
has "empty stdin: ctx --" "ctx --"
B="$(count_files "$DIR")"
run 'not json {'
fine "bad JSON"
run '["sess-x", 1]'
fine "a JSON array"
run '"sess-x"'
fine "a JSON string"
run '{"session_id":"sess-2","context_window":{"used_percentage":"42"}}'
fine "a percentage given as a string"
no_pct "a percentage given as a string: nothing written" sess-2
run '{"session_id":"sess-3","context_window":{"used_percentage":101}}'
no_pct "a percentage above 100: nothing written" sess-3
run '{"session_id":"sess-4","context_window":{"used_percentage":-3}}'
no_pct "a negative percentage: nothing written" sess-4
run '{"session_id":"sess-5","context_window":{"used_percentage":null}}'
no_pct "a null percentage (early in a session): nothing written" sess-5
has "a null percentage: ctx --" "ctx --"
if [ "$(count_files "$DIR")" = "$B" ]; then ok "empty, bad, array, string and out-of-range payloads wrote no file"; else bad "empty, bad, array, string and out-of-range payloads wrote no file" "$(ls -a "$DIR")"; fi

# --- cleanup: the writer's (Main Agent decision, 26 Oct 2026) -----------------------
# At most once an hour, *.pct and *.alert regular files older than 24 h go,
# and so do the orphan .*.tmp files of the two hooks (issue #345): the
# writer's .<session>.<pid>.<n>.tmp and the alert's .<session>.alert.<pid>.<n>.tmp,
# left by a process killed before its rename. A fresh file (a .tmp among
# them: a write in progress), another name, a directory and a link (and what
# it points at) stay. Oracle: the decision's own terms (24 h, once an hour,
# regular files the user owns, never through a link) and issue #345's.
CL="$T/cleantmp"; CLD="$CL/iaeng-ctx-$ID"; mkdir -p "$CLD"
OLD="$(( $(date +%s) - 172800 ))"
for n in old-a.pct old-b.alert old-other.txt old-other.tmp .sess-gone.4242.17.tmp .sess-gone.alert.4242.18.tmp; do
  : > "$CLD/$n"; touch -d "@$OLD" "$CLD/$n"
done
: > "$CLD/fresh.pct"
: > "$CLD/.sess-busy.4243.19.tmp"
mkdir "$CLD/old-dir.pct" "$CLD/.old-dir.4244.20.tmp"; touch -d "@$OLD" "$CLD/old-dir.pct" "$CLD/.old-dir.4244.20.tmp"
LINKED=0
if can_link; then
  printf 'victim\n' > "$T/victim-cl"
  MSYS=winsymlinks:sys ln -s "$T/victim-cl" "$CLD/old-link.pct" && touch -h -d "@$OLD" "$CLD/old-link.pct" 2>/dev/null
  MSYS=winsymlinks:sys ln -s "$T/victim-cl" "$CLD/.old-link.4245.21.tmp" && touch -h -d "@$OLD" "$CLD/.old-link.4245.21.tmp" 2>/dev/null
  [ -L "$CLD/old-link.pct" ] && [ -L "$CLD/.old-link.4245.21.tmp" ] && LINKED=1
fi
RUN_ENV=(TMPDIR="$CL")
run '{"session_id":"sess-cl","context_window":{"used_percentage":5}}'
RUN_ENV=()
fine "a run that cleans up"
if [ ! -e "$CLD/old-a.pct" ] && [ ! -e "$CLD/old-b.alert" ]; then ok "cleanup: *.pct and *.alert older than 24 h are deleted"; else bad "cleanup: *.pct and *.alert older than 24 h are deleted" "$(find "$CLD" -mindepth 1 | tr '\n' ' ')"; fi
if [ ! -e "$CLD/.sess-gone.4242.17.tmp" ] && [ ! -e "$CLD/.sess-gone.alert.4242.18.tmp" ]; then ok "cleanup: the writer's and the alert's orphan .tmp files older than 24 h are deleted"; else bad "cleanup: the writer's and the alert's orphan .tmp files older than 24 h are deleted" "$(find "$CLD" -mindepth 1 -name '*.tmp' | tr '\n' ' ')"; fi
if [ -f "$CLD/fresh.pct" ] && [ -f "$CLD/old-other.txt" ] && [ -d "$CLD/old-dir.pct" ] && [ -f "$CLD/sess-cl.pct" ]; then ok "cleanup: a fresh .pct, another name and a directory stay"; else bad "cleanup: a fresh .pct, another name and a directory stay" "$(find "$CLD" -mindepth 1 | tr '\n' ' ')"; fi
if [ -f "$CLD/.sess-busy.4243.19.tmp" ] && [ -f "$CLD/old-other.tmp" ] && [ -d "$CLD/.old-dir.4244.20.tmp" ]; then ok "cleanup: a fresh .tmp (a write in progress), an old .tmp not named .*.tmp and a directory named .*.tmp stay"; else bad "cleanup: a fresh .tmp, an old .tmp not named .*.tmp and a directory named .*.tmp stay" "$(find "$CLD" -mindepth 1 | tr '\n' ' ')"; fi
if [ "$LINKED" -eq 1 ]; then
  if [ -L "$CLD/old-link.pct" ] && [ -L "$CLD/.old-link.4245.21.tmp" ] && [ "$(cat "$T/victim-cl")" = victim ]; then ok "cleanup: an old link named *.pct or .*.tmp is neither deleted nor followed"; else bad "cleanup: an old link named *.pct or .*.tmp is neither deleted nor followed"; fi
else
  na "cleanup: an old link named *.pct or .*.tmp" "symbolic links cannot be created here"
fi
: > "$CLD/old-c.pct"; touch -d "@$OLD" "$CLD/old-c.pct"
RUN_ENV=(TMPDIR="$CL")
run '{"session_id":"sess-cl","context_window":{"used_percentage":6}}'
RUN_ENV=()
if [ -e "$CLD/old-c.pct" ]; then ok "cleanup: at most once an hour (a second run within the hour deletes nothing)"; else bad "cleanup: at most once an hour"; fi
printf '%s\n' "$(( $(date +%s) - 3700 ))" > "$CLD/.last-clean"
RUN_ENV=(TMPDIR="$CL")
run '{"session_id":"sess-cl","context_window":{"used_percentage":7}}'
RUN_ENV=()
if [ ! -e "$CLD/old-c.pct" ]; then ok "cleanup: an hour after the last one, it cleans again"; else bad "cleanup: an hour after the last one, it cleans again"; fi

# --- an unchanged value is not rewritten (WU-IAENG-421) ----------------------------
# The line runs on every render. A .pct that already holds the value is left
# as it is, so such a render starts no find and no mv. Seen by the file's
# modification time, set 48 hours back: unchanged when the value is the same
# (33.9 floors to 33), rewritten when it changes. A TMPDIR of its own, so the
# file counts of the main directory below are not moved.
SM="$T/sametmp"; SMF="$SM/iaeng-ctx-$ID/sess-same.pct"; mkdir -p "$SM"
RUN_ENV=(TMPDIR="$SM")
run '{"session_id":"sess-same","context_window":{"used_percentage":33}}'
touch -d "@$OLD" "$SMF"
M0="$(stat -c %Y "$SMF" 2>/dev/null)"
run '{"session_id":"sess-same","context_window":{"used_percentage":33.9}}'
fine "the same value again"
if [ -n "$M0" ] && [ "$(stat -c %Y "$SMF" 2>/dev/null)" = "$M0" ] && [ "$(cat "$SMF")" = 33 ]; then ok "a .pct that already holds the value is not written again"; else bad "a .pct that already holds the value is not written again" "mtime $M0 -> $(stat -c %Y "$SMF" 2>&1)"; fi
run '{"session_id":"sess-same","context_window":{"used_percentage":34}}'
if [ "$(cat "$SMF")" = 34 ] && [ "$(stat -c %Y "$SMF" 2>/dev/null)" != "$M0" ]; then ok "a new value is written"; else bad "a new value is written" "$(cat "$SMF")"; fi
RUN_ENV=()

# --- hostile session ids -------------------------------------------------------
mkdir -p "$T/victim"
for sid in '../../victim/owned' '../x' '..' '.hidden' 'a/b' 'a\\b' '-rf' 'a.b' "$(printf 'a%.0s' $(seq 1 129))" ''; do
  run "$(jq -cn --arg s "$sid" '{session_id:$s, context_window:{used_percentage:7}}')"
  fine "session id [${sid:0:20}]"
done
if [ "$(count_files "$T/victim")" = 0 ] && [ "$(count_files "$DIR")" = "$B" ] && [ ! -e "$TMPD/x.pct" ] && [ ! -e "$T/victim/owned.pct" ]; then
  ok "no hostile session id wrote a file anywhere (../, separators, dots, a leading dash, 129 chars, empty)"
else
  bad "no hostile session id wrote a file anywhere" "$(find "$T/victim" "$TMPD" -type f | tr '\n' ' ')"
fi

# --- control characters --------------------------------------------------------
HOST="$(jq -cn --arg m "$(printf 'Op\033[31mus\r\n\302\233X')" --arg s "$(printf 'sess\033-6')" \
  '{session_id:$s, model:{display_name:$m}, context_window:{used_percentage:12}}')"
run "$HOST"
fine "ESC, CR, LF and a C1 CSI in the fields"
if [ "$(printf '%s' "$OUT" | tr -d '\n' | LC_ALL=C tr -d '[:print:]' | wc -c | tr -d ' ')" = 0 ]; then
  ok "no control character from the payload reaches the line (only printable bytes and the final LF)"
else
  bad "no control character from the payload reaches the line" "$(printf '%s' "$OUT" | od -c | head -3)"
fi
if [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = 1 ]; then ok "a CR or LF in a field does not split the line"; else bad "a CR or LF in a field does not split the line" "$OUT"; fi
# Oracle: the record sanitiser rule (WU-IAENG-366, Adapters/scripts/tests/run.sh
# FLAT_366): each control character, and each C1 pair, becomes one space. The
# payload has no 5 h quota, so the model must not move into its place.
if [ "$OUT" = "[Op [31mus   X] ctx 12%" ]; then ok "the model name is shown with each control replaced by one space, no quota present"; else bad "the model name is shown with each control replaced by one space, no quota present" "$(printf '%s' "$OUT" | od -c | head -3)"; fi
no_pct "a session id holding ESC is refused: nothing written" "$(printf 'sess\033-6')"
run "$(jq -cn --arg p "$(printf '4\0332')" '{session_id:"sess-7", context_window:{used_percentage:$p}}')"
no_pct "a percentage holding ESC is refused" sess-7

# --- NO_COLOR ------------------------------------------------------------------------
RUN_ENV=(IAENG_CTX_ALERT_PCT=40)
run "$GOOD"
if [[ $OUT == *$'\033['* ]]; then ok "at or above IAENG_CTX_ALERT_PCT, the ctx part is coloured"; else bad "at or above IAENG_CTX_ALERT_PCT, the ctx part is coloured" "$OUT"; fi
RUN_ENV=(IAENG_CTX_ALERT_PCT=40 NO_COLOR=1)
run "$GOOD"
if [[ $OUT != *$'\033'* ]] && [[ $OUT == *"ctx 42%"* ]]; then ok "NO_COLOR: no escape sequence at all"; else bad "NO_COLOR: no escape sequence at all" "$(printf '%s' "$OUT" | od -c | head -2)"; fi
RUN_ENV=()

# =============================================================================
echo "== context-statusline.sh — the line of its own (WU-IAENG-421, issue #390)"
# Oracles: the Director's scope of 24 Nov 2026 for issue #390, written out
# here by hand. The model; the context as a percentage, then the input tokens
# in the window out of its size (total_input_tokens and context_window_size,
# the statusline page's field table); the weekly quota (seven_day) as a
# percentage, its reset time, and when a steady pace reaches 100 %; the
# branch, and the Work Unit id its name carries. No 5-hour quota. Colours at
# the context alert's two steps: yellow from the alert, bold red and a "!"
# from the last call (60 and 70 by default; IAENG_CTX_ALERT_PCT and
# IAENG_CTX_LAST_CALL_PCT as context-alert.sh reads them).
Y=$'\033[33m'; R=$'\033[1;31m'; Z=$'\033[0m'
# ctxp <pct> <used> <size> — a payload with the context fields only.
ctxp() { jq -cn --argjson p "$1" --argjson u "$2" --argjson s "$3" '{session_id:"sess-421", context_window:{used_percentage:$p, total_input_tokens:$u, context_window_size:$s}}'; }

run "$(ctxp 42.7 427000 1000000)"
line_is "ctx: the floor of the percentage, then the input tokens out of the window" "ctx 42% 427k/1M"
run "$(ctxp 7.9 15500 200000)"
line_is "ctx: a 200k window, thousands floored" "ctx 7% 15k/200k"
run "$(ctxp 0 999 200000)"
line_is "ctx: under a thousand tokens, the count itself" "ctx 0% 999/200k"
run "$(ctxp 37 750000 2000000)"
line_is "ctx: a 2M window" "ctx 37% 750k/2M"
run "$(ctxp 50 1250000 2500000)"
line_is "ctx: millions with one decimal, floored" "ctx 50% 1.2M/2.5M"
run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:42}}')"
line_is "ctx: no token counts, the percentage alone" "ctx 42%"
run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:42, total_input_tokens:"427000", context_window_size:1000000}}')"
line_is "ctx: a token count given as a string is dropped" "ctx 42%"
run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:42, total_input_tokens:427000, context_window_size:0}}')"
line_is "ctx: a window of 0 tokens is dropped" "ctx 42%"
run "$(ctxp null 0 200000)"
line_is "ctx: no percentage yet (before the first response)" "ctx --"

# tier_case <pct> <expected> [VAR=value...] — the context at <pct> % of a 1M
# window, under the given environment.
tier_case() {
  local p="$1" want="$2"; shift 2
  RUN_ENV=("$@")
  run "$(ctxp "$p" "$((p * 10000))" 1000000)"
  RUN_ENV=()
  line_is "colour at $p % (${*:-the default steps 60 and 70})" "$want"
}
tier_case 59 "ctx 59% 590k/1M"
tier_case 60 "ctx ${Y}60% 600k/1M${Z}"
tier_case 69 "ctx ${Y}69% 690k/1M${Z}"
tier_case 70 "ctx ${R}70%! 700k/1M${Z}"
tier_case 100 "ctx ${R}100%! 1M/1M${Z}"
tier_case 39 "ctx 39% 390k/1M" IAENG_CTX_ALERT_PCT=40
tier_case 40 "ctx ${Y}40% 400k/1M${Z}" IAENG_CTX_ALERT_PCT=40
tier_case 49 "ctx ${Y}49% 490k/1M${Z}" IAENG_CTX_ALERT_PCT=40
tier_case 50 "ctx ${R}50%! 500k/1M${Z}" IAENG_CTX_ALERT_PCT=40
tier_case 44 "ctx ${Y}44% 440k/1M${Z}" IAENG_CTX_ALERT_PCT=40 IAENG_CTX_LAST_CALL_PCT=45
tier_case 45 "ctx ${R}45%! 450k/1M${Z}" IAENG_CTX_ALERT_PCT=40 IAENG_CTX_LAST_CALL_PCT=45
tier_case 59 "ctx 59% 590k/1M" IAENG_CTX_ALERT_PCT=abc
tier_case 60 "ctx ${Y}60% 600k/1M${Z}" IAENG_CTX_ALERT_PCT=abc
tier_case 100 "ctx ${Y}100% 1M/1M${Z}" IAENG_CTX_ALERT_PCT=95
tier_case 75 "ctx 75%! 750k/1M" NO_COLOR=1

# --- the weekly quota ------------------------------------------------------------
# Times in UTC (TZ=UTC0 for the script; the expected text from date -u, a
# process the script never starts). The window is the 7 days before
# resets_at. A steady pace reaches 100 % at the window's start plus the time
# elapsed times 100 over the percentage used; worked by hand for each case
# below. The script reads its clock a moment after the test, so the cap may
# move by a few seconds: every second from before the run to after it is
# accepted.
# wkp <used> <resets_at> — the context, the weekly window, and a 5-hour window
# that must not show.
wkp() { jq -cn --argjson u "$1" --argjson r "$2" '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, rate_limits:{five_hour:{used_percentage:55, resets_at:$r}, seven_day:{used_percentage:$u, resets_at:$r}}}'; }
utc() { date -u -d "@$1" '+%a %H:%M'; }
W="ctx 10% 100k/1M"
# wk_run <used> <reset offset from now, s> — runs it at TZ=UTC0; sets T0, T1, RS.
wk_run() {
  T0="$(date +%s)"; RS=$((T0 + $2))
  RUN_ENV=(TZ=UTC0); run "$(wkp "$1" "$RS")"; RUN_ENV=()
  T1="$(date +%s)"
}
# cap_is <label> <text before the cap time> <used %> <cap at T0, in s after T0>
# — the line is <text><cap time>) for the script's clock at some second from
# T0 to T1 + 1. The cap for a clock t: the window's start plus (t - start) x
# 100 / used. The hand-worked value at T0 is checked against it first, so a
# mistaken oracle fails here rather than passing a wrong line.
cap_is() {
  local label="$1" pre="$2" used="$3" at="$4" t c s=$((RS - 604800)) hit=0 want=""
  if [ $((s + (T0 - s) * 100 / used)) -ne $((T0 + at)) ]; then
    bad "$label" "the oracle's own arithmetic disagrees with the hand-worked $at s"; return
  fi
  for ((t = T0; t <= T1 + 1; t++)); do
    c=$((s + (t - s) * 100 / used))
    want="$pre$(utc "$c"))"
    [ "$OUT" = "$want" ] && hit=1
  done
  if [ "$hit" -eq 1 ] && [ "$RC" -eq 0 ] && [ -z "$ERR" ]; then ok "$label"; else bad "$label" "got [$OUT], last tried [$want]"; fi
}

wk_run 41.2 $((3 * 86400))
# 4 of 7 days gone and 41 % used: 100 % comes after 9.8 days, past the reset.
line_is "wk: below the pace, the reset and no cap; the 5-hour quota is not shown" "$W | wk 41% (reset $(utc "$RS"), no cap)"
wk_run 80 $((5 * 86400))
# 2 days gone and 80 % used: 100 % at 2.5 days, half a day from now, 43,200 s.
# A cap before the reset is red with a "!".
cap_is "wk: a cap before the reset, its time, red" "$W | wk ${R}80%!${Z} (reset $(utc "$RS"), cap ~" 80 43200
wk_run 30 $((6 * 86400))
# 1 day gone and 30 % used: 100 % at 3 1/3 days, 2 1/3 days from now,
# 201,600 s. Red, although 30 % is under the alert.
cap_is "wk: a cap before the reset at 30 %, red although under the alert" "$W | wk ${R}30%!${Z} (reset $(utc "$RS"), cap ~" 30 201600
wk_run 100 $((2 * 86400))
line_is "wk: at 100 %, capped" "$W | wk ${R}100%!${Z} (reset $(utc "$RS"), capped)"
wk_run 0 $((2 * 86400))
line_is "wk: at 0 %, no cap" "$W | wk 0% (reset $(utc "$RS"), no cap)"
wk_run 65 3600
# An hour before the reset at 65 %: no cap, yellow from the alert's 60.
line_is "wk: at the alert's 60 to 69 %, yellow" "$W | wk ${Y}65%${Z} (reset $(utc "$RS"), no cap)"
wk_run 72 3600
line_is "wk: from the last call's 70 %, red" "$W | wk ${R}72%!${Z} (reset $(utc "$RS"), no cap)"
T0="$(date +%s)"
RUN_ENV=(TZ=UTC0 IAENG_CTX_ALERT_PCT=40); run "$(wkp 45 $((T0 + 3 * 86400)))"; RUN_ENV=()
line_is "wk: the thresholds follow IAENG_CTX_ALERT_PCT, as the context's do" "$W | wk ${Y}45%${Z} (reset $(utc $((T0 + 3 * 86400))), no cap)"
RUN_ENV=(TZ=UTC0); run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, rate_limits:{seven_day:{used_percentage:41}}}')"; RUN_ENV=()
line_is "wk: no resets_at, the percentage alone" "$W | wk 41%"
RUN_ENV=(TZ=UTC0); run "$(wkp 41 $(($(date +%s) - 60)))"; RUN_ENV=()
line_is "wk: a reset already past, the percentage alone" "$W | wk 41%"
RUN_ENV=(TZ=UTC0); run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, rate_limits:{seven_day:{used_percentage:41, resets_at:"soon"}}}')"; RUN_ENV=()
line_is "wk: a resets_at given as a string, the percentage alone" "$W | wk 41%"
RUN_ENV=(TZ=UTC0); run "$(jq -cn '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, rate_limits:{five_hour:{used_percentage:99, resets_at:9999999999}}}')"; RUN_ENV=()
line_is "wk: a 5-hour window alone shows nothing" "$W"

# --- the branch and its Work Unit -------------------------------------------------
# Read from the repository's HEAD, found by walking up from the payload's
# workspace.current_dir (or cwd). Fake repositories: a .git directory, or a
# .git file naming the git directory, as a linked worktree has.
RP="$T/repos"
# mkhead <dir holding HEAD> <content>
mkhead() { mkdir -p "$1"; printf '%s' "$2" > "$1/HEAD"; }
# bp <current_dir> — the context and the working directory.
bp() { jq -cn --arg d "$1" '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, workspace:{current_dir:$d}}'; }
mkhead "$RP/a/.git" $'ref: refs/heads/feat/x-wu-421-usage\n'
mkdir -p "$RP/a/sub/deep"
run "$(bp "$RP/a/sub/deep")"
line_is "branch: from the repository above the working directory, its Work Unit first" "$W | WU-421 feat/x-wu-421-usage"
run "$(jq -cn --arg d "$RP/a" '{session_id:"sess-421", context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}, cwd:$d}')"
line_is "branch: cwd when there is no workspace.current_dir" "$W | WU-421 feat/x-wu-421-usage"
mkhead "$RP/b/.git" $'0123abcd0123abcd0123abcd0123abcd0123abcd\n'
run "$(bp "$RP/b")"
line_is "branch: a detached HEAD, its short commit" "$W | @0123abc"
mkhead "$RP/gd/wt1" $'ref: refs/heads/fix/y-wu-7\n'
mkdir -p "$RP/c"; printf 'gitdir: %s\n' "$RP/gd/wt1" > "$RP/c/.git"
run "$(bp "$RP/c")"
line_is "branch: a linked worktree's .git file, an absolute gitdir" "$W | WU-7 fix/y-wu-7"
mkhead "$RP/gd/wt2" $'ref: refs/heads/main\r\n'
mkdir -p "$RP/d"; printf 'gitdir: ../gd/wt2\r\n' > "$RP/d/.git"
run "$(bp "$RP/d")"
line_is "branch: a relative gitdir, CRLF line ends" "$W | main"
# <branch>|<segment expected>
for c in "develop|develop" "feat/wu-iaeng-12-x|WU-IAENG-12 feat/wu-iaeng-12-x" "WU-IAENG-12-x|WU-IAENG-12 WU-IAENG-12-x" \
         "wu433-merge|WU-433 wu433-merge" "perf/wu-444-edit|WU-444 perf/wu-444-edit" "menu-12|menu-12" \
         "fix/wu-escape-guard|fix/wu-escape-guard" "fix/swu-12|fix/swu-12"; do
  mkhead "$RP/e/.git" "ref: refs/heads/${c%%|*}"
  run "$(bp "$RP/e")"
  line_is "branch [${c%%|*}]: the Work Unit id only when the name carries one" "$W | ${c#*|}"
done
mkhead "$RP/e/.git" "ref: refs/heads/feat/$(printf 'a%.0s' $(seq 1 60))"
run "$(bp "$RP/e")"
line_is "branch: a long name is cut to 48 characters" "$W | feat/$(printf 'a%.0s' $(seq 1 40))..."
mkhead "$RP/e/.git" $'ref: refs/heads/a\033[31mb\302\233c\n'
run "$(bp "$RP/e")"
line_is "branch: a control character in HEAD becomes a space" "$W | a [31mb c"
rm -f "$RP/e/.git/HEAD"; mkdir -p "$RP/e/.git/HEAD"
run "$(bp "$RP/e")"
line_is "branch: a HEAD that is a directory, no branch" "$W"
mkdir -p "$RP/f"; printf 'not a gitdir line\n' > "$RP/f/.git"
run "$(bp "$RP/f")"
line_is "branch: a .git file without a gitdir, no branch" "$W"
mkdir -p "$RP/none/x"
up="$RP/none/x"; above=0
while :; do [ -e "$up/.git" ] && above=1; [ "$up" = "${up%/*}" ] && break; up="${up%/*}"; done
if [ "$above" -eq 0 ]; then
  run "$(bp "$RP/none/x")"
  line_is "branch: no repository above the working directory, no branch" "$W"
else
  na "branch: no repository above the working directory" "the scratch directory is inside a repository here"
fi
if command -v cygpath >/dev/null 2>&1; then
  run "$(bp "$(cygpath -w "$RP/a/sub")")"
  line_is "branch: a Windows working directory (backslashes)" "$W | WU-421 feat/x-wu-421-usage"
else
  na "branch: a Windows working directory" "no Windows paths on this platform (no cygpath)"
fi

# --- planted links and other files ------------------------------------------------
echo "== context-statusline.sh — planted links, modes, read-only TMP"
if can_link; then
  printf 'victim\n' > "$T/victim/target"
  MSYS=winsymlinks:sys ln -s "$T/victim/target" "$DIR/sess-link.pct"
  run '{"session_id":"sess-link","context_window":{"used_percentage":9}}'
  fine "a planted link at <session_id>.pct"
  if [ "$(cat "$T/victim/target")" = victim ] && [ -L "$DIR/sess-link.pct" ]; then ok "a planted link at <session_id>.pct: neither followed nor replaced"; else bad "a planted link at <session_id>.pct: neither followed nor replaced" "$(cat "$T/victim/target")"; fi

  LT="$T/linktmp"; mkdir -p "$LT" "$T/elsewhere"
  MSYS=winsymlinks:sys ln -s "$T/elsewhere" "$LT/iaeng-ctx-$ID"
  RUN_ENV=(TMPDIR="$LT")
  run '{"session_id":"sess-dl","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "a planted link in place of the directory"
  if [ "$(count_files "$T/elsewhere")" = 0 ]; then ok "a planted link in place of the directory: nothing written through it"; else bad "a planted link in place of the directory: nothing written through it" "$(ls -a "$T/elsewhere")"; fi
else
  na "planted links (<session_id>.pct and the directory)" "symbolic links cannot be created here (Git Bash without the right to create them)"
fi

# A find that fails cannot say the directory is safe (SEC-IAENG-379-02): the
# write is skipped, the earlier value stays.
FF="$T/failfind"; mkdir -p "$FF"
printf '#!%s\nexit 2\n' "$(command -v bash)" > "$FF/find"; chmod +x "$FF/find"
run '{"session_id":"sess-ff","context_window":{"used_percentage":11}}'
RUN_ENV=(PATH="$FF:$PATH")
run '{"session_id":"sess-ff","context_window":{"used_percentage":77}}'
RUN_ENV=()
fine "find fails"
pct_is "a find that fails: the write is skipped, the earlier value stays" sess-ff 11

mkdir -p "$DIR/sess-dir.pct"
run '{"session_id":"sess-dir","context_window":{"used_percentage":9}}'
fine "a directory in place of <session_id>.pct"
if [ -d "$DIR/sess-dir.pct" ] && [ "$(count_files "$DIR/sess-dir.pct")" = 0 ]; then ok "a directory in place of <session_id>.pct: nothing moved into it"; else bad "a directory in place of <session_id>.pct: nothing moved into it"; fi

if mode_enforced; then
  OW="$T/openwrite"; mkdir -p "$OW/iaeng-ctx-$ID"; chmod 777 "$OW/iaeng-ctx-$ID"
  RUN_ENV=(TMPDIR="$OW")
  run '{"session_id":"sess-ow","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "a directory others can write in"
  if [ ! -e "$OW/iaeng-ctx-$ID/sess-ow.pct" ]; then ok "a directory others can write in: not used"; else bad "a directory others can write in: not used"; fi

  RO="$T/readonly"; mkdir -p "$RO"; chmod 555 "$RO"
  RUN_ENV=(TMPDIR="$RO")
  run '{"session_id":"sess-ro","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "a read-only TMPDIR (0555)"
  if [ -z "$(find "$RO" -mindepth 1 2>/dev/null)" ]; then ok "a read-only TMPDIR: nothing created"; else bad "a read-only TMPDIR: nothing created"; fi
  chmod 755 "$RO"
else
  na "a directory others can write in; a 0555 TMPDIR" "this platform does not enforce modes (Windows or root)"
fi

: > "$T/a-file"
# "$T/tmp/../dotdot" names a directory that exists: only the .. rule keeps
# the script from writing there.
mkdir -p "$T/dotdot"
# A relative TMPDIR or one with .. falls back: to /tmp for the user, to the
# scratch fallback here, so the write is seen and the user's real directory
# is never touched (issue #345). A file or a missing directory is absolute:
# nothing can be created there, and nothing is written anywhere.
# <where the .pct must go>|<TMPDIR>
for c in "none|$T/a-file" "none|$T/no/such/dir" "fallback|relative/tmp" "fallback|$T/tmp/../dotdot"; do
  tmp="${c#*|}"
  RUN_ENV=(TMPDIR="$tmp")
  rm -f "$FBD/sess-refused.pct"
  run '{"session_id":"sess-refused","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "TMPDIR=$tmp"
  if [ "${c%%|*}" = fallback ]; then
    if [ -f "$FBD/sess-refused.pct" ]; then ok "TMPDIR=$tmp is refused: the .pct goes to the fallback"; else bad "TMPDIR=$tmp is refused: the .pct goes to the fallback" "$(find "$FB" "$T/dotdot" 2>&1 | tr '\n' ' ')"; fi
  elif [ ! -e "$FBD/sess-refused.pct" ]; then
    ok "TMPDIR=$tmp cannot be used: no .pct, not even in the fallback"
  else
    bad "TMPDIR=$tmp cannot be used: no .pct, not even in the fallback"
  fi
done
if [ -f "$T/a-file" ] && [ ! -s "$T/a-file" ] && [ ! -e "$T/no" ] && [ ! -e "relative" ] && [ -z "$(ls -A "$T/dotdot")" ]; then ok "a TMPDIR that is a file, missing, relative or with .. is never written to"; else bad "a TMPDIR that is a file, missing, relative or with .. is never written to" "$(ls -A "$T/dotdot")"; fi
# The same rule with Windows separators (cr-321 s1): C:\...\tmp\..\dotdot2
# names a directory that exists.
if command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$T/dotdot2"
  rm -f "$FBD/sess-refused.pct"
  RUN_ENV=(TMPDIR="$(cygpath -w "$T/tmp")\\..\\dotdot2")
  run '{"session_id":"sess-refused","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "TMPDIR with a \\..\\ component"
  if [ -z "$(ls -A "$T/dotdot2")" ] && [ -f "$FBD/sess-refused.pct" ]; then ok "a TMPDIR with a backslash .. component is never written to: the .pct goes to the fallback"; else bad "a TMPDIR with a backslash .. component is never written to: the .pct goes to the fallback" "$(ls -A "$T/dotdot2" "$FBD" 2>&1)"; fi
else
  na "a TMPDIR with a backslash .. component" "no Windows paths on this platform (no cygpath)"
fi

# --- no jq ------------------------------------------------------------------------
# A PATH that has every tool the script uses but jq.
NOJQ="$T/nojq-bin"; mkdir -p "$NOJQ"
for tool in find mv mkdir head timeout cat rm bash; do
  p="$(command -v "$tool" 2>/dev/null)" || continue
  printf '#!%s\nexec "%s" "$@"\n' "$(command -v bash)" "$p" > "$NOJQ/$tool"
  chmod +x "$NOJQ/$tool"
done
BASH_BIN="$(command -v bash)"
# The same line as with jq: model, context and its tokens (the top-level
# keys, not current_usage's), the weekly quota and the branch; no 5-hour
# quota. The working directory is JSON-escaped, as a Windows path is.
NJR="$(( $(date +%s) + 3 * 86400 ))"
jq -cn --arg d "$RP/a/sub" --argjson r "$NJR" '{session_id:"sess-nojq", model:{display_name:"Opus 5.5"}, workspace:{current_dir:$d},
  context_window:{current_usage:{used_percentage:99, total_input_tokens:5}, used_percentage:61.9, total_input_tokens:619000, context_window_size:1000000},
  rate_limits:{five_hour:{used_percentage:8, resets_at:$r}, seven_day:{used_percentage:12, resets_at:$r}}}' > "$T/nojq.json"
env -i PATH="$NOJQ" TZ=UTC0 TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$HOMED" CLAUDE_PROJECT_DIR="$PROJ" NO_COLOR=1 "$BASH_BIN" "$SL" < "$T/nojq.json" > "$T/out" 2> "$T/err"
RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
fine "no jq"
line_is "no jq: the same line, model, ctx and tokens, weekly quota, branch" "[Opus 5.5] ctx 61% 619k/1M | wk 12% (reset $(utc "$NJR"), no cap) | WU-421 feat/x-wu-421-usage"
pct_is "no jq: the .pct is written from the top-level used_percentage, not current_usage's" sess-nojq 61
if command -v cygpath >/dev/null 2>&1; then
  jq -cn --arg d "$(cygpath -w "$RP/a/sub")" '{session_id:"sess-nojq", workspace:{current_dir:$d}, context_window:{used_percentage:10, total_input_tokens:100000, context_window_size:1000000}}' \
    | env -i PATH="$NOJQ" TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$HOMED" CLAUDE_PROJECT_DIR="$PROJ" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
  line_is "no jq: a Windows working directory, its backslashes JSON-escaped" "$W | WU-421 feat/x-wu-421-usage"
else
  na "no jq: a Windows working directory" "no Windows paths on this platform (no cygpath)"
fi
printf '%s' 'garbage {"session_id": "x' | env -i PATH="$NOJQ" TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$HOMED" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
fine "no jq, bad JSON"

# No jq, and the user has a statusLine (cr-321 M2): it is still run, read by
# pattern. Written by hand, with the JSON escapes \" and \\ in the command.
NJH="$T/home-nojq"; mkdir -p "$NJH/.claude"
nojq_run() {
  printf '%s' "$GOOD" | env -i PATH="$NOJQ" TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$NJH" CLAUDE_PROJECT_DIR="$PROJ" "$@" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
}
printf '%s\n' '{"model": "opus", "statusLine": {"type": "command", "command": "printf \"%s|%s\" A \"B\\\\C\""}}' > "$NJH/.claude/settings.json"
nojq_run
fine "no jq, a user statusLine"
if [ "$OUT" = 'A|B\C' ]; then ok "no jq: the user statusLine is run, its JSON escapes decoded"; else bad "no jq: the user statusLine is run, its JSON escapes decoded" "[$OUT]"; fi
printf '%s\n' '{"statusLine": {"type": "command", "command": "printf", "args": ["%s+%s", "x y", "it'"'"'s"]}}' > "$NJH/.claude/settings.json"
nojq_run
if [ "$OUT" = "x y+it's" ]; then ok "no jq: a user statusLine in exec form is run with its argv"; else bad "no jq: a user statusLine in exec form is run with its argv" "[$OUT]"; fi
nojq_run IAENG_CONTEXT_HOOKS=off
if [ "$OUT" = "x y+it's" ]; then ok "no jq, switched off: the user statusLine still shows"; else bad "no jq, switched off: the user statusLine still shows" "[$OUT]"; fi

# =============================================================================
echo "== context-statusline.sh — the user's own status line"
US="$HOMED/.claude/settings.json"
jq -n --arg c "jq -r '\"USER \" + .session_id' | tr -d '\\r'" '{statusLine:{type:"command", command:$c}}' > "$US"
run "$GOOD"
fine "a user statusLine"
if [ "$OUT" = "USER sess-1" ]; then ok "a user statusLine: its output is printed, read from the same stdin"; else bad "a user statusLine: its output is printed, read from the same stdin" "$OUT"; fi
pct_is "a user statusLine: the .pct is still written" sess-1 42

printf '\033[32mgreen\033[0m' > "$T/green"
jq -n --arg f "$T/green" '{statusLine:{type:"command", command:("cat \"" + $f + "\"")}}' > "$US"
run "$GOOD"
if [ "$OUT" = $'\033[32mgreen\033[0m' ]; then ok "a user statusLine: its colours are passed through unchanged"; else bad "a user statusLine: its colours are passed through unchanged" "$(printf '%s' "$OUT" | od -c | head -2)"; fi

jq -n '{statusLine:{type:"command", command:"printf", args:["%s-%s", "exec", "it'"'"'s"]}}' > "$US"
run "$GOOD"
if [ "$OUT" = "exec-it's" ]; then ok "a user statusLine in exec form (args), an apostrophe included"; else bad "a user statusLine in exec form (args), an apostrophe included" "$OUT"; fi

jq -n '{statusLine:{type:"command", command:"echo partial; exit 3"}}' > "$US"
run "$GOOD"
fine "a failing user statusLine"
has "a failing user statusLine: the line of its own instead (Claude Code would show nothing)" "ctx 42%"

jq -n '{statusLine:{type:"command", command:"cat >/dev/null"}}' > "$US"
run "$GOOD"
has "a silent user statusLine: the line of its own" "ctx 42%"

if command -v timeout >/dev/null 2>&1; then
  # The bound is loose on purpose (a loaded Windows machine starts processes
  # slowly); without the timeout the run would last 60 s. The command execs
  # sleep, so the process timeout signals is the one holding the pipe: under
  # load on Git Bash a grandchild may outlive the signal (hooks/README.md,
  # Context Status Line).
  jq -n '{statusLine:{type:"command", command:"exec sleep 60"}}' > "$US"
  RUN_ENV=(IAENG_CTX_CHAIN_TIMEOUT=1)
  S0=$SECONDS
  run "$GOOD"
  RUN_ENV=()
  fine "a user statusLine slower than IAENG_CTX_CHAIN_TIMEOUT"
  # On Git Bash under heavy load the signal can arrive late, even to the
  # direct child (seen at 76-88 s with twelve suites running at once): there
  # an overrun is reported n/a with its time, never counted as a pass. Linux,
  # where CI runs, enforces it.
  if [ $((SECONDS - S0)) -lt 40 ] && [[ $OUT == *"ctx 42%"* ]]; then
    ok "a slow user statusLine is cut at the timeout and the line of its own printed"
  elif case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) true ;; *) false ;; esac; then
    na "a slow user statusLine is cut at the timeout" "Git Bash: the timeout signal arrived late ($((SECONDS - S0)) s); enforced on Linux"
  else
    bad "a slow user statusLine is cut at the timeout" "$((SECONDS - S0)) s, out=[$OUT]"
  fi
else
  na "a slow user statusLine is cut" "no timeout command on this platform"
fi

jq -n --arg c "bash \"$SL\"" '{statusLine:{type:"command", command:$c}}' > "$US"
run "$GOOD"
fine "a user statusLine that is this script (no loop)"
has "a user statusLine that is this script: the line of its own" "ctx 42%"

mkdir -p "$T/config"
jq -n '{statusLine:{type:"command", command:"echo FROM-CONFIG-DIR"}}' > "$T/config/settings.json"
RUN_ENV=(CLAUDE_CONFIG_DIR="$T/config")
run "$GOOD"
RUN_ENV=()
if [ "$OUT" = FROM-CONFIG-DIR ]; then ok "CLAUDE_CONFIG_DIR: the user statusLine is read there"; else bad "CLAUDE_CONFIG_DIR: the user statusLine is read there" "$OUT"; fi

jq -n '{statusLine:{type:"command", command:"echo USER-LINE"}}' > "$US"
run "$GOOD" --chain "echo 'PROJECT-LINE'"
if [ "$OUT" = PROJECT-LINE ]; then ok "--chain: the wrapped project command runs, not the user one"; else bad "--chain: the wrapped project command runs, not the user one" "$OUT"; fi
# A --chain that is this script at an earlier path (cr-321 m2): not run (no
# loop), and the user's own line is shown instead of being lost.
run "$GOOD" --chain 'bash "/old/place/hooks/context-statusline.sh"'
if [ "$OUT" = USER-LINE ]; then ok "--chain naming this script falls back to the user statusLine"; else bad "--chain naming this script falls back to the user statusLine" "$OUT"; fi

# The user's command runs with the umask this script was given (cr-321 m3),
# also on the run that creates the directory.
jq -n '{statusLine:{type:"command", command:"umask"}}' > "$US"
rm -rf "$DIR"
UM_SAVED="$(umask)"
umask 022
run "$GOOD"
umask "$UM_SAVED"
if [ -d "$DIR" ] && [ "$OUT" = 0022 ]; then ok "the user command keeps the caller's umask, on the run that creates the directory"; else bad "the user command keeps the caller's umask" "[$OUT]"; fi

echo '{ not json' > "$US"
run "$GOOD"
fine "an unreadable user settings.json"
has "an unreadable user settings.json: the line of its own" "ctx 42%"
rm -f "$US"

# --- the off switches -----------------------------------------------------------
jq -n '{statusLine:{type:"command", command:"echo USER-LINE"}}' > "$US"
rm -rf "$DIR"
RUN_ENV=(IAENG_CONTEXT_HOOKS=off)
run "$GOOD"
RUN_ENV=()
if [ "$OUT" = USER-LINE ] && [ ! -e "$DIR/sess-1.pct" ]; then ok "IAENG_CONTEXT_HOOKS=off: nothing written, the user line shown"; else bad "IAENG_CONTEXT_HOOKS=off: nothing written, the user line shown" "$OUT"; fi
mkdir -p "$PROJ/.ia-engineering" && : > "$PROJ/.ia-engineering/context-hooks.off"
run "$GOOD"
if [ "$OUT" = USER-LINE ] && [ ! -e "$DIR/sess-1.pct" ]; then ok ".ia-engineering/context-hooks.off: nothing written, the user line shown"; else bad ".ia-engineering/context-hooks.off: nothing written, the user line shown" "$OUT"; fi
# Switched off, nothing of the script's own stays (AC5): no directory, no
# line of its own; the user's command decides output and exit status.
if [ ! -e "$DIR" ]; then ok "switched off: not even the directory is created"; else bad "switched off: not even the directory is created"; fi
jq -n '{statusLine:{type:"command", command:"echo partial; exit 3"}}' > "$US"
run "$GOOD"
if [ "$OUT" = partial ] && [ "$RC" -eq 3 ]; then ok "switched off: a failing user statusLine passes through as it is (output and exit status)"; else bad "switched off: a failing user statusLine passes through as it is" "rc=$RC [$OUT]"; fi
rm -f "$US"
run "$GOOD"
if [ -z "$OUT" ] && [ "$RC" -eq 0 ] && [ ! -e "$DIR" ]; then ok "switched off, no user statusLine: nothing printed, as before install"; else bad "switched off, no user statusLine: nothing printed, as before install" "rc=$RC [$OUT]"; fi
rm -f "$PROJ/.ia-engineering/context-hooks.off" "$US"

# --- a line of its own in this project (WU-IAENG-421) ------------------------------
# Oracle: the Director's decision for issue #390. With the file
# .ia-engineering/statusline-own in the project, the script prints its own
# line instead of the chained one: neither the user's statusLine nor a
# --chain command is run (each would leave a marker file). Deleting the file
# restores the chaining. The off switch wins over it. ~/.claude/settings.json
# is never written.
OWNF="$PROJ/.ia-engineering/statusline-own"
MARK421="$T/user-ran"
mkdir -p "$PROJ/.ia-engineering"
jq -n --arg m "$MARK421" '{statusLine:{type:"command", command:("touch \"" + $m + "\"; echo USER-LINE")}}' > "$US"
cp "$US" "$T/us.before"
: > "$OWNF"
rm -f "$MARK421" "$DIR/sess-1.pct"
run "$GOOD"
line_is "statusline-own: the line of its own in place of the user's" "$GOOD_LINE"
if [ ! -e "$MARK421" ]; then ok "statusline-own: the user's statusLine command is not run"; else bad "statusline-own: the user's statusLine command is not run"; fi
pct_is "statusline-own: the .pct is still written for the context alert" sess-1 42
run "$GOOD" --chain "touch '$MARK421'; echo PROJECT-LINE"
line_is "statusline-own: a --chain command gives way too" "$GOOD_LINE"
if [ ! -e "$MARK421" ]; then ok "statusline-own: the --chain command is not run"; else bad "statusline-own: the --chain command is not run"; fi
RUN_ENV=(IAENG_CONTEXT_HOOKS=off)
run "$GOOD"
RUN_ENV=()
if [ "$OUT" = USER-LINE ]; then ok "statusline-own and the off switch: the off switch wins, the user's line passes through"; else bad "statusline-own and the off switch: the off switch wins" "[$OUT]"; fi
rm -f "$OWNF" "$MARK421"
run "$GOOD"
if [ "$OUT" = USER-LINE ] && [ -e "$MARK421" ]; then ok "statusline-own deleted: the user's line is chained again"; else bad "statusline-own deleted: the user's line is chained again" "[$OUT]"; fi
if cmp -s "$US" "$T/us.before"; then ok "the user's settings.json is never written"; else bad "the user's settings.json is never written"; fi
rm -f "$US" "$MARK421"

# =============================================================================
echo "== install-hooks.sh — the statusLine"
IP="$T/hooks-project"
IFW="$IP/ia-engineering/Adapters/ai-runtimes/claude-code"
mkdir -p "$IFW/hooks"
cp -p "$CC/install-hooks.sh" "$CC/settings.example.json" "$IFW/"
cp -p "$HOOKS"/*.sh "$IFW/hooks/"
chmod +x "$IFW"/hooks/*.sh "$IFW/install-hooks.sh"
SET="$IP/.claude/settings.json"
inst() { ( cd "$IP" && bash "$IFW/install-hooks.sh" "$@" ) > "$T/inst.out" 2> "$T/inst.err"; INST_RC=$?; }
OURS="bash \"\$CLAUDE_PROJECT_DIR/ia-engineering/Adapters/ai-runtimes/claude-code/hooks/context-statusline.sh\""
sl_cmd() { jq -r '.statusLine.command // empty' "$SET" | tr -d '\r'; }
# run_installed <payload> — the installed statusLine command, run as Claude
# Code runs it (bash -c, CLAUDE_PROJECT_DIR set). Sets OUT, ERR, RC.
run_installed() {
  printf '%s' "$1" | env -u IAENG_CTX_CHAINED -u IAENG_CONTEXT_HOOKS TMPDIR="$TMPD" IAENG_CTX_TEST_FALLBACK="$FB" HOME="$HOMED" CLAUDE_PROJECT_DIR="$IP" \
    bash -c "$(sl_cmd)" > "$T/out" 2> "$T/err"
  RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
}

inst
if [ "$INST_RC" -eq 0 ] && [ "$(sl_cmd)" = "$OURS" ]; then ok "a fresh project: the statusLine is installed by default"; else bad "a fresh project: the statusLine is installed by default" "rc=$INST_RC $(sl_cmd)"; fi
rm -rf "$DIR"
run_installed "$GOOD"
fine "the installed command, run as Claude Code runs it"
pct_is "the installed command writes the .pct" sess-1 42
inst --check
if [ "$INST_RC" -eq 0 ] && grep -qF "statusline	present	.claude/settings.json	context-statusline.sh" "$T/inst.out"; then ok "--check: statusline present"; else bad "--check: statusline present" "$(cat "$T/inst.out")"; fi

# An adopter's own statusLine, with an apostrophe and a padding.
jq --arg c "echo \"it's mine \$(jq -r .session_id)\"" '.statusLine = {type:"command", command:$c, padding:2}' "$SET" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
inst --check
if [ "$INST_RC" -eq 3 ] && grep -qF "statusline	absent	.claude/settings.json	context-statusline.sh, chaining the project statusLine echo" "$T/inst.out"; then ok "--check: an unwrapped adopter statusLine is absent (a run wraps it)"; else bad "--check: an unwrapped adopter statusLine is absent" "$(cat "$T/inst.out")"; fi
inst
if [ "$INST_RC" -eq 0 ] && [[ "$(sl_cmd)" == "$OURS --chain "* ]] && [ "$(jq -r '.statusLine.padding' "$SET" | tr -d '\r')" = 2 ] \
   && grep -qF "added:   statusLine: context-statusline.sh, chaining the project statusLine" "$T/inst.out"; then
  ok "an adopter statusLine is wrapped, not replaced: --chain, padding kept, reported"
else
  bad "an adopter statusLine is wrapped, not replaced" "rc=$INST_RC $(sl_cmd) $(cat "$T/inst.out")"
fi
rm -rf "$DIR"
run_installed "$GOOD"
fine "the wrapped command, run as Claude Code runs it"
if [ "$OUT" = "it's mine sess-1" ]; then ok "the wrapped command prints the adopter's line (apostrophe intact, same stdin)"; else bad "the wrapped command prints the adopter's line" "[$OUT] err=[$ERR]"; fi
pct_is "the wrapped command writes the .pct" sess-1 42
cp "$SET" "$T/wrapped.json"
inst
if [ "$INST_RC" -eq 0 ] && cmp -s "$SET" "$T/wrapped.json" && grep -qF "present: statusLine: context-statusline.sh, chaining the project statusLine" "$T/inst.out"; then ok "a re-run leaves the wrapped statusLine byte-identical (no double wrap)"; else bad "a re-run leaves the wrapped statusLine byte-identical" "$(cat "$T/inst.out")"; fi
inst --check
if [ "$INST_RC" -eq 0 ] && grep -qF "statusline	present	" "$T/inst.out"; then ok "--check: a wrapped statusLine is present"; else bad "--check: a wrapped statusLine is present" "$(cat "$T/inst.out")"; fi

# The exec form is folded into the command.
jq '.statusLine = {type:"command", command:"printf", args:["%s+%s","exec","form"]}' "$SET" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
inst
run_installed "$GOOD"
if [ "$INST_RC" -eq 0 ] && [ "$OUT" = "exec+form" ] && [ "$(jq -r '.statusLine.args // "none"' "$SET" | tr -d '\r')" = none ]; then ok "an adopter statusLine in exec form is folded and still prints its line"; else bad "an adopter statusLine in exec form is folded" "rc=$INST_RC out=[$OUT] $(sl_cmd)"; fi

# A PowerShell one is kept as it is, and said.
jq '.statusLine = {type:"command", command:"Write-Output hi", shell:"powershell"}' "$SET" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
cp "$SET" "$T/ps.json"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(jq -c .statusLine "$SET")" = "$(jq -c .statusLine "$T/ps.json")" ] && grep -qF "the context % is not recorded" "$T/inst.err"; then ok "a PowerShell statusLine is kept as it is, and reported on stderr"; else bad "a PowerShell statusLine is kept as it is, and reported" "$(cat "$T/inst.err")"; fi
inst --check
if [ "$INST_RC" -eq 0 ] && grep -qF "statusline	near-miss	" "$T/inst.out" && grep -qF "statusLine near-miss/shadowed" "$T/inst.out"; then ok "--check: a PowerShell statusLine is a near miss, not drift"; else bad "--check: a PowerShell statusLine is a near miss" "rc=$INST_RC $(cat "$T/inst.out")"; fi

# A settings.local.json statusLine shadows the project's: reported, untouched.
jq '.statusLine = {type:"command", command:"echo local"}' "$T/wrapped.json" | tr -d '\r' > "$SET"
printf '{"statusLine":{"type":"command","command":"echo mine-only"}}\n' > "$IP/.claude/settings.local.json"
cp "$IP/.claude/settings.local.json" "$T/local.before"
inst --check
if grep -qF "statusline	shadowed	.claude/settings.local.json	echo mine-only" "$T/inst.out"; then ok "--check: a settings.local.json statusLine is reported shadowed"; else bad "--check: a settings.local.json statusLine is reported shadowed" "$(cat "$T/inst.out")"; fi
inst
if cmp -s "$IP/.claude/settings.local.json" "$T/local.before" && grep -qF "settings.local.json sets its own statusLine" "$T/inst.err"; then ok "a run warns about the settings.local.json statusLine and leaves the file untouched"; else bad "a run warns about the settings.local.json statusLine" "$(cat "$T/inst.err")"; fi
rm -f "$IP/.claude/settings.local.json"

# A command holding terminal escapes is printed flattened on the normal path,
# as --check's records are (SEC-IAENG-379-01): the project's own wrapped, and
# a settings.local.json one reported.
ESCC="$(printf 'echo \033]0;PROJ-TITLE\007proj')"
jq --arg c "$ESCC" '.statusLine = {type:"command", command:$c}' "$T/wrapped.json" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
jq -n --arg c "$(printf 'echo \033]0;LOCAL-TITLE\007local')" '{statusLine:{type:"command", command:$c}}' > "$IP/.claude/settings.local.json"
inst
if ! grep -q -- "$(printf '\033')" "$T/inst.out" "$T/inst.err" && grep -qF -- "PROJ-TITLE" "$T/inst.out" && grep -qF -- "LOCAL-TITLE" "$T/inst.err"; then ok "the installer prints statusLine commands with no control character, stdout and stderr"; else bad "the installer prints statusLine commands with no control character" "$(od -c "$T/inst.out" "$T/inst.err" | grep -m2 033)"; fi
rm -f "$IP/.claude/settings.local.json"

# The script at an earlier framework path (cr-321 m2): updated in place, its
# --chain kept; any other command naming the script is kept and reported.
jq --arg c "bash \"\$CLAUDE_PROJECT_DIR/old-fw/Adapters/ai-runtimes/claude-code/hooks/context-statusline.sh\" --chain 'echo kept'" \
  '.statusLine = {type:"command", command:$c}' "$SET" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(sl_cmd)" = "$OURS --chain 'echo kept'" ] && grep -qF "updated in place from an earlier path" "$T/inst.out"; then ok "a statusLine at an earlier framework path is updated in place, its --chain kept"; else bad "a statusLine at an earlier framework path is updated in place" "rc=$INST_RC $(sl_cmd)"; fi
jq '.statusLine = {type:"command", command:"echo hooks/context-statusline.sh"}' "$SET" | tr -d '\r' > "$T/s.json" && mv "$T/s.json" "$SET"
cp "$SET" "$T/other.json"
inst
if cmp -s "$SET" "$T/other.json" && grep -qF "names context-statusline.sh in a form of its own" "$T/inst.err"; then ok "another command naming the script is kept as it is, and reported"; else bad "another command naming the script is kept as it is, and reported" "$(cat "$T/inst.err")"; fi

# =============================================================================
echo "== the user's real context directory (issue #345)"
LEFT="$(real_ctx_changed)"
if [ -z "$LEFT" ]; then ok "no case wrote into the user's real iaeng-ctx directory (/tmp's or TMPDIR's)"; else bad "no case wrote into the user's real iaeng-ctx directory (/tmp's or TMPDIR's)" "added or modified: $(tr '\n' ' ' <<< "$LEFT")"; fi

# =============================================================================
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Context statusLine result: %s checks passed, %s not applicable here.\n' "$TOTAL" "$NA"
  exit 0
fi
printf 'Context statusLine result: %s of %s checks failed, %s not applicable here.\n' "$FAILED" "$TOTAL" "$NA"
exit 1
