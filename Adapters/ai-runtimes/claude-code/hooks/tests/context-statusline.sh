#!/usr/bin/env bash
# IA Engineering — hook tests: the context statusLine (WU-IAENG-379)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/context-statusline.sh [--verbose]
#
# What is proved, on real files in a scratch TMPDIR and HOME:
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
#   - a find that fails skips the write; the cleanup deletes only old *.pct
#     and *.alert regular files, at most once an hour;
#   - install-hooks.sh installs the statusLine, wraps an adopter's own
#     statusLine instead of replacing it (padding kept, an apostrophe in its
#     command survives, the exec form folded), is idempotent, keeps a
#     PowerShell one as it is and says so, reports a settings.local.json one
#     as shadowed, and --check reports each case; the installed command, run
#     as Claude Code runs it (bash -c), writes the .pct and prints the
#     adopter's line.
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
mkdir -p "$TMPD" "$HOMED/.claude" "$PROJ"
DIR="$TMPD/iaeng-ctx-$ID"

# run <stdin> [args...] — runs the statusLine as Claude Code does: stdin, a
# scratch TMPDIR, HOME and project, none of the switches. Sets OUT, ERR, RC.
run() {
  local input="$1"; shift
  printf '%s' "$input" | env -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_CHAINED -u CLAUDE_CONFIG_DIR \
    -u NO_COLOR -u IAENG_CTX_ALERT_PCT \
    TMPDIR="$TMPD" HOME="$HOMED" CLAUDE_PROJECT_DIR="$PROJ" ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
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

GOOD='{"session_id":"sess-1","model":{"display_name":"Opus 5.5"},"context_window":{"used_percentage":42.7,"context_window_size":1000000,"current_usage":{"input_tokens":5}},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1}}}'

# =============================================================================
echo "== context-statusline.sh — the line and the file"

run "$GOOD"
fine "a valid payload"
has "a valid payload: the line shows model, ctx and 5 h quota" "[Opus 5.5] ctx 42% | 5h 23%"
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
# At most once an hour, *.pct and *.alert regular files older than 24 h go;
# a fresh file, another name, a directory and a link (and what it points at)
# stay. Oracle: the decision's own terms (24 h, once an hour, regular files
# the user owns, never through a link).
CL="$T/cleantmp"; CLD="$CL/iaeng-ctx-$ID"; mkdir -p "$CLD"
OLD="$(( $(date +%s) - 172800 ))"
for n in old-a.pct old-b.alert old-other.txt; do : > "$CLD/$n"; touch -d "@$OLD" "$CLD/$n"; done
: > "$CLD/fresh.pct"
mkdir "$CLD/old-dir.pct"; touch -d "@$OLD" "$CLD/old-dir.pct"
LINKED=0
if can_link; then
  printf 'victim\n' > "$T/victim-cl"
  MSYS=winsymlinks:sys ln -s "$T/victim-cl" "$CLD/old-link.pct" && touch -h -d "@$OLD" "$CLD/old-link.pct" 2>/dev/null
  [ -L "$CLD/old-link.pct" ] && LINKED=1
fi
RUN_ENV=(TMPDIR="$CL")
run '{"session_id":"sess-cl","context_window":{"used_percentage":5}}'
RUN_ENV=()
fine "a run that cleans up"
if [ ! -e "$CLD/old-a.pct" ] && [ ! -e "$CLD/old-b.alert" ]; then ok "cleanup: *.pct and *.alert older than 24 h are deleted"; else bad "cleanup: *.pct and *.alert older than 24 h are deleted" "$(find "$CLD" -mindepth 1 | tr '\n' ' ')"; fi
if [ -f "$CLD/fresh.pct" ] && [ -f "$CLD/old-other.txt" ] && [ -d "$CLD/old-dir.pct" ] && [ -f "$CLD/sess-cl.pct" ]; then ok "cleanup: a fresh .pct, another name and a directory stay"; else bad "cleanup: a fresh .pct, another name and a directory stay" "$(find "$CLD" -mindepth 1 | tr '\n' ' ')"; fi
if [ "$LINKED" -eq 1 ]; then
  if [ -L "$CLD/old-link.pct" ] && [ "$(cat "$T/victim-cl")" = victim ]; then ok "cleanup: an old link named *.pct is neither deleted nor followed"; else bad "cleanup: an old link named *.pct is neither deleted nor followed"; fi
else
  na "cleanup: an old link named *.pct" "symbolic links cannot be created here"
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
for tmp in "$T/a-file" "$T/no/such/dir" "relative/tmp" "$T/tmp/../dotdot"; do
  RUN_ENV=(TMPDIR="$tmp")
  run '{"session_id":"sess-bad-tmp","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "TMPDIR=$tmp"
done
if [ -f "$T/a-file" ] && [ ! -s "$T/a-file" ] && [ ! -e "$T/no" ] && [ ! -e "relative" ] && [ -z "$(ls -A "$T/dotdot")" ]; then ok "a TMPDIR that is a file, missing, relative or with .. is never written to"; else bad "a TMPDIR that is a file, missing, relative or with .. is never written to" "$(ls -A "$T/dotdot")"; fi
rm -f "/tmp/iaeng-ctx-$ID/sess-bad-tmp.pct" 2>/dev/null
# The same rule with Windows separators (cr-321 s1): C:\...\tmp\..\dotdot2
# names a directory that exists.
if command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$T/dotdot2"
  RUN_ENV=(TMPDIR="$(cygpath -w "$T/tmp")\\..\\dotdot2")
  run '{"session_id":"sess-bad-tmp","context_window":{"used_percentage":9}}'
  RUN_ENV=()
  fine "TMPDIR with a \\..\\ component"
  if [ -z "$(ls -A "$T/dotdot2")" ]; then ok "a TMPDIR with a backslash .. component is never written to"; else bad "a TMPDIR with a backslash .. component is never written to" "$(ls -A "$T/dotdot2")"; fi
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
printf '%s' '{"session_id":"sess-nojq","context_window":{"current_usage":{"used_percentage":99},"used_percentage":61.9},"rate_limits":{"five_hour":{"used_percentage":8}}}' \
  | env -i PATH="$NOJQ" TMPDIR="$TMPD" HOME="$HOMED" CLAUDE_PROJECT_DIR="$PROJ" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
fine "no jq"
has "no jq: the line still shows ctx and 5 h quota" "ctx 61% | 5h 8%"
pct_is "no jq: the .pct is written from the top-level used_percentage, not current_usage's" sess-nojq 61
printf '%s' 'garbage {"session_id": "x' | env -i PATH="$NOJQ" TMPDIR="$TMPD" HOME="$HOMED" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
RC=$?; OUT="$(cat "$T/out")"; ERR="$(cat "$T/err")"
fine "no jq, bad JSON"

# No jq, and the user has a statusLine (cr-321 M2): it is still run, read by
# pattern. Written by hand, with the JSON escapes \" and \\ in the command.
NJH="$T/home-nojq"; mkdir -p "$NJH/.claude"
nojq_run() {
  printf '%s' "$GOOD" | env -i PATH="$NOJQ" TMPDIR="$TMPD" HOME="$NJH" CLAUDE_PROJECT_DIR="$PROJ" "$@" "$BASH_BIN" "$SL" > "$T/out" 2> "$T/err"
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
  printf '%s' "$1" | env -u IAENG_CTX_CHAINED -u IAENG_CONTEXT_HOOKS TMPDIR="$TMPD" HOME="$HOMED" CLAUDE_PROJECT_DIR="$IP" \
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
if ! grep -q "$(printf '\033')" "$T/inst.out" "$T/inst.err" && grep -qF "PROJ-TITLE" "$T/inst.out" && grep -qF "LOCAL-TITLE" "$T/inst.err"; then ok "the installer prints statusLine commands with no control character, stdout and stderr"; else bad "the installer prints statusLine commands with no control character" "$(od -c "$T/inst.out" "$T/inst.err" | grep -m2 033)"; fi
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
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Context statusLine result: %s checks passed, %s not applicable here.\n' "$TOTAL" "$NA"
  exit 0
fi
printf 'Context statusLine result: %s of %s checks failed, %s not applicable here.\n' "$FAILED" "$TOTAL" "$NA"
exit 1
