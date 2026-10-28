#!/usr/bin/env bash
# IA Engineering — hook tests: a hook loads its files from its own directory
# (WU-IAENG-400, issue #344)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/own-dir.sh [--verbose]
#
# THE DEFECT. Five hooks named their own directory with dirname "$0". When
# bash finds a hook through PATH (`bash stop-gate.sh`, with the hooks
# directory on PATH and the hook not in the working directory), $0 is the
# bare name, and its dirname is the working directory. A lib.sh there was
# sourced by all five. A strip-quotes.awk there was run as the escape-hatch
# lexer. A context-alert.sh there was run by session-start.sh. The
# suppression hook read its patterns from ../../../scripts/ of the working
# directory, and exempted the working directory's tests/. A cloned
# repository can hold any of these files (SEC-IAENG-394-03).
#
# THE REGRESSION GUARDED SINCE. Bash 5.3 imports BASH_SOURCE from the
# environment, so a hook that read its directory from BASH_SOURCE first
# loaded the files under a BASH_SOURCE=<dir>/x set by the caller, even when
# run by its absolute path, as installed (SEC-IAENG-400-01). The hooks take
# $0 when it holds a separator, and BASH_SOURCE only when $0 is a bare name.
#
# What is proved. Each hook is invoked four ways:
#   path  found through PATH, from a working directory that holds a planted
#         copy of every file the hook loads;
#   win   named by a path with backslashes only, from that same directory
#         (Windows, where dirname reads a backslash);
#   env   named by its absolute path, from a clean directory, with
#         BASH_SOURCE=<the planted directory>/x in the environment;
#   here  found in the working directory, which is the hooks directory.
#
#   - No planted file is used (path, win, env). Each planted script appends
#     its name to a log when it runs, and the log must stay empty. The planted
#     patterns file holds one row that matches nothing, so a hook that read it
#     would allow. In the here form no planted file is reachable, so these
#     checks could not fail there and are not run.
#   - The hook still does its job, which it can do only with its own files
#     (all four forms; in the here form, this is what proves it loaded them):
#       block-escape-hatches.sh refuses an escape hatch;
#       block-inline-suppression.sh refuses a directive in a .py file, and
#         also under the working directory's tests/;
#       post-edit-lint.sh fails a .sh file with a syntax error;
#       session-start.sh runs its own context-alert.sh, which warns about an
#         IAENG_CTX_ALERT_PCT that is not a whole number;
#       stop-gate.sh yields on stop_hook_active, a guard that needs lib.sh;
#     and none of them prints "command not found".
#
# ORACLES (Standards/TESTING_STANDARD.md, Independent Oracle). None is taken
# from a hook's output:
#   - where the files must come from: issue #344, and hooks/README.md, Design
#     Rules, "Load from the hook's own directory";
#   - the escape hatch: the first block case of tests/escape-hatch-cases.tsv,
#     written from Standards/GIT_STANDARD.md, Escape Hatches;
#   - the directive: Standards/CODE_QUALITY_STANDARD.md, No Inline
#     Suppression. The scope of the tests/ exemption is "the tests/ directory
#     next to this hook" (block-inline-suppression.sh's header);
#   - the lint failure: post-edit-lint.sh's header (bash -n; a failure is
#     exit 2 with "iaeng: lint failed");
#   - the threshold warning: hooks/README.md, Context Alert;
#   - the loop guard: stop-gate.sh's header, and hooks/README.md's example,
#     where {"stop_hook_active":true} gives rc=0.
#
#   - BASH_SOURCE from the environment: SEC-IAENG-400-01, reproduced on Git
#     Bash 5.3.9 by the Security Engineer on PR #363.
#
# The win form runs only where cygpath exists (Git Bash). The env form runs
# only where this bash takes BASH_SOURCE from the environment, which a probe
# script checks first: elsewhere no hook can be misled that way, and the
# checks could not fail. Either is otherwise reported "n/a" with its reason,
# never counted as a pass. Exit 0 when
# every check passes, 1 when any fails, 2 when the environment is unusable.
# With IAENG_HOOK_TESTS_COUNTS set to a file, "<total> <failed>" is written
# there.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "own-dir.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"

for tool in jq git; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "own-dir.sh: $tool is required and is not installed. Reported rather than skipped." >&2
    exit 2
  }
done
HOOK_NAMES="block-escape-hatches.sh block-inline-suppression.sh post-edit-lint.sh session-start.sh stop-gate.sh"
for h in $HOOK_NAMES; do
  [ -f "$HOOKS/$h" ] || { echo "own-dir.sh: $HOOKS/$h is missing" >&2; exit 2; }
done
ESC="$(awk -F'\t' '$1 == "block" { print $2; exit }' "$HERE/escape-hatch-cases.tsv")"
[ -n "$ESC" ] || { echo "own-dir.sh: no block case in $HERE/escape-hatch-cases.tsv" >&2; exit 2; }

FAILED=0
TOTAL=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0; }
na() { printf '   n/a   %s — %s\n' "$1" "$2"; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-owndir.XXXXXX")" || { echo "own-dir.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'cd / && rm -rf "$T"' EXIT

# --- The planted working directory ---------------------------------------------
# $W/../../../scripts is $T/w/scripts, where the suppression hook looked for its
# patterns when its own directory was taken to be $W.
LOG="$T/planted.log"
W="$T/w/x/y/z"
PROJ="$T/project"
mkdir -p "$W/tests" "$W/src" "$T/w/scripts" "$PROJ" "$T/cache"
cat > "$W/lib.sh" <<EOF
printf '%s\n' lib.sh >> "$LOG"
EOF
cat > "$W/strip-quotes.awk" <<EOF
BEGIN { print "strip-quotes.awk" >> "$LOG" }
EOF
cat > "$W/context-alert.sh" <<EOF
printf '%s\n' context-alert.sh >> "$LOG"
EOF
printf 'planted\t^this-planted-row-matches-nothing$\n' > "$T/w/scripts/suppression-patterns.tsv"
for h in $HOOK_NAMES; do
  [ ! -e "$W/$h" ] || { echo "own-dir.sh: $W/$h exists, so bash would not search PATH" >&2; exit 2; }
done

# A repository with a tracked change, for the stop gate.
REPO="$T/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.com
git -C "$REPO" config user.name t
git -C "$REPO" config commit.gpgsign false
git -C "$REPO" config core.autocrlf false
echo a > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init >/dev/null
echo b > "$REPO/f.txt"

SUPPRESSED="$(printf 'x = 1  #%s' ' noqa')"
printf 'if then\n' > "$T/bad.sh"

# hook <how> <hook> <payload> [VAR=value...] — runs the hook with a scratch
# project and cache, and none of the variables that would change what it
# says. Empties the log first. Sets OUT, ERR and RC.
#   path  `bash <hook>` from $W, the hooks directory first on PATH
#   win   `bash <C:\...\hooks\hook>` from $W, a path with backslashes only
#   env   `bash <absolute path>` from $PROJ, with BASH_SOURCE=$W/<hook>
#   here  `bash <hook>` from the hooks directory itself
WINHOOKS=""
hook() {
  local how="$1" name="$2" payload="$3" dir="$W" arg="$2" pre=()
  shift 3
  case "$how" in
    win) arg="$WINHOOKS\\$name" ;;
    env) dir="$PROJ"; arg="$HOOKS/$name"; pre=(BASH_SOURCE="$W/$name") ;;
    here) dir="$HOOKS" ;;
  esac
  : > "$LOG"
  (cd "$dir" && printf '%s' "$payload" \
    | env -u IAENG_FRAMEWORK -u IAENG_CONTEXT_HOOKS -u IAENG_CTX_ALERT_PCT -u IAENG_CTX_LAST_CALL_PCT \
        CLAUDE_PROJECT_DIR="$PROJ" XDG_CACHE_HOME="$T/cache" PATH="$HOOKS:$PATH" \
        ${pre[@]+"${pre[@]}"} "$@" bash "$arg") > "$T/out" 2> "$T/err"
  RC=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}

# not_used <label> <file> — the planted <file> did not run. Not run in the
# here form, where no planted file is reachable and the check could not fail.
HOW=""
not_used() {
  [ "$HOW" != here ] || return 0
  if grep -qxF -- "$2" "$LOG"; then
    bad "$1: $2 is not loaded from the planted directory" "the planted $2 ran"
  else
    ok "$1: $2 is not loaded from the planted directory"
  fi
}

# all_found <label> — no helper was missing: lib.sh was loaded.
all_found() {
  case "$ERR" in
    *"command not found"*) bad "$1: every helper is defined" "$(grep -m1 'command not found' <<< "$ERR")" ;;
    *) ok "$1: every helper is defined" ;;
  esac
}

# refused <label> — exit 2 with an "iaeng: BLOCKED — " reason.
refused() {
  if [ "$RC" -eq 2 ] && grep -q '^iaeng: BLOCKED — ' <<< "$ERR"; then
    ok "$1"
  else
    bad "$1" "want exit 2 and an iaeng: BLOCKED reason, got exit $RC: $(head -1 <<< "$ERR")"
  fi
}

# suite <how> — every hook, invoked <how>.
suite() {
  local how="$1" l
  HOW="$how"
  echo "== own directory — invoked $how"
  [ "$how" != here ] || na "here: no planted file is used" "the working directory is the hooks directory, so no planted file is reachable; the checks below prove the hooks' own files were loaded"

  l="block-escape-hatches.sh ($how)"
  hook "$how" block-escape-hatches.sh "$(jq -n --arg c "$ESC" '{tool_name:"Bash",tool_input:{command:$c}}')"
  not_used "$l" lib.sh
  not_used "$l" strip-quotes.awk
  all_found "$l"
  refused "$l: refuses an escape hatch"

  l="block-inline-suppression.sh ($how)"
  hook "$how" block-inline-suppression.sh "$(jq -n --arg f "$W/src/x.py" --arg c "$SUPPRESSED" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}')"
  not_used "$l" lib.sh
  all_found "$l"
  refused "$l: refuses a directive in a .py file, by its own patterns"
  hook "$how" block-inline-suppression.sh "$(jq -n --arg f "$W/tests/x.py" --arg c "$SUPPRESSED" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}')"
  refused "$l: refuses a directive under the working directory's tests/ (only its own tests/ is exempt)"

  l="post-edit-lint.sh ($how)"
  hook "$how" post-edit-lint.sh "$(jq -n --arg f "$T/bad.sh" '{tool_name:"Write",tool_input:{file_path:$f}}')"
  not_used "$l" lib.sh
  all_found "$l"
  if [ "$RC" -eq 2 ] && grep -q '^iaeng: lint failed' <<< "$ERR"; then
    ok "$l: fails a .sh file with a syntax error"
  else
    bad "$l: fails a .sh file with a syntax error" "want exit 2 and iaeng: lint failed, got exit $RC: $(head -1 <<< "$ERR")"
  fi

  l="session-start.sh ($how)"
  hook "$how" session-start.sh '{"hook_event_name":"SessionStart","source":"startup"}' IAENG_CTX_ALERT_PCT=abc
  not_used "$l" lib.sh
  not_used "$l" context-alert.sh
  all_found "$l"
  if grep -qF 'IAENG_CTX_ALERT_PCT is not a whole number' <<< "$OUT"; then
    ok "$l: runs its own context-alert.sh"
  else
    bad "$l: runs its own context-alert.sh" "no threshold warning in the output (exit $RC)"
  fi

  l="stop-gate.sh ($how)"
  hook "$how" stop-gate.sh '{"hook_event_name":"Stop","stop_hook_active":true}' CLAUDE_PROJECT_DIR="$REPO"
  not_used "$l" lib.sh
  all_found "$l"
  if [ "$RC" -eq 0 ]; then
    ok "$l: yields on stop_hook_active with a tracked change"
  else
    bad "$l: yields on stop_hook_active with a tracked change" "want exit 0, got exit $RC: $(head -1 <<< "$ERR")"
  fi
}

suite path
if command -v cygpath >/dev/null 2>&1; then
  WINHOOKS="$(cygpath -w "$HOOKS")"
  case "$WINHOOKS" in
    */*) na "invoked win" "cygpath -w gave a path with a forward slash: $WINHOOKS" ;;
    *) suite win ;;
  esac
else
  na "invoked win (a path with backslashes only)" "no Windows paths on this platform (no cygpath)"
fi
cat > "$T/probe.sh" <<'EOF'
printf '%s' "${BASH_SOURCE[0]}"
EOF
if [ "$(env BASH_SOURCE=/iaeng-probe/x bash "$T/probe.sh" 2>/dev/null)" = /iaeng-probe/x ]; then
  suite env
else
  na "invoked env (BASH_SOURCE in the environment)" "this bash ($(bash -c 'echo "$BASH_VERSION"')) does not take BASH_SOURCE from the environment, so no hook can be misled by it"
fi
suite here

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
