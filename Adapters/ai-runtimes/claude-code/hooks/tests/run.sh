#!/usr/bin/env bash
# IA Engineering — hook tests
#
# The Claude Code hooks are the only Adapters whose correctness is a matter of
# BEHAVIOUR rather than structure: shellcheck proves they are valid shell, and
# the validator proves the documents around them agree, but neither can say
# whether `git push --force` is actually refused. Seven real defects were found
# by feeding the escape-hatch hook payloads by hand — a trailing `;`, a global
# option before the subcommand, the short `-n` form, a quoted lone flag, a line
# continuation, the other argument order of a branch deletion, and a false
# positive that refused searching the documentation for a flag name, which is
# exactly how a hook teaches people to work around it.
#
# Finding those by hand once is not a control. This is the control: the cases
# live in the repository, the CI job "Hook Tests" runs them on every Pull
# Request, and a regression names itself.
#
# CASE FILE FORMAT — one case per line, TAB-separated:
#   block<TAB><shell command>    the hook must refuse it (exit 2)
#   allow<TAB><shell command>    the hook must permit it (exit 0)
# Blank lines and lines beginning with # are ignored. The commands live in a
# FILE rather than in a command line on purpose: a corpus full of escape
# hatches, typed into a terminal, is refused by the very hook under test.
#
# Usage:
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/run.sh [--verbose]
#
# Requires jq, to build the payloads. Exits 0 when every case matches, 1 when
# any does not, and 2 when the environment is unusable — never 0 for "could
# not test", which would be a pass that evaluated nothing.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "run.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"

command -v jq >/dev/null 2>&1 || {
  echo "run.sh: jq is required to build hook payloads, and is not installed." >&2
  echo "  Reported rather than skipped: a run that tested nothing is not a pass." >&2
  exit 2
}

FAILED=0
TOTAL=0

# --- Escape-hatch hook, case corpus -----------------------------------------

HOOK="$HOOKS/block-escape-hatches.sh"
CASES="$HERE/escape-hatch-cases.tsv"
[ -f "$HOOK" ]  || { echo "run.sh: $HOOK is missing" >&2; exit 2; }
[ -f "$CASES" ] || { echo "run.sh: $CASES is missing" >&2; exit 2; }

echo "== block-escape-hatches.sh"
cases_run=0
while IFS=$'\t' read -r want cmd; do
  case "${want:-}" in ''|'#'*) continue ;; esac
  [ -n "${cmd:-}" ] || continue
  cases_run=$((cases_run + 1))
  TOTAL=$((TOTAL + 1))

  printf '%s' "$(jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}')" \
    | bash "$HOOK" >/dev/null 2>/dev/null
  rc=$?
  got=allow
  [ "$rc" -eq 2 ] && got=block

  if [ "$got" = "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    [%s] %s\n' "$want" "$cmd"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  want=%-5s got=%-5s (exit %s)  %s\n' "$want" "$got" "$rc" "$cmd"
  fi
done < "$CASES"

if [ "$cases_run" -eq 0 ]; then
  echo "   FAIL  $CASES yielded no cases — the file is empty, or its tab separators were lost." >&2
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
else
  printf '   %s cases\n' "$cases_run"
fi

# --- Payload handling, common to every hook ---------------------------------
# Two properties every hook shares: it fails closed on input it cannot read,
# and it ignores tool calls that are not its own.

echo "== payload handling"

expect_rc() {
  local label="$1" want="$2" hook="$3" payload="$4" rc
  TOTAL=$((TOTAL + 1))
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>/dev/null
  rc=$?
  if [ "$rc" -eq "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s (exit %s)\n' "$label" "$rc"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: want exit %s, got %s\n' "$label" "$want" "$rc"
  fi
}

# Built with jq so this file does not itself contain a suppression directive.
SUPPRESSED="$(printf 'x = 1  #%s' ' noqa')"
PAY_CODE="$(jq -n --arg c "$SUPPRESSED" '{tool_name:"Write",tool_input:{file_path:"a.py",content:$c}}')"
PAY_DOC="$(jq -n --arg c "$SUPPRESSED"  '{tool_name:"Write",tool_input:{file_path:"a.md",content:$c}}')"

expect_rc "escape-hatch: empty payload fails closed"        2 "$HOOKS/block-escape-hatches.sh"    '{}'
expect_rc "escape-hatch: ignores a non-Bash tool"           0 "$HOOKS/block-escape-hatches.sh"    '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
expect_rc "inline-suppression: refuses a directive in code" 2 "$HOOKS/block-inline-suppression.sh" "$PAY_CODE"
expect_rc "inline-suppression: allows it in documentation"  0 "$HOOKS/block-inline-suppression.sh" "$PAY_DOC"

# A directive on line 1 of a code file LARGER than the ~64 KB pipe buffer. The
# old `printf "$TEXT" | grep -q` under pipefail let grep short-circuit the
# printf, which took SIGPIPE, which pipefail reported as no-match — so this
# exact payload was ALLOWED with no obfuscation, just size. A 64 KB source file
# is ordinary. Built via --rawfile because a multi-MB string will not fit on a
# jq command line (that failure looks like a pass). TROUBLESHOOTING X.
BIGSUP="$HERE/bigsup.tmp"
{ printf '# noqa\n'; yes 'filler line padding padding padding padding' | head -n 30000; } > "$BIGSUP"
PAY_BIG="$(jq -n --arg f "big.py" --rawfile c "$BIGSUP" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}')"
rm -f "$BIGSUP"
expect_rc "inline-suppression: refuses a directive in a >64KB payload" 2 "$HOOKS/block-inline-suppression.sh" "$PAY_BIG"
expect_rc "inline-suppression: ignores a non-edit tool"     0 "$HOOKS/block-inline-suppression.sh" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_rc "stop-gate: yields to its own loop guard"         0 "$HOOKS/stop-gate.sh"                '{"stop_hook_active":true}'

# --- Lexer ------------------------------------------------------------------
# The lexer decides what the rules ever see, so it is checked directly: text
# inside quotes must not reach them, text inside a command substitution must,
# and a lone quoted flag must.

echo "== strip-quotes.awk"

LEXER_CASES="$HERE/lexer-cases.tsv"
[ -f "$LEXER_CASES" ] || { echo "run.sh: $LEXER_CASES is missing" >&2; exit 2; }

lex_run=0
while IFS=$'\t' read -r label input needle want; do
  case "${label:-}" in ''|'#'*) continue ;; esac
  [ -n "${want:-}" ] || continue
  lex_run=$((lex_run + 1))
  TOTAL=$((TOTAL + 1))

  # %b expands the \n the case file uses to keep each case on one line.
  got="$(printf '%b\n' "$input" | awk -f "$HOOKS/strip-quotes.awk")"
  case "$got" in
    *"$needle"*) found=yes ;;
    *)           found=no ;;
  esac

  if [ "$found" = "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: expected "%s" present=%s, got [%s]\n' "$label" "$needle" "$want" "$got"
  fi
done < "$LEXER_CASES"

if [ "$lex_run" -eq 0 ]; then
  echo "   FAIL  $LEXER_CASES yielded no cases — the file is empty, or its tab separators were lost." >&2
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
else
  printf '   %s cases\n' "$lex_run"
fi

# --- SESSION_STATE freshness (session-start.sh, stop-gate.sh) ---------------
# The cases above feed a fixed JSON payload to a hook and check its exit code
# — enough for rules that read only the tool call. This rule reads the
# filesystem (SESSION_STATE.md's mtime, HEAD's commit time), so each case
# below builds one throwaway git repository under `mktemp -d`, points
# CLAUDE_PROJECT_DIR at it, runs the hook, and is removed with the rest of
# SSBASE at the end of this section — nothing here is committed or kept.

echo "== SESSION_STATE freshness"

STOPGATE="$HOOKS/stop-gate.sh"
SESSTART="$HOOKS/session-start.sh"
SSBASE="$(mktemp -d)"

# ss_repo <name>  — a throwaway repo with one commit, under $SSBASE/<name>.
ss_repo() {
  local dir="$SSBASE/$1"
  mkdir -p "$dir/.ia-engineering"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.com
  git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  echo a > "$dir/f.txt"
  git -C "$dir" add f.txt
  git -C "$dir" commit -qm init >/dev/null
  printf '%s' "$dir"
}

# ss_run <dir> <hook> [stdin]  — sets SS_OUT (stdout+stderr) and SS_RC.
ss_run() {
  local dir="$1" hook="$2" stdin="${3:-{\}}"
  SS_OUT="$( (export CLAUDE_PROJECT_DIR="$dir"; printf '%s' "$stdin" | bash "$hook") 2>&1 )"
  SS_RC=$?
}

# ss_check_rc <label> <want_rc>  — checks $SS_RC from the most recent ss_run.
ss_check_rc() {
  local label="$1" want="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$SS_RC" -eq "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s (exit %s)\n' "$label" "$SS_RC"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: want exit %s, got %s\n' "$label" "$want" "$SS_RC"
    [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$SS_OUT" | sed 's/^/         /'
  fi
}

# ss_check_has <label> <yes|no> <needle>  — checks $SS_OUT from the most
# recent ss_run contains (yes) or does not contain (no) needle.
ss_check_has() {
  local label="$1" want="$2" needle="$3" found=no
  TOTAL=$((TOTAL + 1))
  case "$SS_OUT" in
    *"$needle"*) found=yes ;;
  esac
  if [ "$found" = "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: expected "%s" present=%s, got present=%s\n' "$label" "$needle" "$want" "$found"
  fi
}

# --- fixtures -----------------------------------------------------------
# "stale": header and mtime both 1 January 2020 — behind any HEAD made today.
STALE="$(ss_repo stale)"
{
  echo '# SESSION STATE — test'
  echo '_Last updated: 1 January 2020, morning by Tester_'
  echo '## Where the Project Stands'
  echo 'x'
} > "$STALE/.ia-engineering/SESSION_STATE.md"
touch -t 202001010000 "$STALE/.ia-engineering/SESSION_STATE.md"

# "fresh": header and mtime both after the repo's one commit.
FRESH="$(ss_repo fresh)"
{
  echo '# SESSION STATE — test'
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Where the Project Stands'
  echo 'x'
} > "$FRESH/.ia-engineering/SESSION_STATE.md"
touch "$FRESH/.ia-engineering/SESSION_STATE.md"

# "missing": no SESSION_STATE.md at all.
MISSING="$(ss_repo missing)"

# "unparsable": a header with no recognisable "DD Month YYYY".
UNPARSABLE="$(ss_repo unparsable)"
echo '_Last updated: some day by Tester_' > "$UNPARSABLE/.ia-engineering/SESSION_STATE.md"
touch "$UNPARSABLE/.ia-engineering/SESSION_STATE.md"

# "stale-header": mtime is current (after HEAD — not behind), but the header
# text inside was never refreshed. Isolates Warning 2 from Warning 1.
STALEHDR="$(ss_repo stale-header)"
echo '_Last updated: 1 January 2020, morning by Tester_' > "$STALEHDR/.ia-engineering/SESSION_STATE.md"
touch "$STALEHDR/.ia-engineering/SESSION_STATE.md"

# "big": current header and mtime, body over the 15,000-character budget.
BIG="$(ss_repo big)"
{
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Where the Project Stands'
  yes 'padding padding padding padding padding' | head -n 400
} > "$BIG/.ia-engineering/SESSION_STATE.md"
touch "$BIG/.ia-engineering/SESSION_STATE.md"

# "dirty": stale SESSION_STATE, plus an uncommitted change to a tracked file —
# the pre-existing tracked-changes gate must still win, unchanged.
DIRTY="$(ss_repo dirty)"
cp "$STALE/.ia-engineering/SESSION_STATE.md" "$DIRTY/.ia-engineering/SESSION_STATE.md"
touch -t 202001010000 "$DIRTY/.ia-engineering/SESSION_STATE.md"
echo b >> "$DIRTY/f.txt"

# "nogit": SESSION_STATE present and stale, but the directory is not a git
# repository at all — the fail-safe path.
NOGIT="$SSBASE/nogit"
mkdir -p "$NOGIT/.ia-engineering"
echo '_Last updated: 1 January 2020, morning by Tester_' > "$NOGIT/.ia-engineering/SESSION_STATE.md"
touch -t 202001010000 "$NOGIT/.ia-engineering/SESSION_STATE.md"

# --- stop-gate.sh --------------------------------------------------------

ss_run "$STALE" "$STOPGATE"
ss_check_rc   "stop-gate: blocks when SESSION_STATE is older than HEAD" 2
ss_check_has  "stop-gate: block message names the reason" yes "behind the repository"

ss_run "$FRESH" "$STOPGATE"
ss_check_rc   "stop-gate: passes when SESSION_STATE is newer than HEAD" 0

ss_run "$MISSING" "$STOPGATE"
ss_check_rc   "stop-gate: passes (non-blocking) when SESSION_STATE is missing" 0
ss_check_has  "stop-gate: reminds when SESSION_STATE is missing" yes "does not exist"

ss_run "$STALE" "$STOPGATE" '{"stop_hook_active":true}'
ss_check_rc   "stop-gate: loop guard still yields even when SESSION_STATE is stale" 0

ss_run "$DIRTY" "$STOPGATE"
ss_check_rc   "stop-gate: uncommitted tracked changes still block first" 2
ss_check_has  "stop-gate: dirty-tree message unchanged by the new gate" yes "uncommitted changes"

ss_run "$NOGIT" "$STOPGATE"
ss_check_rc   "stop-gate: fail-safe — not a git repo does not block" 0

# --- session-start.sh ------------------------------------------------------

ss_run "$STALE" "$SESSTART" ''
ss_check_has  "session-start: warns when SESSION_STATE is behind the repository" yes "behind the repository"

ss_run "$FRESH" "$SESSTART" ''
ss_check_has  "session-start: no behind-warning when SESSION_STATE is current" no "behind the repository"

ss_run "$STALEHDR" "$SESSTART" ''
ss_check_has  "session-start: warns when the header was not refreshed on the last edit" yes "was not refreshed on the file's last edit"

ss_run "$UNPARSABLE" "$SESSTART" ''
ss_check_has  "session-start: reports an unparsable header rather than staying silent" yes "no parsable date found"

ss_run "$BIG" "$SESSTART" ''
ss_check_has  "session-start: warns when SESSION_STATE exceeds the size budget" yes "15,000-character budget"

ss_run "$FRESH" "$SESSTART" ''
ss_check_has  "session-start: no size warning when SESSION_STATE is small" no "15,000-character budget"

rm -rf "$SSBASE"

# --- Verdict ----------------------------------------------------------------

echo
if [ "$FAILED" -eq 0 ]; then
  printf 'Result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
echo "  A hook that stopped refusing what Standards/GIT_STANDARD.md forbids, or"
echo "  started refusing something legitimate, is a regression either way."
exit 1
