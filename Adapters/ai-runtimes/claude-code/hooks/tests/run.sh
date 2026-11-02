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
#   block<TAB><shell command><TAB><reason substring>
#                                the hook must refuse it, and its
#                                "iaeng: BLOCKED — " line must contain the
#                                substring (fixed string, case-sensitive)
# The third column is optional and only legal on a block case. It is for a
# command that more than one rule refuses: an exit code alone stays 2 when the
# rule the case is about is broken and another rule still fires, so the case
# proves nothing about its own rule (Standards/TESTING_STANDARD.md,
# Falsifiability item 3). The hook exits at its FIRST refusal, so the substring
# must name the first rule that fires. It must also occur in exactly one reason
# of the hook's source, or it would not tell the rules apart; both are checked.
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

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
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
# The hook's reason texts, one per line: the first argument of every
# iaeng_block and the hooksPath rule's HOOKSPATH_REASON assignments, without the
# Standard reference that follows (one rule has both on a line). A reason
# substring must occur in exactly one of them, or it would pass whichever of two
# rules fired.
HOOK_REASONS="$(sed -nE -e 's/^[[:space:]]*iaeng_block "([^"]*)".*/\1/p' \
  -e 's/^[[:space:]]*HOOKSPATH_REASON="([^"]*)".*/\1/p' "$HOOK")"
[ "$(printf '%s\n' "$HOOK_REASONS" | grep -c .)" -ge 2 ] \
  || { echo "run.sh: no refusal reasons could be read from $HOOK" >&2; exit 2; }
cases_run=0
while IFS=$'\t' read -r want cmd reason; do
  case "${want:-}" in ''|'#'*) continue ;; esac
  [ -n "${cmd:-}" ] || continue
  cases_run=$((cases_run + 1))
  TOTAL=$((TOTAL + 1))

  err="$(printf '%s' "$(jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}')" \
    | bash "$HOOK" 2>&1 >/dev/null)"
  rc=$?
  got=allow
  [ "$rc" -eq 2 ] && got=block

  if [ "$got" != "$want" ]; then
    FAILED=$((FAILED + 1))
    printf '   FAIL  want=%-5s got=%-5s (exit %s)  %s\n' "$want" "$got" "$rc" "$cmd"
  elif [ -n "${reason:-}" ] && [ "$want" != block ]; then
    FAILED=$((FAILED + 1))
    printf '   FAIL  a reason column on an allow case (only a block case has one)  %s\n' "$cmd"
  elif [ -n "${reason:-}" ] \
       && [ "$(grep -cF -- "$reason" <<< "$HOOK_REASONS")" -ne 1 ]; then
    FAILED=$((FAILED + 1))
    printf '   FAIL  reason "%s" is in %s of the hook'"'"'s reasons, want exactly 1  %s\n' \
      "$reason" "$(grep -cF -- "$reason" <<< "$HOOK_REASONS")" "$cmd"
  elif [ -n "${reason:-}" ] \
       && ! sed -n 's/^iaeng: BLOCKED — //p' <<< "$err" | grep -qF -- "$reason"; then
    FAILED=$((FAILED + 1))
    printf '   FAIL  want reason "%s", got "%s"  %s\n' \
      "$reason" "$(sed -n 's/^iaeng: BLOCKED — //p' <<< "$err")" "$cmd"
  else
    [ "$VERBOSE" -eq 1 ] && printf '   ok    [%s] %s\n' "$want" "$cmd"
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
# Two properties checked here: the guard hooks (block-escape-hatches,
# block-inline-suppression) fail closed on input they cannot read, and each
# hook ignores tool calls that are not its own.

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
# Multi-line commands cannot live in the one-line .tsv corpus. A heredoc body
# is data: an approval-label command quoted in one is not run, and a real
# label flag before a heredoc is still refused (WU-IAENG-311).
HD_ALLOW=$'gh pr create --label bug --body-file - <<\'EOF\'\ngh pr edit 1 --add-label "help wanted,size/approved"\nEOF'
HD_BLOCK=$'gh pr edit 1 --add-label "help wanted,size/approved" --body-file - <<\'EOF\'\nsome text\nEOF'
expect_rc "approval-label: a command quoted in a heredoc body is data" 0 "$HOOKS/block-escape-hatches.sh" "$(jq -n --arg c "$HD_ALLOW" '{tool_name:"Bash",tool_input:{command:$c}}')"
expect_rc "approval-label: a real quoted label list before a heredoc is refused" 2 "$HOOKS/block-escape-hatches.sh" "$(jq -n --arg c "$HD_BLOCK" '{tool_name:"Bash",tool_input:{command:$c}}')"
# A newline withholds the legacy core.hooksPath get (SEC-IAENG-316-02): a value
# on the next line after a backtick is a write the segment split cannot see.
NL_A=$'git config core.hooksPath `\necho /dev/null`'
NL_B=$'git config --local core.hooksPath `\n/dev/null`'
NL_C=$'git config --global core.hooksPath\n/dev/null'
NL_D=$'git config --local core.hooksPath\ngit log'
for NL_CMD in "$NL_A" "$NL_B" "$NL_C" "$NL_D"; do
  expect_rc "hooksPath: a newline withholds the legacy get" 2 "$HOOKS/block-escape-hatches.sh" "$(jq -n --arg c "$NL_CMD" '{tool_name:"Bash",tool_input:{command:$c}}')"
done
# A legacy read refused only because the raw command has a quote (the documented
# fail-closed trade-off) is still refused, but the message names the read to run
# instead; a real set gets no such hint (WU-IAENG-328, NEW-3).
# expect_hint <label> <command> <1 = hint expected | 0 = hint absent>
expect_hint() {
  local label="$1" cmd="$2" want="$3" out rc has=0
  TOTAL=$((TOTAL + 1))
  out="$(jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | bash "$HOOKS/block-escape-hatches.sh" 2>&1 >/dev/null)"
  rc=$?
  grep -qF -- "if this is a read, run \`git config --get core.hooksPath\`" <<< "$out" && has=1
  if [ "$rc" -eq 2 ] && [ "$has" -eq "$want" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: exit %s, hint present=%s (want exit 2, hint=%s)\n' "$label" "$rc" "$has" "$want"
    printf '%s\n' "$out" | sed 's/^/         | /'
  fi
}
expect_hint "hooksPath: a quoted-command legacy read is refused with the --get hint" \
  'cd "/x" && git config core.hooksPath && ls' 1
expect_hint "hooksPath: a real set is refused without the read hint" \
  'git config core.hooksPath /dev/null' 0
expect_hint "hooksPath: a real set beside a quote is refused without the read hint" \
  'cd "/x" && git config --local core.hooksPath /dev/null' 0
expect_hint "hooksPath: a legacy read beside a real set gets no read hint (one message, whole command)" \
  'cd "/x" && git config core.hooksPath && git config core.hooksPath /dev/null' 0
expect_hint "hooksPath: a legacy read beside a -c write gets no read hint" \
  'cd "/x" && git config core.hooksPath; git -c core.hooksPath=/dev/null commit' 0
# The case above is a write by its own shape (`commit` is not a read), so the hook
# marks it a real write before it looks at the -c. Here the -c write rides on a
# segment that IS a read (`config --get`): the read exemption passes it, and only
# the -c check marks the real write. Without that mark the hint would be printed
# for a command that disables the hooks (issue #275, item 4; WU-IAENG-364).
expect_hint "hooksPath: a legacy read beside a -c write layered under a --get read gets no read hint" \
  'cd "/x" && git config core.hooksPath; git -c core.hooksPath=/dev/null config --get core.hooksPath' 0
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
# Unreadable is not the same as "nothing to check" (DEF-4). With jq present an
# unparseable payload left TEXT empty and the hook exited 0, allowing the write.
expect_rc "inline-suppression: an unparseable payload fails closed" 2 "$HOOKS/block-inline-suppression.sh" 'not json at all'
expect_rc "inline-suppression: a truncated JSON payload fails closed" 2 "$HOOKS/block-inline-suppression.sh" '{"tool_name":"Write","tool_input":{"file_path":"a.py","content":"x'
expect_rc "inline-suppression: empty stdin fails closed" 2 "$HOOKS/block-inline-suppression.sh" ''
expect_rc "inline-suppression: valid JSON that is not an object fails closed" 2 "$HOOKS/block-inline-suppression.sh" '[1,2]'
# jq judges a stream by its last value; two objects must not pass as one.
expect_rc "inline-suppression: two concatenated JSON objects fail closed" 2 "$HOOKS/block-inline-suppression.sh" '{"tool_name":"Bash"} {"tool_name":"Write","tool_input":{"file_path":"a.py"}}'
expect_rc "inline-suppression: a readable payload with no text to check is allowed" 0 "$HOOKS/block-inline-suppression.sh" '{"tool_name":"Write","tool_input":{"file_path":"a.py"}}'
expect_rc "inline-suppression: an empty object is readable and has nothing to check" 0 "$HOOKS/block-inline-suppression.sh" '{}'
# The patterns are read from Adapters/scripts/suppression-patterns.tsv, shared
# with check-inline-suppression.sh. One row from each of two different labels
# still blocks, so a hook that read only the first row would be caught.
PAY_JS="$(jq -n --arg c "$(printf '%s%s' '// eslint' '-disable-next-line')" '{tool_name:"Write",tool_input:{file_path:"a.ts",content:$c}}')"
PAY_TEST="$(jq -n --arg c "$(printf '%s%s' 'it.' 'skip("x", f)')" '{tool_name:"Write",tool_input:{file_path:"a.test.js",content:$c}}')"
PAY_CLEAN="$(jq -n '{tool_name:"Write",tool_input:{file_path:"a.py",content:"x = 1"}}')"
# The pattern-file and hooks/tests exemptions compare the CANONICAL path of the
# edit (a relative path resolved against the payload's cwd) with the framework's
# own files, not a suffix: a file that merely ends in the same words, or sits in
# an unrelated hooks/tests/ directory, is code (SEC-04, SEC-06).
PATFILE_ABS="$(cd "$HOOKS/../../../scripts" && pwd)/suppression-patterns.tsv"
HOOKTESTS_ABS="$HOOKS/tests"
mkpay() { jq -n --arg f "$1" --arg c "$SUPPRESSED" --arg w "${2:-}" '{tool_name:"Write",cwd:$w,tool_input:{file_path:$f,content:$c}}'; }
PAY_PATFILE="$(mkpay "$PATFILE_ABS")"
expect_rc "inline-suppression: the documentation exemption folds case (README.MD)" 0 "$HOOKS/block-inline-suppression.sh" "$(mkpay "/work/proj/README.MD")"
expect_rc "inline-suppression: a pattern from the file (JS/TS row) blocks" 2 "$HOOKS/block-inline-suppression.sh" "$PAY_JS"
expect_rc "inline-suppression: a pattern from the file (skipped-test row) blocks" 2 "$HOOKS/block-inline-suppression.sh" "$PAY_TEST"
expect_rc "inline-suppression: clean code is allowed" 0 "$HOOKS/block-inline-suppression.sh" "$PAY_CLEAN"
expect_rc "inline-suppression: a Write to the pattern file is allowed (it quotes every directive)" 0 "$HOOKS/block-inline-suppression.sh" "$PAY_PATFILE"

expect_rc "inline-suppression: the pattern file given relative to the payload cwd is allowed" 0 "$HOOKS/block-inline-suppression.sh" "$(mkpay "scripts/suppression-patterns.tsv" "$(dirname "$PATFILE_ABS")/..")"
expect_rc "inline-suppression: a bare relative path that only looks like the pattern file is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "Adapters/scripts/suppression-patterns.tsv" "/nonexistent")"
expect_rc "inline-suppression: another tree's file ending in the pattern file's path is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "/tmp/evil/Adapters/scripts/suppression-patterns.tsv")"
expect_rc "inline-suppression: a case-variant of the pattern file's path is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "$(dirname "$PATFILE_ABS")/SUPPRESSION-PATTERNS.TSV")"
expect_rc "inline-suppression: a .. path that resolves elsewhere is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "$(dirname "$PATFILE_ABS")/../scripts/../x.py")"
expect_rc "inline-suppression: this hook's own tests/ directory is exempt" 0 "$HOOKS/block-inline-suppression.sh" "$(mkpay "$HOOKTESTS_ABS/cases.sh")"
expect_rc "inline-suppression: a relative path into it, resolved against cwd, is exempt" 0 "$HOOKS/block-inline-suppression.sh" "$(mkpay "tests/cases.sh" "$HOOKS")"
expect_rc "inline-suppression: an unrelated src/hooks/tests/ directory is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "/work/proj/src/hooks/tests/x.sh")"
expect_rc "inline-suppression: a .. escape out of tests/ is code" 2 "$HOOKS/block-inline-suppression.sh" "$(mkpay "$HOOKTESTS_ABS/../x.sh")"
# Fail closed when the pattern file is missing. The hook is copied into a
# scratch tree of the same shape with and without the data file, and the SAME
# clean payload is run against both: a missing list must be refused, and the
# copy that has it must allow the edit, or the refusal proves only that the
# copy is broken.
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/Adapters/ai-runtimes/claude-code/hooks" "$SCRATCH/Adapters/scripts"
cp "$HOOKS/block-inline-suppression.sh" "$HOOKS/lib.sh" "$SCRATCH/Adapters/ai-runtimes/claude-code/hooks/"
expect_rc "inline-suppression: pattern file missing fails closed" 2 "$SCRATCH/Adapters/ai-runtimes/claude-code/hooks/block-inline-suppression.sh" "$PAY_CLEAN"
cp "$HOOKS/../../../scripts/suppression-patterns.tsv" "$SCRATCH/Adapters/scripts/"
expect_rc "inline-suppression: the same copy with the pattern file allows clean code" 0 "$SCRATCH/Adapters/ai-runtimes/claude-code/hooks/block-inline-suppression.sh" "$PAY_CLEAN"
rm -rf "$SCRATCH"

expect_rc "stop-gate: yields to its own loop guard"        0 "$HOOKS/stop-gate.sh"                '{"stop_hook_active":true}'

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
  # XDG_CACHE_HOME: session-start.sh keeps its drift result in the user's
  # cache (WU-IAENG-359); a test run must never write there.
  SS_OUT="$( (export CLAUDE_PROJECT_DIR="$dir" XDG_CACHE_HOME="$SSBASE/cache"; printf '%s' "$stdin" | bash "$hook") 2>&1 )"
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

# "claude-present": has a CLAUDE.md — the pre-existing, unconditional line
# must be unchanged (other tests may assert it).
CLAUDEPRESENT="$(ss_repo claude-present)"
echo '# CLAUDE' > "$CLAUDEPRESENT/CLAUDE.md"

# "claude-template": no CLAUDE.md, but the repo itself satisfies
# iaeng_framework_root (a Core/AGENT_CONDUCT.md of its own) and carries
# Templates/PROJECT_CLAUDE.md — the "template found" branch.
CLAUDETEMPLATE="$(ss_repo claude-template)"
mkdir -p "$CLAUDETEMPLATE/Core" "$CLAUDETEMPLATE/Templates"
echo 'placeholder' > "$CLAUDETEMPLATE/Core/AGENT_CONDUCT.md"
echo 'placeholder' > "$CLAUDETEMPLATE/Templates/PROJECT_CLAUDE.md"

# "state-template": no SESSION_STATE.md, but the repo satisfies
# iaeng_framework_root and carries Templates/SESSION_STATE.md — the branch
# where both hooks name Adapters/scripts/create-session-state.sh (#218).
STATETEMPLATE="$(ss_repo state-template)"
mkdir -p "$STATETEMPLATE/Core" "$STATETEMPLATE/Templates"
echo 'placeholder' > "$STATETEMPLATE/Core/AGENT_CONDUCT.md"
echo 'placeholder' > "$STATETEMPLATE/Templates/SESSION_STATE.md"

# "unparsable": a header with no recognisable "DD Month YYYY".
UNPARSABLE="$(ss_repo unparsable)"
echo '_Last updated: some day by Tester_' > "$UNPARSABLE/.ia-engineering/SESSION_STATE.md"
touch "$UNPARSABLE/.ia-engineering/SESSION_STATE.md"

# "stale-header": mtime is current (after HEAD — not behind), but the header
# text inside was never refreshed. Isolates Warning 2 from Warning 1.
STALEHDR="$(ss_repo stale-header)"
echo '_Last updated: 1 January 2020, morning by Tester_' > "$STALEHDR/.ia-engineering/SESSION_STATE.md"
touch "$STALEHDR/.ia-engineering/SESSION_STATE.md"

# "big": a SESSION_STATE of about 80,000 characters. The file has no size
# limit (Director decision, 22 October 2026: it is the agent's memory and
# may keep history), so the hook must not warn about its size — and must
# still read it to the end: the Next Step sits after the long history.
BIG="$(ss_repo big)"
{
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Where the Project Stands'
  yes 'padding padding padding padding padding' | head -n 2000
  echo '## Next Step'
  echo 'resume after a very long history'
} > "$BIG/.ia-engineering/SESSION_STATE.md"
BIG_CHARS="$(wc -c < "$BIG/.ia-engineering/SESSION_STATE.md" | tr -d '[:space:]')"
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

# ss_repo_future_head <name>  — like ss_repo, but HEAD's one commit is dated
# a day in the future: a clock-skewed or deliberately forward-dated commit.
# Built with the raw "<epoch> <tz>" form git accepts for *_DATE, so this
# needs only `date +%s` (portable) — no `date -d`.
ss_repo_future_head() {
  local dir="$SSBASE/$1" future
  mkdir -p "$dir/.ia-engineering"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.com
  git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  echo a > "$dir/f.txt"
  git -C "$dir" add f.txt
  future="$(( $(date +%s) + 86400 )) +0000"
  GIT_COMMITTER_DATE="$future" GIT_AUTHOR_DATE="$future" git -C "$dir" commit -qm init >/dev/null
  printf '%s' "$dir"
}

# "skew": HEAD dated a day from now; SESSION_STATE touched with a PLAIN
# `touch` — exactly what a real edit does, unlike an earlier version of this
# fixture that used `touch -d '+1 hour'` to keep mtime artificially ahead of
# "now". That version passed for the wrong reason: a first fix clamped
# HEAD's future time at a live-read "now" and kept comparing, which this
# fixture could not catch (mtime was always ahead of the clamp by
# construction) but review did — a real `touch`, checked a moment later,
# still failed, because "now" moves forward on every invocation while mtime
# stays fixed. The fix this now proves is different: a future HEAD_TS is
# never compared against mtime at all, so a plain touch passes regardless of
# how much real time elapses before the check runs.
SKEW="$(ss_repo_future_head skew)"
{
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Where the Project Stands'
  echo 'x'
} > "$SKEW/.ia-engineering/SESSION_STATE.md"
touch "$SKEW/.ia-engineering/SESSION_STATE.md"

# "skew-old": same future-dated HEAD, but SESSION_STATE's mtime is a fixed,
# ordinary date in the past — as real and "un-fresh" as a file gets. This is
# the case that proves the gate STAYS unblocked no matter how much time has
# passed or how old the file looks: since a future HEAD_TS is never used as
# a comparison partner at all, mtime's own age is irrelevant here. Chosen
# over an actual multi-second sleep in the test (which a slow CI box would
# pay on every run) — the mechanism this proves is identical: the gate does
# not silently re-open on elapsed real time.
SKEWOLD="$(ss_repo_future_head skew-old)"
echo '_Last updated: 1 January 2020, morning by Tester_' > "$SKEWOLD/.ia-engineering/SESSION_STATE.md"
touch -t 202001010000 "$SKEWOLD/.ia-engineering/SESSION_STATE.md"

# "no-datecmd-header": header "9 September 2026" (the reviewer's own
# example), mtime fixed later — proves the header-staleness check (Warning
# 2 / lib.sh's iaeng_ymd_from_header_date) works without `date -d` at all,
# via a fixed date pair rather than relying on the real clock ever being
# after 9 September 2026.
NODATECMD="$(ss_repo no-datecmd-header)"
echo '_Last updated: 9 September 2026, morning by Tester_' > "$NODATECMD/.ia-engineering/SESSION_STATE.md"
touch -t 202609240930 "$NODATECMD/.ia-engineering/SESSION_STATE.md"

# --- stop-gate.sh --------------------------------------------------------

ss_run "$STALE" "$STOPGATE"
ss_check_rc   "stop-gate: blocks when SESSION_STATE is older than HEAD" 2
ss_check_has  "stop-gate: block message names the reason" yes "behind the repository"

ss_run "$FRESH" "$STOPGATE"
ss_check_rc   "stop-gate: passes when SESSION_STATE is newer than HEAD" 0

ss_run "$MISSING" "$STOPGATE"
ss_check_rc   "stop-gate: passes (non-blocking) when SESSION_STATE is missing" 0
ss_check_has  "stop-gate: reminds when SESSION_STATE is missing" yes "does not exist"
ss_check_has  "stop-gate: the reminder names the helper that creates it (#218)" yes "the framework's Adapters/scripts/create-session-state.sh"

ss_run "$STATETEMPLATE" "$STOPGATE"
ss_check_rc   "stop-gate: missing SESSION_STATE with the framework found — still not blocking" 0
ss_check_has  "stop-gate: framework found — the reminder gives the helper's path (#218)" yes "run $STATETEMPLATE/Adapters/scripts/create-session-state.sh"

ss_run "$STALE" "$STOPGATE" '{"stop_hook_active":true}'
ss_check_rc   "stop-gate: loop guard still yields even when SESSION_STATE is stale" 0

ss_run "$DIRTY" "$STOPGATE"
ss_check_rc   "stop-gate: uncommitted tracked changes still block first" 2
ss_check_has  "stop-gate: dirty-tree message unchanged by the new gate" yes "uncommitted changes"

# ss_check_silent <label>  — the most recent ss_run exited 0 and printed nothing.
ss_check_silent() {
  TOTAL=$((TOTAL + 1))
  if [ "$SS_RC" -eq 0 ] && [ -z "$SS_OUT" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s: want exit 0 and no output, got exit %s and [%s]\n' "$1" "$SS_RC" "$(printf '%s' "$SS_OUT" | head -c 200)"
  fi
}

ss_run "$NOGIT" "$STOPGATE"
ss_check_rc   "stop-gate: fail-safe — not a git repo does not block" 0
# Outside a git directory the gate says nothing at all: no reminder, no
# "cannot verify", on every stop (WU-IAENG-410: git status, then rev-parse).
ss_check_silent "stop-gate: not a git repo — exits without a word"

ss_run "$SKEW" "$STOPGATE"
ss_check_rc   "stop-gate: a future-dated HEAD commit does not block a freshly-touched state (clock skew)" 0
ss_check_has  "stop-gate: clock-skew message names HEAD's date, not the behind-repository message" yes "dated after the system clock"
ss_check_has  "stop-gate: clock-skew case does not print the behind-repository message" no "is behind the repository"

ss_run "$SKEWOLD" "$STOPGATE"
ss_check_rc   "stop-gate: stays unblocked under clock skew even with an old, real mtime" 0
ss_check_has  "stop-gate: old-mtime clock-skew case still names the reason" yes "dated after the system clock"

# A SESSION_STATE.md whose mtime is not a non-negative integer, here one
# before 1970 (date -r prints a negative number), gives no value: the gate
# says it cannot verify and does not block, as lib.sh's helper always did.
# Where touch or the filesystem cannot set such a mtime, the case is said
# to be skipped, with the reason, and counts neither way.
PRE1970="$(ss_repo pre1970)"
echo '_Last updated: 1 January 1960_' > "$PRE1970/.ia-engineering/SESSION_STATE.md"
touch -t 196001010000 "$PRE1970/.ia-engineering/SESSION_STATE.md" 2>/dev/null
case "$(date -r "$PRE1970/.ia-engineering/SESSION_STATE.md" +%s 2>/dev/null)" in
  -[0-9]*)
    ss_run "$PRE1970" "$STOPGATE"
    ss_check_rc   "stop-gate: a pre-1970 SESSION_STATE mtime — not blocking" 0
    ss_check_has  "stop-gate: a pre-1970 SESSION_STATE mtime — says it cannot verify" yes "could not determine"
    ;;
  *) printf '   skip  %s\n' "stop-gate: a pre-1970 SESSION_STATE mtime — touch or this filesystem cannot set a mtime before 1970 here" ;;
esac

# THE LOOP GUARD SILENCES EVERY OUTPUT, NOT ONLY THE BLOCKS (WU-IAENG-410).
# stop-gate.sh reads stop_hook_active only when it is about to block or
# remind, so the path most stops take starts no jq. On the continuation a
# block gave, every path that would block or remind is still exit 0 and
# silent, as when the guard was read first. NOHEAD: a repository with no
# commit, where HEAD's time cannot be read and the hook says so.
NOHEAD="$SSBASE/nohead"
mkdir -p "$NOHEAD/.ia-engineering"
git -C "$NOHEAD" init -q
touch "$NOHEAD/.ia-engineering/SESSION_STATE.md"
ss_run "$NOHEAD" "$STOPGATE"
ss_check_has  "stop-gate: no commit yet — says it cannot verify (the fixture reaches that path)" yes "could not determine"
for case_dir in "$DIRTY" "$STALE" "$MISSING" "$SKEW" "$NOHEAD"; do
  ss_run "$case_dir" "$STOPGATE" '{"stop_hook_active":true}'
  ss_check_silent "stop-gate: loop guard — ${case_dir##*/}: exit 0, nothing printed"
done

# THE COMMON PATH'S PROCESS BUDGET (WU-IAENG-410, issue #351). On Windows
# every command a hook starts is a process creation, and under parallel
# agents that, not the hook's own work, is its latency
# (Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md). The path most stops take,
# a clean tree and a current SESSION_STATE, starts cat (lib.sh reading the
# payload), git twice (the status, HEAD's time) and date once (the file's
# mtime), and no jq. Counted with recording stand-ins, first on PATH, for
# the commands the hook used to start there and the text tools a hook
# reaches for; a command not in that list is not counted.
#
# A COUNT OF NOTHING IS NOT A PASS (CR M1 and QA F1 of PR #388). Under a
# drive-letter TMPDIR, mktemp -d gives C:/..., and C:/.../shims on PATH is
# split at the drive's colon: no stand-in ran and an empty log passed. So
# the directory goes on PATH in its POSIX form where cygpath can give it,
# and the check requires git in the log: the common path always starts git
# status, so a log without git means nothing was counted.
SHIMS="$SSBASE/shims"
SHIMLOG="$SSBASE/shims.log"
SHIMS_ON_PATH="$SHIMS"
command -v cygpath >/dev/null 2>&1 && SHIMS_ON_PATH="$(cygpath -u "$SHIMS")"
SHIM_CMDS="awk basename cat date dirname git grep head jq sed sort tr"
mkdir -p "$SHIMS"
for shim_cmd in $SHIM_CMDS; do
  shim_real="$(command -v "$shim_cmd")" || continue
  printf '#!/bin/sh\necho %s >> "%s"\nexec "%s" "$@"\n' "$shim_cmd" "$SHIMLOG" "$shim_real" > "$SHIMS/$shim_cmd"
  chmod +x "$SHIMS/$shim_cmd"
done
: > "$SHIMLOG"
PATH="$SHIMS_ON_PATH:$PATH" ss_run "$FRESH" "$STOPGATE"
ss_check_rc   "stop-gate: budget — the fresh path still passes with the stand-ins on PATH" 0
SHIM_GIT="$(grep -c '^git$' "$SHIMLOG")"
SHIM_JQ="$(grep -c '^jq$' "$SHIMLOG")"
SHIM_ALL="$(wc -l < "$SHIMLOG" | tr -d ' ')"
SHIM_LABEL="stop-gate: budget — clean tree, current state: git counted, no jq, at most 4 starts of: $SHIM_CMDS"
TOTAL=$((TOTAL + 1))
if [ "$SHIM_GIT" -ge 1 ] && [ "$SHIM_JQ" -eq 0 ] && [ "$SHIM_ALL" -le 4 ]; then
  [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$SHIM_LABEL"
else
  FAILED=$((FAILED + 1))
  SHIM_SEEN="$(sort "$SHIMLOG" | uniq -c | awk '{printf "%s x%s, ", $2, $1}')"
  [ -n "$SHIM_SEEN" ] || SHIM_SEEN="nothing (no stand-in ran, so nothing was counted)"
  printf '   FAIL  %s: started %s\n' "$SHIM_LABEL" "$SHIM_SEEN"
fi
# git rev-parse now runs only when git status fails, and decides as it did
# when it ran first: a bare repository fails git status but is a git
# directory, so the gate goes on to the state check (here, the reminder).
BARE="$SSBASE/bare.git"
git init -q --bare "$BARE"
ss_run "$BARE" "$STOPGATE"
ss_check_rc   "stop-gate: a bare repository (git status fails, rev-parse does not) — not blocking" 0
ss_check_has  "stop-gate: a bare repository — still reaches the state check, as before" yes "does not exist"

# Without dirname, lib.sh is still found from the hook's own path: by a bare
# name from its own directory, and where Windows spellings exist (cygpath),
# by a path with backslashes only, which MSYS dirname also splits.
SS_OUT="$(cd "$HOOKS" && printf '{}' | CLAUDE_PROJECT_DIR="$FRESH" bash stop-gate.sh 2>&1)"
SS_RC=$?
ss_check_silent "stop-gate: run by a bare name from its own directory — finds lib.sh, passes silently"
if command -v cygpath >/dev/null 2>&1; then
  SS_OUT="$(printf '{}' | CLAUDE_PROJECT_DIR="$FRESH" bash "$(cygpath -w "$STOPGATE")" 2>&1)"
  SS_RC=$?
  ss_check_silent "stop-gate: run by a Windows path with backslashes only — finds lib.sh, passes silently"
fi

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
ss_check_has  "session-start: no size warning for an ~80,000-character SESSION_STATE (no size limit)" no "character budget"
ss_check_has  "session-start: no character-count warning of any size for a long SESSION_STATE" no " characters (Core/CONTEXT_BUDGET.md"
ss_check_has  "session-start: the long SESSION_STATE's size ($BIG_CHARS characters) is not reported" no "$BIG_CHARS"
ss_check_has  "session-start: a long SESSION_STATE is still read — its header is printed" yes "Last updated: 24 September 2026"
ss_check_has  "session-start: a long SESSION_STATE is still read to the end — its Next Step is printed" yes "resume after a very long history"

ss_run "$SKEW" "$SESSTART" ''
ss_check_has  "session-start: no behind-warning when HEAD has a future committer date (clock skew)" no "behind the repository"
ss_check_has  "session-start: reports the clock-skew condition instead" yes "dated after the system clock"

ss_run "$SKEWOLD" "$SESSTART" ''
ss_check_has  "session-start: stays silent on behind-warning under clock skew even with an old, real mtime" no "behind the repository"
ss_check_has  "session-start: old-mtime clock-skew case still reports the reason" yes "dated after the system clock"

ss_run "$NODATECMD" "$SESSTART" ''
ss_check_has  "session-start: header staleness detected without date -d (9 September 2026 example)" yes "was not refreshed on the file's last edit"

ss_run "$CLAUDEPRESENT" "$SESSTART" ''
ss_check_has  "session-start: CLAUDE.md present — unchanged line" yes "1. CLAUDE.md — the project's stable contract."
ss_check_has  "session-start: CLAUDE.md present — does not warn it is missing" no "CLAUDE.md does not exist yet"

ss_run "$MISSING" "$SESSTART" ''
ss_check_has  "session-start: CLAUDE.md missing, template not found — says so" yes "CLAUDE.md does not exist yet and the framework's template was not found"
ss_check_has  "session-start: CLAUDE.md missing — does not print the stable-contract line" no "1. CLAUDE.md — the project's stable contract."

ss_run "$STATETEMPLATE" "$SESSTART" ''
ss_check_has  "session-start: SESSION_STATE missing, template found — names the helper that creates it (#218)" yes "Create it before any other action with $STATETEMPLATE/Adapters/scripts/create-session-state.sh, which writes the Template block of $STATETEMPLATE/Templates/SESSION_STATE.md"

ss_run "$CLAUDETEMPLATE" "$SESSTART" ''
ss_check_has  "session-start: CLAUDE.md missing, template found — points to PROJECT_BOOTSTRAP Phase B and Templates/PROJECT_CLAUDE.md" yes "CLAUDE.md does not exist yet — this project has not completed Workflows/PROJECT_BOOTSTRAP.md Phase B. It is created from $CLAUDETEMPLATE/Templates/PROJECT_CLAUDE.md at Workflows/ONBOARDING.md Step 1"
ss_check_has  "session-start: CLAUDE.md missing, template found — does not print the stable-contract line" no "1. CLAUDE.md — the project's stable contract."

echo 'placeholder' > "$CLAUDETEMPLATE/Core/MAIN_AGENT_CONDUCT.md"
ss_run "$CLAUDETEMPLATE" "$SESSTART" ''
ss_check_has  "session-start: MAIN_AGENT_CONDUCT.md found — points the Main Agent at it" yes "The Main Agent follows $CLAUDETEMPLATE/Core/MAIN_AGENT_CONDUCT.md: delegate every Work Unit to its named Employee"
ss_run "$CLAUDEPRESENT" "$SESSTART" ''
ss_check_has  "session-start: framework root not found — no Main Agent pointer" no "The Main Agent follows"
rm -f "$CLAUDETEMPLATE/Core/MAIN_AGENT_CONDUCT.md"
ss_run "$CLAUDETEMPLATE" "$SESSTART" ''
ss_check_has  "session-start: root found but MAIN_AGENT_CONDUCT.md absent — no Main Agent pointer" no "The Main Agent follows"

# --- Every SessionStart source, the same read-first context (WU-IAENG-373) ---
# /clear starts a new session (payload "source": "clear"); it must get what a
# startup gets — SESSION_STATE read, its Next Step printed — not a shorter or
# different context. The payload is the one Claude Code sends, per source;
# the output is compared whole, so any branch on the source would show.
{
  echo '# SESSION STATE — test'
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Next Step'
  echo 'resume the Work Unit after /clear'
} > "$FRESH/.ia-engineering/SESSION_STATE.md"
touch "$FRESH/.ia-engineering/SESSION_STATE.md"
ss_payload() { printf '{"session_id":"t","transcript_path":"/nonexistent","cwd":"%s","hook_event_name":"SessionStart","source":"%s"}' "$FRESH" "$1"; }
ss_run "$FRESH" "$SESSTART" "$(ss_payload startup)"
SS_STARTUP_OUT="$SS_OUT"
ss_check_rc   "session-start: source startup — exits 0" 0
ss_check_has  "session-start: source startup — SESSION_STATE's Next Step is printed" yes "resume the Work Unit after /clear"
for ss_src in clear resume compact; do
  ss_run "$FRESH" "$SESSTART" "$(ss_payload "$ss_src")"
  ss_check_rc   "session-start: source $ss_src — exits 0" 0
  ss_check_has  "session-start: source $ss_src — SESSION_STATE's Next Step is printed" yes "resume the Work Unit after /clear"
  TOTAL=$((TOTAL + 1))
  if [ "$SS_OUT" = "$SS_STARTUP_OUT" ]; then
    [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "session-start: source $ss_src — output identical to startup"
  else
    FAILED=$((FAILED + 1))
    printf '   FAIL  %s\n' "session-start: source $ss_src — output identical to startup"
    diff <(printf '%s\n' "$SS_STARTUP_OUT") <(printf '%s\n' "$SS_OUT") | head -10 | sed 's/^/         /'
  fi
done

# --- Tier map in force (WU-IAENG-336, issue #212) ------------------------
# A Main Agent applying a Lightweight Tier Override in a project whose
# tier-map gave every tier claude-opus-5-5 dispatched with "sonnet": nothing
# the session read named the Lightweight model. The hook now prints the map
# the generator resolves. These fixtures are throwaway projects pointed at the
# REAL framework (IAENG_FRAMEWORK), so the real generate-agents.sh resolves.
FRAMEWORK="$(cd "$HOOKS/../../../.." && pwd)"
export IAENG_FRAMEWORK="$FRAMEWORK"

TM_SAME="$(ss_repo tiermap-same)"
printf '%s\n' 'map=strategic=claude-opus-5-5,standard=claude-opus-5-5,lightweight=claude-opus-5-5,frontier=fable' \
  'effort-map=strategic=high,standard=,lightweight=,frontier=' > "$TM_SAME/.ia-engineering/tier-map"
ss_run "$TM_SAME" "$SESSTART" ''
ss_check_rc   "session-start: tier-map present — exits 0" 0
ss_check_has  "session-start: tier-map present — prints the map in force and its source" yes "Tier map in force — mapping: file ("
ss_check_has  "session-start: tier-map present — names the Lightweight model of the map" yes "lightweight=claude-opus-5-5,"
ss_check_has  "session-start: tier-map present — states the override rule" yes "never on a model or alias of the Main Agent's own choosing"
ss_check_has  "session-start: every tier on one model — says an override passes no model" yes "all map to claude-opus-5-5: an override between them changes no model — dispatch without a model parameter."

TM_DEFAULTS="$(ss_repo tiermap-defaults)"
ss_run "$TM_DEFAULTS" "$SESSTART" ''
ss_check_has  "session-start: no tier-map — prints the target defaults, said so" yes "Tier map in force — mapping: defaults (target claude-code"
ss_check_has  "session-start: no tier-map — names the default Lightweight model" yes "lightweight=haiku,"
ss_check_has  "session-start: tiers on different models — no same-model line" no "an override between them changes no model"

TM_PARTIAL="$(ss_repo tiermap-partial)"
printf '%s\n' 'map=strategic=big,standard=mid,lightweight=mid,frontier=top' > "$TM_PARTIAL/.ia-engineering/tier-map"
ss_run "$TM_PARTIAL" "$SESSTART" ''
ss_check_has  "session-start: lightweight equal to standard only — no same-model line" no "an override between them changes no model"
ss_check_has  "session-start: lightweight equal to standard only — map printed" yes "map=strategic=big,standard=mid,lightweight=mid,frontier=top"

TM_BAD="$(ss_repo tiermap-malformed)"
printf '%s\n' 'map=bogus=x' > "$TM_BAD/.ia-engineering/tier-map"
ss_run "$TM_BAD" "$SESSTART" ''
ss_check_rc   "session-start: malformed tier-map — still exits 0 (never blocks)" 0
ss_check_has  "session-start: malformed tier-map — reports it, not silent" yes "WARNING: the tier map could not be resolved — "
ss_check_has  "session-start: malformed tier-map — names the generator's reason" yes "entry: bogus=x"
ss_check_has  "session-start: malformed tier-map — tells the Main Agent not to pick a model" yes "ask the Director rather than pick one"
ss_check_has  "session-start: malformed tier-map — prints no map in force" no "Tier map in force"

unset IAENG_FRAMEWORK
ss_run "$CLAUDEPRESENT" "$SESSTART" ''
ss_check_has  "session-start: framework root not found — no tier map line" no "Tier map in force"
ss_check_has  "session-start: framework root not found — no tier map warning" no "the tier map could not be resolved"

rm -rf "$SSBASE"

# --- Usage dashboard: Stop hook, installers, /dashboard (WU-IAENG-342) -------
# Its own file, so it can be run alone (tests/dashboard.sh); its checks are
# counted here. A run that reports no counts is a failure, never a pass.
DASH_COUNTS="$(mktemp "${TMPDIR:-/tmp}/iaeng-dash-counts.XXXXXX")"
DASH_ARGS=()
[ "$VERBOSE" -eq 1 ] && DASH_ARGS=(--verbose)
IAENG_HOOK_TESTS_COUNTS="$DASH_COUNTS" bash "$HERE/dashboard.sh" ${DASH_ARGS[@]+"${DASH_ARGS[@]}"}
DASH_RC=$?
if read -r DASH_TOTAL DASH_FAILED < "$DASH_COUNTS" 2>/dev/null \
    && [[ "$DASH_TOTAL" =~ ^[0-9]+$ ]] && [[ "$DASH_FAILED" =~ ^[0-9]+$ ]] && [ "$DASH_TOTAL" -gt 0 ]; then
  TOTAL=$((TOTAL + DASH_TOTAL))
  FAILED=$((FAILED + DASH_FAILED))
  if [ "$DASH_RC" -ne 0 ] && [ "$DASH_FAILED" -eq 0 ]; then
    TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
    echo "   FAIL  tests/dashboard.sh exited $DASH_RC with no failed check counted"
  fi
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  echo "   FAIL  tests/dashboard.sh reported no counts (exit $DASH_RC) — it could not run"
fi
rm -f "$DASH_COUNTS"

# --- Framework drift at session start (WU-IAENG-359) -------------------------
# Its own file too (tests/drift.sh), counted here the same way.
DRIFT_COUNTS="$(mktemp "${TMPDIR:-/tmp}/iaeng-drift-counts.XXXXXX")"
IAENG_HOOK_TESTS_COUNTS="$DRIFT_COUNTS" bash "$HERE/drift.sh" ${DASH_ARGS[@]+"${DASH_ARGS[@]}"}
DRIFT_RC=$?
if read -r DRIFT_TOTAL DRIFT_FAILED < "$DRIFT_COUNTS" 2>/dev/null \
    && [[ "$DRIFT_TOTAL" =~ ^[0-9]+$ ]] && [[ "$DRIFT_FAILED" =~ ^[0-9]+$ ]] && [ "$DRIFT_TOTAL" -gt 0 ]; then
  TOTAL=$((TOTAL + DRIFT_TOTAL))
  FAILED=$((FAILED + DRIFT_FAILED))
  if [ "$DRIFT_RC" -ne 0 ] && [ "$DRIFT_FAILED" -eq 0 ]; then
    TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
    echo "   FAIL  tests/drift.sh exited $DRIFT_RC with no failed check counted"
  fi
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  echo "   FAIL  tests/drift.sh reported no counts (exit $DRIFT_RC) — it could not run"
fi
rm -f "$DRIFT_COUNTS"

# --- Context alert (WU-IAENG-380) ---------------------------------------------
# Its own file too (tests/context-alert.sh), counted here the same way.
ALERT_COUNTS="$(mktemp "${TMPDIR:-/tmp}/iaeng-alert-counts.XXXXXX")"
IAENG_HOOK_TESTS_COUNTS="$ALERT_COUNTS" bash "$HERE/context-alert.sh" ${DASH_ARGS[@]+"${DASH_ARGS[@]}"}
ALERT_RC=$?
if read -r ALERT_TOTAL ALERT_FAILED < "$ALERT_COUNTS" 2>/dev/null \
    && [[ "$ALERT_TOTAL" =~ ^[0-9]+$ ]] && [[ "$ALERT_FAILED" =~ ^[0-9]+$ ]] && [ "$ALERT_TOTAL" -gt 0 ]; then
  TOTAL=$((TOTAL + ALERT_TOTAL))
  FAILED=$((FAILED + ALERT_FAILED))
  if [ "$ALERT_RC" -ne 0 ] && [ "$ALERT_FAILED" -eq 0 ]; then
    TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
    echo "   FAIL  tests/context-alert.sh exited $ALERT_RC with no failed check counted"
  fi
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  echo "   FAIL  tests/context-alert.sh reported no counts (exit $ALERT_RC) — it could not run"
fi
rm -f "$ALERT_COUNTS"

# --- Context statusLine (WU-IAENG-379) -----------------------------------------
# Its own file too (tests/context-statusline.sh), counted here the same way.
CTX_COUNTS="$(mktemp "${TMPDIR:-/tmp}/iaeng-ctx-counts.XXXXXX")"
IAENG_HOOK_TESTS_COUNTS="$CTX_COUNTS" bash "$HERE/context-statusline.sh" ${DASH_ARGS[@]+"${DASH_ARGS[@]}"}
CTX_RC=$?
if read -r CTX_TOTAL CTX_FAILED < "$CTX_COUNTS" 2>/dev/null \
    && [[ "$CTX_TOTAL" =~ ^[0-9]+$ ]] && [[ "$CTX_FAILED" =~ ^[0-9]+$ ]] && [ "$CTX_TOTAL" -gt 0 ]; then
  TOTAL=$((TOTAL + CTX_TOTAL))
  FAILED=$((FAILED + CTX_FAILED))
  if [ "$CTX_RC" -ne 0 ] && [ "$CTX_FAILED" -eq 0 ]; then
    TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
    echo "   FAIL  tests/context-statusline.sh exited $CTX_RC with no failed check counted"
  fi
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  echo "   FAIL  tests/context-statusline.sh reported no counts (exit $CTX_RC) — it could not run"
fi
rm -f "$CTX_COUNTS"

# --- Own directory (WU-IAENG-400) ----------------------------------------------
# Its own file too (tests/own-dir.sh), counted here the same way.
OWN_COUNTS="$(mktemp "${TMPDIR:-/tmp}/iaeng-own-counts.XXXXXX")"
IAENG_HOOK_TESTS_COUNTS="$OWN_COUNTS" bash "$HERE/own-dir.sh" ${DASH_ARGS[@]+"${DASH_ARGS[@]}"}
OWN_RC=$?
if read -r OWN_TOTAL OWN_FAILED < "$OWN_COUNTS" 2>/dev/null \
    && [[ "$OWN_TOTAL" =~ ^[0-9]+$ ]] && [[ "$OWN_FAILED" =~ ^[0-9]+$ ]] && [ "$OWN_TOTAL" -gt 0 ]; then
  TOTAL=$((TOTAL + OWN_TOTAL))
  FAILED=$((FAILED + OWN_FAILED))
  if [ "$OWN_RC" -ne 0 ] && [ "$OWN_FAILED" -eq 0 ]; then
    TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
    echo "   FAIL  tests/own-dir.sh exited $OWN_RC with no failed check counted"
  fi
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  echo "   FAIL  tests/own-dir.sh reported no counts (exit $OWN_RC) — it could not run"
fi
rm -f "$OWN_COUNTS"

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
