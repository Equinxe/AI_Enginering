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
    --help|-h) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
